//! Own-finalized Unzen history and own-EL authentication of the Etna start (SYNC-9-5a).

use alethia_reth_primitives::addresses::get_treasury_address;
use alloy_consensus::Header;

use super::{AbciError, App, within};
use crate::{
    engine::Engine,
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
        let implementation = within(
            "Etna start Anchor proof",
            self.opts.engine_timeout,
            self.engine.anchor_implementation(
                get_treasury_address(self.params.l2_chain_id),
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
