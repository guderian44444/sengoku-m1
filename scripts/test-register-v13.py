"""Check that selecting accepted source cells does not change their geometry."""
import copy
import importlib.util
import json
from pathlib import Path
import sys

sys.argv = [__file__, "v13"]
spec = importlib.util.spec_from_file_location("registration", Path(__file__).with_name("register-v12.py"))
registration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registration)
meta = json.loads((registration.ROOT / "oichi-dash-clips.json").read_text(encoding="utf-8"))["oichi-dash_heavy"]
expected = registration.register("oichi-dash_heavy", meta)
selected = copy.deepcopy(meta)
first = selected["parts"].pop(0)
selected["parts"][:0] = [{**first, "indices": [0, 1, 2]}, {**first, "indices": [3, 4, 5]}]
assert registration.register("oichi-dash_heavy", selected) == expected
selected["parts"][0]["indices"] = [0, 0, 2]
try:
    registration.register("oichi-dash_heavy", selected)
except AssertionError as error:
    assert "invalid selected drawings" in str(error)
else:
    raise AssertionError("Duplicated drawings must not be accepted as new frames")
print("PASS: source-cell selection preserves geometry, scaling and hand anchors; duplicate indices rejected")
