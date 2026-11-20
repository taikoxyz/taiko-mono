"""Audit-viewer regressions: real source indexing, safe embedding and stale-output rejection."""
import importlib.util
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT/'scripts/generate_statements.py'


def generator():
    spec = importlib.util.spec_from_file_location('etna_statements_html', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class StatementsHTMLTests(unittest.TestCase):
    def test_nested_names_ignore_comment_and_string_declarations(self):
        rows = generator().source_declarations('''namespace Outer.Inner
/- nested /- def fake := 1 -/ theorem alsoFake : True -/
section
/-- A real definition. -/
def text := "def notADeclaration := 3"
namespace More
structure Data where
  height : Nat
end More
end
theorem fine : True := by trivial
end Outer.Inner
''')
        self.assertEqual([(r['name'],r['kind'],r['line']) for r in rows], [
            ('Outer.Inner.text','def',5), ('Outer.Inner.More.Data','structure',7),
            ('Outer.Inner.fine','theorem',11)])
        self.assertEqual(rows[0]['doc'], 'A real definition.')

    def test_every_reviewed_contract_has_its_actual_module_and_source_line(self):
        data = generator().build_catalogue()
        entries = {d['name']:d for d in data['declarations']}
        manifest = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
        self.assertEqual(sum('contract' in d for d in entries.values()),len(manifest))
        for contract in manifest:
            row = entries[contract['declaration']]
            self.assertEqual(row['module'],contract['module'])
            source_line = data['files'][row['file']]['text'].splitlines()[row['line']-1]
            self.assertIn(row['name'].rsplit('.',1)[-1],source_line)
            self.assertEqual(row['contract'],contract)
        self.assertEqual(entries['Etna.Statements.Current.Premises']['profile'],'current')
        self.assertEqual(entries['Etna.Design.Staking.fraction_bounded']['profile'],'shared')

    def test_lean_string_cannot_escape_the_embedded_json(self):
        module = generator()
        payload = {'text':'</script><script>alert("injected")</script>&\u2028'}
        page = module.render_page(payload)
        from html.parser import HTMLParser
        class Scripts(HTMLParser):
            def __init__(self):
                super().__init__(); self.scripts=[]; self.active=False
            def handle_starttag(self, tag, attrs):
                self.active = tag == 'script'
                if self.active: self.scripts.append([dict(attrs),''])
            def handle_data(self, value):
                if self.active: self.scripts[-1][1] += value
            def handle_endtag(self, tag):
                if tag == 'script': self.active=False
        parser=Scripts(); parser.feed(page)
        self.assertEqual(len(parser.scripts),2)
        self.assertEqual(json.loads(parser.scripts[0][1]),payload)
        self.assertTrue(all('src' not in attrs for attrs,_ in parser.scripts))

    def test_check_rejects_a_hand_edited_viewer(self):
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'STATEMENTS.html'
            command=[sys.executable,str(SCRIPT),'--out',str(output)]
            first=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(first.returncode,0,first.stderr)
            good=subprocess.run(command+['--check'],capture_output=True,text=True)
            self.assertEqual(good.returncode,0,good.stderr)
            output.write_text(output.read_text()+'<!-- stale -->')
            bad=subprocess.run(command+['--check'],capture_output=True,text=True)
            self.assertNotEqual(bad.returncode,0)
            self.assertIn('stale',bad.stderr)

    def test_csp_hashes_match_actual_inline_bytes_after_template_formatting(self):
        import re
        page=generator().render_page({})
        for tag in ('style','script'):
            bodies=re.findall(r'<'+tag+r'>(.*?)</'+tag+r'>',page,re.S)
            self.assertEqual(len(bodies),1)
            digest=base64.b64encode(hashlib.sha256(bodies[0].encode()).digest()).decode()
            self.assertTrue(f"{tag}-src 'sha256-{digest}'" in page,
                            f'{tag} inline bytes no longer match the declared CSP hash')

    def test_curated_navigation_and_explanations_resolve_to_actual_declarations(self):
        import re
        module=generator()
        data=module.build_catalogue()
        names={row['name'] for row in data['declarations']}
        assets=ROOT/'scripts/statements'
        text=(assets/'reader.html').read_text()+(assets/'reader.js').read_text()
        # Catches dead headline buttons and stale explanatory entries after a rename.
        targets=set(re.findall(r'Etna\.[A-Za-z0-9_.]+',text))
        self.assertTrue(targets)
        self.assertEqual(targets-names,set())

    def test_citations_use_each_authority_path_at_its_pinned_commit(self):
        module=generator()
        data=module.build_catalogue()
        pins=json.loads((ROOT/'spec-coverage.json').read_text())
        paths={path for _,_,path,_ in module.coverage.SOURCE_INPUTS}
        self.assertEqual(set(data['authorities']),paths)
        for key,_,path,_ in module.coverage.SOURCE_INPUTS:
            self.assertEqual(data['authorities'][path].get('github_path'),path)
            self.assertEqual(data['authorities'][path]['commit'],pins[key]['commit'])
        self.assertEqual({c['path'] for c in data['clauses']},paths)

    def test_citation_lines_keep_raw_offsets_when_rule_marker_lines_are_removed(self):
        module=generator()
        raw='one\n// [ENC-A-6]\n**[ENC-A-7]** two\n  // [ENC-A-8]\nthree\n'
        self.assertEqual(module.source_line_map(raw),[1,3,5])
        data=module.build_catalogue()
        for clause in data['clauses']:
            raw=(module.REPO/clause['path']).read_text()
            clean=module.coverage.strip_markers(raw).splitlines(keepends=True)
            excerpt=''.join(raw.splitlines(keepends=True)[clause['github_start_line']-1:clause['github_end_line']])
            expected=''.join(clean[clause['start_line']-1:clause['end_line']])
            self.assertEqual(module.coverage.strip_markers(excerpt),expected,clause['id'])


if __name__ == '__main__':
    unittest.main()
