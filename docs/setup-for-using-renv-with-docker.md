# Setup for using `renv` with Docker

This document describes a reproducible workflow for managing R package dependencies with `renv` and executing the project in Docker.

The workflow has three stages:

1. Initialize the `renv` project.
2. Build a Docker image containing the project and its package environment.
3. Run the analysis from the Docker image.

---

# Recreating the `renv` environment (optional)

> **Note**
>
> This section is only required if the project's `renv` metadata has become inconsistent or you want to recreate the environment from scratch.

From the project directory:

``` bash
cd ~/github/maize-yield-project

# Remove any existing renv bootstrap files.
rm -f .Rprofile
rm -rf renv
rm -f renv.lock

# Start R without reading project startup files.
R --no-init-file
```

Install `renv` and initialize a new project environment.

``` r
install.packages(
  "renv",
  repos = "https://cloud.r-project.org"
)

renv::init(bare = TRUE)
```

This creates the project metadata:

``` text
.Rprofile
renv/
├── activate.R
├── library/
└── settings.json
renv.lock
```

Install the project dependencies:

``` r
renv::install(c(
  "dplyr",
  "ggplot2",
  "here",
  "janitor",
  "readr",
  "rmarkdown",
  "rsample",
  "stringr",
  "tibble",
  "tidyr",
  "yaml",
  "yardstick"
))
```

Create the lockfile and verify the environment:

``` r
renv::snapshot(prompt = FALSE)
renv::status()
```

---

# Build the Docker image

The Docker image restores the package environment directly from `renv.lock`.

Only the `renv` metadata is copied initially. This allows Docker to cache the package installation layer so that modifying project source files does not trigger a complete package reinstall.

```dockerfile
FROM rocker/verse:4.3.3

WORKDIR /work

ENV RENV_CONFIG_REPOS_OVERRIDE=https://cloud.r-project.org

# Copy dependency metadata.
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

# Restore the project package library.
RUN Rscript -e 'renv::restore(prompt = FALSE)'

# Copy the remaining project files.
COPY . .

# Verify that the project library matches renv.lock.
RUN Rscript -e 'renv::status()'

CMD ["Rscript", "scripts/run-all.R"]
```

Build the image:

``` bash
docker build -t maize-yield-project .
```

> Rebuild the image whenever the project source code or `renv.lock` changes.

---

# Run the analysis

The Docker image contains both the project source code and the R package environment. Only the input and output directories are mounted so that analysis results remain available on the host while the code executed inside the container is exactly the code stored in the image.

Run the complete pipeline:

``` bash
docker run --rm \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

---

# Interactive use

Start an interactive shell inside the container:

``` bash
docker run --rm -it \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project \
  bash
```

Inside the container you can execute individual scripts:

``` bash
Rscript scripts/03-explore-maize-data.R
```

or start an interactive R session:

``` bash
R
```
