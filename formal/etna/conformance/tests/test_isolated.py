"""Focused validation tests; these never execute the namespace backend."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "run_isolated.py"

class IsolatedLauncherTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("isolated_launcher", MODULE)
        self.launcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.launcher)

    def test_binding_requires_absolute_private_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            for target in ("relative", "/", "/home", "/tmp", "/tmp/../etc"):
                with self.subTest(target=target), self.assertRaises(ValueError):
                    self.launcher.parse_binding(f"{temporary}={target}")

    def test_original_git_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            (source / ".git").write_text("gitdir: somewhere")
            with self.assertRaises(ValueError):
                self.launcher.parse_binding(f"{source}=/tmp/source")

    def test_environment_has_no_inherited_credentials_or_home(self):
        environment = self.launcher.clean_environment(["CUSTOM=value"])
        self.assertEqual(environment["CUSTOM"], "value")
        self.assertNotIn("HOME", environment)
        self.assertNotIn("GH_TOKEN", environment)
        with self.assertRaises(ValueError):
            self.launcher.clean_environment(["LD_PRELOAD=unexpected"])

    def test_nested_write_needs_existing_snapshot_mountpoint(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, output = root / "source", root / "output"
            source.mkdir(); output.mkdir()
            read = self.launcher.parse_binding(f"{source}=/tmp/source")
            write = self.launcher.parse_binding(f"{output}=/tmp/source/.lake")
            with self.assertRaises(ValueError):
                self.launcher.validate_bindings([read], [write])
            (source / ".lake").mkdir()
            self.launcher.validate_bindings([read], [write])

    def test_duplicate_mounts_and_parent_writable_mount_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            first = self.launcher.parse_binding(f"{temporary}=/tmp/source")
            second = self.launcher.parse_binding(f"{temporary}=/tmp/source/sub")
            with self.assertRaises(ValueError):
                self.launcher.validate_bindings([first], [first])
            with self.assertRaises(ValueError):
                self.launcher.validate_bindings([second], [first])

if __name__ == "__main__":
    unittest.main()
