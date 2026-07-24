# Why use Git and GitHub?

## Learning objectives

After reading this guide, you should be able to:

- explain the difference between Git and GitHub;
- describe how version control supports reproducible data science;
- identify useful points at which to commit work; and
- explain how GitHub supports collaboration.

## A common problem

Without version control, a project folder can quickly contain files such as:

```text
analysis.R
analysis-new.R
analysis-final.R
analysis-final-revised.R
analysis-final-revised-2.R
```

It is difficult to tell which file is authoritative, what changed between versions, or why a change was made. Sharing files by email or chat creates additional copies and makes collaborative editing even harder.

Git addresses this problem by recording meaningful snapshots of a project over time. GitHub provides an online home for Git repositories and adds tools for sharing, reviewing, discussing, and integrating work.

## Git and GitHub are different tools

**Git** is a distributed version control system. It runs on your computer and records the history of files in a repository. Most Git operations work without an internet connection.

**GitHub** is an online platform that hosts Git repositories. It supports collaboration through pull requests, issues, code review, project permissions, and other services.

You can use Git without GitHub, and GitHub can host repositories created with Git. In this course, we use them together.

## Why Git matters in data science

### A traceable history

A commit records a snapshot of the tracked files together with an author, timestamp, and message. A useful history helps answer:

- What changed?
- Who changed it?
- Why was it changed?
- When did a result or error first appear?

This is especially valuable when a small change in data preparation or model code changes the final result.

### Safe experimentation

Git makes it easier to try an idea without losing known working code. Branches can isolate experimental work, while previous commits provide recovery points.

Git is not a replacement for good backups, but it is much safer and clearer than maintaining manually numbered copies of scripts.

### Reproducibility

A reproducible analysis needs more than a final report. It should include the code and documentation required to explain how the result was produced.
Version control connects those materials to a specific point in the project's history.

For example, a commit can record the exact versions of:

- a data-cleaning script;
- a model specification;
- an environment lockfile such as `renv.lock`; and
- a Quarto report.

Large or sensitive datasets and secrets generally require other storage solutions and should not be committed automatically.

### Collaboration

Git allows each collaborator to have a complete local copy of the repository and its history. Contributors can work independently and then integrate their changes.

GitHub adds a shared location where a team can:

- discuss tasks in issues;
- propose changes in pull requests;
- review code and documentation;
- see automated checks; and
- control who can read or modify a repository.

## A simple mental model

```text
working directory  --git add-->  staging area  --git commit-->  local history
                                                                    |
                                                               git push
                                                                    |
                                                                    ▼
                                                              GitHub repository
```

- The **working directory** contains the files you are editing.
- The **staging area** contains the changes selected for the next commit.
- The **local history** is the sequence of commits stored by Git.
- A **remote repository** is another copy of the repository, commonly hosted
  on GitHub.

`git push` sends local commits to a remote. `git pull` retrieves and integrates remote changes. Saving a file does not automatically create a commit or upload anything to GitHub.

## What makes a useful commit?

A useful commit is a small, coherent change that leaves the project in a reasonable state. Examples include:

- `Add maize data preparation script`
- `Correct yield unit conversion`
- `Document how to restore the renv environment`
- `Add country-level yield figure`

Messages such as `changes`, `stuff`, or `final` do not explain the purpose of a commit.

A practical workflow is:

```bash
git status
git diff
git add path/to/file
git diff --staged
git commit -m "Describe the completed change"
git push
```

Reviewing `git status`, the unstaged diff, and the staged diff reduces the risk of committing temporary files, data, credentials, or unrelated work.

## What Git should not track

Not every project file belongs in version control. A `.gitignore` file commonly excludes:

- downloaded or reproducibly generated data;
- rendered reports and temporary figures;
- package libraries and caches;
- editor-specific state;
- logs; and
- `.env` files or other secrets.

Never commit passwords, access tokens, private SSH keys, or confidential data. Removing a secret in a later commit does not remove it from earlier history.

## How this connects to the maize yield project

In this repository:

- analysis steps are separated into numbered scripts;
- `renv.lock` records the R package environment;
- the Quarto source records the report's code and narrative;
- `.gitignore` excludes reproducible or machine-specific artifacts; and
- Git history can connect changes in scripts to changes in results.

Git and GitHub are therefore part of the scientific workflow, not only tools for software developers.

## Check your understanding

1. What is the difference between saving a file and committing it?
2. What is the difference between committing and pushing?
3. Why might a raw dataset be excluded from Git?
4. What information should a commit message communicate?
5. How could Git help identify when an analysis result changed?

## Videos

The following videos provide an alternative introduction to the concepts in this guide:

- [Git and GitHub for Beginners: What are Git and version control?](https://www.youtube.com/watch?v=RGOj5yH7evk&t=70s) — freeCodeCamp, starting at the explanation of Git and version control.
- [GitHub for Beginners](https://www.youtube.com/playlist?list=PL0lo9MOBetEFcp4SCWinBdpml9B2U25-f) — GitHub's official beginner video series covering repositories, collaboration, and common workflows.

The freeCodeCamp video is a longer course. The link opens at the section most relevant to this guide; continue watching if you would like to see the concepts applied at the command line.

## Further reading

- [About version control — Pro Git](https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control)
- [Getting started with Git — GitHub Docs](https://docs.github.com/en/get-started/learning-to-code/getting-started-with-git)
- [Git cheat sheet](https://git-scm.com/cheat-sheet.pdf)
