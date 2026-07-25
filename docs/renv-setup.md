# Set up and use `renv`

## Learning objectives

After completing this guide, you should be able to:

- explain the files that make an `renv` project portable;
- restore the maize yield project's R package library;
- check whether the library and lockfile are synchronized;
- add or update a package deliberately; and
- share an environment change safely through Git.

## What `renv` manages

`renv` creates a private R package library for each project. This allows two projects on the same computer to use different package versions.

The principal files are:

| Path | Purpose | Commit to Git? |
|---|---|---:|
| `.Rprofile` | Activates `renv` when R starts in the project | Yes |
| `renv.lock` | Records R and package versions and package sources | Yes |
| `renv/activate.R` | Bootstraps and activates `renv` | Yes |
| `renv/settings.json` | Stores project-level `renv` settings | Yes |
| `renv/library/` | Contains installed packages for this machine | No |

The project library is excluded because it is large and platform-specific. Another student recreates it from the tracked metadata.

## This repository is already initialized

Do **not** run `renv::init()` for the maize yield repository. It already contains the required metadata and a lockfile pinned to R 4.3.3.

For a fresh clone, your task is to **restore** that recorded environment:

```text
tracked renv.lock ──renv::restore()──► local project library
```

`renv::init()` is discussed later for use in a new project.

## 1. Install R

Install R 4.3.3 if the course environment requires an exact match. Check the active version:

```bash
R --version
```

From inside R, check:

```r
R.version.string
```

`renv` records the R version but does not install or switch R itself. A different R version may still restore successfully, but it no longer recreates the environment as closely and package binaries may differ.

## 2. Open the project correctly

Start from the repository root—the directory containing `renv.lock`:

```bash
cd maize-yield-project
pwd
```

You can then:

- open `maize-yield-project.Rproj` in RStudio;
- start R by running `R`; or
- execute an R script with `Rscript`.

When R starts in this directory, `.Rprofile` sources `renv/activate.R`. On a fresh machine, the activation script can bootstrap the version of `renv` required by the project.

Check that `renv` is active:

```r
renv::project()
.libPaths()
```

The first library path should refer to this project's `renv/library` directory.

## 3. Restore the recorded environment

The repository provides a setup script:

```bash
Rscript scripts/00-setup.R
```

The script:

1. confirms that `renv.lock` exists;
2. installs `renv` if it is unavailable;
3. runs `renv::restore()` without an interactive prompt; and
4. checks `renv::status()`.

The first restore downloads and installs many packages and can take time. It requires internet access and may require compilers or system libraries if binary packages are unavailable.

Alternatively, from an R session in the project:

```r
renv::restore()
renv::status()
```

Read the proposed package actions before accepting an interactive restore.

## 4. Verify the environment

Run:

```r
renv::status()
```

A synchronized project has agreement among:

- packages used by the project;
- packages installed in the project library; and
- packages recorded in `renv.lock`.

You can inspect selected versions:

```r
R.version.string
packageVersion("renv")
packageVersion("dplyr")
```

Do not compare only the package count. Exact versions and sources matter.

## The everyday `renv` workflow

### Use the existing environment

Normally, start R in the project and work as usual:

```r
library(dplyr)
library(ggplot2)
```

Because `renv` is active, R loads packages from the project library.

### Add a package

Install into the active project library:

```r
renv::install("package-name")
```

You can also use `install.packages("package-name")` while `renv` is active. `renv::install()` makes the project context explicit.

Use the package in project code and verify that the analysis still works.

### Record the new environment

Check what changed:

```r
renv::status()
renv::snapshot()
renv::status()
```

`renv::snapshot()` updates `renv.lock` to describe the packages used by the project. Review the proposed changes rather than accepting a surprising lockfile update.

Outside R, inspect and commit the metadata:

```bash
git status
git diff -- renv.lock
git add renv.lock
git commit -m "Record package-name dependency"
git push
```

If `renv` intentionally changed another tracked metadata file, review and stage that file too.

### Receive an environment update

After pulling a collaborator's changed lockfile:

```bash
git pull --no-rebase origin main
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript -e 'renv::status()'
```

Restoring changes the local package library. It should not rewrite the lockfile.

## `snapshot()` and `restore()` point in opposite directions

This distinction is essential:

```text
project library ──snapshot──► renv.lock
project library ◄──restore─── renv.lock
```

- Use `snapshot()` after intentionally changing packages and testing the code.
- Use `restore()` after cloning the project or receiving a changed lockfile.

Running `snapshot()` when you meant `restore()` can record unintended local versions. Always inspect `renv::status()` first.

## Updating packages

Package updates should be deliberate:

```r
renv::update("package-name")
```

Then:

1. run the complete analysis and relevant tests;
2. inspect warnings and outputs;
3. run `renv::snapshot()`;
4. review the `renv.lock` diff; and
5. commit the code and lockfile changes together when appropriate.

Do not update every package immediately before a deadline merely because newer versions exist. A lockfile is useful precisely because updates become explicit project changes.

## Initialize `renv` in a different project

For a new R project that does not already use `renv`:

```r
install.packages("renv", repos = "https://cloud.r-project.org")
renv::init()
```

After initialization:

```r
renv::status()
renv::snapshot()
```

Commit `.Rprofile`, `renv.lock`, `renv/activate.R`, and
`renv/settings.json`. Do not commit `renv/library/`.

This initialization procedure is **not** required for the maize yield project.

## How this project uses `renv`

The project has an implicit snapshot setting. `renv` discovers dependencies in the project files and records the packages required by those dependencies.

The Docker build also restores from the same lockfile:

```dockerfile
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
RUN Rscript -e 'renv::restore(prompt = FALSE)'
```

This allows local execution and container execution to share the same R package specification.

## Troubleshooting

### The project library is not synchronized

Start with:

```r
renv::status()
```

Read whether packages are missing, installed at different versions, or used in code but absent from the lockfile. Do not choose `snapshot()` or `restore()` until you understand which state is intended.

### A package fails to compile

The host may lack a compiler or system library. Read the complete installation message. On Linux, `renv::sysreqs()` can help report system requirements:

```r
renv::sysreqs()
```

Ask the instructor before installing system packages on a managed computer. Docker may provide a more consistent alternative.

### R is loading packages from the wrong library

Confirm that R was started from the project root:

```r
getwd()
renv::project()
.libPaths()
```

Close R, navigate to the repository root, and start a new session.

### Restore cannot download a package

Check internet access, proxy settings, and the package source recorded in `renv.lock`. A lockfile records where a package should come from, but it cannot guarantee that the source remains available forever.

### You see unexpected lockfile changes

Do not commit them automatically. Inspect:

```bash
git diff -- renv.lock
```

If the changes are not intentional, use `renv::restore()` to return the project library to the recorded state. Ask for help before discarding work.

## Completion checklist

- [ ] I started R from the repository root.
- [ ] `.libPaths()` shows a project library.
- [ ] `renv::status()` reports a synchronized environment.
- [ ] I can explain the difference between `snapshot()` and `restore()`.
- [ ] I know which `renv` files belong in Git.
- [ ] I do not commit `renv/library/`.

## Further reading

- [`renv` workflow](https://rstudio.github.io/renv/)
- [Introduction to `renv`](https://rstudio.github.io/renv/articles/renv)
- [`renv` function reference](https://rstudio.github.io/renv/reference/index.html)
- [Using `renv` with Docker](https://rstudio.github.io/renv/articles/docker.html)
