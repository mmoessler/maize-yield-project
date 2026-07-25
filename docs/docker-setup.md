# Install and set up Docker

## Learning objectives

After completing this guide, you should be able to:

- distinguish an image, container, Dockerfile, bind mount, and Compose file;
- install Docker and Docker Compose for your operating system;
- verify that the Docker engine is running;
- run and remove a test container; and
- identify common installation and permission problems.

## Docker concepts

### Image

An **image** is an immutable, layered package containing the files, binaries, libraries, and configuration needed to run an application.

### Container

A **container** is an isolated process created from an image. Starting two containers from one image creates two separate runtime instances.

### Dockerfile

A **Dockerfile** is a text recipe for building an image:

```text
Dockerfile ──docker build──► image ──docker run──► container
```

### Bind mount

A **bind mount** exposes a host path inside a container. It is useful when inputs or generated outputs must remain on the host after the container exits.

### Docker Compose

Docker Compose describes one or more related containers and their settings in a YAML file, normally `compose.yaml`. It can record images, build instructions, commands, environment variables, networks, and mounts.

Modern Compose uses:

```bash
docker compose
```

The older hyphenated `docker-compose` standalone program is considered legacy.

## Choose an installation method

For Windows and macOS, use Docker Desktop. It includes Docker Engine, the Docker command-line interface, Docker Build, and Docker Compose.

For Linux, follow one of these paths:

- Docker Desktop, if appropriate for the course computer; or
- Docker Engine plus the Docker Compose plugin from Docker's official package repository.

Do not install unofficial packages or copy installation commands from an old blog post. Docker's repository and requirements change over time.

Docker Desktop has licensing terms for commercial use in larger organizations. Students should review the current terms if installing it on an employer-owned computer.

## Windows installation

Docker Desktop normally uses the WSL 2 backend for Linux containers.

1. Confirm that the computer meets Docker's current Windows and virtualization requirements.
2. Install or update WSL 2 if required.
3. Download Docker Desktop from the official Docker website.
4. Run the installer and use the WSL 2 backend.
5. Start Docker Desktop and wait until the engine reports that it is running.
6. Use Linux containers for this R project.

Follow the current [Docker Desktop for Windows instructions](https://docs.docker.com/desktop/setup/install/windows-install/).

Open PowerShell or another terminal and verify:

```bash
docker version
docker compose version
```

If the client is installed but the server section is missing, Docker Desktop is probably not running.

## macOS installation

1. Determine whether the Mac uses Apple silicon or an Intel processor.
2. Download the matching Docker Desktop installer.
3. Move Docker to Applications as instructed.
4. Start Docker Desktop and complete its initial configuration.
5. Wait until the Docker engine is running.

Follow the current [Docker Desktop for Mac instructions](https://docs.docker.com/desktop/setup/install/mac-install/).

In Terminal, verify:

```bash
docker version
docker compose version
```

## Linux installation

Installation commands differ by distribution. Use Docker's official page for your distribution from the [Docker Engine installation overview](https://docs.docker.com/engine/install/).

For Ubuntu, follow the official [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) guide. The maintained repository installation includes packages such as Docker Engine, the CLI, Buildx, and the Compose plugin.

Start and verify the service according to the distribution's instructions:

```bash
sudo systemctl status docker
docker version
docker compose version
```

Some installations require `sudo` for Docker commands. Adding a user to the `docker` group allows root-level control through the Docker daemon; treat that membership as a security-sensitive administrative decision. Follow Docker's [Linux post-installation guidance](https://docs.docker.com/engine/install/linux-postinstall/) and the policy of the course computer.

If Docker Engine is already installed but Compose is missing, install the [Docker Compose plugin](https://docs.docker.com/compose/install/linux/) from Docker's repository.

## Verify the complete setup

### Check versions

```bash
docker --version
docker compose version
```

Both commands should print versions.

### Check the client–engine connection

```bash
docker version
```

This should show both **Client** and **Server** information.

### Run a test container

```bash
docker run --rm hello-world
```

Docker downloads the image if necessary, starts a container, prints a success message, and removes the stopped container because of `--rm`.

The first download requires internet access.

### Inspect Docker state

```bash
docker image ls
docker container ls
docker container ls --all
```

The `hello-world` image may remain cached. The test container should not remain because it was run with `--rm`.

## Verify Docker Compose

This repository currently has a Dockerfile but no `compose.yaml`. The maize analysis therefore uses `docker build` and `docker run`; Compose is installed for later workflows that coordinate services or record longer run configurations.

To see the Compose help:

```bash
docker compose --help
```

A minimal Compose file has this general structure:

```yaml
services:
  analysis:
    build: .
    command: ["Rscript", "scripts/run-all.R"]
```

Do not add this example to the maize repository as part of the installation exercise. A real Compose configuration must also decide how data and output directories are mounted.

When a project provides `compose.yaml`, common commands are:

```bash
docker compose config
docker compose build
docker compose run --rm analysis
docker compose up
docker compose down
```

- `config` validates and renders the configuration.
- `build` creates images for services with a `build` definition.
- `run --rm` performs a one-off service command.
- `up` creates and starts the defined services.
- `down` stops and removes resources created by `up`.

Do not run `docker compose down --volumes` unless you understand that it also removes named volumes and their data.

## Understand the maize project image

The repository's Dockerfile begins with:

```dockerfile
FROM rocker/verse:4.3.3
```

The versioned Rocker image provides R 4.3.3 and publishing tools. The Dockerfile then:

1. selects `/work` as the working directory;
2. copies the `renv` lockfile and activation files;
3. restores the R packages;
4. copies the project files;
5. checks `renv` status; and
6. defines `Rscript scripts/run-all.R` as the default command.

The `.dockerignore` prevents Git state, editor files, and the host's machine-specific `renv` library from entering the build context.

## Resource and security considerations

Docker images can use substantial disk space. Inspect usage with:

```bash
docker system df
```

Containers are isolated processes, not an absolute security boundary:

- use trusted base images;
- review Dockerfiles before building them;
- do not mount sensitive host directories unnecessarily;
- do not pass secrets in image layers or commit them to Git; and
- do not expose the Docker daemon to untrusted users.

Avoid broad cleanup commands during coursework. They may delete images, containers, caches, networks, or volumes needed by other projects.

## Troubleshooting

### `docker: command not found`

Docker is not installed or its CLI directory is not on `PATH`. Complete the platform installation, open a new terminal, and retry.

### Cannot connect to the Docker daemon

On Windows or macOS, start Docker Desktop. On Linux, check the Docker service and whether your user has the required permission.

### Virtualization or WSL error

On Windows, confirm that hardware virtualization and WSL 2 meet Docker's current requirements. Institution-managed machines may require administrator support.

### `docker compose` is not recognized

Docker Compose is missing or outdated. Docker Desktop includes it. On Linux, install the Compose plugin from Docker's official repository.

### A bind mount is empty or inaccessible

Check that the host path exists and that Docker Desktop is permitted to share it. On Linux, inspect ownership and permissions. A bind mount hides files that were already present at the target path inside the container.

### Build runs out of disk space

Inspect usage with `docker system df`. Ask the instructor before deleting shared images, caches, or volumes.

## Completion checklist

- [ ] `docker version` shows a client and server.
- [ ] `docker compose version` prints a version.
- [ ] `docker run --rm hello-world` succeeds.
- [ ] I can explain the difference between an image and a container.
- [ ] I know that this repository currently does not contain a Compose file.
- [ ] I understand that mounted host directories are writable from the container.

## Videos

### Concepts and first commands

- [Docker in 100 Seconds](https://www.youtube.com/watch?v=Gjnup-PuquQ) — a short visual overview of containers, images, Dockerfiles, and how Docker differs from a virtual machine.
- [Docker Tutorial for Beginners](https://www.youtube.com/watch?v=3c-iBn73dDE) — TechWorld with Nana's complete beginner course, including installation, basic commands, debugging, Dockerfiles, volumes, and containerized development.

Use Docker's current written installation instructions in this guide even when a video's installer screens differ. Operating-system requirements and Docker Desktop interfaces change more quickly than the underlying concepts.

### Docker Compose

- [Ultimate Docker Compose Tutorial](https://www.youtube.com/watch?v=SXwC9fSwct8) — TechWorld with Nana explains why Compose is useful, translates `docker run` settings into YAML, and demonstrates `up`, `down`, services, variables, and multi-container applications.

The Compose demonstration uses multiple application services. This maize repository currently has no `compose.yaml`; watch it to learn the tool, but use the project's documented `docker build` and `docker run` commands until a Compose configuration is provided.

## Further reading

- [Get started with Docker](https://docs.docker.com/get-started/)
- [Docker Desktop](https://docs.docker.com/desktop/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- [Docker CLI cheat sheet](https://docs.docker.com/get-started/docker_cheatsheet.pdf)
