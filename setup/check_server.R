# Environment check for a plain RStudio Server (system R, no pixi).
# Run from the project root:  source("setup/check_server.R")
#
# Unlike check_env.R this assumes nothing about pixi. It reports what the labs
# will actually find, so gaps show up before the students hit them.

ok <- TRUE
line <- function(status, label, detail = "") {
  cat(sprintf("[%-4s] %-34s %s\n", status, label, detail))
  if (status == "FAIL") ok <<- FALSE
}
check <- function(label, expr) {
  r <- tryCatch(expr, error = function(e) e)
  if (inherits(r, "error")) line("FAIL", label, conditionMessage(r))
  else line("ok", label, r)
}

cat("== System ==\n")
line("info", "R", R.version.string)
line("info", "platform", R.version$platform)
line("info", "user", Sys.info()[["user"]])
line("info", "working directory", getwd())
line("info", "cores", as.character(parallel::detectCores()))
mem <- tryCatch(system("free -g | awk '/Mem:/ {print $2\" GB total, \"$7\" GB available\"}'",
                       intern = TRUE), error = function(e) "n/a", warning = function(w) "n/a")
line("info", "memory", paste(mem, collapse = ""))
line("info", "pixi activation seen?",
     if (nzchar(Sys.getenv("PIXI_PROJECT_ROOT"))) "yes" else "no (expected on system R)")

cat("\n== Project layout ==\n")
for (f in c("labs/01_CLL_MOFA.Rmd", "labs/02_CLL_DIABLO.Rmd",
            "labs/03a_TCGA_MOFA_vs_DIABLO.Rmd", "labs/03b_TCGA_your_code.Rmd",
            "data/CLL_sample_metadata.txt", "data/TCGA-BRCA.Clinical.tsv")) {
  line(if (file.exists(f)) "ok" else "FAIL", f)
}

cat("\n== Writable? (the labs write .hdf5/.rds into labs/) ==\n")
check("write into labs/", {
  t <- file.path("labs", ".write_test"); writeLines("x", t); unlink(t); "yes"
})
check("home directory free space", {
  d <- tryCatch(system("df -h ~ | tail -1 | awk '{print $4\" free\"}'", intern = TRUE),
                error = function(e) "n/a")
  d
})

cat("\n== R packages ==\n")
pkgs <- c("MOFA2", "MOFAdata", "mixOmics", "tidyverse", "data.table",
          "randomForest", "survival", "survminer", "BiocStyle", "rmarkdown",
          "reticulate", "AnnotationHub", "ensembldb", "MASS", "magick")
for (p in pkgs) {
  if (requireNamespace(p, quietly = TRUE)) line("ok", p, as.character(packageVersion(p)))
  else line("FAIL", p, "not installed")
}
line("info", ".libPaths()[1]", .libPaths()[1])

cat("\n== Python backend for MOFA2 ==\n")
# The labs call run_mofa(use_basilisk = FALSE), which needs mofapy2 importable
# from the python reticulate picks. On system R that is usually NOT the case.
if (requireNamespace("reticulate", quietly = TRUE)) {
  check("reticulate python", reticulate::py_config()$python)
  check("mofapy2 importable (basilisk = FALSE)", {
    reticulate::import("mofapy2"); "import ok"
  })
}
if (requireNamespace("basilisk", quietly = TRUE)) {
  line("info", "basilisk installed", as.character(packageVersion("basilisk")))
  line("info", "=> fallback", "use_basilisk = TRUE needs outbound internet + a per-user download")
} else {
  line("info", "basilisk", "not installed (only matters if mofapy2 is missing above)")
}

cat("\n== Network (outbound, from this server) ==\n")
reach <- function(label, url) check(label, {
  con <- url(url, open = "rb"); on.exit(close(con)); readBin(con, "raw", 16); "reachable"
})
reach("EBI precomputed CLL model", "https://ftp.ebi.ac.uk/pub/databases/mofa/cll_vignette/MOFA2_CLL.rds")
reach("Bioconductor", "https://bioconductor.org/packages/release/bioc/src/contrib/PACKAGES")
reach("AnnotationHub", "https://annotationhub.bioconductor.org/metadata/annotationhub.sqlite3")
reach("CRAN", "https://cloud.r-project.org/src/contrib/PACKAGES")

cat("\n== Data load ==\n")
if (requireNamespace("MOFAdata", quietly = TRUE))
  check("CLL_data", { utils::data("CLL_data", package = "MOFAdata", envir = environment()); "loads" })
if (requireNamespace("mixOmics", quietly = TRUE))
  check("breast.TCGA", { utils::data("breast.TCGA", package = "mixOmics", envir = environment()); "loads" })

cat("\n")
if (ok) cat("Everything the labs need is here.\n") else
  cat("Gaps found - see FAIL lines. Fix before the session, not during.\n")
