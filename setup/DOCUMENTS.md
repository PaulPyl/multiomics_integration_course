# Features of the lab documents

Shared by all four labs. Two files in `setup/` provide them; each lab includes
them from its header and its `setup` chunk.

## Click-to-enlarge figures

`setup/lightbox.html` is included from the YAML header:

```yaml
output:
  BiocStyle::html_document:
    includes:
      in_header: ../setup/lightbox.html
```

Click a figure to enlarge it; click again or press Esc to close. It is a small
self-contained script with no external dependencies, so it works offline. Images
narrower than 200 px (icons, logos) and anything in the table of contents are
left alone. Quarto has this built in (`lightbox: true`); R Markdown does not.

## Folding long output

`setup/knitr_helpers.R` adds a chunk option, `summary`. A chunk that has it gets
its printed output wrapped in a collapsed block with that text as the heading:

````markdown
```{r, summary = "MOFA training log"}
...
```
````

A chunk with no printed output produces nothing, so no empty block appears.

## MOFA's training log

The log is printed by Python, not R. That bypasses both R's output capture and
knitr's, so `capture.output()` does nothing to it, and it never reaches the
rendered document: it only appears in the console. Two helpers in
`knitr_helpers.R` capture it at the Python level with `reticulate::py_capture_output()`:

- `show_python_output(expr)` prints the captured log as ordinary output, so a
  chunk's `summary` option can fold it. Used where `run_mofa()` is called directly
  (labs 01 and 03a).
- `quiet_python_output(expr)` discards it. Used inside `fit_mofa()` in lab 03b,
  where task 2 fits seven models.

The assignment inside the call still happens in the calling environment:

```r
show_python_output(
  MOFAobject <- run_mofa(MOFAobject, outfile = "model.hdf5", use_basilisk = FALSE)
)
```

## Paths

The instructor documents live one level deeper, in `instructor/labs/`, so they
refer to these files as `../../setup/...`.
