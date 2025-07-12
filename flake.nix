{
  description = "Rust with WASM target";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    naersk.url = "github:nix-community/naersk";
    wasm-server-runner.url = "github:sempruijs/wasm-server-runner";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, naersk, wasm-server-runner }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rust = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-unknown-unknown" ];
        };
        
        naersk' = naersk.lib.${system}.override {
          cargo = rust;
          rustc = rust;
        };
      in {
        packages.default = naersk'.buildPackage {
          src = ./.;
          
          nativeBuildInputs = with pkgs; [ wasm-bindgen-cli binaryen ];
          
          CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
          
          postBuild = ''
            # Generate bindings using wasm-bindgen
            wasm-bindgen \
              --out-dir pkg \
              --out-name bevy-hello-world \
              --target web \
              target/wasm32-unknown-unknown/release/bevy_hello_world.wasm
            
            # Optimize with wasm-opt
            wasm-opt -Oz -o pkg/bevy-hello-world_bg.wasm pkg/bevy-hello-world_bg.wasm
          '';
          
          installPhase = ''
            mkdir -p $out
            
            # Copy generated WASM files
            cp pkg/bevy-hello-world.js $out/
            cp pkg/bevy-hello-world_bg.wasm $out/
            
            # Create index.html
            cat > $out/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Bevy Hello World</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #222;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            font-family: Arial, sans-serif;
        }
        canvas {
            border: 1px solid #444;
            max-width: 100%;
            max-height: 100%;
        }
        .container {
            text-align: center;
        }
        h1 {
            color: white;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Bevy Hello World</h1>
        <canvas id="bevy-canvas"></canvas>
    </div>
    
    <script type="module">
        import init from './bevy-hello-world.js';
        
        async function run() {
            await init();
        }
        
        run();
    </script>
</body>
</html>
EOF
          '';
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rust
            pkgs.wasm-pack  # optional, for wasm-pack support
            wasm-server-runner.packages.${system}.default
            pkgs.trunk
          ];
        };
      }
    );
}
