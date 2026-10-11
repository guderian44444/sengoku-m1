"""Check every packaged byte, then require the real Tadakatsu artwork in a fresh extraction."""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("package_checks", Path(__file__).with_name("verify-package-v14.py"))
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
checks.VERSION = "v17"
checks.ARCHIVE = checks.ARTIFACTS / "吞食戰國-M1-v0.17-Windows.zip"
checks.VERSIONS += ["v15", "v16", "v17"]
checks.TESTS = ["battle", "wire", "tadakatsu_combat_v17", "tadakatsu_render_v17", "tadakatsu_atlas_v17", "local_coop_startup"]

if __name__ == "__main__":
    checks.main()
