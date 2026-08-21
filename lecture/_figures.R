# Figures rendered live in slides.qmd.
#
# All maths glyphs go through plotmath (parse = TRUE / expression()), not literal
# unicode: the graphics device silently drops characters like the times sign and
# lambda from the default font, which shows up as "n .. 1" and "best .." rather
# than as an error.

suppressPackageStartupMessages({
  library(ggplot2); library(tibble); library(dplyr); library(tidyr)
  library(glmnet);  library(patchwork)
})

TEAL <- "#0d7a7a"; DARK <- "#14332e"; ACC <- "#d1552b"; MUTE <- "#9aa8a5"
GRID <- "#e8edec"; SUBT <- "#5c6b68"; AXTX <- "#7d8b88"

theme_kimn <- function(base = 17) {
  theme_minimal(base_size = base) +
    theme(
      plot.title       = element_text(face = "bold", colour = DARK, size = rel(1.0)),
      plot.subtitle    = element_text(colour = SUBT, size = rel(0.82)),
      axis.title       = element_text(colour = SUBT, size = rel(0.82)),
      axis.text        = element_text(colour = AXTX, size = rel(0.74)),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = GRID, linewidth = 0.4),
      legend.position  = "none",
      plot.background  = element_rect(fill = "transparent", colour = NA),
      panel.background = element_rect(fill = "transparent", colour = NA)
    )
}

# Shared simulated problem: 60 samples, 40 features, only 5 of them real.
# Deliberately p-close-to-n so the penalty has visible work to do.
sim_problem <- function(n = 60, p = 40, k = 5, seed = 42) {
  set.seed(seed)
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(rep(c(2.4, -1.9), length.out = k), rep(0, p - k))
  list(X = X, y = as.vector(X %*% beta + rnorm(n, 0, 1.4)), k = k)
}

# --------------------------------------------------------------------------
# 1. What "fitting a linear model" means, and the same thing as matrices.
fig_linear_model <- function() {
  set.seed(7)
  d <- tibble(x = runif(40, 0, 10)) |> mutate(y = 1.2 + 0.75 * x + rnorm(40, 0, 1.1))
  fit <- lm(y ~ x, d); d$fitted <- fitted(fit)

  p1 <- ggplot(d, aes(x, y)) +
    geom_segment(aes(xend = x, yend = fitted), colour = ACC, linewidth = 0.6, alpha = 0.85) +
    geom_point(size = 2.4, colour = DARK) +
    geom_abline(intercept = coef(fit)[1], slope = coef(fit)[2],
                colour = TEAL, linewidth = 1.3) +
    labs(title = "One feature",
         x = "a feature", y = "the outcome") +
    theme_kimn()

  rect <- function(x0, y0, w, h, fill, lab, sz = 6.5) list(
    annotate("rect", xmin = x0, xmax = x0 + w, ymin = y0, ymax = y0 + h,
             fill = fill, colour = DARK, linewidth = 0.5),
    annotate("text", x = x0 + w/2, y = y0 + h/2, label = lab,
             size = sz, colour = DARK, fontface = "bold")
  )
  dim_lab <- function(x, y, lab) annotate("text", x = x, y = y, label = lab,
                                          parse = TRUE, size = 3.9, colour = AXTX)

  p2 <- ggplot() +
    rect(0.0, 0.0, 0.62, 3.0, "#dfeae8", "y") +
    annotate("text", x = 0.95, y = 1.5, label = "phantom(0) %~~% phantom(0)",
             parse = TRUE, size = 7, colour = DARK) +
    rect(1.30, 0.0, 2.40, 3.0, "#eaf1f0", "X") +
    annotate("text", x = 3.92, y = 1.5, label = "phantom(0) %*% phantom(0)",
             parse = TRUE, size = 6, colour = DARK) +
    rect(4.20, 1.05, 0.62, 0.9, "#f6ded4", "b") +
    dim_lab(0.31, 3.28, "n %*% 1") +
    dim_lab(2.50, 3.28, "n %*% p") +
    dim_lab(4.51, 2.25, "p %*% 1") +
    annotate("text", x = 4.51, y = 0.72, label = "one weight\nper feature",
             size = 4.0, colour = ACC, fontface = "bold", lineheight = 0.95) +
    coord_cartesian(xlim = c(-0.15, 5.4), ylim = c(-0.2, 3.7)) +
    labs(title = "Many features at once") +
    theme_void(base_size = 15) +
    theme(plot.title = element_text(face = "bold", colour = DARK, hjust = 0),
          plot.background = element_rect(fill = "transparent", colour = NA))

  p1 | p2
}

# --------------------------------------------------------------------------
# 2. LASSO: grow the penalty and weights snap to exactly zero.
fig_lasso_paths <- function() {
  s <- sim_problem()
  f <- glmnet(s$X, s$y, alpha = 1)

  paths <- as_tibble(t(as.matrix(f$beta))) |>
    mutate(loglam = log(f$lambda)) |>
    pivot_longer(-loglam, names_to = "var", values_to = "coef") |>
    mutate(real = as.integer(sub("V", "", var)) <= s$k)

  p1 <- ggplot(paths, aes(loglam, coef, group = var)) +
    geom_hline(yintercept = 0, colour = "#c3cecc", linewidth = 0.5) +
    geom_line(data = ~ filter(.x, !real), colour = MUTE, linewidth = 0.45, alpha = 0.75) +
    geom_line(data = ~ filter(.x, real),  colour = ACC,  linewidth = 1.15) +
    labs(title = "Every feature's weight",
         x = expression(log(lambda)), y = "weight") +
    theme_kimn()

  p2 <- ggplot(tibble(loglam = log(f$lambda), nzero = f$df), aes(loglam, nzero)) +
    geom_hline(yintercept = s$k, linetype = "dashed", colour = ACC, linewidth = 0.6) +
    geom_step(colour = TEAL, linewidth = 1.1) +
    annotate("text", x = -5.6, y = s$k + 3.4, label = "the 5 real ones",
             colour = ACC, size = 3.9, hjust = 0, fontface = "bold") +
    labs(title = "How many survive",
         x = expression(log(lambda)), y = "non-zero weights") +
    theme_kimn()

  p1 | p2
}

# --------------------------------------------------------------------------
# 3. Choosing the penalty: cross-validation, and a grid when there is >1 knob.
fig_choosing_lambda <- function() {
  s  <- sim_problem()
  set.seed(11)
  cv <- cv.glmnet(s$X, s$y, alpha = 1, nfolds = 10)

  d <- tibble(loglam = log(cv$lambda), m = cv$cvm, lo = cv$cvlo, hi = cv$cvup)
  best <- log(cv$lambda.min)

  p1 <- ggplot(d, aes(loglam, m)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = TEAL, alpha = 0.15) +
    geom_line(colour = TEAL, linewidth = 1.1) +
    geom_vline(xintercept = best, linetype = "dashed", colour = ACC, linewidth = 0.7) +
    annotate("text", x = best + 0.25, y = max(d$hi) * 0.93, label = "best~lambda",
             parse = TRUE, colour = ACC, size = 4.4, hjust = 0, fontface = "bold") +
    labs(title = "One knob: cross-validate",
         x = expression(log(lambda)), y = "held-out error") +
    theme_kimn()

  gd <- expand_grid(b1 = 1:10, b2 = 1:10) |>
    mutate(score = exp(-((b1 - 5)^2 + (b2 - 7)^2) / 12))
  p2 <- ggplot(gd, aes(b1, b2, fill = score)) +
    geom_tile(colour = "white", linewidth = 0.7) +
    geom_point(data = ~ filter(.x, score == max(score)),
               shape = 21, size = 9, stroke = 2.4, fill = NA, colour = ACC) +
    scale_fill_gradient(low = "#f2f6f5", high = TEAL) +
    scale_x_continuous(breaks = c(1, 5, 10)) +
    scale_y_continuous(breaks = c(1, 7, 10)) +
    coord_equal() +
    labs(title = "Two knobs: a grid",
         x = "features kept, omic 1", y = "features kept, omic 2") +
    theme_kimn()

  p1 + p2 + plot_layout(widths = c(1.35, 1))
}

# --------------------------------------------------------------------------
# 4. Why the seed matters: a bumpy objective and four starting points.
fig_local_optima <- function() {
  f  <- function(x) 0.55 * sin(2.4 * x) + 0.30 * sin(5.1 * x + 1) + 0.05 * (x - 4)^2
  df <- function(x) 0.55 * 2.4 * cos(2.4 * x) + 0.30 * 5.1 * cos(5.1 * x + 1) + 0.10 * (x - 4)

  curve <- tibble(x = seq(0, 8, length.out = 900)) |> mutate(y = f(x))
  descend <- function(x0, steps = 220, eta = 0.045) {
    x <- x0; for (i in seq_len(steps)) x <- x - eta * df(x); x
  }
  starts <- c(0.6, 2.7, 5.0, 7.4)
  pts <- tibble(start = starts, end = vapply(starts, descend, numeric(1))) |>
    mutate(ys = f(start), ye = f(end))
  gmin <- curve |> slice_min(y, n = 1)

  ggplot(curve, aes(x, y)) +
    geom_line(colour = DARK, linewidth = 1.1) +
    geom_segment(data = pts, aes(x = start, y = ys, xend = end, yend = ye),
                 arrow = arrow(length = unit(0.2, "cm"), type = "closed"),
                 colour = "#7f8f8c", linewidth = 0.7, inherit.aes = FALSE) +
    geom_point(data = pts, aes(start, ys), size = 3.0, colour = MUTE, inherit.aes = FALSE) +
    geom_point(data = pts, aes(end, ye), size = 3.6, colour = ACC, inherit.aes = FALSE) +
    geom_point(data = gmin, size = 5.4, shape = 21, stroke = 1.7, fill = NA, colour = TEAL) +
    annotate("text", x = gmin$x, y = gmin$y - 0.32, label = "global optimum",
             colour = TEAL, size = 4.3, fontface = "bold") +
    labs(title = "Four starts, four answers",
         x = "parameters", y = "objective (lower is better)") +
    theme_kimn()
}
