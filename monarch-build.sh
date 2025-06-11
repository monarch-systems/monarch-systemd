#!/bin/bash
#
# Systemd Builder for Monarch Linux 
# 
# This script is intended for building systemd into a *chroot environment*

# --- Configuration ---
# Path to the systemd source directory (where the git repo will be cloned)

SYSTEMD_SRC_DIR="/usr/local/src/systemd"
# Path to your chroot environment where systemd will be installed
# IMPORTANT: CHANGE THIS TO YOUR ACTUAL CHROOT PATH!
CHROOT_INSTALL_DIR="/home/void/monarch-rootfs" 
# Number of parallel jobs for compilation (adjust based on your CPU cores)
MAKE_JOBS=$(nproc)

# --- Dependency List ---
# These are the development packages required for systemd to compile successfully on Monarch Linux.
# Based on your previous successful compilation and dependency output.
declare -a SYSTEMD_DEPS=(
    "libmount-devel"
    "libselinux-devel"
    "libkmod-devel"
    "libaudit-devel"
    "libgcrypt-devel"
    "libgpg-error-devel"
    "dbus-devel"
    "libpwquality-devel"
    "passwdqc-devel"
    "libapparmor-devel"
    "polkit-devel"
    "libiptcdata-devel" 
    "qrencode-devel"
    "libfido2-devel"
    "tpm2-tss-devel"
    "libxkbcommon-devel"
    "pcre2-devel"
    "glib-devel"
    "git"
    "meson"
    "ninja"
    "pkg-config"
    "gcc"
    "make"
)

# display error messages and exit

die() {
    echo -e "\n\033[0;31mERROR:\033[0m $1" >&2
    exit 1
}

# check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root. Please use sudo."
    fi
}

confirm_action() {
    read -rp "$1 (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}


echo -e "\033[0;36m"
echo "---------------------------------------------------------"
echo "  Systemd Builder & Installer for Monarch Linux"
echo "---------------------------------------------------------"
echo -e "\033[0m"

check_root

echo -e "\033[0;33m"
echo "ATTENTION: This script will install systemd into the specified chroot."
echo "Your chroot path is set to: $CHROOT_INSTALL_DIR"
echo -e "\033[0m"

if ! confirm_action "Do you wish to proceed?"; then
    die "Operation cancelled by user."
fi

# 1. Install Build Dependencies
echo -e "\n\033[0;32m[*] Installing necessary build dependencies...\033[0m"
xbps-install -S "${SYSTEMD_DEPS[@]}" || die "Failed to install dependencies."
echo -e "\033[0;32m[*] Dependencies installed successfully.\033[0m"

# 2. Prepare Source Directory
echo -e "\n\033[0;32m[*] Preparing systemd source directory...\033[0m"
if [[ -d "$SYSTEMD_SRC_DIR/.git" ]]; then
    echo "    - systemd repository already exists. Pulling latest changes..."
    pushd "$SYSTEMD_SRC_DIR" > /dev/null || die "Failed to change directory to $SYSTEMD_SRC_DIR."
    git pull || die "Failed to pull latest systemd changes."
    popd > /dev/null || die "Failed to return to previous directory."
else
    echo "    - Cloning systemd repository..."
    git clone https://github.com/monarch-systems/monarch-systemd.git "$SYSTEMD_SRC_DIR" || die "Failed to clone systemd repository."
fi

if [[ ! -d "$SYSTEMD_SRC_DIR" ]]; then
    die "Systemd source directory $SYSTEMD_SRC_DIR does disabledt exist after cloning."
fi

pushd "$SYSTEMD_SRC_DIR" > /dev/null || die "Failed to change directory to $SYSTEMD_SRC_DIR."

# 3. Clean Previous Build
echo -e "\n\033[0;32m[*] Cleaning previous build directory...\033[0m"
if [[ -d "build" ]]; then
    rm -rf build || die "Failed to remove old build directory."
    echo "    - Removed existing 'build' directory."
else
    echo "    - No existing 'build' directory found."
fi

# 4. Configure Build with Meson
echo -e "\n\033[0;32m[*] Configuring systemd build with Meson...\033[0m"
# We explicitly set --prefix=/usr so that files are laid out correctly
# when DESTDIR is applied during installation.
meson build --prefix=/usr -Dpam=enabled -Dlogind=enabled || die "Meson configuration failed."
echo -e "\033[0;32m[*] Meson configuration successful.\033[0m"

# 5. Compile with Ninja
echo -e "\n\033[0;32m[*] Compiling systemd with Ninja (using $MAKE_JOBS jobs)...\033[0m"
ninja -C build -j "$MAKE_JOBS" || die "Ninja compilation failed."
echo -e "\033[0;32m[*] Compilation successful.\033[0m"

# 6. Install to Chroot
echo -e "\n\033[0;32m[*] Installing systemd into chroot: $CHROOT_INSTALL_DIR ...\033[0m"
# DESTDIR ensures all paths are prefixed by your chroot path
DESTDIR="$CHROOT_INSTALL_DIR" ninja -C build install || die "Systemd installation to chroot failed."
echo -e "\033[0;32m[*] Systemd installed successfully into $CHROOT_INSTALL_DIR.\033[0m"

# Return to original directory
popd > /dev/null || die "Failed to return to original directory."

echo -e "\n\033[0;32m"
echo "---------------------------------------------------------"
echo "  systemd Build and Installation Complete!"
echo "---------------------------------------------------------"
echo -e "\033[0m"
echo "Remember, you have installed systemd into your chroot at:"
echo "  $CHROOT_INSTALL_DIR"
echo "Further configuration will be needed INSIDE the chroot"
echo "to make systemd the active init system there."
echo -e "\033[0;31m"
echo "REITERATING WARNING: DO NOT TRY TO BOOT YOUR NATIVE VOID"
echo "LINUX SYSTEM WITH THIS COMPILED SYSTEMD. IT IS FOR THE"
echo "CHROOT ENVIRONMENT ONLY."
echo -e "\033[0m"
