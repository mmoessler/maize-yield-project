# Why use reproducible environments?

## Learning objectives

After reading this guide, you should be able to:

- explain why code alone is not enough to reproduce an analysis;
- describe dependencies and dependency versions;
- distinguish an R project environment from a container;
- explain how `renv`, virtual environments, and Docker complement one another; and
- identify important aspects of reproducibility that these tools do not solve.

## The problem: "It works on my machine"

Imagine that one student runs the maize yield analysis successfully, but another student receives an error. Both students have the same scripts. The difference might be:

- a package is not installed;
- different package versions behave differently;
- the computers use different versions of R;
- a package needs a system library that is missing;
- the operating systems handle paths or fonts differently; or
- an external dataset or website has changed.

The scripts describe **what to do**, but an analysis also depends on the environment in which those scripts run.

## What is a computational environment?

A computational environment includes the software and configuration required
to execute a project:

```text
analysis
├── source code
├── language and version, such as R 4.3.3
├── R packages and their versions
├── operating-system libraries
├── external tools, such as Quarto and Pandoc
├── environment variables and configuration
└── data and other external inputs
```

If important parts of this environment are unspecified, a collaborator may have to guess how to recreate it.

## Package versions matter

An R script might contain:

```r
library(dplyr)
```

This states that the project needs `dplyr`, but not which version. Packages change over time: functions can gain arguments, defaults can change, bugs can be fixed, and older behavior can be removed.

Installing the newest available package versions months later may therefore produce different output or cause code to fail. Recording versions turns an implicit assumption into explicit project metadata.

## Isolation, portability, and reproducibility

A useful environment aims to provide three properties:

- **Isolation:** changing packages for one project does not unexpectedly break another project.
- **Portability:** another person or computer can recreate the environment from shared instructions and metadata.
- **Reproducibility:** the recreated environment uses the intended dependency versions rather than whichever versions happen to be installed.

These properties overlap, but they are not identical. An isolated environment that exists only on one laptop is not yet portable. A portable description that always installs unpinned latest versions is not fully reproducible.

## R project environments with `renv`

[`renv`](https://rstudio.github.io/renv/) gives an R project its own package library and records package versions in `renv.lock`.

Its core workflow is:

```text
project code ──► dependency discovery
                       │
                       ▼
               project library
                  │         ▲
         snapshot │         │ restore
                  ▼         │
                  renv.lock
```

- `renv::init()` starts using `renv` in a project.
- `renv::install()` installs packages into the project library.
- `renv::snapshot()` records the environment in `renv.lock`.
- `renv::restore()` recreates the library from `renv.lock`.
- `renv::status()` compares the code, library, and lockfile.

The lockfile is small text metadata and belongs in Git. The installed package library is large and machine-specific, so it normally does not.

## Virtual environments

A **virtual environment** is an isolated language-level environment. Different language ecosystems provide different tools:

- R projects can use `renv`;
- Python projects often use `venv`, Conda, Poetry, or similar tools; and
- other languages have their own package and environment managers.

The details differ, but the goal is similar: keep project dependencies separate and provide a machine-readable way to reconstruct them.

A virtual environment generally manages packages for a language. It does not fully specify the host operating system, system libraries, drivers, or external command-line programs.

## Containers with Docker

A Docker **image** is a packaged, layered description containing files, binaries, libraries, and configuration. A **container** is an isolated process started from an image.

```text
Dockerfile ──docker build──► image ──docker run──► container
```

A Dockerfile can pin an R base image, install system dependencies, restore an `renv` library, copy the analysis code, and define the command to run.

This captures more of the software stack than `renv` alone:

```text
┌──────────────────────────────────────┐
│ Analysis code and project files      │
├──────────────────────────────────────┤
│ R packages: managed with renv        │
├──────────────────────────────────────┤
│ R, Quarto, system tools and libraries│
├──────────────────────────────────────┤
│ Container image                      │
├──────────────────────────────────────┤
│ Host operating system and hardware   │
└──────────────────────────────────────┘
```

Containers are lighter than full virtual machines because they share the host kernel. They still provide a controlled user-space environment.

## Why combine `renv` and Docker?

The tools address different layers:

| Tool | Primarily controls | Useful for |
|---|---|---|
| `renv` | R package library and package versions | Everyday R development and collaboration |
| Language virtual environment | Packages and runtime for a language | Isolating projects in that ecosystem |
| Docker | Runtime, system libraries, tools, files, and command | Portable batch execution and deployment |
| Git | Versioned environment definitions | Sharing and reviewing changes |

In the maize yield project:

- `renv.lock` records R 4.3.3 and the R package dependencies;
- `.Rprofile` activates the project library;
- `Dockerfile` starts from `rocker/verse:4.3.3`;
- the image restores packages from `renv.lock`; and
- the container runs `scripts/run-all.R`.

Git stores the recipes; `renv` and Docker reconstruct the environments.

## Why this matters in food-systems data science

Food-systems analyses may inform research, policy, monitoring, or operational decisions. They often combine data from different organizations and must be revisited after a semester, reporting cycle, or data revision.

A documented environment helps:

- a classmate reproduce a result;
- an instructor diagnose a problem;
- a research team rerun an analysis after new data arrive;
- reviewers understand the software context;
- an automated service execute the same workflow; and
- future maintainers update dependencies deliberately.

Reproducibility also improves learning: instead of spending class time on unexplained package differences, students can work from a known starting point.

## What these tools do not guarantee

`renv` and Docker improve computational reproducibility, but neither guarantees scientific validity or identical results in every situation.

You must still manage:

- source-data versions and provenance;
- random-number seeds;
- external web services and changing download URLs;
- secrets and credentials;
- hardware-specific calculations;
- locale, time zone, and platform differences;
- undocumented manual steps;
- statistical assumptions and data quality; and
- long-term availability of package and image sources.

An environment can reproduce an incorrect analysis perfectly. Reproducibility makes work inspectable; it does not replace good methods.

## A practical reproducibility record

For a small data science project, record and version:

- source scripts and reports;
- a README with execution instructions;
- an R version and `renv.lock`;
- `.Rprofile`, `renv/activate.R`, and `renv/settings.json`;
- a Dockerfile and `.dockerignore`;
- data provenance and acquisition instructions; and
- checks that reveal whether execution succeeded.

Do not commit package libraries, passwords, tokens, or confidential data.

## Check your understanding

1. Why can the same script behave differently on two computers?
2. What does `renv.lock` record, and why is it committed to Git?
3. What additional layer does Docker control compared with `renv`?
4. What is the difference between a Docker image and a container?
5. Name two reproducibility concerns that neither `renv` nor Docker solves by itself.

## Further reading

- [Introduction to `renv`](https://rstudio.github.io/renv/articles/renv)
- [Using `renv` with Docker](https://rstudio.github.io/renv/articles/docker.html)
- [Docker: What is an image?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/)
- [The Turing Way: Reproducible environments](https://book.the-turing-way.org/reproducible-research/renv/renv)
