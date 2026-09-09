#!/usr/bin/env python3
"""Validate every manifest branch using the same CMake parser as the build."""
import pathlib
import subprocess
import sys


def main() -> int:
    script = pathlib.Path(__file__).with_suffix(".cmake")
    try:
        return subprocess.run(["cmake", "-P", str(script)], check=False).returncode
    except FileNotFoundError:
        print("[check_deps] CMake >= 3.25 is required", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
