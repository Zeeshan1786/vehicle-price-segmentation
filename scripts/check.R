if (!file.exists("shared/schema.R")) stop("Run checks from the repository root.")
r_files <- list.files(c("frontend", "backend", "shared", "scripts", "tests"),
                      pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
invisible(lapply(r_files, parse))
source("tests/contracts.R")
source("shared/schema.R")
source("backend/R/services.R")
router <- plumber::plumb("backend/plumber.R")
stopifnot(inherits(router, "Plumber"))
app_env <- new.env(parent = globalenv())
app <- source("frontend/app.R", local = app_env, chdir = TRUE)$value
stopifnot(inherits(app, "shiny.appobj"))
message("All R files parse; contracts pass; API router and Shiny application load.")
