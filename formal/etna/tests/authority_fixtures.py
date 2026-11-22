"""Materialize the pinned historical sources for mutation tests."""
import json


def copy_historical_authorities(coverage, fixture):
    clause_config = json.loads((coverage.ROOT/coverage.HISTORICAL_CONFIG).read_text())
    rule_config = json.loads((coverage.ROOT/'rule-coverage.json').read_text())
    pins = [clause_config[key] for key, _, _, _ in coverage.SOURCE_INPUTS] + [rule_config['index']]
    for pin in pins:
        path = pin['path']
        target = fixture/path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(coverage.archive_bytes(coverage.REPO, path, pin['commit']))
