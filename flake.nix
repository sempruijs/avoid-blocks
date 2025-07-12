{
  description = "Rust with WASM target";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    wasm-server-runner.url = "github:sempruijs/wasm-server-runner";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, wasm-server-runner }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rust = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-unknown-unknown" ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rust
            pkgs.wasm-pack  # optional, for wasm-pack support
            wasm-server-runner.packages.${system}.default
          ];
        };
      }
    );
}
