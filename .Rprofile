# Keep Bioconductor packages that are not on conda in a project-local library so
# the pixi environment stays reproducible and disposable.
local({
  lib <- file.path(getwd(), ".Rlibrary")
  dir.create(lib, showWarnings = FALSE, recursive = TRUE)
  .libPaths(c(lib, .libPaths()))

  # Point reticulate at the pixi python that already carries mofapy2, so MOFA2
  # does not fall back to basilisk downloading its own environment mid-lab.
  py <- Sys.getenv("CONDA_PREFIX", unset = "")
  if (nzchar(py)) {
    bin <- if (.Platform$OS.type == "windows") file.path(py, "python.exe") else file.path(py, "bin", "python")
    if (file.exists(bin)) Sys.setenv(RETICULATE_PYTHON = bin)
  }
})
