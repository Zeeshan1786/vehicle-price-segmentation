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
      span(class = "phase-pill", "Phase 01 · Application foundation")
    ),
    layout_columns(
      card(card_header("01 / Price prediction"),
           h3("From features to an estimate"),
           p("Enter a vehicle profile and submit it to the prediction API. Price estimates become available after training.")),
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
      p(class = "muted", "No training has run. No database or account is required."))
  ),
  nav_panel("Vehicle workspace",
    div(class = "section-intro", h2("Build a vehicle profile"),
        p("Use the same profile for price prediction and segmentation.")),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Vehicle details"),
        div(class = "input-grid",
          lapply(names(vehicle_schema()), function(name) {
            feature_control(name, vehicle_schema()[[name]], vehicle_example()[[name]])
          })),
        div(class = "action-row",
          actionButton("predict", "Request price estimate", class = "btn-primary"),
          actionButton("segment", "Request segment", class = "btn-outline-primary"))),
      card(card_header("Result"),
        uiOutput("result"),
        tags$hr(),
        p(class = "muted", "A result belongs to the submitted profile. Submit again after changing inputs."))
    )
  ),
  nav_panel("Dataset plan",
    div(class = "section-intro", h2("Data before models"),
        p("Initial scope: Indian used-car listings, with prices expressed in INR.")),
    card(card_header("Proposed source"),
      h3("Vehicle dataset / CarDekho"),
      p("Candidate file: Car details v3.csv. Inspect the exact version, license, units, duplicates and missing values before using it."),
      tags$a("Open dataset source", href = "https://www.kaggle.com/datasets/nehalbirla/vehicle-dataset-from-cardekho",
             target = "_blank", rel = "noopener"),
      p("A versioned source acquisition is available locally for the dashboard. Raw data stays outside Git; clone users can run scripts/acquire_data.R. No models have been trained.")),
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
    card(card_header("03 / Price models · later"),
         p("Compare a median baseline, linear regression and random forest with held-out MAE, RMSE and R-squared.")),
    card(card_header("04 / Segmentation · later"),
         p("Compare standardized numeric k-means and mixed-feature Gower/PAM clustering; evaluate stability and interpret profiles.")),
    card(card_header("05 / Model integration · later"),
         p("Load versioned preprocessing and model bundles, implement inference, and validate the full user journey."))
  )
)

server <- function(input, output, session) {
  dashboard_server(input, output, session)
  status <- reactiveVal(NULL)
  result <- reactiveVal(NULL)
  refresh <- function() status(api_request("/health"))
  observeEvent(TRUE, refresh(), once = TRUE)
  observeEvent(input$refresh_status, refresh())

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
    profile <- setNames(lapply(names(vehicle_schema()), function(name) input[[name]]),
                        names(vehicle_schema()))
    validation <- validate_vehicle(profile)
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
      span(class = "phase-pill", "Models awaiting training")))
    body <- current$body
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
