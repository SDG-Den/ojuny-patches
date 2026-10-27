/*
  @menu
  displayname = "Advanced workspaces";
  icon = "preferences-desktop-workspaces-symbolic";
  order = 165;
  description = "Per-tag layouts and saved named layouts";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

let
  layoutChoices = [
    "tile"
    "dwindle"
    "scroller"
    "monocle"
    "deck"
    "grid"
    "fair"
    "vertical_scroller"
    "vertical_tile"
    "vertical_fair"
    "vertical_grid"
    "vertical_deck"
    "right_tile"
    "center_tile"
  ];

  tagFields = lib: {
    layout = lib.mkOption {
      type = lib.types.enum layoutChoices;
      default = "tile";
      description = "Mango layout name.";
    };

    masterCount = lib.mkOption {
      type = lib.types.ints.between 0 99;
      default = 0;
      description = "Master count. 0 leaves the Mango per-tag default.";
    };

    masterFactor = lib.mkOption {
      type = lib.types.numbers.between 0.0 0.9;
      default = 0.0;
      description = "Master factor. 0.0 leaves the Mango per-tag default.";
    };

    monitor = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Monitor name. Empty applies to every monitor.";
    };
  };

  tagSpec = lib: lib.types.submodule {
    options = tagFields lib;
  };

  savedSpec = lib: lib.types.submodule {
    options = tagFields lib // {
      preset = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Name of the saved layout this row belongs to.";
      };

      tag = lib.mkOption {
        type = lib.types.ints.between 0 99;
        description = "Tag id.";
      };
    };
  };

  mkTagRule =
    { lib, tag, spec }:
    { id = lib.toInt tag; layout_name = spec.layout; }
    // lib.optionalAttrs (spec.masterCount > 0) { master_count = spec.masterCount; }
    // lib.optionalAttrs (spec.masterFactor > 0.0) { master_factor = spec.masterFactor; }
    // lib.optionalAttrs (spec.monitor != "") { monitor_name = spec.monitor; };

  rowToTag = row: {
    name = toString row.tag;
    value = row;
  };
in
{
  flake.modules.nixos.patch-advanced-workspaces =
    { config, lib, ... }:
    let
      cfg = config.ojuny.patch.advancedWorkspaces;
      tagNum = config.desktop.ojuny.mango.global.tag_num or 10;
      savedRows = lib.attrValues cfg.saved;

      presetRows =
        if cfg.preset == null then
          [ ]
        else
          lib.filter (row: row.preset == cfg.preset) savedRows;

      presetTags = lib.listToAttrs (map rowToTag presetRows);
      effectiveTags = presetTags // cfg.tags;
      orderedTags = lib.sort (a: b: lib.toInt a < lib.toInt b) (lib.attrNames effectiveTags);

      tagRules = map (
        tag: mkTagRule { inherit lib tag; spec = effectiveTags.${tag}; }
      ) orderedTags;

      presetNames = lib.unique (map (row: row.preset) savedRows);

      presetHasDuplicateTags =
        name:
        let
          rows = lib.filter (row: row.preset == name) savedRows;
        in
        lib.length rows != lib.length (lib.unique (map (row: row.tag) rows));
    in
    {
      options.ojuny.patch.advancedWorkspaces = {
        enable = lib.mkEnableOption "per-tag layouts and saved named layouts";

        tags = lib.mkOption {
          type = lib.types.attrsOf (tagSpec lib);
          default = { };
          description = "Per-tag layout assignments, keyed by tag id.";
        };

        saved = lib.mkOption {
          type = lib.types.attrsOf (savedSpec lib);
          default = { };
          description = "Saved layout rows, grouped by preset name.";
        };

        preset = lib.mkOption {
          type = lib.types.nullOr lib.types.nonEmptyStr;
          default = null;
          description = "Saved layout name used as the baseline. tags overrides it.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Advanced workspaces"; group = "Patches"; description = "Enable per-tag layouts and saved named layouts.";
          ojuny.patch.advancedWorkspaces.enable = false;

          # @option widget = "text"; label = "Active saved layout"; group = "Advanced workspaces"; groupOrder = 10; order = 10; nullable = true; description = "Saved layout used as the baseline. Per-tag layouts override the same tag. Empty leaves only per-tag layouts."; visibleWhen.path = "ojuny.patch.advancedWorkspaces.enable"; visibleWhen.equals = true;
          ojuny.patch.advancedWorkspaces.preset = null;

          # @option widget = "table-attrset"; label = "Per-tag layouts"; group = "Advanced workspaces"; groupOrder = 10; order = 20; columns = [ "layout" "masterCount" "masterFactor" "monitor" ]; columnTypes = [ "str" "int" "float" "str" ]; keyEditable = true; firstValueEditable = true; description = "Tag id to layout. masterCount 0 and masterFactor 0 leave Mango defaults. Empty monitor applies to every monitor."; visibleWhen.path = "ojuny.patch.advancedWorkspaces.enable"; visibleWhen.equals = true;
          ojuny.patch.advancedWorkspaces.tags = { };

          # @option widget = "table-attrset"; label = "Saved layouts"; group = "Advanced workspaces"; groupOrder = 10; order = 30; advanced = true; columns = [ "preset" "tag" "layout" "masterCount" "masterFactor" "monitor" ]; columnTypes = [ "str" "int" "str" "int" "float" "str" ]; keyEditable = false; firstValueEditable = true; description = "Rows sharing a preset name form one saved layout. Select it with Active saved layout."; visibleWhen.path = "ojuny.patch.advancedWorkspaces.enable"; visibleWhen.equals = true;
          ojuny.patch.advancedWorkspaces.saved = { };
        }

        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = lib.all (tag: builtins.match "[0-9]+" tag != null) (lib.attrNames cfg.tags);
              message = "ojuny.patch.advancedWorkspaces.tags keys must be numeric tag ids.";
            }
            {
              assertion = lib.all (tag: lib.toInt tag <= tagNum) (lib.attrNames cfg.tags);
              message = "ojuny.patch.advancedWorkspaces.tags contains a tag id above desktop.ojuny.mango.global.tag_num.";
            }
            {
              assertion = lib.all (row: row.tag <= tagNum) savedRows;
              message = "ojuny.patch.advancedWorkspaces.saved contains a tag id above desktop.ojuny.mango.global.tag_num.";
            }
            {
              assertion = cfg.preset == null || lib.any (row: row.preset == cfg.preset) savedRows;
              message = "ojuny.patch.advancedWorkspaces.preset does not name a saved layout.";
            }
            {
              assertion = lib.all (name: !presetHasDuplicateTags name) presetNames;
              message = "ojuny.patch.advancedWorkspaces.saved has duplicate tag ids inside one preset.";
            }
          ];

          desktop.ojuny.mango.rules.tag_rule = lib.mkAfter tagRules;
        })
      ];
    };
}
