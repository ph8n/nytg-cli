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

      zigVersion = "0.15.2";

      zigTarballs = {
        aarch64-darwin = {
          url = "https://ziglang.org/download/${zigVersion}/zig-aarch64-macos-${zigVersion}.tar.xz";
          sha256 = "3cc2bab367e185cdfb27501c4b30b1b0653c28d9f73df8dc91488e66ece5fa6b";
        };
        x86_64-darwin = {
          url = "https://ziglang.org/download/${zigVersion}/zig-x86_64-macos-${zigVersion}.tar.xz";
          sha256 = "375b6909fc1495d16fc2c7db9538f707456bfc3373b14ee83fdd3e22b3d43f7f";
        };
        aarch64-linux = {
          url = "https://ziglang.org/download/${zigVersion}/zig-aarch64-linux-${zigVersion}.tar.xz";
          sha256 = "958ed7d1e00d0ea76590d27666efbf7a932281b3d7ba0c6b01b0ff26498f667f";
        };
        x86_64-linux = {
          url = "https://ziglang.org/download/${zigVersion}/zig-x86_64-linux-${zigVersion}.tar.xz";
          sha256 = "02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239";
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
