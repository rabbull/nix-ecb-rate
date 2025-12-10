# Daily ECB FX Converter

Plain Nix expressions pinned to the ECB daily XML feed, parsed entirely in Nix using `xml/parse-xml.nix` (nix-parsec). No non-nix code is used for parsing or conversion.

## Files
- `default.nix`: main entry with data fetch, XML parsing, and `lib` helpers.
- `xml/`: XML parser (pinned nix-parsec).

## Usage
```
# Convert using the library directly

nix eval --file default.nix --apply 'env: env.lib.convert { amount = 100; from = "USD"; to = "CHF"; }'
# => converts 100 USD to CHF using the pinned ECB rates

# Read packaged rates directly
nix build -f default.nix rates
nix eval --file default.nix --apply 'env: env.lib.rateTableFromFile ./result/share/rates.json'
```

## Flake usage (optional)
- First time only: `nix flake update` to create `flake.lock`.
- Build the packaged rates: `nix build .#rates` (or `.#default`) and read `result/share/rates.json` (map of all currencies).
- Install the data package: `nix profile install .#rates` (links `share/rates.json`, `share/date.txt`).
- CLI (packaged): `nix run .#ecb-rate -- convert USD CHF 100`; list currencies with `nix run .#ecb-rate -- currencies`. Installable with `nix profile install .#cli`.
- Smoke test the package: `nix flake check`.
- Dev shell with formatter: `nix develop` (includes `nixpkgs-fmt`).

## How it works
- Data: `fetchurl` of `eurofxref-daily.xml` with pinned SRI hash.
- Parsing: `xml/parse-xml.nix` (nix-parsec) extracts `Cube@time` and all `Cube@currency/rate` entries.
- Packaging: `linkFarm` exposes `share/eurofxref.xml`, `share/rates.json` (all currencies), `share/date.txt`.
- Conversion: pure Nix math; helpers convert between any two currencies listed in the XML feed (EUR is the base currency but is not currently supported as an explicit input/output). CLI is a thin shell wrapper over packaged rates.

## Updating the dataset
1) Download latest ECB XML: `https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml`.
2) Hash it:
```
nix hash file eurofxref-daily.xml
```
3) Edit `default.nix`: update `expectedDate` and `ratesHash` (and `ratesUrl` if needed).
