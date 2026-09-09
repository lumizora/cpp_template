"""Exercise the executable contract, including Unicode paths and bad images."""
import json
import pathlib
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())
version = sys.argv[2]


def invoke(*args):
    return subprocess.run([exe, *args], text=True, encoding="utf-8", capture_output=True, timeout=15)


result = invoke("--version")
assert result.returncode == 0 and version in result.stdout, result
result = invoke("--name", "模板", "--repeat", "2")
assert result.returncode == 0 and result.stdout == "Hello, 模板!\n" * 2, result
result = invoke("--json", "--verbose", "--name", 'a"b', "--repeat", "2")
assert result.returncode == 0, result.stderr
data = json.loads(result.stdout)
assert data["greeting"] == 'Hello, a"b!' and data["repeat"] == 2, data
assert data["version"] == version, data
for args in (("--repeat", "0"), ("--repeat", "-1"), ("--repeat", "oops"), ("--unknown",)):
    result = invoke(*args)
    assert result.returncode != 0 and result.stderr, result

with tempfile.TemporaryDirectory(prefix="cpp-cli-") as directory:
    root = pathlib.Path(directory)
    valid = root / "图片 with spaces.ppm"
    valid.write_bytes(b"P6\n2 1\n255\n" + bytes([255, 0, 0, 0, 255, 0]))
    result = invoke("--json", "--image", str(valid))
    assert result.returncode == 0, result.stderr
    image = json.loads(result.stdout)["image"]
    assert (image["width"], image["height"], image["channels"]) == (2, 1, 3), image
    invalid = root / "broken.png"
    invalid.write_bytes(b"\x89PNG\r\n\x1a\n")
    for path in (invalid, root / "missing.png", root, ""):
        result = invoke("--json", "--image", str(path))
        assert result.returncode != 0 and result.stderr and not result.stdout, result
print("CLI contract passed")
