use std::time::Duration;

use alloy::consensus::Transaction as TransactionTrait;
use alloy::network::Ethereum;
use alloy::primitives::Address;
use alloy::providers::{Provider, ProviderBuilder};
use alloy::rpc::types::{BlockNumberOrTag, Filter, Log as RpcLog};
use eyre::Result;
use tokio::time;
use tracing::{info, warn};
use url::Url;

use crate::{
    config::Config,
    events::{
        Alert, ObservedEvent, ProposalTracker, RoleAction, SafeOperation, SgxReason,
        classify_eoa_transaction, classify_event, decode_contract_log,
        proposal_observation_from_log,
    },
    metrics,
    scanner::{LogKey, ScanCursor, SeenLogCache, chunk_ranges},
};

pub struct RollupMonitor {
    config: Config,
    l1_cursor: ScanCursor,
    seen_logs: SeenLogCache,
    proposals: ProposalTracker,
}

impl RollupMonitor {
    pub fn new(config: Config) -> Self {
        let l1_cursor =
            ScanCursor::new(config.start_block, config.start_block_lookback, config.overlap_blocks);
        let seen_logs = SeenLogCache::new(config.seen_log_cache_size);
        Self { config, l1_cursor, seen_logs, proposals: ProposalTracker::default() }
    }

    pub async fn run(mut self) -> Result<()> {
        let l1_url = Url::parse(&self.config.l1_http_url).map_err(|error| {
            eyre::eyre!("invalid L1_HTTP_URL '{}': {error}", self.config.l1_http_url)
        })?;
        let l1_provider = ProviderBuilder::new().connect_http(l1_url);
        let l1_chain_id = match l1_provider.get_chain_id().await {
            Ok(chain_id) => chain_id,
            Err(error) => {
                warn!("failed to fetch L1 chain ID: {error}");
                0
            }
        };
        let mut interval = time::interval(Duration::from_secs(self.config.poll_interval_seconds));

        info!("rollup monitor polling L1 HTTP RPC {}", self.config.l1_http_url);

        loop {
            interval.tick().await;
            match l1_provider.get_block_number().await {
                Ok(latest_block) => {
                    if let Err(error) = self
                        .execute_l1_cycle_with_provider(&l1_provider, l1_chain_id, latest_block)
                        .await
                    {
                        warn!("failed to execute L1 rollup monitor cycle: {error}");
                        metrics::inc_scan_error("l1", "cycle");
                    }
                }
                Err(error) => {
                    warn!("failed to fetch L1 block number: {error}");
                    metrics::inc_scan_error("l1", "block_number");
                }
            }
        }
    }

    fn next_l1_scan_range(&self, latest_block: u64) -> Option<(u64, u64)> {
        self.l1_cursor.next_range(latest_block, self.config.confirmations)
    }

    pub async fn execute_l1_cycle_with_provider<P>(
        &mut self,
        provider: &P,
        chain_id: u64,
        latest_block: u64,
    ) -> Result<()>
    where
        P: Provider<Ethereum>,
    {
        let Some((from_block, safe_head)) = self.next_l1_scan_range(latest_block) else {
            return Ok(());
        };

        info!(from_block, safe_head, "scanning L1 rollup monitor range");
        for (chunk_from, chunk_to) in
            chunk_ranges(from_block, safe_head, self.config.max_block_range)
        {
            self.scan_contract_logs(provider, chain_id, chunk_from, chunk_to).await?;
            if let Some((eoa_from, eoa_to)) = self.eoa_scan_range(chunk_from, chunk_to) {
                self.scan_eoa_transactions(provider, eoa_from, eoa_to).await?;
            }
        }

        self.l1_cursor.mark_scanned(safe_head);
        metrics::set_scan_position("l1", safe_head, safe_head);
        Ok(())
    }

    async fn scan_contract_logs<P>(
        &mut self,
        provider: &P,
        chain_id: u64,
        from_block: u64,
        to_block: u64,
    ) -> Result<()>
    where
        P: Provider<Ethereum>,
    {
        if self.config.watched_contracts.is_empty() {
            return Ok(());
        }

        let addresses = self.config.watched_contracts.values().copied().collect::<Vec<_>>();
        let filter = Filter::new().address(addresses).from_block(from_block).to_block(to_block);
        let logs = provider.get_logs(&filter).await?;

        for log in logs {
            let Some(target) = self.contract_name(log.address()) else {
                continue;
            };
            self.process_log("l1", chain_id, target.as_str(), &log);
        }

        Ok(())
    }

    async fn scan_eoa_transactions<P>(
        &self,
        provider: &P,
        from_block: u64,
        to_block: u64,
    ) -> Result<()>
    where
        P: Provider<Ethereum>,
    {
        if self.config.watched_eoas.is_empty() {
            return Ok(());
        }

        for block_number in from_block..=to_block {
            let Some(block) =
                provider.get_block_by_number(BlockNumberOrTag::Number(block_number)).full().await?
            else {
                metrics::inc_scan_error("l1", "block_missing");
                continue;
            };

            for tx in block.into_transactions_vec() {
                let signer = tx.inner.signer();
                let to = tx.inner.inner().to();
                self.process_eoa_transaction("l1", signer, to);
            }
        }

        Ok(())
    }

    fn contract_name(&self, address: Address) -> Option<String> {
        self.config
            .watched_contracts
            .iter()
            .find_map(|(name, candidate)| (*candidate == address).then(|| name.clone()))
    }

    pub fn eoa_scan_range(&self, from_block: u64, to_block: u64) -> Option<(u64, u64)> {
        if !self.config.eoa_scan_enabled
            || self.config.watched_eoas.is_empty()
            || from_block > to_block
        {
            return None;
        }

        let max_blocks = self.config.eoa_scan_max_block_range.max(1);
        let span = to_block - from_block + 1;
        let limited_from =
            if span > max_blocks { to_block.saturating_sub(max_blocks - 1) } else { from_block };

        Some((limited_from, to_block))
    }

    pub fn classify_and_record(&self, chain: &str, event: &ObservedEvent) -> Option<Alert> {
        let alert = classify_event(&self.config, event)?;
        record_alert(chain, &alert);
        Some(alert)
    }

    pub fn process_log(&mut self, chain: &str, chain_id: u64, target: &str, log: &RpcLog) -> usize {
        if let (Some(tx_hash), Some(log_index)) = (log.transaction_hash, log.log_index) {
            let key = LogKey { chain_id, tx_hash, log_index };
            if !self.seen_logs.insert(key) {
                return 0;
            }
        }

        let mut recorded = 0;
        if let Some(observation) = proposal_observation_from_log(log)
            && let Some(event) = self.proposals.observe(observation)
        {
            recorded += usize::from(self.classify_and_record(chain, &event).is_some());
        }

        for event in decode_contract_log(target, log) {
            recorded += usize::from(self.classify_and_record(chain, &event).is_some());
        }

        recorded
    }

    pub fn process_eoa_transaction(
        &self,
        chain: &str,
        signer: Address,
        to: Option<Address>,
    ) -> Option<Alert> {
        let event = classify_eoa_transaction(&self.config.watched_eoas, signer, to)?;
        self.classify_and_record(chain, &event)
    }
}

pub fn record_alert(chain: &str, alert: &Alert) {
    match alert {
        Alert::NonWhitelistedProver { prover } => {
            metrics::inc_non_whitelisted_prover(chain, *prover);
        }
        Alert::NonWhitelistedProposer { proposer } => {
            metrics::inc_non_whitelisted_proposer(chain, *proposer);
        }
        Alert::LargeWithdrawal { target, token, recipient, .. } => {
            metrics::inc_large_withdrawal(chain, target, *token, *recipient);
        }
        Alert::PauseEvent { target, action } => {
            metrics::inc_pause_event(chain, target, action);
        }
        Alert::ProxyUpgrade { target, proxy, implementation, expected } => {
            metrics::inc_proxy_upgrade(chain, target, *proxy, *implementation, *expected);
        }
        Alert::OwnershipTransfer { target, previous_owner, new_owner, expected } => {
            metrics::inc_ownership_transfer(chain, target, *previous_owner, *new_owner, *expected);
        }
        Alert::RoleChange { target, role, account, action } => {
            metrics::inc_role_change(
                chain,
                target,
                &role.to_string(),
                *account,
                role_action(*action),
            );
        }
        Alert::SafeTransaction { safe, operation } => {
            metrics::inc_safe_transaction(chain, safe, safe_operation(*operation));
        }
        Alert::VerifierChange { target, verifier, expected } => {
            metrics::inc_verifier_change(chain, target, &verifier.to_string(), *expected);
        }
        Alert::SgxAnomaly { instance, reason } => {
            metrics::inc_sgx_anomaly(chain, *instance, sgx_reason(*reason));
        }
        Alert::UnexpectedEoaTransaction { signer, to, allowed } => {
            metrics::inc_unexpected_eoa_transaction(chain, *signer, *to, *allowed);
        }
        Alert::ProposalReorg { proposal_id } => {
            metrics::inc_proposal_reorg(chain, *proposal_id);
        }
    }
}

fn role_action(action: RoleAction) -> &'static str {
    match action {
        RoleAction::Granted => "granted",
        RoleAction::Revoked => "revoked",
    }
}

fn safe_operation(operation: SafeOperation) -> &'static str {
    match operation {
        SafeOperation::Success => "success",
        SafeOperation::Failure => "failure",
    }
}

fn sgx_reason(reason: SgxReason) -> &'static str {
    match reason {
        SgxReason::InstanceAdded => "instance_added",
        SgxReason::InstanceDeleted => "instance_deleted",
    }
}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use alloy::primitives::{Address, B256, Log as PrimitiveLog, Uint};
    use alloy::rpc::types::Log as RpcLog;
    use alloy::sol_types::SolEvent;
    use clap::Parser;

    use crate::{
        bindings,
        config::Config,
        events::{Alert, ObservedEvent},
        monitor::RollupMonitor,
    };

    fn config(args: &[&str]) -> Config {
        let mut full_args = vec!["rollup-monitor", "--l1-http-url", "http://localhost:8545"];
        full_args.extend_from_slice(args);
        Config::parse_from(full_args)
    }

    fn addr(value: &str) -> Address {
        Address::from_str(value).expect("test address should parse")
    }

    fn u48(value: u64) -> Uint<48, 1> {
        Uint::<48, 1>::from(value)
    }

    fn rpc_log<E: SolEvent>(address: Address, tx_hash: B256, log_index: u64, event: E) -> RpcLog {
        RpcLog {
            inner: E::encode_log(&PrimitiveLog { address, data: event }),
            block_hash: Some(B256::repeat_byte(0xaa)),
            block_number: Some(100),
            block_timestamp: None,
            transaction_hash: Some(tx_hash),
            transaction_index: Some(1),
            log_index: Some(log_index),
            removed: false,
        }
    }

    #[test]
    fn next_l1_scan_range_plans_without_advancing_cursor() {
        let config =
            config(&["--start-block", "100", "--confirmations", "3", "--overlap-blocks", "20"]);
        let monitor = RollupMonitor::new(config);

        assert_eq!(monitor.next_l1_scan_range(120), Some((100, 117)));
        assert_eq!(monitor.next_l1_scan_range(130), Some((100, 127)));
    }

    #[test]
    fn classify_and_record_returns_alert_for_unexpected_prover() {
        let prover = addr("0x0000000000000000000000000000000000000002");
        let config = config(&["--allowed-provers", "0x0000000000000000000000000000000000000001"]);
        let monitor = RollupMonitor::new(config);

        let alert = monitor.classify_and_record("l1", &ObservedEvent::Prover { prover });

        assert_eq!(alert, Some(Alert::NonWhitelistedProver { prover }));
    }

    #[test]
    fn process_log_dedupes_repeated_log_key() {
        let proposer = addr("0x0000000000000000000000000000000000000031");
        let inbox = addr("0x0000000000000000000000000000000000000032");
        let config = config(&["--allowed-proposers", "0x0000000000000000000000000000000000000030"]);
        let mut monitor = RollupMonitor::new(config);
        let log = rpc_log(
            inbox,
            B256::repeat_byte(0x01),
            0,
            bindings::Proposed {
                id: u48(1),
                proposer,
                parentProposalHash: B256::ZERO,
                endOfSubmissionWindowTimestamp: u48(0),
                basefeeSharingPctg: 0,
                sources: Vec::new(),
            },
        );

        assert_eq!(monitor.process_log("l1", 1, "inbox", &log), 1);
        assert_eq!(monitor.process_log("l1", 1, "inbox", &log), 0);
    }

    #[test]
    fn process_log_detects_changed_proposal_observation() {
        let proposer = addr("0x0000000000000000000000000000000000000033");
        let inbox = addr("0x0000000000000000000000000000000000000034");
        let config = config(&["--allowed-proposers", "0x0000000000000000000000000000000000000033"]);
        let mut monitor = RollupMonitor::new(config);
        let first = rpc_log(
            inbox,
            B256::repeat_byte(0x02),
            0,
            bindings::Proposed {
                id: u48(2),
                proposer,
                parentProposalHash: B256::ZERO,
                endOfSubmissionWindowTimestamp: u48(0),
                basefeeSharingPctg: 0,
                sources: Vec::new(),
            },
        );
        let replacement = rpc_log(
            inbox,
            B256::repeat_byte(0x03),
            0,
            bindings::Proposed {
                id: u48(2),
                proposer,
                parentProposalHash: B256::ZERO,
                endOfSubmissionWindowTimestamp: u48(0),
                basefeeSharingPctg: 0,
                sources: Vec::new(),
            },
        );

        assert_eq!(monitor.process_log("l1", 1, "inbox", &first), 0);
        assert_eq!(monitor.process_log("l1", 1, "inbox", &replacement), 1);
    }

    #[test]
    fn process_eoa_transaction_records_only_watched_unapproved_sender() {
        let signer = addr("0x0000000000000000000000000000000000000035");
        let allowed = addr("0x0000000000000000000000000000000000000036");
        let unexpected = addr("0x0000000000000000000000000000000000000037");
        let config = config(&[
            "--watched-eoas",
            "0x0000000000000000000000000000000000000035",
            "--allowed-eoa-destinations",
            "0x0000000000000000000000000000000000000036",
        ]);
        let monitor = RollupMonitor::new(config);

        assert_eq!(monitor.process_eoa_transaction("l1", signer, Some(allowed)), None);
        assert_eq!(
            monitor.process_eoa_transaction("l1", signer, Some(unexpected)),
            Some(Alert::UnexpectedEoaTransaction { signer, to: Some(unexpected), allowed: false })
        );
        assert_eq!(monitor.process_eoa_transaction("l1", unexpected, Some(unexpected)), None);
    }

    #[test]
    fn eoa_scan_range_is_disabled_by_default_even_with_watched_eoas() {
        let config = config(&["--watched-eoas", "0x0000000000000000000000000000000000000035"]);
        let monitor = RollupMonitor::new(config);

        assert_eq!(monitor.eoa_scan_range(100, 200), None);
    }

    #[test]
    fn eoa_scan_range_uses_tail_limited_independent_range_when_enabled() {
        let config = config(&[
            "--watched-eoas",
            "0x0000000000000000000000000000000000000035",
            "--eoa-scan-enabled",
            "--eoa-scan-max-block-range",
            "25",
        ]);
        let monitor = RollupMonitor::new(config);

        assert_eq!(monitor.eoa_scan_range(100, 200), Some((176, 200)));
        assert_eq!(monitor.eoa_scan_range(190, 200), Some((190, 200)));
    }
}
