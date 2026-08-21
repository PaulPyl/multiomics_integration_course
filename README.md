# KIMN20 — Multi-Omics Integration (2026)

Lecture (90 min) and computer lab on unsupervised and supervised multi-omics
integration, using **MOFA2** and **mixOmics DIABLO**.

Instructor: Paul-Theodor Pyl (NBIS / SciLifeLab)

## Layout

| Path | Contents |
|---|---|
| `lecture/` | Slide source and the small live-demo scripts used in the lecture |
| `labs/` | Student-facing labs (`*.Rmd`) and instructor versions (`*.instructor.Rmd`) |
| `data/` | Small vendored inputs — sample metadata, TCGA clinical table |
| `assessment/` | Exam questions and the script that regenerates their figures |
| `setup/` | Environment install and smoke-test scripts |

## Getting started (students)

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
| `03_TCGA_MOFA_vs_DIABLO.Rmd` | Group report: MOFA vs DIABLO on TCGA-BRCA |

Lab 3 is the assessed group exercise. Students run the code, write their own
interpretation under each result, and hand in the rendered HTML.

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
  Ignore it — tell students up front so nobody chases it mid-lab.
