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
# Shared setup built by setup/build_shared_library.R and picked up by .Rprofile.
root <- Sys.getenv("KIMN20_SHARED_ROOT", unset = "/scratch/kimn20")
shared_lib <- file.path(root, "library",
                        paste0(R.version$major, ".", sub("\\..*", "", R.version$minor)))
line(if (dir.exists(shared_lib)) "ok" else "info", "shared library", shared_lib)
line(if (shared_lib %in% .libPaths()) "ok" else "info", "on .libPaths()?",
     if (shared_lib %in% .libPaths()) "yes" else "no (open the project, not just the folder, so .Rprofile runs)")
cat("\n")

pkgs <- c("MOFA2", "MOFAdata", "mixOmics", "tidyverse", "data.table",
          "randomForest", "survival", "survminer", "BiocStyle", "rmarkdown",
          "reticulate", "AnnotationHub", "ensembldb", "MASS")
ip   <- installed.packages()
core <- rownames(ip)[ip[, "Priority"] %in% c("base", "recommended")]  # ships with R itself
has_shared <- dir.exists(shared_lib)
for (p in pkgs) {
  if (requireNamespace(p, quietly = TRUE)) {
    from <- normalizePath(dirname(find.package(p)))
    origin <- if (has_shared && from == normalizePath(shared_lib)) "shared library"
              else if (p %in% core) "R core"
              else from
    # With a shared library present, any non-core package from elsewhere (a
    # personal or host library) is suspect: it may be a stale or unreadable copy.
    stray <- has_shared && !(p %in% core) && origin != "shared library"
    line(if (stray) "WARN" else "ok", p,
         sprintf("%s  [%s]", as.character(packageVersion(p)), origin))
  } else line("FAIL", p, "not installed")
}
line("info", ".libPaths()[1]", .libPaths()[1])
if ("BiocVersion" %in% rownames(installed.packages())) {
  line("info", "BiocVersion in use", as.character(packageVersion("BiocVersion")))
}

cat("\n== Python backend for MOFA2 ==\n")
# The labs call run_mofa(use_basilisk = FALSE), which needs mofapy2 importable
# from the Python reticulate picks. On the course server that is the shared venv
# that .Rprofile points RETICULATE_PYTHON at.
line("info", "RETICULATE_PYTHON", Sys.getenv("RETICULATE_PYTHON", unset = "(not set)"))
if (requireNamespace("reticulate", quietly = TRUE)) {
  check("reticulate python", reticulate::py_config()$python)
  check("mofapy2 importable (basilisk = FALSE)", {
    reticulate::import("mofapy2"); "import ok"
  })
} else {
  # Do not skip silently: without reticulate nobody can tell whether MOFA will run.
  line("FAIL", "reticulate", "not installed, so mofapy2 cannot be tested")
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
