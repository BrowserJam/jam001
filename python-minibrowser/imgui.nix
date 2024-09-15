with import <nixpkgs> {};

( let
    p = python310.pkgs.buildPythonPackage rec {
      pname = "imgui";
      version = "2.0.0";

      src = python310.pkgs.fetchPypi {
        inherit pname version;
        sha256 = "L7247tO429fqmK+eTBxlgrC8TalColjeFjM9jGU9Z+E=";
      };

      doCheck = false;

				  checkInputs = [
				    pytest
				  ];

				  checkPhase = ''
				    py.test tests/unit tests/integration
				  '';

      meta = {
        homepage = "https://github.com/swistakm/pyimgui";
        description = "Cython-based Python bindings for dear imgui";
      };
    };

  in python310.withPackages (ps: [p])
)