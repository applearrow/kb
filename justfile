# KB — Local Obsidian vault + GitHub Wiki automation
# Run `just` to list all available recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

wiki_dir := env("KB_WIKI_DIR", env("HOME") / "kb-wiki")

# List all available recipes
[private]
default:
    @just --list --unsorted

# Check required tools on this machine (git, Obsidian, gh, brew)
[group('setup')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Checking tools..."

    ok()   { printf "  [OK]   %s\n" "$1"; }
    warn() { printf "  [WARN] %s\n" "$1"; }
    fail() { printf "  [FAIL] %s\n" "$1"; exit 1; }

    if command -v git >/dev/null 2>&1; then
      ok "git ($(git --version))"
    else
      fail "git is not installed. Please install it before continuing."
    fi

    if [[ -d "/Applications/Obsidian.app" || -d "${HOME}/Applications/Obsidian.app" ]] || command -v obsidian >/dev/null 2>&1; then
      ok "Obsidian installed"
    else
      warn "Obsidian not detected (on macOS: brew install --cask obsidian)"
    fi

    if command -v gh >/dev/null 2>&1; then
      ok "gh ($(gh --version | head -n1))"
    else
      warn "gh (GitHub CLI) not installed (optional for HTTPS authentication)"
    fi

    if command -v brew >/dev/null 2>&1; then
      ok "brew ($(brew --version | head -n1))"
    else
      warn "brew not installed (optional)"
    fi

# Install and configure the local vault (accepts setup-wiki.sh flags, e.g. just install --ssh --with-git-plugin --open)
[group('setup')]
install *args:
    #!/usr/bin/env bash
    set -euo pipefail

    # 1. Tool check (+ auto-install Obsidian on macOS if missing)
    just check

    if [[ "$(uname -s)" == "Darwin" ]] && [[ ! -d "/Applications/Obsidian.app" && ! -d "${HOME}/Applications/Obsidian.app" ]]; then
      if command -v brew >/dev/null 2>&1; then
        echo "==> Installing Obsidian via Homebrew..."
        brew install --cask obsidian
      else
        echo "Notice: Obsidian is not installed and Homebrew is not available. Install it manually from https://obsidian.md/"
      fi
    fi

    # 2. Clone the wiki and apply configuration (excludes, images/, .obsidian/app.json, Obsidian registration)
    ./scripts/setup-wiki.sh --dir "{{wiki_dir}}" {{args}}

    # 3. Final vault verification
    just verify

# Install and preconfigure the Obsidian Git community plugin in the vault
[group('setup')]
install-git-plugin:
    ./scripts/setup-wiki.sh --dir "{{wiki_dir}}" --with-git-plugin

# Verify that the local vault is properly configured
[group('setup')]
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    vault="{{wiki_dir}}"
    echo "==> Verifying vault configuration in: ${vault}"

    [[ -d "${vault}/.git" ]] || { echo "  [FAIL] ${vault} is not a Git repository."; exit 1; }
    echo "  [OK]   Git repository cloned in ${vault}"

    grep -Fxq ".obsidian/" "${vault}/.git/info/exclude" || { echo "  [FAIL] .obsidian/ is missing from .git/info/exclude"; exit 1; }
    echo "  [OK]   .obsidian/ excluded in ${vault}/.git/info/exclude"

    if [[ -n "$(git -C "${vault}" ls-files .obsidian)" ]]; then
      echo "  [FAIL] .obsidian/ is currently tracked by Git."
      exit 1
    fi
    echo "  [OK]   .obsidian/ is not tracked by Git"

    [[ -d "${vault}/images" ]] || { echo "  [FAIL] Missing folder ${vault}/images"; exit 1; }
    echo "  [OK]   Images folder ready: ${vault}/images"

    app_json="${vault}/.obsidian/app.json"
    [[ -f "${app_json}" ]] || { echo "  [FAIL] Missing ${app_json}"; exit 1; }
    for key in '"useMarkdownLinks": true' '"newLinkFormat": "relative"' '"attachmentFolderPath": "images"' '"alwaysUpdateLinks": true'; do
      grep -Fq "${key}" "${app_json}" || { echo "  [FAIL] Missing ${key} in ${app_json}"; exit 1; }
    done
    echo "  [OK]   ${app_json} configured for Obsidian <-> GitHub Wiki compatibility"

    if [[ -f "${vault}/.obsidian/plugins/obsidian-git/main.js" ]] && grep -Fq '"obsidian-git"' "${vault}/.obsidian/community-plugins.json" 2>/dev/null; then
      echo "  [OK]   Obsidian Git community plugin installed and enabled"
    else
      echo "  [INFO] Obsidian Git plugin not installed (optional: just install-git-plugin)"
    fi

# Sync local and remote changes (commit + pull --rebase + push)
[group('daily')]
sync *args:
    ./scripts/sync-wiki.sh --dir "{{wiki_dir}}" {{args}}

# Pull remote wiki changes only
[group('daily')]
pull:
    ./scripts/sync-wiki.sh --dir "{{wiki_dir}}" --pull-only

# Open the vault directly in Obsidian
[group('daily')]
open:
    #!/usr/bin/env bash
    set -euo pipefail
    vault="{{wiki_dir}}"
    obsidian_cfg=""
    case "$(uname -s)" in
      Darwin) obsidian_cfg="${HOME}/Library/Application Support/obsidian/obsidian.json" ;;
      Linux)  obsidian_cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/obsidian/obsidian.json" ;;
    esac

    if command -v python3 >/dev/null 2>&1; then
      vault_id="$(python3 - "${obsidian_cfg}" "${vault}" <<'PY'
    import json
    import os
    import sys
    import urllib.parse

    cfg_path, vault_path = sys.argv[1], os.path.abspath(os.path.expanduser(sys.argv[2]))
    if cfg_path and os.path.isfile(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for vid, info in data.get("vaults", {}).items():
                if isinstance(info, dict) and os.path.abspath(info.get("path", "")) == vault_path:
                    print(urllib.parse.quote(vid, safe=""))
                    sys.exit(0)
        except Exception:
            pass
    PY
    )"
      if [[ -z "${vault_id}" ]]; then
        echo "Error: '${vault}' is not registered in Obsidian yet." >&2
        echo "Run 'just install --open' (will restart Obsidian if needed) or open the folder once via Obsidian -> Open folder as vault." >&2
        exit 1
      fi
      uri="obsidian://open?vault=${vault_id}"
      case "$(uname -s)" in
        Darwin) open "${uri}" ;;
        Linux)  xdg-open "${uri}" >/dev/null 2>&1 & ;;
        *)      echo "Open in Obsidian: ${uri}" ;;
      esac
    else
      open -a Obsidian "${vault}"
    fi

# Remove the local vault and clean up Obsidian registration (keeps Obsidian installed). Use --force to skip prompts.
[group('maintenance')]
uninstall *args:
    #!/usr/bin/env bash
    set -euo pipefail
    vault="{{wiki_dir}}"
    force=false

    for arg in {{args}}; do
      case "${arg}" in
        -f|--force) force=true ;;
        *) echo "Error: unknown option '${arg}'. Usage: just uninstall [--force]" >&2; exit 1 ;;
      esac
    done

    if [[ -z "${vault}" || "${vault}" == "/" || "${vault}" == "${HOME}" ]]; then
      echo "Error: unsafe vault path to remove: '${vault}'" >&2
      exit 1
    fi

    if [[ ! -d "${vault}" ]]; then
      echo "==> ${vault} does not exist. Nothing to uninstall."
      exit 0
    fi

    if [[ -d "${vault}/.git" && "${force}" == "false" ]]; then
      if [[ -n "$(git -C "${vault}" status --porcelain)" ]]; then
        echo "Warning: uncommitted local changes in ${vault}:" >&2
        git -C "${vault}" status --short >&2
        echo "Run 'just sync' first or use 'just uninstall --force' to delete anyway." >&2
        exit 1
      fi

      unpushed="$(git -C "${vault}" log --branches --not --remotes --oneline 2>/dev/null || true)"
      if [[ -n "${unpushed}" ]]; then
        echo "Warning: unpushed local commits in ${vault}:" >&2
        echo "${unpushed}" >&2
        echo "Run 'just sync' first or use 'just uninstall --force' to delete anyway." >&2
        exit 1
      fi
    fi

    if [[ "${force}" == "false" ]]; then
      read -r -p "Completely remove local vault '${vault}'? (Obsidian will NOT be uninstalled) [y/N]: " reply
      if [[ ! "${reply}" =~ ^[yY]$ ]]; then
        echo "Cancelled."
        exit 0
      fi
    fi

    rm -rf "${vault}"
    echo "==> Vault removed: ${vault}"

    obsidian_cfg=""
    case "$(uname -s)" in
      Darwin) obsidian_cfg="${HOME}/Library/Application Support/obsidian/obsidian.json" ;;
      Linux)  obsidian_cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/obsidian/obsidian.json" ;;
    esac

    obsidian_running=false
    case "$(uname -s)" in
      Darwin) pgrep -x Obsidian >/dev/null 2>&1 && obsidian_running=true ;;
      Linux)  pgrep -x obsidian >/dev/null 2>&1 && obsidian_running=true ;;
    esac

    if [[ "${obsidian_running}" == "true" ]]; then
      echo "    Notice: Obsidian is currently running; remove the vault from Obsidian's vault switcher if it still appears."
    elif [[ -n "${obsidian_cfg}" && -f "${obsidian_cfg}" ]] && command -v python3 >/dev/null 2>&1; then
      removed="$(python3 - "${obsidian_cfg}" "${vault}" <<'PY'
    import json
    import os
    import sys

    cfg_path, vault_path = sys.argv[1], os.path.abspath(os.path.expanduser(sys.argv[2]))
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        print("none")
        sys.exit(0)

    vaults = data.get("vaults", {})
    to_delete = [
        vid for vid, info in vaults.items()
        if isinstance(info, dict) and os.path.abspath(info.get("path", "")) == vault_path
    ]
    if not to_delete:
        print("none")
        sys.exit(0)

    for vid in to_delete:
        del vaults[vid]

    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)

    print("removed")
    PY
    )"
      if [[ "${removed}" == "removed" ]]; then
        echo "==> Vault entry removed from Obsidian (${obsidian_cfg})"
      fi
    fi
    echo "    Obsidian remains installed."
