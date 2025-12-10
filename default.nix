let
  mkEnv =
    { pkgs ? import <nixpkgs> {}
    , src ? builtins.path { path = ./.; name = "ecb-fx-src"; }
    , expectedDate ? "2025-12-09"
    , ratesUrl ? "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"
    , ratesHash ? "sha256-HaGm7DIZU+xfSMlZoTZCk0wY9ZCkJF9+t22LGB57zF0="
    }:
    let
      xmlDir = src + "/xml";
      xmlParser = import (xmlDir + "/parse-xml.nix") { inherit pkgs; };

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

      toNumber = x: if builtins.isString x then builtins.fromJSON x else x;
      toInt = x: if builtins.isString x then builtins.fromJSON x else x;
      pow10 = n: if n <= 0 then 1.0 else 10.0 * pow10 (n - 1);
      roundTo = digits: value:
        let factor = pow10 digits;
        in (builtins.floor (value * factor + 0.5)) / factor;
      maybeRound = digits: value: if digits == null then value else roundTo digits value;

      currencyNodes = builtins.filter
        (n: (n.attributes or {}) ? currency && (n.attributes or {}) ? rate)
        (getTags datedCube.children);

      _currencyNodesCheck = if currencyNodes == [] then throw "No currency rates found in ECB XML" else null;

      ratesAttr = builtins.listToAttrs (builtins.map
        (n: { name = n.attributes.currency; value = toNumber n.attributes.rate; })
        currencyNodes);

      rateFor = currency:
        if currency == "EUR" then 1.0
        else if builtins.hasAttr currency ratesAttr
        then builtins.getAttr currency ratesAttr
        else throw "Currency ${currency} not found in ECB data";


      ratesJsonFile = pkgs.writeText "rates-${dateFromXml}.json" (builtins.toJSON ratesAttr);
      dateFile = pkgs.writeText "date-${dateFromXml}.txt" dateFromXml;

      ratesPkg = pkgs.linkFarm "ecb-rates-${dateFromXml}" [
        { name = "share/eurofxref.xml"; path = source; }

        { name = "share/rates.json"; path = ratesJsonFile; }
        { name = "share/date.txt"; path = dateFile; }
      ];

      trim = s: pkgs.lib.strings.trim s;

      rateTableFromFile = path: builtins.fromJSON (trim (builtins.readFile path));


      defaultRatesJsonPath = "${ratesPkg}/share/rates.json";

      lookupRate = { currency, rates ? null, ratePath ? defaultRatesJsonPath }:
        if currency == "EUR" then 1.0 else
        let table = if rates != null then rates else rateTableFromFile ratePath;
        in if builtins.hasAttr currency table
        then builtins.getAttr currency table
        else throw "Currency ${currency} not found in ECB rates table";

      convert = { amount, from, to, rates ? null, ratePath ? defaultRatesJsonPath, digits ? null }:
        let
          digitsVal = if digits == null then null else toInt digits;
          table = if rates != null then rates else rateTableFromFile ratePath;
          fromRate = lookupRate { currency = from; rates = table; ratePath = ratePath; };
          toRate = lookupRate { currency = to; rates = table; ratePath = ratePath; };
          amt = toNumber amount;
        in maybeRound digitsVal ((amt / fromRate) * toRate);

      formatValue = { value, digits ? null }:
        let digitsVal = if digits == null then null else toInt digits;
        in builtins.toString (maybeRound digitsVal value);

      lib = {
        inherit rateTableFromFile rateFor convert pow10 roundTo maybeRound formatValue;
        rates = {
          package = ratesPkg;

          ratesPath = "${ratesPkg}/share/rates.json";
          datePath = "${ratesPkg}/share/date.txt";
          xmlPath = source;
          version = dateFromXml;
          url = ratesUrl;
          hash = ratesHash;
          date = dateFromXml;
          currencies = builtins.attrNames ratesAttr;
          table = ratesAttr;
        };
        cli = {
          convert = args: formatValue {
            value = convert args;
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
