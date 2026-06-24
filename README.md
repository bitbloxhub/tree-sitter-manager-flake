# Flake for [tree-sitter-manager.nvim](https://github.com/romus204/tree-sitter-manager.nvim)

This flake packages `tree-sitter-manager.nvim` with Nix-built parsers, so grammars can be selected declaratively and installed through Nix instead of being managed imperatively at runtime.

## Installation

Add this project as a flake input.

The plugin is available as `inputs.tree-sitter-manager-flake.packages.${pkgs.stdenv.hostPlatform.system}.default` and exposes `withAllGrammars` on that package:
- `withAllGrammars`: Installs all grammars.  
  (`inputs'` is shorthand originally from flake-parts, pre-selects per-system outputs like `packages`)  
  Like this:  
  ```nix
  {
    programs.neovim.plugins = [ inputs'.tree-sitter-manager-flake.packages.default.withAllGrammars ];
  }
  ```
- `withGrammars`: Installs only selected grammars.
  Takes a function that receives `grammars` (attrset of available grammars, keyed by name) and returns list of selected grammars.  
  Like this:  
  ```nix
  {
    programs.neovim.plugins = [
      (inputs'.tree-sitter-manager-flake.packages.default.withGrammars (grammars: [
        grammars.nix
        grammars.lua
      ]))
    ];
  }
  ```

See [upstream docs](https://github.com/romus204/tree-sitter-manager.nvim?tab=readme-ov-file#tree-sitter-managernvim) for more info.

## Installation (non-flake)

Import the repo's `default.nix` package set with your pinned `pkgs`:
```nix
let
  tree-sitter-manager = import sources.tree-sitter-manager-flake {
    inherit pkgs;
  };
in
{
  programs.neovim.plugins = [
    tree-sitter-manager.withAllGrammars
  ];
}
```

The non-flake package set is built with manual `pkgs.callPackage` entries from `default.nix`.
