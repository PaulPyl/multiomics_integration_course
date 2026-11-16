# Helpers shared by the lab documents. Source from a setup chunk:
#
#   source("../setup/knitr_helpers.R")
#
# Adds one chunk option, `summary`. A chunk with it has its printed output wrapped
# in a collapsed <details> block, so a long training log does not push the results
# off the screen but is still one click away:
#
#   ```{r, summary = "MOFA training log"}
#   MOFAobject <- run_mofa(MOFAobject, ...)
#   ```

local({
  default <- knitr::knit_hooks$get("output")
  knitr::knit_hooks$set(output = function(x, options) {
    out <- default(x, options)
    if (is.null(options$summary)) return(out)
    # Blank lines matter: pandoc only renders the markdown inside <details> if
    # the tags sit in their own paragraphs.
    paste0("\n<details><summary>", options$summary, "</summary>\n\n",
           out, "\n</details>\n\n")
  })
})

# MOFA's training log is printed by Python, which bypasses both R's own output
# capture and knitr's, so it never reaches the document (it only shows in the
# console). This captures it at the Python level and prints it as ordinary output,
# so that a chunk's `summary` option can fold it away:
#
#   ```{r, summary = "MOFA training log"}
#   show_python_output(
#     MOFAobject <- run_mofa(MOFAobject, outfile = "model.hdf5", use_basilisk = FALSE)
#   )
#   ```
#
# The assignment still happens in the calling environment.
show_python_output <- function(expr) {
  out <- reticulate::py_capture_output(expr)
  cat(out)
  invisible(NULL)
}

# As above, but discards the log. For loops that fit many models.
quiet_python_output <- function(expr) {
  invisible(reticulate::py_capture_output(expr))
}
