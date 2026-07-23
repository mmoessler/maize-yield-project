# Maize Yield Project

This readme explains the purpose of the principal files and directories in the `maize-yield-project` repository and how they work together to support a reproducible data science workflow.

## Top-level files

### `README.md`

The main entry point for the repository. It introduces the project, explains its purpose, lists prerequisites, and provides instructions for reproducing the analysis.

### `maize-yield-project.Rproj`

The RStudio Project file. Opening the project through this file ensures project-relative paths and a consistent working directory.

### `compose.yaml`

Defines the Docker Compose services used to run the project, including a batch analysis service and an optional RStudio Server service.

### `Dockerfile`

Defines the container image used for reproducible execution, including the operating system, R version, system libraries, and project setup.

### `.env.example`

A template containing potential configurable environment variables such as passwords, ... .

### `.dockerignore`

Lists files and folders that should not be copied into Docker images to keep builds small and efficient.

### `.gitignore`

Lists generated files, caches, temporary files, and local configuration that should not be committed to Git.

### `renv.lock`

Pins the versions of all R packages used in the project so that the software environment can be recreated.

## Directories

### `data-raw/`

Stores original downloaded datasets. These files should never be edited manually.

### `data-processed/`

Stores cleaned datasets produced by reproducible scripts.

### `scripts/`

Contains the numbered workflow scripts executed in order:

1. acquire data
2. clean data
3. exploratory analysis
4. modelling
5. report generation

### `reports/`

Contains Quarto reports that combine narrative, code, tables, figures, and interpretation.

### `figures/`

Stores generated plots and other graphical outputs.

### `docs/`

Contains supplementary documentation such as Docker guides and instructor notes.

## Workflow

``` text
Raw Data
    │
    ▼
scripts/
    │
    ▼
data-processed/
    │
    ▼
reports/
    │
    ▼
figures/
    │
    ▼
Final Report
```

Docker and `renv` ensure that this workflow can be reproduced consistently across laptops, remote servers, and cloud infrastructure.

## Design Principles

The repository follows recommendations from **The Turing Way** by emphasising:

- reproducibility;
- clear documentation;
- transparent data provenance;
- modular code;
- version control with Git;
- project-relative paths;
- portable execution with Docker; and
- reproducible package management with `renv`.

These practices help students learn not only data analysis but also professional research software engineering and reproducible computational research.
