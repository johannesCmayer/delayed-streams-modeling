{
  description = "A Nix-flake-based Rust development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.cudaSupport = true;
          overlays = [
            inputs.self.overlays.default
          ];
        };
      });
    in
    {
      overlays.default = final: prev: {
        rustToolchain = with inputs.fenix.packages.${prev.stdenv.hostPlatform.system};
          combine (with stable; [
            clippy
            rustc
            cargo
            rustfmt
            rust-src
          ]);
      };

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell rec {
          packages = with pkgs; [
            uv
            libxcrypt
            portaudio
            rustToolchain
            openssl
            pkg-config
            cargo-deny
            cargo-edit
            cargo-watch
            rust-analyzer
            cudaPackages.cudatoolkit 
            opusfile
            libz
          ];

          env = {
            # Required by rust-analyzer
            RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
          };

          shellHook = ''
            export LD_LIBRARY_PATH=/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath packages}:"$LD_LIBRARY_PATH"
            export CUDA_ROOT=${pkgs.cudaPackages.cudatoolkit}
          '';
        };
      });
    };
}
