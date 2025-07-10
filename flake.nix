{
  description = "A Bevy hello world application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rustfmt" "clippy" ];
          targets = [ "wasm32-unknown-unknown" ];
        };

        naersk-lib = naersk.lib."${system}".override {
          cargo = rustToolchain;
          rustc = rustToolchain;
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

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let baseName = baseNameOf path;
            in baseName != "target" && baseName != "result" && baseName != ".git";
        };

      in
      {
        packages.default = naersk-lib.buildPackage {
          inherit src;
          inherit nativeBuildInputs buildInputs;
          
          # Set environment variables for runtime
          postInstall = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            wrapProgram $out/bin/bevy-hello-world \
              --set LD_LIBRARY_PATH "${runtimeLibs}"
          '';
        };

        packages.webapp = naersk-lib.buildPackage {
          inherit src;
          root = ./.;
          
          nativeBuildInputs = with pkgs; [
            pkg-config
            rustToolchain
            wasm-bindgen-cli
            binaryen
          ];
          
          # Override the target for WebAssembly
          CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
          
          # Custom build phase for WebAssembly
          preBuild = ''
            export CARGO_TARGET_DIR=$PWD/target
          '';
          
          postBuild = ''
            # Use wasm-bindgen to generate JS bindings
            wasm-bindgen --out-dir $out/webapp --target web --no-typescript \
              target/wasm32-unknown-unknown/release/bevy-hello-world.wasm
            
            # Optimize the wasm file
            wasm-opt -Oz -o $out/webapp/bevy-hello-world_bg.wasm $out/webapp/bevy-hello-world_bg.wasm
            
            # Create a simple HTML file to serve the webapp
            mkdir -p $out/webapp
            cat > $out/webapp/index.html << EOF
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Bevy Hello World</title>
                <style>
                    body {
                        margin: 0;
                        padding: 0;
                        background-color: #000;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        min-height: 100vh;
                        font-family: Arial, sans-serif;
                    }
                    canvas {
                        max-width: 100%;
                        max-height: 100vh;
                    }
                    #loading {
                        color: white;
                        text-align: center;
                    }
                </style>
            </head>
            <body>
                <div id="loading">Loading...</div>
                <script type="module">
                    import init from './bevy-hello-world.js';
                    
                    async function run() {
                        await init();
                        document.getElementById('loading').remove();
                    }
                    
                    run();
                </script>
            </body>
            </html>
            EOF
          '';
          
          # Skip the standard check phase as it's not applicable for wasm
          doCheck = false;
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          nativeBuildInputs = nativeBuildInputs ++ [ 
            pkgs.rust-analyzer 
            pkgs.cargo-watch 
            pkgs.wasm-bindgen-cli 
            pkgs.binaryen
            pkgs.simple-http-server
          ];
          
          shellHook = ''
            export RUST_LOG=debug
            export CARGO_TARGET_DIR="$PWD/target"
            ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              export LD_LIBRARY_PATH="${runtimeLibs}:$LD_LIBRARY_PATH"
            ''}
            echo "🦀 Bevy development environment loaded!"
            echo "Run 'cargo run' to start the native application"
            echo "Run 'cargo watch -c -x \"run --features bevy/dynamic_linking\"' for auto-rebuild"
            echo "Run 'nix build .#webapp' to build the webapp"
            echo "Run 'simple-http-server ./result/webapp' to serve the webapp"
          '';
        };
      });
}
