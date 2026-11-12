{ lib, runCommand, fetchurl, gzip, qingjianSrc }:
let
  readLock = name: "${qingjianSrc}/tools/release/${name}";

  parse = path:
    let
      lines = lib.splitString "\n" (builtins.readFile path);
      parseLine = line:
        let
          m = builtins.match "([^#][^=]*)=[ ]*([0-9a-f]{64})[ ]+([^ ]+)" line;
        in
        if m == null then
          null
        else
          {
            tag = lib.removeSuffix " " (builtins.elemAt m 0);
            sha = builtins.elemAt m 1;
            installed = builtins.elemAt m 2;
          };
    in
    lib.filter (x: x != null) (map parseLine lines);

  toSri = sha: builtins.convertHash {
    hash = "sha256:${sha}";
    toHashFormat = "sri";
  };

  dictId = tag:
    let
      m = builtins.match "(.*)-v[0-9]+\\.[0-9]+\\.[0-9]+" tag;
    in
    if m == null then tag else builtins.head m;

  dicts = parse (readLock "dicts.lock");
  models = parse (readLock "models.lock");

  fetchDict = entry: fetchurl {
    url = "https://github.com/qingjian-team/qingjian-dicts/releases/download/${entry.tag}/${dictId entry.tag}.qjz";
    hash = toSri entry.sha;
    name = "${entry.tag}.qjz";
  };

  fetchModel = entry: fetchurl {
    url = "https://github.com/qingjian-team/qingjian-models/releases/download/${entry.tag}/${entry.tag}.tar.gz.part1";
    hash = toSri entry.sha;
    name = "${entry.tag}.tar.gz";
  };

  installDict = entry: ''
    mkdir -p "$out/generated/$(dirname '${entry.installed}')"
    gzip -dc ${fetchDict entry} > "$out/generated/${entry.installed}"
  '';

  installModel = entry: ''
    mkdir -p extract
    tar -xzf ${fetchModel entry} -C extract
    mkdir -p "$(dirname "$out/${lib.removePrefix "data/" entry.installed}")"
    find extract -type f -name '${baseNameOf entry.installed}' \
      -exec cp {} "$out/${lib.removePrefix "data/" entry.installed}" \;
    rm -rf extract
  '';
in
runCommand "qingjian-data" { nativeBuildInputs = [ gzip ]; } ''
  mkdir -p $out
  ${lib.concatMapStrings installDict dicts}
  ${lib.concatMapStrings installModel models}
''
