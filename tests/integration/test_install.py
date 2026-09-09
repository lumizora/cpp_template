"""Install, relocate and run the release without build-directory search paths."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

build = pathlib.Path(sys.argv[1]).resolve()
version, cmake, cpack = sys.argv[2:5]


def verify(relocated):
    env = os.environ.copy()
    for key in ("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH"):
        env.pop(key, None)
    env["PATH"] = str(pathlib.Path(env.get("SystemRoot", "C:/Windows")) / "System32") if os.name == "nt" else "/usr/bin:/bin"
    exe = relocated / "bin" / ("cpp_template.exe" if os.name == "nt" else "cpp_template")
    result = subprocess.run([str(exe), "--json"], cwd=relocated.parent, env=env, check=True,
                            text=True, encoding="utf-8", capture_output=True, timeout=15)
    assert json.loads(result.stdout)["version"] == version
    metadata = relocated / "share/cpp_template"
    assert json.loads((metadata / "build-info.json").read_text())["version"] == version
    dependencies = json.loads((metadata / "dependencies.json").read_text())
    assert {item["name"] for item in dependencies} >= {"fmt", "spdlog", "cli11", "stb", "nlohmann_json"}
    assert not ({item["name"] for item in dependencies} & {"googletest", "benchmark"})
    for item in dependencies:
        assert len(item["URL_HASH"]) == 71 and item["URL_HASH"].startswith("SHA256=")
        assert list((relocated / "share/licenses/cpp_template" / item["name"]).glob("LICENSE*"))
    # Check loader metadata too: relocation alone can still find the old build.
    for artifact in [exe, *relocated.rglob("*.dylib"), *relocated.rglob("*.so*")]:
        if sys.platform == "darwin":
            command = ["/usr/bin/otool", "-l", str(artifact)]
        elif sys.platform.startswith("linux"):
            command = ["readelf", "-d", str(artifact)]
        else:
            continue
        loader = subprocess.check_output(command, text=True, timeout=15)
        assert str(build) not in loader and ".deps-cache" not in loader, loader


with tempfile.TemporaryDirectory(prefix="cpp-install-") as directory:
    root = pathlib.Path(directory)
    prefix = root / "install"
    subprocess.run([cmake, "--install", str(build), "--config", "Release",
                    "--prefix", str(prefix), "--component", "Runtime"], check=True, timeout=30)
    relocated = root / "relocated"
    prefix.rename(relocated)
    verify(relocated)
    packages = root / "packages"
    subprocess.run([cpack, "--config", str(build / "CPackConfig.cmake"), "-C", "Release",
                    "-B", str(packages)], check=True, timeout=60)
    archives = [*packages.glob("*.tar.gz"), *packages.glob("*.zip")]
    assert len(archives) == 2, archives
    for index, archive in enumerate(archives):
        extracted = root / f"extracted-{index}"
        extracted.mkdir()
        subprocess.run([cmake, "-E", "tar", "xf", str(archive)], cwd=extracted, check=True, timeout=30)
        verify(extracted)
print("Relocated install, TGZ/ZIP archives and provenance passed")
