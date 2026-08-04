# Remote-computing implementation

This document describes how the project can be used in a remote Linux environment. The parent learning module contains the conceptual SSH/Linux lessons and detailed exercises.

## Intended deployment pattern

```text
Local computer
      │
      │ SSH
      ▼
Remote Linux server
      │
      ├── Git checkout
      ├── local R + renv, or Docker
      └── persistent data and outputs
```

The repository does not configure or administer a remote server. It supplies portable, command-line workflows suitable for a server that already provides Git and either R/Quarto or Docker.

## Obtain the project

When working through the parent module:

```bash
git clone --recurse-submodules <parent-repository-url>
cd ukudla-intro-ds-module/example-projects/maize-yield-project
```

For an existing parent clone:

```bash
git submodule update --init --recursive
```

Confirm context before running anything:

```bash
hostname
whoami
pwd
git status
```

## Run with local R on the server

```bash
Rscript scripts/setup.R
Rscript scripts/run-all.R
```

The first command can download and compile packages. Follow server policies for storage, network access, and long-running work.

## Run with Docker on the server

If Docker use is permitted:

```bash
docker build -t maize-yield-project .
mkdir -p data-raw data-processed figures reports
docker run --rm \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-interim:/work/data-interim" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

Some shared systems prohibit Docker or require a scheduler/container alternative. Adapt the execution mechanism to the infrastructure policy rather than attempting to bypass it.

## Long-running sessions

An SSH connection can end while a process is running. Use the remote system's supported scheduler or session manager for long work. Do not assume that starting `Rscript` in an interactive SSH shell makes it resilient to disconnection.

Record:

- project commit;
- submodule commit when applicable;
- environment/image version;
- command and parameters;
- input data identity;
- output/log locations;
- allocated resources.

## Data and output persistence

Keep large data and generated outputs in approved persistent storage. Docker bind mounts should reference that storage. Do not place credentials, private keys, restricted data, or access tokens in Git or a container image.

The remote host, container, and local laptop have different filesystems unless files are explicitly cloned, transferred, or mounted. Confirm the active host and path before modifying or deleting anything.

## Current boundary

The project supports command-line execution in a remote environment but does not currently include:

- scheduler job scripts;
- server provisioning;
- infrastructure-as-code;
- cloud storage configuration;
- remote secrets management;
- automated deployment.

Add infrastructure-specific files only when a supported target environment has been selected.
