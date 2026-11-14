{ lib, runCommand, fetchurl, gzip, python3, qingjianSrc }:
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
    mkdir -p "$out/data/generated/$(dirname '${entry.installed}')"
    gzip -dc ${fetchDict entry} > "$out/data/generated/${entry.installed}"
  '';

  installModel = entry: ''
    mkdir -p extract
    tar -xzf ${fetchModel entry} -C extract
    mkdir -p "$(dirname "$out/data/${lib.removePrefix "data/" entry.installed}")"
    find extract -type f -name '${baseNameOf entry.installed}' \
      -exec cp {} "$out/data/${lib.removePrefix "data/" entry.installed}" \;
    rm -rf extract
  '';
in
runCommand "qingjian-data" { nativeBuildInputs = [ gzip python3 ]; } ''
  mkdir -p $out/data $out/assets/emoji
  ${lib.concatMapStrings installDict dicts}
  ${lib.concatMapStrings installModel models}
  python3 - ${./emoji-zh-extra.tsv} ${qingjianSrc}/assets/emoji/emoji-zh.tsv "$out/assets/emoji/emoji-zh.tsv" <<'PY'
import sys

extra_path, source_path, out_path = sys.argv[1:4]

extra = {}
order = []
with open(extra_path, encoding="utf-8") as file:
    for line in file:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        word, emojis = line.split("\t", 1)
        extra[word] = emojis
        order.append(word)

kept = []
with open(source_path, encoding="utf-8") as file:
    for line in file:
        if not line.strip() or line.startswith("#"):
            continue
        if line.split("\t", 1)[0] not in extra:
            kept.append(line.rstrip("\n"))

merged = kept + [f"{word}\t{extra[word]}" for word in order]
with open(out_path, "w", encoding="utf-8") as file:
    file.write("\n".join(merged) + "\n")
PY
  cp ${qingjianSrc}/assets/emoji/emoji-en.tsv $out/assets/emoji/emoji-en.tsv
  cp ${qingjianSrc}/assets/emoji/LICENSE-unicode.txt $out/assets/emoji/LICENSE-unicode.txt
''
