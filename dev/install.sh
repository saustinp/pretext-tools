#!/usr/bin/env bash
#
# install.sh — Build and install the pretext-tools VS Code extension from source.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/saustinp/pretext-tools/feature/emacs_keybindings/install.sh | bash
#
#   Or clone the repo first and run locally:
#     git clone https://github.com/saustinp/pretext-tools.git
#     cd pretext-tools
#     bash install.sh
#
# What this script does:
#   1. Checks for (or installs) VS Code
#   2. Checks for (or installs via nvm) Node.js 22+
#   3. Clones the repository (if not already inside it)
#   4. Installs npm dependencies
#   5. Builds and packages the extension as a .vsix
#   6. Installs the .vsix into VS Code
#
# The script is idempotent — safe to run multiple times.
# It does NOT require sudo (nvm installs Node to ~/.nvm).

set -euo pipefail

REPO_URL="https://github.com/saustinp/pretext-tools.git"
BRANCH="feature/emacs_keybindings"
MIN_NODE_MAJOR=22

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
fail()  { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ─── Step 1: Check for VS Code ───────────────────────────
info "Checking for VS Code..."
if command -v code &>/dev/null; then
    ok "VS Code found: $(code --version | head -1)"
else
    fail "VS Code ('code' command) not found on PATH.
    Install VS Code from https://code.visualstudio.com/
    Then re-run this script."
fi

# ─── Step 2: Check for Node.js 22+ ───────────────────────
ensure_node() {
    if command -v node &>/dev/null; then
        local ver
        ver=$(node --version | sed 's/^v//' | cut -d. -f1)
        if [ "$ver" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then
            ok "Node.js $(node --version) is sufficient (need v${MIN_NODE_MAJOR}+)"
            return 0
        fi
    fi
    return 1
}

info "Checking for Node.js ${MIN_NODE_MAJOR}+..."

# Try current shell first
if ensure_node; then
    : # already good
# Try loading nvm if it exists
elif [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    info "Loading nvm..."
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    if ! ensure_node; then
        info "Installing Node.js ${MIN_NODE_MAJOR} via nvm..."
        nvm install "$MIN_NODE_MAJOR"
        nvm use "$MIN_NODE_MAJOR"
        ensure_node || fail "Node ${MIN_NODE_MAJOR}+ still not available after nvm install"
    fi
else
    # No node, no nvm — install nvm + node
    warn "Node.js ${MIN_NODE_MAJOR}+ not found and nvm is not installed."
    info "Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    info "Installing Node.js ${MIN_NODE_MAJOR} via nvm..."
    nvm install "$MIN_NODE_MAJOR"
    nvm use "$MIN_NODE_MAJOR"
    ensure_node || fail "Node ${MIN_NODE_MAJOR}+ still not available after nvm install"
fi

# ─── Step 3: Get the source code ─────────────────────────
# If we're already inside the repo, use it; otherwise clone.
if [ -f "package.json" ] && grep -q '"pretext-tools"' package.json 2>/dev/null; then
    REPO_DIR="$(pwd)"
    ok "Already inside pretext-tools repo at $REPO_DIR"
    info "Checking out branch ${BRANCH}..."
    git fetch origin "$BRANCH" 2>/dev/null || true
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || warn "Could not switch to $BRANCH, using current branch"
    git pull --ff-only 2>/dev/null || true
else
    REPO_DIR="${HOME}/pretext-tools"
    if [ -d "$REPO_DIR/.git" ]; then
        info "Found existing clone at $REPO_DIR, updating..."
        cd "$REPO_DIR"
        git fetch origin "$BRANCH" 2>/dev/null || true
        git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || true
        git pull --ff-only 2>/dev/null || true
    else
        info "Cloning ${REPO_URL} into ${REPO_DIR}..."
        git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
        cd "$REPO_DIR"
    fi
    ok "Source code ready at $REPO_DIR"
fi

cd "$REPO_DIR"

# ─── Step 4: Install dependencies ────────────────────────
info "Installing npm dependencies (this may take a minute on first run)..."
npm install --loglevel=error
ok "Dependencies installed"

# ─── Step 5: Build and package ────────────────────────────
info "Building the extension..."
npm run build --loglevel=error
ok "Build complete"

info "Packaging .vsix..."
cd dist/vscode-extension
VSIX_FILE=$(npx vsce package --no-dependencies 2>&1 | grep -oP '(?<=Packaged: ).*\.vsix')
if [ -z "$VSIX_FILE" ]; then
    # Fallback: find the vsix file
    VSIX_FILE=$(ls -t *.vsix 2>/dev/null | head -1)
fi
[ -f "$VSIX_FILE" ] || fail "Could not find packaged .vsix file"
ok "Packaged: $VSIX_FILE"

# ─── Step 6: Install into VS Code ────────────────────────
info "Installing extension into VS Code..."
code --install-extension "$VSIX_FILE" --force
ok "Extension installed"

cd "$REPO_DIR"

# ─── Done ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  pretext-tools installed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Next steps:"
echo "    1. Reload any open VS Code windows:"
echo "       Ctrl+Shift+P → 'Developer: Reload Window'"
echo ""
echo "    2. Open a .ptx file and try these shortcuts:"
echo "       Ctrl+Alt+L    Live side-by-side preview"
echo "       Ctrl+Alt+J    Forward search (source → preview)"
echo "       Ctrl+C /      Close most recent unclosed tag"
echo ""
echo "  Optional: for best Ctrl+C / experience, install the"
echo "  Emacs keymap extension:"
echo "    code --install-extension tuttieee.emacs-mcx"
echo ""
echo "  To update later, re-run this script from the repo:"
echo "    cd $REPO_DIR && bash install.sh"
echo ""
