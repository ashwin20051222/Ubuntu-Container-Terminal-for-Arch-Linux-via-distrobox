# Ubuntu Container Terminal for Arch Linux via Distrobox

This project sets up a separate **Ubuntu Terminal** application on an Arch Linux host using **Distrobox** and **Podman**.

It gives you:

- A real Ubuntu 24.04 container you can enter with `apt`
- A separate launcher named **Ubuntu Terminal**
- A shared home directory with your Arch user
- A clean prompt that shows the container name
- Fixes for the repeated shared-shell issues like:
  - `bash: /usr/share/nvm/init-nvm.sh: No such file or directory`
  - `bash: npm: command not found`
  - `apt update` hanging at `0% [Waiting for headers]`

## What This Does

The setup uses:

- **Arch Linux** as the host OS
- **Podman** as the container engine
- **Distrobox** to create and manage the Ubuntu user environment
- **Ubuntu 24.04** as the container image

This means:

- `pacman` stays on Arch
- `apt` stays inside Ubuntu
- Both environments share the same Linux kernel
- Your home folder is shared between host and container

## Files In This Project

- `README.md`
- `setup_ubuntu_terminal.sh`

## Quick Start

Run this on the **Arch host**, not inside the Ubuntu container:

```bash
chmod +x setup_ubuntu_terminal.sh
./setup_ubuntu_terminal.sh
```

After the script finishes:

- Search your app launcher for `Ubuntu Terminal`
- Or run:

```bash
~/.local/bin/ubuntu-terminal
```

## What The Script Configures

The script will:

1. Install `distrobox` and `podman` with `pacman`
2. Ensure `/etc/subuid` and `/etc/subgid` are configured for your user
3. Run `podman system migrate`
4. Create a Distrobox container named `my-ubuntu`
5. Run `apt update` with IPv4 forced
6. Install useful packages inside Ubuntu:
   - `nano`
   - `curl`
   - `ca-certificates`
   - `nodejs`
   - `npm`
7. Create an NVM compatibility shim inside Ubuntu to stop the shared `.bashrc` error
8. Create a launcher script at `~/.local/bin/ubuntu-terminal`
9. Create a desktop entry at `~/.local/share/applications/ubuntu-terminal.desktop`
10. Append a container-only prompt block to `~/.bashrc`

## Verify The Container

Open the Ubuntu terminal and run:

```bash
cat /etc/os-release
```

Expected output includes:

```text
PRETTY_NAME="Ubuntu 24.04..."
```

You can also test `apt`:

```bash
sudo apt -o Acquire::ForceIPv4=true update
```

## Why This Does Not Break Arch

This setup does **not** replace Arch.

- Arch remains your host OS
- Ubuntu runs inside a container
- Ubuntu uses the Arch kernel
- Packages installed with `apt` stay in the Ubuntu container
- Packages installed with `pacman` stay on Arch

The only shared part is mostly your home directory, which is why shared shell config like `.bashrc` can affect both environments.

## Common Notes

### 1. Prompt still looks like Arch

That usually happens because the host `.bashrc` is shared. This project appends a container-only prompt fix so the shell shows:

```text
user@my-ubuntu:~$
```

### 2. `bash: /usr/share/nvm/init-nvm.sh: No such file or directory`

This happens when your Arch `.bashrc` tries to source an NVM file path that does not exist inside Ubuntu.

The script creates a safe compatibility file in:

```text
/usr/share/nvm/init-nvm.sh
```

### 3. `bash: npm: command not found`

The script installs `nodejs` and `npm` inside Ubuntu to avoid this error when your shared shell config expects them.

### 4. `apt update` hangs at `0% [Waiting for headers]`

Use:

```bash
sudo apt -o Acquire::ForceIPv4=true update
```

The setup script already uses that form during provisioning.

### 5. Closing the terminal shows a warning

That is normal for terminal apps when `podman` is still attached.

Close the container cleanly with:

```bash
exit
```

## Optional Customization

You can override defaults when running the script:

```bash
CONTAINER_NAME=ubuntu-dev UBUNTU_IMAGE=ubuntu:24.04 DESKTOP_NAME="Ubuntu Terminal" ./setup_ubuntu_terminal.sh
```

Available environment variables:

- `CONTAINER_NAME`
- `UBUNTU_IMAGE`
- `DESKTOP_NAME`
- `INSTALL_NODE`

Example without Node/NPM installation:

```bash
INSTALL_NODE=0 ./setup_ubuntu_terminal.sh
```

## Recovery If A Container Gets Corrupted

Run these on the Arch host:

```bash
podman kill --all
podman system reset --force
sudo rm -rf ~/.local/share/containers
```

Then run the setup script again.

Use this only when the container state is clearly broken.

## Result

You end up with:

- A separate Ubuntu terminal app
- Ubuntu package management with `apt`
- Arch host package management with `pacman`
- Shared files, but separated userland environments
- No VM required

---

<p align="center">Made with Ashwin S ❤️</p>
# Ubuntu-Container-Terminal-for-Arch-Linux-via-distrobox
