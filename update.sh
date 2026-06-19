#!/usr/bin/env bash
set -euo pipefail

OWNER='romus204'
REPO='tree-sitter-manager.nvim'
FILE='nix/plugin.nix'
RULE="$(mktemp)"
PREFETCH_JSON="$(mktemp)"

cleanup() {
	rm -f "$RULE" "$PREFETCH_JSON"
}
trap cleanup EXIT

NEW_REV="$(git ls-remote "https://github.com/$OWNER/$REPO.git" HEAD | cut -f1)"
nix-prefetch-github --meta "$OWNER" "$REPO" --rev "$NEW_REV" > "$PREFETCH_JSON"
NEW_HASH="$(jq -r '.src.hash // .src.sha256 // empty' "$PREFETCH_JSON")"
NEW_VERSION="0-unstable-$(jq -r '.meta.commitDate' "$PREFETCH_JSON")"

cat > "$RULE" <<EOF
id: update-tree-sitter-manager-nvim-rev
language: Nix
rule:
  all:
    - pattern:
        context: |
          { rev = \$OLD_REV; }
        selector: binding
    - inside:
        all:
          - pattern: pkgs.fetchFromGitHub \$ARG
          - has:
              pattern:
                context: |
                  { owner = "romus204"; }
                selector: binding
              stopBy: end
          - has:
              pattern:
                context: |
                  { repo = "tree-sitter-manager.nvim"; }
                selector: binding
              stopBy: end
        stopBy: end
fix: rev = "$NEW_REV";
---
id: update-tree-sitter-manager-nvim-hash
language: Nix
rule:
  all:
    - pattern:
        context: |
          { hash = \$OLD_HASH; }
        selector: binding
    - inside:
        all:
          - pattern: pkgs.fetchFromGitHub \$ARG
          - has:
              pattern:
                context: |
                  { owner = "romus204"; }
                selector: binding
              stopBy: end
          - has:
              pattern:
                context: |
                  { repo = "tree-sitter-manager.nvim"; }
                selector: binding
              stopBy: end
        stopBy: end
fix: hash = "$NEW_HASH";
---
id: update-tree-sitter-manager-nvim-version
language: Nix
rule:
  all:
    - pattern:
        context: |
          { version = \$OLD_VERSION; }
        selector: binding
    - inside:
        all:
          - pattern: pkgs.vimUtils.buildVimPlugin \$ARG
          - has:
              pattern:
                context: |
                  { pname = "tree-sitter-manager-nvim"; }
                selector: binding
              stopBy: end
        stopBy: end
fix: version = "$NEW_VERSION";
EOF

# Preview
ast-grep scan -r "$RULE" "$FILE"

# Apply
ast-grep scan -r "$RULE" -U "$FILE"

nvim --headless -u NONE -n -l update-lockfile.lua
