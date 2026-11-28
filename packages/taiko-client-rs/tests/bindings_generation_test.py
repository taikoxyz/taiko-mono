#!/usr/bin/env python3
"""Regression tests for Rust contract binding normalization."""

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))

from normalize_bindings import normalize_bindings, normalize_source


class BindingsGenerationTests(unittest.TestCase):
    def test_removes_derived_attribute_from_inherent_impls(self):
        for header in (
            "impl Binding",
            "impl<P: Provider<N>, N: Network> Binding<P, N>",
            "impl<F: for<'a> Fn(&'a str)> Binding<F>",
            "impl<F> Binding<F> where F: for<'a> Fn(&'a str)",
        ):
            with self.subTest(header=header):
                source = f"    #[automatically_derived]\n    {header} {{}}\n"
                self.assertEqual(normalize_source(source), f"    {header} {{}}\n")

    def test_preserves_derived_attributes_on_trait_impls(self):
        for header in (
            "impl Debug for Binding",
            "impl<P, N> Debug for Binding<P, N>",
            "impl<F> Debug for Binding<F> where F: for<'a> Fn(&'a str)",
        ):
            with self.subTest(header=header):
                source = f"    #[automatically_derived]\n    #[doc(hidden)]\n    {header} {{}}\n"
                self.assertEqual(normalize_source(source), source)

    def test_preserves_other_attributes_on_inherent_impls(self):
        source = "#[automatically_derived]\n#[doc(hidden)]\nimpl Binding {}\n"
        self.assertEqual(normalize_source(source), "#[doc(hidden)]\nimpl Binding {}\n")

    def test_normalization_is_idempotent_and_limits_warning_exemptions(self):
        with tempfile.TemporaryDirectory() as directory:
            bindings = Path(directory)
            source = bindings / "src"
            source.mkdir()
            library = source / "lib.rs"
            library.write_text("#![allow(unused_imports, clippy::all, rustdoc::all)]\npub mod binding;\n")
            contract = source / "binding.rs"
            contract.write_text("#[automatically_derived]\nimpl Binding {}\n")
            normalize_bindings(bindings)
            once = {path.name: path.read_bytes() for path in source.glob("*.rs")}
            self.assertTrue(library.read_text().startswith("#![allow(dead_code)]\n"))
            self.assertNotIn("allow(warnings)", library.read_text())
            self.assertEqual(contract.read_text(), "impl Binding {}\n")
            normalize_bindings(bindings)
            self.assertEqual(once, {path.name: path.read_bytes() for path in source.glob("*.rs")})


if __name__ == "__main__":
    unittest.main()
