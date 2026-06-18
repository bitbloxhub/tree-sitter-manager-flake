# Flake for [tree-sitter-manager.nvim](https://github.com/romus204/tree-sitter-manager.nvim)

This flake packages `tree-sitter-manager.nvim` with Nix-built parsers, so grammars can be selected declaratively and installed through Nix instead of being managed imperatively at runtime.

## Installation

Add this project as a flake input.

The plugin is available as `inputs.tree-sitter-manager-flake.packages.${pkgs.stdenv.hostPlatform.system}.default` and has two ways of adding grammars:
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

This project now has a `default.nix` powered by [`flake-ultra-polyfill`](https://github.com/bitbloxhub/flake-ultra-polyfill/)! Add this repo using your preferred input pinner and import this project like this to reuse your pinned `sources.nixpkgs` for `nixpkgs`:
```nix
let
  tree-sitter-manager = import sources.tree-sitter-manager {
    system = pkgs.stdenv.hostPlatform.system;
    overrides = [
      {
        path = [ "nixpkgs" ];
        value = {
          sourceInfo.outPath = sources.nixpkgs;
        };
      }
    ];
  };
in
{
  programs.neovim.plugins = [
    (tree-sitter-manager.default.withGrammars (grammars: [
      grammars.nix
      grammars.lua
    ]))
  ];
}
```
