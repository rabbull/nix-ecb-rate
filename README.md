# Daily ECB FX Converter

A reproducible CLI tool for currency conversion (e.g., CHF <-> EUR) using the daily reference rates from the European Central Bank (ECB).

**Key Feature:** This project is built **entirely in pure Nix**. It fetches the XML data using a Fixed-Output Derivation (pinned hash) and parses the XML structure inside the Nix evaluator (using `nix-parsec`) without any external build-time tools like Python or `jq`.

## Installation

### Method 1: Install data and CLI to your profile
This exposes the `ecb-rate` command globally.

```bash
nix profile install .#cli
```

### Method 2: Enter a development shell
This gives you a shell with `ecb-rate` available without installing it permanently.

```bash
nix develop
# Then run:
ecb-rate convert CHF EUR 100
```

### Method 3: One-off execution
Run without installing:

```bash
nix run .#cli -- convert USD EUR 100
```

## Usage

The primary tool is `ecb-rate`.

### Convert Currencies
Convert an amount from one currency to another.

```bash
# Convert 100 USD to CHF
ecb-rate convert USD CHF 100
# => 89.45

# Convert 100 EUR to CNY (EUR is the base currency)
ecb-rate convert EUR CNY 100
# => 785.42
```

### Check a Rate
Get the exchange rate for a specific currency against EUR.

```bash
ecb-rate rate USD
# => 1.05
```

### List Available Currencies
Show all currencies supported by the current dataset.

```bash
ecb-rate currencies
```

### Check Dataset Date
See the date of the ECB data being used.

```bash
ecb-rate date
# => 2025-12-09
```

## detailed Technical Overview

Everything in this project is deterministic.

1.  **Fixed-Output Derivation (FOD)**: We use `pkgs.fetchurl` to download the `eurofxref-daily.xml` from the ECB. By providing a sha256 hash, Nix guarantees the input is identical every time.
2.  **Pure XML Parsing**: Instead of using `jq` or `xml2json` during a build phase, we parse the XML string *during Nix evaluation* using a parser combinator library (`xml/parse-xml.nix`). This ensures the "build" is essentially just text processing in memory.
3.  **Hermeticism**: The final executable is a simple shell script that evaluates the Nix expression to retrieve the rates from verified files. It requires no network at runtime.

## Project Structure

- `flake.nix`: Entry point. Defines packages, apps, and devShells.
- `default.nix`: Core logic. Fetches data, parses XML, and creates the library functions.
- `xml/`: Contains the pure Nix XML parser.
- `presentation/`: Slides and script for the project presentation.

## Updating the Dataset

To update to today's rates:

1.  Download the latest XML:
    ```bash
    wget https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml
    ```
2.  Calculate the new hash:
    ```bash
    nix hash file eurofxref-daily.xml
    ```
3.  Update `default.nix`:
    - Set `expectedDate` to today's date (YYYY-MM-DD).
    - Update `ratesHash` with the new hash.
