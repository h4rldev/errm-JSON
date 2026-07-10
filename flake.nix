{
  description = "Errm.. JSON, a JSON parser, and writer for erlang.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    beamPackages = pkgs.beamPackages;

    errm-prod = beamPackages.buildRebar3 {
      name = "errm-JSON";
      version = "0.1.0-prod";

      src = ./.;

      beamDeps = [];
      env = {
        REBAR_PROFILE = "prod";
      };
    };

    errm-debug = beamPackages.buildRebar3 {
      name = "errm-JSON";
      version = "0.1.0-debug";

      src = ./.;

      beamDeps = [];

      env = {
        REBAR_PROFILE = "debug";
      };
    };
  in {
    packages.${system} = {
      errm-json-prod = errm-prod;
      default = errm-prod;
      errm-json-debug = errm-debug;
    };

    devShells.${system}.default = pkgs.mkShell {
      name = "errm-JSON";

      buildInputs = with pkgs; [
        beamPackages.erlang
        beamPackages.rebar3
        fixjson
      ];

      packages = with pkgs; [
        erlang-language-platform
      ];
    };
  };
}
