{
  description = "青简 Qingjian：Linux fcitx5 输入法（Rust server + fcitx5 插件）";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qingjian = {
      url = "github:qingjian-team/qingjian";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      ... 
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };

      rustToolchain = pkgs.rust-bin.stable."1.96.0".default;
      rustPlatform = pkgs.makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
      };

      qingjianServer = pkgs.callPackage ./packages/server.nix {
        inherit rustPlatform;
        qingjianSrc = inputs.qingjian;
      };

      qingjianFcitx5 = pkgs.callPackage ./packages/fcitx5.nix {
        qingjianSrc = inputs.qingjian;
      };

      qingjianData = pkgs.callPackage ./packages/data.nix {
        qingjianSrc = inputs.qingjian;
      };
    in
    {
      packages.${system} = {
        inherit qingjianServer qingjianFcitx5 qingjianData;
        default = qingjianFcitx5;
      };

      nixosModules.default = import ./modules/nixos.nix {
        inherit qingjianFcitx5 qingjianServer;
        dataPackage = qingjianData;
      };

      devShells.${system}.default = pkgs.mkShell {
        name = "qingjian-linux-dev";
        packages = with pkgs; [
          rustup
          gcc
          cmake
          pkg-config
        ];
        buildInputs = with pkgs; [
          fcitx5
          openssl
        ];
        shellHook = ''
          rustup toolchain install 1.96.0 --profile minimal 2>/dev/null || true
          export PATH="$HOME/.cargo/bin:$PATH"
        '';
      };
    };
}
