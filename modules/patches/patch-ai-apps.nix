/*
  @menu
  displayname = "AI desktop apps";
  icon = "applications-internet-symbolic";
  order = 145;
  description = "Opt-in hosted AI desktop apps and web-app presets, with no AI in the default install";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, inputs, ... }:
let
  hasChromiumWebapps = inputs ? chromium-webapps;
in
{
  flake.modules.nixos.patch-ai-apps =
    { config, lib, ... }:
    {
      options.ojuny.patch.ai-apps.enable = lib.mkEnableOption "the AI desktop apps patch";

      # @option widget = "switch"; label = "AI desktop apps"; group = "AI desktop apps"; order = 10; description = "Install hosted AI desktop applications and web-app presets. Nothing is installed until this is on.";
      config.ojuny.patch.ai-apps.enable = false;

      imports = [ self.modules.nixos.ai-apps-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.ai-apps.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.ai-apps-backend ];
    };

  flake.modules.nixos.ai-apps-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.ai-apps;
      active = cfg.enable && (config.ojuny.patches or true);
    in
    {
      options.ojuny.patch.ai-apps = {
        chatgpt = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the ChatGPT desktop package. It is unfree, so nixpkgs.config.allowUnfree must be true.";
        };

        t3code = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the T3 Code desktop package.";
        };

        openclaw = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the OpenClaw desktop package.";
        };

        lmstudio = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the LM Studio desktop package.";
        };

        webApps = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Install this web app.";
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Application name.";
                };
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "URL to open.";
                };
                icon = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "Optional icon file.";
                };
              };
            }
          );
          default = { };
          description = "Hosted AI web apps keyed by id. Rows without a nixpkgs desktop package live here.";
        };
      };

      config = {
        # @option widget = "switch"; label = "ChatGPT"; group = "Hosted apps"; groupOrder = 20; order = 10; visibleWhen.path = "ojuny.patch.ai-apps.enable"; visibleWhen.equals = true; description = "Install the ChatGPT desktop app. It is unfree, so nixpkgs.config.allowUnfree must be true.";
        ojuny.patch.ai-apps.chatgpt = false;

        # @option widget = "switch"; label = "T3 Code"; group = "Hosted apps"; groupOrder = 20; order = 20; visibleWhen.path = "ojuny.patch.ai-apps.enable"; visibleWhen.equals = true; description = "Install the T3 Code desktop app.";
        ojuny.patch.ai-apps.t3code = false;

        # @option widget = "switch"; label = "OpenClaw"; group = "Hosted apps"; groupOrder = 20; order = 30; visibleWhen.path = "ojuny.patch.ai-apps.enable"; visibleWhen.equals = true; description = "Install the OpenClaw desktop app.";
        ojuny.patch.ai-apps.openclaw = false;

        # @option widget = "switch"; label = "LM Studio"; group = "Hosted apps"; groupOrder = 20; order = 40; visibleWhen.path = "ojuny.patch.ai-apps.enable"; visibleWhen.equals = true; description = "Install the LM Studio desktop app.";
        ojuny.patch.ai-apps.lmstudio = false;

        # @option widget = "table-attrset"; label = "Web apps"; group = "Web apps"; groupOrder = 30; columns = [ "enable" "name" "url" "icon" ]; columnTypes = [ "bool" "str" "str" "icon" ]; iconDir = "./icons"; visibleWhen.path = "ojuny.patch.ai-apps.enable"; visibleWhen.equals = true; description = "Web-app presets opened in Chromium. They install no desktop package and start disabled.";
        ojuny.patch.ai-apps.webApps = {
          /* @table-item label = "Claude"; */
          claude = {
            enable = false;
            name = "Claude";
            url = "https://claude.ai";
            icon = null;
          };

          /* @table-item label = "Perplexity"; */
          perplexity = {
            enable = false;
            name = "Perplexity";
            url = "https://www.perplexity.ai";
            icon = null;
          };

          /* @table-item label = "Grok"; */
          grok = {
            enable = false;
            name = "Grok";
            url = "https://grok.com";
            icon = null;
          };

          /* @table-item label = "Hermes"; */
          hermes = {
            enable = false;
            name = "Hermes";
            url = "https://hermes-agent.nousresearch.com/desktop";
            icon = null;
          };
        };

        environment.systemPackages = lib.mkIf active (
          lib.optional cfg.chatgpt pkgs.chatgpt
          ++ lib.optional cfg.t3code pkgs.t3code
          ++ lib.optional cfg.openclaw pkgs.openclaw
          ++ lib.optional cfg.lmstudio pkgs.lmstudio
        );
      };
    };

  flake.modules.homeManager.ai-apps-backend =
    {
      lib,
      osConfig ? { },
      ...
    }:
    let
      fallback = {
        enable = false;
        webApps = { };
      };

      cfg = fallback // (osConfig.ojuny.patch.ai-apps or { });
      active = cfg.enable && (osConfig.ojuny.patches or true);
      enabledApps = lib.filterAttrs (_: app: app.enable) cfg.webApps;
    in
    {
      imports = lib.optional (inputs ? chromium-webapps) inputs.chromium-webapps.homeManagerModules.default;

      config = lib.mkIf (active && hasChromiumWebapps) {
        programs.chromium-webapps.enable = lib.mkIf (enabledApps != { }) true;

        programs.chromium-webapps.webApps = lib.mapAttrsToList (
          _: app: { inherit (app) name url; } // lib.optionalAttrs (app.icon != null) { inherit (app) icon; }
        ) enabledApps;
      };
    };
}
