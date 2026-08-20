# Reproducible-environment implementation

This document describes how the maize-yield project implements reproducible execution with `renv` and Docker. Conceptual explanations, installation guides, and learner exercises belong in the parent learning module.

## Environment layers

The project records two related layers:

```text
Docker image
  R 4.3.3 + system tools + Quarto
        ↓
renv project library
  recorded R packages and versions
        ↓
project scripts
  acquisition, preparation, exploration, modeling, report
```

`renv` manages the R package library. Docker records a broader execution image. Neither records the current external FAOSTAT contents or guarantees scientifically valid results.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `.Rprofile` | Activates the project `renv` environment |
| `renv.lock` | Records R 4.3.3, CRAN, and package versions |
| `renv/activate.R` | Bootstraps and activates `renv` |
| `renv/settings.json` | Records project `renv` behavior |
| `scripts/setup.R` | Restores and verifies the local package environment |
| `scripts/functions.R` | Checks project context/packages and creates output directories |
| `Dockerfile` | Builds the broader container environment |
| `.dockerignore` | Keeps local state, data, outputs, and secrets out of the image |

The project library and cache are intentionally not tracked.

## Fresh local setup

Requirements:

- R compatible with the lockfile (R 4.3.3 is recorded);
- network access to the recorded package repository for first restore;
- Quarto for automatic report rendering.

Run from the project root:

```bash
Rscript scripts/setup.R
```

The setup script:

1. checks that the command is running in the project root;
2. creates the `data/`, `results/`, `figures/`, and `reports/` directories when absent;
3. installs `renv` when it is not already available;
4. restores the versions in `renv.lock`;
5. checks that the project is synchronized with the lockfile;
6. verifies packages required by the analysis scripts.

The script stops with a clear error when the environment remains incomplete.

## Run locally

After setup:

```bash
Rscript scripts/run-all.R
```

`run-all.R` verifies project context, directories, and packages before starting. It then runs the workflow stages in their documented order and renders the Quarto reports when Quarto is available.

Individual stages can be run in order:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/integrate-data.R
Rscript scripts/explore-maize-data.R
Rscript scripts/model-maize-yield.R
```

Each stage creates required directories and checks its package subset. It still expects outputs from preceding stages.

## Check the local environment

Inside R:

```r
renv::status()
sessionInfo()
```

From the shell:

```bash
Rscript -e 'renv::status()'
Rscript --vanilla -e \
  'files <- list.files("scripts", pattern = "[.]R$", full.names = TRUE); lapply(files, parse)'
quarto check
```

`--vanilla` is appropriate for syntax parsing because parsing does not require the project library. Do not use it when the goal is to run the analysis inside the activated `renv` environment.

## Updating R dependencies

Package changes should be explicit:

```r
renv::install("package-name")
renv::snapshot()
renv::status()
```

Review the lockfile diff before committing:

```bash
git diff -- renv.lock
```

Another contributor receives the change with:

```bash
git pull
Rscript scripts/setup.R
```

Do not run `snapshot()` merely to remove a warning. Confirm that the resulting lockfile represents the packages actually required by the project.

## Docker build

Build from the project root:

```bash
docker build -t maize-yield-project .
```

The Dockerfile:

1. starts from `rocker/verse:4.3.3`;
2. sets `/work` as the working directory;
3. copies dependency metadata before source code for layer caching;
4. restores `renv.lock`;
5. copies the filtered project context;
6. checks `renv` synchronization;
7. parses all R scripts during the build;
8. uses `Rscript scripts/run-all.R` as the default command.

`.dockerignore` prevents `.env`, Git state, local R state, complete source downloads, derived data, generated results, rendered outputs, partial downloads, and the local `renv` library from entering the image. The two fixed files in `data/input/` remain in the image for offline execution.

## Docker run and persistence

Create host directories explicitly so their ownership and location are clear:

```bash
mkdir -p data/source data/input data/derived results/tables results/models figures reports
```

Run:

```bash
docker run --rm \
  -v "$(pwd)/data:/work/data" \
  -v "$(pwd)/results:/work/results" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

The container is disposable. Bind mounts preserve downloaded data and generated outputs on the host. Mounting `reports/` also supplies the tracked Quarto source from the host, so run this command from a complete project checkout.

For an interactive shell:

```bash
docker run --rm -it \
  -v "$(pwd)/data:/work/data" \
  -v "$(pwd)/results:/work/results" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project bash
```

## Acquisition behavior

The acquisition stage downloads a large external FAOSTAT archive. It writes to a `.part` file and only moves a completed download into place.

If downloading or extraction fails, the script uses the course sample only when this file exists:

```text
data/input/faostat-maize-yield-sample.csv
```

The sample is tracked so that the workflow remains available without a network connection. Maintainers can regenerate it from the bulk input with `Rscript scripts/create-faostat-data-teaching-sample.R`. When neither source is available, the acquisition script stops and reports both recovery options; it does not claim success after a failed fallback.

External data are outside the guarantees of `renv` and Docker. The data-management and data-acquisition documentation records endpoints, access dates, releases, checksums, and licence/citation information for the tracked teaching snapshots.

## Troubleshooting

### Run from the wrong directory

Run commands from the directory containing `renv.lock`, `scripts/`, and `maize-yield-project.Rproj`.

### Missing package error

Run:

```bash
Rscript scripts/setup.R
```

Then inspect `renv::status()`. Do not install packages into an unrelated global library as a substitute for restoring the project.

### Restore fails

Check network/proxy access, the recorded CRAN repository, R version, compiler/system-library errors, and available storage. Preserve the complete error output.

### Docker build fails during restore

Re-run with visible output:

```bash
docker build --progress=plain -t maize-yield-project .
```

Check registry/network access and package compilation messages.

### Container output disappears

Confirm that the required directories were bind-mounted and inspect host permissions. Files written only to an unmounted container filesystem disappear with `--rm`.

## Reproducibility boundary

This setup helps recreate package and system environments. It does not by itself guarantee:

- permanent availability or unchanged contents of external data;
- identical results across every hardware/platform combination;
- correct data transformations or model assumptions;
- valid interpretation;
- permitted redistribution of data or outputs.

Those concerns require data management, validation, tests, documentation, and scientific review in addition to an environment definition.
