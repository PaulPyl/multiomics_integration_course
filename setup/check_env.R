#!/usr/bin/env Rscript
# Smoke test: everything a student needs before the lab starts.
# Run with: pixi run check

ok <- TRUE

report <- function(label, expr) {
  res <- tryCatch(expr, error = function(e) e)
  if (inherits(res, "error")) {
    cat(sprintf("[FAIL] %-34s %s\n", label, conditionMessage(res)))
    ok <<- FALSE
  } else {
    cat(sprintf("[ok]   %-34s %s\n", label, res))
  }
}

# Run first: if R is searching libraries outside the project, every package check
# below can be answered by the wrong R's packages. This happens when a host
# exports R_LIBS_SITE / R_LIBS (RStudio Server's terminal does).
report("library paths isolated", {
  root <- Sys.getenv("PIXI_PROJECT_ROOT")
  if (!nzchar(root)) stop("PIXI_PROJECT_ROOT is not set - run this with `pixi run check`")
  outside <- Filter(function(p) !startsWith(normalizePath(p), normalizePath(root)), .libPaths())
  if (length(outside))
    stop("R also searches: ", paste(outside, collapse = ", "),
         " - these belong to another R and can shadow this environment's packages")
  "all inside the project"
})

for (pkg in c("MOFA2", "MOFAdata", "mixOmics", "tidyverse", "data.table",
              "randomForest", "survival", "survminer", "BiocStyle",
              "rmarkdown", "reticulate")) {
  local({
    p <- pkg
    report(p, as.character(packageVersion(p)))
  })
}

report("reticulate python", {
  py <- reticulate::py_config()$python
  # reticulate silently swaps in a scratch uv-managed Python (no mofapy2) when it
  # cannot use RETICULATE_PYTHON, so check it picked the project's own.
  if (!startsWith(normalizePath(py), normalizePath(Sys.getenv("PIXI_PROJECT_ROOT"))))
    stop("using ", py, " instead of the project's Python (RETICULATE_PYTHON was ignored)")
  py
})
report("mofapy2 importable", {
  reticulate::import("mofapy2")
  "import ok"
})

report("CLL_data loads", {
  utils::data("CLL_data", package = "MOFAdata")
  paste(names(get("CLL_data")), collapse = ", ")
})

report("breast.TCGA loads", {
  utils::data("breast.TCGA", package = "mixOmics")
  paste(names(get("breast.TCGA")$data.train), collapse = ", ")
})

report("local CLL metadata", {
  m <- data.table::fread("data/CLL_sample_metadata.txt")
  sprintf("%d samples x %d cols", nrow(m), ncol(m))
})

report("local TCGA clinical", {
  m <- data.table::fread("data/TCGA-BRCA.Clinical.tsv")
  sprintf("%d rows x %d cols", nrow(m), ncol(m))
})

cat("\n")
if (ok) {
  cat("Environment looks good.\n")
} else {
  cat("Some checks failed - see [FAIL] lines above.\n")
  quit(status = 1)
}
