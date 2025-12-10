# Presentation Script: Daily ECB FX Converter (Nix)

## 1. Introduction (0:00 - 0:30)

"Hi everyone. My project is the **Daily ECB FX Converter**.

The goal was simple: build a CLI tool to convert currencies (CHF to EUR) using the latest daily rates from the European Central Bank.

But there’s a twist: **I did it entirely in pure Nix.**

Most people would write a Python script that fetches data at runtime. I wanted to see if I could make the *data itself* a build-time dependency, resulting in a tool that has **zero runtime dependencies**—no Python, no `jq`, just standard POSIX shell."

## 2. Architecture & The "Magic" (0:30 - 1:15)

"So, how does it work? There are two main parts:

First, getting the data.
Nix is 'hermetic'—it can't just access the internet.
I used a **Fixed-Output Derivation (FOD)**. This allows us to download the ECB's XML feed securely by promising Nix the file will have a specific hash. Once downloaded, Nix treats this external file as a pure, immutable input.

Second, using the data.
Here is the real trick. I didn't want to parse XML with an external tool during the build. I wanted to parse it **inside the Nix evaluator**.
I used a library called `nix-parsec` to write an XML parser in pure Nix configuration language.
This means the 'build' process is just text processing in memory. The final output is a shell script with the exchange rate hardcoded into it."

## 3. Challenges (1:15 - 2:00)

"This brings me to the **Challenges**, which were significant.

**Challenge 1: Pure XML Parsing.**
Nix is not designed for complex text processing. Writing an XML parser using parser combinators in a configuration language was... intense. It was the hardest part of the project, but it proved that Nix is a Turing-complete language capable of complex logic.

**Challenge 2: The 'Purity' Constraint.**
You can't just 'read a file'. You have to verify it. Every time the ECB data updates, the hash changes. This forces a workflow where 'Data is Code'—you must update the hash in your flake to 'release' a new version of the data."

## 4. Nix Characteristics & Conclusion (2:00 - 2:45)

"Finally, how does this reflect the **Characteristics of Nix**?

1.  **Reproducibility**: If you run this flake in 5 years, it will produce the *exact* same binary with the *exact* same exchange rate from today. It won't break because the API changed.
2.  **Hermeticism**: The build process touches nothing outside the sandbox.
3.  **Data as Dependencies**: We treat data feeds exactly like software libraries—versioned, hashed, and locked.

**Conclusion:**
This project is minimal, but it demonstrates the extreme power of Nix's model. It turns a dynamic runtime problem (fetching API data) into a static build-time guarantee.

Thank you."

---

## Speaker Notes

- **Emphasis**: Stress "Pure Nix" vs "Python script".
- **Visuals**: When talking about XML parsing, show the `parse-xml.nix` slide.
- **Q&A Prep**: Be ready to answer "Why not just use `jq`?" (Answer: To demonstrate purity and avoid extra build-time tools).
