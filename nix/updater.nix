{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      make-shells.default = {
        packages = [
          # Updater stuff
          pkgs.nix-prefetch-github
          pkgs.ast-grep
          pkgs.jq
          pkgs.nix-prefetch-git
          pkgs.neovim
        ];
      };
    };
}
