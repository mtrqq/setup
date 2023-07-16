#!/usr/bin/env bash

set -e

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

if ! prompt "Proceed with the installation?"; then
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

function install_brew() {
    HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    if [[ ! -x "${HOMEBREW_PREFIX}/bin/brew" ]]; then
        git clone "${HOMEBREW_BREW_GIT_REMOTE:-https://github.com/Homebrew/brew}" "${HOME}/.linuxbrew/Homebrew"
        mkdir "${HOME}/.linuxbrew/bin"
        ln -sfn "${HOME}/.linuxbrew/Homebrew/bin/brew" "${HOME}/.linuxbrew/bin"
    fi
    eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"
    brew update --force --quiet
}

function install_vscode() {
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
    sudo apt install code -y
}

function install_dependencies() {
    if command -v apt > /dev/null 2>&1; then
        sudo apt update -y
        sudo apt install -y curl ca-certificates gnupg build-essential wget
    elif command -v yum > /dev/null 2>&1; then
        sudo yum update -y
        sudo yum install -y curl ca-certificates gnupg wget
        sudo yum groupinstall -y "Development Tools"
    elif command -v dnf > /dev/null 2>&1; then
        sudo dnf update -y
        sudo dnf install -y curl ca-certificates gnupg wget
        sudo dnf groupinstall -y "Development Tools"
    else
        echo "Unsupported package manager. Please install either 'apt', 'yum', or 'dnf'."
        exit 1
    fi
}

function main() {
    # welcome

    install_dependencies

    install_if_needed "brew" install_brew
    install_if_needed "code" install_vscode

    install_if_needed "tfswitch" brew install warrensbox/tap/tfswitch
    install_if_needed "pyenv" brew install pyenv
    install_if_needed "goenv" brew install goenv
    install_if_needed "docker" brew install docker
    install_if_needed "aws" brew install awscli
    install_if_needed "k3d" brew install k3d
    install_if_needed "kubectl" brew install kubernetes-cli
    install_if_needed "helm" brew install helm
    install_if_needed "k9s" brew install k9s

    # post_installation
}

main "$@"
