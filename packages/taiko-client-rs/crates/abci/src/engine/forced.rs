//! EL confirmation of calldata forced-inclusion decisions.
//!
//! Only a canonical transaction
//! absent from a singleton build on the candidate's exact parent may be skipped. Callers own
//! timeouts and retry policy; no returned build is submitted or made canonical here.

use alloy_primitives::B256;

use super::{Engine, EngineError};
use crate::{
    forced::calldata::{ForcedDecision, decode_canonical},
    rules::{self, ExpectedHeader, RuleViolation},
};

/// Candidate context to preserve when checking whether the EL can include one transaction.
#[derive(Clone, Copy, Debug)]
pub struct ForcedBuildContext<'a> {
    /// Consensus-derived candidate fields, including the committed parent hash and anchor root.
    pub expected: &'a ExpectedHeader,
    /// Hash of the L1 anchor recorded in the build's L1 origin.
    pub anchor_hash: B256,
}

/// Why a forced decision cannot authorize consuming its queue entry.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum ForcedBuildError {
    /// The engine failed or returned an unusable or incomplete build result.
    #[error(transparent)]
    Engine(#[from] EngineError),
    /// The singleton result does not preserve the candidate's consensus-derived header.
    #[error(transparent)]
    Header(#[from] RuleViolation),
    /// The singleton build retained a transaction, so it does not prove a valid skip.
    #[error("singleton build retained a transaction")]
    Retained,
    /// A skip decision supplied bytes that are not exactly one canonical transaction.
    #[error("canonical skip decision contains invalid transaction bytes")]
    InvalidDecision,
}

/// Resolves an authenticated pure decision into the queue index consumed by this block.
///
/// A canonical skip requires a successful singleton build with the candidate's header and no
/// retained transactions. Every other decision needs no EL calls. Engine failures remain
/// errors, and this function neither retries nor submits or canonicalizes the singleton result.
pub async fn verify_forced<E: Engine + ?Sized>(
    engine: &E,
    context: ForcedBuildContext<'_>,
    decision: &ForcedDecision,
) -> Result<Option<u64>, ForcedBuildError> {
    match decision {
        ForcedDecision::Ordinary => Ok(None),
        ForcedDecision::Included(index) | ForcedDecision::SkippedInvalid(index) => Ok(Some(*index)),
        ForcedDecision::NeedsSkip { index, tx } => {
            let transaction = decode_canonical(tx).ok_or(ForcedBuildError::InvalidDecision)?;
            let tx_list = protocol::shasta::encode_transactions(&[transaction]);
            let attrs =
                rules::payload_attributes(context.expected, context.anchor_hash, Some(tx_list));
            let rebuilt = engine.build_block(context.expected.parent_hash, attrs).await?;
            rules::check_header(&rebuilt.header, context.expected)?;
            if !rebuilt.transactions.is_empty() {
                return Err(ForcedBuildError::Retained);
            }
            Ok(Some(*index))
        }
    }
}

#[cfg(test)]
mod tests {
    use alloy_consensus::Header;
    use alloy_eips::eip2718::Encodable2718;
    use alloy_primitives::{Address, Bytes, U256};

    use super::*;
    use crate::{
        envelope::ExecutionBlock,
        test_utils::{EngineCall, MockEngine, sample_transactions, simple_block},
    };

    fn expected_header() -> ExpectedHeader {
        ExpectedHeader {
            number: 42,
            parent_hash: B256::repeat_byte(0x11),
            timestamp: 1_000,
            beneficiary: Address::repeat_byte(0x22),
            extra_data: rules::encode_extra_data(7, 80).unwrap(),
            parent_beacon_block_root: B256::repeat_byte(0x33),
            gas_limit: 30_000_000,
            base_fee: 123,
            mix_hash: B256::repeat_byte(0x44),
        }
    }

    fn context(expected: &ExpectedHeader) -> ForcedBuildContext<'_> {
        ForcedBuildContext { expected, anchor_hash: B256::repeat_byte(0x55) }
    }

    fn needs_skip() -> ForcedDecision {
        ForcedDecision::NeedsSkip { index: 9, tx: sample_transactions()[0].encoded_2718().into() }
    }

    fn empty_build(expected: &ExpectedHeader) -> ExecutionBlock {
        simple_block(
            expected.parent_hash,
            &rules::payload_attributes(
                expected,
                context(expected).anchor_hash,
                Some(protocol::shasta::encode_transactions(&[])),
            ),
        )
    }

    fn assert_singleton_call(
        engine: &MockEngine,
        expected: &ExpectedHeader,
        decision: &ForcedDecision,
    ) {
        let ForcedDecision::NeedsSkip { tx, .. } = decision else { panic!("skip decision") };
        let calls = engine.calls();
        let [EngineCall::BuildBlock { parent, attrs }] = calls.as_slice() else {
            panic!("expected only one singleton build, got {calls:?}");
        };
        assert_eq!(*parent, expected.parent_hash);
        let eth = &attrs.payload_attributes;
        assert_eq!(eth.suggested_fee_recipient, expected.beneficiary);
        assert_eq!(eth.timestamp, expected.timestamp);
        assert_eq!(eth.prev_randao, expected.mix_hash);
        assert_eq!(eth.parent_beacon_block_root, Some(expected.parent_beacon_block_root));
        assert_eq!(attrs.block_metadata.beneficiary, expected.beneficiary);
        assert_eq!(attrs.block_metadata.gas_limit, expected.gas_limit);
        assert_eq!(attrs.block_metadata.extra_data, expected.extra_data);
        assert_eq!(attrs.base_fee_per_gas, U256::from(expected.base_fee));
        assert_eq!(attrs.l1_origin.block_id, U256::from(expected.number));
        assert_eq!(attrs.l1_origin.l1_block_hash, Some(context(expected).anchor_hash));
        assert_eq!(attrs.l1_origin.l1_block_height, Some(U256::from(80)));
        assert!(attrs.l1_origin.is_forced_inclusion);
        let provided: Vec<alloy_consensus::TxEnvelope> =
            alloy_rlp::decode_exact(attrs.block_metadata.tx_list.as_ref().expect("explicit list"))
                .unwrap();
        assert_eq!(provided.len(), 1);
        assert_eq!(provided[0].encoded_2718().as_slice(), tx.as_ref());
        assert_eq!(
            **attrs,
            rules::payload_attributes(
                expected,
                context(expected).anchor_hash,
                Some(protocol::shasta::encode_transactions(&provided))
            )
        );
    }

    #[tokio::test]
    async fn retained_forced_transaction_cannot_authorize_consumption() {
        let engine = MockEngine::new();
        let expected = expected_header();
        let decision = needs_skip();
        let mut retained = empty_build(&expected);
        let ForcedDecision::NeedsSkip { tx, .. } = &decision else { unreachable!() };
        retained.transactions.push(tx.clone());
        engine.state().build_script.push_back(Ok(retained));

        assert_eq!(
            verify_forced(&engine, context(&expected), &decision).await,
            Err(ForcedBuildError::Retained)
        );
        assert_singleton_call(&engine, &expected, &decision);
    }

    #[tokio::test]
    async fn empty_singleton_consumes_the_index_and_preserves_all_attributes() {
        for tx in sample_transactions() {
            let engine = MockEngine::new();
            // A populated pool must never be selected or included in a singleton probe.
            engine.state().pool = sample_transactions();
            let expected = expected_header();
            let decision = ForcedDecision::NeedsSkip { index: 9, tx: tx.encoded_2718().into() };
            engine.state().build_script.push_back(Ok(empty_build(&expected)));

            let engine_ref: &dyn Engine = &engine;
            assert_eq!(verify_forced(engine_ref, context(&expected), &decision).await, Ok(Some(9)));
            assert_singleton_call(&engine, &expected, &decision);
        }
    }

    #[tokio::test]
    async fn engine_failures_and_incomplete_results_do_not_authorize_consumption() {
        for error in [
            EngineError::Transport("connection reset".into()),
            EngineError::BuildNotStarted("SYNCING without payload id".into()),
            EngineError::BadReply("null payload".into()),
            EngineError::ErrorReply {
                call: "engine_getPayloadV5".into(),
                code: -32603,
                message: "internal error".into(),
            },
        ] {
            let engine = MockEngine::new();
            let expected = expected_header();
            let decision = needs_skip();
            engine.state().build_script.push_back(Err(error.clone()));
            assert_eq!(
                verify_forced(&engine, context(&expected), &decision).await,
                Err(ForcedBuildError::Engine(error))
            );
            assert_singleton_call(&engine, &expected, &decision);
        }
    }

    #[tokio::test]
    async fn decisions_without_canonical_skips_make_no_engine_calls() {
        for (decision, consumed) in [
            (ForcedDecision::Ordinary, None),
            (ForcedDecision::Included(9), Some(9)),
            (ForcedDecision::SkippedInvalid(9), Some(9)),
        ] {
            let engine = MockEngine::new();
            assert_eq!(
                verify_forced(&engine, context(&expected_header()), &decision).await,
                Ok(consumed)
            );
            assert!(engine.calls().is_empty());
        }
    }

    #[tokio::test]
    async fn invalid_skip_bytes_are_rejected_before_building() {
        let mut trailing = sample_transactions()[0].encoded_2718();
        trailing.push(0);
        for tx in [Bytes::new(), Bytes::from_static(&[0xff]), trailing.into()] {
            let engine = MockEngine::new();
            let decision = ForcedDecision::NeedsSkip { index: 9, tx };
            assert_eq!(
                verify_forced(&engine, context(&expected_header()), &decision).await,
                Err(ForcedBuildError::InvalidDecision)
            );
            assert!(engine.calls().is_empty());
        }
    }

    #[tokio::test]
    async fn empty_build_with_wrong_candidate_header_cannot_authorize_consumption() {
        type HeaderMutation = (&'static str, fn(&mut Header));
        let mutations: &[HeaderMutation] = &[
            ("number", |h| h.number += 1),
            ("parent_hash", |h| h.parent_hash = B256::ZERO),
            ("timestamp", |h| h.timestamp += 1),
            ("beneficiary", |h| h.beneficiary = Address::ZERO),
            ("extra_data", |h| h.extra_data = Bytes::new()),
            ("parent_beacon_block_root", |h| h.parent_beacon_block_root = None),
            ("gas_limit", |h| h.gas_limit += 1),
            ("base_fee_per_gas", |h| h.base_fee_per_gas = None),
            ("mix_hash", |h| h.mix_hash = B256::ZERO),
            ("withdrawals_root", |h| h.withdrawals_root = None),
        ];
        for (field, mutate) in mutations {
            let engine = MockEngine::new();
            let expected = expected_header();
            let decision = needs_skip();
            let mut block = empty_build(&expected);
            mutate(&mut block.header);
            engine.state().build_script.push_back(Ok(block));
            let result = verify_forced(&engine, context(&expected), &decision).await;
            assert!(
                matches!(result, Err(ForcedBuildError::Header(RuleViolation::HeaderField { field: got, .. })) if got == *field),
                "wrong {field}: {result:?}"
            );
            assert_singleton_call(&engine, &expected, &decision);
        }
    }

    #[tokio::test]
    async fn any_retained_transaction_cannot_authorize_consumption() {
        let engine = MockEngine::new();
        let expected = expected_header();
        let decision = needs_skip();
        let mut block = empty_build(&expected);
        block.transactions.push(sample_transactions()[1].encoded_2718().into());
        engine.state().build_script.push_back(Ok(block));
        assert_eq!(
            verify_forced(&engine, context(&expected), &decision).await,
            Err(ForcedBuildError::Retained)
        );
        assert_singleton_call(&engine, &expected, &decision);
    }
}
