---
marp: true
theme: gaia
class: lead
backgroundColor: #fff
backgroundImage: url('https://marp.app/assets/hero-background.svg')
---

# Daily ECB FX Converter
## Pure Nix & Reproducible Data Processing

karl

---

# Why Nix?

- **Hermetic Builds**: No access to `/bin`, network, or user environment during build.
- **Strict Reproducibility**: Input hash pinning ensures identical results every time.
- **Pure Evaluation**: XML parsing happens at *eval time*, implying zero runtime overhead.
- **Zero Runtime Deps**: The final output depends only on standard POSIX shell.

---

# Architecture

1.  **Input**: Daily XML feed from European Central Bank (ECB).
2.  **Fetch**: Securely download with `fetchurl` (pinned SRI hash).
3.  **Parse**: Extract rates using **Pure Nix** (no external parsers).
4.  **Expose**: Provide results via `lib` (Nix API) and `apps` (CLI).

---

# Purity & External Data

**The Challenge**: Nix evaluation is "pure"—it cannot access the internet or mutable files.

```nix
source = pkgs.fetchurl {
  url = "https://www.ecb.europa.eu/.../eurofxref-daily.xml";
  hash = "sha256-qDIKv7rg+naM0pfZghEsE56e+g0CjNNt51M5ObhGAb4=";
};
# Now we can read it purely!
xmlContent = builtins.readFile source;
```

---

# Purity & External Data

**The Solution**: Fixed-Output Derivations (FOD).

1.  **Promise**: We tell Nix exactly what the file's hash **will** be.
2.  **Verify**: Nix downloads the file. If the hash matches, it's saved to the Nix Store.
3.  **Use**: Since the hash is known, the file is effectively "constant" and "pure."

---

# Deep Dive: Pure XML Parsing

We parse XML **inside** the Nix evaluator using `nix-parsec`.

- **Benefit**: No *Import From Derivation* (IFD).
- **Result**: The "build" is just text processing in memory.

```nix
# xml/parse-xml.nix usage in default.nix
let
  xmlParser = import (xmlDir + "/parse-xml.nix") { inherit pkgs; };
  parsed = xmlParser.parseXml xmlContent;
  # ... recursive tag finding ...
in
  # Returns a usable Nix attribute set of rates
  { USD = 1.05; CHF = 0.94; ... }
```

---

# Usage: Dual Interface

**1. CLI (Ad-hoc or Installed)**

```bash
$ nix run . -- convert USD CHF 100
89.45
```

**2. Nix Library (Composable)**

```nix
# In your flake.nix or default.nix
let rates = import ./default.nix; in
rates.lib.convert { amount = 50; from = "EUR"; to = "GBP"; }
# => 42.85 (evaluated purely)
```

---

# Challenges

- **XML Parsing**: Nix is not meant for complex text processing. Writing `parse-xml.nix` with `nix-parsec` was the hardest part.
- **Purity Constraints**: Cannot just "download and read"—must use strict hash pinning.

---

# Reflections on Nix

- **Steep Learning Curve**: Functional paradigm + lazy evaluation + dynamic typing = confusing errors.
- **Powerful Abstraction**: Once it works, it works *forever* and *everywhere*.
- **Data as Code**: Treating data sources as versioned inputs is a paradigm shift.

---

# Recommendations

- **Use Flakes**: It simplifies dependency management significantly.
- **Master `nix repl`**: Essential for debugging expressions.
- **Avoid Pure Parsing**: For real work, use `runCommand` with tools like `jq` or `xml2json`. We did this strictly for the demo.

---

# Summary

- **Hermetic**: Zero access to the outside world during build.
- **Composable**: Use as a CLI tool or a Nix library function.
- **Educational**: Demonstrates Flakes, Fixed-Output Derivations, and pure parsing.

**Thank You!**
