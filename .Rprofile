# --- pixi ------------------------------------------------------------------
# The project-local library and the python interpreter are set by pixi's
# [activation.env] (R_LIBS_USER / RETICULATE_PYTHON) so that they work from any
# working directory. R only honours R_LIBS_USER if the directory exists, so
# make sure it does.
local({
  lib <- Sys.getenv("R_LIBS_USER", unset = "")
  if (nzchar(lib) && !dir.exists(lib)) dir.create(lib, recursive = TRUE, showWarnings = FALSE)
})

# --- course RStudio Server (plain system R, no pixi) -------------------------
# The server's R has none of the Bioconductor packages, and students cannot
# install them all themselves in a reasonable time, so one read-only library and
# one Python environment are built once (setup/build_shared_library.R) and added
# here. Both are skipped when absent, so this is a no-op on any other machine.
#
# Prepended, not appended: the host's own library holds a stale BiocVersion that
# would otherwise be found first and make BiocManager pick the wrong release.
local({
  if (nzchar(Sys.getenv("PIXI_PROJECT_ROOT"))) return(invisible(NULL))  # pixi manages it all

  root <- Sys.getenv("KIMN20_SHARED_ROOT", unset = "/scratch/kimn20")
  rver <- paste0(R.version$major, ".", sub("\\..*", "", R.version$minor))  # packages are per R minor version

  lib <- file.path(root, "library", rver)
  if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))

  py <- file.path(root, "venv", "bin", "python")
  if (!nzchar(Sys.getenv("RETICULATE_PYTHON")) && file.exists(py)) Sys.setenv(RETICULATE_PYTHON = py)
  invisible(NULL)
})
