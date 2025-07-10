{
  description = "A Bevy hello world application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rustfmt" "clippy" ];
        };

        # Platform-specific libraries
        linuxDeps = with pkgs; [
          alsa-lib
          udev
          vulkan-loader
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
          libxkbcommon
          wayland
        ];

        darwinDeps = with pkgs; [
          darwin.apple_sdk.frameworks.Cocoa
          darwin.apple_sdk.frameworks.CoreGraphics
          darwin.apple_sdk.frameworks.CoreServices
          darwin.apple_sdk.frameworks.Foundation
          darwin.apple_sdk.frameworks.Metal
          darwin.apple_sdk.frameworks.QuartzCore
        ];

        buildInputs = if pkgs.stdenv.isDarwin then darwinDeps else linuxDeps;
        
        nativeBuildInputs = with pkgs; [
          pkg-config
          rustToolchain
        ];

        # Runtime libraries for Linux
        runtimeLibs = if pkgs.stdenv.isLinux then pkgs.lib.makeLibraryPath [
          pkgs.vulkan-loader
          pkgs.alsa-lib
          pkgs.udev
          pkgs.xorg.libX11
          pkgs.xorg.libXcursor
          pkgs.xorg.libXi
          pkgs.xorg.libXrandr
          pkgs.libxkbcommon
          pkgs.wayland
        ] else "";

      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "bevy-hello-world";
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          inherit nativeBuildInputs buildInputs;
          
          # Set environment variables for runtime
          postInstall = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            wrapProgram $out/bin/bevy-hello-world \
              --set LD_LIBRARY_PATH "${runtimeLibs}"
          '';
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          nativeBuildInputs = nativeBuildInputs ++ [ pkgs.rust-analyzer pkgs.cargo-watch ];
          
          shellHook = ''
            export RUST_LOG=debug
            export CARGO_TARGET_DIR="$PWD/target"
            ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              export LD_LIBRARY_PATH="${runtimeLibs}:$LD_LIBRARY_PATH"
            ''}
            echo "🦀 Bevy development environment loaded!"
            echo "Run 'cargo run' to start the application"
            echo "Run 'cargo watch -c -x \"run --features bevy/dynamic_linking\"' for auto-rebuild"
          '';
        };
      });
}
