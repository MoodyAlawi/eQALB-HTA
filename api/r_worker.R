# eQalb model worker: a persistent, headless R bridge to the model API.
#
# This process owns no model logic and no request-shaping logic of its own.
# At start-up it builds the plumber router from api/plumber.R and takes the
# route handler functions out of it, so every endpoint keeps exactly one
# implementation (the plumber one). Requests then arrive over stdin as one
# JSON object per line and replies go to stdout as one JSON object per line:
#
#   in   {"id": 1, "endpoint": "psa", "query": {"n_sim": "1000"}, "body": {}}
#   out  {"id": 1, "ok": true, "result": {...}}
#   out  {"id": 1, "ok": false, "error": "..."}
#
# A start-up line {"ready": true, ...} announces that the model modules parsed
# and which endpoints are available. Anything the model prints while handling a
# request is captured (and forwarded to stderr), so stdout carries protocol
# lines only.
#
# Started by api/r_client.py; not meant to be run by hand, but it is harmless:
# it reads stdin until end-of-input and then exits.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
api_dir <- if (length(file_arg) > 0L) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  file.path(getwd(), "api")
}
api_root <- dirname(api_dir)
options(eqalb.api.root = api_root)

suppressPackageStartupMessages({
  library(plumber)
  library(jsonlite)
})

write_line <- function(payload) {
  cat(
    jsonlite::toJSON(payload, auto_unbox = TRUE, digits = NA, null = "null", na = "null"),
    "\n",
    sep = "",
    file = stdout()
  )
  flush(stdout())
}

log_stderr <- function(...) {
  cat(paste0("[r_worker] ", ...), "\n", sep = "", file = stderr())
  flush(stderr())
}

# --- Endpoint registry -------------------------------------------------------
# plumber stores the parsed routes as a list of router nodes; each node is a
# named list of route entries that carry the handler function. Taking the
# handlers out of the router is what keeps this file free of model logic.

router <- plumber::pr(file.path(api_dir, "plumber.R"))

endpoints <- list()
for (node in router$routes) {
  if (!is.list(node) || is.null(names(node))) next
  for (name in names(node)) {
    handler <- tryCatch(node[[name]]$getFunc(), error = function(error) NULL)
    if (is.function(handler)) {
      endpoints[[name]] <- handler
    }
  }
}
rm(node, name)

if (length(endpoints) == 0L) {
  log_stderr("no endpoints found in ", file.path(api_dir, "plumber.R"))
  quit(status = 1L)
}

# --- Request handling --------------------------------------------------------

handle_request <- function(request) {
  id <- request$id
  endpoint <- as.character(request$endpoint)[1]
  handler <- endpoints[[endpoint]]
  if (is.null(handler)) {
    return(list(
      id = id, ok = FALSE,
      error = paste0("Unknown endpoint '", endpoint, "'. Known: ", paste(sort(names(endpoints)), collapse = ", "))
    ))
  }

  query <- request$query
  if (is.null(query)) query <- list()
  body <- request$body
  # digits = NA keeps posted numbers at full double precision. jsonlite's default
  # would round them to four decimal places, which quietly changes values a client
  # sends back to R (most visibly the PSA draws posted to /api/value-of-information).
  post_body <- if (is.null(body) || length(body) == 0L) {
    ""
  } else {
    jsonlite::toJSON(body, auto_unbox = TRUE, digits = NA, null = "null", na = "null")
  }
  req <- list(
    postBody = as.character(post_body),
    argsQuery = query,
    REQUEST_METHOD = if (identical(post_body, "")) "GET" else "POST"
  )

  # The handler return value is shipped in an environment because capture.output()
  # evaluates its expression in a frame of its own; environments are passed by
  # reference, so the assignment survives.
  box <- new.env(parent = emptyenv())
  output <- character(0)
  tryCatch(
    {
      call <- if (length(formals(handler)) == 0L) handler else function() handler(req)
      output <- utils::capture.output(box$value <- call(), type = "output")
      TRUE
    },
    error = function(error) {
      output <<- c(output, paste0("error: ", conditionMessage(error)))
      FALSE
    }
  ) -> succeeded

  if (length(output) > 0L) {
    # Model progress printing (e.g. heemod state expansion) is captured above;
    # forward it to stderr so the protocol stream stays clean but nothing is lost.
    log_stderr(endpoint, ": ", paste(trimws(output), collapse = " | "))
  }

  if (!isTRUE(succeeded)) {
    return(list(id = id, ok = FALSE, error = paste(trimws(output), collapse = "\n")))
  }

  list(id = id, ok = TRUE, result = box$value)
}

# --- Main loop ---------------------------------------------------------------

input <- file("stdin", open = "r")
on.exit(close(input), add = TRUE)

write_line(list(
  ready = TRUE,
  worker_pid = Sys.getpid(),
  api_root = api_root,
  endpoints = sort(names(endpoints))
))

repeat {
  line <- readLines(input, n = 1L, warn = FALSE)
  if (length(line) == 0L) break
  line <- trimws(line)
  if (!nzchar(line)) next

  response <- tryCatch(
    handle_request(jsonlite::fromJSON(line, simplifyVector = FALSE)),
    error = function(error) {
      list(id = NULL, ok = FALSE, error = paste0("worker failure: ", conditionMessage(error)))
    }
  )
  write_line(response)
}
