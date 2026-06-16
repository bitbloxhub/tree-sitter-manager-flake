{
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      packages.tree-sitter-manager-nvim-src = pkgs.fetchFromGitHub {
        owner = "romus204";
        repo = "tree-sitter-manager.nvim";
        rev = "ff0c04f418c610540148cb5a29a5960251f9a223";
        hash = "sha256-SCblz2qZ49nhhn6l0fDEmL0GL3jJIS5NUotcOghBudY=";
      };

      packages.tree-sitter-manager-nvim = pkgs.vimUtils.buildVimPlugin {
        pname = "tree-sitter-manager-nvim";
        version = "0-unstable-2026-06-16";

        src = self'.packages.tree-sitter-manager-nvim-src;

        passthru = {
          withGrammars =
            grammarsFn:
            pkgs.runCommand "tree-sitter-manager-nvim-with-grammars"
              {
                passthru = {
                  grammars = self'.packages.tree-sitter-manager-grammars.grammars;

                  selectedGrammars = grammarsFn self'.packages.tree-sitter-manager-grammars.grammars;

                  selectedLanguages = builtins.map (grammar: grammar.language) (
                    grammarsFn self'.packages.tree-sitter-manager-grammars.grammars
                  );
                };
              }
              ''
                mkdir -p "$out"

                cp -R ${self'.packages.tree-sitter-manager-nvim}/. "$out"
                chmod -R u+w "$out"

                mkdir -p "$out/parser"

                # TODO: add query source overrides
                ln -s runtime/queries "$out/queries"

                substituteInPlace "$out/lua/tree-sitter-manager/config.lua" \
                  --replace-fail 'parser_dir = vim.fs.joinpath(datapath, "site/parser")' \
                                 'parser_dir = "'"$out"'/parser"' \
                  --replace-fail 'query_dir = vim.fs.joinpath(datapath, "site/queries")' \
                                 'query_dir = "'"$out"'/queries"'

                ${lib.concatMapStringsSep "\n" (grammar: ''
                  ln -s ${grammar}/parser "$out/parser/${grammar.language}${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}"
                '') (grammarsFn self'.packages.tree-sitter-manager-grammars.grammars)}
              '';

          withAllGrammars = self'.packages.tree-sitter-manager-nvim.withGrammars (
            grammars: builtins.attrValues grammars
          );
        };
      };

      packages.default = self'.packages.tree-sitter-manager-nvim;
    };
}
