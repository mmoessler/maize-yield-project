# Create your maize yield repository

## Goal

In this exercise, you will:

1. create an empty `maize-yield-project` repository in your GitHub account;
2. clone the public course repository;
3. keep the course repository as a remote named `upstream`;
4. add your repository as the remote named `origin`; and
5. push the project history to your repository.

At the end, the relationship will be:

```text
course repository
git@github.com:mmoessler/maize-yield-project.git
                  ▲
                  │ fetch updates
                  │
        local maize-yield-project
                  │
                  │ push your work
                  ▼
your repository
git@github.com:YOUR-USERNAME/maize-yield-project.git
```

## Before you start

Complete [`git-github-setup.md`](git-github-setup.md) first. Confirm that:

```bash
git --version
ssh -T git@github.com
```

Replace `YOUR-USERNAME` in this guide with your actual GitHub username. Do not type the angle brackets sometimes used around placeholders.

Choose a parent directory in which to store course projects. Do not run the clone command from inside another copy of `maize-yield-project`.

## 1. Create an empty repository on GitHub

1. Sign in to [GitHub](https://github.com/).
2. Select the **+** menu in the upper-right corner.
3. Select **New repository**.
4. Choose your personal account as the owner.
5. Enter `maize-yield-project` as the repository name.
6. Choose the visibility required by your course. If no visibility was
   specified, choose **Private** for coursework or **Public** if you intend to
   share it openly.
7. Do **not** add a README, `.gitignore`, or license.
8. Select **Create repository**.

The repository must be empty because the course project already has files and Git history. Initializing both repositories separately can create unrelated
histories and unnecessary merge problems.

Keep the new repository's Quick Setup page open. Its SSH address should have this form:

```text
git@github.com:YOUR-USERNAME/maize-yield-project.git
```

GitHub also documents this empty-repository approach in [Adding locally hosted code to GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).

## 2. Clone the public course repository

In a terminal, move to the parent directory where you keep projects. For example:

```bash
cd ~/projects
```

The directory must already exist. You may use a different location.

Clone the course repository:

```bash
git clone git@github.com:mmoessler/maize-yield-project.git
```

Enter the new project directory:

```bash
cd maize-yield-project
```

Check its status:

```bash
git status
```

You should be on a branch named `main` with no uncommitted changes.

## 3. Inspect the existing remote

A clone automatically calls its source remote `origin`. Confirm this:

```bash
git remote -v
```

You should initially see the course address for both fetch and push:

```text
origin  git@github.com:mmoessler/maize-yield-project.git (fetch)
origin  git@github.com:mmoessler/maize-yield-project.git (push)
```

Do not push student work to the course repository.

## 4. Rename the course remote

Rename the existing remote from `origin` to `upstream`:

```bash
git remote rename origin upstream
```

`upstream` is a conventional name for the repository from which your copy originated. It will allow you to fetch later course updates without confusing
them with your own repository.

Verify the change:

```bash
git remote -v
```

The course address should now be listed as `upstream`.

## 5. Add your repository as `origin`

Replace `YOUR-USERNAME` with your GitHub username:

```bash
git remote add origin git@github.com:YOUR-USERNAME/maize-yield-project.git
```

Inspect both remotes:

```bash
git remote -v
```

The result should follow this pattern:

```text
origin    git@github.com:YOUR-USERNAME/maize-yield-project.git (fetch)
origin    git@github.com:YOUR-USERNAME/maize-yield-project.git (push)
upstream  git@github.com:mmoessler/maize-yield-project.git (fetch)
upstream  git@github.com:mmoessler/maize-yield-project.git (push)
```

Read each address carefully. `origin` must contain your username; `upstream` must contain `mmoessler`.

## 6. Push to your repository

Push the existing `main` branch and set it to track `origin/main`:

```bash
git push -u origin main
```

The `-u` option records the tracking relationship. After this first push, you can normally use `git push` and `git pull` without repeating the remote and
branch names.

Refresh your repository page on GitHub. The project files and commit history should now be visible.

## 7. Verify the setup

Run:

```bash
git status
git branch -vv
git remote -v
```

Check that:

- the working tree is clean;
- `main` tracks `origin/main`;
- `origin` points to your GitHub account; and
- `upstream` points to the public course repository.

You can inspect one remote in more detail with:

```bash
git remote show origin
```

## Your normal workflow

After editing a file:

```bash
git status
git diff
git add path/to/changed-file
git diff --staged
git commit -m "Describe the completed change"
git push
```

Stage specific files rather than automatically staging everything. Always review changes before committing, especially when the project contains data,
environment files, or credentials.

## Receive later course updates

Only do this when instructed, particularly if you have changed the same files as the course repository.

Fetch the upstream history:

```bash
git fetch upstream
```

Inspect the incoming commits:

```bash
git log --oneline main..upstream/main
```

Integrating upstream changes may require a merge or rebase and may produce conflicts. Your instructor will specify the appropriate method for the course
exercise. Fetching alone does not change your working files.

## Troubleshooting

### `Repository not found`

Check the spelling and capitalization of your username and repository name. Also confirm that you are authenticated as the GitHub account that owns the
repository.

### `Permission denied (publickey)`

Return to [`git-github-setup.md`](git-github-setup.md) and test:

```bash
ssh -T git@github.com
```

### `remote origin already exists`

Inspect the current configuration before changing anything:

```bash
git remote -v
```

If `origin` already points to your repository, no change is needed. If you missed the rename step and `origin` still points to the course repository, run:

```bash
git remote rename origin upstream
git remote add origin git@github.com:YOUR-USERNAME/maize-yield-project.git
```

### The destination directory already exists

Do not delete it blindly. It may contain work. Use `pwd`, `ls`, and `git status` to determine what it contains, then ask your instructor if you
are unsure.

### The GitHub repository contains an initial README

The safest beginner solution is usually to delete and recreate the new GitHub repository as an empty repository, provided it contains no work you need.
Do not force-push unless your instructor explicitly asks you to.

## Completion checklist

- [ ] My GitHub repository is named `maize-yield-project`.
- [ ] I cloned the course repository using SSH.
- [ ] `origin` points to my repository.
- [ ] `upstream` points to the course repository.
- [ ] My local `main` branch tracks `origin/main`.
- [ ] The files and commit history appear in my GitHub repository.
- [ ] I understand that commits stay local until I push them.
