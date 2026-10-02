{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  wheel,
  pybind11,
  pillow,
}:
buildPythonPackage rec {
  pname = "materialyoucolor";
  version = "3.0.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-MLjd4DTc4YCEWw6vUvcsWyLNW2C9ev+WgE/rrk4mYnY=";
  };
  build-system = [ setuptools wheel pybind11 ];
  dependencies = [ pillow ];
  # Hydra keeps its own quantizer; only the pure-Python DynamicScheme is needed.
  MYCP_PURE_PYTHON = "1";
  pythonImportsCheck = [
    "materialyoucolor.dynamiccolor.dynamic_scheme"
    "materialyoucolor.dynamiccolor.material_dynamic_colors"
  ];

  meta = {
    description = "Material Color Utilities with the 2025 color spec for Python";
    homepage = "https://github.com/T-Dynamos/materialyoucolor-python";
    license = lib.licenses.mit;
  };
}
