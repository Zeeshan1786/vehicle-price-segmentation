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
  nav_panel("Overview",
    div(class = "hero",
      div(class = "eyebrow", "VEHICLE INTELLIGENCE / R PROJECT"),
      h1("Understand a vehicle.", tags$br(), "Discover its value."),
      p("A workspace for used-car price prediction and vehicle segmentation."),
      span(class = "phase-pill", "R linear regression · Price prediction ready")
    ),
    layout_columns(
      card(card_header("01 / Price prediction"),
           h3("From features to an estimate"),
           p("Enter dataset-based vehicle details and estimate the historical listing price using the trained R linear regression.")),
      card(card_header("02 / Vehicle segmentation"),
           h3("Find vehicles that belong together"),
           p("Group vehicles by their characteristics. Cluster assignments and profiles arrive after the segmentation pipeline.")),
      card(card_header("03 / Data preparation"),
           h3("A documented foundation"),
           p("Source selection, a shared feature contract, and an evaluation plan come before model fitting."))
    ),
    card(card_header("Project readiness"),
      actionButton("refresh_status", "Refresh API status", class = "btn-outline-primary"),
      uiOutput("health"),
      p(class = "muted", "Linear regression is trained. Segmentation remains planned. No database or account is required."))
  ),
  nav_panel("Price predictor",
    div(class = "section-intro", h2("Estimate a vehicle's listing price"),
        p("Choose a manufacturer and model from the dataset, then check the year and specifications.")),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Vehicle details"),
        uiOutput("predictor_form"),
        div(class = "action-row",
          actionButton("predict", "Predict price", class = "btn-primary"),
          actionButton("segment", "Request segment", class = "btn-outline-primary"))),
      card(card_header("Result"),
        uiOutput("result"),
        tags$hr(),
        p(class = "muted", "A result belongs to the submitted profile. Submit again after changing inputs."))
    ),
    card(card_header("Model evaluation"), uiOutput("price_metrics"),
      p(class = "muted", "Mileage and torque are omitted from this baseline because source units and formats vary. Selling price is the target, never an input. Exact variants are pooled into manufacturer/model families for regression."))
  ),
  nav_panel("Dataset plan",
    div(class = "section-intro", h2("Data before models"),
        p("Initial scope: Indian used-car listings, with prices expressed in INR.")),
    card(card_header("Proposed source"),
      h3("Vehicle dataset / CarDekho"),
      p("Candidate file: Car details v3.csv. Inspect the exact version, license, units, duplicates and missing values before using it."),
      tags$a("Open dataset source", href = "https://www.kaggle.com/datasets/nehalbirla/vehicle-dataset-from-cardekho",
             target = "_blank", rel = "noopener"),
      p("A versioned source acquisition is available locally. Raw data stays outside Git; clone users can run scripts/acquire_data.R. A linear price regression is trained; segmentation remains planned.")),
    card(card_header("Application feature contract"), tableOutput("schema_table")),
    card(card_header("Planned workflow"),
      tags$ol(
        tags$li("Verify source and license; record acquisition metadata."),
        tags$li("Audit units, missing values and duplicate listing groups."),
        tags$li("Reserve the test set before preprocessing or model selection."),
        tags$li("Train regression and clustering workflows separately."),
        tags$li("Publish validated RDS bundles, metrics and a model card.")))
  ),
  nav_panel("Roadmap",
    div(class = "section-intro", h2("Build in deliberate phases"),
        p("The application structure is the first deliverable.")),
    card(card_header("01 / Foundation · current"),
         p("Frontend, API, validation, input examples, dataset contract and documentation.")),
    card(card_header("02 / Dataset audit · next"),
         p("Confirm source eligibility, clean fields, define duplicate groups, freeze a split and capture dependencies.")),
    card(card_header("03 / Price model · implemented"),
         p("An R linear regression is trained and compared with a median-price baseline on a grouped held-out test set. MAE, RMSE and R-squared are reported in the predictor.")),
    card(card_header("04 / Segmentation · later"),
         p("Compare standardized numeric k-means and mixed-feature Gower/PAM clustering; evaluate stability and interpret profiles.")),
    card(card_header("05 / Price inference · implemented"),
         p("The API loads a versioned coefficient/preprocessing bundle and serves validated price estimates. Clustering and more advanced price models remain future work."))
  )
)

server <- function(input, output, session) {
  dashboard_server(input, output, session)
  status <- reactiveVal(NULL)
  result <- reactiveVal(NULL)
  predictor_options <- reactiveVal(NULL)
  refresh <- function() {
    status(api_request("/health"))
    options_response <- api_request("/predictor/options")
    predictor_options(if (options_response$ok) options_response$body else NULL)
  }
  observeEvent(TRUE, refresh(), once = TRUE)
  observeEvent(input$refresh_status, refresh())

  output$predictor_form <- renderUI({
    options <- predictor_options()
    if (is.null(options)) return(div(class = "notice", "The predictor is unavailable. Check that the backend is running and refresh API status."))
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
    div(p(strong("Multiple linear regression · R stats::lm")),
      p(paste0(format(options$training$train_rows, big.mark = ","), " training records · ",
        format(options$training$test_rows, big.mark = ","), " held-out test records · matching profiles kept together")),
      p(paste0("Test MAE: INR ", format(round(metrics$mae_inr), big.mark = ","),
        " · RMSE: INR ", format(round(metrics$rmse_inr), big.mark = ","),
        " · R-squared: ", round(metrics$r_squared, 3))),
      p(class = "muted", paste(options$metrics$test_nonpositive_predictions,
        "test estimates were nonpositive; the interactive predictor rejects those results. Metrics include them without clipping.")))
  })

  output$health <- renderUI({
    current <- status()
    if (is.null(current)) return(p("Checking API status..."))
    if (!current$ok) return(div(class = "notice notice-error", current$body$message))
    div(class = "notice",
        strong("API connected"),
        p("Price model: ", current$body$models$price_model,
          " · Segmentation model: ", current$body$models$segmentation_model))
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
  observeEvent(input$segment, submit_profile("segment"))

  output$result <- renderUI({
    current <- result()
    if (is.null(current)) return(div(class = "empty-state", h3("Your result will appear here"),
      p("Complete the vehicle profile and choose an action."),
      span(class = "phase-pill", "Linear regression trained in R")))
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
      div(class = "eyebrow", if (current$task == "predict") "PRICE PREDICTION" else "VEHICLE SEGMENTATION"),
      h3(if (identical(body$code, "MODEL_NOT_TRAINED")) "Ready for the training phase" else "Request status"),
      p(body$message),
      if (length(body$details)) tags$ul(lapply(body$details, tags$li)))
  })

  output$schema_table <- renderTable({
    schema <- vehicle_schema()
    data.frame(
      Field = names(schema),
      Description = vapply(schema, function(x) x$label, character(1)),
      Type = vapply(schema, function(x) x$type, character(1)),
      check.names = FALSE)
  }, striped = TRUE, bordered = FALSE)
}

shinyApp(ui, server)
