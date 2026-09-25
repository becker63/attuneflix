{
  description = "AttuneFlix developer shell; Bazel owns project derivation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      perSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # BuildBuddy authentication stays outside Bazel's declared action
          # inputs. A Factory Computer Secret in BUILDBUDDY_API_KEY or the
          # ignored .env value is returned only to the credential request and
          # is never exported into the client environment.
          buildbuddyCredential = pkgs.writeShellScriptBin
            "attune-buildbuddy-credential" ''
              set -eu
              if [ "''${1:-}" != get ]; then
                echo "unsupported credential-helper command" >&2
                exit 1
              fi
              read -r _request || true

              # Factory managed Droid Computers inject BUILDBUDDY_API_KEY as a
              # Computer Secret. Use it directly when present; the ignored
              # workspace .env remains the local-development fallback.
              key="''${BUILDBUDDY_API_KEY:-}"
              if [ -z "$key" ]; then
                workspace="''${ATTUNE_WORKSPACE:-$PWD}"
                if [ ! -f "$workspace/.env" ]; then
                  echo "ignored workspace .env not found" >&2
                  exit 1
                fi
                key=$(
                  ${pkgs.gawk}/bin/awk '
                    /^BUILDBUDDY_API_KEY=/ {
                      if (found) exit 2
                      sub(/^[^=]*=/, "")
                      print
                      found = 1
                    }
                    END { if (!found) exit 1 }
                  ' "$workspace/.env"
                )
              fi
              case "$key" in
                ""|*[!A-Za-z0-9._~-]*)
                  echo "BUILDBUDDY_API_KEY is missing or malformed" >&2
                  exit 1
                  ;;
              esac
              printf '{"headers":{"x-buildbuddy-api-key":["%s"]}}\n' "$key"
            '';

          # Bazel receives a small allowlisted client environment rather than
          # the caller's desktop, Nix shell, SSH agent, or provider secrets.
          bazel = pkgs.writeShellScriptBin "bazel" ''
            set -eu
            workspace="$PWD"
            while [ "$workspace" != / ] && [ ! -f "$workspace/MODULE.bazel" ]; do
              workspace="$(${pkgs.coreutils}/bin/dirname -- "$workspace")"
            done
            repin_environment=
            if [ "''${REPIN:-}" = 1 ]; then
              repin_environment=REPIN=1
            fi
            # Forward a Factory Computer Secret to the credential helper when
            # present. The validated key charset has no separators, so the
            # conditional-argument shape used for REPIN is safe here too.
            buildbuddy_key_environment=
            if [ -n "''${BUILDBUDDY_API_KEY:-}" ]; then
              buildbuddy_key_environment=BUILDBUDDY_API_KEY="''${BUILDBUDDY_API_KEY}"
            fi
            exec ${pkgs.coreutils}/bin/env -i \
              HOME="$HOME" \
              USER="''${USER:-unknown}" \
              ATTUNE_WORKSPACE="$workspace" \
              $repin_environment \
              $buildbuddy_key_environment \
              BAZELISK_SKIP_WRAPPER=true \
              USE_BAZEL_VERSION=8.6.0 \
              PATH=${pkgs.lib.makeBinPath [
                pkgs.bash
                pkgs.bazelisk
                pkgs.coreutils
                pkgs.findutils
                pkgs.gawk
                pkgs.gcc
                pkgs.git
                pkgs.gnugrep
                pkgs.gnused
                pkgs.which
              ]} \
              SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
              ${pkgs.bazelisk}/bin/bazelisk "$@" \
                --credential_helper=remote.buildbuddy.io=${buildbuddyCredential}/bin/attune-buildbuddy-credential
          '';

          # Smallest deterministic law for the credential helper: a Factory
          # Computer Secret wins, the ignored .env stays a working fallback,
          # and malformed keys are still rejected. Dummy values only.
          credentialHelperCheck = pkgs.runCommand "attune-credential-helper-check" { } ''
            set -eu
            helper=${buildbuddyCredential}/bin/attune-buildbuddy-credential
            envelope() { printf '{"headers":{"x-buildbuddy-api-key":["%s"]}}' "$1"; }
            expect() {
              expected=$1
              shift
              actual=$(printf 'remote.buildbuddy.io\n' | env "$@" $helper get)
              if [ "$actual" != "$expected" ]; then
                echo "credential helper produced: $actual" >&2
                exit 1
              fi
            }

            # Factory Computer Secret path: an environment key wins over .env.
            mkdir env-first
            printf 'BUILDBUDDY_API_KEY=dotenv-value\n' > env-first/.env
            expect "$(envelope env-secret-value)" \
              BUILDBUDDY_API_KEY=env-secret-value ATTUNE_WORKSPACE=$PWD/env-first

            # Local fallback: the ignored workspace .env still supplies the key.
            mkdir fallback
            printf 'BUILDBUDDY_API_KEY=dotenv-value\n' > fallback/.env
            expect "$(envelope dotenv-value)" ATTUNE_WORKSPACE=$PWD/fallback

            # A malformed environment key is rejected instead of forwarded.
            if printf 'remote.buildbuddy.io\n' | env BUILDBUDDY_API_KEY='bad key' ATTUNE_WORKSPACE=$PWD $helper get >/dev/null 2>&1; then
              echo "malformed key was accepted" >&2
              exit 1
            fi
            touch $out
          '';
        in {
          devShell = pkgs.mkShell {
            packages = [
              bazel
              pkgs.bazel-buildtools
              pkgs.git
              pkgs.jq
              pkgs.jujutsu
              pkgs.util-linux
            ];
          };
          inherit credentialHelperCheck;
        };
    in {
      devShells = forAllSystems (system: { default = (perSystem system).devShell; });
      checks = forAllSystems (system: { credential-helper = (perSystem system).credentialHelperCheck; });
    };
}
