# TODO: remember why git does not use ${} syntax, I remember ther was a reason
# TODO: how to expose env vars such as those for fzf and MANPAGER?
# TODO: how to expose aliases so they are easily consumed by outside tools?
# remember tmux uses SHELL to determine which shell to use
# What about setting inpurc?
{
  description = "Basic cli toolset";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    let
      mkWrappedTmux = pkgs: let
        tmux-config = pkgs.writeText "tmux.conf" ''
          set  -g default-terminal "tmux-256color"
          set  -g base-index      0
          setw -g pane-base-index 0

          set -g status-keys vi
          set -g mode-keys   vi

          # rebind main key: C-a
          unbind C-b
          set -g prefix C-a
          bind -n -N "Send the prefix key through to the application" \
            C-a send-prefix

          set  -g mouse             off
          set  -g focus-events      off
          setw -g aggressive-resize off
          setw -g clock-mode-style  12
          set  -s escape-time       0
          set  -g history-limit     5000

          # Differentiate with user config by color for debugging purposes
          set -g status-style bg=color234,fg=color208
        '';
        pkg = pkgs.tmux;
        mainProg = pkg.meta.mainProgram or pkg.pname;
      in pkgs.symlinkJoin {
        inherit (pkg) name meta;
        paths = [ pkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/${mainProg} \
            --add-flags "-f ${tmux-config}"
        '';
      };
      mkWrappedZsh = pkgs: let
        zsh-config = pkgs.writeTextDir ".zshrc" ''
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
        pkg = pkgs.zsh;
        mainProg = pkg.meta.mainProgram or pkg.pname;
      in pkgs.symlinkJoin {
        inherit (pkg) name meta;
        paths = [ pkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/${mainProg} \
            --set ZDOTDIR ${zsh-config}
        '';
      };
    in
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
        packages.default = mkWrappedZsh pkgs;
        packages.tmux = mkWrappedTmux pkgs;
        packages.fzf-config = pkgs.writeText "fzf-config" ''
          --layout=reverse
          --info=inline
          --height=40%
          --bind='ctrl-/:toggle-preview'
          --multi
        '';
        packages.smart-copy = pkgs.writeShellScript "smart-copy" ''
          if [ -n "$WAYLAND_DISPLAY" ]; then
            ${pkgs.wl-clipboard}/bin/wl-copy
          elif [ -n "$DISPLAY" ]; then
            ${pkgs.xclip}/bin/xclip -selection clipboard
          else
            cat > /dev/null
          fi
        '';
        devShells.default = pkgs.mkShell {
          packages =[
            self'.packages.default
            self'.packages.tmux
            pkgs.fzf
            pkgs.git
            pkgs.gh
          ];
          env = {
            FZF_DEFAULT_OPTS_FILE = "${self'.packages.fzf-config}";
            FZF_CTRL_R_OPTS = "--with-nth 2.. --bind='ctrl-y:execute-silent(echo -n {2..} | ${self'.packages.smart-copy})+abort'";
            FZF_CTRL_T_OPTS = "--walker-skip=.git,node_modules,target --preview='${pkgs.bat}/bin/bat --style=plain --color=always --line-range :500 {}' --bind='ctrl-/:change-preview-window(down|hidden|)'";
            FZF_ALT_C_OPTS = "--preview='${pkgs.eza}/bin/eza -T --color=always {} | head -200'";
          };
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

        overlays.default = final: prev: {
          zsh = mkWrappedZsh final;
          tmux = mkWrappedTmux final;
        };
      };
    };
}
