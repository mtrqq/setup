#!/usr/bin/env bash

set -e

function log() {
    local timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "$timestamp $1"
}

function install_if_needed {
    local executable_name=$1
    shift
    local install_command=$@

    if ! command -v "$executable_name" > /dev/null 2>&1; then
        log "Installing $executable_name..."
        $install_command
    else
        log "$executable_name is already installed, skip installation"
    fi
}

function prompt() {
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

function install_brew() {
    HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    if [[ ! -x "${HOMEBREW_PREFIX}/bin/brew" ]]; then
        git clone "${HOMEBREW_BREW_GIT_REMOTE:-https://github.com/Homebrew/brew}" "${HOME}/.linuxbrew/Homebrew"
        mkdir "${HOME}/.linuxbrew/bin"
        ln -sfn "${HOME}/.linuxbrew/Homebrew/bin/brew" "${HOME}/.linuxbrew/bin"
    fi
    eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"
    echo 'eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"' >> ${HOME}/.zprofile
    brew update --force --quiet
}

function install_vscode() {
    if command -v apt > /dev/null 2>&1; then
        wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
        sudo apt install code -y
    elif command -v yum > /dev/null 2>&1; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        yum check-update
        sudo yum install code
    elif  command -v dnf > /dev/null 2>&1; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        dnf check-update
        sudo dnf install code
    else
        log "Unsupported package manager. Please install either 'apt', 'yum', or 'dnf'."
        exit 1
    fi
}

add_zsh_plugin() {
    local plugin_name=$1
    if ! grep -q "plugins=.*$plugin_name" ~/.zshrc; then
        sed -i'' -E 's/(^plugins=\([^)]*)/\1 '"$plugin_name"'/' ~/.zshrc
    fi
}

function install_zsh() {
    install_if_needed "zsh" sudo apt install zsh -y

    if grep -qF '/usr/bin/zsh' /etc/shells; then
		sudo chsh --shell /usr/bin/zsh ${USER}
	elif grep -qF '/bin/zsh' /etc/shells; then
        sudo chsh --shell /bin/zsh ${USER}
	fi

    # Install Oh-My-Zsh
    export ZSH="${ZSH:-"${HOME}/.oh-my-zsh"}"
    export ZSH_CUSTOM="${ZSH_CUSTOM:-"${ZSH}/custom"}"
    export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-"${ZSH}/cache"}"

    if [[ -d "${ZSH}/.git" && -f "${ZSH}/tools/upgrade.sh" ]]; then
        rm -f "${ZSH_CACHE_DIR}/.zsh-update" 2>/dev/null
        zsh "${ZSH}/tools/check_for_upgrade.sh" 2>/dev/null
        zsh "${ZSH}/tools/upgrade.sh" 2>&1
    fi

    # Install Powerlevel10k theme and Zsh plugins
    while read -r repo target; do
        if [[ ! -d "${ZSH_CUSTOM}/${target}/.git" ]]; then
            git clone --depth=1 https://github.com/${repo}.git "${ZSH_CUSTOM}/${target}" 2>&1
        else
            git -C "${ZSH_CUSTOM}/${target}" pull --ff-only 2>&1
        fi
    done <<EOS
romkatv/powerlevel10k             themes/powerlevel10k
zsh-users/zsh-syntax-highlighting plugins/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions     plugins/zsh-autosuggestions
zsh-users/zsh-completions         plugins/zsh-completions
EOS

    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    # Set the oh-my-zsh theme to "af-magic"
    log "Setting oh-my-zsh theme to 'af-magic'... (from default one)"
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="af-magic"/' ${HOME}/.zshrc

    # Add zsh plugins
    add_zsh_plugin "kubectl"
    add_zsh_plugin "aws"
    add_zsh_plugin "helm"
    add_zsh_plugin "terraform"
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
        log "Unsupported package manager. Please install either 'apt', 'yum', or 'dnf'."
        exit 1
    fi
}

function main() {
    log "Installing dependencies..."
    install_dependencies

    log "Installing Homebrew..."
    install_if_needed "brew" install_brew

    log "Installing Visual Studio Code..."
    install_if_needed "code" install_vscode

    log "Installing tools..."
    install_if_needed "tfswitch" brew install warrensbox/tap/tfswitch
    install_if_needed "pyenv" brew install pyenv
    install_if_needed "goenv" brew install goenv
    install_if_needed "docker" brew install docker
    install_if_needed "aws" brew install awscli
    install_if_needed "k3d" brew install k3d
    install_if_needed "kubectl" brew install kubernetes-cli
    install_if_needed "helm" brew install helm
    install_if_needed "k9s" brew install k9s

    if prompt "Install Zsh?"; then
        log "Installing zsh..."
        install_zsh
    fi

    log "Installation completed."
}

main "$@"
