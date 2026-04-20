# vibe-install

One-command macOS bootstrap: iTerm2, Claude Code (Vertex AI), dev runtimes, cloud CLIs, and a curated zsh setup — installed in 20–30 minutes.

## Quick start

On a fresh Mac, paste this into Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/i87ce/vibe-install/main/bootstrap.sh)"
```

The script will:
1. Install Xcode Command Line Tools, Homebrew, Rosetta 2 (Apple Silicon)
2. Install iTerm2 with a preconfigured profile
3. Open a TUI where you select everything else (all on by default)
4. Ask for your Vertex AI project (default `ea-claw`) and open a browser for `gcloud` login
5. Install components, verify with a `doctor` report

## What's included

- **Shell:** oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting, tmux, Powerlevel10k (or Starship)
- **CLI:** git, gh, jq, yq, fzf, ripgrep, bat, eza, fd, zoxide, tldr, mkcert, tree, htop
- **Claude Code:** CLI, Vertex AI login, settings.json merge, 14 plugins, statusline, Agent Teams
- **Editor:** Obsidian (+ optional vault symlink)
- **Runtimes:** Node (nvm), Python (uv), Go, Rust (rustup), Ruby (rbenv), Java (sdkman), Bun
- **Containers & IaC:** Docker Desktop, Terraform, Ansible
- **Cloud & Ops:** gcloud SDK, Azure CLI, Cloudflare Wrangler, m365 CLI, PowerShell 7 + Microsoft.Graph
- **Browsers & Debug:** Chrome, Postman
- **DB clients:** psql, mysql-client, redis-cli, sqlite

## Options

```
./install.sh                  # interactive TUI (default)
./install.sh --config FILE    # replay saved selections
./install.sh --only MOD[,MOD] # run only listed modules
./install.sh --doctor         # verify existing installation
./install.sh --dry-run        # print planned actions
./install.sh --help           # full usage
```

Your selections persist in `~/.vibe-install.conf` — rerun with `--config ~/.vibe-install.conf` on another machine.

## Idempotent

Every step checks for existing installs first. Safe to re-run at any time.

## Customization

`~/.zshrc.local` is yours to edit — the script will never overwrite it. Put personal aliases, secrets sourcing, and project-specific config there.

## Troubleshooting

- **Xcode CLT install hangs:** accept the GUI prompt, then rerun `./install.sh`
- **gcloud auth failed:** ensure your DonTouch Google account has access to the Vertex project
- **Plugin didn't enable:** run `/plugin` inside Claude Code to enable manually
- **Check logs:** `~/vibe-install.log`

## License

MIT — see [LICENSE](LICENSE).
