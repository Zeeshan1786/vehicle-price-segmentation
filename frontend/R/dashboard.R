dashboard_ui <- function() {
  nav_panel("Dashboard",
    div(class = "dashboard-heading",
        div(div(class = "eyebrow", "MOTOR / VALUE INTELLIGENCE"), h2("The used-car market, explored."),
            p("Explore historical listings. Filter the market, inspect the data, then build your models.")),
        span(class = "data-badge", "REAL DATA / NO MODELS TRAINED")),
    layout_sidebar(
      sidebar = sidebar(width = 260, title = "Explore the market",
        selectizeInput("dash_brand", "Manufacturer", choices = c("All manufacturers" = "__all__")),
        selectInput("dash_fuel", "Fuel type", choices = c("All fuels" = "__all__")),
        selectInput("dash_transmission", "Transmission", choices = c("All transmissions" = "__all__")),
        sliderInput("dash_year", "Manufacturing year", min = 1980, max = as.integer(format(Sys.Date(), "%Y")),
                    value = c(1980, as.integer(format(Sys.Date(), "%Y"))), sep = ""),
        checkboxInput("dash_log", "Log scale for prices", value = TRUE),
        actionButton("dash_reset", "Reset filters", class = "btn-outline-primary"),
        tags$hr(),
        actionButton("dash_reload", "Load repository dataset", class = "btn-primary"),
        fileInput("dash_upload", "Or explore your CSV", accept = ".csv", buttonLabel = "Choose CSV"),
        p(class = "muted text-small", "CarDekho v3 column format. Maximum 15 MB. Uploaded data stays in this session."),
        downloadButton("dash_download", "Export filtered data")),
      uiOutput("dash_source"),
      uiOutput("dash_kpis"),
      navset_card_underline(
        nav_panel("Market overview",
          layout_columns(col_widths = c(7, 5),
            card(card_header("Distance driven vs. listing price"),
                 plotOutput("dash_scatter", height = 330, hover = hoverOpts("dash_hover", delay = 100)),
                 uiOutput("dash_hover_detail"),
                 p(class = "chart-caption", "Each point is one listing. Hover to inspect. No regression model is fitted.")),
            card(card_header("Listing price distribution"), plotOutput("dash_hist", height = 330),
                 p(class = "chart-caption", "Historical asking prices, not completed sale prices."))),
          layout_columns(
            card(card_header("Price ranges by manufacturer"), plotOutput("dash_brands", height = 320),
                 p(class = "chart-caption", "Top eight manufacturers by listing count. Boxplots show median and spread.")),
            card(card_header("Fuel mix"), plotOutput("dash_fuel_plot", height = 320),
                 p(class = "chart-caption", "Counts update with the active filters.")))),
        nav_panel("Relationships",
          layout_columns(
            card(card_header("Numeric feature correlations"), plotOutput("dash_correlation", height = 400),
                 p(class = "chart-caption", "Pearson correlation using available pairs. Association does not establish causation.")),
            card(card_header("Median asking price by model year"), plotOutput("dash_year_plot", height = 400),
                 p(class = "chart-caption", "A descriptive trend across historical listings, not a forecast.")))),
        nav_panel("Data quality",
          uiOutput("dash_audit"),
          card(card_header("Missing source values"), plotOutput("dash_missing", height = 340),
               p(class = "chart-caption", "Source-wide audit before deduplication and row exclusions. Dashboard filters do not change this audit."))),
        nav_panel("Data explorer", DT::DTOutput("dash_table"))
      )
    )
  )
}

dashboard_server <- function(input, output, session) {
  data_state <- reactiveVal(NULL)
  error_state <- reactiveVal("Loading the dataset from the API...")
  set_dataset <- function(response) {
    if (!response$ok || !isTRUE(response$body$ready)) {
      error_state(response$body$message)
      showNotification(response$body$message, type = "warning", duration = 8)
      return(invisible(NULL))
    }
    payload <- response$body
    if (!is.data.frame(payload$vehicles)) {
      error_state("The dataset response is invalid.")
      return(invisible(NULL))
    }
    data_state(payload)
    error_state(NULL)
    updateSelectizeInput(session, "dash_brand", choices = c("All manufacturers" = "__all__",
      sort(unique(payload$vehicles$brand))), selected = "__all__", server = TRUE)
    updateSelectInput(session, "dash_fuel", choices = c("All fuels" = "__all__", sort(unique(payload$vehicles$fuel))), selected = "__all__")
    updateSelectInput(session, "dash_transmission", choices = c("All transmissions" = "__all__",
      sort(unique(payload$vehicles$transmission))), selected = "__all__")
    updateSliderInput(session, "dash_year", min = min(payload$vehicles$year), max = max(payload$vehicles$year),
      value = range(payload$vehicles$year))
  }
  observeEvent(TRUE, set_dataset(api_request("/data/vehicles")), once = TRUE)
  observeEvent(input$dash_reload, set_dataset(api_request("/data/vehicles")))
  observeEvent(input$dash_upload, {
    upload <- input$dash_upload
    if (upload$size > 15 * 1024^2) {
      showNotification("Choose a CSV smaller than 15 MB.", type = "error")
      return(invisible(NULL))
    }
    csv <- paste(readLines(upload$datapath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    set_dataset(api_request("/data/preview", charToRaw(enc2utf8(csv)), content_type = "csv"))
  })
  observeEvent(input$dash_reset, {
    req(data_state())
    updateSelectizeInput(session, "dash_brand", selected = "__all__")
    updateSelectInput(session, "dash_fuel", selected = "__all__")
    updateSelectInput(session, "dash_transmission", selected = "__all__")
    updateSliderInput(session, "dash_year", value = range(data_state()$vehicles$year))
    updateCheckboxInput(session, "dash_log", value = TRUE)
  })
  filtered <- reactive({
    validate(need(!is.null(data_state()), "Load the repository dataset or upload a compatible CSV to explore it."))
    values <- data_state()$vehicles
    for (pair in list(c("brand", "dash_brand"), c("fuel", "dash_fuel"), c("transmission", "dash_transmission"))) {
      choice <- input[[pair[[2]]]]
      if (!is.null(choice) && choice != "__all__") values <- values[values[[pair[[1]]]] == choice, , drop = FALSE]
    }
    if (!is.null(input$dash_year)) values <- values[values$year >= input$dash_year[[1]] &
      values$year <= input$dash_year[[2]], , drop = FALSE]
    values
  })
  nonempty <- reactive({
    values <- filtered()
    validate(need(nrow(values) > 0L, "No listings match these filters. Try resetting the filters."))
    values
  })
  chart_theme <- function() {
    ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#e8edf4", linewidth = .4),
      axis.title = ggplot2::element_text(colour = "#64728a", size = 11),
      plot.margin = ggplot2::margin(12, 14, 8, 8), legend.position = "bottom",
      legend.title = ggplot2::element_blank())
  }
  price_scale <- function() {
    if (isTRUE(input$dash_log)) ggplot2::scale_y_log10(labels = scales::label_number(scale = 1e-5, suffix = " L"))
    else ggplot2::scale_y_continuous(labels = scales::label_number(scale = 1e-5, suffix = " L"))
  }
  fuel_colors <- c(Petrol = "#2458d3", Diesel = "#079987", CNG = "#d78924", LPG = "#9a60ba")
  output$dash_source <- renderUI({
    current <- data_state()
    if (is.null(current)) return(div(class = "notice notice-error", error_state()))
    div(class = "source-line", span(class = "source-dot"), current$source,
        span(class = "muted", " / Historical dataset · Prices in INR"),
        if (!is.null(error_state())) div(class = "notice notice-error", error_state()))
  })
  output$dash_kpis <- renderUI({
    values <- nonempty()
    stat <- function(label, value, detail) div(class = "metric-card", div(class = "metric-label", label),
      div(class = "metric-value", value), div(class = "metric-detail", detail))
    div(class = "metric-grid",
      stat("VEHICLES IN VIEW", format(nrow(values), big.mark = ","), "After audit and active filters"),
      stat("MEDIAN ASKING PRICE", paste0("INR ", format(round(median(values$selling_price_inr) / 1e5, 2), nsmall = 2), " L"), "L = lakh = 100,000 INR"),
      stat("MEDIAN DISTANCE", paste0(format(round(median(values$km_driven)), big.mark = ","), " km"), "Recorded odometer distance"),
      stat("MANUFACTURERS", length(unique(values$brand)), paste0(min(values$year), "–", max(values$year), " model years")))
  })
  output$dash_scatter <- renderPlot({
    values <- nonempty()
    ggplot2::ggplot(values, ggplot2::aes(km_driven, selling_price_inr, colour = fuel)) +
      ggplot2::geom_point(alpha = .42, size = 1.7) + price_scale() +
      ggplot2::scale_colour_manual(values = fuel_colors, na.value = "#64728a") +
      ggplot2::scale_x_continuous(labels = scales::label_number(scale = .001, suffix = "k")) +
      ggplot2::labs(x = "Distance driven (km)", y = "Asking price (INR lakh)") + chart_theme()
  }, res = 110)
  output$dash_hover_detail <- renderUI({
    req(input$dash_hover)
    values <- nonempty()
    # ggplot hover coordinates on a log axis are transformed; compare in the same space.
    if (isTRUE(input$dash_log)) {
      values$.hover_price <- log10(values$selling_price_inr)
      point <- nearPoints(values, input$dash_hover, xvar = "km_driven", yvar = ".hover_price", maxpoints = 1)
    } else point <- nearPoints(values, input$dash_hover, xvar = "km_driven", yvar = "selling_price_inr", maxpoints = 1)
    if (!nrow(point)) return(NULL)
    div(class = "hover-detail", strong(point$name[[1]]), " · INR ",
        format(point$selling_price_inr[[1]], big.mark = ","), " · ", point$fuel[[1]])
  })
  output$dash_hist <- renderPlot({
    values <- nonempty()
    plot <- ggplot2::ggplot(values, ggplot2::aes(selling_price_inr)) +
      ggplot2::geom_histogram(bins = 28, fill = "#2458d3", colour = "#f4f6fa", linewidth = .25) +
      ggplot2::labs(x = "Asking price (INR lakh)", y = "Listings") + chart_theme()
    if (isTRUE(input$dash_log)) plot + ggplot2::scale_x_log10(labels = scales::label_number(scale = 1e-5))
    else plot + ggplot2::scale_x_continuous(labels = scales::label_number(scale = 1e-5))
  }, res = 110)
  output$dash_brands <- renderPlot({
    values <- nonempty()
    top <- names(head(sort(table(values$brand), decreasing = TRUE), 8))
    values <- values[values$brand %in% top, ]
    ggplot2::ggplot(values, ggplot2::aes(stats::reorder(brand, selling_price_inr, median), selling_price_inr)) +
      ggplot2::geom_boxplot(fill = "#bcd0ff", colour = "#2458d3", outlier.alpha = .15, width = .6) +
      price_scale() + ggplot2::coord_flip() + ggplot2::labs(x = NULL, y = "Asking price (INR lakh)") + chart_theme()
  }, res = 110)
  output$dash_fuel_plot <- renderPlot({
    values <- nonempty()
    ggplot2::ggplot(values, ggplot2::aes(fuel, fill = fuel)) + ggplot2::geom_bar(width = .55) +
      ggplot2::scale_fill_manual(values = fuel_colors, guide = "none") +
      ggplot2::labs(x = NULL, y = "Listings") + chart_theme()
  }, res = 110)
  output$dash_year_plot <- renderPlot({
    values <- nonempty()
    trend <- aggregate(selling_price_inr ~ year, values, median)
    ggplot2::ggplot(trend, ggplot2::aes(year, selling_price_inr)) +
      ggplot2::geom_line(colour = "#079987", linewidth = 1) + ggplot2::geom_point(colour = "#079987", size = 2) +
      price_scale() + ggplot2::labs(x = "Manufacturing year", y = "Median asking price (INR lakh)") + chart_theme()
  }, res = 110)
  output$dash_correlation <- renderPlot({
    values <- nonempty()[c("selling_price_inr", "year", "km_driven", "engine_cc", "max_power_bhp", "seats")]
    validate(need(nrow(values) >= 3, "Choose filters with at least three listings."))
    names(values) <- c("Price", "Year", "Distance", "Engine", "Power", "Seats")
    matrix <- suppressWarnings(stats::cor(values, use = "pairwise.complete.obs"))
    cells <- as.data.frame(as.table(matrix), stringsAsFactors = FALSE)
    ggplot2::ggplot(cells, ggplot2::aes(Var1, Var2, fill = Freq)) +
      ggplot2::geom_tile(colour = "#ffffff", linewidth = 1) +
      ggplot2::geom_text(ggplot2::aes(label = ifelse(is.na(Freq), "—", sprintf("%.2f", Freq))), size = 3.3) +
      ggplot2::scale_fill_gradient2(low = "#f0b884", mid = "#f6f8fc", high = "#7ba0f2", limits = c(-1, 1),
        na.value = "#eeeeee", name = "Correlation") +
      ggplot2::coord_equal() + ggplot2::labs(x = NULL, y = NULL) + chart_theme() +
      ggplot2::theme(panel.grid = ggplot2::element_blank())
  }, res = 110)
  output$dash_audit <- renderUI({
    req(data_state())
    audit <- data_state()$report
    div(class = "audit-summary", strong("Source-wide cleaning audit"),
      p(paste(format(audit$raw_rows, big.mark = ","), "source rows ·",
        audit$exact_duplicates_removed, "exact duplicates removed ·", audit$invalid_rows_removed,
        "invalid price/year/distance rows excluded ·", audit$unknown_brand_rows, "unmapped manufacturer rows.")),
      p("Missing engine, power or seat values are retained for exploration. No imputation or model fitting has run."))
  })
  output$dash_missing <- renderPlot({
    req(data_state())
    missing <- data_state()$missingness
    missing$percent <- 100 * missing$missing / pmax(missing$total, 1)
    ggplot2::ggplot(missing, ggplot2::aes(stats::reorder(field, percent), percent)) +
      ggplot2::geom_col(fill = "#d78924", width = .6) + ggplot2::coord_flip() +
      ggplot2::labs(x = NULL, y = "Missing source values (%)") + chart_theme()
  }, res = 110)
  output$dash_table <- DT::renderDT({
    values <- filtered()[c("name", "year", "selling_price_inr", "km_driven", "fuel", "transmission",
      "owner", "engine_cc", "max_power_bhp", "seats")]
    DT::datatable(values, rownames = FALSE, filter = "top", escape = TRUE,
      options = list(pageLength = 10, scrollX = TRUE, lengthMenu = c(10, 25, 50))) |>
      DT::formatCurrency("selling_price_inr", currency = "INR ", digits = 0)
  }, server = TRUE)
  output$dash_download <- downloadHandler(
    filename = function() paste0("vehicle-listings-", Sys.Date(), ".csv"),
    content = function(file) {
      values <- filtered()
      # Prevent spreadsheet formulas when arbitrary uploaded strings are exported.
      values[] <- lapply(values, function(x) {
        if (is.character(x)) x[grepl("^[=+@-]", x)] <- paste0("'", x[grepl("^[=+@-]", x)])
        x
      })
      write.csv(values, file, row.names = FALSE, na = "")
    })
}
