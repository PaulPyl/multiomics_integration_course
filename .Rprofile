# The project-local library and the python interpreter are set by pixi's
# [activation.env] (R_LIBS_USER / RETICULATE_PYTHON) so that they work from any
# working directory. R only honours R_LIBS_USER if the directory exists, so
# make sure it does.
local({
  lib <- Sys.getenv("R_LIBS_USER", unset = "")
  if (nzchar(lib) && !dir.exists(lib)) dir.create(lib, recursive = TRUE, showWarnings = FALSE)
})
