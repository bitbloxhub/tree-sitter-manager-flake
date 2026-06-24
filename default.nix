{
  pkgs ? import <nixpkgs> { },
}:
let
  packages = rec {
    tree-sitter-manager-nvim-src = pkgs.callPackage ./nix/tree-sitter-manager-nvim-src.pkg.nix { };
    tree-sitter-manager-grammars = pkgs.callPackage ./nix/tree-sitter-manager-grammars.pkg.nix { };
    tree-sitter-manager-nvim = pkgs.callPackage ./nix/tree-sitter-manager-nvim.pkg.nix {
      self' = {
        inherit packages;
      };
    };
    default = tree-sitter-manager-nvim;
    inherit (tree-sitter-manager-nvim) withAllGrammars;
  };
in
packages
