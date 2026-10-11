"""Use the same fresh-extraction verifier, adding the v15 assets and regressions."""
import importlib.util
from pathlib import Path

source = Path(__file__).with_name("verify-package-v14.py")
spec = importlib.util.spec_from_file_location("package_checks", source)
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
checks.VERSION = "v15"
checks.ARCHIVE = checks.ARTIFACTS / "吞食戰國-M1-v0.15-Windows.zip"
checks.VERSIONS.append("v15")
checks.TESTS = ["battle", "wire", "audio_v15", "victory_v15", "victory_integration_v15", "render_v14", "local_coop_startup"]

if __name__ == "__main__":
    checks.main()
