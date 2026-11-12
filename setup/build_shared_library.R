#!/usr/bin/env Rscript
# Build the shared, read-only software stack for the course RStudio Server,
# without root. Run once by the instructor, from a plain terminal on the server:
#
#   nohup Rscript setup/build_shared_library.R > build.log 2>&1 &
#   tail -f build.log
#
# It produces, under KIMN20_SHARED_ROOT (default /scratch/kimn20):
#   library/<R minor version>/   every R package the labs need
#   venv/                        a Python venv containing mofapy2
# .Rprofile in the repository adds both for students automatically.
#
# Re-runnable: packages already in the library are not rebuilt. To redo just one
# part, set KIMN20_STEPS, e.g.  KIMN20_STEPS=python,perms Rscript setup/build_shared_library.R
#
# Why a venv and not basilisk: basilisk builds its Python environment into each
# user's own cache unless BASILISK_USE_SYSTEM_DIR=1 is set at install *and* run
# time, which would make every student download one. The labs call
# run_mofa(use_basilisk = FALSE), so all they need is a Python with mofapy2 that
# RETICULATE_PYTHON points at. A plain venv is not a conda env, so reticulate
# also does not need a conda binary to use it.

# ---- settings (override with environment variables) -------------------------
ROOT         <- Sys.getenv("KIMN20_SHARED_ROOT",  unset = "/scratch/kimn20")
# The Bioconductor release matching this R. If it is wrong the build stops with a
# message about the mismatch; set KIMN20_BIOC_VERSION to the right one and re-run.
BIOC_VERSION <- Sys.getenv("KIMN20_BIOC_VERSION", unset = "3.23")
NCPUS        <- as.integer(Sys.getenv("KIMN20_NCPUS", unset = "32"))
STEPS        <- strsplit(Sys.getenv("KIMN20_STEPS", unset = "r,python,perms,verify"), ",")[[1]]

# Everything the labs load, directly or as a dependency they need to be found.
PACKAGES <- c(
  # CRAN
  "rmarkdown", "knitr", "tidyverse", "data.table", "randomForest",
  "survminer", "reticulate",
  # Bioconductor
  "MOFA2", "MOFAdata", "mixOmics", "BiocStyle", "AnnotationHub", "ensembldb"
)
# A shorter list, for testing the build logic quickly.
if (nzchar(Sys.getenv("KIMN20_PACKAGES")))
  PACKAGES <- strsplit(Sys.getenv("KIMN20_PACKAGES"), ",")[[1]]

# ---- derived ---------------------------------------------------------------
rver <- paste0(R.version$major, ".", sub("\\..*", "", R.version$minor))
LIB  <- file.path(ROOT, "library", rver)
VENV <- file.path(ROOT, "venv")

say  <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")
fail <- function(...) { say("FAILED:", ...); quit(status = 1) }
run  <- function(cmd, args) {
  status <- system2(cmd, args)
  if (status != 0) fail(cmd, paste(args, collapse = " "), "(exit", status, ")")
  invisible(status)
}

say("R", R.version.string)
say("target library :", LIB)
say("target venv    :", VENV)
say("steps          :", paste(STEPS, collapse = ", "))

# Files created here must be readable by every student.
invisible(Sys.umask("022"))
dir.create(LIB, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(LIB)) fail("cannot create", LIB)

# ---- 1. R packages ---------------------------------------------------------
if ("r" %in% STEPS) {
  # LIB first and the instructor's personal library *excluded*. If it were
  # visible, install.packages() would treat anything already in it as satisfied
  # and skip it, and students (who cannot read the instructor's home) would be
  # missing those dependencies.
  .libPaths(LIB)
  say("library paths while building:"); print(.libPaths())

  options(repos = c(CRAN = "https://cloud.r-project.org"), Ncpus = NCPUS, timeout = 1200)
  Sys.setenv(MAKEFLAGS = paste0("-j", NCPUS))

  if (!dir.exists(file.path(LIB, "BiocManager")))
    install.packages("BiocManager", lib = LIB)

  # Select the Bioconductor release by putting its BiocVersion first on the path.
  # Not by passing version= to BiocManager::install(): that treats it as a version
  # *change* and refuses unless every older package it can see is upgraded first,
  # including the host's own, which cannot be written to. BiocVersion is a tiny
  # pure-R package, so it is installed straight from that release's repository.
  if (!dir.exists(file.path(LIB, "BiocVersion"))) {
    say("installing BiocVersion", BIOC_VERSION)
    install.packages("BiocVersion", lib = LIB, type = "source",
                     repos = sprintf("https://bioconductor.org/packages/%s/bioc", BIOC_VERSION))
  }
  if (!dir.exists(file.path(LIB, "BiocVersion")))
    fail("BiocVersion", BIOC_VERSION, "could not be installed; is KIMN20_BIOC_VERSION right for this R?")
  say("Bioconductor release in use:", as.character(BiocManager::version()))

  # Install the COMPLETE dependency set, not only the packages listed above.
  # install.packages() skips any dependency it can already see, and the host's own
  # library can hold copies built for a different R that look installed but crash
  # on load (e.g. vctrs, htmltools, GenomeInfoDb). So every non-core package the
  # labs need is installed here, and only what ships with R itself is left alone.
  repos <- BiocManager::repositories()
  db    <- available.packages(repos = repos, type = "source")
  deps  <- tools::package_dependencies(PACKAGES, db = db, recursive = TRUE,
                                       which = c("Depends", "Imports", "LinkingTo"))
  ip    <- installed.packages()
  core  <- rownames(ip)[ip[, "Priority"] %in% c("base", "recommended")]
  closure <- setdiff(unique(c(PACKAGES, unlist(deps, use.names = FALSE))), core)
  todo    <- setdiff(closure, rownames(installed.packages(lib.loc = LIB)))

  say(length(PACKAGES), "requested,", length(closure), "with dependencies,",
      length(todo), "still to install; this takes a while")
  if (length(todo))
    BiocManager::install(todo, lib = LIB, ask = FALSE, update = FALSE, force = TRUE, Ncpus = NCPUS)

  missing <- closure[!dir.exists(file.path(LIB, closure))]
  if (length(missing)) fail("not installed into", LIB, ":", paste(missing, collapse = ", "))
  say("R packages done")
}

# ---- 2. Python venv with mofapy2 --------------------------------------------
if ("python" %in% STEPS) {
  say("python venv")
  if (!file.exists(file.path(VENV, "bin", "python")))
    run("python3", c("-m", "venv", shQuote(VENV)))
  pip <- file.path(VENV, "bin", "pip")
  run(pip, c("install", "--quiet", "--upgrade", "pip"))
  run(pip, c("install", "--quiet", "mofapy2"))
  run(file.path(VENV, "bin", "python"),
      c("-c", shQuote("import mofapy2; print('mofapy2', mofapy2.__version__)")))
}

# ---- 3. permissions ---------------------------------------------------------
if ("perms" %in% STEPS) {
  say("permissions: world-readable, writable by nobody but the owner")
  run("chmod", c("-R", "a+rX,go-w", shQuote(ROOT)))
}

# ---- 4. verify, the way a student's session would see it ---------------------
if ("verify" %in% STEPS) {
  say("verifying")
  .libPaths(LIB)  # instructor's personal library excluded, as for a student
  ok <- TRUE
  for (p in PACKAGES) {
    v <- tryCatch({ loadNamespace(p); as.character(packageVersion(p)) },
                  error = function(e) { ok <<- FALSE; paste("FAILED:", conditionMessage(e)) })
    cat(sprintf("  %-15s %s\n", p, v))
  }
  cat(sprintf("  %-15s %s\n", "BiocVersion", tryCatch(as.character(packageVersion("BiocVersion")), error = function(e) "missing")))

  # Nothing outside R itself may have been loaded from anywhere but the shared
  # library: a stale copy in the host's library can load fine here and still
  # misbehave later.
  ip    <- installed.packages()
  core  <- rownames(ip)[ip[, "Priority"] %in% c("base", "recommended")]
  loaded <- setdiff(loadedNamespaces(), core)
  where  <- vapply(loaded, function(p) normalizePath(dirname(getNamespaceInfo(p, "path"))), character(1))
  stray  <- loaded[where != normalizePath(LIB)]
  if (length(stray)) {
    ok <- FALSE
    cat("  loaded from outside the shared library:\n")
    for (p in stray) cat(sprintf("    %-20s %s\n", p, where[[p]]))
  } else cat(sprintf("  all %d loaded non-core packages come from the shared library\n", length(loaded)))

  py <- file.path(VENV, "bin", "python")
  if (file.exists(py)) {
    Sys.setenv(RETICULATE_PYTHON = py)
    has_mofapy2 <- tryCatch(reticulate::py_module_available("mofapy2"), error = function(e) FALSE)
    cat(sprintf("  %-15s %s\n", "mofapy2 (py)", if (has_mofapy2) "importable" else "NOT importable"))
    if (!has_mofapy2) ok <- FALSE
  } else cat("  (no venv yet, Python check skipped)\n")

  if (!ok) fail("verification found problems, see above")
  say("all good. Now test as a *different* user: source('setup/check_server.R') from a student account.")
}
