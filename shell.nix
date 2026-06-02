let
  pkgs = import (import ./npins).nixpkgs { };

  check = pkgs.writeShellApplication {
    name = "check";
    text = ''
      find . -name "*.nix" -type f -print0 | xargs -0 nixfmt --check
      statix check --ignore "npins/default.nix"
    '';
  };

  fix = pkgs.writeShellApplication {
    name = "fix";
    text = ''
      find . -name "*.nix" -type f -print0 | xargs -0 nixfmt
      statix fix --ignore "npins/default.nix"
    '';
  };

  run-tests = pkgs.writeShellApplication {
    name = "run-tests";
    runtimeInputs = [ pkgs.home-manager ];
    text = ''
      for profile in minimal desktop ouster; do
        echo "Testing home-manager profile: $profile"
        ROBSON_HOME_PROFILE="$profile" USER=$(id -un) home-manager build -f home.nix
      done
    '';
  };

  build = pkgs.writeShellApplication {
    name = "build";
    text = ''echo "No build step for dotfiles"'';
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.nixfmt
    pkgs.statix
    pkgs.home-manager
    check
    fix
    run-tests
    build
  ];
}
