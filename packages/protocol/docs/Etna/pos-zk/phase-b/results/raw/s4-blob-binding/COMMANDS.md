# S4 public-data collection — exact commands

Working directory for every command below:
`packages/protocol/docs/Etna/pos-zk/phase-b/results/raw/s4-blob-binding/`
(scripts are in this directory; raw outputs are written beside them).
Collected 2026-10-07 (Asia/Singapore) against Ethereum mainnet as served by the
RPCs listed in the report §2.1. L1 head at start: block 26,140,717.

## 1. Proposal-log census (Shasta era, blocks 24,792,175–26,140,717)

    python3 scan_chunks.py 24792175 26140717 .        # 113 chunks, 10k blocks each (0xrpc-first)
    python3 finish_scan2.py 25922175 26140717 .       # remaining 220k blocks (mevblocker)
    python3 decode_proposed.py .                      # -> proposals.csv, proposals_by_tx.csv

> **Not committed (PR size, 2026-10-08).** `proposals.csv` (40,475 data rows, 9,016,011 B) and
> `proposals_by_tx.csv` (40,474 data rows, 11,469,376 B) are fetched data and are re-created by
> exactly the three commands above, against the public mainnet RPCs in §2.1 of the report. Every
> figure that used them is traced from the committed `summary.json` and the committed
> sample/filter scripts. See `../../README.md` "Datasets dropped from raw/".

First-proposal search (bisection, before the census):

    # walked 5,000-block windows forward from the proxy deployment block 24,585,332,
    # then bisected [24,792,032, 24,795,331]; first Proposed log at block 24,792,175.

## 2. Transaction sample (41 proposals, every 1000th)

    python3 verify_tx_sample.py .                     # -> tx-sample.json

## 3. Blob base fee formula check

    python3 blobfee_check.py . 24792175 24848364 24904553 24960742 25016931 25073120 \
      25129309 25185498 25241687 25297876 25354065 25410254 25466443 25522632 \
      25578821 25635010 25691199 25747388 25803577 25859766 25915955 25972144 \
      26028333 26084522                              # -> blobfee-check.json

## 4. Blob price series over proposal blocks

    python3 header_sample.py . 20                     # every 20th proposal block -> headers-sample.jsonl
    # (an earlier full census attempt, headers.jsonl, was stopped at 18,432 blocks; kept as evidence)

## 5. KZG / sidecar checks

    # reference library and setup (not committed; reproducible):
    python3 -m pip install --target /tmp/s4pkgs ckzg
    curl -sL -o /tmp/trusted_setup.txt \
      https://raw.githubusercontent.com/ethereum/c-kzg-4844/main/src/trusted_setup.txt
    shasum -a 256 /tmp/trusted_setup.txt   # d39b9f2d047cc9dca2de58f264b6a09448ccd34db967881a6713eacacf0f26b7

    PYTHONPATH=/tmp/s4pkgs python3 sample_sidecars.py . /tmp/trusted_setup.txt \
      26140717 26135739 26120000 26110000 26000002   # -> sample-sidecars.json
    PYTHONPATH=/tmp/s4pkgs python3 verify_blob.py . /tmp/trusted_setup.txt \
      26135739:0x280a53ed92b0b9f2be001e74cd707b44dbd84fb6dfe4a1b05760a2e8cc15afd6
                                                     # -> blobs/26135739-0x280a53ed.json
    PYTHONPATH=/tmp/s4pkgs python3 blob_content.py .  # -> blob-content.json

    # review fix PB-L-02: highest non-zero 32-byte word / used prefix (fetches the four
    # sidecars named in blob-content.json and keeps only the selected sidecar per slot)
    python3 sidecar_word_prefix.py .                  # -> blob-word-prefix.json, sidecars/slot-*-index-*.json

## 6. Blob retention probe

    # beacon sidecars at increasing block ages; results in blob-retention-probe.json

## 7. Earlier-era samples

    python3 era_check.py . \
      2024-08-taikoL1:0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a:0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a:20402317 \
      2025-02-taikoL1:0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a:0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a:21727117 \
      2025-06-pacaya:0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a:0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096:22591117
                                                     # -> era-trend.json
    python3 pacaya_check.py . 2026-02:24355117 2025-09:23253517 2025-02:21727117 2024-08:20402317
                                                     # -> pacaya-era.json
    python3 era_events.py .                           # -> era-proposal-events.json
    # 2025-02 all-log topic histogram (BlockProposedV2 + CalldataTxList) -> old-inbox-2025-02-topics.json

## 8. Primary parameter sources (saved under sources/)

    curl -s "https://ethereum-beacon-api.publicnode.com/eth/v1/node/version"
    curl -s "https://ethereum-beacon-api.publicnode.com/eth/v1/config/spec"          # -> sources/beacon-config-spec.json
    curl -s "https://ethereum-beacon-api.publicnode.com/eth/v1/config/fork_schedule" # -> sources/beacon-fork-schedule.json
    curl -sL "https://raw.githubusercontent.com/ethereum/consensus-specs/master/configs/mainnet.yaml" \
      -o sources/consensus-specs-mainnet.yaml
    curl -sL "https://eips.ethereum.org/EIPS/eip-4844" -o sources/eip-4844.html
    curl -sL "https://eips.ethereum.org/EIPS/eip-7691" -o sources/eip-7691.html
    curl -sL "https://eips.ethereum.org/EIPS/eip-7892" -o sources/eip-7892.html
    curl -sL "https://raw.githubusercontent.com/ethereum/c-kzg-4844/main/src/eip4844/eip4844.c" \
      -o sources/c-kzg-eip4844.c

## 9. Deployed-contract checks (Blockscout verified record + on-chain bytecode)

    curl -s "https://eth.blockscout.com/api/v2/smart-contracts/0x5253D4C91e80b880DdB54B78E74082Abe066F6b9" \
      -o blockscout-impl-0x5253.json
    curl -s -X POST https://ethereum-rpc.publicnode.com -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x5253D4C91e80b880DdB54B78E74082Abe066F6b9","latest"]}'
    curl -s -X POST https://ethereum-rpc.publicnode.com -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":["0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f","0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc","latest"]}'

## 10. Network-wide blob usage sample

    python3 net_sample.py                             # 400 blocks spread across the era -> network-blob-usage-sample.json

## 11. Summary

    python3 - <<'PY'   # (the inline summary script in the session transcript)
    PY                 # -> summary.json
