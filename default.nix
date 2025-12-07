let
  mkEnv =
    { pkgs ? import <nixpkgs> {}
    , expectedDate ? "2025-12-05"
    , ratesUrl ? "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"
    , ratesHash ? "sha256-qDIKv7rg+naM0pfZghEsE56e+g0CjNNt51M5ObhGAb4="
    }:
    let
      xmlParser = import ./xml/parse-xml.nix { inherit pkgs; };

      # Fetch and parse ECB XML once (pure Nix)
      source = pkgs.fetchurl { url = ratesUrl; hash = ratesHash; };
      xmlContent = builtins.readFile source;

      getTags = nodes: builtins.filter (n: (n ? type) && n.type == "tag") nodes;

      findOne = { name, nodes, err }:
        let hits = builtins.filter (n: (n.name or "") == name) nodes;
        in if hits == [] then throw err else builtins.head hits;

      findOneBy = { nodes, predicate, err }:
        let hits = builtins.filter predicate nodes;
        in if hits == [] then throw err else builtins.head hits;

      parsed = xmlParser.parseXml xmlContent;
      envelope = findOne { name = "gesmes:Envelope"; nodes = getTags parsed.value.children; err = "Envelope tag not found"; };
      cubeRoot = findOne { name = "Cube"; nodes = getTags envelope.children; err = "Cube root not found"; };
      datedCube = findOneBy {
        nodes = getTags cubeRoot.children;
        predicate = n: (n.attributes or {}) ? time;
        err = "Dated Cube not found";
      };

      dateFromXml = datedCube.attributes.time;
      _ = if expectedDate != null && expectedDate != "" && expectedDate != dateFromXml
        then throw "Date mismatch: expected ${expectedDate}, got ${dateFromXml}"
        else null;

      chfNode = findOneBy {
        nodes = getTags datedCube.children;
        predicate = n: (n.attributes or {}) ? currency && n.attributes.currency == "CHF";
        err = "CHF rate missing in XML";
      };

      chfRateStr = chfNode.attributes.rate;

      rateFile = pkgs.writeText "rate-${dateFromXml}.txt" chfRateStr;
      dateFile = pkgs.writeText "date-${dateFromXml}.txt" dateFromXml;

      ratesPkg = pkgs.linkFarm "ecb-rates-${dateFromXml}" [
        { name = "share/eurofxref.xml"; path = source; }
        { name = "share/rate.txt"; path = rateFile; }
        { name = "share/date.txt"; path = dateFile; }
      ];

      toNumber = x: if builtins.isString x then builtins.fromJSON x else x;
      toInt = x: if builtins.isString x then builtins.fromJSON x else x;
      pow10 = n: if n <= 0 then 1.0 else 10.0 * pow10 (n - 1);
      roundTo = digits: value:
        let factor = pow10 digits;
        in (builtins.floor (value * factor + 0.5)) / factor;
      maybeRound = digits: value: if digits == null then value else roundTo digits value;

      trim = s: pkgs.lib.strings.trim s;
      rateFromFile = path: builtins.fromJSON (trim (builtins.readFile path));

      defaultRatePath = "${ratesPkg}/share/rate.txt";

      chfToEur = { amount, ratePath ? defaultRatePath, rate ? null, digits ? null }:
        let
          digitsVal = if digits == null then null else toInt digits;
          r = if rate != null then toNumber rate else rateFromFile ratePath;
          amt = toNumber amount;
        in maybeRound digitsVal (amt / r);

      eurToChf = { amount, ratePath ? defaultRatePath, rate ? null, digits ? null }:
        let
          digitsVal = if digits == null then null else toInt digits;
          r = if rate != null then toNumber rate else rateFromFile ratePath;
          amt = toNumber amount;
        in maybeRound digitsVal (amt * r);

      formatValue = { value, digits ? null }:
        let digitsVal = if digits == null then null else toInt digits;
        in builtins.toString (maybeRound digitsVal value);

      lib = {
        inherit rateFromFile chfToEur eurToChf pow10 roundTo maybeRound formatValue;
        rates = {
          package = ratesPkg;
          ratePath = "${ratesPkg}/share/rate.txt";
          datePath = "${ratesPkg}/share/date.txt";
          xmlPath = source;
          version = dateFromXml;
          url = ratesUrl;
          hash = ratesHash;
          date = dateFromXml;
        };
        cli = {
          chfToEur = args: formatValue {
            value = chfToEur args;
            digits = if args ? digits then args.digits else 4;
          };
          eurToChf = args: formatValue {
            value = eurToChf args;
            digits = if args ? digits then args.digits else 4;
          };
        };
        meta = {
          date = dateFromXml;
          expectedDate = expectedDate;
          sourceUrl = ratesUrl;
          hash = ratesHash;
        };
      };
    in {
      inherit ratesPkg;
      rates = ratesPkg;
      inherit lib;
    };

  defaultEnv = mkEnv {};
in
defaultEnv // { inherit mkEnv; }
