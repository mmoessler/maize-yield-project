# A collaborative Git workflow

## Learning objectives

After completing this guide, you should be able to:

- follow the pull–edit–stage–commit–push workflow;
- explain why a push can be rejected;
- integrate non-conflicting work from another collaborator;
- recognize and resolve a merge conflict; and
- distinguish local commits from commits on GitHub.

## The setting

This guide considers two collaborators working on the same branch of the same GitHub repository:

- **Collaborator 1:** you;
- **Collaborator 2:** someone else; and
- **Remote:** the shared repository on GitHub, named `origin`.

The examples use the `main` branch. They demonstrate the mechanics of a shared branch because it keeps the first exercise small. In a larger project,
collaborators would usually make changes on separate branches and integrate them through pull requests.

## The basic cycle

```text
GitHub                  your computer
  │                           │
  │  git pull                ▼
  ├──────────────────► working directory
  │                           │ edit
  │                           ▼
  │                      changed files
  │                           │ git add
  │                           ▼
  │                      staging area
  │                           │ git commit
  │                           ▼
  │                      local history
  │                           │ git push
  ◄───────────────────────────┘
```

The commands have different purposes:

- `git pull` obtains and integrates remote commits.
- Editing changes files only in your working directory.
- `git add` selects content for the next commit.
- `git commit` creates a snapshot in your local repository.
- `git push` sends local commits to GitHub.

Saving, adding, committing, and pushing are separate actions.

## Before making a change

Move into the repository and inspect its state:

```bash
cd maize-yield-project
git status
git branch --show-current
git remote -v
```

Confirm that:

- you are in the intended repository;
- the working tree does not contain unexpected changes;
- the current branch is `main`; and
- `origin` points to the shared repository.

Then retrieve the latest shared work:

```bash
git pull --no-rebase origin main
```

`--no-rebase` tells Git to integrate diverging histories with a merge. It makes the behavior in these introductory examples explicit, regardless of the
student's global Git configuration.

Pulling before you edit reduces the chance of divergence, but it cannot prevent another collaborator from pushing while you are working.

## Scenario 1: Simple commit

Only Collaborator 1 changes the repository.

### Starting point

Both the local and remote repositories contain commit `A`:

```text
local main:   A
remote main:  A
```

### Collaborator 1

First, pull the current state:

```bash
git pull --no-rebase origin main
```

Edit a file. For example, add a sentence to `README.md`. Then inspect the change:

```bash
git status
git diff
```

Stage only the intended file:

```bash
git add README.md
```

Review exactly what will be committed:

```bash
git diff --staged
```

Create the local commit:

```bash
git commit -m "Clarify the project description"
```

The histories are now:

```text
local main:   A──B
remote main:  A
```

Push the new commit:

```bash
git push origin main
```

After the push:

```text
local main:   A──B
remote main:  A──B
```

Verify the result:

```bash
git status
git log --oneline --decorate -5
```

`git status` should report that the branch is up to date with `origin/main` and that the working tree is clean.

## Scenario 2: Non-conflicting diverging snapshots

Both collaborators pull commit `A`. Collaborator 1 changes `file-1.md`, while Collaborator 2 changes `file-2.md`.

Because both people start from the same commit, their local histories diverge:

```text
             B  collaborator 1 changes file-1.md
            /
starting   A
            \
             C  collaborator 2 changes file-2.md
```

The edits are non-conflicting because they affect different files.

### Collaborator 1

```bash
git pull --no-rebase origin main
# Edit file-1.md
git diff
git add file-1.md
git diff --staged
git commit -m "Update file 1"
git push origin main
```

The push succeeds, so GitHub now contains:

```text
A──B
```

### Collaborator 2

Collaborator 2 had already pulled `A`, edited `file-2.md`, and committed:

```bash
# Edit file-2.md
git diff
git add file-2.md
git diff --staged
git commit -m "Update file 2"
```

Their local history contains `A──C`, but GitHub contains `A──B`. If Collaborator 2 now runs:

```bash
git push origin main
```

Git rejects the push because it would discard commit `B` from the remote branch. The rejection commonly includes the term `non-fast-forward`.

This rejection protects the shared history. It does not mean that Collaborator 2's commit has been lost.

### Integrate the remote commit

Collaborator 2 pulls the remote history:

```bash
git pull --no-rebase origin main
```

Because `B` and `C` change different files, Git can normally merge them automatically. Git creates a merge commit `M`:

```text
             B─────M
            /     /
           A─────C
```

Both changes are now present locally. Collaborator 2 should inspect and, where appropriate, test the combined project:

```bash
git status
git log --oneline --graph --decorate -5
```

Finally, push the integrated history:

```bash
git push origin main
```

GitHub now contains `B`, `C`, and merge commit `M`.

### What to notice

- Different files can still produce diverging Git histories.
- A push rejection is expected when another commit reached GitHub first.
- Non-conflicting divergence can usually be merged automatically.
- The collaborator who integrates the histories should inspect the combined result before pushing.

## Scenario 3: Conflicting diverging snapshots

Both collaborators pull commit `A`, then both change the same part of `file-1.md`.

```text
             B  collaborator 1 changes the same lines
            /
starting   A
            \
             C  collaborator 2 changes the same lines differently
```

Git cannot decide which content should be retained.

### Collaborator 1

```bash
git pull --no-rebase origin main
# Edit file-1.md
git diff
git add file-1.md
git diff --staged
git commit -m "Revise the introduction"
git push origin main
```

The push succeeds. GitHub now contains `A──B`.

### Collaborator 2

Collaborator 2, still working from `A`, makes and commits a different edit:

```bash
# Edit the same part of file-1.md
git diff
git add file-1.md
git diff --staged
git commit -m "Rewrite the introduction"
git push origin main
```

The push is rejected because GitHub already contains commit `B`.

Collaborator 2 retrieves and attempts to merge that commit:

```bash
git pull --no-rebase origin main
```

Git stops the merge and reports a conflict. `git status` identifies the affected files:

```bash
git status
```

A conflicted file contains markers similar to:

```text
<<<<<<< HEAD
The introduction written by Collaborator 2.
=======
The introduction written by Collaborator 1.
>>>>>>> origin/main
```

The sections mean:

- `<<<<<<< HEAD` to `=======` is the content from the current local branch;
- `=======` to `>>>>>>> origin/main` is the incoming remote content.

Do not simply choose the top or bottom section without understanding both changes. The collaborators may need to discuss the intended result.

### Resolve the conflict

Open `file-1.md` in an editor. Replace the complete marked section with the agreed final content and remove all three marker lines.

For example:

```text
The revised introduction combining the relevant ideas from both collaborators.
```

Confirm that no conflict markers remain:

```bash
git diff
```

Search the repository if necessary:

```bash
git grep -n -e '<<<<<<<' -e '=======' -e '>>>>>>>'
```

An empty result is expected after all markers have been removed.

Stage the resolved file and check the state:

```bash
git add file-1.md
git status
git diff --staged
```

Complete the merge:

```bash
git commit -m "Merge introduction changes"
```

Inspect or test the combined work, then push:

```bash
git log --oneline --graph --decorate -5
git push origin main
```

The resulting history has the same shape as the non-conflicting case:

```text
             B─────M
            /     /
           A─────C
```

The difference is that a person had to determine the contents of merge commit `M`.

## If you are not ready to resolve a merge

While a conflicted merge is still in progress, you can return to the state before the pull:

```bash
git merge --abort
```

This is useful when you need help or want to discuss the changes first. It does not delete the local commit you made before beginning the merge.

Do not use destructive commands such as `git reset --hard` or force-push as a shortcut. They can discard work or overwrite shared history.

## Comparison of the scenarios

| Scenario | Remote changed while you worked? | Same content changed? | Expected result |
|---|---:|---:|---|
| Simple commit | No | No | Push succeeds |
| Non-conflicting divergence | Yes | No | Push rejected; pull merges automatically; push again |
| Conflicting divergence | Yes | Yes | Push rejected; pull reports conflict; resolve, commit, and push |

## Habits that reduce problems

1. Pull before beginning a unit of work.
2. Communicate which files or sections each person is changing.
3. Keep changes focused and commits small.
4. Check `git status` frequently.
5. Review `git diff` before staging.
6. Review `git diff --staged` before committing.
7. Write commit messages that describe the completed change.
8. Push completed work regularly.
9. Never commit secrets, private data, or generated files that belong in `.gitignore`.
10. In larger collaborations, use separate branches and pull requests.

## Videos

Use these videos to reinforce the workflow after reading the corresponding scenario:

### Scenario 1: Add, commit, and push

- [Git and GitHub for Beginners: add, commit, and push](https://www.youtube.com/watch?v=RGOj5yH7evk&t=1050s) — freeCodeCamp, beginning with its demonstration of staging and committing changes. The push and review of the complete local-to-remote workflow follow in the same video.
- [GitHub for Beginners](https://www.youtube.com/playlist?list=PL0lo9MOBetEFcp4SCWinBdpml9B2U25-f) — GitHub's official beginner series, including its overview of commonly used Git commands.

Pause the demonstration before each command and predict whether it changes the working directory, staging area, local history, or remote history.

### Scenario 2: Diverging histories and merging

- [Git and GitHub for Poets: branches](https://www.youtube.com/watch?v=oPpnCh7InLY) — The Coding Train's visual introduction to branches and histories that develop from a shared starting point.
- [GitHub for Beginners: answers to common questions](https://www.youtube.com/watch?v=ZgARMqR3qq8) — GitHub's official discussion includes merging versus rebasing and synchronizing work with an upstream repository.

The branch video demonstrates divergence through separate branches. Scenario 2 creates divergence through separate clones of a shared branch, but the important history shape and the need to integrate both commits are equivalent.

### Scenario 3: Merge conflicts

- [GitHub for Beginners](https://www.youtube.com/playlist?list=PL0lo9MOBetEFcp4SCWinBdpml9B2U25-f) — watch the official episode about merging a pull request, which creates a conflict, displays the conflict markers, resolves the file locally, commits the resolution, and pushes it.
- [GitHub for Beginners: answers to common questions](https://www.youtube.com/watch?v=ZgARMqR3qq8) — includes a shorter official explanation of why conflicts occur and how a person chooses the final content.

GitHub's merge-conflict demonstration uses two pull-request branches, whereas Scenario 3 uses two collaborators on `main`. In both cases, Git reports a conflict because different commits changed the same part of the same file. Use the commands and safety checks in this guide for the course exercise.

## Practice exercise

Practise these cases in a temporary repository before using important project work. Two collaborators can use separate clones, or one learner can create two clones in different directories to simulate two computers.

For each scenario:

1. Record the output of `git log --oneline --graph --all`.
2. Predict whether the next push will succeed.
3. Explain why Git can or cannot merge automatically.
4. Confirm that the final files contain both intended changes.
5. Confirm that both collaborators can pull the final history.

## Command summary

```bash
# Inspect
git status
git diff
git diff --staged
git log --oneline --graph --decorate -5

# Synchronize before editing
git pull --no-rebase origin main

# Record a change
git add path/to/file
git commit -m "Describe the completed change"

# Share a change
git push origin main

# During a conflict
git status
git add path/to/resolved-file
git commit -m "Merge conflicting changes"
git push origin main

# Cancel an unfinished merge
git merge --abort
```

## Further reading

- [Git basics — GitHub Docs](https://docs.github.com/en/get-started/git-basics)
- [About remote repositories — GitHub Docs](https://docs.github.com/en/get-started/git-basics/about-remote-repositories)
- [Dealing with non-fast-forward errors — GitHub Docs](https://docs.github.com/en/get-started/using-git/dealing-with-non-fast-forward-errors)
- [Resolving a merge conflict using the command line — GitHub Docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts/resolving-a-merge-conflict-using-the-command-line)
