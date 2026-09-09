"""Dependency-engine regressions; standard library only, no network required."""
import hashlib
import pathlib
import subprocess
import tarfile
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ENGINE = (ROOT / "cmake/DependencyManager.cmake").as_posix()


def run(*args, cwd=None, ok=True):
    result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    if ok and result.returncode:
        raise AssertionError(result.stdout)
    return result


class DependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cpp-deps-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.source = self.root / "upstream"
        self.source.mkdir()
        (self.source / "CMakeLists.txt").write_text(
            'cmake_minimum_required(VERSION 3.25)\n'
            'project(probe LANGUAGES NONE)\n'
            'configure_file(mode.in mode.txt @ONLY)\n'
            'add_library(probe INTERFACE)\n', encoding="utf-8")
        (self.source / "mode.in").write_text("@MODE@\n", encoding="utf-8")
        self.archive = self.root / "probe.tar.gz"
        self.pack()

    def pack(self):
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.add(self.source, arcname="probe")
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def configure(self, build="build", *options, declaration=None, ok=True):
        if declaration is None:
            declaration = (f'add_dependency(probe URL "{self.archive.as_uri()}" '
                           f'URL_HASH SHA256={self.digest})')
        (self.root / "CMakeLists.txt").write_text(
            'cmake_minimum_required(VERSION 3.25)\n'
            'project(engine_test LANGUAGES NONE)\n'
            f'include("{ENGINE}")\n{declaration}\n'
            'if(TARGET probe)\n'
            '  get_target_property(dep_binary probe BINARY_DIR)\n'
            '  configure_file("${dep_binary}/mode.txt" observed.txt COPYONLY)\n'
            '  file(WRITE "${CMAKE_BINARY_DIR}/dependency-dir.txt" "${dep_binary}")\n'
            'endif()\n'
            'file(WRITE "${CMAKE_BINARY_DIR}/parent-mode.txt" "${MODE}")\n', encoding="utf-8")
        return run("cmake", "-S", str(self.root), "-B", str(self.root / build),
                   "-G", "Ninja", *options, ok=ok)

    def test_build_directories_are_isolated(self):
        self.configure("a", "-DMODE=one")
        self.configure("b", "-DMODE=two")
        dep_a = pathlib.Path((self.root / "a/dependency-dir.txt").read_text())
        dep_b = pathlib.Path((self.root / "b/dependency-dir.txt").read_text())
        self.assertNotEqual(dep_a, dep_b)
        self.assertEqual((dep_a / "mode.txt").read_text(), "one\n")

    def test_offline_reuses_matching_cache_in_fresh_build(self):
        self.configure("online")
        self.archive.unlink()
        self.configure("offline", "-DDEPS_OFFLINE=ON")

    def test_offline_rejects_changed_pin(self):
        self.configure()
        self.digest = "0" * 64
        result = self.configure("build", "-DDEPS_OFFLINE=ON", ok=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("offline", result.stdout.lower())

    def test_offline_switch_can_be_disabled(self):
        self.configure("build", "-DDEPS_OFFLINE=ON", ok=False)
        self.configure("build", "-DDEPS_OFFLINE=OFF")

    def test_automatic_override_is_not_sticky(self):
        override = self.root / ".deps-override/probe"
        override.mkdir(parents=True)
        (override / "CMakeLists.txt").write_text(
            'message(STATUS "USING_LOCAL_OVERRIDE")\n', encoding="utf-8")
        self.assertIn("USING_LOCAL_OVERRIDE", self.configure().stdout)
        self.assertNotIn("USING_LOCAL_OVERRIDE",
                         self.configure("build", "-DDEPS_ALLOW_OVERRIDE=OFF").stdout)

    def test_explicit_override_is_rejected_in_strict_mode(self):
        result = self.configure("build", "-DDEPS_ALLOW_OVERRIDE=OFF",
                                f"-DFETCHCONTENT_SOURCE_DIR_PROBE={self.source}", ok=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_invalid_source_declarations_fail_before_download(self):
        declarations = [
            'GIT_REPOSITORY https://example.invalid/repo',
            'GIT_REPOSITORY https://example.invalid/repo GIT_TAG main',
            f'URL "{self.archive.as_uri()}"',
            f'URL "{self.archive.as_uri()}" URL_HASH SHA256=invalid',
            f'URL "{self.archive.as_uri()}" URL_HASH SHA256={self.digest} TYPO',
        ]
        # Local overrides prevent a buggy implementation from accessing the network.
        for index, declaration in enumerate(declarations):
            for function in ("add_dependency", "add_header_dependency"):
                with self.subTest(function=function, declaration=declaration):
                    result = self.configure(f"invalid-{function}-{index}",
                        f"-DFETCHCONTENT_SOURCE_DIR_PROBE={self.source}",
                        declaration=f"{function}(probe {declaration})", ok=False)
                    self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_shallow_clone_and_offline_git_cache(self):
        run("git", "init", "-q", str(self.source))
        run("git", "add", ".", cwd=self.source)
        run("git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "-qm", "fixture", cwd=self.source)
        run("git", "tag", "v1.0.0", cwd=self.source)
        declaration = (f'add_dependency(probe GIT_REPOSITORY "{self.source.as_uri()}" '
                       'GIT_TAG v1.0.0 GIT_SHALLOW)')
        self.configure(declaration=declaration)
        clones = list(self.root.rglob(".git/shallow"))
        self.assertEqual(len(clones), 1)
        self.configure("offline", "-DDEPS_OFFLINE=ON", declaration=declaration)

    def test_dependency_options_do_not_leak_into_parent(self):
        declaration = (f'add_dependency(probe URL "{self.archive.as_uri()}" '
                       f'URL_HASH SHA256={self.digest} CMAKE_ARGS -DMODE=child)')
        self.configure(declaration=declaration)
        self.assertEqual((self.root / "build/observed.txt").read_text(), "child\n")
        self.assertEqual((self.root / "build/parent-mode.txt").read_text(), "")

    def test_header_only_never_executes_upstream_cmake(self):
        (self.source / "CMakeLists.txt").write_text('message(FATAL_ERROR "must not execute")\n')
        self.pack()
        self.configure(declaration=(f'add_header_dependency(probe URL "{self.archive.as_uri()}" '
                                    f'URL_HASH SHA256={self.digest})'))

    def test_binary_cache_survives_failed_pin_update(self):
        (self.source / "include").mkdir()
        (self.source / "include/probe.h").write_text("// fixture\n")
        (self.source / "probe.lib").write_text("fixture import library\n")
        (self.source / "probe.dll").write_text("fixture runtime\n")
        self.pack()

        def declaration(digest):
            # Exercise Windows package layout without executing a foreign binary.
            return ('set(WIN32 TRUE)\n'
                    f'add_binary_dependency(probe VERSION 1.0.0 URL "{self.archive.as_uri()}" '
                    f'URL_HASH SHA256={digest} SUBDIR probe INCLUDE_DIR include '
                    'IMPLIB probe.lib RUNTIME probe.dll)')

        self.configure(declaration=declaration(self.digest))
        result = self.configure("bad", declaration=declaration("0" * 64), ok=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.archive.unlink()
        self.configure("offline", "-DDEPS_OFFLINE=ON", declaration=declaration(self.digest))
        result = self.configure("missing", "-DDEPS_OFFLINE=ON",
                                declaration=declaration("0" * 64), ok=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_binary_release_fallback_requires_opt_in(self):
        (self.source / "include").mkdir()
        (self.source / "probe.lib").write_text("fixture import library\n")
        (self.source / "probe.dll").write_text("fixture runtime\n")
        self.pack()
        declaration = ('set(WIN32 TRUE)\n'
                       f'add_binary_dependency(probe VERSION 1.0.0 URL "{self.archive.as_uri()}" '
                       f'URL_HASH SHA256={self.digest} SUBDIR probe INCLUDE_DIR include '
                       'IMPLIB probe.lib RUNTIME probe.dll {fallback})\n'
                       'file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/runtime.txt" '
                       'CONTENT "$<TARGET_FILE:probe::probe>")')
        result = self.configure("strict", "-DCMAKE_BUILD_TYPE=Debug",
                                declaration=declaration.replace("{fallback}", ""), ok=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("IMPORTED_LOCATION", result.stdout)
        self.configure("allowed", "-DCMAKE_BUILD_TYPE=Debug",
                       declaration=declaration.replace("{fallback}", "ALLOW_RELEASE_FALLBACK"))
        self.assertTrue((self.root / "allowed/runtime.txt").read_text().endswith("probe.dll"))

    def test_manifest_checker_uses_cmake_syntax(self):
        manifest = self.root / "manifest.cmake"
        checker = ROOT / "scripts/check_deps_pinned.cmake"
        for function in ("add_dependency", "add_header_dependency"):
            manifest.write_text(f'{function}(probe GIT_REPOSITORY invalid GIT_TAG main)\n')
            result = run("cmake", f"-DDEPS_MANIFEST={manifest}", "-P", str(checker), ok=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            manifest.write_text(f'{function}(\n probe\n URL\n "{self.archive.as_uri()}"\n'
                                f' URL_HASH\n "SHA256={self.digest}"\n)\n')
            run("cmake", f"-DDEPS_MANIFEST={manifest}", "-P", str(checker))


if __name__ == "__main__":
    unittest.main()
