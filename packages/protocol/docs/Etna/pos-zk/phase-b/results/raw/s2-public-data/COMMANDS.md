# S2 public-data substitution — exact commands

All commands were run on 2026-10-07 (UTC) from this directory
(packages/protocol/docs/Etna/pos-zk/phase-b/results/raw/s2-public-data)
unless stated otherwise. \`cast\` = Foundry 1.8.3 (cae51ad458f6abb64852b7709eb784352429825d),
python3 = 3.9.6. Every fetch script appends a timestamped \`<out>.meta.txt\` line per
request batch, so the coverage window of every file is auditable next to it.

## 1. Ethereum L1 block headers (mainnet, chain id 1)

    python3 fetch_rpc.py blocks https://rpc.mevblocker.io 26120733 26140732 l1_blocks_mevblocker.jsonl --batch=500
    # 20000 headers, 89.6 s, blocks 26120733..26140732
    # cross-check provider (partial, stopped at 10556 headers):
    python3 fetch_rpc.py blocks https://ethereum-rpc.publicnode.com 26120733 26140732 l1_blocks_26140732.jsonl --batch=500 --resume

    python3 analyze.py blocks l1_blocks_mevblocker.jsonl l1_blocks
    python3 analyze.py blocks l1_blocks_26140732.jsonl l1_blocks_partial

    # provider agreement over the overlap (0 timestamp mismatches):
    python3 - <<'EOF'
    import json
    a = {int(json.loads(l)["number"],16): int(json.loads(l)["timestamp"],16) for l in open('l1_blocks_26140732.jsonl')}
    b = {int(json.loads(l)["number"],16): int(json.loads(l)["timestamp"],16) for l in open('l1_blocks_mevblocker.jsonl')}
    common = sorted(set(a) & set(b)); print(len(common), sum(1 for h in common if a[h]!=b[h]))
    EOF

## 2. Taiko L2 block headers (Taiko mainnet, chain id 167000 = 0x28c58)

    python3 fetch_rpc.py blocks https://rpc.taiko.xyz 12347771 12367770 taiko_l2_blocks_12367770.jsonl --batch=50 --resume
    python3 analyze.py blocks taiko_l2_blocks_12367770.jsonl taiko_l2

## 3. Taiko Shasta Inbox logs on L1 (7-day window) + headers for the log blocks

    # archive-capable endpoint: publicnode/flashbots return empty or refuse ranges
    # older than the full-node window; tenderly's public gateway serves them.
    python3 fetch_rpc.py logs https://mainnet.gateway.tenderly.co \
        0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 26090333 26140732 taiko_inbox_logs_7d.json --chunk=2000

    python3 - <<'EOF'
    import json
    logs = json.load(open('taiko_inbox_logs_7d.json'))
    hs = sorted({int(l['blockNumber'],16) for l in logs})
    open('inbox_log_heights.txt','w').write("\n".join(str(h) for h in hs) + "\n")
    EOF
    python3 fetch_rpc.py headers https://rpc.mevblocker.io inbox_log_heights.txt inbox_block_headers.json
    python3 analyze.py inbox taiko_inbox_logs_7d.json inbox_block_headers.json

    # event topics (Foundry):  Proposed(...) = 0x7c4c..1213,  Proved(uint48,uint48,uint48,address) = 0xa274..a2f0
    cast sig-event "Proposed(uint48,address,bytes32,uint48,uint8,(bool,(bytes32[],uint24,uint48))[])"
    cast sig-event "Proved(uint48,uint48,uint48,address)"

## 4. Production CometBFT chains (third-party networks, for comparison only)

    python3 fetch_cometbft_chain.py https://cosmos-rpc.polkachu.com 1000 cosmos_hub_blocks.jsonl
    python3 fetch_cometbft_chain.py https://celestia-rpc.polkachu.com 1000 celestia_blocks.jsonl
    python3 fetch_cometbft.py https://dydx-rpc.publicnode.com 1000 dydx_blocks.jsonl --batch=20

    python3 analyze.py cometbft cosmos_hub_blocks.jsonl cosmos_hub
    python3 analyze.py cometbft celestia_blocks.jsonl celestia
    python3 analyze.py cometbft dydx_blocks.jsonl dydx

    # bonded validator counts (Cosmos SDK REST):
    curl -s "https://cosmos-rest.publicnode.com/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.count_total=true&pagination.limit=1" | jq .pagination
    curl -s "https://celestia-rest.publicnode.com/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.count_total=true&pagination.limit=1" | jq .pagination
    curl -s "https://dydx-rest.publicnode.com/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.count_total=true&pagination.limit=1" | jq .pagination

## 5. Third-party published sources (downloads + text extraction)

    curl -sL -o thirdparty/tendermint-srds2021-srds.pdf "https://www.inf.usi.ch/faculty/pedone/Paper/2021/srds2021a.pdf"
    curl -sL -o thirdparty/zenodo-ccs26-artifact-appendix.pdf \
        "https://zenodo.org/api/records/21828731/files/Artifact%20Appendix.pdf/content"
    curl -s -o thirdparty/tenderload-parameters.json \
        "https://raw.githubusercontent.com/cryptobern/tenderload/ccs26/benchmark/parameters.json"
    for F in baseline_n_28_1000_1 baseline_n_28_10000_1 baseline_n_49_1000_1; do
      curl -s -o "thirdparty/tenderload/$F.csv" "https://raw.githubusercontent.com/cryptobern/tenderload/ccs26/benchmark/$F.csv"
    done
    # PDF -> text (pypdf 6.19.0 installed to /tmp/pylibs, not to the repo):
    python3 -m pip install --target /tmp/pylibs pypdf
    python3 -c "import sys; sys.path.insert(0,'/tmp/pylibs'); from pypdf import PdfReader; \
      open('thirdparty/tendermint-srds2021-extracted.txt','w').write('\n'.join(p.extract_text() or '' for p in PdfReader('thirdparty/tendermint-srds2021-srds.pdf').pages))"

    # CometBFT repository check (no published latency table):
    for p in docs/references/benchmarks.md docs/architecture/benchmarks.md docs/references/benchmarks/index.md; do
      curl -s -o /dev/null -w "%{http_code} $p\n" "https://raw.githubusercontent.com/cometbft/cometbft/main/$p"; done
    # present: test/loadtime/README.md (tooling, no numbers); docs/references/rfc/tendermint-core/rfc-003-performance-questions.md (no numbers)

## 6. Hashes

    shasum -a 256 *.jsonl *.json *.csv > HASHES.txt
