# Use Linux inside the maize yield container

## Learning objectives

After completing this guide, you should be able to:

- start and enter the project's Docker container;
- tell the host computer from the container;
- navigate and inspect the project with basic Linux commands;
- combine commands with pipes;
- understand which container changes persist; and
- make and save a small practice edit with Vim.

## Before you begin

Open a terminal in the repository root and check the context:

```bash
pwd
git status
docker version
```

Build the image if it has not already been built, or rebuild it after changing the
`Dockerfile` or `renv.lock`:

```bash
docker build -t maize-yield-project .
```

The image uses Linux and R 4.3.3 from `rocker/verse`. Its working directory is
`/work`, and its default command runs `scripts/run-all.R`.

## Method 1: Create and enter a container directly

Prepare the host directories that will receive data and results:

```bash
mkdir -p data-raw data-processed figures reports
```

Then create a container and enter its Bash shell:

```bash
docker run --rm -it \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project \
  bash
```

The options mean:

- `--rm`: remove the container after it stops;
- `-i`: keep standard input open;
- `-t`: allocate a terminal;
- `-v host:container`: bind-mount a host directory; and
- `bash`: replace the image's normal analysis command with an interactive shell.

Your prompt changes because commands now run inside the container.

## Establish your context

Run these commands inside the container:

```bash
pwd
whoami
hostname
cat /etc/os-release
R --version
```

`pwd` should report `/work`. `hostname` normally shows the container's generated
identifier. Compare these results with the same commands on the host.

When in doubt, ask:

```text
Which prompt is this?  Which computer?  Which directory?  Which user?
```

## Navigate through the project

List files and directories:

```bash
ls
ls -la
```

Move between directories:

```bash
cd scripts
pwd
ls
cd ..
cd reports
cd -
```

Useful path notation:

- `/work/scripts` is an **absolute path** beginning at the filesystem root;
- `scripts` is a **relative path** beginning at the current directory;
- `.` means the current directory;
- `..` means the parent directory; and
- `cd -` returns to the previous directory.

Find project files without changing them:

```bash
find . -maxdepth 2 -type f
find scripts -type f -name "*.R"
```

Linux paths and filenames are case-sensitive: `README.md` and `readme.md` are
different names.

## Inspect text and data

Display a short file:

```bash
cat .Rprofile
```

Inspect only the beginning or end:

```bash
head -n 10 scripts/run-all.R
tail -n 10 scripts/run-all.R
```

Use a scrollable viewer for a longer file:

```bash
less README.md
```

In `less`, use the arrow keys or Page Up/Page Down, `/word` to search, `n` for the
next match, and `q` to quit.

Count lines and search text:

```bash
wc -l scripts/*.R
grep -n "Rscript" README.md
grep -R -n "renv" docs
```

If processed data already exist, inspect them without loading all rows:

```bash
head -n 5 data-processed/maize-yield-panel.csv
wc -l data-processed/maize-yield-panel.csv
```

A displayed line count includes the CSV header.

## Combine commands

A pipe, `|`, sends the output of the command on its left to the input of the command
on its right:

```bash
find scripts -type f | sort
grep -R -n "maize" scripts | head
```

This does not create a file. Redirection does:

```text
command > file     overwrite file with command output
command >> file    append command output to file
```

Do not practise redirection on tracked project files. An accidental `>` can replace
their contents.

## Inspect storage and processes

```bash
df -h
du -sh /work
ps
```

- `df -h` summarizes filesystem capacity;
- `du -sh /work` estimates the project directory's size; and
- `ps` lists processes associated with the current shell.

Many commands describe their options with `--help`, for example:

```bash
grep --help
```

Manual pages may not be installed in a minimal container. If `man grep` fails, use
`--help` or consult the linked documentation outside the container.

## Run project operations

Check the restored R environment:

```bash
Rscript -e 'renv::status()'
```

Inspect the pipeline rather than running it:

```bash
less scripts/run-all.R
```

Run the complete analysis only when you are ready for the FAOSTAT download and the
required output directories are mounted:

```bash
Rscript scripts/run-all.R
```

The first stage downloads a large FAOSTAT archive. See
[`re-application.md`](re-application.md) for prerequisites, expected outputs, and
the complete local/container workflow.

## A brief Vim exercise

Vim is a modal command-line text editor. First check whether it is available:

```bash
vim --version
```

If that command is not found, try `vi --version`. Do not install software in the
course container merely for this exercise; ask the instructor which editor to use.

Use a disposable file so that the exercise cannot alter the repository:

```bash
vim /tmp/vim-practice.txt
```

Vim starts in **Normal mode**. Practise this sequence:

1. Press `i` to enter **Insert mode**.
2. Type `Maize yield analysis`.
3. Press `Esc` to return to Normal mode.
4. Type `:w` and press Enter to save.
5. Type `:q` and press Enter to quit.

Essential commands:

| Keys | Action |
|---|---|
| `i` | enter Insert mode |
| `Esc` | return to Normal mode |
| `:w` | save |
| `:q` | quit when no unsaved changes remain |
| `:wq` | save and quit |
| `:q!` | quit and discard unsaved changes |
| `u` | undo |
| `dd` | delete the current line |
| `/word` | search for `word` |
| `n` | move to the next search result |

Read the practice file:

```bash
cat /tmp/vim-practice.txt
```

`/tmp/vim-practice.txt` disappears when this `--rm` container is removed.

## Persistence: image, container, and mounts

The project source was copied into the image when `docker build` ran. Edits to that
copy exist only in the current container and disappear with `--rm`.

The four bind-mounted directories are different:

```text
host directory          container directory
data-raw                /work/data-raw
data-processed          /work/data-processed
figures                 /work/figures
reports                 /work/reports
```

Changes inside those container paths immediately affect the corresponding host
directories. A container is isolation, not a safety backup. Do not delete or
overwrite mounted data casually.

Edit source code on the host, record it with Git, and rebuild the image. Use the
container for reproducible execution and inspection.

## Method 2: Enter an already running container

`docker exec` opens another process in an existing container. From the host, start
a named container in the background:

```bash
docker run --rm -dit \
  --name maize-shell \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project \
  bash
```

Check that it is running, then enter it:

```bash
docker ps
docker exec -it maize-shell bash
```

Type `exit` to leave the added shell. The container continues running. Stop it from
the host:

```bash
docker stop maize-shell
```

Because it was created with `--rm`, Docker removes it after it stops.

## Leave the direct interactive container

At its shell prompt, run:

```bash
exit
```

This stops and removes the container created by Method 1. It does not remove the
image or files in the mounted host directories.

## Troubleshooting

### `docker: command not found`

Install Docker as described in [`docker-setup.md`](docker-setup.md), then open a new
terminal.

### `Unable to find image 'maize-yield-project:latest'`

Run the `docker build -t maize-yield-project .` command from the repository root.

### A bind mount is empty or points somewhere unexpected

Run `pwd` on the host before `docker run`. `$(pwd)` must be the repository root.

### `vim: command not found`

The image may not contain Vim. Use `vi` if available or perform the editor exercise
in a course environment that provides Vim. This does not prevent the analysis from
running.

### Permission errors appear in a mounted directory

Stop before using `sudo` or broad permission changes. Container-created files can
have host ownership implications. Record the command, path, and `ls -l` output and
ask the instructor for the platform-specific solution.

## Check your work

- [ ] I can identify whether a prompt is on the host or in a container.
- [ ] I can navigate with `pwd`, `ls`, and `cd`.
- [ ] I can inspect files with `less`, `head`, `tail`, and `grep`.
- [ ] I understand what a pipe does.
- [ ] I know which project directories are bind-mounted.
- [ ] I can save and quit a disposable Vim file.
- [ ] I can leave and stop the container cleanly.

## Videos

- [Bash/Terminal Crash Course for Beginners](https://www.youtube.com/watch?v=oxuRxtrO2Ag) — Traversy Media; covers the shell and common file, navigation, search, and piping commands.
- [Vim in 100 Seconds](https://www.youtube.com/watch?v=-txKSRn0qeA) — Fireship; a concise visual introduction to Vim's modal editing model.
- [Docker Tutorial for Beginners](https://www.youtube.com/watch?v=pTFZFxd4hOI) — Programming with Mosh; use the sections on running and interacting with containers to reinforce this exercise.

## Further reading

- [The Linux command line for beginners — Ubuntu](https://ubuntu.com/desktop/docs/en/latest/tutorial/the-linux-command-line-for-beginners/)
- [The Unix Shell lesson — Software Carpentry](https://swcarpentry.github.io/shell-novice/)
- [Run containers — Docker Docs](https://docs.docker.com/guides/golang/run-containers/)
- [`docker container exec` reference — Docker Docs](https://docs.docker.com/reference/cli/docker/container/exec/)
- [Vim help files](https://vimhelp.org/)
