# Why learn SSH and the Linux command line?

## Learning objectives

After reading this guide, you should be able to:

- explain why command-line skills are useful in data science;
- distinguish a terminal, a shell, and Linux;
- explain what SSH provides;
- distinguish SSH access to GitHub from an SSH session on a remote server; and
- identify basic security practices for remote work.

## From a laptop to other computers

An analysis may begin on a laptop but later run somewhere else:

- in a Docker container;
- on a university server or computing cluster;
- on a cloud virtual machine; or
- as an automated task without a graphical desktop.

These systems are commonly controlled through text commands. A small vocabulary of
Linux commands makes the same workflow usable across many systems, while SSH makes
it possible to reach a remote system securely over a network.

## Linux, terminal, and shell are related but different

The terms are often used interchangeably, but they describe different things:

- **Linux** is an operating-system kernel and, informally, a family of operating
  systems built around it.
- A **terminal** is the window or application through which you enter text commands.
- A **shell** is the program that reads and runs those commands. Bash is a common
  shell and is the one used in this course's container examples.
- The **command line** is the text-based way of interacting with the shell.

A macOS terminal also provides a Unix-like command line. On Windows, students can
use a terminal with tools such as Git Bash or Windows Subsystem for Linux, depending
on the course setup.

## Why the command line matters in data science

### The same instructions can be repeated

A graphical action can be difficult to describe precisely: "click this button,
select that file, and change this option." A command records the operation directly:

```bash
Rscript scripts/run-all.R
```

Commands can be copied into documentation or scripts, reviewed, and repeated. This
supports reproducibility, although a command is reproducible only when its inputs,
software environment, and assumptions are also documented.

### Small tools can be combined

Linux commands often do one focused task. Pipes connect them:

```bash
find scripts -type f | sort
```

Here, `find` produces a list and `sort` orders it. This composability is useful for
inspecting files, filtering logs, and automating routine work.

### Remote systems often have no desktop

Servers and containers are commonly smaller and easier to automate when they do not
run a graphical interface. The command line therefore becomes the shared interface
between your laptop, a container, and a remote computing system.

### It helps you see the computing context

Commands such as `pwd`, `whoami`, and `hostname` answer three important questions:

```text
Where am I?    Which user am I?    Which computer am I using?
```

These questions prevent many mistakes when several terminals, containers, or remote
servers are open at the same time.

## What SSH provides

SSH stands for **Secure Shell**. It is a protocol and a collection of tools for
encrypted communication between computers. SSH can be used to:

- authenticate with a password or cryptographic key;
- open a command-line session on a remote server;
- run a command remotely;
- transfer files with tools such as `scp` or `sftp`; and
- carry Git traffic between a local repository and GitHub.

Encryption protects data in transit. Authentication establishes which account is
connecting. Authorization still determines what that account is allowed to do.

## Two SSH uses in this course

### GitHub repository access

An SSH Git remote can look like:

```text
git@github.com:mmoessler/maize-yield-project.git
```

Git uses SSH to authenticate and exchange repository data. GitHub does **not** give
you a general-purpose interactive shell on its servers. The account name in this
URL is normally the literal `git`; GitHub identifies your personal account from
the public key you registered.

### Remote computing

A server login commonly looks like:

```bash
ssh student@login.example.edu
```

After authentication, this opens a shell on another computer. Commands entered
there run on that remote computer and use its files, software, memory, and CPU.
The hostname and username for a real course server must come from the instructor or
system administrator.

## Public-key authentication

An SSH key pair contains:

- a **private key**, which remains secret on your computer; and
- a **public key**, which may be registered with GitHub or placed on a server.

The private key proves your identity. Never send it to another person, commit it to
Git, or copy it into a course container. Protect it with a strong passphrase when
practical.

On the first connection, SSH may ask whether you trust a host key. This key
identifies the server, not you. Verify its fingerprint through an official,
independent source before accepting it. If SSH later warns that a host key changed,
stop and contact the administrator rather than bypassing the warning.

## Command-line care

Text commands are exact and can change many files quickly. Before pressing Enter:

- confirm whether the prompt is local, inside a container, or on a remote server;
- use `pwd`, `hostname`, and `git status` to establish context;
- read unfamiliar commands and options instead of pasting them blindly;
- treat `sudo`, recursive deletion, and output redirection with particular care;
- do not expose passwords, tokens, private keys, or confidential data; and
- log out with `exit` when remote work is complete.

Linux expertise is not memorizing every command. It is understanding paths,
permissions, input and output, and knowing how to consult `--help`, manual pages,
and trustworthy documentation.

## How this connects to the maize yield project

The project combines these ideas:

```text
local computer
├── Git over SSH ───────────────► GitHub repository
├── Docker ─────────────────────► Linux container at /work
└── SSH login (when provided) ──► remote Linux server
```

The Git repository records the project. The Docker image supplies a controlled
Linux and R environment. SSH can move Git data to GitHub or provide access to a
larger remote computer. The same core command-line habits apply in each setting.

## Check your understanding

1. What is the difference between a terminal and a shell?
2. Why are text commands useful for reproducible work?
3. How does SSH use differ between GitHub and a remote computing server?
4. Which part of an SSH key pair may be shared?
5. What should you do before accepting an unfamiliar host fingerprint?

## Videos

- [Bash/Terminal Crash Course for Beginners](https://www.youtube.com/watch?v=oxuRxtrO2Ag) — Traversy Media; a practical introduction to navigation, files, pipes, and common shell commands.
- [SSH Crash Course](https://www.youtube.com/watch?v=hQWRp-FdTpc) — Traversy Media; introduces SSH keys, remote connections, and related tools.
- [SSH key authentication for GitHub](https://www.youtube.com/watch?v=ZgARMqR3qq8) — GitHub; focuses on configuring an SSH key for GitHub.

The first two are broad tutorials. Use the application guides in this repository
for the commands and safety boundaries specific to the maize yield project.

## Further reading

- [The Linux command line for beginners — Ubuntu](https://ubuntu.com/desktop/docs/en/latest/tutorial/the-linux-command-line-for-beginners/)
- [The Unix Shell — Software Carpentry](https://swcarpentry.github.io/shell-novice/)
- [Secure Shell introduction — Ubuntu](https://ubuntu.com/server/docs/openssh-introduction)
- [About SSH — GitHub Docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/about-ssh)
