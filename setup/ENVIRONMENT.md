# How the environments are set up, and why

Two ways of running the labs are supported. Both give the same R packages and the
same `mofapy2`; they differ in who installs them.

| | Where | Packages come from | Set up by |
|---|---|---|---|
| **pixi** | a laptop, or any machine you control | `pixi.toml` / `pixi.lock` | each user, with `pixi run setup` |
| **Shared library** | the course RStudio Server (plain system R) | one read-only library | the instructor, once, without root |

`pixi run check` verifies the first; `source("setup/check_server.R")` in R verifies
the second.

## pixi

`pixi.toml` pins R 4.5 and the conda packages; `pixi run setup` installs the two
packages that are not on conda (`MOFA2`, `MOFAdata`) from Bioconductor into
`.Rlibrary/`. Platforms are macOS and Linux only: bioconda publishes no Windows
builds, so Windows users need WSL2 or the server.

Three details in `pixi.toml` look odd and each prevents a real failure:

- **`micromamba` is a dependency** although nothing calls it. reticulate treats
  any Python inside a conda-style environment as a conda env and runs `conda run`
  to compute its `PATH`. With no conda on the machine that fails, reticulate
  silently drops `RETICULATE_PYTHON` for a scratch Python without `mofapy2`, and
  `run_mofa()` then reports "mofapy2 is not detected". reticulate accepts
  micromamba as the conda binary, so shipping it fixes this.
- **`R_LIBS_SITE` is set to empty.** Some hosts export it (RStudio Server's
  terminal does), pointing at the system R's libraries. pixi's R would then search
  another R's packages ahead of its own, and a stale `BiocVersion` there made
  `BiocManager` choose the wrong Bioconductor release.
- **`mofapy2` and `python` are installed directly**, so `run_mofa()` can use
  `use_basilisk = FALSE` and nothing is downloaded during a lab.

`pixi run check` fails if `.libPaths()` contains anything outside the project, or
if reticulate is not using the project's Python.

## Shared library on a plain-R server

RStudio Server uses the server's system R, which cannot be switched to pixi's R
without administrator settings. So the packages are built once into a read-only
directory that every student's session adds to its library path.

Default location: `/scratch/kimn20` (change it with `KIMN20_SHARED_ROOT`).

```
/scratch/kimn20/
  library/<R minor version>/   R packages, e.g. library/4.6/
  venv/                        Python venv containing mofapy2
```

### Building it

From a plain terminal on the server (not inside pixi), as the instructor:

```bash
nohup Rscript setup/build_shared_library.R > build.log 2>&1 &
tail -f build.log
```

It takes a while, since everything compiles from source. Re-running skips what is
already installed. To redo one part, set `KIMN20_STEPS` (any of `r`, `python`,
`perms`, `verify`):

```bash
KIMN20_STEPS=python,perms Rscript setup/build_shared_library.R
```

`KIMN20_BIOC_VERSION` selects the Bioconductor release. If it does not match the
R version, the build stops with a message about the mismatch.

### How students pick it up

The project's `.Rprofile` prepends `library/<R minor version>/` to `.libPaths()`
and sets `RETICULATE_PYTHON` to `venv/bin/python`. It does nothing under pixi or
when those paths do not exist, so it is harmless on a laptop. It only runs when
the folder is opened as an RStudio *project*.

### Design choices

- **Prepended, not appended.** The system library can hold an older
  `BiocVersion` that would otherwise be found first.
- **The Bioconductor release is chosen by installing `BiocVersion` first**, not by
  passing `version =` to `BiocManager::install()`. With a package list,
  `version =` is treated as a version *change* and refused until every older
  package `BiocManager` can see has been upgraded, including the host's own, which
  cannot be written to. `BiocVersion` is installed straight from that release's
  repository into the shared library, where it is found first.
- **Every dependency is installed, not just the listed packages.** The host's own
  library can contain copies built for a different R (seen: `vctrs`, `htmltools`,
  `GenomeInfoDb`). They look installed, so `install.packages` skips them as
  already-satisfied dependencies, and then they crash on load (`undefined symbol:
  SETLENGTH`) or lack newer classes. The build therefore computes the full
  dependency closure and installs all of it, leaving alone only the packages that
  ship with R itself. The `verify` step then checks that nothing outside R's core
  was loaded from anywhere but the shared library.
- **The instructor's own library is excluded while building.** `install.packages`
  treats anything it can already see as satisfied. A dependency sitting in a
  personal library would be skipped, and students could not read it.
- **A venv, not basilisk.** basilisk builds its Python environment into each
  user's own cache unless `BASILISK_USE_SYSTEM_DIR=1` is set at install and at run
  time, so every student would download one. A plain venv is also not a conda
  env, so reticulate needs no conda binary to use it.
- **One library per R minor version.** Compiled packages do not survive an R
  upgrade; after one, run the build again and a new directory appears.
- **Permissions.** The build sets everything world-readable and writable only by
  the owner. Put `ROOT` somewhere only you can modify: if the parent directory is
  world-writable without the sticky bit, anyone can rename the directory.

### Checking it

The instructor's own account proves little. From a *different* account, open the
project and run:

```r
source("setup/check_server.R")
```

Each package line shows where it was found: `shared library` or `R core`. A
`WARN` means a non-core package came from somewhere else.

Two checks need no second account and catch most problems. Run them from the
repository root:

```bash
# The check with the instructor's personal library removed, as a student sees it.
R_LIBS_USER=/nonexistent Rscript -e 'source("setup/check_server.R")' 2>&1 | grep -E "FAIL|WARN|Everything|Gaps"

# Files under the shared folder that other users cannot read or enter (want no output).
find /scratch/kimn20 ! -perm -o=r | head
find /scratch/kimn20 -type d ! -perm -o=x | head
```

These do not replace a real test from another account, since they cannot show a
mount, ACL or SELinux restriction.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Bioconductor version '3.xx' requires R version ...` | A stale `BiocVersion` from another library is visible. Check `.libPaths()`; under pixi `pixi run check` reports this. |
| `mofapy2 ... is not detected` | reticulate is not using the intended Python. Run `reticulate::py_config()`; the path should be under `.pixi/` (pixi) or `venv/` (shared). |
| `undefined symbol: SETLENGTH` (or similar) while building or loading | A package built for an older R is being picked up from the host's library. The build avoids this by installing the whole dependency set; if it appears, delete the shared library for that R version and rebuild. |
| `class "..." is not exported by 'namespace:...'` | A stale Bioconductor package from another library is shadowing the right one. Same remedy. |
| `uv.h: No such file or directory`, then `configuration failed for package 'fs'` | The libuv headers (a `-devel` package) are not installed. The build sets `USE_BUNDLED_LIBUV=1` so `fs` compiles its own copy. `sass`, `bslib`, `rmarkdown` and `tidyverse` all fail as a cascade when `fs` does. |
| A long list of packages "not installed" at the end of a build | Usually victims of one or two root failures. `grep -E '^ERROR: (configuration\|compilation) failed' build.log` shows the causes. |
| Students see no packages | The folder was opened without the project, so `.Rprofile` did not run; or the shared directory is not readable by them. |
| A package is "not installed" for students only | It was present only in the instructor's personal library, which is why the build excludes that library. |
