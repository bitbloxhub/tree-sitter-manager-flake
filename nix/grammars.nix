{
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      make-shells.default = {
        packages = [
          pkgs.nix-prefetch-git
        ];
      };

      packages.tree-sitter-manager-grammars =
        pkgs.runCommand "tree-sitter-manager-grammars-scope"
          {
            passthru.grammars =
              builtins.mapAttrs
                (
                  language: lock:
                  pkgs.tree-sitter.buildGrammar {
                    inherit language;
                    version = lock.revision;

                    src = pkgs.fetchgit {
                      inherit (lock) url;
                      rev = lock.revision;
                      inherit (lock) hash;
                    };

                    generate = lock.generate or false;
                    location = lock.location or "/";
                  }
                )
                (
                  lib.filterAttrs (_language: lock: !lock.query_only) (
                    lib.importJSON ../tree-sitter-manager-grammars.lock.json
                  )
                );
          }
          ''
            mkdir -p $out
          '';
    };
}
