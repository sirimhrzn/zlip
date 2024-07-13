{
  description = "Nepali Patro - calendar";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-24.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          pkg-config
          wayland-protocols
          wayland-scanner
          wayland
          wlroots
        ];
        shellHook = ''
                        export LD_LIBRARY_PATH=${pkgs.wayland}/lib:$LD_LIBRARY_PATH
          	      export WAYLAND_XML=${pkgs.wayland}/share/wayland/wayland.xml
        '';
      };
    };
}
