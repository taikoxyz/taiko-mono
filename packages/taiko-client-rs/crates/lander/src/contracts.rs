//! The subset of the Etna Inbox ABI the lander calls, decodes and binds, written by hand from the
//! specification's `land` interface and the Inbox views: a seven-field `LandInput`, `land`, the
//! `Landed` event, the deployment getters and the three record views. The fallback key list's
//! ABI is declared once, in `abci::fallback`, and is not repeated here.

use alloy::sol;

sol! {
    #[sol(all_derives)]
    interface IEtnaInbox {
        /// The public inputs of `land`: the seven fields, and no others.
        struct LandInput {
            /// The proof origin p, a retained checkpoint at or below the latest checkpoint c.
            uint256 parentHeight;
            /// The terminal height h.
            uint256 lastHeight;
            /// h's EL block hash.
            bytes32 lastBlockHash;
            /// h's CometBFT block hash.
            bytes32 lastCometHash;
            /// h's EL state root.
            bytes32 lastStateRoot;
            /// The L1 block whose header chain authenticates every anchor and root used.
            uint256 l1ReferenceBlockNumber;
            /// The forced inclusion head after settlement: the cursor at h.
            uint256 forcedInclusionHead;
        }

        /// A landing record (slot 285): its actual parent checkpoint, generation, forced
        /// inclusion cursor and EL and CometBFT hashes.
        struct Landing {
            /// The checkpoint c the landing settled on, never the proof origin.
            uint48 parentHeight;
            /// The recovery generation of the landing.
            uint48 generation;
            /// The forced inclusion cursor at this height.
            uint48 head;
            /// The EL block hash at this height.
            bytes32 elHash;
            /// The CometBFT block hash at this height; zero at the Etna start.
            bytes32 cometHash;
        }

        /// A generation's fixed origin record (slot 290), four words.
        struct Origin {
            /// The checkpoint height the generation starts from.
            uint256 startHeight;
            /// The origin L1 block: `L1_0` for generation 0, R for a recovery generation.
            uint256 l1BlockNumber;
            /// That L1 block's timestamp.
            uint256 l1Timestamp;
            /// The fallback key hash when the record was written: the list that signs the
            /// generation's first two blocks.
            bytes32 fallbackKeysHash;
        }

        /// Settles (c, h] with the proof covering (p, h]; `_leaves` are the cut leaves of the
        /// heights strictly inside (p, h), in height order.
        function land(LandInput calldata _input, bytes32[] calldata _leaves, bytes calldata _proof)
            external;

        /// Emitted by `land`: p, the checkpoint c it settled on, h, the cut hash and `VERSION`.
        event Landed(
            uint256 indexed parentHeight,
            uint256 indexed checkpointHeight,
            uint256 indexed lastHeight,
            bytes32 cutHash,
            uint8 version
        );

        /// The configuration hash (slot 269) over the L2 chain id, the `EtnaStaking` proxy and U.
        function configHash() external view returns (bytes32);
        /// The fixed origin record of `_generation`.
        function origins(uint256 _generation) external view returns (Origin memory);
        /// The landing record of `_height`.
        function landings(uint256 _height) external view returns (Landing memory);
        /// The most blocks one landing may cover.
        function maxBatchBlocks() external view returns (uint64);
        /// The landing statement version, 1.
        function VERSION() external view returns (uint8);
        /// Whether `init` has run.
        function isInitialized() external view returns (bool);
        /// The L2 chain id.
        function l2ChainId() external view returns (uint64);
        /// The shared L1 SignalService that `land` saves checkpoints into.
        function signalService() external view returns (address);
        /// The Etna start S and its EL block hash, both zero until the start write.
        function etnaStart() external view returns (uint48 height_, bytes32 blockHash_);

        /// `land`'s reference block has no readable hash at execution.
        error ReferenceBlockUnavailable();
    }
}

/// Journal representation of the seven-field `LandInput` as canonical ABI bytes.
pub(crate) mod abi_serde {
    use alloy::sol_types::{SolType, SolValue};
    use alloy_primitives::Bytes;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Serialize without hand-writing or duplicating the ABI fields.
    pub fn serialize<T: SolValue, S: Serializer>(
        value: &T,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        Bytes::from(value.abi_encode()).serialize(serializer)
    }

    /// Reject noncanonical ABI bytes while restoring the ABI type.
    pub fn deserialize<'de, T, D>(deserializer: D) -> Result<T, D::Error>
    where
        T: SolValue + From<<T::SolType as SolType>::RustType>,
        D: Deserializer<'de>,
    {
        let bytes = Bytes::deserialize(deserializer)?;
        let value = T::abi_decode(&bytes).map_err(serde::de::Error::custom)?;
        if value.abi_encode().as_slice() != bytes.as_ref() {
            return Err(serde::de::Error::custom("noncanonical ABI journal value"));
        }
        Ok(value)
    }
}
