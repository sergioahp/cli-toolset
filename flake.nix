{
  description = "Basic cli toolset";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import an internal flake module: ./other.nix
        # To import an external flake module:
        #   1. Add foo to inputs
        #   2. Add foo as a parameter to the outputs function
        #   3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        packages.default = pkgs.zsh;
        packages.fzf-config = pkgs.writeText "fzf-config" ''
          --layout=reverse
          --info=inline
          --height=40%
          --bind='ctrl-/:toggle-preview'
          --multi
        '';
        packages.zsh-config = pkgs.writeTextDir ".zshrc" ''
          bindkey -v
          autoload -U compinit
          source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh


          # TODO: You should think about isolating this in a separate file
          HISTFILE=~/.zsh_history

          HISTSIZE=10000
          SAVEHIST=10000

          source <(${pkgs.fzf}/bin/fzf --zsh)

          # Set shell options
          set_opts=(
            HIST_FCNTL_LOCK APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
            SHARE_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
            NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS
          )
          for opt in "''${set_opts[@]}"; do
            setopt "$opt"
          done
          unset opt set_opts


          bindkey -v '^?' backward-delete-char
          bindkey ^K fzf-cd-widget
          bindkey ^J fzf-file-widget
          bindkey ^O autosuggest-accept
          autoload -U edit-command-line
          zle -N edit-command-line
          bindkey -M vicmd ^F edit-command-line
          bindkey ^F edit-command-line
          preexec() {
            local cmd="''${1%% *}"
            printf "\e]0;%s - %s\a" "$cmd" "''${PWD/#$HOME/~}"
          }
          if [[ $TERM != "dumb" ]]; then
            eval "$(${pkgs.starship}/bin/starship init zsh)"
          fi

          alias -- cat=${pkgs.bat}/bin/bat --paging=never --style=plain
          alias -- g=git
          alias -- ls=${pkgs.eza}/bin/eza
          alias -- tree=${pkgs.eza}/bin/eza -T

          source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        '';
        devShells.default = pkgs.mkShell {
          packages = [ self'.packages.default pkgs.fzf ];
          env = {
            FZF_DEFAULT_OPTS_FILE = "${self'.packages.fzf-config}";
            FZF_CTRL_R_OPTS = "--with-nth 2.. --bind='ctrl-y:execute-silent(echo -n {2..} | ${pkgs.wl-clipboard}/bin/wl-copy)+abort'";
            FZF_CTRL_T_OPTS = "--walker-skip=.git,node_modules,target --preview='${pkgs.bat}/bin/bat --style=plain --color=always --line-range :500 {}' --bind='ctrl-/:change-preview-window(down|hidden|)'";
            FZF_ALT_C_OPTS = "--preview='${pkgs.eza}/bin/eza -T --color=always {} | head -200'";
            ZDOTDIR = "${self'.packages.zsh-config}";
          };
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
}
