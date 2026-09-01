#!/bin/bash
# install.sh – Install all dependencies for MaestroHunt

set -e

echo "[*] Installing MaestroHunt dependencies..."

# Update package list
sudo apt update

# Install system packages
sudo apt install -y whois dnsutils golang git python3-pip

# Install ProjectDiscovery tools using pdtm
go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
export PATH=$PATH:$HOME/go/bin
pdtm -install-all

# Install other tools not in pdtm
go install -v github.com/owasp-amass/amass/v4/...@master
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/tomnomnom/gf@latest
go install -v github.com/projectdiscovery/puredns/v2@latest
pip3 install arjun

# Install SecLists
sudo apt install -y seclists

# Download common resolvers list (if not present)
if [ ! -f ~/resolvers.txt ]; then
    wget -O ~/resolvers.txt https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt
fi

echo "[*] All dependencies installed."
echo "[*] Make sure ~/go/bin is in your PATH (add to ~/.bashrc if needed)."
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

echo "[*] Installation complete. You can now run ./maestrohunt.sh <domain>"