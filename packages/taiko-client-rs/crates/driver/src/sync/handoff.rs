//! Finalized Unzen closure proof shared by startup and the serial event loop.

use std::{
    fs::{self, File},
    io::Write,
    path::Path,
};

use alethia_reth_primitives::payload::attributes::RpcL1Origin;
use alloy::{
    eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash},
    primitives::{Address, B256, U256, keccak256},
    sol_types::{SolEvent, SolValue},
};
use alloy_provider::Provider;
use alloy_rpc_types::Filter;
use bindings::inbox::{IInbox::Proposal, Inbox::Proposed};
use rpc::{RpcClientError, client::Client};
use serde::{Deserialize, Serialize};

use crate::{
    driver::UnzenOrigin,
    sync::{
        SyncError, confirmed_sync::build_confirmed_sync_snapshot, is_finalized_block_not_found,
    },
};

/// Closing proposal identity authenticated by one exact finalized L1 state.
struct ClosingProposal {
    /// Hash pinning every closing Inbox state read.
    finalized_hash: B256,
    /// Finalized height bounding the proposal's canonical L1 origin.
    finalized_number: u64,
    /// Timestamp after which no Unzen proposal or block may be accepted.
    fork_timestamp: u64,
    /// Last accepted proposal in the closing core state.
    target: u64,
    /// L1 height at which the closing core state accepted its last proposal.
    last_proposal_block: u64,
}

/// Build a canonical EIP-1898 block selector for one authenticated L1 state.
fn pinned_block(hash: B256) -> BlockId {
    BlockId::Hash(RpcBlockHash { block_hash: hash, require_canonical: Some(true) })
}

/// Whole-proposal completion recorded only after the serialized derivation call returns.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub(crate) struct CompletedProposal {
    /// Proposal whose complete manifest was materialized and its origins refreshed.
    pub(crate) proposal_id: u64,
    /// Exact source L1 height of that successful proposal call.
    pub(crate) l1_number: u64,
    /// Exact source L1 hash of that successful proposal call.
    pub(crate) l1_hash: B256,
    /// Final outcome after all sources and blocks of the proposal finished.
    pub(crate) height: u64,
    /// Canonical final outcome hash returned by the complete proposal call.
    pub(crate) hash: B256,
}

/// Durable completion evidence, reauthenticated against finalized L1 and canonical EL on use.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct CompletionReceipt {
    /// Receipt encoding, rejected rather than migrated when it differs.
    version: u8,
    /// Execution chain whose complete proposal was derived.
    chain_id: u64,
    /// Legacy Inbox accepting that proposal.
    inbox: Address,
    /// Configured transition timestamp that closed the proposal stream.
    fork_timestamp: u64,
    /// Whole-proposal outcome, independent of EL's per-block batch mapping writes.
    completed: CompletedProposal,
    /// Proposal hash authenticated by the exact finalized Inbox state.
    proposal_hash: B256,
    /// Own finalized observation used before durably recording completion.
    finalized_l1_number: u64,
    /// Hash of the own finalized observation.
    finalized_l1_hash: B256,
}

/// Canonical proposal identity independently authenticated by finalized Inbox state.
struct AuthenticatedProposal {
    /// Accepted proposal source height in canonical L1.
    l1_number: u64,
    /// Accepted proposal source hash in canonical L1.
    l1_hash: B256,
    /// Hash of the accepted proposal reconstructed from its canonical source log.
    proposal_hash: B256,
}

/// Load optional completion evidence without trusting malformed or stale local metadata.
fn load_receipt(path: &Path) -> Result<Option<CompletionReceipt>, SyncError> {
    match fs::read(path) {
        Ok(bytes) => Ok(serde_json::from_slice(&bytes).ok()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(SyncError::EtnaReceipt(error.to_string())),
    }
}

/// Persist completion before returning control to Etna; the caller exclusively owns the path.
fn save_receipt(path: &Path, receipt: &CompletionReceipt) -> Result<(), SyncError> {
    let parent = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .ok_or_else(|| SyncError::EtnaReceipt("receipt needs a parent directory".into()))?;
    let bytes =
        serde_json::to_vec(receipt).map_err(|error| SyncError::EtnaReceipt(error.to_string()))?;
    let temporary = path.with_extension(format!("tmp-{}", std::process::id()));
    let persist = || -> std::io::Result<()> {
        fs::create_dir_all(parent)?;
        let mut file = File::create(&temporary)?;
        file.write_all(&bytes)?;
        file.sync_all()?;
        fs::rename(&temporary, path)?;
        File::open(parent)?.sync_all()
    };
    persist().map_err(|error| SyncError::EtnaReceipt(error.to_string()))
}

/// Bind the independent origin row to the canonical accepted proposal and its stored hash.
/// Missing custom metadata or L1 data keeps handoff pending; authenticated contradictions fail.
async fn verify_proposal_origin(
    rpc: &Client,
    closing: &ClosingProposal,
    origin: &RpcL1Origin,
) -> Result<Option<AuthenticatedProposal>, SyncError> {
    let (Some(origin_number), Some(origin_hash)) = (origin.l1_block_height, origin.l1_block_hash)
    else {
        return Ok(None);
    };
    let Ok(origin_number) = u64::try_from(origin_number) else { return Ok(None) };
    if origin_number == 0 ||
        origin_number != closing.last_proposal_block ||
        origin_number > closing.finalized_number
    {
        return Ok(None);
    }
    let Some(canonical) = rpc
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Number(origin_number))
        .await
        .map_err(RpcClientError::from)?
    else {
        return Ok(None);
    };
    if canonical.header.number != origin_number ||
        canonical.header.inner.hash_slow() != canonical.header.hash
    {
        return Err(SyncError::InvalidEtnaHandoff(
            "canonical local L1 header is internally inconsistent",
        ));
    }
    if canonical.header.hash != origin_hash {
        return Ok(None);
    }
    if canonical.header.timestamp >= closing.fork_timestamp {
        return Err(SyncError::InvalidEtnaHandoff(
            "closing Unzen proposal timestamp reaches the Etna fork",
        ));
    }
    let filter = Filter::new()
        .address(*rpc.shasta.inbox.address())
        .at_block_hash(origin_hash)
        .event_signature(Proposed::SIGNATURE_HASH)
        .topic1(B256::from(U256::from(closing.target)));
    let logs = rpc.l1_provider.get_logs(&filter).await.map_err(RpcClientError::from)?;
    let mut accepted = None;
    for log in logs {
        if log.removed ||
            log.block_hash != Some(origin_hash) ||
            log.block_number != Some(origin_number) ||
            log.address() != *rpc.shasta.inbox.address()
        {
            return Err(SyncError::InvalidEtnaHandoff(
                "closing proposal log contradicts its canonical origin",
            ));
        }
        let event = Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
            .map_err(|_| SyncError::InvalidEtnaHandoff("closing proposal log is malformed"))?;
        if event.id.to::<u64>() != closing.target || accepted.replace(event).is_some() {
            return Err(SyncError::InvalidEtnaHandoff("closing proposal log identity is ambiguous"));
        }
    }
    let Some(event) = accepted else { return Ok(None) };
    let timestamp =
        canonical.header.timestamp.try_into().map_err(|_| {
            SyncError::InvalidEtnaHandoff("closing proposal timestamp exceeds uint48")
        })?;
    let parent_number = (origin_number - 1).try_into().map_err(|_| {
        SyncError::InvalidEtnaHandoff("closing proposal parent height exceeds uint48")
    })?;
    let proposal = Proposal {
        id: event.id,
        timestamp,
        endOfSubmissionWindowTimestamp: event.endOfSubmissionWindowTimestamp,
        proposer: event.proposer,
        parentProposalHash: event.parentProposalHash,
        originBlockNumber: parent_number,
        originBlockHash: canonical.header.parent_hash,
        basefeeSharingPctg: event.basefeeSharingPctg,
        sources: event.sources,
    };
    let expected = rpc
        .shasta
        .inbox
        .getProposalHash(U256::from(closing.target))
        .block(pinned_block(closing.finalized_hash))
        .call()
        .await
        .map_err(RpcClientError::from)?;
    if expected.is_zero() || expected != keccak256(proposal.abi_encode()) {
        return Err(SyncError::InvalidEtnaHandoff(
            "closing proposal hash contradicts finalized Inbox state",
        ));
    }
    Ok(Some(AuthenticatedProposal {
        l1_number: origin_number,
        l1_hash: origin_hash,
        proposal_hash: expected,
    }))
}

/// Prove the closing proposal's canonical block from core state pinned to finalized L1.
/// Missing finality or independent execution metadata keeps handoff pending (WLP-INV-005/006).
pub(crate) async fn try_etna_origin(
    rpc: &Client,
    fork_timestamp: u64,
    receipt_path: &Path,
    completed: Option<&CompletedProposal>,
) -> Result<Option<UnzenOrigin>, SyncError> {
    let finalized = match rpc.l1_provider.get_block_by_number(BlockNumberOrTag::Finalized).await {
        Ok(finalized) => finalized,
        Err(error)
            if error.as_error_resp().is_some_and(|payload| {
                is_finalized_block_not_found(payload.code, payload.message.as_ref())
            }) =>
        {
            return Ok(None)
        }
        Err(error) => return Err(RpcClientError::from(error).into()),
    };
    let Some(finalized) = finalized else { return Ok(None) };
    if finalized.header.timestamp < fork_timestamp {
        return Ok(None);
    }
    let finalized_hash = finalized.header.hash;
    if finalized.header.inner.hash_slow() != finalized_hash {
        return Err(SyncError::InvalidEtnaHandoff(
            "local finalized L1 header has an inconsistent hash",
        ));
    }
    let core = rpc
        .shasta
        .inbox
        .getCoreState()
        .block(pinned_block(finalized_hash))
        .call()
        .await
        .map_err(RpcClientError::from)?;
    let target = core
        .nextProposalId
        .to::<u64>()
        .checked_sub(1)
        .ok_or(SyncError::InvalidEtnaHandoff("closing Inbox is not activated"))?;
    let proof_complete = core.lastFinalizedProposalId.to::<u64>() == target &&
        !core.lastFinalizedBlockHash.is_zero();
    let receipt = load_receipt(receipt_path)?;
    // A prior completed handoff identifies S by hash even if custom tables were later lost.
    // Fresh derivation evidence takes precedence so a stale receipt can be replaced safely.
    let receipt_candidate = receipt.as_ref().filter(|receipt| {
        completed.is_none() &&
            receipt.version == 1 &&
            receipt.chain_id == rpc.chain_id &&
            receipt.inbox == *rpc.shasta.inbox.address() &&
            receipt.fork_timestamp == fork_timestamp &&
            receipt.completed.proposal_id == target
    });
    let independent_hash = if proof_complete {
        Some(core.lastFinalizedBlockHash)
    } else {
        receipt_candidate.map(|receipt| receipt.completed.hash)
    };
    let mut mapped_height = None;
    let block = if let Some(hash) = independent_hash {
        // The finalized Inbox terminal hash is stronger than per-build custom tables. P2P
        // import or a crashed partial build may leave those tables absent or behind this block.
        rpc.l2_provider.get_block_by_hash(hash).await.map_err(RpcClientError::from)?
    } else {
        let gate = build_confirmed_sync_snapshot(
            target,
            |proposal_id| async move {
                Ok::<_, RpcClientError>(
                    rpc.last_block_id_by_batch_id(U256::from(proposal_id))
                        .await?
                        .and_then(|height| u64::try_from(height).ok()),
                )
            },
            || async {
                Ok::<_, RpcClientError>(
                    rpc.head_l1_origin()
                        .await?
                        .and_then(|origin| u64::try_from(origin.block_id).ok()),
                )
            },
        )
        .await?;
        if !gate.is_ready() {
            return Ok(None)
        }
        let height = if target == 0 {
            0
        } else {
            let Some(height) = gate.target_block.filter(|height| *height != 0) else {
                return Ok(None)
            };
            height
        };
        mapped_height = Some(height);
        rpc.l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(height))
            .await
            .map_err(RpcClientError::from)?
    };
    let Some(block) = block else { return Ok(None) };
    let height = block.header.number;
    if target != 0 && height == 0 {
        return Ok(None)
    }
    if mapped_height.is_some_and(|mapped| mapped != height) ||
        independent_hash.is_some_and(|hash| block.header.hash != hash)
    {
        return Err(SyncError::InvalidEtnaHandoff("local proof-finalized block has the wrong hash"));
    }
    if block.header.hash.is_zero() || block.header.inner.hash_slow() != block.header.hash {
        return Err(SyncError::InvalidEtnaHandoff(
            "closing Unzen header hash or height is inconsistent",
        ));
    }
    if block.header.timestamp >= fork_timestamp {
        return Ok(None);
    }
    let authenticated = if target != 0 {
        if block.header.extra_data.len() != 7 ||
            alethia_reth_primitives::decode_shasta_proposal_id(&block.header.extra_data) !=
                Some(target)
        {
            return Ok(None);
        }
        let origin = if let Some(receipt) = receipt_candidate.filter(|_| !proof_complete) {
            RpcL1Origin {
                block_id: U256::from(height),
                l2_block_hash: block.header.hash,
                l1_block_height: Some(U256::from(receipt.completed.l1_number)),
                l1_block_hash: Some(receipt.completed.l1_hash),
                build_payload_args_id: [0; 8],
                is_forced_inclusion: false,
                signature: [0; 65],
            }
        } else if proof_complete {
            let source_number = core.lastProposalBlockId.to::<u64>();
            let Some(source) = rpc
                .l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(source_number))
                .await
                .map_err(RpcClientError::from)?
            else {
                return Ok(None)
            };
            RpcL1Origin {
                block_id: U256::from(height),
                l2_block_hash: block.header.hash,
                l1_block_height: Some(U256::from(source_number)),
                l1_block_hash: Some(source.header.hash),
                build_payload_args_id: [0; 8],
                is_forced_inclusion: false,
                signature: [0; 65],
            }
        } else {
            let Some(origin) = rpc.l1_origin_by_id(U256::from(height)).await? else {
                return Ok(None)
            };
            if origin.l2_block_hash != block.header.hash || origin.block_id != U256::from(height) {
                return Ok(None);
            }
            origin
        };
        let closing = ClosingProposal {
            finalized_hash,
            finalized_number: finalized.header.number,
            fork_timestamp,
            target,
            last_proposal_block: core.lastProposalBlockId.to::<u64>(),
        };
        let Some(authenticated) = verify_proposal_origin(rpc, &closing, &origin).await? else {
            return Ok(None);
        };
        authenticated
    } else {
        AuthenticatedProposal { l1_number: 0, l1_hash: B256::ZERO, proposal_hash: B256::ZERO }
    };
    let expected_completion = CompletedProposal {
        proposal_id: target,
        l1_number: authenticated.l1_number,
        l1_hash: authenticated.l1_hash,
        height,
        hash: block.header.hash,
    };
    // EL's batch/head metadata is written for each block, so it cannot establish that all
    // blocks in this proposal finished. Accept only a completed serial derivation, a verified
    // durable receipt, or the terminal hash independently finalized by the Inbox itself.
    let mut receipt_valid = false;
    if let Some(receipt) = &receipt &&
        receipt.version == 1 &&
        receipt.chain_id == rpc.chain_id &&
        receipt.inbox == *rpc.shasta.inbox.address() &&
        receipt.fork_timestamp == fork_timestamp &&
        receipt.completed == expected_completion &&
        receipt.proposal_hash == authenticated.proposal_hash &&
        receipt.finalized_l1_number <= finalized.header.number
    {
        let observation = rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(receipt.finalized_l1_number))
            .await
            .map_err(RpcClientError::from)?;
        receipt_valid = observation.is_some_and(|observation| {
            observation.header.hash == receipt.finalized_l1_hash &&
                observation.header.timestamp >= fork_timestamp &&
                observation.header.inner.hash_slow() == observation.header.hash
        });
    }

    let finalized_completion = proof_complete;
    if target != 0 &&
        completed != Some(&expected_completion) &&
        !receipt_valid &&
        !finalized_completion
    {
        return Ok(None);
    }
    // Reconfirm canonicality after all independent state/table/log reads. A finality rollback
    // or a moved canonical header keeps the handoff pending rather than publishing a mixed view.
    let current_finalized = rpc
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Finalized)
        .await
        .map_err(RpcClientError::from)?;
    let canonical_closing = rpc
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Number(finalized.header.number))
        .await
        .map_err(RpcClientError::from)?;
    let canonical_l2 = rpc
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(height))
        .await
        .map_err(RpcClientError::from)?;
    if current_finalized.is_none_or(|header| {
        header.header.number < finalized.header.number ||
            (header.header.number == finalized.header.number &&
                header.header.hash != finalized_hash)
    }) || canonical_closing.is_none_or(|header| header.header.hash != finalized_hash) ||
        canonical_l2.is_none_or(|header| header.header.hash != block.header.hash)
    {
        return Ok(None);
    }
    if !receipt_valid {
        save_receipt(
            receipt_path,
            &CompletionReceipt {
                version: 1,
                chain_id: rpc.chain_id,
                inbox: *rpc.shasta.inbox.address(),
                fork_timestamp,
                completed: expected_completion,
                proposal_hash: authenticated.proposal_hash,
                finalized_l1_number: finalized.header.number,
                finalized_l1_hash: finalized_hash,
            },
        )?;
    }
    Ok(Some(UnzenOrigin {
        finalized_l1_number: finalized.header.number,
        finalized_l1_hash: finalized_hash,
        height,
        hash: block.header.hash,
    }))
}
