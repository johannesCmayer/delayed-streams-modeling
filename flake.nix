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
<<<<<<< HEAD
            # python3
            stdenv.cc.cc.lib
            portaudio
            moshi
            uv
            rustToolchain
            cmake
=======
            uv
            libxcrypt
            portaudio
            rustToolchain
>>>>>>> origin/main
            openssl
            pkg-config
            cargo-deny
            cargo-edit
            cargo-watch
            rust-analyzer
            cudaPackages.cudatoolkit 
            opusfile
            libz
<<<<<<< HEAD
            glibc
=======
>>>>>>> origin/main
          ];

          env = {
            # Required by rust-analyzer
            RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
          };

          shellHook = ''
<<<<<<< HEAD
            echo "Setup python with uv"
            ${pkgs.uv}/bin/uv python install 3.12
            ${pkgs.uv}/bin/uv sync
            python_path=$(${pkgs.uv}/bin/uv run -- python -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')

            export LD_LIBRARY_PATH=:/run/opengl-driver/lib:"$python_path":${pkgs.lib.makeLibraryPath packages}:"$LD_LIBRARY_PATH"
            export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib/
            export CUDA_ROOT=${pkgs.cudaPackages.cudatoolkit}

            # For moshi see: https://github.com/kyutai-labs/unmute/blob/main/dockerless/start_tts.sh
            export CXXFLAGS="-include cstdint"
=======
            export LD_LIBRARY_PATH=/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath packages}:"$LD_LIBRARY_PATH"
            export CUDA_ROOT=${pkgs.cudaPackages.cudatoolkit}
>>>>>>> origin/main
          '';
        };
      });
    };
}
