{
  pkgs,
  lib,
  ...
}:

let
  sources = import ../../npins;
  pyprojectNix = import sources.pyproject-nix { inherit lib; };
  uv2nixPkg = import sources.uv2nix {
    inherit lib;
    pyproject-nix = pyprojectNix;
  };
  buildSystemPkgs = import sources.build-system-pkgs {
    inherit lib;
    pyproject-nix = pyprojectNix;
    uv2nix = uv2nixPkg;
  };
  workspace = uv2nixPkg.lib.workspace.loadWorkspace { workspaceRoot = ./headroom; };
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  pythonSet =
    (pkgs.callPackage pyprojectNix.build.packages { python = pkgs.python3; }).overrideScope
      (
        lib.composeManyExtensions [
          buildSystemPkgs.overlays.wheel
          overlay
        ]
      );
in
{
  home.packages = [ (pythonSet.mkVirtualEnv "headroom-env" workspace.deps.default) ];
}
