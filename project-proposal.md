# Project: Daily CHF/EUR Converter

This project provides a reproducible Nix flake that packages two tiny command-line tools, written and built with Nix, to convert between CHF and EUR using the European Central Bank’s daily reference rates. The flake fetches the daily OpenAPI rates payload, pins it for reproducibility, and sets the software version to that dataset’s date.

## Motivation
- Nix is ideal for packaging small data-driven tools with strong reproducibility guarantees. Fetching external data (ECB rates) can be made deterministic by pinning hashes, while scripts are generated purely from Nix expressions.
- The project demonstrates practical Nix concepts: flakes, fixed-output fetchers, hermetic builds, content-addressed data, and exposing multiple executables via `apps`/`packages`.
- Using the dataset date as the package version showcases how Nix can encode provenance into build outputs.

## Key Language Features
- Nix conventions:
  - Flake: `inputs`/`outputs` structure, per-`system` outputs, and `packages` and `apps` exposure.
  - Derivations: use `stdenv` to build standard package derivations.
  - Executables: generate executables via `pkgs.writeShellApplication` (installed to `$out/bin`) and expose them under both `packages` and `apps`.
- Fixed-output fetch: use `fetchurl` with a pre-calculated hash to fetch ECB data deterministically for a given `date`; the hash pins the exact content.
- Pure Nix evaluation: expose Nix functions that read the store file `rate.txt` via `builtins.readFile` and perform conversions; these can be executed with `nix eval` by passing the store path as an argument.
- Versioning: set `version = <YYYY-MM-DD>` based on the ECB dataset date to make outputs traceable.

## Architecture / Design
- Data fetcher (rates): a derivation named `rates-${date}` that uses `pkgs.fetchurl` to download the ECB OpenAPI payload for a specific `date` (single-day series). Prefer the `format=CSV` response to simplify parsing with POSIX sh and Nix. The SRI hash must match that date’s content. Optionally transform the payload into `rate.txt` containing only the numeric CHF↔EUR rate for simpler runtime use.
- Converter scripts:
  - `chf-to-eur`: reads an amount in CHF, looks up the CHF/EUR rate from the packaged data, and prints the EUR value.
  - `eur-to-chf`: performs the inverse conversion from EUR to CHF.
  Implement them with `pkgs.writeShellApplication` and no external runtime dependencies (pure POSIX shell). They default to the packaged data path and can be overridden via `--rates /path/file` or an environment variable. If using JSON, parse via shell string operations; if using `rate.txt`, simply read the number.
- Nix lib (eval path): provide `lib.rateFromFile` to parse `$storePath/rate.txt` with `builtins.readFile`, plus `lib.chfToEur`/`lib.eurToChf` that take `{ amount, ratePath }` and return a string or number. These can be invoked via `nix eval`.
- Flake outputs:
  - `packages.${system}.rates`: the fetched ECB OpenAPI data derivation for the chosen date.
  - `packages.${system}.chf-to-eur` and `packages.${system}.eur-to-chf`: executables.
  - `packages.${system}.default`: a meta-package that depends on both tools and the data.
  - `apps.${system}.chf-to-eur` / `apps.${system}.eur-to-chf`: convenient `nix run` entry points.
- Versioning: all relevant derivations set `version = date`; the `default` package name includes the date for clarity (e.g., `2025-01-15`).

## Scope
- Must-haves
  - A flake with pinned `nixpkgs` input and per-system outputs.
  - A fixed-output fetch derivation that retrieves the ECB daily rates payload for a given `date` and pins its hash.
  - Two executables (built via Nix) that perform CHF <-> EUR conversion using the fetched rates.
  - Nix `lib` functions that read the store `rate.txt` (pure Nix) to perform conversions via `nix eval`.
  - Version string equals the ECB dataset date used.
  - Minimal README with build/run instructions and how to update `date` and `sha256`.
- Nice-to-haves
  - CLI flags: `--rates PATH` (override rate source), `--digits N` (rounding), `--date YYYY-MM-DD`, etc.
  - Support for additional currencies with the same mechanism.
- Out of scope
  - Live network access during build or run that bypasses Nix-store pinning.
  - GUI or web frontend; the deliverable is CLI only.
  - Including external tools at runtime (e.g., `jq`, `awk`, `sed`, `Python`).

## Potential Challenges and Mitigations
- Changing daily data and hashes: each date has different content and thus a new hash. Mitigation: parameterize the `date`, document `nix-prefetch-url`/`nix hash` usage, and require updating the `sha256` alongside the `date`.
- ECB feed format and availability: The ECB feed is XML, which is parseable in pure Nix but is cumbersome. I plan to use a JSON or CSV alternative so I don't spend too much time writing a parser.
- Pure evaluation vs. data access: When evaluating Nix expressions, file I/O is generally discouraged because it introduces impurity. However, in this project I will access files with a pinned hash to bound the impurity.

## Deliverables
- `flake.nix` and `flake.lock`
- `packages`: `rates`, `chf-to-eur`, `eur-to-chf`, and `default`
- `apps`: `chf-to-eur`, `eur-to-chf`
- `lib` attrs: `rateFromFile`, `chfToEur`, `eurToChf`
- `README.md` with instructions to execute the programs, design notes, and, if the assigned target cannot be achieved, any workarounds used.
