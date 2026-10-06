# Launcher for the eQalb Shiny app.
# Pinned to http://127.0.0.1:7788 so the address is stable.
#
# Run it directly:
#   & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" ".\run_app.R"
# Or in VS Code: Terminal > Run Task > "eQalb: run app (127.0.0.1:7788)".
#
# Note: this file intentionally contains no model logic and does not modify
# app.R; it only starts the existing Shiny application.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
app_dir <- if (length(file_arg) > 0L) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  getwd()
}

shiny::runApp(
  appDir = app_dir,
  host = "127.0.0.1",
  port = 7788L,
  launch.browser = TRUE
)
