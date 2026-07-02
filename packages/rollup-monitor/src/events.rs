use std::collections::{HashMap, HashSet};

use alloy::primitives::{Address, B256, U256};
use alloy::rpc::types::Log as RpcLog;
use alloy::sol_types::SolEvent;
use tracing::warn;

use crate::bindings;
use crate::config::Config;
use crate::metrics;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObservedEvent {
    Prover { prover: Address },
    Proposer { proposer: Address },
    Withdrawal { target: String, token: Address, recipient: Address, amount_wei: U256 },
    Pause { target: String, paused: bool },
    ProxyUpgrade { target: String, proxy: Address, implementation: Address },
    OwnershipTransfer { target: String, previous_owner: Address, new_owner: Address },
    RoleChange { target: String, role: B256, account: Address, action: RoleAction },
    SafeTransaction { safe: String, operation: SafeOperation },
    VerifierChange { target: String, verifier: B256 },
    SgxInstanceChange { instance: Address, reason: SgxReason },
    UnexpectedEoaTransaction { signer: Address, to: Option<Address> },
    ProposalReorg { proposal_id: u64 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Alert {
    NonWhitelistedProver {
        prover: Address,
    },
    NonWhitelistedProposer {
        proposer: Address,
    },
    LargeWithdrawal {
        target: String,
        token: Address,
        recipient: Address,
        amount_wei: U256,
        threshold_wei: u128,
    },
    PauseEvent {
        target: String,
        action: &'static str,
    },
    ProxyUpgrade {
        target: String,
        proxy: Address,
        implementation: Address,
        expected: bool,
    },
    OwnershipTransfer {
        target: String,
        previous_owner: Address,
        new_owner: Address,
        expected: bool,
    },
    RoleChange {
        target: String,
        role: B256,
        account: Address,
        action: RoleAction,
    },
    SafeTransaction {
        safe: String,
        operation: SafeOperation,
    },
    VerifierChange {
        target: String,
        verifier: B256,
        expected: bool,
    },
    SgxAnomaly {
        instance: Address,
        reason: SgxReason,
    },
    UnexpectedEoaTransaction {
        signer: Address,
        to: Option<Address>,
        allowed: bool,
    },
    ProposalReorg {
        proposal_id: u64,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RoleAction {
    Granted,
    Revoked,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SafeOperation {
    Success,
    Failure,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SgxReason {
    InstanceAdded,
    InstanceDeleted,
}

pub fn classify_event(config: &Config, event: &ObservedEvent) -> Option<Alert> {
    match event {
        ObservedEvent::Prover { prover } => {
            if config.allowed_provers.contains(prover) {
                return None;
            }

            Some(Alert::NonWhitelistedProver { prover: *prover })
        }
        ObservedEvent::Proposer { proposer } => {
            if config.allowed_proposers.contains(proposer) {
                return None;
            }

            Some(Alert::NonWhitelistedProposer { proposer: *proposer })
        }
        ObservedEvent::Withdrawal { target, token, recipient, amount_wei } => {
            let threshold = config.withdrawal_thresholds_wei.get(target)?;
            if *amount_wei <= U256::from(*threshold) {
                return None;
            }

            Some(Alert::LargeWithdrawal {
                target: target.clone(),
                token: *token,
                recipient: *recipient,
                amount_wei: *amount_wei,
                threshold_wei: *threshold,
            })
        }
        ObservedEvent::Pause { target, paused } => Some(Alert::PauseEvent {
            target: target.clone(),
            action: if *paused { "paused" } else { "unpaused" },
        }),
        ObservedEvent::ProxyUpgrade { target, proxy, implementation } => {
            let expected = config
                .expected_proxy_implementations
                .get(target)
                .is_some_and(|expected| expected == implementation);
            Some(Alert::ProxyUpgrade {
                target: target.clone(),
                proxy: *proxy,
                implementation: *implementation,
                expected,
            })
        }
        ObservedEvent::OwnershipTransfer { target, previous_owner, new_owner } => {
            let expected =
                config.expected_owners.get(target).is_some_and(|expected| expected == new_owner);
            Some(Alert::OwnershipTransfer {
                target: target.clone(),
                previous_owner: *previous_owner,
                new_owner: *new_owner,
                expected,
            })
        }
        ObservedEvent::RoleChange { target, role, account, action } => Some(Alert::RoleChange {
            target: target.clone(),
            role: *role,
            account: *account,
            action: *action,
        }),
        ObservedEvent::SafeTransaction { safe, operation } => {
            Some(Alert::SafeTransaction { safe: safe.clone(), operation: *operation })
        }
        ObservedEvent::VerifierChange { target, verifier } => {
            let expected = config
                .expected_verifiers
                .get(target)
                .is_some_and(|expected| expected.contains(verifier));
            Some(Alert::VerifierChange { target: target.clone(), verifier: *verifier, expected })
        }
        ObservedEvent::SgxInstanceChange { instance, reason } => {
            Some(Alert::SgxAnomaly { instance: *instance, reason: *reason })
        }
        ObservedEvent::UnexpectedEoaTransaction { signer, to } => {
            let allowed = to.is_some_and(|to| config.allowed_eoa_destinations.contains(&to));
            if allowed {
                return None;
            }

            Some(Alert::UnexpectedEoaTransaction { signer: *signer, to: *to, allowed })
        }
        ObservedEvent::ProposalReorg { proposal_id } => {
            Some(Alert::ProposalReorg { proposal_id: *proposal_id })
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProposalObservation {
    pub proposal_id: u64,
    pub block_hash: Option<B256>,
    pub tx_hash: Option<B256>,
}

#[derive(Default, Debug)]
pub struct ProposalTracker {
    seen: HashMap<u64, ProposalObservation>,
}

impl ProposalTracker {
    pub fn observe(&mut self, observation: ProposalObservation) -> Option<ObservedEvent> {
        let proposal_id = observation.proposal_id;
        if let Some(previous) = self.seen.get(&proposal_id)
            && (previous.block_hash != observation.block_hash
                || previous.tx_hash != observation.tx_hash)
        {
            self.seen.insert(proposal_id, observation);
            return Some(ObservedEvent::ProposalReorg { proposal_id });
        }

        self.seen.insert(proposal_id, observation);
        None
    }
}

pub fn classify_eoa_transaction(
    watched_eoas: &HashSet<Address>,
    signer: Address,
    to: Option<Address>,
) -> Option<ObservedEvent> {
    watched_eoas.contains(&signer).then_some(ObservedEvent::UnexpectedEoaTransaction { signer, to })
}

pub fn decode_contract_log(target: &str, log: &RpcLog) -> Vec<ObservedEvent> {
    decode_contract_log_for_chain("l1", target, log)
}

pub fn decode_contract_log_for_chain(
    chain: &str,
    target: &str,
    log: &RpcLog,
) -> Vec<ObservedEvent> {
    let mut events = Vec::new();

    decode_matched::<bindings::Proposed, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::Proposer { proposer: decoded.proposer }
    });
    decode_matched::<bindings::Proved, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::Prover { prover: decoded.actualProver }
    });
    decode_matched::<bindings::TokenSent, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::Withdrawal {
            target: target.to_string(),
            token: decoded.ctoken,
            recipient: decoded.to,
            amount_wei: decoded.amount,
        }
    });
    decode_matched::<bindings::TokenReleased, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::Withdrawal {
            target: target.to_string(),
            token: decoded.ctoken,
            recipient: decoded.from,
            amount_wei: decoded.amount,
        }
    });
    decode_matched::<bindings::Paused, _>(chain, target, log, &mut events, |_| {
        ObservedEvent::Pause { target: target.to_string(), paused: true }
    });
    decode_matched::<bindings::Unpaused, _>(chain, target, log, &mut events, |_| {
        ObservedEvent::Pause { target: target.to_string(), paused: false }
    });
    decode_matched::<bindings::Upgraded, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::ProxyUpgrade {
            target: target.to_string(),
            proxy: log.address(),
            implementation: decoded.implementation,
        }
    });
    decode_matched::<bindings::OwnershipTransferred, _>(
        chain,
        target,
        log,
        &mut events,
        |decoded| ObservedEvent::OwnershipTransfer {
            target: target.to_string(),
            previous_owner: decoded.previousOwner,
            new_owner: decoded.newOwner,
        },
    );
    decode_matched::<bindings::RoleGranted, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::RoleChange {
            target: target.to_string(),
            role: decoded.role,
            account: decoded.account,
            action: RoleAction::Granted,
        }
    });
    decode_matched::<bindings::RoleRevoked, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::RoleChange {
            target: target.to_string(),
            role: decoded.role,
            account: decoded.account,
            action: RoleAction::Revoked,
        }
    });
    decode_matched::<bindings::ExecutionSuccess, _>(chain, target, log, &mut events, |_| {
        ObservedEvent::SafeTransaction {
            safe: target.to_string(),
            operation: SafeOperation::Success,
        }
    });
    decode_matched::<bindings::ExecutionFailure, _>(chain, target, log, &mut events, |_| {
        ObservedEvent::SafeTransaction {
            safe: target.to_string(),
            operation: SafeOperation::Failure,
        }
    });
    decode_matched::<bindings::ImageTrusted, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::VerifierChange { target: target.to_string(), verifier: decoded.imageId }
    });
    decode_matched::<bindings::ProgramTrusted, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::VerifierChange { target: target.to_string(), verifier: decoded.programVKey }
    });
    decode_matched::<bindings::InstanceAdded, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::SgxInstanceChange {
            instance: decoded.instance,
            reason: SgxReason::InstanceAdded,
        }
    });
    decode_matched::<bindings::InstanceDeleted, _>(chain, target, log, &mut events, |decoded| {
        ObservedEvent::SgxInstanceChange {
            instance: decoded.instance,
            reason: SgxReason::InstanceDeleted,
        }
    });

    events
}

fn decode_matched<E, F>(
    chain: &str,
    target: &str,
    log: &RpcLog,
    events: &mut Vec<ObservedEvent>,
    map: F,
) where
    E: SolEvent,
    F: FnOnce(E) -> ObservedEvent,
{
    if log.topics().first().copied() != Some(E::SIGNATURE_HASH) {
        return;
    }

    match log.log_decode::<E>() {
        Ok(decoded) => events.push(map(decoded.inner.data)),
        Err(error) => {
            warn!(
                target,
                event = E::SIGNATURE,
                error = %error,
                "failed to decode known rollup monitor event"
            );
            metrics::inc_scan_error(chain, "decode");
        }
    }
}

pub fn proposal_observation_from_log(log: &RpcLog) -> Option<ProposalObservation> {
    let decoded = log.log_decode::<bindings::Proposed>().ok()?;
    Some(ProposalObservation {
        proposal_id: decoded.inner.data.id.to::<u64>(),
        block_hash: log.block_hash,
        tx_hash: log.transaction_hash,
    })
}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use alloy::primitives::{Address, B256, Bytes, Log as PrimitiveLog, LogData, U256, Uint};
    use alloy::rpc::types::Log as RpcLog;
    use alloy::sol_types::SolEvent;
    use clap::Parser;

    use super::{
        Alert, ObservedEvent, ProposalObservation, ProposalTracker, RoleAction, SafeOperation,
        SgxReason, classify_eoa_transaction, classify_event, decode_contract_log,
        proposal_observation_from_log,
    };
    use crate::{bindings, config::Config};

    fn addr(value: &str) -> Address {
        Address::from_str(value).expect("test address should parse")
    }

    fn u48(value: u64) -> Uint<48, 1> {
        Uint::<48, 1>::from(value)
    }

    fn config(args: &[&str]) -> Config {
        let mut full_args = vec!["rollup-monitor", "--l1-http-url", "http://localhost:8545"];
        full_args.extend_from_slice(args);
        Config::parse_from(full_args)
    }

    fn rpc_log<E: SolEvent>(address: Address, event: E) -> RpcLog {
        RpcLog {
            inner: E::encode_log(&PrimitiveLog { address, data: event }),
            block_hash: Some(B256::repeat_byte(0xaa)),
            block_number: Some(100),
            block_timestamp: None,
            transaction_hash: Some(B256::repeat_byte(0xbb)),
            transaction_index: Some(1),
            log_index: Some(2),
            removed: false,
        }
    }

    fn raw_log(address: Address, topics: Vec<B256>, data: Vec<u8>) -> RpcLog {
        RpcLog {
            inner: PrimitiveLog {
                address,
                data: LogData::new_unchecked(topics, Bytes::from(data)),
            },
            block_hash: Some(B256::repeat_byte(0xaa)),
            block_number: Some(100),
            block_timestamp: None,
            transaction_hash: Some(B256::repeat_byte(0xbb)),
            transaction_index: Some(1),
            log_index: Some(2),
            removed: false,
        }
    }

    #[test]
    fn ignores_whitelisted_prover() {
        let prover = "0x0000000000000000000000000000000000000001";
        let config = config(&["--allowed-provers", prover]);

        let alert = classify_event(&config, &ObservedEvent::Prover { prover: addr(prover) });

        assert_eq!(alert, None);
    }

    #[test]
    fn alerts_on_non_whitelisted_prover() {
        let prover = addr("0x0000000000000000000000000000000000000002");
        let config = config(&["--allowed-provers", "0x0000000000000000000000000000000000000001"]);

        let alert = classify_event(&config, &ObservedEvent::Prover { prover });

        assert_eq!(alert, Some(Alert::NonWhitelistedProver { prover }));
    }

    #[test]
    fn alerts_on_non_whitelisted_proposer() {
        let proposer = addr("0x0000000000000000000000000000000000000003");
        let config = config(&["--allowed-proposers", "0x0000000000000000000000000000000000000001"]);

        let alert = classify_event(&config, &ObservedEvent::Proposer { proposer });

        assert_eq!(alert, Some(Alert::NonWhitelistedProposer { proposer }));
    }

    #[test]
    fn alerts_on_large_withdrawal() {
        let token = addr("0x0000000000000000000000000000000000000004");
        let recipient = addr("0x0000000000000000000000000000000000000005");
        let config = config(&["--withdrawal-thresholds-wei", "bridge=100"]);

        let alert = classify_event(
            &config,
            &ObservedEvent::Withdrawal {
                target: "bridge".to_string(),
                token,
                recipient,
                amount_wei: U256::from(101u64),
            },
        );

        assert_eq!(
            alert,
            Some(Alert::LargeWithdrawal {
                target: "bridge".to_string(),
                token,
                recipient,
                amount_wei: U256::from(101u64),
                threshold_wei: 100,
            })
        );
    }

    #[test]
    fn ignores_withdrawal_at_threshold() {
        let config = config(&["--withdrawal-thresholds-wei", "bridge=100"]);

        let alert = classify_event(
            &config,
            &ObservedEvent::Withdrawal {
                target: "bridge".to_string(),
                token: Address::ZERO,
                recipient: Address::ZERO,
                amount_wei: U256::from(100u64),
            },
        );

        assert_eq!(alert, None);
    }

    #[test]
    fn emits_pause_event_alert() {
        let config = config(&[]);

        let alert = classify_event(
            &config,
            &ObservedEvent::Pause { target: "bridge".to_string(), paused: true },
        );

        assert_eq!(
            alert,
            Some(Alert::PauseEvent { target: "bridge".to_string(), action: "paused" })
        );
    }

    #[test]
    fn alerts_on_proxy_upgrade_and_marks_expected_implementation() {
        let proxy = addr("0x0000000000000000000000000000000000000010");
        let implementation = addr("0x0000000000000000000000000000000000000011");
        let config = config(&[
            "--expected-proxy-implementations",
            "inbox=0x0000000000000000000000000000000000000011",
        ]);

        let alert = classify_event(
            &config,
            &ObservedEvent::ProxyUpgrade { target: "inbox".to_string(), proxy, implementation },
        );

        assert_eq!(
            alert,
            Some(Alert::ProxyUpgrade {
                target: "inbox".to_string(),
                proxy,
                implementation,
                expected: true,
            })
        );
    }

    #[test]
    fn alerts_on_ownership_transfer() {
        let previous_owner = addr("0x0000000000000000000000000000000000000012");
        let new_owner = addr("0x0000000000000000000000000000000000000013");
        let config = config(&[
            "--expected-owners",
            "proxy_admin=0x0000000000000000000000000000000000000013",
        ]);

        let alert = classify_event(
            &config,
            &ObservedEvent::OwnershipTransfer {
                target: "proxy_admin".to_string(),
                previous_owner,
                new_owner,
            },
        );

        assert_eq!(
            alert,
            Some(Alert::OwnershipTransfer {
                target: "proxy_admin".to_string(),
                previous_owner,
                new_owner,
                expected: true,
            })
        );
    }

    #[test]
    fn alerts_on_role_change() {
        let role = B256::repeat_byte(0x7a);
        let account = addr("0x0000000000000000000000000000000000000014");
        let config = config(&[]);

        let alert = classify_event(
            &config,
            &ObservedEvent::RoleChange {
                target: "bridge".to_string(),
                role,
                account,
                action: RoleAction::Granted,
            },
        );

        assert_eq!(
            alert,
            Some(Alert::RoleChange {
                target: "bridge".to_string(),
                role,
                account,
                action: RoleAction::Granted,
            })
        );
    }

    #[test]
    fn alerts_on_safe_transaction() {
        let config = config(&[]);

        let alert = classify_event(
            &config,
            &ObservedEvent::SafeTransaction {
                safe: "guardian_safe".to_string(),
                operation: SafeOperation::Success,
            },
        );

        assert_eq!(
            alert,
            Some(Alert::SafeTransaction {
                safe: "guardian_safe".to_string(),
                operation: SafeOperation::Success,
            })
        );
    }

    #[test]
    fn alerts_on_verifier_change_and_marks_expected() {
        let verifier = B256::repeat_byte(0x80);
        let config = config(&[
            "--expected-verifiers",
            "risc0_verifier=0x8080808080808080808080808080808080808080808080808080808080808080",
        ]);

        let alert = classify_event(
            &config,
            &ObservedEvent::VerifierChange { target: "risc0_verifier".to_string(), verifier },
        );

        assert_eq!(
            alert,
            Some(Alert::VerifierChange {
                target: "risc0_verifier".to_string(),
                verifier,
                expected: true,
            })
        );
    }

    #[test]
    fn alerts_on_sgx_instance_change() {
        let instance = addr("0x0000000000000000000000000000000000000015");
        let config = config(&[]);

        let alert = classify_event(
            &config,
            &ObservedEvent::SgxInstanceChange { instance, reason: SgxReason::InstanceDeleted },
        );

        assert_eq!(alert, Some(Alert::SgxAnomaly { instance, reason: SgxReason::InstanceDeleted }));
    }

    #[test]
    fn alerts_on_watched_eoa_transaction_to_unapproved_destination() {
        let signer = addr("0x0000000000000000000000000000000000000016");
        let to = addr("0x0000000000000000000000000000000000000017");
        let config = config(&[
            "--watched-eoas",
            "0x0000000000000000000000000000000000000016",
            "--allowed-eoa-destinations",
            "0x0000000000000000000000000000000000000018",
        ]);
        let event = classify_eoa_transaction(&config.watched_eoas, signer, Some(to))
            .expect("watched signer should produce event");

        let alert = classify_event(&config, &event);

        assert_eq!(
            alert,
            Some(Alert::UnexpectedEoaTransaction { signer, to: Some(to), allowed: false })
        );
    }

    #[test]
    fn ignores_watched_eoa_transaction_to_allowed_destination() {
        let signer = addr("0x0000000000000000000000000000000000000019");
        let to = addr("0x0000000000000000000000000000000000000020");
        let config = config(&[
            "--watched-eoas",
            "0x0000000000000000000000000000000000000019",
            "--allowed-eoa-destinations",
            "0x0000000000000000000000000000000000000020",
        ]);
        let event = classify_eoa_transaction(&config.watched_eoas, signer, Some(to))
            .expect("watched signer should produce event");

        let alert = classify_event(&config, &event);

        assert_eq!(alert, None);
    }

    #[test]
    fn detects_proposal_reorg_when_seen_proposal_moves() {
        let mut tracker = ProposalTracker::default();
        let first = ProposalObservation {
            proposal_id: 42,
            block_hash: Some(B256::repeat_byte(0x01)),
            tx_hash: Some(B256::repeat_byte(0x02)),
        };
        let replacement = ProposalObservation {
            proposal_id: 42,
            block_hash: Some(B256::repeat_byte(0x03)),
            tx_hash: Some(B256::repeat_byte(0x04)),
        };

        assert_eq!(tracker.observe(first), None);
        assert_eq!(
            tracker.observe(replacement),
            Some(ObservedEvent::ProposalReorg { proposal_id: 42 })
        );
    }

    #[test]
    fn decodes_inbox_proposed_log_to_proposer_event_and_proposal_observation() {
        let inbox = addr("0x0000000000000000000000000000000000000021");
        let proposer = addr("0x0000000000000000000000000000000000000022");
        let log = rpc_log(
            inbox,
            bindings::Proposed {
                id: u48(7),
                proposer,
                parentProposalHash: B256::ZERO,
                endOfSubmissionWindowTimestamp: u48(0),
                basefeeSharingPctg: 0,
                sources: Vec::new(),
            },
        );

        let events = decode_contract_log("inbox", &log);
        let proposal = proposal_observation_from_log(&log);

        assert_eq!(events, vec![ObservedEvent::Proposer { proposer }]);
        assert_eq!(
            proposal,
            Some(ProposalObservation {
                proposal_id: 7,
                block_hash: Some(B256::repeat_byte(0xaa)),
                tx_hash: Some(B256::repeat_byte(0xbb)),
            })
        );
    }

    #[test]
    fn decodes_inbox_proved_log_to_prover_event() {
        let inbox = addr("0x0000000000000000000000000000000000000023");
        let prover = addr("0x0000000000000000000000000000000000000024");
        let log = rpc_log(
            inbox,
            bindings::Proved {
                firstProposalId: u48(1),
                firstNewProposalId: u48(1),
                lastProposalId: u48(2),
                actualProver: prover,
            },
        );

        let events = decode_contract_log("inbox", &log);

        assert_eq!(events, vec![ObservedEvent::Prover { prover }]);
    }

    #[test]
    fn decodes_erc20_token_sent_log_to_withdrawal_event() {
        let vault = addr("0x0000000000000000000000000000000000000025");
        let from = addr("0x0000000000000000000000000000000000000026");
        let to = addr("0x0000000000000000000000000000000000000027");
        let ctoken = addr("0x0000000000000000000000000000000000000028");
        let token = addr("0x0000000000000000000000000000000000000029");
        let log = rpc_log(
            vault,
            bindings::TokenSent {
                msgHash: B256::repeat_byte(0x01),
                from,
                to,
                canonicalChainId: 1,
                destChainId: 167000,
                ctoken,
                token,
                amount: U256::from(500u64),
            },
        );

        let events = decode_contract_log("erc20_vault", &log);

        assert_eq!(
            events,
            vec![ObservedEvent::Withdrawal {
                target: "erc20_vault".to_string(),
                token: ctoken,
                recipient: to,
                amount_wei: U256::from(500u64),
            }]
        );
    }

    #[test]
    fn decodes_common_security_events() {
        let proxy = addr("0x0000000000000000000000000000000000000030");
        let implementation = addr("0x0000000000000000000000000000000000000031");
        let account = addr("0x0000000000000000000000000000000000000032");
        let role = B256::repeat_byte(0x99);

        assert_eq!(
            decode_contract_log("inbox", &rpc_log(proxy, bindings::Upgraded { implementation })),
            vec![ObservedEvent::ProxyUpgrade {
                target: "inbox".to_string(),
                proxy,
                implementation,
            }]
        );
        assert_eq!(
            decode_contract_log("bridge", &rpc_log(proxy, bindings::Paused { account })),
            vec![ObservedEvent::Pause { target: "bridge".to_string(), paused: true }]
        );
        assert_eq!(
            decode_contract_log(
                "bridge",
                &rpc_log(proxy, bindings::RoleGranted { role, account, sender: Address::ZERO },),
            ),
            vec![ObservedEvent::RoleChange {
                target: "bridge".to_string(),
                role,
                account,
                action: RoleAction::Granted,
            }]
        );
    }

    #[test]
    fn decodes_verifier_proxy_upgrade_only_as_proxy_upgrade() {
        let proxy = addr("0x0000000000000000000000000000000000000030");
        let implementation = addr("0x0000000000000000000000000000000000000031");

        assert_eq!(
            decode_contract_log(
                "risc0_verifier",
                &rpc_log(proxy, bindings::Upgraded { implementation }),
            ),
            vec![ObservedEvent::ProxyUpgrade {
                target: "risc0_verifier".to_string(),
                proxy,
                implementation,
            }]
        );
    }

    #[test]
    fn decodes_safe_verifier_and_sgx_events() {
        let safe = addr("0x0000000000000000000000000000000000000033");
        let verifier = addr("0x0000000000000000000000000000000000000034");
        let sgx = addr("0x0000000000000000000000000000000000000035");
        let image_id = B256::repeat_byte(0x44);
        let instance = addr("0x0000000000000000000000000000000000000036");

        assert_eq!(
            decode_contract_log(
                "guardian_safe",
                &rpc_log(
                    safe,
                    bindings::ExecutionSuccess {
                        txHash: B256::repeat_byte(0x55),
                        payment: U256::ZERO,
                    },
                ),
            ),
            vec![ObservedEvent::SafeTransaction {
                safe: "guardian_safe".to_string(),
                operation: SafeOperation::Success,
            }]
        );
        assert_eq!(
            decode_contract_log(
                "risc0_verifier",
                &rpc_log(verifier, bindings::ImageTrusted { imageId: image_id, trusted: true }),
            ),
            vec![ObservedEvent::VerifierChange {
                target: "risc0_verifier".to_string(),
                verifier: image_id,
            }]
        );
        assert_eq!(
            decode_contract_log(
                "sgx_verifier",
                &rpc_log(sgx, bindings::InstanceDeleted { id: U256::from(1u64), instance },),
            ),
            vec![ObservedEvent::SgxInstanceChange { instance, reason: SgxReason::InstanceDeleted }]
        );
    }

    #[test]
    fn decodes_real_safe_execution_success_with_indexed_tx_hash() {
        let safe = addr("0x0000000000000000000000000000000000000033");
        let log = raw_log(
            safe,
            vec![bindings::ExecutionSuccess::SIGNATURE_HASH, B256::repeat_byte(0x55)],
            vec![0; 32],
        );

        assert_eq!(
            decode_contract_log("guardian_safe", &log),
            vec![ObservedEvent::SafeTransaction {
                safe: "guardian_safe".to_string(),
                operation: SafeOperation::Success,
            }]
        );
    }

    #[test]
    fn decodes_real_safe_execution_failure_with_indexed_tx_hash() {
        let safe = addr("0x0000000000000000000000000000000000000033");
        let log = raw_log(
            safe,
            vec![bindings::ExecutionFailure::SIGNATURE_HASH, B256::repeat_byte(0x55)],
            vec![0; 32],
        );

        assert_eq!(
            decode_contract_log("guardian_safe", &log),
            vec![ObservedEvent::SafeTransaction {
                safe: "guardian_safe".to_string(),
                operation: SafeOperation::Failure,
            }]
        );
    }
}
