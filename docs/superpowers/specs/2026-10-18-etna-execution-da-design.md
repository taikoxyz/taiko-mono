# Etna execution DA and private consensus witnesses

## Approved behavior

Publish canonical complete CometBFT headers and complete L2 execution blocks (EL header and ordered EIP-2718 transactions). Keep original envelope v6, all anchor/committee/forced witnesses, evidence, commits and signatures as consensus/proving inputs. Preserve back-pressure, recovery generation, committee selection, forced inclusion validity, payouts and withdrawal eligibility.

Payload v6 is `0x06 || zlib(rlp([[comet_header_proto_bytes, execution_block_rlp_bytes], ...]))`. The second item is an opaque canonical RLP byte string encoding [el_header, transactions], without envelope version or witnesses. Batches decode independently. Check canonical framing and linked Comet/EL heights and parents. Public decoding cannot authenticate the omitted envelope against data_hash. Before publication and after job restoration, authenticate original private envelopes and project their exact execution blocks. The proof authenticates original certificates, witness rules, execution and the public projection.

## Recovery trust boundary

Assume a sound real ZK landing proof and a finalized canonical L1 checkpoint binding the ordered blob hashes. Archived blob bytes plus the required genesis/execution context suffice to reconstruct the landed EL chain and match the terminal hash/state root without original consensus witnesses or signatures. Commitments alone cannot recover unavailable blob bytes. Exact historical consensus envelopes and stock CometBFT validator bootstrap are separate capabilities; L1-only CometBFT state bootstrap is not implemented. Unlanded blocks retain existing consensus/proving requirements. Dummy proofs do not establish the soundness assumption.

## Capacity and persistence

Prepare/Process measure the execution-block bytes payload v6 publishes, with existing conservative header/framing allowance and split-compression fallback. Preserve six blobs, contract maxBatchBlocks, back-pressure and generation. Bound full private protobuf/envelope/commit retention independently so smaller DA cannot admit an unjournalable job. Preserve allocation, decompression and compression-work limits.

## Compatibility and verification

Use statement domain V10 with the existing nine LandInput fields and 21-word layout. Bump journal schema to 12; incompatible outstanding jobs fail closed without discarding signed bytes/nonces. Envelope v6, APP_VERSION 3, config opening, storage layout and reward receipt format remain unchanged. Regenerate protocol/client ABI, bytecode, fixtures and independent vectors from the new protocol commit.

Verify projection and private-envelope tampering, witness-free canonical decoding/recovery, old format rejection, arbitrary batch cuts, cross-epoch transitions, forced inclusion/skip hot and cold replay, journal/nonce restoration, private-retention prefix bounds and single-block capacity. Compare compressed payload size/capacity using identical blocks. Run full verification before pushing. Update both PR descriptions with the recovery assumption and edit only item 9 of linked Notion/GitHub review.
