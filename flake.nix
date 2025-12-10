{
  description = "Daily CHF/EUR converter packaged as a flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      mkPerSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs { inherit system; };
            envSet = import ./default.nix;
            src = self;
            env = envSet.mkEnv { inherit pkgs src; };
            ratesPkg = env.ratesPkg;

            ratesJsonFile = "${ratesPkg}/share/rates.json";
            dateFile = "${ratesPkg}/share/date.txt";
            default_nix = "${src}/default.nix";
            ecbRateCli = pkgs.writeShellApplication {
              name = "ecb-rate";
              runtimeInputs = [ pkgs.nix ];
              text = ''
                              set -euo pipefail

                              nix_bin=${pkgs.nix}/bin/nix
                              default_nix=${default_nix}
                              nix_path="nixpkgs=${nixpkgs}"

                              eval_cli() {
                                local expr="$1"
                                NIX_PATH="$nix_path" "$nix_bin" eval --raw --file "$default_nix" --apply "$expr"
                                echo ""
                              }

                              usage() {
                                cat <<'EOF'
                Usage:
                  ecb-rate convert <from> <to> <amount> [digits]
                  ecb-rate rate <currency>
                  ecb-rate date
                  ecb-rate currencies
                EOF
                              }

                              cmd="''${1:-}"
                              case "$cmd" in
                                convert)
                                  from="''${2:-}"
                                  to="''${3:-}"
                                  amt="''${4:-}"
                                  digits="''${5:-4}"
                                  if [ -z "$from" ] || [ -z "$to" ] || [ -z "$amt" ]; then usage; exit 1; fi
                                  digitsArg=""
                                  if [ -n "$digits" ]; then digitsArg="; digits = ''${digits}"; fi
                                  expr="env: env.lib.cli.convert { amount = ''${amt}; from = \"''${from}\"; to = \"''${to}\"''${digitsArg}; }"
                                  eval_cli "$expr"
                                  ;;
                                rate)
                                  currency="''${2:-}"
                                  if [ -z "$currency" ]; then usage; exit 1; fi
                                  expr="env: builtins.toString (env.lib.rateFor \"''${currency}\")"
                                  eval_cli "$expr"
                                  ;;
                                date)
                                  eval_cli "env: env.lib.meta.date"
                                  ;;
                                currencies)
                                  eval_cli "env: builtins.concatStringsSep \"\\n\" env.lib.rates.currencies"
                                  ;;
                                *)
                                  usage
                                  exit 1
                                  ;;
                              esac
              '';
            };
          in
          f {
            inherit
              system
              pkgs
              env
              ratesPkg
              ratesJsonFile
              dateFile
              ;
            ecbRateCli = ecbRateCli;
          }
        );
    in
    {
      packages = mkPerSystem (
        { ratesPkg, ecbRateCli, ... }:
        {
          default = ratesPkg;
          rates = ratesPkg;
          cli = ecbRateCli;
        }
      );

      apps = mkPerSystem (
        { ecbRateCli, ... }:
        {
          default = {
            type = "app";
            program = "${ecbRateCli}/bin/ecb-rate";
          };
          ecb-rate = {
            type = "app";
            program = "${ecbRateCli}/bin/ecb-rate";
          };
        }
      );

      checks = mkPerSystem (
        { pkgs, ratesPkg, ... }:
        {
          rates-present = pkgs.runCommand "ecb-rates-smoke" { } ''

            test -s ${ratesPkg}/share/date.txt
            mkdir -p "$out"
          '';
        }
      );

      devShells = mkPerSystem (
        { pkgs, ecbRateCli, ... }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixpkgs-fmt
              ecbRateCli
            ];
          };
        }
      );

      formatter = mkPerSystem ({ pkgs, ... }: pkgs.nixpkgs-fmt);
    };
}
