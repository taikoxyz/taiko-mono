#!/usr/bin/env python3
"""Build deterministic model inputs; Lean alone supplies their expected outputs."""
import argparse
from copy import deepcopy
import json
from pathlib import Path

from generate_boundaries import FORKS, block, source

ROOT = Path(__file__).resolve().parent


def build_inputs():
    """Retain golden inputs and add source/state combinations without an output oracle."""
    golden = json.loads((ROOT / 'boundary_cases.json').read_text())['cases']
    cases = [{k: deepcopy(v) for k, v in case.items() if k != 'expected'} for case in golden]
    control = next(case for case in cases if case['name'] == 'valid_control')
    manifests = json.loads((ROOT / 'manifest_cases.json').read_text())['cases']
    transactions = [case['engine_tx_list_hex'] for case in manifests
                    if case['name'] in {'type2_control', 'signed_control'}]
    for chain, fork in FORKS.items():
        for gas in [11000000, 31000000, 46000000]:
            for length in [1, 2, 4, 8]:
                for mixed in [False, True]:
                    case = deepcopy(control)
                    case['name'] = f'model_sequence_{chain}_{gas}_{length}_{int(mixed)}'
                    case['category'] = 'sequence'
                    case['chain_id'] = chain
                    case['parent'].update(timestamp=fork + 1900, gas_limit=gas)
                    case['proposal']['timestamp'] = fork + 2000
                    # These are candidate inputs, not predictions of acceptance or inheritance.
                    case['sources'] = [source(
                        [block(fork + 1901 + i, 401 + i, 30000000,
                               txs=transactions[i % len(transactions)])],
                        forced=mixed and i < length - 1)[0] for i in range(length)]
                    cases.append(case)
    return {'schema_version': 1, 'cases': cases}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('output already exists; refusing to overwrite a fixture')
    corpus = build_inputs()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(corpus, indent=2) + '\n')
    print(f"{len(corpus['cases'])} model inputs written to {args.output}")


if __name__ == '__main__':
    main()
