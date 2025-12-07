# Daily CHF/EUR Converter

Plain Nix expressions pinned to the ECB daily XML feed (2025-12-05), parsed entirely in Nix using `xml/parse-xml.nix` (nix-parsec). No non-nix code is used for parsing or conversion.

## Files
- `default.nix`: main entry with data fetch, XML parsing, and `lib` helpers.
- `run-chf-to-eur.nix`, `run-eur-to-chf.nix`: `nix eval --file` entrypoints for CLI-style use.
- `xml/`: XML parser (pinned nix-parsec).

### Usage
```
# Convert using the library directly

nix eval --file default.nix --apply 'env: env.lib.chfToEur { amount = 100; }'
# => 106.781

nix eval --file default.nix --apply 'env: env.lib.eurToChf { amount = 100; }'
# => 93.65

# Read the packaged rate directly
nix build -f default.nix rates
nix eval --file default.nix --apply 'env: env.lib.rateFromFile ./result/share/rate.txt'
```

## How it works
- Data: `fetchurl` of `eurofxref-daily.xml` with pinned SRI hash.
- Parsing: `xml/parse-xml.nix` (nix-parsec) extracts `Cube@time` and CHF `Cube@rate`.
- Packaging: `linkFarm` exposes `share/eurofxref.xml`, `share/rate.txt`, `share/date.txt`.
- Conversion: pure Nix math; CLI wrappers are just `nix eval --file …`.

## Updating the dataset
1) Download latest ECB XML: `https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml`.
2) Hash it:
```
nix hash file eurofxref-daily.xml
```
3) Edit `default.nix`: update `expectedDate` and `ratesHash` (and `ratesUrl` if needed).

Everything stays pure Nix—no flakes, no shell, no extra languages.
