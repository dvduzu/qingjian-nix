{
  rustPlatform,
  openssl,
  pkg-config,
  pkgs,
  qingjianSrc,
}:
let
  src = pkgs.runCommand "qingjian-linux-src" { } ''
    cp -r ${qingjianSrc}/. $out/
    chmod -R u+w $out
    rm -rf $out/apps/linux/fcitx5/build $out/target $out/result
  '';
in
rustPlatform.buildRustPackage {
  pname = "qingjian-server";
  version = (builtins.fromTOML (builtins.readFile "${qingjianSrc}/apps/linux/server/Cargo.toml")).package.version;
  inherit src;

  env = {
    cargoBuildFlags = "-p qingjian-linux-server";
    cargoTestFlags = "-p qingjian-linux-server";
  };

  cargoHash = "sha256-szjKr19B+S7ba4TBYGl1mC4S5ffBCoLNgTWp3L8bnJI=";

  installPhase = ''
    mkdir -p "$out/bin"
    cp target/x86_64-unknown-linux-gnu/release/qingjian-linux-server "$out/bin/qingjian-server"
  '';

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  meta = {
    description = "青简输入法 Linux server（Rust）：Unix socket IPC + 本地组句/选词/整句模型";
    mainProgram = "qingjian-server";
  };
}
