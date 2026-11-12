# KIMN20 — Multi-Omics Integration (2026)

Lecture (90 min) and computer lab on unsupervised and supervised multi-omics
integration, using **MOFA2** and **mixOmics DIABLO**.

Instructor: Paul-Theodor Pyl (NBIS / SciLifeLab)

## Layout

| Path | Contents |
|---|---|
| `lecture/` | Slide source and the small live-demo scripts used in the lecture |
| `labs/` | The labs, as R Markdown documents |
| `data/` | Small vendored inputs — sample metadata, TCGA clinical table |
| `setup/` | Environment install and smoke-test scripts |

## Getting started

### On the course RStudio Server

1. **File → New Project → Version Control → Git**, and paste this repository's URL.
   Open it as a *project* (not just the folder): the project's `.Rprofile` is what
   adds the course's shared R packages and Python.
2. In the console, run `source("setup/check_server.R")`. Every line should be `ok`;
   if one says `FAIL`, tell us before the session rather than during it.

(For whoever runs the server, and for how both environments are set up and why,
see [`setup/ENVIRONMENT.md`](setup/ENVIRONMENT.md).)

### On your own machine

Install [pixi](https://pixi.sh), then:

```bash
pixi run setup   # one-time: fetches MOFA2 from Bioconductor
pixi run check   # verifies every package and dataset the labs need
```

`pixi run check` must print `Environment looks good.` before the lab. If it does
not, ask before the session rather than during it.

To work in RStudio with this environment:

```bash
pixi run rstudio
```

## Labs

| Lab | Topic |
|---|---|
| `01_CLL_MOFA.Rmd` | MOFA2 walkthrough on the CLL cohort (4 omics, N=200) |
| `02_CLL_DIABLO.Rmd` | The same cohort with mixOmics `block.(s)plsda` |
| `03a_TCGA_MOFA_vs_DIABLO.Rmd` | MOFA vs DIABLO on TCGA-BRCA — run and interpret |
| `03b_TCGA_your_code.Rmd` | **Students write the code themselves** |

`03a` is the run-and-comment report: students execute the document, write their
own interpretation under each result, and hand in the rendered HTML.

`03b` is where you stop following along and write the code yourself. Two
open-ended tasks — characterise a factor against a clinical covariate your group
picks, then drop a modality and ask whether integrating three omics was worth it.
There is no single right answer, and different groups will get different results.

## Lecture

```bash
pixi run slides
```

Renders `lecture/slides.qmd` to a single self-contained `lecture/slides.html`
(reveal.js). Open it directly in a browser — no server needed. Speaker notes are
in `::: notes` blocks; press `s` in the browser for the speaker view.

18 slides for a 90-minute session, with three scheduled question pauses marked
in the notes.

### Windows

`pixi.toml` targets macOS (Intel + Apple Silicon) and Linux only. This is not an
oversight: **bioconda publishes no `win-64` builds**, so `mixOmics`, `MOFAdata`
and friends simply cannot be solved for native Windows. Windows students should
use **WSL2** (Ubuntu, then pixi inside it) or a course-provided server.

## Environment notes

- R and everything on conda comes from `pixi.toml` (`conda-forge` + `bioconda`).
- **MOFA2 is not on bioconda**, so `pixi run setup` installs it from
  Bioconductor into a project-local `.Rlibrary/` (gitignored).
- `.Rprofile` points `reticulate` at the pixi python, which already carries
  `mofapy2`. That means `run_mofa()` should be called with
  `use_basilisk = FALSE` — basilisk would otherwise download a second python
  environment mid-lab, which is slow and fails behind restrictive networks.
  Verified: MOFA trains to convergence this way on the TCGA-BRCA lab data.
- Expect one harmless warning during `run_mofa()`: MOFA2 hard-codes 0.7.3 as the
  newest `mofapy2` and the environment ships 0.7.4, so it suggests upgrading.
  It is harmless: ignore it.
