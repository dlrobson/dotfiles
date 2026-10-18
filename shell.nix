let
  sources = import ./pins.nix;
  pkgs = import sources.nixpkgs { };
  unstablePkgs = import sources.nixpkgs-unstable { };
  hm = import sources.home-manager { inherit pkgs; };

  check = pkgs.writeShellApplication {
    name = "check";
    text = ''
      find . -name "*.nix" -type f -print0 | xargs -0 nixfmt --check
      statix check --ignore "npins/default.nix"
      find . -name "*.nix" -type f -not -path "./npins/*" -print0 | xargs -0 deadnix --fail

      # Pins must be consumed through pins.nix (see that file): it asks npins for
      # the Nixpkgs fetchers, so each pin is a fixed-output derivation, and a
      # store path a consumer's weekly GC has deleted gets substituted or
      # rebuilt instead of aborting evaluation with `path '…' is not valid`.
      bypass=$(
        find . -name "*.nix" -type f -not -path "./npins/*" -print0 |
          xargs -0 grep -lE 'import [^ ;]*/npins\b' |
          grep -vE '^\./pins\.nix$' || true
      )
      if [ -n "$bypass" ]; then
        echo "ERROR: these files import npins/ directly; consume pins via pins.nix (see that file):" >&2
        echo "$bypass" >&2
        exit 1
      fi
    '';
  };

  run-tests = pkgs.writeShellApplication {
    name = "run-tests";
    runtimeInputs = [ hm.home-manager ];
    text = ''
      for profile in minimal desktop coverage; do
        echo "Testing home-manager profile: $profile"
        USER=$(id -un) home-manager build -f profiles/$profile.nix -I nixpkgs=${sources.nixpkgs}
      done
    '';
  };

  build = pkgs.writeShellApplication {
    name = "build";
    text = ''echo "No build step for dotfiles"'';
  };

  format = pkgs.writeShellApplication {
    name = "format";
    text = ''
      find . -name "*.nix" -type f -print0 | xargs -0 nixfmt
      statix fix --ignore "npins/default.nix"
      find . -name "*.nix" -type f -not -path "./npins/*" -print0 | xargs -0 deadnix --edit
    '';
  };

  update-pins = pkgs.writeShellApplication {
    name = "update-pins";
    runtimeInputs = [ unstablePkgs.npins ];
    text = "npins upgrade && npins update";
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.nixfmt
    pkgs.statix
    pkgs.deadnix
    hm.home-manager
    unstablePkgs.npins
    check
    format
    run-tests
    build
    update-pins
  ];
}
