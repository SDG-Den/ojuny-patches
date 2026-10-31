/*
  @menu
  displayname = "Hooks";
  icon = "system-run-symbolic";
  order = 210;
  description = "Typed lifecycle hooks with validation, logging, retries and rollback boundaries";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-hooks =
    { config, lib, ... }:
    {
      options.ojuny.patch.hooks.enable = lib.mkEnableOption "typed lifecycle hooks";

      imports = [ self.modules.nixos.hooks-backend ];

      config = {
        # @option widget = "switch"; label = "Hooks"; group = "Hooks"; groupOrder = 10; description = "Enable typed lifecycle hooks with validation, logging and retries.";
        ojuny.patch.hooks.enable = false;

        # @option widget = "raw"; label = "Pre-rebuild hooks"; group = "Events"; groupOrder = 20; order = 10; rows = 10; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "Attrset of hooks run by ojuny-rebuild before nixos-rebuild. Shape: name = { order = 100; command = [ ... ]; as = \"root\"; user = null; timeoutSeconds = 30; retries = 0; retryDelaySeconds = 5; onFailure = \"abort\"; environment = { }; };";
        ojuny.patch.hooks.events.preRebuild = { };

        # @option widget = "raw"; label = "Post-boot hooks"; group = "Events"; groupOrder = 20; order = 20; rows = 10; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "Attrset of hooks run once per boot by the post-boot dispatcher.";
        ojuny.patch.hooks.events.postBoot = { };

        # @option widget = "raw"; label = "Post-update hooks"; group = "Events"; groupOrder = 20; order = 30; rows = 10; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "Attrset of hooks run by ojuny-rebuild after a successful activation.";
        ojuny.patch.hooks.events.postUpdate = { };

        # @option widget = "text"; label = "Log directory"; group = "Logging"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "Root directory for per-attempt hook logs.";
        ojuny.patch.hooks.logging.directory = "/var/log/ojuny/hooks";

        # @option widget = "spin"; label = "Keep logs for days"; group = "Logging"; groupOrder = 30; order = 20; min = 1; max = 365; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "The daily prune removes hook logs older than this.";
        ojuny.patch.hooks.logging.retainDays = 30;

        # @option widget = "switch"; label = "Log full command"; group = "Logging"; groupOrder = 30; order = 30; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "Write the argv list to each attempt log. Off by default because arguments can contain secrets.";
        ojuny.patch.hooks.logging.includeCommand = false;

        # @option widget = "switch"; label = "Mark degraded generation"; group = "Rollback"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.hooks.enable"; visibleWhen.equals = true; description = "When an aborting post-update hook fails, record the previous generation and exit 2 instead of silently accepting the update.";
        ojuny.patch.hooks.rollback.markDegraded = true;
      };
    };

  flake.modules.nixos.hooks-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.hooks.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.hooks // {
        enable = active;
      };
      patchesEnabled = lib.attrByPath [ "ojuny" "patches" ] true config;

      eventNames = [
        "preRebuild"
        "postBoot"
        "postUpdate"
      ];

      hookNamePattern = "[A-Za-z0-9][A-Za-z0-9_-]*";
      envNamePattern = "[A-Za-z_][A-Za-z0-9_]*";

      hookType = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Run this hook. Disabled hooks are shown in the GUI but do not run; custom assertions only apply to enabled hooks.";
          };

          order = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "Run order within the event. Lower runs first; ties sort by hook name.";
          };

          command = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "/run/current-system/sw/bin/notify-send"
              "update finished"
            ];
            description = "Command as an argv list. No shell is involved unless the list starts with a shell.";
          };

          as = lib.mkOption {
            type = lib.types.enum [
              "root"
              "user"
            ];
            default = "root";
            description = "Run the child as root or as the configured user.";
          };

          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "User name for as = \"user\". Must exist in users.users.";
          };

          timeoutSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 30;
            description = "Maximum seconds for one attempt.";
          };

          retries = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 0;
            description = "Additional attempts after the first failure.";
          };

          retryDelaySeconds = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 5;
            description = "Seconds between attempts.";
          };

          onFailure = lib.mkOption {
            type = lib.types.enum [
              "abort"
              "continue"
            ];
            default = "abort";
            description = "For every event, stop the remaining hooks or continue with later hooks.";
          };

          environment = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Extra environment variables for the child process.";
          };
        };
      };

      hookEvents = lib.types.attrsOf hookType;

      enabledHooks =
        event:
        lib.mapAttrsToList (name: hook: hook // { inherit name; }) (
          lib.filterAttrs (_: hook: hook.enable) cfg.events.${event}
        );

      sortedHooks =
        event:
        lib.sort (a: b: a.order < b.order || (a.order == b.order && a.name < b.name)) (enabledHooks event);

      allHooks = lib.concatMap (
        event: map (hook: hook // { inherit event; }) (sortedHooks event)
      ) eventNames;

      logDir = cfg.logging.directory;
      stateDir = "/var/lib/ojuny/hooks";
      statusDir = "${stateDir}/status";
      degradedFile = "${stateDir}/degraded";
      previousFile = "${stateDir}/previous-generation";
      pendingFile = "${stateDir}/pending-postupdate";

      unitName = event: name: "ojuny-hook-${lib.toLower event}-${name}.service";

      envArgs = hook: lib.mapAttrsToList (key: value: "${key}=${value}") hook.environment;

      hookArgs =
        hook:
        (
          if hook.as == "user" then
            [
              "${pkgs.util-linux}/bin/runuser"
              "-u"
              hook.user
              "--"
              "${pkgs.coreutils}/bin/env"
            ]
          else
            [ "${pkgs.coreutils}/bin/env" ]
        )
        ++ envArgs hook
        ++ hook.command;

      runner = pkgs.writeShellApplication {
        name = "ojuny-hook-runner";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gnugrep
          util-linux
        ];
        text = ''
          event=""
          hook=""
          timeout_seconds=30
          retries=0
          delay=5
          log_dir=""
          status_dir=""
          state_dir=""
          include_command=0

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --event) event="$2"; shift 2 ;;
              --hook) hook="$2"; shift 2 ;;
              --timeout) timeout_seconds="$2"; shift 2 ;;
              --retries) retries="$2"; shift 2 ;;
              --delay) delay="$2"; shift 2 ;;
              --log-dir) log_dir="$2"; shift 2 ;;
              --status-dir) status_dir="$2"; shift 2 ;;
              --state-dir) state_dir="$2"; shift 2 ;;
              --include-command) include_command=1; shift ;;
              --) shift; break ;;
              *) echo "ojuny-hook-runner: unknown argument: $1" >&2; exit 2 ;;
            esac
          done

          if [ "$#" -eq 0 ]; then
            echo "ojuny-hook-runner: missing command" >&2
            exit 2
          fi

          case "$event" in
            preRebuild|postBoot|postUpdate) ;;
            *) echo "ojuny-hook-runner: invalid event: $event" >&2; exit 2 ;;
          esac

          if ! printf '%s' "$hook" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*$'; then
            echo "ojuny-hook-runner: invalid hook name: $hook" >&2
            exit 2
          fi

          umask 0027
          mkdir -p "$log_dir/$event/$hook" "$status_dir" "$state_dir"
          exec 9>"$state_dir/$event.$hook.lock"
          flock 9

          if [ -r "$state_dir/previous-generation" ]; then
            OJUNY_PREVIOUS_GENERATION="$(cat "$state_dir/previous-generation")"
            export OJUNY_PREVIOUS_GENERATION
          fi

          export OJUNY_HOOK_EVENT="$event"
          export OJUNY_HOOK_NAME="$hook"
          export OJUNY_HOOKS_ACTIVE=1

          started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          attempts=$((retries + 1))
          attempt=1
          exit_code=1
          log_file="$log_dir/$event/$hook/$(date -u +%Y%m%dT%H%M%SZ)-attempt-1.log"

          for attempt in $(seq 1 "$attempts"); do
            log_file="$log_dir/$event/$hook/$(date -u +%Y%m%dT%H%M%SZ)-attempt-$attempt.log"
            {
              printf 'event=%s\n' "$event"
              printf 'hook=%s\n' "$hook"
              printf 'attempt=%s\n' "$attempt"
              printf 'started=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
              if [ "$include_command" -eq 1 ]; then
                printf 'argv='
                printf '%q ' "$@"
                printf '\n'
              fi
            } > "$log_file"

            if timeout --signal=TERM --kill-after=5s "''${timeout_seconds}s" "$@" 2>&1 | tee -a "$log_file"; then
              exit_code=0
            else
              exit_code="''${PIPESTATUS[0]}"
            fi

            printf 'exit_code=%s\n' "$exit_code" >> "$log_file"

            if [ "$exit_code" -eq 0 ]; then
              break
            fi

            if [ "$attempt" -lt "$attempts" ]; then
              sleep "$delay"
            fi
          done

          finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          status_tmp="$status_dir/$event.$hook.env.tmp.$$"
          {
            printf 'event=%s\n' "$event"
            printf 'hook=%s\n' "$hook"
            printf 'attempts=%s\n' "$attempt"
            printf 'exit_code=%s\n' "$exit_code"
            printf 'started=%s\n' "$started"
            printf 'finished=%s\n' "$finished"
            printf 'log=%s\n' "$log_file"
          } > "$status_tmp"
          mv "$status_tmp" "$status_dir/$event.$hook.env"
          chmod 0644 "$status_dir/$event.$hook.env"

          exit "$exit_code"
        '';
      };

      mkHookScript =
        event: hook:
        pkgs.writeShellApplication {
          name = "ojuny-hook-${lib.toLower event}-${hook.name}";
          runtimeInputs = with pkgs; [
            coreutils
            util-linux
          ];
          text = ''
            exec ${runner}/bin/ojuny-hook-runner \
              --event ${lib.escapeShellArg event} \
              --hook ${lib.escapeShellArg hook.name} \
              --timeout ${toString hook.timeoutSeconds} \
              --retries ${toString hook.retries} \
              --delay ${toString hook.retryDelaySeconds} \
              --log-dir ${lib.escapeShellArg logDir} \
              --status-dir ${lib.escapeShellArg statusDir} \
              --state-dir ${lib.escapeShellArg stateDir} \
              ${lib.optionalString cfg.logging.includeCommand "--include-command"} \
              -- ${lib.escapeShellArgs (hookArgs hook)}
          '';
        };

      hookScripts = lib.genAttrs eventNames (
        event:
        lib.listToAttrs (
          map (hook: lib.nameValuePair hook.name (mkHookScript event hook)) (sortedHooks event)
        )
      );

      hookUnits = lib.listToAttrs (
        map (hook: {
          name = unitName hook.event hook.name;
          value = {
            description = "Ojuny ${hook.event} hook ${hook.name}";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${
                hookScripts.${hook.event}.${hook.name}
              }/bin/ojuny-hook-${lib.toLower hook.event}-${hook.name}";
              TimeoutStartSec = "${
                toString (hook.timeoutSeconds * (hook.retries + 1) + hook.retryDelaySeconds * hook.retries + 30)
              }s";
              RemainAfterExit = false;
              Restart = "no";
              StandardOutput = "journal";
              StandardError = "journal";
              SyslogIdentifier = "ojuny-hook-${lib.toLower hook.event}-${hook.name}";
            };
          };
        }) allHooks
      );

      dispatchCase =
        event:
        lib.concatMapStringsSep "\n" (hook: ''
          if [ "$rc" -eq 0 ]; then
            if systemctl start --wait ${lib.escapeShellArg (unitName event hook.name)}; then
              :
            else
              case ${lib.escapeShellArg hook.onFailure} in
                abort) rc=1 ;;
                continue) printf 'ojuny-hooks: %s/%s failed; continuing\n' ${lib.escapeShellArg event} ${lib.escapeShellArg hook.name} >&2 ;;
              esac
            fi
          fi
        '') (sortedHooks event);

      dispatcher = pkgs.writeShellApplication {
        name = "ojuny-hooks-run";
        runtimeInputs = with pkgs; [
          coreutils
          systemd
        ];
        text = ''
          event="''${1:-}"
          case "$event" in
            preRebuild|postBoot|postUpdate) ;;
            *) echo "usage: ojuny-hooks-run preRebuild|postBoot|postUpdate" >&2; exit 2 ;;
          esac

          if [ -n "''${OJUNY_HOOKS_ACTIVE:-}" ]; then
            echo "ojuny-hooks-run: refusing recursive call from a hook" >&2
            exit 2
          fi
          export OJUNY_HOOKS_ACTIVE=1

          rc=0
          case "$event" in
            preRebuild)
          ${dispatchCase "preRebuild"}
              ;;
            postBoot)
          ${dispatchCase "postBoot"}
              ;;
            postUpdate)
          ${dispatchCase "postUpdate"}
              ;;
          esac
          exit "$rc"
        '';
      };

      status = pkgs.writeShellApplication {
        name = "ojuny-hooks-status";
        runtimeInputs = with pkgs; [
          coreutils
        ];
        text = ''
          status_dir=${lib.escapeShellArg statusDir}
          degraded=${lib.escapeShellArg degradedFile}

          if [ ! -d "$status_dir" ]; then
            echo "ojuny-hooks: no hook runs recorded"
            exit 0
          fi

          printf '%-12s %-20s %-8s %-8s %s\n' EVENT HOOK EXIT ATTEMPTS LOG
          for file in "$status_dir"/*.env; do
            [ -r "$file" ] || continue
            event=""; hook=""; exit_code=""; attempts=""; log=""
            while IFS='=' read -r key value; do
              case "$key" in
                event) event="$value" ;;
                hook) hook="$value" ;;
                exit_code) exit_code="$value" ;;
                attempts) attempts="$value" ;;
                log) log="$value" ;;
              esac
            done < "$file"
            printf '%-12s %-20s %-8s %-8s %s\n' "$event" "$hook" "$exit_code" "$attempts" "$log"
          done

          if [ -r "$degraded" ]; then
            printf '\ndegraded generation:\n'
            cat "$degraded"
          fi
        '';
      };

      clean = pkgs.writeShellApplication {
        name = "ojuny-hooks-clean";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
        ];
        text = ''
          [ -d ${lib.escapeShellArg logDir} ] || exit 0
          find ${lib.escapeShellArg logDir} -type f -mtime +${toString cfg.logging.retainDays} -delete
          find ${lib.escapeShellArg logDir} -mindepth 1 -type d -empty -delete
        '';
      };

      pending = pkgs.writeShellApplication {
        name = "ojuny-hooks-pending";
        runtimeInputs = with pkgs; [
          coreutils
          systemd
        ];
        text = ''
          pending=${lib.escapeShellArg pendingFile}
          degraded=${lib.escapeShellArg degradedFile}
          previous_file=${lib.escapeShellArg previousFile}

          [ -r "$pending" ] || exit 0

          if ${dispatcher}/bin/ojuny-hooks-run postUpdate; then
            rm -f "$pending" "$degraded"
            exit 0
          fi

          rm -f "$pending"
          previous="$(cat "$previous_file" 2>/dev/null || echo unknown)"
          ${lib.optionalString cfg.rollback.markDegraded ''
            printf 'previous_generation=%s\nfailed_at=%s\n' "$previous" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > ${lib.escapeShellArg degradedFile}.tmp
            mv ${lib.escapeShellArg degradedFile}.tmp ${lib.escapeShellArg degradedFile}
          ''}
          echo "ojuny-hooks-pending: post-update hook failed after boot" >&2
          echo "previous generation: $previous" >&2
          echo "recover with: sudo nixos-rebuild switch --rollback" >&2
          exit 2
        '';
      };

      rebuild = pkgs.writeShellApplication {
        name = "ojuny-rebuild";
        runtimeInputs = with pkgs; [
          coreutils
          nixos-rebuild
          systemd
          util-linux
        ];
        text = ''
          if [ -n "''${OJUNY_HOOKS_ACTIVE:-}" ]; then
            echo "ojuny-rebuild: refusing recursive call from a hook" >&2
            exit 2
          fi

          if [ "$#" -eq 0 ]; then
            echo "usage: ojuny-rebuild <switch|boot|test|build|dry-build|dry-activate> <nixos-rebuild arguments...>" >&2
            exit 2
          fi

          subcommand="$1"
          case "$subcommand" in
            switch|test) run_postupdate=1 ;;
            boot|build|dry-build|dry-activate) run_postupdate=0 ;;
            *)
              echo "ojuny-rebuild: unsupported subcommand: $subcommand" >&2
              echo "usage: ojuny-rebuild <switch|boot|test|build|dry-build|dry-activate> <nixos-rebuild arguments...>" >&2
              exit 2
              ;;
          esac

          previous="$(readlink -f /run/current-system)"
          install -d -m 0755 ${lib.escapeShellArg stateDir}
          printf '%s\n' "$previous" > ${lib.escapeShellArg previousFile}

          if ! ${dispatcher}/bin/ojuny-hooks-run preRebuild; then
            echo "ojuny-rebuild: pre-rebuild hook failed; rebuild aborted" >&2
            exit 1
          fi

          nixos-rebuild "$@" || exit $?

          if [ "$subcommand" = "boot" ]; then
            : > ${lib.escapeShellArg pendingFile}
            echo "ojuny-rebuild: post-update hooks will run on the next boot" >&2
            exit 0
          fi

          if [ "$run_postupdate" -eq 1 ]; then
            rm -f ${lib.escapeShellArg pendingFile}
            if ! ${dispatcher}/bin/ojuny-hooks-run postUpdate; then
              ${lib.optionalString cfg.rollback.markDegraded ''
                printf 'previous_generation=%s\nfailed_at=%s\n' "$previous" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > ${lib.escapeShellArg degradedFile}.tmp
                mv ${lib.escapeShellArg degradedFile}.tmp ${lib.escapeShellArg degradedFile}
              ''}
              echo "ojuny-rebuild: post-update hook failed" >&2
              echo "previous generation: $previous" >&2
              echo "recover with: sudo nixos-rebuild switch --rollback" >&2
              exit 2
            fi
            rm -f ${lib.escapeShellArg degradedFile} ${lib.escapeShellArg pendingFile}
          fi
        '';
      };

      hookAssertions =
        map (hook: {
          assertion = hook.command != [ ] && (builtins.head hook.command) != "";
          message = "ojuny.patch.hooks: ${hook.event}/${hook.name} needs a non-empty command argv.";
        }) allHooks
        ++ map (hook: {
          assertion =
            hook.as != "user"
            || (hook.user != null && hook.user != "" && (builtins.hasAttr hook.user config.users.users));
          message = "ojuny.patch.hooks: ${hook.event}/${hook.name} sets as = \"user\" but user does not exist.";
        }) allHooks
        ++ map (hook: {
          assertion = builtins.all (key: builtins.match envNamePattern key != null) (
            builtins.attrNames hook.environment
          );
          message = "ojuny.patch.hooks: ${hook.event}/${hook.name} has an invalid environment variable name.";
        }) allHooks
        ++ lib.concatMap (
          event:
          lib.mapAttrsToList (name: _: {
            assertion = builtins.match hookNamePattern name != null;
            message = "ojuny.patch.hooks: hook name '${name}' in ${event} must match ${hookNamePattern}.";
          }) cfg.events.${event}
        ) eventNames
        ++ [
          {
            assertion = cfg.logging.directory != "" && lib.hasPrefix "/" cfg.logging.directory;
            message = "ojuny.patch.hooks: logging.directory must be an absolute path.";
          }
        ];
    in
    {
      options.ojuny.patch.hooks = {
        events = {
          preRebuild = lib.mkOption {
            type = hookEvents;
            default = { };
            description = "Hooks run by ojuny-rebuild before nixos-rebuild.";
          };
          postBoot = lib.mkOption {
            type = hookEvents;
            default = { };
            description = "Hooks run once per boot by the post-boot dispatcher.";
          };
          postUpdate = lib.mkOption {
            type = hookEvents;
            default = { };
            description = "Hooks run by ojuny-rebuild after a successful activation.";
          };
        };

        logging = {
          directory = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/ojuny/hooks";
            description = "Root directory for per-attempt hook logs.";
          };
          retainDays = lib.mkOption {
            type = lib.types.ints.positive;
            default = 30;
            description = "Number of days to keep hook logs.";
          };
          includeCommand = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Log the argv list. Off by default to avoid leaking arguments.";
          };
        };

        rollback.markDegraded = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Write a degraded marker when an aborting postUpdate hook fails.";
        };
      };

      config = lib.mkIf (patchesEnabled && cfg.enable) {
          assertions = hookAssertions;

          warnings =
            lib.optional (cfg.events.preRebuild != { } || cfg.events.postUpdate != { })
              "ojuny.patch.hooks: preRebuild and postUpdate hooks only run when every rebuild surface calls ojuny-rebuild. Direct nixos-rebuild calls bypass them.";

          environment.systemPackages = [
            dispatcher
            status
            clean
            pending
            rebuild
          ];

          systemd.tmpfiles.rules = [
            "d ${cfg.logging.directory} 0750 root root -"
            "d /var/lib/ojuny/hooks 0755 root root -"
            "d /var/lib/ojuny/hooks/status 0755 root root -"
          ];

          systemd.services =
            hookUnits
            // lib.optionalAttrs (sortedHooks "postBoot" != [ ]) {
              ojuny-hooks-postboot = {
                description = "Ojuny post-boot hooks";
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${dispatcher}/bin/ojuny-hooks-run postBoot";
                  TimeoutStartSec = "${
                    toString (
                      lib.foldl' (
                        total: hook:
                        total + hook.timeoutSeconds * (hook.retries + 1) + hook.retryDelaySeconds * hook.retries + 30
                      ) 0 (sortedHooks "postBoot")
                      + 30
                    )
                  }s";
                };
              };
            }
            // {
              ojuny-hooks-pending-postupdate = {
                description = "Ojuny pending post-update hooks";
                wantedBy = [ "multi-user.target" ];
                after = lib.optional (sortedHooks "postBoot" != [ ]) "ojuny-hooks-postboot.service";
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pending}/bin/ojuny-hooks-pending";
                  TimeoutStartSec = "${
                    toString (
                      lib.foldl' (
                        total: hook:
                        total + hook.timeoutSeconds * (hook.retries + 1) + hook.retryDelaySeconds * hook.retries + 30
                      ) 0 (sortedHooks "postUpdate")
                      + 30
                    )
                  }s";
                };
              };

              ojuny-hooks-prune = {
                description = "Prune old Ojuny hook logs";
                serviceConfig.Type = "oneshot";
                serviceConfig.ExecStart = "${clean}/bin/ojuny-hooks-clean";
              };
            };

          systemd.timers.ojuny-hooks-prune = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              Persistent = true;
            };
          };
      };
    };
}
