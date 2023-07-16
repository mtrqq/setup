#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
then
    echo "Installation should only be run with elevated permissions"
    exit 1
fi

function prompt {
    local retries=3
    local response

    while [[ $retries -gt 0 ]]; do
        read -p "$1 (y/N): " response

        case "$response" in
            [Yy])
                return 0  # true (0) for "yes"
                ;;
            [Nn]|"")
                return 1  # false (1) for "no" or empty input
                ;;
            *)
                ((retries--))
                echo "Unrecognized input. Please enter 'y' or 'n'. $retries retries left."
                ;;
        esac
    done

    return 1  # If retries are exhausted, return false (1) for "no" or empty input
}

# Function to check and install an executable
function install_if_needed {
    local executable_name=$1
    shift
    local install_command=$@

    if ! command -v "$executable_name" > /dev/null 2>&1; then
        echo "Installing $executable_name..."
        $install_command
    else
        echo "$executable_name is already installed, skip installation"
    fi
}

function welcome() {
    cat << EOM
Before we begin installation, ensure you have the following:

1. Brew Package Manager - refer to https://brew.sh/ for installation instructions
2. Snapd - refer to https://snapcraft.io/docs/installing-snapd for installation instructions
EOM

if !prompt "Proceed with the installation?"; then
    echo "Exiting..."
    exit 0
fi
}

function post_installation() {
    cat << EOM
Embrace the magic of software! ✨

1. Add to ~/.zshrc or ~/.bashrc:
   eval "\$(pyenv init -)"
   eval "\$(goenv init -)"

2. Unleash the power of Docker:
   sudo groupadd docker
   sudo usermod -aG docker \$USER
   newgrp docker
EOM
}

function install_dependencies() {
    if command -v apt > /dev/null 2>&1; then
        echo "Updating package list..."
        apt update
        echo "Installing required packages..."
        apt install -y curl ca-certificates gnupg build-essential
    elif command -v yum > /dev/null 2>&1; then
        echo "Updating package list..."
        yum update -y
        echo "Installing required packages..."
        yum install -y curl ca-certificates gnupg
        yum groupinstall -y "Development Tools"
    elif command -v dnf > /dev/null 2>&1; then
        echo "Updating package list..."
        dnf update -y
        echo "Installing required packages..."
        dnf install -y curl ca-certificates gnupg
        dnf groupinstall -y "Development Tools"
    else
        echo "Unsupported package manager. Please install either 'apt', 'yum', or 'dnf'."
        exit 1
    fi
}

function main() {
    welcome

    install_dependencies

    install_if_needed "tfswitch" brew install warrensbox/tap/tfswitch
    install_if_needed "pyenv" brew install pyenv
    install_if_needed "goenv" brew install goenv
    install_if_needed "docker" brew install docker

    if prompt "Install VS Code?"; then
        if ! command -v "snap" > /dev/null 2>&1; then
            echo "Snapd should be installed in order to install VS Code"
        else
            snap install --classic code
         fi
    fi

    if prompt "Install AWS CLI?"; then
        brew install awscli
    fi

    if prompt "Install Kubernetes tooling?"; then
        brew install k3d kubernetes-cli helm k9s
    fi

    post_installation
}

main "$@"