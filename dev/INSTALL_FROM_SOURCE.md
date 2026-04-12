# Installing pretext-tools from Source

These instructions walk you through building and installing the pretext-tools VS Code extension from this GitHub fork. This is useful if you want features that haven't been merged into the official marketplace release yet, such as:

- **Live side-by-side preview** with forward/inverse search (`Ctrl+Alt+L`, `Ctrl+Alt+J`)
- **Document outline sidebar** for navigating PreTeXt document structure
- **Emacs-style close tag** (`Ctrl+C /`) — closes the most recent unclosed XML tag with proper indentation
- **LSP server lifecycle fix** — prevents leaked language server processes from consuming CPU

## Prerequisites

- **VS Code** (any recent version)
- **Node.js 22+** — required by the build system. If you have an older Node, install [nvm](https://github.com/nvm-sh/nvm) and run `nvm install 22`.
- **Git**

## Step 1: Clone the repository

```bash
git clone https://github.com/saustinp/pretext-tools.git
cd pretext-tools
```

To get a specific feature branch (e.g., the Emacs keybindings):

```bash
git checkout feature/emacs_keybindings
```

Available branches:

| Branch | Features |
|---|---|
| `main` | Live preview, forward/inverse search, document outline, LSP leak fix |
| `feature/emacs_keybindings` | Everything in `main` + Emacs-style close tag (`Ctrl+C /`) |

## Step 2: Install dependencies

```bash
npm install
```

This installs all workspace dependencies for the Nx monorepo. It may take a minute on the first run.

## Step 3: Build the extension

```bash
npm run build
```

This builds all packages in the monorepo, including the VS Code extension. The build output lands in `dist/vscode-extension/`.

If you see errors about Node version, make sure you're on Node 22+:

```bash
node --version    # should be v22.x.x or later
```

If you're using nvm:

```bash
nvm use 22
npm run build
```

## Step 4: Package the `.vsix` file

```bash
cd dist/vscode-extension
npx vsce package --no-dependencies
```

This produces a file like `pretext-tools-0.36.0.vsix` in the current directory. The `--no-dependencies` flag skips bundling the `redhat.vscode-xml` dependency (VS Code will prompt you to install it separately if needed).

## Step 5: Install the extension into VS Code

```bash
code --install-extension pretext-tools-0.36.0.vsix --force
```

The `--force` flag overwrites any previously installed version of pretext-tools (including the marketplace version). To revert to the marketplace version later, uninstall and reinstall from the Extensions panel.

Alternatively, you can install from within VS Code:
1. Open VS Code
2. Open the Command Palette (`Ctrl+Shift+P`)
3. Type "Install from VSIX"
4. Select the `.vsix` file you just built

## Step 6: Reload VS Code

After installation, reload any open VS Code windows to activate the new extension:
- **Command Palette** (`Ctrl+Shift+P`) → "Developer: Reload Window"
- Or simply close and reopen VS Code

## Verifying the installation

Open any `.ptx` file and check:

- **Status bar**: You should see a PreTeXt status indicator at the bottom of the window.
- **Output channel**: Open the Output panel (`Ctrl+Shift+U`) and select "PreTeXt" from the dropdown. You should see "Welcome to the pretext-tools extension" and "PreTeXt LSP Launched".
- **Live preview**: Press `Ctrl+Alt+L` to open a side-by-side HTML preview of your document.
- **Close tag** (if on `feature/emacs_keybindings`): Type an opening tag like `<p>`, press Enter, type some text, then press `Ctrl+C` followed by `/`. The closing `</p>` should appear at the correct indentation.

## Optional: Emacs keybindings

If you prefer Emacs-style keybindings, install the [Awesome Emacs Keymap](https://marketplace.visualstudio.com/items?itemName=tuttieee.emacs-mcx) extension. With it installed, `Ctrl+C` becomes the Emacs `C-c` prefix key, and the `Ctrl+C /` close-tag chord fires instantly with no interference with copy behavior.

```bash
code --install-extension tuttieee.emacs-mcx
```

## Updating

To pull the latest changes and rebuild:

```bash
cd pretext-tools
git pull
npm install       # in case dependencies changed
npm run build
cd dist/vscode-extension
npx vsce package --no-dependencies
code --install-extension pretext-tools-0.36.0.vsix --force
```

## Reverting to the marketplace version

To go back to the official pretext-tools release:

1. Uninstall the current version: `code --uninstall-extension oscarlevin.pretext-tools`
2. Reinstall from marketplace: search "pretext-tools" in the VS Code Extensions panel and click Install

## Troubleshooting

**Build fails with "engines" or Node version error:**
Make sure you're using Node 22+. Run `node --version` to check. Use `nvm use 22` if you have nvm installed.

**"Cannot find module" errors during build:**
Run `npm install` again. If that doesn't help, delete `node_modules/` and reinstall:
```bash
rm -rf node_modules
npm install
npm run build
```

**Extension installs but features don't appear:**
Reload the VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window"). If that doesn't help, check the Output panel for error messages.

**`Ctrl+C /` doesn't work:**
Make sure you're editing a `.ptx` file (the keybinding only activates for PreTeXt files). Also check that the file is recognized as PreTeXt language mode — look at the language indicator in the bottom-right corner of VS Code; it should say "PreTeXt", not "XML" or "Plain Text".
