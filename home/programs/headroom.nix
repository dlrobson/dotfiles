{ pkgs, ... }:

let
  ast-grep-cli = pkgs.python3Packages.buildPythonPackage {
    pname = "ast-grep-cli";
    version = "0.42.3";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/8d/a5/a3e40d49b32a6ec545efbe2be1d0ebabe5fa3abe2dcc8588577fd2fb2741/ast_grep_cli-0.42.3-py3-none-manylinux_2_28_x86_64.whl";
      hash = "sha256-CiP/W8vqwWWkSxuzqcFCcM3+pJFv5iNktMPPimSRCxw=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    doCheck = false;
  };

  headroom-ai = pkgs.python3Packages.buildPythonPackage {
    pname = "headroom-ai";
    version = "0.25.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/aa/cb/84969342e34fda736e8a8aa0bf614b46ffc2a4129011b7c66142faee26d0/headroom_ai-0.25.0-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-ICrjH5N+iZMzlEGzY6Lkfrv0NQLiKkR7LGQ9OQhW9Nw=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    pythonRelaxDeps = true;
    propagatedBuildInputs = with pkgs.python3Packages; [
      tiktoken
      pydantic
      litellm
      click
      rich
      opentelemetry-api
      ast-grep-cli
    ];
    doCheck = false;
  };
in
{
  home.packages = [ (pkgs.python3.withPackages (_ps: [ headroom-ai ])) ];
}
