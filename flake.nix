{
  description = "Sliding puzzle solver's flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    zig-version = "0.14.0";
    zig-filename = "zig-linux-x86_64-${zig-version}";
    zig-custom = pkgs.stdenv.mkDerivation {
      pname = "zig-custom";
      version = zig-version;

      src = pkgs.fetchurl {
        url = "https://ziglang.org/download/${zig-version}/${zig-filename}.tar.xz";
        sha256 = "Rz7CaAYTPPTRkYyvGkEPhAOhPZeXJqkEW0IbaFAxqYI=";
      };

      buildPhase = ''
        tar xf $src
      '';

      installPhase = ''
        mkdir -p $out/bin/
        cp ${zig-filename}/zig $out/bin/
        cp -r ${zig-filename}/lib $out
      '';
    };
  in {
    devShell.${system} = pkgs.mkShell {
      buildInputs = [
        zig-custom

        # Debugger and benchmark tool
        pkgs.lldb
        pkgs.poop

        # Local web server
        pkgs.static-web-server

        # Wasm devtools
        pkgs.binaryen
        pkgs.wabt

        # Type-checking tool
        pkgs.typescript
      ];
    };
  };
}
