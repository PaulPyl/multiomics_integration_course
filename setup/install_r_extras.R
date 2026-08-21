#!/usr/bin/env Rscript
# Packages the labs need that are not available on conda-forge/bioconda.
# Run once per checkout with: pixi run setup

lib <- Sys.getenv("R_LIBS_USER", unset = "")
if (!nzchar(lib)) stop("R_LIBS_USER is not set - run this through `pixi run setup`.")
dir.create(lib, showWarnings = FALSE, recursive = TRUE)
.libPaths(c(lib, .libPaths()))

needed <- c(
  # Not published on bioconda at all (as of 2026-08).
  MOFA2 = "bioc",
  # On bioconda only as a post-link-script data package, which pixi skips by
  # default -- so install it here rather than via pixi.
  MOFAdata = "bioc"
)

for (pkg in names(needed)) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("[ok]   %s already available (%s)", pkg, packageVersion(pkg)))
    next
  }
  message(sprintf("[inst] %s from %s ...", pkg, needed[[pkg]]))
  if (needed[[pkg]] == "bioc") {
    BiocManager::install(pkg, lib = lib, ask = FALSE, update = FALSE)
  } else {
    install.packages(pkg, lib = lib, repos = "https://cloud.r-project.org")
  }
}

message("\nDone. Verify with: pixi run check")
