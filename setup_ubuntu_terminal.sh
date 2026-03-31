#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-my-ubuntu}"
UBUNTU_IMAGE="${UBUNTU_IMAGE:-ubuntu:24.04}"
DESKTOP_NAME="${DESKTOP_NAME:-Ubuntu Terminal}"
INSTALL_NODE="${INSTALL_NODE:-1}"

LOCAL_BIN_DIR="${HOME}/.local/bin"
LOCAL_APP_DIR="${HOME}/.local/share/applications"
WRAPPER_PATH="${LOCAL_BIN_DIR}/ubuntu-terminal"
DESKTOP_FILE="${LOCAL_APP_DIR}/ubuntu-terminal.desktop"
BASHRC_PATH="${HOME}/.bashrc"

log() {
    printf '\n[setup] %s\n' "$*"
}

warn() {
    printf '\n[warn] %s\n' "$*" >&2
}

die() {
    printf '\n[error] %s\n' "$*" >&2
    exit 1
}

require_host_arch() {
    if [ -n "${CONTAINER_ID:-}" ]; then
        die "Run this script on the Arch host, not inside the Ubuntu container."
    fi

    if ! command -v pacman >/dev/null 2>&1; then
        die "pacman was not found. This script is intended for Arch Linux hosts."
    fi
}

ensure_host_packages() {
    log "Installing required host packages"
    sudo pacman -S --needed distrobox podman
}

ensure_subid_mapping() {
    log "Ensuring /etc/subuid and /etc/subgid exist"
    sudo touch /etc/subuid /etc/subgid

    if ! grep -q "^${USER}:" /etc/subuid 2>/dev/null; then
        log "Adding subuid range for ${USER}"
        sudo usermod --add-subuids 100000-165535 "${USER}"
    else
        log "Subuid mapping already exists for ${USER}"
    fi

    if ! grep -q "^${USER}:" /etc/subgid 2>/dev/null; then
        log "Adding subgid range for ${USER}"
        sudo usermod --add-subgids 100000-165535 "${USER}"
    else
        log "Subgid mapping already exists for ${USER}"
    fi

    log "Migrating Podman storage"
    podman system migrate || true
}

container_exists() {
    podman container exists "${CONTAINER_NAME}" 2>/dev/null
}

create_container() {
    if container_exists; then
        log "Container ${CONTAINER_NAME} already exists"
        return
    fi

    log "Creating Ubuntu container ${CONTAINER_NAME} from ${UBUNTU_IMAGE}"
    distrobox create -i "${UBUNTU_IMAGE}" -n "${CONTAINER_NAME}"
}

run_in_container() {
    distrobox enter "${CONTAINER_NAME}" -- sh -lc "$1"
}

configure_container() {
    log "Updating Ubuntu package lists with IPv4 forced"
    run_in_container 'sudo apt -o Acquire::ForceIPv4=true update'

    if [ "${INSTALL_NODE}" = "1" ]; then
        log "Installing nano, curl, ca-certificates, nodejs, and npm inside Ubuntu"
        run_in_container 'sudo DEBIAN_FRONTEND=noninteractive apt install -y nano curl ca-certificates nodejs npm'
    else
        log "Installing nano, curl, and ca-certificates inside Ubuntu"
        run_in_container 'sudo DEBIAN_FRONTEND=noninteractive apt install -y nano curl ca-certificates'
    fi

    log "Creating NVM compatibility shim inside Ubuntu"
    run_in_container 'sudo mkdir -p /usr/share/nvm && printf "%s\n" "# Distrobox compatibility shim for shared Arch .bashrc" "return 0 2>/dev/null || true" | sudo tee /usr/share/nvm/init-nvm.sh >/dev/null && sudo chmod 0644 /usr/share/nvm/init-nvm.sh'
}

write_wrapper_script() {
    log "Writing launcher wrapper to ${WRAPPER_PATH}"
    mkdir -p "${LOCAL_BIN_DIR}"

    cat > "${WRAPPER_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec distrobox enter "${CONTAINER_NAME}"
EOF

    chmod +x "${WRAPPER_PATH}"
}

write_desktop_file() {
    log "Writing desktop entry to ${DESKTOP_FILE}"
    mkdir -p "${LOCAL_APP_DIR}"

    cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Name=${DESKTOP_NAME}
Comment=Ubuntu container via Distrobox
Exec=${WRAPPER_PATH}
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=System;TerminalEmulator;
StartupNotify=true
EOF

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${LOCAL_APP_DIR}" >/dev/null 2>&1 || true
    fi
}

append_container_prompt() {
    log "Appending container-only prompt block to ${BASHRC_PATH}"

    if [ ! -f "${BASHRC_PATH}" ]; then
        touch "${BASHRC_PATH}"
    fi

    if grep -qF "# >>> ubuntu-terminal prompt >>>" "${BASHRC_PATH}"; then
        log "Prompt block already present in ${BASHRC_PATH}"
        return
    fi

    cat >> "${BASHRC_PATH}" <<'EOF'

# >>> ubuntu-terminal prompt >>>
if [ -n "${CONTAINER_ID:-}" ]; then
    PS1="\u@${CONTAINER_ID}:\w\$ "
fi
# <<< ubuntu-terminal prompt <<<
EOF
}

print_summary() {
    printf '\n'
    printf 'Setup complete.\n'
    printf '\n'
    printf 'Open "%s" from your app launcher, or run:\n' "${DESKTOP_NAME}"
    printf '  %s\n' "${WRAPPER_PATH}"
    printf '\n'
    printf 'Verify Ubuntu with:\n'
    printf '  distrobox enter %s -- cat /etc/os-release\n' "${CONTAINER_NAME}"
    printf '\n'
    printf 'If apt stalls, use:\n'
    printf '  sudo apt -o Acquire::ForceIPv4=true update\n'
    printf '\n'
    printf 'Close the Ubuntu terminal cleanly with:\n'
    printf '  exit\n'
    printf '\n'
}

main() {
    require_host_arch
    ensure_host_packages
    ensure_subid_mapping
    create_container
    configure_container
    write_wrapper_script
    write_desktop_file
    append_container_prompt
    print_summary
}

main "$@"
