---
marp: true
theme: gaia
class: lead
backgroundColor: #fff
backgroundImage: url('https://marp.app/assets/hero-background.svg')
---

# Daily ECB FX Converter
## Pure Nix & Reproducible Data Processing

Zisen Liu

---

# Structure

1. `default.nix`: Serves as the library.
2. `flake.nix`: The flake metadata. Serves as a wrapper for the library.
3. `xml/`: The XML parser written in pure Nix.

---

# Purity vs. External Data

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

- **Nix**: Nix itself is challenging to learn, and it's not always easy to find the right tools.
- **XML Parsing**: Nix is not meant for complex text processing. Writing `parse-xml.nix` with `nix-parsec` was the most time-consuming part.
- **Purity Constraints**: Cannot just "download and read"; must use strict hash pinning.

---

# Recommendations

- **Only for Building**: Nix is not a general-purpose programming language. It's best used for building software.
- **Purity**: The way Nix ensures purity is unique and may be inspiring for other languages.
- **Use Flakes**: It simplifies dependency management significantly.
- **Combine with Other Languages or Tools**: Implement the complexity (e.g. XML parsing) with other general-purpose languages, and use Nix only for the reproducibility.
