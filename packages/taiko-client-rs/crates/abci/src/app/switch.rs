//! Own-finalized Unzen history and own-EL authentication of the Etna start (SYNC-9-5a).

use alethia_reth_primitives::addresses::get_treasury_address;
use alloy_consensus::Header;

use super::{AbciError, App, within};
use crate::{
    engine::{Engine, EngineError},
    l1::{L1Source, OwnFinality, RawL1Header, own_finality},
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
        let anchor = get_treasury_address(self.params.l2_chain_id);
        let implementation = within(
            "Etna start Anchor proof",
            self.opts.engine_timeout,
            self.engine.anchor_implementation(
                anchor,
                genesis.genesis_hash,
                genesis.genesis_state_root,
            ),
        )
        .await?
        .ok_or_else(|| AbciError::TrustControl("Etna start Anchor state is unavailable".into()))?;
        if implementation != config.anchor_implementation {
            return Err(AbciError::SafetyHalt(
                "Etna start Anchor implementation differs from deployment configuration".into(),
            ));
        }
        let timestamp = within(
            "Etna start Anchor fork timestamp",
            self.opts.engine_timeout,
            self.engine.anchor_fork_timestamp(anchor, genesis.genesis_hash),
        )
        .await?
        .ok_or_else(|| {
            EngineError::Transport("Etna start Anchor fork timestamp unavailable".into())
        })?;
        if timestamp != config.fork_timestamp {
            return Err(AbciError::SafetyHalt(format!(
                "Etna start Anchor fork timestamp {timestamp} differs from configured fork timestamp {}",
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
    use alloy_primitives::Address;

    use super::*;
    use crate::{
        config::SwitchConfig,
        store::Store,
        switch::SwitchOrigin,
        test_utils::{Fixture, MockEngine},
    };

    #[tokio::test]
    async fn switch_origin_requires_the_configured_anchor_fork_timestamp() {
        let fx = Fixture::genesis(1);
        let mut start = fx.el_chain[0].clone();
        start.number = 1;
        let expected = start.timestamp + 1;
        let genesis = GenesisRecord {
            genesis_height: start.number,
            genesis_hash: start.hash_slow(),
            genesis_state_root: start.state_root,
            ..fx.genesis.clone()
        };
        let implementation = Address::with_last_byte(2);
        let mut params = fx.params.clone();
        params.switch = Some(SwitchConfig {
            unzen_inbox: Address::with_last_byte(1),
            fork_timestamp: expected,
            anchor_implementation: implementation,
        });
        let engine = MockEngine::with_chain([start]);
        engine.state().anchor_implementation = Some(implementation);
        let origin = SwitchOrigin {
            l1_number: fx.witness.l1_header.number(),
            l1_hash: fx.witness.l1_header.hash(),
            height: genesis.genesis_height,
            hash: genesis.genesis_hash,
        };
        let dir = tempfile::tempdir().unwrap();
        let app = App::new(
            fx.l1(),
            engine,
            params,
            Store::volatile(dir.path().to_owned()),
            Default::default(),
        )
        .unwrap()
        .with_switch_origin(origin);

        let result = app.verify_switch_origin(&genesis, &fx.witness.l1_header).await;
        assert!(
            matches!(result, Err(AbciError::Engine(EngineError::Transport(_)))),
            "an implementation address alone cannot authorize the switch: {result:?}"
        );
        for timestamp in [expected - 1, expected + 1] {
            app.engine().state().anchor_fork_timestamp = Some(timestamp);
            let result = app.verify_switch_origin(&genesis, &fx.witness.l1_header).await;
            assert!(
                matches!(result, Err(AbciError::SafetyHalt(ref reason))
                if reason.contains("Anchor fork timestamp")),
                "{result:?}"
            );
        }
        app.engine().state().anchor_fork_timestamp = Some(expected);
        app.verify_switch_origin(&genesis, &fx.witness.l1_header).await.unwrap();
    }
}
