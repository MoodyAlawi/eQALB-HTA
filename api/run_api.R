# Launcher for the eQalb model API.
# Pinned to http://127.0.0.1:8788 so the frontend proxy address is stable.
#
# Run it directly:
#   & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" ".\api\run_api.R"
# Or in VS Code: Terminal > Run Task > "eQalb: run model API (127.0.0.1:8788)".
#
# This file only starts the HTTP service defined in api/plumber.R; it contains
# no model logic and does not modify app.R or the model modules.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
api_dir <- if (length(file_arg) > 0L) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  file.path(getwd(), "api")
}
api_root <- dirname(api_dir)

if (!requireNamespace("plumber", quietly = TRUE)) {
  stop(
    "The plumber package is required for the API layer. ",
    "Install it with renv::install(\"plumber\").",
    call. = FALSE
  )
}

options(eqalb.api.root = api_root)
API_ROOT <- api_root

pr <- plumber::pr(file.path(api_dir, "plumber.R"))
cat("eQalb model API on http://127.0.0.1:8788 (model root: ", api_root, ")\n", sep = "")
cat("Simulated illustrative data - not clinical evidence.\n")

plumber::pr_run(
  pr,
  host = "127.0.0.1",
  port = 8788L,
  docs = TRUE
)
