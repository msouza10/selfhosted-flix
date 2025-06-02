#!/usr/bin/env bash

set -euo pipefail

for os in $(cat /etc/os-release); do
    if [[ "$os" == "Ubuntu" ]]; then
        echo "Ubuntu" && exit 0
    fi
    if [[ "$os" == "Debian" ]]; then
        echo "Debian" && exit 0
    fi
    if [[ "$os" == "Arch Linux" ]]; then
        echo "Arch Linux" && exit 0
    fi
done



# install requirements
for cmd in "${REQUIREMENTS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Instalando $cmd..."
        sudo apt-get install -y "$cmd"
    fi
done