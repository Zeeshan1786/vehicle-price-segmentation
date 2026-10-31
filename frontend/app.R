library(shiny)
library(bslib)
source("../shared/schema.R", local = TRUE)
source("R/client.R", local = TRUE)
source("R/dashboard.R", local = TRUE)
options(shiny.maxRequestSize = 15 * 1024^2)

feature_control <- function(name, spec, value) {
  if (!is.null(spec$choices)) return(selectInput(name, spec$label, spec$choices, selected = value))
  if (spec$type == "string") return(textInput(name, spec$label, value = value))
  numericInput(name, spec$label, value = value, min = spec$min, max = spec$max,
               step = if (spec$type == "integer") 1 else 0.1)
}

ui <- page_navbar(
  title = tags$span(class = "brand-mark", "MOTOR / VALUE"),
  theme = bs_theme(version = 5, bg = "#f4f6fa", fg = "#18243b", primary = "#2458d3",
                   base_font = "system-ui"),
  header = tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
  fillable = FALSE,
  dashboard_ui(),
  nav_panel("Price predictor",
    div(class = "section-intro", h2("Estimate a vehicle's listing price"),
        p("Choose a manufacturer and model from the dataset, then check the year and specifications.")),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Vehicle details"),
        uiOutput("predictor_form"),
        div(class = "action-row",
          actionButton("predict", "Predict price", class = "btn-primary"))),
      card(card_header("Result"),
        uiOutput("result"),
        tags$hr(),
        p(class = "muted", "A result belongs to the submitted profile. Submit again after changing inputs."))
    ),
    card(card_header("Model evaluation"), uiOutput("price_metrics"),
      p(class = "muted", "Mileage and torque are omitted from this baseline because source units and formats vary. Selling price is the target, never an input. Exact variants are pooled into manufacturer/model families for regression."))
  )
)

server <- function(input, output, session) {
  dashboard_server(input, output, session)
  result <- reactiveVal(NULL)
  predictor_options <- reactiveVal(NULL)
  refresh <- function() {
    options_response <- api_request("/predictor/options")
    predictor_options(if (options_response$ok) options_response$body else NULL)
  }
  observeEvent(TRUE, refresh(), once = TRUE)

  output$predictor_form <- renderUI({
    options <- predictor_options()
    if (is.null(options)) return(div(class = "notice", "The predictor is unavailable. Check that the backend is running, then refresh this page."))
    div(class = "input-grid", lapply(names(options$fields), function(name) {
      spec <- options$fields[[name]]
      if (name == "model") spec$choices <- options$models_by_brand[[options$example$brand]]
      feature_control(name, spec, options$example[[name]])
    }))
  })
  observeEvent(input$brand, {
    options <- predictor_options()
    req(options)
    choices <- options$models_by_brand[[input$brand]]
    req(length(choices))
    selected <- if (!is.null(input$model) && input$model %in% choices) input$model else choices[[1]]
    updateSelectInput(session, "model", choices = choices, selected = selected)
  })
  output$price_metrics <- renderUI({
    options <- predictor_options()
    req(options)
    metrics <- options$metrics$model
    div(p(strong(if (is.null(options$algorithm_label)) "Multiple linear regression · R stats::lm" else options$algorithm_label)),
      p(paste0(format(options$training$train_rows, big.mark = ","), " training records · ",
        format(options$training$test_rows, big.mark = ","), " held-out test records · matching profiles kept together")),
      p(paste0("Test MAE: INR ", format(round(metrics$mae_inr), big.mark = ","),
        " · RMSE: INR ", format(round(metrics$rmse_inr), big.mark = ","),
        " · R-squared: ", round(metrics$r_squared, 3))),
      if (!is.null(options$metrics$linear_baseline)) p(paste0(
        "Linear baseline: R-squared ", round(options$metrics$linear_baseline$r_squared, 3),
        " · MAE INR ", format(round(options$metrics$linear_baseline$mae_inr), big.mark = ","))),
      p(class = "muted", "Model settings were selected using five-fold grouped cross-validation within the training set. Every record in the unchanged test set is included in these test metrics. R-squared measures explained variation, not percentage accuracy."))
  })

  submit_profile <- function(task) {
    options <- predictor_options()
    req(options)
    profile <- setNames(lapply(names(options$fields), function(name) {
      value <- input[[name]]
      if (options$fields[[name]]$type == "integer") value <- suppressWarnings(as.integer(value))
      value
    }), names(options$fields))
    validation <- validate_vehicle(profile, options$fields)
    if (!validation$ok) {
      result(list(task = task, body = list(code = "VALIDATION_ERROR",
        message = "Please correct the vehicle details.", details = as.list(validation$errors))))
      return(invisible(NULL))
    }
    response <- api_request(paste0("/", task), profile)
    result(list(task = task, body = response$body))
  }
  observeEvent(input$predict, submit_profile("predict"))

  output$result <- renderUI({
    current <- result()
    if (is.null(current)) return(div(class = "empty-state", h3("Your result will appear here"),
      p("Complete the vehicle profile and click Predict price."),
      span(class = "phase-pill", "Price model trained in R")))
    body <- current$body
    if (identical(body$status, "ok") && !is.null(body$predicted_price_inr)) {
      return(div(class = "notice",
        div(class = "eyebrow", "ESTIMATED HISTORICAL LISTING PRICE"),
        div(class = "metric-value", paste0("INR ", format(body$predicted_price_inr, big.mark = ",", scientific = FALSE))),
        p(paste0(round(body$predicted_price_inr / 1e5, 2), " lakh · ", body$algorithm)),
        p(class = "muted", paste("Model:", body$model_version)),
        tags$ul(lapply(body$warnings, tags$li))))
    }
    div(class = "notice",
      div(class = "eyebrow", "PRICE PREDICTION"),
      h3(if (identical(body$code, "MODEL_NOT_TRAINED")) "Ready for the training phase" else "Request status"),
      p(body$message),
      if (length(body$details)) tags$ul(lapply(body$details, tags$li)))
  })

}

shinyApp(ui, server)
