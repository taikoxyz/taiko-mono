//! Native QC, original body commitments and full-identity ancestry.
use super::{
    codec::CodecError,
    native::{Block, Commit, CommitSig, RawBlock, evidence::Sum as RawEvidence},
};
use alloc::{collections::BTreeSet, format, string::String, vec::Vec};
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    Hash, Vote,
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{
    Protobuf,
    v0_38::types::{CanonicalVote as RawVote, CommitSig as RawCommitSig},
};

/// Pure native certificate/body failure; host runtime policy belongs at the caller.
#[derive(Debug, thiserror::Error)]
pub enum BftError {
    /// Invalid native certificate, signed field or ordered slot.
    #[error("invalid CometBFT certificate: {0}")]
    Certificate(String),
    /// Original body differs from a committed root or ancestry identity.
    #[error("CometBFT {0} commitment mismatch")]
    Commitment(&'static str),
    /// Canonical original protobuf or projection mismatch.
    #[error(transparent)]
    Codec(#[from] CodecError),
    /// Etna requires exactly one committed transaction, independently of envelope decoding.
    #[error("expected exactly one Etna transaction, got {0}")]
    TransactionCount(usize),
    /// Empty or oversized encoding cannot form a nonempty stock u32 part set.
    #[error("invalid native block part-set length")]
    PartSetLength,
}

/// Borrowed original block, projection and current certificate, without host transport state.
#[derive(Clone, Copy)]
pub struct CertifiedBlockRef<'a> {
    /// Supported header, transactions and previous certificate.
    pub block: &'a Block,
    /// Original canonical protobuf; evidence is committed from these bytes.
    pub raw_block: &'a [u8],
    /// Current-height native certificate, separately authenticated by QC verification.
    pub commit: &'a Commit,
}

/// Portable SDK SHA-256 provider; native and guest header hashing use the same SHA-256 bytes.
#[derive(Default)]
struct NativeSha256(
    /// Incremental SHA-256 state delegated to the SDK's stock Merkle implementation.
    Sha256,
);
impl tendermint::merkle::MerkleHash for NativeSha256 {
    /// Delegates the stock empty-root hash to the SDK implementation.
    fn empty_hash(&mut self) -> [u8; 32] {
        tendermint::merkle::MerkleHash::empty_hash(&mut self.0)
    }
    /// Delegates stock leaf-domain hashing to the SDK implementation.
    fn leaf_hash(&mut self, bytes: &[u8]) -> [u8; 32] {
        tendermint::merkle::MerkleHash::leaf_hash(&mut self.0, bytes)
    }
    /// Delegates stock inner-node-domain hashing to the SDK implementation.
    fn inner_hash(&mut self, left: [u8; 32], right: [u8; 32]) -> [u8; 32] {
        tendermint::merkle::MerkleHash::inner_hash(&mut self.0, left, right)
    }
}
impl tendermint::crypto::Sha256 for NativeSha256 {
    /// Hashes one complete SDK header/Merkle preimage with the existing SHA-256 dependency.
    fn digest(data: impl AsRef<[u8]>) -> [u8; 32] {
        <Sha256 as Digest>::digest(data).into()
    }
}

/// Stock SDK header hash without enabling unrelated SDK signature algorithms or std.
pub fn header_hash(header: &tendermint::block::Header) -> Hash {
    header.hash_with::<NativeSha256>()
}

/// Verify the native certificate against keys/powers bound by this header, independently of
/// where the historical set comes from.
/// The caller must independently authorize the supplied set for this height and generation.
///
/// A landing proof of (p,h] needs this only for the commit of h and of each block in (p,h)
/// whose successor a different committee signs; the last_block_id links of the other blocks
/// reach one of those (PROOF-6.2-16, PROOF-6.2-17). Any commit for the block's BlockID serves,
/// such as its successor's LastCommit.
pub fn verify_native_commit(
    commit: &Commit,
    header: &tendermint::block::Header,
    validators: &super::validators::Validators,
    chain_id: &str,
) -> Result<(), BftError> {
    if header.version.app != super::APP_VERSION {
        return Err(BftError::Certificate("unsupported Etna APP_VERSION".into()));
    }
    if header.chain_id.as_str() != chain_id || commit.height != header.height {
        return Err(BftError::Certificate("chain id or commit height mismatch".into()));
    }
    if commit.block_id.hash != header_hash(header) ||
        commit.block_id.part_set_header.total == 0 ||
        commit.block_id.part_set_header.hash == Hash::None
    {
        return Err(BftError::Certificate("commit block id mismatch or empty part set".into()));
    }
    if commit.signatures.len() != validators.validators().len() {
        return Err(BftError::Certificate("signature slots differ from validator count".into()));
    }
    if header.validators_hash != validators.hash() {
        return Err(BftError::Commitment("validator set"));
    }
    let mut signed_power = 0u128;
    let mut seen = BTreeSet::new();
    for (index, (sig, validator)) in
        commit.signatures.iter().zip(validators.validators()).enumerate()
    {
        let (address, timestamp, signature, is_commit) = match sig {
            CommitSig::BlockIdFlagAbsent => continue,
            CommitSig::BlockIdFlagCommit { validator_address, timestamp, signature } => {
                (*validator_address, *timestamp, signature.as_ref(), true)
            }
            CommitSig::BlockIdFlagNil { validator_address, timestamp, signature } => {
                (*validator_address, *timestamp, signature.as_ref(), false)
            }
        };
        if !seen.insert(address) || address != validator.address {
            return Err(BftError::Certificate(
                "duplicate signer or incorrect validator slot".into(),
            ));
        }
        let signature =
            signature.ok_or_else(|| BftError::Certificate("missing signature".into()))?;
        let vote = Vote {
            vote_type: Type::Precommit,
            height: commit.height,
            round: commit.round,
            block_id: is_commit.then_some(commit.block_id),
            timestamp: Some(timestamp),
            validator_address: address,
            validator_index: u32::try_from(index)
                .map_err(|_| BftError::Certificate("validator index overflow".into()))?
                .try_into()
                .map_err(|e| BftError::Certificate(format!("validator index: {e}")))?,
            signature: None,
            extension: Vec::new(),
            extension_signature: None,
        };
        let chain_id =
            chain_id.parse().map_err(|e| BftError::Certificate(format!("chain id: {e}")))?;
        let sign_bytes =
            Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(vote, chain_id));
        if !validator.pub_key.verify_signature(&sign_bytes, signature.as_bytes()) {
            return Err(BftError::Certificate(
                "native secp256k1eth signature verification failed".into(),
            ));
        }
        if is_commit {
            signed_power += u128::from(validator.power());
        }
    }
    let total = u128::from(validators.total_voting_power());
    if signed_power * 3 <= total * 2 {
        return Err(BftError::Certificate(format!(
            "insufficient commit power {signed_power}/{total}; require strictly more than 2/3"
        )));
    }
    Ok(())
}

/// Tendermint's simple Merkle root of byte slices, including the SHA-256 empty root.
fn merkle(items: &[Vec<u8>]) -> Hash {
    Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<sha2::Sha256>(items))
}

/// CometBFT `Data.Hash`: the simple Merkle root of the transactions' SHA-256 hashes.
pub fn data_hash(txs: &[Vec<u8>]) -> Hash {
    merkle(&txs.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>())
}

/// Commit hash binds the signature protobufs, as CometBFT `Commit.Hash` does.
pub fn commit_hash(commit: &Commit) -> Hash {
    merkle(
        &commit
            .signatures
            .iter()
            .cloned()
            .map(|s| RawCommitSig::from(s).encode_to_vec())
            .collect::<Vec<_>>(),
    )
}

/// Stock CometBFT's 64-KiB part commitment over the original block protobuf.
///
/// Never reconstruct this witness through the Tendermint domain adapter: that adapter changes
/// evidence powers, nil vote block ids and nested light-client validator set encodings.
/// Allocation is proportional to the encoding; callers must bound untrusted witness bytes.
pub fn block_parts(block: &RawBlock) -> Result<tendermint::block::parts::Header, BftError> {
    let bytes = block.encode_to_vec();
    if bytes.is_empty() {
        return Err(BftError::PartSetLength);
    }
    let parts = bytes.chunks(65_536).map(<[u8]>::to_vec).collect::<Vec<_>>();
    tendermint::block::parts::Header::new(
        u32::try_from(parts.len()).map_err(|_| BftError::PartSetLength)?,
        merkle(&parts),
    )
    .map_err(|_| BftError::PartSetLength)
}

/// Recomputes native body commitments and returns the single committed transaction unchanged.
/// Consensus ancestry must be empty at the authenticated origin + 1 and present thereafter.
///
/// This is also necessary for an already-landed checkpoint: a genuine certificate signs the
/// header's roots, not an arbitrary body an RPC response happens to return beside it.
///
/// The header's app_hash, which commits the validator state as well as the parent EL hash, is
/// not checked (PROOF-6.2-42).
pub fn verify_body_at_origin<'a>(
    pair: CertifiedBlockRef<'a>,
    expected_height: u64,
    origin_height: u64,
) -> Result<&'a [u8], BftError> {
    let block = &pair.block;
    if block.header.height.value() != expected_height {
        return Err(BftError::Certificate("requested block height mismatch".into()));
    }
    let first_height = origin_height
        .checked_add(1)
        .filter(|height| *height <= expected_height)
        .ok_or(BftError::Commitment("generation origin"))?;
    if block.header.data_hash != Some(data_hash(&block.data)) {
        return Err(BftError::Commitment("data"));
    }
    if block.header.evidence_hash.is_none() {
        return Err(BftError::Commitment("evidence"));
    }
    let raw = super::codec::checked_block_proto(pair.raw_block, block)?;
    let evidence = raw
        .evidence
        .as_ref()
        .into_iter()
        .flat_map(|list| &list.evidence)
        .map(|e| {
            // EvidenceList.Hash uses each concrete evidence's Bytes(), not the Evidence oneof.
            match e.sum.as_ref() {
                Some(RawEvidence::DuplicateVoteEvidence(e)) => Ok(e.encode_to_vec()),
                Some(RawEvidence::LightClientAttackEvidence(e)) => Ok(e.encode_to_vec()),
                None => Err(BftError::Certificate("missing evidence subtype".into())),
            }
        })
        .collect::<Result<Vec<_>, _>>()?;
    if block.header.evidence_hash != Some(merkle(&evidence)) {
        return Err(BftError::Commitment("evidence"));
    }
    if pair.commit.block_id.part_set_header != block_parts(&raw)? {
        return Err(BftError::Commitment("block part set"));
    }
    match &block.last_commit {
        None if expected_height == first_height => {
            if block.header.last_commit_hash != Some(merkle(&[])) ||
                block.header.last_block_id.is_some()
            {
                return Err(BftError::Commitment("genesis last commit"));
            }
        }
        Some(last) => {
            if expected_height.checked_sub(1) != Some(last.height.value()) ||
                block.header.last_block_id != Some(last.block_id) ||
                block.header.last_commit_hash != Some(commit_hash(last))
            {
                return Err(BftError::Commitment("last commit"));
            }
        }
        None => return Err(BftError::Commitment("missing last commit")),
    }
    let [transaction] = block.data.as_slice() else {
        return Err(BftError::TransactionCount(block.data.len()));
    };
    // Check the committed body before reporting forbidden generation-start ancestry.
    if expected_height == first_height && block.last_commit.is_some() {
        return Err(BftError::Commitment("missing or conflicting previous block/commit"));
    }
    Ok(transaction)
}

/// Verifies one body's commitments plus its BFT ancestry against the preceding certificate.
///
/// A previous pair may be absent only at origin + 1. Certificate verification remains a
/// separate operation using the independently authenticated set that signs.
pub fn verify_structure<'a>(
    pair: CertifiedBlockRef<'a>,
    previous: Option<CertifiedBlockRef<'_>>,
    expected_height: u64,
) -> Result<&'a [u8], BftError> {
    verify_structure_at_origin(pair, previous, expected_height, 0)
}

/// Verifies BFT ancestry with an empty LastCommit only at the authenticated generation start.
pub fn verify_structure_at_origin<'a>(
    pair: CertifiedBlockRef<'a>,
    previous: Option<CertifiedBlockRef<'_>>,
    expected_height: u64,
    origin_height: u64,
) -> Result<&'a [u8], BftError> {
    let envelope = verify_body_at_origin(pair, expected_height, origin_height)?;
    match (&pair.block.last_commit, previous) {
        (None, None) => {}
        (Some(last), Some(previous)) if last.block_id == previous.commit.block_id => {}
        _ => return Err(BftError::Commitment("missing or conflicting previous block/commit")),
    }
    Ok(envelope)
}
