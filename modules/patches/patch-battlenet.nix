/*
  @menu
  displayname = "Battle.net";
  icon = "applications-games-symbolic";
  order = 185;
  description = "Blizzard Battle.net launcher through umu-launcher and GE-Proton";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-battlenet =
    { config, lib, ... }:
    {
      options.ojuny.patch.battlenet.enable = lib.mkEnableOption "the Battle.net patch";

      imports = [ self.modules.nixos.battlenet-backend ];

      config = {
        # @option widget = "switch"; label = "Battle.net"; group = "Battle.net"; description = "Install the Battle.net installer, launcher, reset command, and desktop entry. The installer downloads from Blizzard on first run.";
        ojuny.patch.battlenet.enable = false;

        # @option widget = "text"; label = "Wine prefix"; group = "Battle.net"; description = "Per-user Battle.net prefix. Keep the default unless another location is required."; visibleWhen.path = "ojuny.patch.battlenet.enable"; visibleWhen.equals = true;
        ojuny.patch.battlenet.prefix = "$HOME/Games/battlenet";

        # @option widget = "switch"; label = "MangoHud"; group = "Battle.net"; description = "Run Battle.net and its games with the MangoHud overlay."; advanced = true; visibleWhen.path = "ojuny.patch.battlenet.enable"; visibleWhen.equals = true;
        ojuny.patch.battlenet.mangohud = false;
      };
    };

  flake.modules.nixos.battlenet-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.battlenet // {
        enable = active;
      };
      active = config.ojuny.patch.battlenet.enable && (config.ojuny.patches or true);

      proton = pkgs.proton-ge-bin.steamcompattool;
      umu = "${pkgs.umu-launcher}/bin/umu-run";
      launcherRelative = "drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe";

      launchCommand =
        if cfg.mangohud then
          ''
            exec "${pkgs.mangohud}/bin/mangohud" --dlsym env \
              WINEPREFIX="$prefix" \
              PROTONPATH="${proton}" \
              GAMEID=umu-battlenet \
              PROTON_VERB=run \
              "${umu}" "$launcher" "$@"
          ''
        else
          ''
            exec env \
              WINEPREFIX="$prefix" \
              PROTONPATH="${proton}" \
              GAMEID=umu-battlenet \
              PROTON_VERB=run \
              "${umu}" "$launcher" "$@"
          '';

      installerBin = pkgs.writeShellApplication {
        name = "battlenet-install";
        runtimeInputs = with pkgs; [
          coreutils
          curl
        ];
        text = ''
          set -euo pipefail

          prefix="${cfg.prefix}"
          launcher="$prefix/${launcherRelative}"
          cache="''${XDG_CACHE_HOME:-$HOME/.cache}/ojuny/battlenet"
          setup="$cache/Battle.net-Setup.exe"
          url="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

          if [[ -e "$launcher" ]]; then
            printf 'Battle.net is already installed at %s\n' "$prefix"
            exit 0
          fi

          if [[ -e "$prefix" ]]; then
            printf 'Partial Battle.net prefix found at %s\n' "$prefix" >&2
            printf 'Run battlenet-reset, then run battlenet-install again.\n' >&2
            exit 1
          fi

          mkdir -p "$cache"
          printf 'Downloading the Battle.net installer...\n'
          curl --fail --location --retry 3 --output "$setup" "$url"
          mkdir -p "$prefix"

          printf 'Starting the Battle.net setup wizard. Keep the default install path.\n'
          WINEPREFIX="$prefix" \
            PROTONPATH="${proton}" \
            GAMEID=umu-battlenet \
            PROTON_VERB=run \
            "${umu}" "$setup"

          if [[ ! -e "$launcher" ]]; then
            printf 'The wizard finished without creating %s\n' "$launcher" >&2
            exit 1
          fi
        '';
      };

      launcherBin = pkgs.writeShellApplication {
        name = "battlenet";
        runtimeInputs = with pkgs; [
          coreutils
        ];
        text = ''
          set -euo pipefail

          prefix="${cfg.prefix}"
          launcher="$prefix/${launcherRelative}"

          if [[ ! -e "$launcher" ]]; then
            printf 'Battle.net is not installed at %s\n' "$prefix" >&2
            printf 'Run battlenet-install first.\n' >&2
            exit 1
          fi

          ${launchCommand}
        '';
      };

      resetBin = pkgs.writeShellApplication {
        name = "battlenet-reset";
        runtimeInputs = with pkgs; [
          coreutils
        ];
        text = ''
          set -euo pipefail

          prefix="${cfg.prefix}"
          if [[ ! -e "$prefix" ]]; then
            printf 'No Battle.net prefix at %s\n' "$prefix"
            exit 0
          fi

          backup="$prefix.bak.$(date +%Y%m%d-%H%M%S)"
          printf 'Moving %s to %s\n' "$prefix" "$backup"
          read -r -p "Continue? [y/N] " answer
          case "$answer" in
            [yY]) ;;
            *)
              printf 'Aborted.\n'
              exit 1
              ;;
          esac

          mv -- "$prefix" "$backup"
          printf 'Moved to %s. Delete it manually when it is no longer needed.\n' "$backup"
        '';
      };

      desktopItem = pkgs.makeDesktopItem {
        name = "battlenet";
        desktopName = "Battle.net";
        genericName = "Game Launcher";
        comment = "Blizzard game launcher through umu-launcher and GE-Proton";
        exec = "battlenet";
        icon = "applications-games";
        categories = [ "Game" ];
        startupNotify = true;
        startupWMClass = "battle.net.exe";
      };

      package = pkgs.symlinkJoin {
        name = "battlenet-patch";
        paths = [
          installerBin
          launcherBin
          resetBin
          desktopItem
        ];
      };
    in
    {
      options.ojuny.patch.battlenet = {
        prefix = lib.mkOption {
          type = lib.types.str;
          default = "$HOME/Games/battlenet";
          description = "Battle.net Wine prefix. Use an absolute path or a string that expands $HOME at runtime.";
        };

        mangohud = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run Battle.net through MangoHud.";
        };
      };

      config = lib.mkIf cfg.enable {
          hardware.graphics.enable = lib.mkDefault true;
          hardware.graphics.enable32Bit = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 true;

          environment.systemPackages = [ package ];
      };
    };
}
