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

for (pkg in c("MOFA2", "MOFAdata", "mixOmics", "tidyverse", "data.table",
              "randomForest", "survival", "survminer", "BiocStyle",
              "rmarkdown", "reticulate")) {
  local({
    p <- pkg
    report(p, as.character(packageVersion(p)))
  })
}

report("reticulate python", reticulate::py_config()$python)
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
