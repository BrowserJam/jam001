let
  pkgs = import <nixpkgs> {};
  imgui = import ./imgui.nix;
in pkgs.mkShell {
  buildInputs = [
    pkgs.python310
    pkgs.python310.pkgs.pip
    pkgs.python310.pkgs.setuptools
    pkgs.python310.pkgs.wheel
    pkgs.python310.pkgs.pyopengl
    pkgs.python310.pkgs.pysdl2
    pkgs.python310.pkgs.loguru
    imgui
  ];
  shellHook = ''
    # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
    # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
    export PIP_PREFIX=$(pwd)/_build/pip_packages
    alias pip="PIP_PREFIX='$(pwd)/_build/pip_packages' TMPDIR='$HOME' \pip"
    export PYTHONPATH="$PIP_PREFIX/${pkgs.python310.sitePackages}:$PYTHONPATH"
    echo PYTHONPATH="$PIP_PREFIX/${pkgs.python310.sitePackages}:$PYTHONPATH"
    export PATH="$PIP_PREFIX/bin:$PATH"
    unset SOURCE_DATE_EPOCH
  '';
}