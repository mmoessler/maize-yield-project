# Set up Git and GitHub

## Learning objectives

After completing this guide, you should be able to:

- confirm that Git is installed;
- create and secure a GitHub account;
- configure the identity attached to your commits;
- authenticate to GitHub with SSH; and
- test your setup.

The commands in this guide are entered in a terminal. On Windows, use Git Bash unless your instructor specifies another terminal.

## 1. Install Git

First, check whether Git is already installed:

```bash
git --version
```

If the command prints a version number, continue to the next section.

### Windows

Download and run [Git for Windows](https://git-scm.com/download/win). The default installation choices are suitable for this course. Git for Windows
includes Git Bash.

After installation, open **Git Bash** and run:

```bash
git --version
```

### macOS

In Terminal, run:

```bash
git --version
```

If Git is missing, macOS may offer to install the Command Line Tools. Follow the prompt. Alternatively, use the installer from
[git-scm.com](https://git-scm.com/download/mac).

### Ubuntu or Debian Linux

```bash
sudo apt update
sudo apt install git
git --version
```

For another Linux distribution, follow its package manager's instructions or the [official Git installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

## 2. Create a GitHub account

1. Go to [github.com](https://github.com/).
2. Select **Sign up** and create a free personal account.
3. Choose a professional username that you are comfortable sharing.
4. Use a unique, strong password.
5. Verify your email address.
6. Enable two-factor authentication and store the recovery codes safely.

Your GitHub username will be used in repository addresses later. It does not have to match your computer username.

GitHub's current account instructions are available in [Creating an account on GitHub](https://docs.github.com/en/get-started/start-your-journey/creating-an-account-on-github).

## 3. Configure your Git identity

Git records a name and email address in every commit. Set them globally for your user account on this computer:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Use an email address associated with your GitHub account if you want GitHub to link your commits to your profile. If you prefer not to expose your address, GitHub provides a `noreply` commit email under **Settings → Emails**.

Set `main` as the initial branch name for new repositories:

```bash
git config --global init.defaultBranch main
```

Review the configuration:

```bash
git config --global --list
```

Check that `user.name`, `user.email`, and `init.defaultbranch` have the intended values. Do not copy another student's identity.

For more detail, see [Set up Git — GitHub Docs](https://docs.github.com/en/get-started/git-basics/set-up-git).

## 4. Check for an existing SSH key

SSH allows Git to authenticate securely to GitHub without entering your GitHub password for every push.

List any existing public keys:

```bash
ls -al ~/.ssh
```

Look for a matching pair such as:

```text
id_ed25519
id_ed25519.pub
```

The file ending in `.pub` is the **public key**. The file without `.pub` is the **private key**. Never share, upload, email, or commit the private key.

If an existing key is already used for GitHub, ask your instructor before replacing it. Otherwise, continue with the next section.

## 5. Generate an SSH key

Replace the example email with the address associated with your GitHub account:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

When prompted:

1. Press Enter to accept the default file location, unless that would overwrite a key you need.
2. Enter a strong passphrase.
3. Enter the passphrase again.

On an older system that does not support Ed25519, consult GitHub's [SSH key instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

## 6. Add the key to the SSH agent

Start the agent:

```bash
eval "$(ssh-agent -s)"
```

On Linux or Git Bash, add the default Ed25519 key:

```bash
ssh-add ~/.ssh/id_ed25519
```

On macOS, use:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Enter the key's passphrase if requested.

## 7. Add the public key to GitHub

Display the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the complete line beginning with `ssh-ed25519`. Sharing this public key is safe; do not display or copy the file without `.pub`.

On GitHub:

1. Open your profile menu and select **Settings**.
2. Select **SSH and GPG keys**.
3. Select **New SSH key**.
4. Give the key a descriptive title, such as `Personal laptop`.
5. Keep the key type as **Authentication Key**.
6. Paste the public key and select **Add SSH key**.

## 8. Test the connection

Run:

```bash
ssh -T git@github.com
```

On the first connection, SSH may ask whether you trust the host. Compare the displayed fingerprint with GitHub's published fingerprints before entering
`yes`.

A successful response includes your GitHub username and explains that GitHub does not provide shell access. The command may still return exit status 1;
that is expected because this test authenticates you but does not open an interactive shell.

See [Testing your SSH connection — GitHub Docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection) for expected output and troubleshooting.

## Final checklist

Run these commands:

```bash
git --version
git config user.name
git config user.email
ssh -T git@github.com
```

You are ready for the repository setup exercise when:

- Git reports a version;
- the configured name and email are yours; and
- GitHub's SSH response contains your GitHub username.

## Common problems

### `git: command not found`

Git is not installed or the terminal has not detected the new installation. Install Git, close the terminal, open it again, and retry.

### `Permission denied (publickey)`

Confirm that:

- the public key was added to the correct GitHub account;
- the private key was added to the SSH agent; and
- `ssh-add -l` lists the expected key.

### Commits appear under the wrong identity

Check:

```bash
git config --show-origin --get-regexp "^user\\."
```

Correct the global name or email with the commands in section 3. Repository- specific configuration can override the global configuration.

### SSH warns that the host key has changed

Do not bypass the warning. Stop and ask your instructor or system administrator to verify the connection.
