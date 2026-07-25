# Run the maize yield analysis reproducibly

## Learning objectives

After completing this guide, you should be able to:

- restore and verify the local R package environment;
- run the complete analysis locally in batch mode;
- work locally in an interactive R session;
- build the project's Docker image;
- run the complete analysis non-interactively in a container; and
- enter a container for interactive shell or R work.

## Four ways to work

The same project can be used in several modes:

| Mode | Environment | Interaction | Best suited to |
|---|---|---|---|
| Local batch | Host R plus project `renv` library | Non-interactive | Repeating the full workflow |
| Local R/RStudio | Host R plus project `renv` library | Interactive | Learning, exploration, and development |
| Container batch | Image-defined R, system, and `renv` library | Non-interactive | Portable end-to-end execution |
| Container shell/R | Image-defined R, system, and `renv` library | Interactive | Inspection and controlled experiments |

All commands in this guide start from the repository root.

## Before running the analysis

### Confirm the repository

```bash
pwd
git status
```

The current directory should be `maize-yield-project`. Review unexpected Git changes before running code.

### Understand the data acquisition

The first pipeline stage downloads the FAOSTAT Crops and Livestock Products bulk archive. The archive is large, the initial run can take time, and the download URL may change.

The current repository does not contain the sample file named by the fallback path in `scripts/01-acquire-faostat-data.R`. A fresh run therefore requires a successful FAOSTAT download unless the course provides that sample separately.

Raw and processed data are ignored by Git. Do not commit the bulk dataset.

### Know the workflow

`scripts/run-all.R` runs:

```text
01 acquire data
      ↓
02 prepare maize panel
      ↓
03 create summaries and figure
      ↓
04 fit and evaluate models
      ↓
render the Quarto report, if Quarto is available
```

The acquisition script sources `scripts/00-setup.R`, so the package environment is restored and checked when the full pipeline begins.

## Method 1: Run locally in batch mode

This method uses R installed on the host and packages in the project-specific `renv` library.

### 1. Check R

```bash
R --version
```

The lockfile records R 4.3.3.

### 2. Restore the package environment

```bash
Rscript scripts/00-setup.R
```

Wait for the restore and status check to complete.

### 3. Run the complete workflow

```bash
Rscript scripts/run-all.R
```

If Quarto is on `PATH`, the script renders `reports/maize-yield-report.qmd`. Otherwise it reports that the analysis report must be rendered manually.

### 4. Inspect the outputs

```bash
ls data-processed
ls figures
ls reports
```

The expected principal outputs are:

```text
data-processed/maize-yield-panel.csv
data-processed/country-yield-summary.csv
data-processed/maize-yield-predictions.csv
data-processed/model-performance.csv
data-processed/country-model.rds
figures/maize-yield-over-time.png
reports/maize-yield-report.html
```

Generated output existing on disk does not prove that the latest run produced it. Read terminal errors and warnings and check modification times when necessary.

## Method 2: Work locally and interactively

Interactive work is useful for inspecting intermediate objects, running one stage at a time, and learning how the transformations work.

### RStudio

Open:

```text
maize-yield-project.Rproj
```

The project sets the working directory to the repository root and activates `renv` through `.Rprofile`.

In the R console:

```r
renv::status()
getwd()
.libPaths()
```

Run a script:

```r
source("scripts/02-prepare-maize-data.R", echo = TRUE)
```

Only run a later stage after its required input exists.

### Terminal R session

From the project root:

```bash
R
```

Then:

```r
renv::status()
source("scripts/03-explore-maize-data.R", echo = TRUE)
```

Exit R with:

```r
q()
```

Review whether you want to save a workspace. This project does not rely on an `.RData` workspace, and `.RData` is excluded from the Docker build.

### Run a single script non-interactively

```bash
Rscript scripts/03-explore-maize-data.R
```

The preparation output must already exist for this example.

## Method 3: Run non-interactively in Docker

This method uses the environment defined by the Dockerfile rather than the host's R installation.

### 1. Verify Docker

```bash
docker version
docker compose version
```

Docker Compose is not required for the current commands, but the version check confirms the course setup.

### 2. Build the image

```bash
docker build -t maize-yield-project .
```

The build:

1. downloads `rocker/verse:4.3.3` if necessary;
2. restores the packages recorded in `renv.lock`;
3. copies the project into `/work`; and
4. checks the environment with `renv::status()`.

The first build can take considerable time. Docker caches layers, so later builds may be faster. Changing `renv.lock` invalidates the package-restore layer. Changing only analysis code should reuse that layer.

### 3. Prepare host output directories

```bash
mkdir -p data-raw data-processed figures reports
```

These directories will be bind-mounted into the container. Files written there remain on the host after the container is removed.

### 4. Run the default container command

```bash
docker run --rm \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

The image's default command is:

```text
Rscript scripts/run-all.R
```

`--rm` removes the stopped container but not the image or files in the mounted host directories.

### Why mount only data and output directories?

The analysis code is copied into the image during `docker build`. Mounting only the input and output directories means the container executes that image snapshot while results remain accessible on the host.

If source code changes, rebuild the image:

```bash
docker build -t maize-yield-project .
```

Otherwise the container continues to run the older code stored in the existing image.

## Method 4: Work interactively in Docker

### Start a shell

```bash
docker run --rm -it \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project \
  bash
```

- `-i` keeps standard input open.
- `-t` allocates a terminal.
- `bash` overrides the image's default analysis command.

Inside the container, confirm the environment:

```bash
pwd
R --version
Rscript -e 'renv::status()'
```

The working directory should be `/work`.

Run individual stages:

```bash
Rscript scripts/02-prepare-maize-data.R
Rscript scripts/03-explore-maize-data.R
```

Start an interactive R session:

```bash
R
```

Inside R:

```r
renv::status()
maize <- readr::read_csv(
  "data-processed/maize-yield-panel.csv",
  show_col_types = FALSE
)
dplyr::glimpse(maize)
```

Exit R with `q()` and exit the shell with:

```bash
exit
```

Because the container uses `--rm`, changes outside the bind-mounted directories are discarded when it exits.

### Start interactive R directly

You can bypass the shell:

```bash
docker run --rm -it \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project \
  R
```

This is convenient when you need R but not general Linux shell tools.

## Container source code versus host source code

The current commands do **not** mount `scripts/` or the whole repository.

```text
host source --docker build--> image source --docker run--> executed source
```

This has an important consequence:

- local edits are immediately visible to local R;
- local edits are not visible in an already-built image; and
- rebuilding creates a new image layer containing those edits.

For development, it is possible to bind-mount the whole repository, but that changes the isolation model and can hide the restored project library or other image content. Use such a workflow only when the course introduces it explicitly.

## `renv` inside and outside the container

Both modes use the same `renv.lock`, but they create different physical libraries:

```text
renv.lock
   ├──restore──► host project library
   └──restore──► image project library
```

Do not mount the host `renv/library` into the container. Installed R packages can contain platform-specific binaries and links.

If you intentionally change R dependencies locally:

1. install the package in the active project;
2. test the full analysis;
3. run `renv::snapshot()`;
4. review and commit `renv.lock`; and
5. rebuild the Docker image.

## Docker Compose in this project

Docker Compose is useful for recording lengthy service configurations or coordinating an analysis with services such as a database or RStudio Server.

This repository currently has no `compose.yaml`, so these commands are not available yet:

```bash
docker compose build
docker compose run --rm analysis
```

Use the documented `docker build` and `docker run` commands. Do not invent a Compose service name or assume a missing configuration.

## Compare the execution methods

| Question | Local `renv` | Docker |
|---|---|---|
| Uses host R installation? | Yes | No |
| Uses project package versions? | Yes | Yes |
| Controls R version through project metadata alone? | Records, but does not install it | Yes, through the base image |
| Controls more system libraries and tools? | No | Yes |
| Edits immediately visible? | Yes | Only after rebuild with current commands |
| Outputs persist automatically? | Yes | Only in mounted paths or other persistent storage |
| Easy interactive IDE use? | Yes | Requires additional container/IDE configuration |

Neither method replaces data provenance, validation, tests, or interpretation.

## Troubleshooting

### Local restore fails

Read the full package installation output. Confirm the R version, internet access, package source, compiler, and system-library requirements. See [`renv-setup.md`](renv-setup.md).

### Docker build fails during `renv::restore()`

The cause may be a missing or unavailable package source, network access, or a system dependency absent from the base image. The build log immediately above the error is more informative than the final `exit code` line.

### FAOSTAT download fails

Confirm network access and the current bulk-download endpoint. The acquisition script warns that FAOSTAT URLs can change. The repository's fallback sample is not currently present in a fresh clone.

### Output files are owned by another user

On Linux, a container process running as `root` can create root-owned files in bind-mounted directories. Ask the instructor for the course's preferred user-mapping approach rather than changing permissions recursively.

### Changes made in the container disappear

This is expected for paths that are not bind-mounted. Containers started with `--rm` are removed after exit. Edit tracked project code on the host and rebuild the image.

### The report was not rendered locally

Check:

```bash
quarto --version
```

If Quarto is absent, install it or render in the container, whose `rocker/verse` base image supplies publishing tools.

## Completion checklist

- [ ] I can restore and verify the local `renv` environment.
- [ ] I can run `scripts/run-all.R` locally.
- [ ] I can explain which outputs the pipeline creates.
- [ ] I can build the `maize-yield-project` image.
- [ ] I can run the complete workflow in a temporary container.
- [ ] I can start a shell or R session inside the container.
- [ ] I understand which container paths persist on the host.
- [ ] I know when the Docker image must be rebuilt.

## Further reading

- [`renv` setup for this project](renv-setup.md)
- [Docker setup for this course](docker-setup.md)
- [Original `renv` and Docker project notes](setup-for-using-renv-with-docker.md)
- [Using `renv` with Docker](https://rstudio.github.io/renv/articles/docker.html)
- [Docker bind mounts](https://docs.docker.com/get-started/workshop/06_bind_mounts/)
