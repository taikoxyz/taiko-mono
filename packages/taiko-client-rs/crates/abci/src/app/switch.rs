//! Own-finalized Unzen history and own-EL authentication of the Etna start (SYNC-9-5a).

use alloy_consensus::Header;
use alloy_primitives::B256;

use super::{AbciError, App, within};
use crate::{
    engine::Engine,
    l1::{L1Source, OwnFinality, RawL1Header, own_finality},
    switch::l2_signal_service_address,
    types::GenesisRecord,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Authenticates S only while it remains the latest L1 checkpoint; later landings settle
    /// these facts, so imported nodes then need neither S's state nor the Unzen chain.
    pub(super) async fn verify_switch_origin(
        &self,
        genesis: &GenesisRecord,
        observation: &RawL1Header,
    ) -> Result<(), AbciError> {
        let Some(config) = &self.params.switch else {
            return if genesis.genesis_height == 0 {
                Ok(())
            } else {
                Err(AbciError::TrustControl(
                    "nonzero Etna start requires switch configuration".into(),
                ))
            };
        };
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
        let implementation = within(
            "Etna start SignalService proof",
            self.opts.engine_timeout,
            self.engine.proxy_implementation(
                l2_signal_service_address(self.params.l2_chain_id),
                genesis.genesis_hash,
                genesis.genesis_state_root,
            ),
        )
        .await?
        .ok_or_else(|| {
            AbciError::TrustControl("Etna start SignalService state is unavailable".into())
        })?;
        if implementation != config.signal_service_implementation {
            return Err(AbciError::SafetyHalt(
                "Etna start L2 SignalService implementation differs from the built-in one".into(),
            ));
        }
        Ok(())
    }

    /// On a switching network, checks before every trust grant that the built-in L2
    /// SignalService implementation's `beaconRootsFrom()` equals the node's own fork time, in
    /// the authenticated L2 state at canonical block `hash`: S, or the trust target once the
    /// node holds it (SYNC-9-5a). No landing settles the node's own fork time.
    pub(super) async fn verify_fork_time(&self, hash: B256) -> Result<(), AbciError> {
        let Some(config) = &self.params.switch else { return Ok(()) };
        let beacon_roots_from = within(
            "L2 SignalService fork time",
            self.opts.engine_timeout,
            self.engine.beacon_roots_from(config.signal_service_implementation, hash),
        )
        .await?
        .ok_or_else(|| {
            AbciError::TrustControl("L2 SignalService fork time is unavailable".into())
        })?;
        if beacon_roots_from != config.fork_timestamp {
            return Err(AbciError::SafetyHalt(format!(
                "L2 SignalService beaconRootsFrom {beacon_roots_from} differs from the node's \
                 fork time {}",
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
        test_utils::{Fixture, MockEngine, MockL1},
    };

    /// A switching app at S = 1 whose built-in L2 SignalService implementation is
    /// `implementation`, with the start header in its EL.
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

        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))), "no proof yet");
        // The Anchor proxy is no longer the switch evidence.
        app.engine().state().proxy_implementation =
            Some((get_treasury_address(fx.params.l2_chain_id), implementation));
        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))));
        app.engine().state().proxy_implementation =
            Some((signal_service, Address::with_last_byte(3)));
        let result = verify().await;
        assert!(
            matches!(result, Err(AbciError::SafetyHalt(ref reason))
            if reason.contains("SignalService implementation")),
            "{result:?}"
        );
        app.engine().state().proxy_implementation = Some((signal_service, implementation));
        verify().await.unwrap();
    }

    #[tokio::test]
    async fn fork_time_is_read_on_the_built_in_implementation() {
        let fx = Fixture::genesis(1);
        let implementation = Address::with_last_byte(2);
        let fork_timestamp = fx.el_chain[0].timestamp + 1;
        let (app, genesis, _dir) = switching_app(&fx, implementation, fork_timestamp);
        let verify = || app.verify_fork_time(genesis.genesis_hash);

        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))), "no reading yet");
        // A reading through the proxy, or from another implementation, is no evidence.
        app.engine().state().beacon_roots_from =
            Some((l2_signal_service_address(fx.params.l2_chain_id), fork_timestamp));
        assert!(matches!(verify().await, Err(AbciError::TrustControl(_))));
        for value in [fork_timestamp - 1, fork_timestamp + 1] {
            app.engine().state().beacon_roots_from = Some((implementation, value));
            let result = verify().await;
            assert!(
                matches!(result, Err(AbciError::SafetyHalt(ref reason))
                if reason.contains("beaconRootsFrom")),
                "{result:?}"
            );
        }
        app.engine().state().beacon_roots_from = Some((implementation, fork_timestamp));
        verify().await.unwrap();
    }
}
