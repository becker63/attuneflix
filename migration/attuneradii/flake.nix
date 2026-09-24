{
  description = "Attune Radii";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    crane.url = "github:ipetkov/crane";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    {
      crane,
      nixpkgs,
      pyproject-build-systems,
      pyproject-nix,
      uv2nix,
      ...
    }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      environment =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python313;

          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = ./.;
          };

          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };

          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                pkgs.lib.composeManyExtensions [
                  pyproject-build-systems.overlays.wheel
                  overlay
                ]
              );

          nixComponents = pkgs.nixVersions.nixComponents_2_34;

          nixUtilC = nixComponents."nix-util-c";
          nixStoreC = nixComponents."nix-store-c";
          nixExprC = nixComponents."nix-expr-c";
          nixFetchersC = nixComponents."nix-fetchers-c";
          nixFlakeC = nixComponents."nix-flake-c";

          nixUtilCDev = pkgs.lib.getDev nixUtilC;
          nixStoreCDev = pkgs.lib.getDev nixStoreC;
          nixExprCDev = pkgs.lib.getDev nixExprC;
          nixFetchersCDev = pkgs.lib.getDev nixFetchersC;
          nixFlakeCDev = pkgs.lib.getDev nixFlakeC;

          nixUtilCLib = pkgs.lib.getLib nixUtilC;
          nixStoreCLib = pkgs.lib.getLib nixStoreC;
          nixExprCLib = pkgs.lib.getLib nixExprC;
          nixFetchersCLib = pkgs.lib.getLib nixFetchersC;
          nixFlakeCLib = pkgs.lib.getLib nixFlakeC;

          clang19 = pkgs.llvmPackages_19.clang;
          libclang19 = pkgs.llvmPackages_19.libclang.lib;
          libcDev = pkgs.lib.getDev pkgs.stdenv.cc.libc;

          nixAbiGenerator = pythonSet.mkVirtualEnv "attune-nix-abi-generator-env" {
            clang = [ ];
            ctypeslib2 = [ ];
          };

          nixAbiHeader = pkgs.writeText "attune-nix-abi.h" ''
            #include <stddef.h>
            #include <stdint.h>
            #include <stdbool.h>

            #include <nix_api_util.h>
            #include <nix_api_store.h>
            #include <nix_api_store/store_path.h>
            #include <nix_api_expr.h>
            #include <nix_api_value.h>
            #include <nix_api_flake.h>
          '';

          nixAbi =
            pkgs.runCommand "attune-nix-abi"
              {
                nativeBuildInputs = [
                  nixAbiGenerator
                ];

                CLANG_LIBRARY_PATH = "${libclang19}/lib";

                passthru = {
                  dependencies = { };
                  optional-dependencies = { };
                };
              }
              ''
                site="$out/${python.sitePackages}"

                mkdir -p "$site"

                clang2py \
                  -d \
                  -e \
                  -i \
                  -k cdefstu \
                  -r '^(nix_|NIX_|Store$|StorePath$|EvalState$|ValueType$|nix_value$|nix_c_context$)' \
                  --nm ${pkgs.binutils}/bin/nm \
                  -l ${nixUtilCLib}/lib/libnixutilc.so \
                  -l ${nixStoreCLib}/lib/libnixstorec.so \
                  -l ${nixExprCLib}/lib/libnixexprc.so \
                  -l ${nixFetchersCLib}/lib/libnixfetchersc.so \
                  -l ${nixFlakeCLib}/lib/libnixflakec.so \
                  --clang-args='-std=c17 -I${nixUtilCDev}/include -I${nixStoreCDev}/include -I${nixExprCDev}/include -I${nixFetchersCDev}/include -I${nixFlakeCDev}/include -isystem${clang19}/resource-root/include -isystem${libcDev}/include -resource-dir=${clang19}/resource-root' \
                  -o "$site/_attune_nix_abi.py" \
                  ${nixAbiHeader}

                ${python.interpreter} -m py_compile \
                  "$site/_attune_nix_abi.py"
              '';

          craneLib = crane.mkLib pkgs;

          gritRustSource = craneLib.cleanCargoSource ./native/grit;

          # native/grit/Cargo.toml owns the parser feature policy. Upstream
          # Marzano still gates concrete parser implementations on one broad
          # `builtin-parser` cfg, so project only the selected implementations
          # onto their individual optional dependency features.
          gritParserModules = {
            "go.rs" = "tree-sitter-go";
            "java.rs" = "tree-sitter-java";
            "javascript.rs" = "tree-sitter-javascript";
            "php.rs" = "tree-sitter-php";
            "php_only.rs" = "tree-sitter-php";
            "python.rs" = "tree-sitter-python";
            "ruby.rs" = "tree-sitter-ruby";
            "rust.rs" = "tree-sitter-rust";
            "tsx.rs" = "tree-sitter-typescript";
            "typescript.rs" = "tree-sitter-typescript";
          };

          gritParserCfgPatch = pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (file: feature: ''
              substituteInPlace "crates/language/src/${file}" \
                --replace-fail \
                '#[cfg(not(feature = "builtin-parser"))]' \
                '#[cfg(not(feature = "${feature}"))]' \
                --replace-fail \
                '#[cfg(feature = "builtin-parser")]' \
                '#[cfg(feature = "${feature}")]'
            '') gritParserModules
          );

          gritVendorGitCheckout =
            packages: drv:
            if pkgs.lib.any (package: (package.name or "") == "marzano-language") packages then
              drv.overrideAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                  # Upstream source-only grammar repositories contain package
                  # manifests duplicating the actual language-metavariable
                  # crates. Hide those manifests from Crane package discovery.
                  if [ -d resources/language-submodules ]; then
                    ${pkgs.findutils}/bin/find \
                      resources/language-submodules \
                      -type f \
                      -name Cargo.toml \
                      -delete
                  fi

                  # tree-sitter-php 0.22.2 is a selected parent package whose
                  # build script compiles php/src and php_only/src. These two
                  # directories also carry obsolete nested package manifests;
                  # hiding the manifests keeps their generated parser sources
                  # inside the selected parent package.
                  rm -f \
                    resources/language-metavariables/tree-sitter-php/php/Cargo.toml \
                    resources/language-metavariables/tree-sitter-php/php_only/Cargo.toml

                  # Cargo.toml selects the parser dependencies. Upstream
                  # language implementations still key off the broad
                  # builtin-parser cfg, so project only the selected modules
                  # onto their actual optional parser features.
                  ${gritParserCfgPatch}
                '';

                postInstall = (old.postInstall or "") + ''
                  language="$out/marzano-language-0.1.0"

                  if [ ! -d "$language/src" ]; then
                    echo \
                      "Crane produced no marzano-language-0.1.0 package" \
                      >&2
                    exit 1
                  fi

                  if [ ! -d resources/node-types ]; then
                    echo \
                      "pinned Grit checkout has no resources/node-types" \
                      >&2
                    exit 1
                  fi

                  # marzano-language embeds its syntax metadata with
                  # include_str!, but the upstream paths leave the Cargo crate.
                  # Internalize those immutable JSON assets into the vendored
                  # package so its compilation no longer depends on repository
                  # layout.
                  mkdir -p "$language/node-types"

                  cp -R \
                    resources/node-types/. \
                    "$language/node-types/"

                  ${pkgs.gnused}/bin/sed \
                    -i \
                    's#../../../resources/node-types/#../node-types/#g' \
                    "$language"/src/*.rs

                  # Fail immediately if this pinned revision gains another
                  # repository-relative node-types reference we did not project.
                  if ${pkgs.gnugrep}/bin/grep \
                    -R \
                    -n \
                    -F \
                    '../../../resources/node-types/' \
                    "$language/src"
                  then
                    echo \
                      "unprojected marzano-language node-types reference" \
                      >&2
                    exit 1
                  fi

                  node_type_count="$(
                    ${pkgs.findutils}/bin/find \
                      "$language/node-types" \
                      -type f \
                      -name '*-node-types.json' \
                      | wc -l
                  )"

                  if [ "$node_type_count" -lt 1 ]; then
                    echo \
                      "marzano-language projection copied no node-type metadata" \
                      >&2
                    exit 1
                  fi

                  echo \
                    "marzano-language node-types internalized: $node_type_count"
                '';
              })
            else
              drv;

          gritCargoVendor = craneLib.vendorCargoDeps {
            src = gritRustSource;
            overrideVendorGitCheckout = gritVendorGitCheckout;
          };

          gritRustArgs = {
            src = gritRustSource;
            cargoVendorDir = gritCargoVendor;

            pname = "attune-radii-grit";
            version = "0.0.0";

            strictDeps = true;
            doCheck = false;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.openssl
            ];

            OPENSSL_NO_VENDOR = "1";
          };

          gritCargoArtifacts = craneLib.buildDepsOnly gritRustArgs;

          gritNative = craneLib.buildPackage (
            gritRustArgs
            // {
              cargoArtifacts = gritCargoArtifacts;
              cargoExtraArgs = "--locked";
            }
          );

          gritFmt = craneLib.cargoFmt {
            src = gritRustSource;
          };

          gritClippy = craneLib.cargoClippy (
            gritRustArgs
            // {
              cargoArtifacts = gritCargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          gritPython =
            pkgs.runCommand "attune-grit-native"
              {
                passthru = {
                  dependencies = { };
                  optional-dependencies = { };
                };
              }
              ''
                site="$out/${python.sitePackages}"

                mkdir -p "$site"

                module="$(
                  find ${gritNative}                     -type f                     \( -name 'lib_attune_grit*.so' -o -name '_attune_grit*.so' \)                     -print                     -quit
                )"

                if [ -z "$module" ]; then
                  echo "Crane build produced no _attune_grit shared object" >&2
                  find ${gritNative} -maxdepth 4 -type f -print >&2
                  exit 1
                fi

                cp "$module" "$site/_attune_grit.so"
                cp ${./src/_attune_grit.pyi} "$site/_attune_grit.pyi"
              '';

          runtimePythonSet = pythonSet.overrideScope (
            _final: prev: {
              "attune-nix-abi" = nixAbi;
              "attune-grit-native" = gritPython;

              "rote" = prev."rote".overrideAttrs (old: {
                postInstall = (old.postInstall or "") + ''
                  substituteInPlace "$out/${python.sitePackages}/rote/session.py" \
                    --replace-fail \
                    '    # File appends always count — they persist state observable to the user.' \
                    '    if event in ("exec", "compile"):
                        caller = sys._getframe(1)
                        if caller is not None and _is_library_filename(caller.f_code.co_filename):
                            return
                    # File appends always count — they persist state observable to the user.'
                '';
              });
              "pydantic-ai-slim" = prev."pydantic-ai-slim".overrideAttrs (old: {
                postInstall = (old.postInstall or "") + ''
                  substituteInPlace "$out/${python.sitePackages}/pydantic_ai/embeddings/openai.py" \
                    --replace-fail \
                    '        embeddings = [item.embedding for item in response.data]' \
                    '        embeddings = [item.embedding for item in sorted(response.data, key=lambda item: item.index)]'
                '';
              });

            }
          );

          runtimeDependencies = workspace.deps.all // {
            "attune-nix-abi" = [ ];
            "attune-grit-native" = [ ];
          };

          venv = runtimePythonSet.mkVirtualEnv "attune-radii-env" runtimeDependencies;

          profiler = pkgs.writeShellApplication {
            name = "profile";

            runtimeInputs = [
              venv
              pkgs.coreutils
              pkgs.py-spy
            ];

            text = ''
                            usage() {
                              cat <<'EOF'
              profile — Attune Python flame profiler

              usage:
                profile cpu     [--name NAME] -- TARGET [ARGS...]
                profile memory  [--name NAME] -- TARGET [ARGS...]
                profile all     [--name NAME] -- TARGET [ARGS...]

              TARGET uses normal Python invocation syntax:

                profile cpu --name pace -- script.py
                profile cpu --name test -- -m pytest -q tests/test_transfer.py
                profile cpu --name tiny -- -c 'print(sum(range(1000000)))'

              modes:
                cpu
                  Sampling CPU flame graph with py-spy.

                memory
                  Allocation flame graph with Memray.

                all
                  Run both profilers sequentially.
                  The target executes twice.

              outputs:
                .attune/profiles/NAME/cpu.svg
                .attune/profiles/NAME/memory.bin
                .attune/profiles/NAME/memory.html
              EOF
                            }

                            if [ "$#" -eq 0 ]; then
                              usage
                              exit 0
                            fi

                            case "$1" in
                              -h|--help)
                                usage
                                exit 0
                                ;;
                            esac

                            # Match pytest's:
                            #
                            #   pythonpath = ["src"]
                            #
                            # without globally contaminating the development shell.
                            if [ -d "$PWD/src" ]; then
                              export PYTHONPATH="$PWD:$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
                            fi

                            mode="$1"
                            shift

                            name="$(date +%Y%m%d-%H%M%S)"

                            if [ "''${1:-}" = "--name" ]; then
                              if [ "$#" -lt 2 ]; then
                                echo "profile: --name requires a value" >&2
                                exit 2
                              fi

                              name="$2"
                              shift 2
                            fi

                            if [ "''${1:-}" = "--" ]; then
                              shift
                            fi

                            if [ "$#" -eq 0 ]; then
                              echo "profile: missing Python target" >&2
                              exit 2
                            fi

                            out="$PWD/.attune/profiles/$name"

                            mkdir -p "$out"

                            target=("$@")

                            run_cpu() {
                              status="$out/cpu.status"

                              rm -f \
                                "$out/cpu.svg" \
                                "$status"

                              echo
                              echo "=== CPU FLAME GRAPH ==="
                              echo "backend=py-spy"
                              echo "output=$out/cpu.svg"

                              # py-spy itself may return success even when the program
                              # being profiled raises. Run Python through a tiny shell
                              # trampoline so the child's real status is persisted.
                              ${pkgs.py-spy}/bin/py-spy record \
                                --rate 100 \
                                --subprocesses \
                                --format flamegraph \
                                -o "$out/cpu.svg" \
                                -- \
                                ${pkgs.bash}/bin/bash \
                                -c "
                                  status_file=\"\$1\"
                                  shift

                                  set +e

                                  \"\$@\"

                                  code=\"\$?\"

                                  printf '%s\n' \"\$code\" > \"\$status_file\"

                                  exit \"\$code\"
                                " \
                                profile-child \
                                "$status" \
                                ${venv}/bin/python \
                                "''${target[@]}"

                              if [ ! -f "$status" ]; then
                                echo "profile: CPU target status was not captured" >&2
                                exit 1
                              fi

                              code="$(cat "$status")"

                              if [ "$code" -ne 0 ]; then
                                echo "profile: CPU target exited with $code" >&2
                                exit "$code"
                              fi

                              rm "$status"
                            }

                            run_memory() {
                              echo
                              echo "=== MEMORY FLAME GRAPH ==="
                              echo "backend=memray"
                              echo "capture=$out/memory.bin"
                              echo "output=$out/memory.html"

                              rm -f \
                                "$out/memory.bin" \
                                "$out/memory.html"

                              ${venv}/bin/python -m memray run \
                                --force \
                                --output "$out/memory.bin" \
                                "''${target[@]}"

                              ${venv}/bin/python -m memray flamegraph \
                                --force \
                                --no-web \
                                --output "$out/memory.html" \
                                "$out/memory.bin"
                            }

                            case "$mode" in
                              cpu)
                                run_cpu
                                ;;

                              memory)
                                run_memory
                                ;;

                              all)
                                echo "profile: target executes twice"
                                run_cpu
                                run_memory
                                ;;

                              *)
                                echo "profile: unknown mode '$mode'" >&2
                                echo >&2
                                usage >&2
                                exit 2
                                ;;
                            esac

                            echo
                            echo "=== PROFILE COMPLETE ==="
                            echo "directory=$out"
            '';
          };

          runner = pkgs.writeShellApplication {
            name = "attune-radii";

            runtimeInputs = [
              venv
            ];

            text = ''
              export ROTE_MIN_DURATION_S=0.1

              if [ -f "$PWD/.env" ]; then
                set -a
                . "$PWD/.env"
                set +a
              fi

              pytest "$@"
            '';
          };
        in
        {
          inherit
            pkgs
            python
            profiler
            gritCargoArtifacts
            gritClippy
            gritFmt
            gritNative
            gritPython
            runner
            nixAbi
            venv
            ;
        };
    in
    {
      packages = forAllSystems (system: {
        grit-clippy = (environment system).gritClippy;
        grit-deps = (environment system).gritCargoArtifacts;
        grit-fmt = (environment system).gritFmt;
        grit-native = (environment system).gritPython;
        grit-rust = (environment system).gritNative;
        nix-abi = (environment system).nixAbi;
      });

      formatter = forAllSystems (system: (environment system).pkgs.nixfmt);

      devShells = forAllSystems (
        system:
        let
          env = environment system;

        in
        {
          default = env.pkgs.mkShell {
            packages = [
              env.venv
              env.profiler
              env.pkgs.cargo
              env.pkgs.clippy
              env.pkgs.rustc
              env.pkgs.rustfmt
              env.pkgs.jujutsu
              env.pkgs.nixfmt
              env.pkgs.uv
            ];

            env = {
              ROTE_MIN_DURATION_S = "0.1";
              UV_NO_SYNC = "1";
              UV_PYTHON = env.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              export TMPDIR=/tmp
              if [ -f "$PWD/.env" ]; then
                set -a
                . "$PWD/.env"
                set +a
              fi
              ln -sfnT ${env.venv} .venv
              export PYTHONPATH="$PWD/src"
            '';
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          env = environment system;
        in
        {
          default = {
            type = "app";
            program = "${env.runner}/bin/attune-radii";
          };
        }
      );
    };
}
