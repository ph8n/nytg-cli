{
  description = "NYT games terminal client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f (import nixpkgs { inherit system; }));

      zigVersion = "0.16.0";

      zigTarballs = {
        aarch64-darwin = {
          url = "https://ziglang.org/download/${zigVersion}/zig-aarch64-macos-${zigVersion}.tar.xz";
          sha256 = "b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489";
        };
        x86_64-darwin = {
          url = "https://ziglang.org/download/${zigVersion}/zig-x86_64-macos-${zigVersion}.tar.xz";
          sha256 = "0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7";
        };
        aarch64-linux = {
          url = "https://ziglang.org/download/${zigVersion}/zig-aarch64-linux-${zigVersion}.tar.xz";
          sha256 = "ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17";
        };
        x86_64-linux = {
          url = "https://ziglang.org/download/${zigVersion}/zig-x86_64-linux-${zigVersion}.tar.xz";
          sha256 = "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00";
        };
      };

      zigBin = pkgs:
        let
          tarball = zigTarballs.${pkgs.stdenv.hostPlatform.system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "zig-bin";
          version = zigVersion;

          src = pkgs.fetchurl tarball;

          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -R . "$out/"
            mkdir -p "$out/bin"
            ln -s "$out/zig" "$out/bin/zig"
            runHook postInstall
          '';
        };
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (zigBin pkgs)
          ];
        };
      });
    };
}
