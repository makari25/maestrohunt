# MaestroHunt – Automated Bug Bounty Reconnaissance Framework

MaestroHunt orchestrates the entire bug bounty reconnaissance pipeline, from OSINT to vulnerability scanning, with a modular design and easy configuration.

## Features

- **8‑phase pipeline** – OSINT, Passive/Active subdomain enumeration, Live host discovery, Web crawling, Parameter discovery, Vulnerability scanning, and Reporting.
- **Modular** – each phase can be enabled/disabled in `config.conf`.
- **Extensible** – add your own tools or phases with minimal changes.
- **Configurable** – threads, rate limits, API keys, and paths via a single config file.
- **Clean output** – timestamped directories with organised results.
- **Notifications** – optional Discord integration via `notify`.

## Requirements

- Kali Linux (or any Debian‑based) with:
  - Bash 4+
  - Go 1.18+
  - Python3 + pip
  - Git
- Installed tools (installer provided):
  - ProjectDiscovery suite (`subfinder`, `httpx`, `nuclei`, `katana`, `dnsx`, etc.)
  - `amass`, `assetfinder`, `waybackurls`, `gau`, `puredns`, `arjun`, `gf`

## Installation

```bash
git clone https://github.com/your/maestrohunt.git
cd maestrohunt
chmod +x install.sh
./install.sh