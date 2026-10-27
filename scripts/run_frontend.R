if (!file.exists("frontend/app.R")) stop("Run this script from the repository root.")
port <- as.integer(Sys.getenv("SHINY_PORT", "3838"))
if (is.na(port) || port < 1L || port > 65535L) stop("Invalid SHINY_PORT.")
shiny::runApp("frontend", host = "127.0.0.1", port = port, launch.browser = interactive())
