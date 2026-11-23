//! Own-finalized Unzen history and own-EL authentication of the Etna start (SYNC-9-5a).

use alloy_consensus::Header;
use alloy_primitives::B256;
use alloy_sol_types::SolCall;

use super::{AbciError, App, within};
use crate::{
    config::SwitchConfig,
    engine::Engine,
    l1::{L1Source, OwnFinality, RawL1Header, own_finality},
    switch::l2_signal_service_address,
    types::GenesisRecord,
};

alloy_sol_types::sol! {
    /// The switching EtnaInbox's immutable Etna fork time (PARAM-11-12a).
    function etnaForkTime() external view returns (uint48);
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// The switch configuration the checks below use: none on a new network (S = 0), and on a
    /// nonzero Etna start a refusal that keeps trust closed while it is absent, because no
    /// landing settles the node's own fork time.
    fn switch_config(&self, genesis: &GenesisRecord) -> Result<Option<&SwitchConfig>, AbciError> {
        match &self.params.switch {
            None if genesis.genesis_height != 0 => Err(AbciError::TrustControl(
                "nonzero Etna start requires switch configuration".into(),
            )),
            config => Ok(config.as_ref()),
        }
    }

    /// Authenticates S only while it remains the latest L1 checkpoint; later landings settle
    /// these facts, so imported nodes then need neither S's state nor the Unzen chain. Each
    /// proxy's implementation proof at S that the EL does not serve yet keeps trust closed;
    /// another implementation than the built-in one halts.
    pub(super) async fn verify_switch_origin(
        &self,
        genesis: &GenesisRecord,
        observation: &RawL1Header,
    ) -> Result<(), AbciError> {
        let Some(config) = self.switch_config(genesis)? else { return Ok(()) };
        if observation.timestamp() < config.fork_timestamp {
            return Err(AbciError::TrustControl(
                "own finalized L1 has not reached the Etna fork".into(),
            ));
        }
        if let Some(origin) = &self.switch_origin {
            match within(
                "Unzen derivation finality",
                self.opts.l1_timeout,
                own_finality(self.l1(), origin.l1_number, origin.l1_hash),
            )
            .await?
            {
                OwnFinality::NotFinal { .. } => {
                    return Err(AbciError::TrustControl(
                        "Unzen derivation observation is not final in own L1".into(),
                    ))
                }
                OwnFinality::OffChain { .. } => {
                    return Err(AbciError::SafetyHalt(
                        "Unzen derivation observation contradicts own finalized L1".into(),
                    ))
                }
                OwnFinality::Canonical => {}
            }
            let header = within(
                "Unzen derivation observation",
                self.opts.l1_timeout,
                self.l1.header(origin.l1_number),
            )
            .await?;
            if header.hash() != origin.l1_hash || header.timestamp() < config.fork_timestamp {
                return Err(AbciError::SafetyHalt(
                    "Unzen derivation predates proposal closure".into(),
                ));
            }
            if origin.height != genesis.genesis_height || origin.hash != genesis.genesis_hash {
                return Err(AbciError::SafetyHalt(
                    "Etna start differs from the derived last Unzen block".into(),
                ));
            }
        } else {
            let hash = within(
                "Unzen finalized core state",
                self.opts.l1_timeout,
                self.l1.finalized_unzen_hash(config.unzen_inbox, observation.hash()),
            )
            .await?
            .ok_or_else(|| {
                AbciError::TrustControl(
                    "waiting for complete Unzen derivation or final proposal proofs".into(),
                )
            })?;
            if hash != genesis.genesis_hash {
                return Err(AbciError::SafetyHalt(
                    "Etna start differs from the finalized last Unzen block".into(),
                ));
            }
        }
        let header = within(
            "Etna start header",
            self.opts.engine_timeout,
            self.engine.header_by_number(genesis.genesis_height),
        )
        .await?
        .ok_or(AbciError::ElBlockMissing(genesis.genesis_height))?;
        self.check_switch_header(genesis, &header)?;
        // The L2 SignalService proxy, then the `EtnaStaking` proxy at the staking address the
        // configuration hash commits, each holding its built-in implementation in S's state.
        for (contract, what, proxy, built_in) in [
            (
                "SignalService",
                "Etna start SignalService proof",
                l2_signal_service_address(self.params.l2_chain_id),
                config.signal_service_implementation,
            ),
            (
                "EtnaStaking",
                "Etna start EtnaStaking proof",
                self.params.staking,
                config.staking_implementation,
            ),
        ] {
            let implementation = within(
                what,
                self.opts.engine_timeout,
                self.engine.proxy_implementation(
                    proxy,
                    genesis.genesis_hash,
                    genesis.genesis_state_root,
                ),
            )
            .await?
            .ok_or_else(|| {
                AbciError::TrustControl(format!("Etna start {contract} state is unavailable"))
            })?;
            if implementation != built_in {
                return Err(AbciError::SafetyHalt(format!(
                    "Etna start L2 {contract} implementation differs from the built-in one"
                )));
            }
        }
        Ok(())
    }

    /// On a switching network, checks before every trust grant that the Etna fork time this node
    /// runs with, including any local override, equals the switching EtnaInbox's immutable
    /// `etnaForkTime()`, read by `eth_call` at the own finalized L1 block `l1_hash` (SYNC-9-5a,
    /// PARAM-11-12a). No landing settles the node's own fork time, so this holds at S and at
    /// every later checkpoint. An unavailable read keeps trust closed; a malformed answer or
    /// another value is an authenticated contradiction (SYNC-9-7).
    pub(super) async fn verify_fork_time(
        &self,
        genesis: &GenesisRecord,
        l1_hash: B256,
    ) -> Result<(), AbciError> {
        let Some(config) = self.switch_config(genesis)? else { return Ok(()) };
        let answer = match within(
            "EtnaInbox fork time",
            self.opts.l1_timeout,
            self.l1.call_at(self.params.inbox, etnaForkTimeCall {}.abi_encode().into(), l1_hash),
        )
        .await
        {
            Ok(answer) => answer,
            Err(AbciError::L1(error)) if !error.is_integrity_failure() => {
                return Err(AbciError::TrustControl(format!(
                    "EtnaInbox fork time is unavailable: {error}"
                )));
            }
            Err(error) => return Err(error),
        };
        if answer.len() != 32 {
            return Err(AbciError::SafetyHalt("invalid etnaForkTime ABI length".into()));
        }
        let fork_time = etnaForkTimeCall::abi_decode_returns_validate(&answer)
            .map_err(|_| AbciError::SafetyHalt("invalid etnaForkTime ABI value".into()))?
            .to::<u64>();
        if fork_time != config.fork_timestamp {
            return Err(AbciError::SafetyHalt(format!(
                "EtnaInbox etnaForkTime {fork_time} differs from the node's fork time {}",
                config.fork_timestamp
            )));
        }
        Ok(())
    }

    /// Checks the own header's identity, authenticated state root and pre-Etna timestamp.
    pub(super) fn check_switch_header(
        &self,
        genesis: &GenesisRecord,
        header: &Header,
    ) -> Result<(), AbciError> {
        if header.number != genesis.genesis_height ||
            header.hash_slow() != genesis.genesis_hash ||
            header.state_root != genesis.genesis_state_root
        {
            return Err(AbciError::SafetyHalt("own EL header contradicts the Etna start".into()));
        }
        if self
            .params
            .switch
            .as_ref()
            .is_some_and(|config| header.timestamp >= config.fork_timestamp)
        {
            return Err(AbciError::SafetyHalt(
                "last Unzen block timestamp reaches the Etna fork".into(),
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use alethia_reth_primitives::addresses::get_treasury_address;
    use alloy_primitives::Address;

    use super::*;
    use crate::{
        config::SwitchConfig,
        store::Store,
        switch::SwitchOrigin,
        test_utils::{EngineCall, Fixture, MockEngine, MockL1},
    };

    /// The built-in `EtnaStaking` implementation of [`switching_app`].
    const STAKING_IMPLEMENTATION: Address = Address::with_last_byte(0x56);

    /// A switching app at S = 1 whose built-in L2 SignalService implementation is
    /// `implementation` and `EtnaStaking` implementation [`STAKING_IMPLEMENTATION`], with the
    /// start header in its EL.
    fn switching_app(
        fx: &Fixture,
        implementation: Address,
        fork_timestamp: u64,
    ) -> (App<MockL1, MockEngine>, GenesisRecord, tempfile::TempDir) {
        let mut start = fx.el_chain[0].clone();
        start.number = 1;
        let genesis = GenesisRecord {
            genesis_height: start.number,
            genesis_hash: start.hash_slow(),
            genesis_state_root: start.state_root,
            ..fx.genesis.clone()
        };
        let mut params = fx.params.clone();
        params.switch = Some(SwitchConfig {
            unzen_inbox: Address::with_last_byte(1),
            fork_timestamp,
            signal_service_implementation: implementation,
            staking_implementation: STAKING_IMPLEMENTATION,
        });
        let origin = SwitchOrigin {
            l1_number: fx.witness.l1_header.number(),
            l1_hash: fx.witness.l1_header.hash(),
            height: genesis.genesis_height,
            hash: genesis.genesis_hash,
        };
        let dir = tempfile::tempdir().unwrap();
        let app = App::new(
            fx.l1(),
            MockEngine::with_chain([start]),
            params,
            Store::volatile(dir.path().to_owned()),
            Default::default(),
        )
        .unwrap()
        .with_switch_origin(origin);
        (app, genesis, dir)
    }

    #[tokio::test]
    async fn switch_origin_requires_the_built_in_signal_service_at_s() {
        let fx = Fixture::genesis(1);
        let implementation = Address::with_last_byte(2);
        let fork_timestamp = fx.el_chain[0].timestamp + 1;
        let (app, genesis, _dir) = switching_app(&fx, implementation, fork_timestamp);
        let signal_service = l2_signal_service_address(fx.params.l2_chain_id);
        let verify = || app.verify_switch_origin(&genesis, &fx.witness.l1_header);
        let prove = |proxy, implementation| {
            app.engine().state().proxy_implementations.insert(proxy, Ok(implementation));
        };
        prove(fx.params.staking, STAKING_IMPLEMENTATION);

        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))), "no proof yet");
        // The Anchor proxy is no longer the switch evidence.
        prove(get_treasury_address(fx.params.l2_chain_id), implementation);
        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))));
        prove(signal_service, Address::with_last_byte(3));
        let result = verify().await;
        assert!(
            matches!(result, Err(AbciError::SafetyHalt(ref reason))
            if reason.contains("SignalService implementation")),
            "{result:?}"
        );
        prove(signal_service, implementation);
        verify().await.unwrap();
    }

    /// The `EtnaStaking` proxy at the configured staking address, the one the configuration
    /// hash commits, must hold the built-in `EtnaStaking` implementation in S's state, read at
    /// S's hash and proven under S's state root, after the SignalService proof: another
    /// implementation halts, and a proof from another proxy is no evidence.
    #[tokio::test]
    async fn switch_origin_requires_the_built_in_staking_implementation_at_s() {
        let fx = Fixture::genesis(1);
        let implementation = Address::with_last_byte(2);
        let fork_timestamp = fx.el_chain[0].timestamp + 1;
        let (app, genesis, _dir) = switching_app(&fx, implementation, fork_timestamp);
        let signal_service = l2_signal_service_address(fx.params.l2_chain_id);
        let verify = || app.verify_switch_origin(&genesis, &fx.witness.l1_header);
        let prove = |proxy, implementation| {
            app.engine().state().proxy_implementations.insert(proxy, Ok(implementation));
        };
        let halted_on_staking = |result: &Result<(), AbciError>| {
            matches!(result, Err(AbciError::SafetyHalt(reason))
                if reason.contains("EtnaStaking implementation"))
        };

        // The SignalService is checked first: with both wrong, the halt names it.
        prove(signal_service, Address::with_last_byte(3));
        prove(fx.params.staking, Address::with_last_byte(4));
        let result = verify().await;
        assert!(
            matches!(result, Err(AbciError::SafetyHalt(ref reason))
            if reason.contains("SignalService implementation")),
            "{result:?}"
        );
        prove(signal_service, implementation);
        let result = verify().await;
        assert!(halted_on_staking(&result), "{result:?}");
        // The SignalService implementation in the staking proxy is another implementation too.
        prove(fx.params.staking, implementation);
        let result = verify().await;
        assert!(halted_on_staking(&result), "{result:?}");
        // The built-in implementation behind another proxy proves nothing about the staking one.
        app.engine().state().proxy_implementations.remove(&fx.params.staking);
        prove(Address::with_last_byte(0x99), STAKING_IMPLEMENTATION);
        let result = verify().await;
        assert!(
            matches!(result, Err(AbciError::TrustControl(ref reason))
            if reason.contains("EtnaStaking")),
            "{result:?}"
        );
        prove(fx.params.staking, STAKING_IMPLEMENTATION);
        app.engine().state().calls.clear();
        verify().await.unwrap();
        let reads: Vec<_> = app
            .engine()
            .calls()
            .into_iter()
            .filter(|call| matches!(call, EngineCall::ProxyImplementation { .. }))
            .collect();
        let at_s = |proxy| EngineCall::ProxyImplementation {
            proxy,
            hash: genesis.genesis_hash,
            state_root: genesis.genesis_state_root,
        };
        assert_eq!(reads, [at_s(signal_service), at_s(fx.params.staking)]);
    }

    /// SYNC-9-5a 5a.j/5a.k/5a.m: the node's fork time must equal the switching EtnaInbox's
    /// immutable `etnaForkTime()`, read on L1 at the own finalized block's hash. No answer keeps
    /// trust closed; another value or a malformed answer halts.
    #[tokio::test]
    async fn fork_time_is_the_switching_inbox_immutable_at_the_finalized_hash() {
        let fx = Fixture::genesis(1);
        let implementation = Address::with_last_byte(2);
        let fork_timestamp = fx.el_chain[0].timestamp + 1;
        let (app, genesis, _dir) = switching_app(&fx, implementation, fork_timestamp);
        let finalized = B256::repeat_byte(0x77);
        let verify = || app.verify_fork_time(&genesis, finalized);

        let unavailable = |result: Result<(), AbciError>| {
            matches!(result, Err(AbciError::TrustControl(ref reason))
                if reason.contains("EtnaInbox fork time is unavailable"))
        };
        assert!(unavailable(verify().await), "no answer yet");
        // Another contract's answer is no evidence.
        app.l1().state().etna_fork_time = Some((Address::with_last_byte(9), fork_timestamp));
        assert!(unavailable(verify().await));
        // A malformed answer from the own L1 node is unverifiable data (SYNC-9-7).
        app.l1().state().fail = Some(crate::l1::L1Error::MalformedResponse("shape".into()));
        assert!(matches!(verify().await, Err(AbciError::L1(_))));
        app.l1().state().fail = None;
        for value in [fork_timestamp - 1, fork_timestamp + 1] {
            app.l1().state().etna_fork_time = Some((fx.params.inbox, value));
            let result = verify().await;
            assert!(
                matches!(result, Err(AbciError::SafetyHalt(ref reason))
                if reason.contains("etnaForkTime")),
                "{result:?}"
            );
        }
        app.l1().state().etna_fork_time = Some((fx.params.inbox, fork_timestamp));
        verify().await.unwrap();
        let input: alloy_primitives::Bytes = etnaForkTimeCall {}.abi_encode().into();
        assert_eq!(
            app.l1().calls().last(),
            Some(&crate::test_utils::L1Call::CallAt {
                address: fx.params.inbox,
                input,
                hash: finalized
            })
        );
    }

    /// Without a switch configuration a node cannot check its own fork time, which no landing
    /// settles, so a nonzero Etna start keeps trust closed at S and at every later checkpoint;
    /// a new network (S = 0) has no switch to check.
    #[tokio::test]
    async fn a_nonzero_start_without_switch_configuration_keeps_trust_closed() {
        let fx = Fixture::genesis(1);
        let implementation = Address::with_last_byte(2);
        let fork_timestamp = fx.el_chain[0].timestamp + 1;
        let (mut app, genesis, _dir) = switching_app(&fx, implementation, fork_timestamp);
        app.l1().state().etna_fork_time = Some((fx.params.inbox, fork_timestamp));
        app.verify_fork_time(&genesis, genesis.genesis_hash).await.unwrap();
        app.params.switch = None;
        for result in [
            app.verify_switch_origin(&genesis, &fx.witness.l1_header).await,
            app.verify_fork_time(&genesis, genesis.genesis_hash).await,
        ] {
            assert!(
                matches!(result, Err(AbciError::TrustControl(ref reason))
                if reason.contains("switch configuration")),
                "{result:?}"
            );
        }
        let fresh = GenesisRecord { genesis_height: 0, ..genesis };
        app.verify_fork_time(&fresh, fresh.genesis_hash).await.unwrap();
    }
}
