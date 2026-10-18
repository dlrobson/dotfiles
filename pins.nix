# This repo's npins pins, fetched with the *Nixpkgs* fetchers rather than the
# builtins ones.
#
# `builtins.fetchTarball` fetches during evaluation and hands back a bare store
# path: no derivation, so nothing can substitute it and nothing can rebuild it.
# On a machine that runs `nix.gc` — the CI runner of any repo that pins this one
# does, weekly — such a pin is collected between jobs, and the next evaluation
# either re-downloads it mid-flight or aborts with `path '…' is not valid`.
#
# Asking a pin for its `pkgs` variant produces a fixed-output derivation for the
# *same* store path (npins documents this as "Using the Nixpkgs fetchers"; the
# path is identical because its hash is the same tarball hash). A missing pin is
# then substituted from a binary cache, or rebuilt from the pinned URL and
# verified against that hash, and a failure is an ordinary build error.
#
# Consume pins through this file:
#
#   sources = import ./pins.nix;
#   (config.unstablePkgs.callPackage "${sources.paseo}/nix/package.nix" { })
#
# It deliberately does not take a `pkgs` argument: a fixed-output derivation's
# output path depends only on the pinned hash, not on which `pkgs` instantiates
# it, and taking the module system's `pkgs` invites infinite recursion where
# pins are used in `imports = [ … ]`. The bootstrap nixpkgs from this same pin
# set is enough.
#
# `check` fails the build if any other file imports `npins/` directly.
let
  raw = import ./npins;

  # Pins fetched with the builtins flavour, deliberately: `nixpkgs` provides the
  # fetchers used below, and `nixpkgs-unstable` is imported as a second `pkgs`
  # (see `modules/common/unstable-pkgs.nix`).
  bootstrap = [
    "nixpkgs"
    "nixpkgs-unstable"
  ];

  pkgs = import raw.nixpkgs { };

  # Everything else: a fixed-output derivation per pin. Still lazy per pin,
  # because `//` and `mapAttrs` evaluate values on demand.
  pinned = builtins.mapAttrs (name: _: raw.${name} { inherit pkgs; }) (
    builtins.removeAttrs raw bootstrap
  );
in
raw // pinned
