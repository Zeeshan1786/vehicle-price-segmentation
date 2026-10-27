if (!file.exists("DESCRIPTION")) stop("Run setup from the repository root.")
runtime_packages <- c("shiny", "bslib", "plumber", "httr2", "jsonlite", "ggplot2", "scales", "DT", "openssl")
missing_packages <- runtime_packages[!vapply(runtime_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) install.packages(missing_packages, repos = "https://cloud.r-project.org")
unavailable <- runtime_packages[!vapply(runtime_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(unavailable)) stop(paste("Installation did not complete for:", paste(unavailable, collapse = ", ")))
message("Runtime dependencies are ready. Setup does not download datasets or train models.")
message("Before team development, validate versions and capture an renv lockfile; see docs/ROADMAP.md.")
