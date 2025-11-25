///Module containing a contract's types and functions.
/**

```solidity
library ICheckpointStore {
    struct Checkpoint { uint48 blockNumber; bytes32 blockHash; bytes32 stateRoot; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod ICheckpointStore {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct Checkpoint { uint48 blockNumber; bytes32 blockHash; bytes32 stateRoot; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Checkpoint {
        #[allow(missing_docs)]
        pub blockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub blockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub stateRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<Checkpoint> for UnderlyingRustTuple<'_> {
            fn from(value: Checkpoint) -> Self {
                (value.blockNumber, value.blockHash, value.stateRoot)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Checkpoint {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blockNumber: tuple.0,
                    blockHash: tuple.1,
                    stateRoot: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for Checkpoint {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for Checkpoint {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.blockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.blockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.stateRoot),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for Checkpoint {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for Checkpoint {
            const NAME: &'static str = "Checkpoint";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "Checkpoint(uint48 blockNumber,bytes32 blockHash,bytes32 stateRoot)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blockNumber)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blockHash)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.stateRoot)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for Checkpoint {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blockNumber,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blockHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.stateRoot,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blockHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.stateRoot,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`ICheckpointStore`](self) contract instance.

See the [wrapper's documentation](`ICheckpointStoreInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> ICheckpointStoreInstance<P, N> {
        ICheckpointStoreInstance::<P, N>::new(address, provider)
    }
    /**A [`ICheckpointStore`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`ICheckpointStore`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct ICheckpointStoreInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for ICheckpointStoreInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("ICheckpointStoreInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ICheckpointStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ICheckpointStore`](self) contract instance.

See the [wrapper's documentation](`ICheckpointStoreInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            provider: P,
        ) -> Self {
            Self {
                address,
                provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /// Returns a reference to the address.
        #[inline]
        pub const fn address(&self) -> &alloy_sol_types::private::Address {
            &self.address
        }
        /// Sets the address.
        #[inline]
        pub fn set_address(&mut self, address: alloy_sol_types::private::Address) {
            self.address = address;
        }
        /// Sets the address and returns `self`.
        pub fn at(mut self, address: alloy_sol_types::private::Address) -> Self {
            self.set_address(address);
            self
        }
        /// Returns a reference to the provider.
        #[inline]
        pub const fn provider(&self) -> &P {
            &self.provider
        }
    }
    impl<P: ::core::clone::Clone, N> ICheckpointStoreInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> ICheckpointStoreInstance<P, N> {
            ICheckpointStoreInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ICheckpointStoreInstance<P, N> {
        /// Creates a new call builder using this contract instance's provider and address.
        ///
        /// Note that the call can be any function call, not just those defined in this
        /// contract. Prefer using the other methods for building type-safe contract calls.
        pub fn call_builder<C: alloy_sol_types::SolCall>(
            &self,
            call: &C,
        ) -> alloy_contract::SolCallBuilder<&P, C, N> {
            alloy_contract::SolCallBuilder::new_sol(&self.provider, &self.address, call)
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ICheckpointStoreInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
    }
}
///Module containing a contract's types and functions.
/**

```solidity
library IInbox {
    struct CoreState { uint48 nextProposalId; uint48 lastProposalBlockId; uint48 lastFinalizedProposalId; uint48 lastCheckpointTimestamp; bytes32 lastFinalizedTransitionHash; bytes32 bondInstructionsHash; }
    struct Derivation { uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
    struct DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
    struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 coreStateHash; bytes32 derivationHash; }
    struct ProposeInput { uint48 deadline; CoreState coreState; Proposal[] parentProposals; LibBlobs.BlobReference blobReference; TransitionRecord[] transitionRecords; ICheckpointStore.Checkpoint checkpoint; uint8 numForcedInclusions; }
    struct ProposedEventPayload { Proposal proposal; Derivation derivation; CoreState coreState; LibBonds.BondInstruction[] bondInstructions; }
    struct ProveInput { Proposal[] proposals; Transition[] transitions; TransitionMetadata[] metadata; }
    struct ProvedEventPayload { uint48 proposalId; Transition transition; TransitionRecord transitionRecord; TransitionMetadata metadata; }
    struct Transition { bytes32 proposalHash; bytes32 parentTransitionHash; ICheckpointStore.Checkpoint checkpoint; }
    struct TransitionMetadata { address designatedProver; address actualProver; }
    struct TransitionRecord { uint8 span; LibBonds.BondInstruction[] bondInstructions; bytes32 transitionHash; bytes32 checkpointHash; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod IInbox {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct CoreState { uint48 nextProposalId; uint48 lastProposalBlockId; uint48 lastFinalizedProposalId; uint48 lastCheckpointTimestamp; bytes32 lastFinalizedTransitionHash; bytes32 bondInstructionsHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct CoreState {
        #[allow(missing_docs)]
        pub nextProposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastProposalBlockId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastFinalizedProposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastCheckpointTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastFinalizedTransitionHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<CoreState> for UnderlyingRustTuple<'_> {
            fn from(value: CoreState) -> Self {
                (
                    value.nextProposalId,
                    value.lastProposalBlockId,
                    value.lastFinalizedProposalId,
                    value.lastCheckpointTimestamp,
                    value.lastFinalizedTransitionHash,
                    value.bondInstructionsHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for CoreState {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    nextProposalId: tuple.0,
                    lastProposalBlockId: tuple.1,
                    lastFinalizedProposalId: tuple.2,
                    lastCheckpointTimestamp: tuple.3,
                    lastFinalizedTransitionHash: tuple.4,
                    bondInstructionsHash: tuple.5,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for CoreState {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for CoreState {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.nextProposalId),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.lastProposalBlockId),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.lastFinalizedProposalId,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.lastCheckpointTimestamp,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.lastFinalizedTransitionHash,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructionsHash),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for CoreState {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for CoreState {
            const NAME: &'static str = "CoreState";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "CoreState(uint48 nextProposalId,uint48 lastProposalBlockId,uint48 lastFinalizedProposalId,uint48 lastCheckpointTimestamp,bytes32 lastFinalizedTransitionHash,bytes32 bondInstructionsHash)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.nextProposalId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastProposalBlockId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastFinalizedProposalId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastCheckpointTimestamp,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastFinalizedTransitionHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstructionsHash,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for CoreState {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.nextProposalId,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastProposalBlockId,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastFinalizedProposalId,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastCheckpointTimestamp,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastFinalizedTransitionHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructionsHash,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.nextProposalId,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastProposalBlockId,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastFinalizedProposalId,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastCheckpointTimestamp,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastFinalizedTransitionHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondInstructionsHash,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct Derivation { uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Derivation {
        #[allow(missing_docs)]
        pub originBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub originBlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub basefeeSharingPctg: u8,
        #[allow(missing_docs)]
        pub sources: alloy::sol_types::private::Vec<
            <DerivationSource as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Uint<8>,
            alloy::sol_types::sol_data::Array<DerivationSource>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            u8,
            alloy::sol_types::private::Vec<
                <DerivationSource as alloy::sol_types::SolType>::RustType,
            >,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<Derivation> for UnderlyingRustTuple<'_> {
            fn from(value: Derivation) -> Self {
                (
                    value.originBlockNumber,
                    value.originBlockHash,
                    value.basefeeSharingPctg,
                    value.sources,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Derivation {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    originBlockNumber: tuple.0,
                    originBlockHash: tuple.1,
                    basefeeSharingPctg: tuple.2,
                    sources: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for Derivation {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for Derivation {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.originBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.originBlockHash),
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.basefeeSharingPctg),
                    <alloy::sol_types::sol_data::Array<
                        DerivationSource,
                    > as alloy_sol_types::SolType>::tokenize(&self.sources),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for Derivation {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for Derivation {
            const NAME: &'static str = "Derivation";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "Derivation(uint48 originBlockNumber,bytes32 originBlockHash,uint8 basefeeSharingPctg,DerivationSource[] sources)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <DerivationSource as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <DerivationSource as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.originBlockNumber,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.originBlockHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.basefeeSharingPctg,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        DerivationSource,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.sources)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for Derivation {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.originBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.originBlockHash,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.basefeeSharingPctg,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        DerivationSource,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.sources,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.originBlockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.originBlockHash,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.basefeeSharingPctg,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    DerivationSource,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.sources,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct DerivationSource {
        #[allow(missing_docs)]
        pub isForcedInclusion: bool,
        #[allow(missing_docs)]
        pub blobSlice: <LibBlobs::BlobSlice as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Bool,
            LibBlobs::BlobSlice,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            bool,
            <LibBlobs::BlobSlice as alloy::sol_types::SolType>::RustType,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<DerivationSource> for UnderlyingRustTuple<'_> {
            fn from(value: DerivationSource) -> Self {
                (value.isForcedInclusion, value.blobSlice)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for DerivationSource {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    isForcedInclusion: tuple.0,
                    blobSlice: tuple.1,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for DerivationSource {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for DerivationSource {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isForcedInclusion,
                    ),
                    <LibBlobs::BlobSlice as alloy_sol_types::SolType>::tokenize(
                        &self.blobSlice,
                    ),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for DerivationSource {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for DerivationSource {
            const NAME: &'static str = "DerivationSource";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "DerivationSource(bool isForcedInclusion,BlobSlice blobSlice)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <LibBlobs::BlobSlice as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LibBlobs::BlobSlice as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.isForcedInclusion,
                        )
                        .0,
                    <LibBlobs::BlobSlice as alloy_sol_types::SolType>::eip712_data_word(
                            &self.blobSlice,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for DerivationSource {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.isForcedInclusion,
                    )
                    + <LibBlobs::BlobSlice as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blobSlice,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.isForcedInclusion,
                    out,
                );
                <LibBlobs::BlobSlice as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blobSlice,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 coreStateHash; bytes32 derivationHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Proposal {
        #[allow(missing_docs)]
        pub id: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub timestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub endOfSubmissionWindowTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub coreStateHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub derivationHash: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<Proposal> for UnderlyingRustTuple<'_> {
            fn from(value: Proposal) -> Self {
                (
                    value.id,
                    value.timestamp,
                    value.endOfSubmissionWindowTimestamp,
                    value.proposer,
                    value.coreStateHash,
                    value.derivationHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Proposal {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    id: tuple.0,
                    timestamp: tuple.1,
                    endOfSubmissionWindowTimestamp: tuple.2,
                    proposer: tuple.3,
                    coreStateHash: tuple.4,
                    derivationHash: tuple.5,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for Proposal {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for Proposal {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.id),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.endOfSubmissionWindowTimestamp,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.proposer,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.coreStateHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.derivationHash),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for Proposal {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for Proposal {
            const NAME: &'static str = "Proposal";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "Proposal(uint48 id,uint48 timestamp,uint48 endOfSubmissionWindowTimestamp,address proposer,bytes32 coreStateHash,bytes32 derivationHash)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.id)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.timestamp)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.endOfSubmissionWindowTimestamp,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proposer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.coreStateHash)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.derivationHash,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for Proposal {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(&rust.id)
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.timestamp,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.endOfSubmissionWindowTimestamp,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposer,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.coreStateHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.derivationHash,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(&rust.id, out);
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.timestamp,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.endOfSubmissionWindowTimestamp,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposer,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.coreStateHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.derivationHash,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**```solidity
struct ProposeInput { uint48 deadline; CoreState coreState; Proposal[] parentProposals; LibBlobs.BlobReference blobReference; TransitionRecord[] transitionRecords; ICheckpointStore.Checkpoint checkpoint; uint8 numForcedInclusions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposeInput {
        #[allow(missing_docs)]
        pub deadline: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub coreState: <CoreState as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub parentProposals: alloy::sol_types::private::Vec<
            <Proposal as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub blobReference: <LibBlobs::BlobReference as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub transitionRecords: alloy::sol_types::private::Vec<
            <TransitionRecord as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub numForcedInclusions: u8,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            CoreState,
            alloy::sol_types::sol_data::Array<Proposal>,
            LibBlobs::BlobReference,
            alloy::sol_types::sol_data::Array<TransitionRecord>,
            ICheckpointStore::Checkpoint,
            alloy::sol_types::sol_data::Uint<8>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            <CoreState as alloy::sol_types::SolType>::RustType,
            alloy::sol_types::private::Vec<
                <Proposal as alloy::sol_types::SolType>::RustType,
            >,
            <LibBlobs::BlobReference as alloy::sol_types::SolType>::RustType,
            alloy::sol_types::private::Vec<
                <TransitionRecord as alloy::sol_types::SolType>::RustType,
            >,
            <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
            u8,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<ProposeInput> for UnderlyingRustTuple<'_> {
            fn from(value: ProposeInput) -> Self {
                (
                    value.deadline,
                    value.coreState,
                    value.parentProposals,
                    value.blobReference,
                    value.transitionRecords,
                    value.checkpoint,
                    value.numForcedInclusions,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposeInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    deadline: tuple.0,
                    coreState: tuple.1,
                    parentProposals: tuple.2,
                    blobReference: tuple.3,
                    transitionRecords: tuple.4,
                    checkpoint: tuple.5,
                    numForcedInclusions: tuple.6,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProposeInput {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProposeInput {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.deadline),
                    <CoreState as alloy_sol_types::SolType>::tokenize(&self.coreState),
                    <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentProposals),
                    <LibBlobs::BlobReference as alloy_sol_types::SolType>::tokenize(
                        &self.blobReference,
                    ),
                    <alloy::sol_types::sol_data::Array<
                        TransitionRecord,
                    > as alloy_sol_types::SolType>::tokenize(&self.transitionRecords),
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::tokenize(
                        &self.checkpoint,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.numForcedInclusions),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for ProposeInput {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for ProposeInput {
            const NAME: &'static str = "ProposeInput";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProposeInput(uint48 deadline,CoreState coreState,Proposal[] parentProposals,BlobReference blobReference,TransitionRecord[] transitionRecords,Checkpoint checkpoint,uint8 numForcedInclusions)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(5);
                components
                    .push(<CoreState as alloy_sol_types::SolStruct>::eip712_root_type());
                components
                    .extend(
                        <CoreState as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(<Proposal as alloy_sol_types::SolStruct>::eip712_root_type());
                components
                    .extend(
                        <Proposal as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <LibBlobs::BlobReference as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LibBlobs::BlobReference as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <TransitionRecord as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <TransitionRecord as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <ICheckpointStore::Checkpoint as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <ICheckpointStore::Checkpoint as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.deadline)
                        .0,
                    <CoreState as alloy_sol_types::SolType>::eip712_data_word(
                            &self.coreState,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.parentProposals,
                        )
                        .0,
                    <LibBlobs::BlobReference as alloy_sol_types::SolType>::eip712_data_word(
                            &self.blobReference,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        TransitionRecord,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.transitionRecords,
                        )
                        .0,
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::eip712_data_word(
                            &self.checkpoint,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.numForcedInclusions,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProposeInput {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.deadline,
                    )
                    + <CoreState as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.coreState,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.parentProposals,
                    )
                    + <LibBlobs::BlobReference as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blobReference,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        TransitionRecord,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitionRecords,
                    )
                    + <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.checkpoint,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.numForcedInclusions,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.deadline,
                    out,
                );
                <CoreState as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.coreState,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    Proposal,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.parentProposals,
                    out,
                );
                <LibBlobs::BlobReference as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blobReference,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    TransitionRecord,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitionRecords,
                    out,
                );
                <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.checkpoint,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.numForcedInclusions,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**```solidity
struct ProposedEventPayload { Proposal proposal; Derivation derivation; CoreState coreState; LibBonds.BondInstruction[] bondInstructions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposedEventPayload {
        #[allow(missing_docs)]
        pub proposal: <Proposal as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub derivation: <Derivation as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub coreState: <CoreState as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub bondInstructions: alloy::sol_types::private::Vec<
            <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            Proposal,
            Derivation,
            CoreState,
            alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            <Proposal as alloy::sol_types::SolType>::RustType,
            <Derivation as alloy::sol_types::SolType>::RustType,
            <CoreState as alloy::sol_types::SolType>::RustType,
            alloy::sol_types::private::Vec<
                <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
            >,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<ProposedEventPayload> for UnderlyingRustTuple<'_> {
            fn from(value: ProposedEventPayload) -> Self {
                (
                    value.proposal,
                    value.derivation,
                    value.coreState,
                    value.bondInstructions,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposedEventPayload {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposal: tuple.0,
                    derivation: tuple.1,
                    coreState: tuple.2,
                    bondInstructions: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProposedEventPayload {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProposedEventPayload {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <Proposal as alloy_sol_types::SolType>::tokenize(&self.proposal),
                    <Derivation as alloy_sol_types::SolType>::tokenize(&self.derivation),
                    <CoreState as alloy_sol_types::SolType>::tokenize(&self.coreState),
                    <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructions),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for ProposedEventPayload {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for ProposedEventPayload {
            const NAME: &'static str = "ProposedEventPayload";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProposedEventPayload(Proposal proposal,Derivation derivation,CoreState coreState,LibBonds.BondInstruction[] bondInstructions)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(4);
                components
                    .push(<Proposal as alloy_sol_types::SolStruct>::eip712_root_type());
                components
                    .extend(
                        <Proposal as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <Derivation as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <Derivation as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(<CoreState as alloy_sol_types::SolStruct>::eip712_root_type());
                components
                    .extend(
                        <CoreState as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <LibBonds::BondInstruction as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LibBonds::BondInstruction as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <Proposal as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proposal,
                        )
                        .0,
                    <Derivation as alloy_sol_types::SolType>::eip712_data_word(
                            &self.derivation,
                        )
                        .0,
                    <CoreState as alloy_sol_types::SolType>::eip712_data_word(
                            &self.coreState,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstructions,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProposedEventPayload {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <Proposal as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposal,
                    )
                    + <Derivation as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.derivation,
                    )
                    + <CoreState as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.coreState,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructions,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <Proposal as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposal,
                    out,
                );
                <Derivation as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.derivation,
                    out,
                );
                <CoreState as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.coreState,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    LibBonds::BondInstruction,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondInstructions,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct ProveInput { Proposal[] proposals; Transition[] transitions; TransitionMetadata[] metadata; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProveInput {
        #[allow(missing_docs)]
        pub proposals: alloy::sol_types::private::Vec<
            <Proposal as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub transitions: alloy::sol_types::private::Vec<
            <Transition as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub metadata: alloy::sol_types::private::Vec<
            <TransitionMetadata as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Array<Proposal>,
            alloy::sol_types::sol_data::Array<Transition>,
            alloy::sol_types::sol_data::Array<TransitionMetadata>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Vec<
                <Proposal as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::Vec<
                <Transition as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::Vec<
                <TransitionMetadata as alloy::sol_types::SolType>::RustType,
            >,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<ProveInput> for UnderlyingRustTuple<'_> {
            fn from(value: ProveInput) -> Self {
                (value.proposals, value.transitions, value.metadata)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProveInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposals: tuple.0,
                    transitions: tuple.1,
                    metadata: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProveInput {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProveInput {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposals),
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::tokenize(&self.transitions),
                    <alloy::sol_types::sol_data::Array<
                        TransitionMetadata,
                    > as alloy_sol_types::SolType>::tokenize(&self.metadata),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for ProveInput {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for ProveInput {
            const NAME: &'static str = "ProveInput";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProveInput(Proposal[] proposals,Transition[] transitions,TransitionMetadata[] metadata)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(3);
                components
                    .push(<Proposal as alloy_sol_types::SolStruct>::eip712_root_type());
                components
                    .extend(
                        <Proposal as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <Transition as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <Transition as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <TransitionMetadata as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <TransitionMetadata as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposals)
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.transitions)
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        TransitionMetadata,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.metadata)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProveInput {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Array<
                        Proposal,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposals,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitions,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        TransitionMetadata,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.metadata,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Array<
                    Proposal,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposals,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    Transition,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitions,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    TransitionMetadata,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.metadata,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**```solidity
struct ProvedEventPayload { uint48 proposalId; Transition transition; TransitionRecord transitionRecord; TransitionMetadata metadata; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProvedEventPayload {
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub transition: <Transition as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub transitionRecord: <TransitionRecord as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub metadata: <TransitionMetadata as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            Transition,
            TransitionRecord,
            TransitionMetadata,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            <Transition as alloy::sol_types::SolType>::RustType,
            <TransitionRecord as alloy::sol_types::SolType>::RustType,
            <TransitionMetadata as alloy::sol_types::SolType>::RustType,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<ProvedEventPayload> for UnderlyingRustTuple<'_> {
            fn from(value: ProvedEventPayload) -> Self {
                (
                    value.proposalId,
                    value.transition,
                    value.transitionRecord,
                    value.metadata,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProvedEventPayload {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposalId: tuple.0,
                    transition: tuple.1,
                    transitionRecord: tuple.2,
                    metadata: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProvedEventPayload {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProvedEventPayload {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalId),
                    <Transition as alloy_sol_types::SolType>::tokenize(&self.transition),
                    <TransitionRecord as alloy_sol_types::SolType>::tokenize(
                        &self.transitionRecord,
                    ),
                    <TransitionMetadata as alloy_sol_types::SolType>::tokenize(
                        &self.metadata,
                    ),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for ProvedEventPayload {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for ProvedEventPayload {
            const NAME: &'static str = "ProvedEventPayload";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProvedEventPayload(uint48 proposalId,Transition transition,TransitionRecord transitionRecord,TransitionMetadata metadata)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(3);
                components
                    .push(
                        <Transition as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <Transition as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <TransitionRecord as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <TransitionRecord as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <TransitionMetadata as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <TransitionMetadata as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalId)
                        .0,
                    <Transition as alloy_sol_types::SolType>::eip712_data_word(
                            &self.transition,
                        )
                        .0,
                    <TransitionRecord as alloy_sol_types::SolType>::eip712_data_word(
                            &self.transitionRecord,
                        )
                        .0,
                    <TransitionMetadata as alloy_sol_types::SolType>::eip712_data_word(
                            &self.metadata,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProvedEventPayload {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalId,
                    )
                    + <Transition as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transition,
                    )
                    + <TransitionRecord as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitionRecord,
                    )
                    + <TransitionMetadata as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.metadata,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposalId,
                    out,
                );
                <Transition as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transition,
                    out,
                );
                <TransitionRecord as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitionRecord,
                    out,
                );
                <TransitionMetadata as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.metadata,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct Transition { bytes32 proposalHash; bytes32 parentTransitionHash; ICheckpointStore.Checkpoint checkpoint; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Transition {
        #[allow(missing_docs)]
        pub proposalHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub parentTransitionHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            ICheckpointStore::Checkpoint,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
            <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<Transition> for UnderlyingRustTuple<'_> {
            fn from(value: Transition) -> Self {
                (value.proposalHash, value.parentTransitionHash, value.checkpoint)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Transition {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposalHash: tuple.0,
                    parentTransitionHash: tuple.1,
                    checkpoint: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for Transition {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for Transition {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentTransitionHash),
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::tokenize(
                        &self.checkpoint,
                    ),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for Transition {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for Transition {
            const NAME: &'static str = "Transition";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "Transition(bytes32 proposalHash,bytes32 parentTransitionHash,Checkpoint checkpoint)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <ICheckpointStore::Checkpoint as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <ICheckpointStore::Checkpoint as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalHash)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.parentTransitionHash,
                        )
                        .0,
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::eip712_data_word(
                            &self.checkpoint,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for Transition {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.parentTransitionHash,
                    )
                    + <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.checkpoint,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposalHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.parentTransitionHash,
                    out,
                );
                <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.checkpoint,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct TransitionMetadata { address designatedProver; address actualProver; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct TransitionMetadata {
        #[allow(missing_docs)]
        pub designatedProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub actualProver: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Address,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Address,
            alloy::sol_types::private::Address,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<TransitionMetadata> for UnderlyingRustTuple<'_> {
            fn from(value: TransitionMetadata) -> Self {
                (value.designatedProver, value.actualProver)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for TransitionMetadata {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    designatedProver: tuple.0,
                    actualProver: tuple.1,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for TransitionMetadata {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for TransitionMetadata {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.actualProver,
                    ),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for TransitionMetadata {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for TransitionMetadata {
            const NAME: &'static str = "TransitionMetadata";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "TransitionMetadata(address designatedProver,address actualProver)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.designatedProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.actualProver,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for TransitionMetadata {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.designatedProver,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.actualProver,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.designatedProver,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.actualProver,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**```solidity
struct TransitionRecord { uint8 span; LibBonds.BondInstruction[] bondInstructions; bytes32 transitionHash; bytes32 checkpointHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct TransitionRecord {
        #[allow(missing_docs)]
        pub span: u8,
        #[allow(missing_docs)]
        pub bondInstructions: alloy::sol_types::private::Vec<
            <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub transitionHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub checkpointHash: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<8>,
            alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            u8,
            alloy::sol_types::private::Vec<
                <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<TransitionRecord> for UnderlyingRustTuple<'_> {
            fn from(value: TransitionRecord) -> Self {
                (
                    value.span,
                    value.bondInstructions,
                    value.transitionHash,
                    value.checkpointHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for TransitionRecord {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    span: tuple.0,
                    bondInstructions: tuple.1,
                    transitionHash: tuple.2,
                    checkpointHash: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for TransitionRecord {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for TransitionRecord {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.span),
                    <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructions),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.transitionHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.checkpointHash),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for TransitionRecord {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for TransitionRecord {
            const NAME: &'static str = "TransitionRecord";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "TransitionRecord(uint8 span,LibBonds.BondInstruction[] bondInstructions,bytes32 transitionHash,bytes32 checkpointHash)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <LibBonds::BondInstruction as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LibBonds::BondInstruction as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.span)
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstructions,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.transitionHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.checkpointHash,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for TransitionRecord {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(&rust.span)
                    + <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructions,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitionHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.checkpointHash,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.span,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    LibBonds::BondInstruction,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondInstructions,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitionHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.checkpointHash,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`IInbox`](self) contract instance.

See the [wrapper's documentation](`IInboxInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(address: alloy_sol_types::private::Address, provider: P) -> IInboxInstance<P, N> {
        IInboxInstance::<P, N>::new(address, provider)
    }
    /**A [`IInbox`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`IInbox`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct IInboxInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for IInboxInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("IInboxInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > IInboxInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`IInbox`](self) contract instance.

See the [wrapper's documentation](`IInboxInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            provider: P,
        ) -> Self {
            Self {
                address,
                provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /// Returns a reference to the address.
        #[inline]
        pub const fn address(&self) -> &alloy_sol_types::private::Address {
            &self.address
        }
        /// Sets the address.
        #[inline]
        pub fn set_address(&mut self, address: alloy_sol_types::private::Address) {
            self.address = address;
        }
        /// Sets the address and returns `self`.
        pub fn at(mut self, address: alloy_sol_types::private::Address) -> Self {
            self.set_address(address);
            self
        }
        /// Returns a reference to the provider.
        #[inline]
        pub const fn provider(&self) -> &P {
            &self.provider
        }
    }
    impl<P: ::core::clone::Clone, N> IInboxInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> IInboxInstance<P, N> {
            IInboxInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > IInboxInstance<P, N> {
        /// Creates a new call builder using this contract instance's provider and address.
        ///
        /// Note that the call can be any function call, not just those defined in this
        /// contract. Prefer using the other methods for building type-safe contract calls.
        pub fn call_builder<C: alloy_sol_types::SolCall>(
            &self,
            call: &C,
        ) -> alloy_contract::SolCallBuilder<&P, C, N> {
            alloy_contract::SolCallBuilder::new_sol(&self.provider, &self.address, call)
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > IInboxInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
    }
}
///Module containing a contract's types and functions.
/**

```solidity
library LibBlobs {
    struct BlobReference { uint16 blobStartIndex; uint16 numBlobs; uint24 offset; }
    struct BlobSlice { bytes32[] blobHashes; uint24 offset; uint48 timestamp; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod LibBlobs {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BlobReference { uint16 blobStartIndex; uint16 numBlobs; uint24 offset; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlobReference {
        #[allow(missing_docs)]
        pub blobStartIndex: u16,
        #[allow(missing_docs)]
        pub numBlobs: u16,
        #[allow(missing_docs)]
        pub offset: alloy::sol_types::private::primitives::aliases::U24,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<16>,
            alloy::sol_types::sol_data::Uint<16>,
            alloy::sol_types::sol_data::Uint<24>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            u16,
            u16,
            alloy::sol_types::private::primitives::aliases::U24,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<BlobReference> for UnderlyingRustTuple<'_> {
            fn from(value: BlobReference) -> Self {
                (value.blobStartIndex, value.numBlobs, value.offset)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlobReference {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blobStartIndex: tuple.0,
                    numBlobs: tuple.1,
                    offset: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlobReference {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlobReference {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self.blobStartIndex),
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self.numBlobs),
                    <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::SolType>::tokenize(&self.offset),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for BlobReference {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for BlobReference {
            const NAME: &'static str = "BlobReference";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlobReference(uint16 blobStartIndex,uint16 numBlobs,uint24 offset)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.blobStartIndex,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.numBlobs)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.offset)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlobReference {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blobStartIndex,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.numBlobs,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.offset,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    16,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blobStartIndex,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    16,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.numBlobs,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    24,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.offset,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BlobSlice { bytes32[] blobHashes; uint24 offset; uint48 timestamp; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlobSlice {
        #[allow(missing_docs)]
        pub blobHashes: alloy::sol_types::private::Vec<
            alloy::sol_types::private::FixedBytes<32>,
        >,
        #[allow(missing_docs)]
        pub offset: alloy::sol_types::private::primitives::aliases::U24,
        #[allow(missing_docs)]
        pub timestamp: alloy::sol_types::private::primitives::aliases::U48,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Array<
                alloy::sol_types::sol_data::FixedBytes<32>,
            >,
            alloy::sol_types::sol_data::Uint<24>,
            alloy::sol_types::sol_data::Uint<48>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Vec<alloy::sol_types::private::FixedBytes<32>>,
            alloy::sol_types::private::primitives::aliases::U24,
            alloy::sol_types::private::primitives::aliases::U48,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<BlobSlice> for UnderlyingRustTuple<'_> {
            fn from(value: BlobSlice) -> Self {
                (value.blobHashes, value.offset, value.timestamp)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlobSlice {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blobHashes: tuple.0,
                    offset: tuple.1,
                    timestamp: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlobSlice {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlobSlice {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::FixedBytes<32>,
                    > as alloy_sol_types::SolType>::tokenize(&self.blobHashes),
                    <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::SolType>::tokenize(&self.offset),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for BlobSlice {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for BlobSlice {
            const NAME: &'static str = "BlobSlice";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlobSlice(bytes32[] blobHashes,uint24 offset,uint48 timestamp)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::FixedBytes<32>,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blobHashes)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.offset)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.timestamp)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlobSlice {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::FixedBytes<32>,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blobHashes,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        24,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.offset,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.timestamp,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Array<
                    alloy::sol_types::sol_data::FixedBytes<32>,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blobHashes,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    24,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.offset,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.timestamp,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`LibBlobs`](self) contract instance.

See the [wrapper's documentation](`LibBlobsInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> LibBlobsInstance<P, N> {
        LibBlobsInstance::<P, N>::new(address, provider)
    }
    /**A [`LibBlobs`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`LibBlobs`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct LibBlobsInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for LibBlobsInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("LibBlobsInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBlobsInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`LibBlobs`](self) contract instance.

See the [wrapper's documentation](`LibBlobsInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            provider: P,
        ) -> Self {
            Self {
                address,
                provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /// Returns a reference to the address.
        #[inline]
        pub const fn address(&self) -> &alloy_sol_types::private::Address {
            &self.address
        }
        /// Sets the address.
        #[inline]
        pub fn set_address(&mut self, address: alloy_sol_types::private::Address) {
            self.address = address;
        }
        /// Sets the address and returns `self`.
        pub fn at(mut self, address: alloy_sol_types::private::Address) -> Self {
            self.set_address(address);
            self
        }
        /// Returns a reference to the provider.
        #[inline]
        pub const fn provider(&self) -> &P {
            &self.provider
        }
    }
    impl<P: ::core::clone::Clone, N> LibBlobsInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> LibBlobsInstance<P, N> {
            LibBlobsInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBlobsInstance<P, N> {
        /// Creates a new call builder using this contract instance's provider and address.
        ///
        /// Note that the call can be any function call, not just those defined in this
        /// contract. Prefer using the other methods for building type-safe contract calls.
        pub fn call_builder<C: alloy_sol_types::SolCall>(
            &self,
            call: &C,
        ) -> alloy_contract::SolCallBuilder<&P, C, N> {
            alloy_contract::SolCallBuilder::new_sol(&self.provider, &self.address, call)
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBlobsInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
    }
}
///Module containing a contract's types and functions.
/**

```solidity
library LibBonds {
    type BondType is uint8;
    struct BondInstruction { uint48 proposalId; BondType bondType; address payer; address payee; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod LibBonds {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BondType(u8);
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<BondType> for u8 {
            #[inline]
            fn stv_to_tokens(
                &self,
            ) -> <alloy::sol_types::sol_data::Uint<
                8,
            > as alloy_sol_types::SolType>::Token<'_> {
                alloy_sol_types::private::SolTypeValue::<
                    alloy::sol_types::sol_data::Uint<8>,
                >::stv_to_tokens(self)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::SolType>::tokenize(self)
                    .0
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(self, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::SolType>::abi_encoded_size(self)
            }
        }
        #[automatically_derived]
        impl BondType {
            /// The Solidity type name.
            pub const NAME: &'static str = stringify!(@ name);
            /// Convert from the underlying value type.
            #[inline]
            pub const fn from_underlying(value: u8) -> Self {
                Self(value)
            }
            /// Return the underlying value.
            #[inline]
            pub const fn into_underlying(self) -> u8 {
                self.0
            }
            /// Return the single encoding of this value, delegating to the
            /// underlying type.
            #[inline]
            pub fn abi_encode(&self) -> alloy_sol_types::private::Vec<u8> {
                <Self as alloy_sol_types::SolType>::abi_encode(&self.0)
            }
            /// Return the packed encoding of this value, delegating to the
            /// underlying type.
            #[inline]
            pub fn abi_encode_packed(&self) -> alloy_sol_types::private::Vec<u8> {
                <Self as alloy_sol_types::SolType>::abi_encode_packed(&self.0)
            }
        }
        #[automatically_derived]
        impl From<u8> for BondType {
            fn from(value: u8) -> Self {
                Self::from_underlying(value)
            }
        }
        #[automatically_derived]
        impl From<BondType> for u8 {
            fn from(value: BondType) -> Self {
                value.into_underlying()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for BondType {
            type RustType = u8;
            type Token<'a> = <alloy::sol_types::sol_data::Uint<
                8,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = Self::NAME;
            const ENCODED_SIZE: Option<usize> = <alloy::sol_types::sol_data::Uint<
                8,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <alloy::sol_types::sol_data::Uint<
                8,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                Self::type_check(token).is_ok()
            }
            #[inline]
            fn type_check(token: &Self::Token<'_>) -> alloy_sol_types::Result<()> {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::SolType>::type_check(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::SolType>::detokenize(token)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BondType {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::topic_preimage_length(rust)
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(rust, out)
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic(rust)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BondInstruction { uint48 proposalId; BondType bondType; address payer; address payee; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BondInstruction {
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub bondType: <BondType as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub payer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub payee: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<48>,
            BondType,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Address,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            <BondType as alloy::sol_types::SolType>::RustType,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::Address,
        );
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<BondInstruction> for UnderlyingRustTuple<'_> {
            fn from(value: BondInstruction) -> Self {
                (value.proposalId, value.bondType, value.payer, value.payee)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BondInstruction {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposalId: tuple.0,
                    bondType: tuple.1,
                    payer: tuple.2,
                    payee: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BondInstruction {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BondInstruction {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalId),
                    <BondType as alloy_sol_types::SolType>::tokenize(&self.bondType),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.payer,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.payee,
                    ),
                )
            }
            #[inline]
            fn stv_abi_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encoded_size(&tuple)
            }
            #[inline]
            fn stv_eip712_data_word(&self) -> alloy_sol_types::Word {
                <Self as alloy_sol_types::SolStruct>::eip712_hash_struct(self)
            }
            #[inline]
            fn stv_abi_encode_packed_to(
                &self,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_encode_packed_to(&tuple, out)
            }
            #[inline]
            fn stv_abi_packed_encoded_size(&self) -> usize {
                if let Some(size) = <Self as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE {
                    return size;
                }
                let tuple = <UnderlyingRustTuple<
                    '_,
                > as ::core::convert::From<Self>>::from(self.clone());
                <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_packed_encoded_size(&tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolType for BondInstruction {
            type RustType = Self;
            type Token<'a> = <UnderlyingSolTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SOL_NAME: &'static str = <Self as alloy_sol_types::SolStruct>::NAME;
            const ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::ENCODED_SIZE;
            const PACKED_ENCODED_SIZE: Option<usize> = <UnderlyingSolTuple<
                '_,
            > as alloy_sol_types::SolType>::PACKED_ENCODED_SIZE;
            #[inline]
            fn valid_token(token: &Self::Token<'_>) -> bool {
                <UnderlyingSolTuple<'_> as alloy_sol_types::SolType>::valid_token(token)
            }
            #[inline]
            fn detokenize(token: Self::Token<'_>) -> Self::RustType {
                let tuple = <UnderlyingSolTuple<
                    '_,
                > as alloy_sol_types::SolType>::detokenize(token);
                <Self as ::core::convert::From<UnderlyingRustTuple<'_>>>::from(tuple)
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolStruct for BondInstruction {
            const NAME: &'static str = "BondInstruction";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BondInstruction(uint48 proposalId,uint8 bondType,address payer,address payee)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                alloy_sol_types::private::Vec::new()
            }
            #[inline]
            fn eip712_encode_type() -> alloy_sol_types::private::Cow<'static, str> {
                <Self as alloy_sol_types::SolStruct>::eip712_root_type()
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalId)
                        .0,
                    <BondType as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondType,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.payer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.payee,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BondInstruction {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalId,
                    )
                    + <BondType as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondType,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.payer,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.payee,
                    )
            }
            #[inline]
            fn encode_topic_preimage(
                rust: &Self::RustType,
                out: &mut alloy_sol_types::private::Vec<u8>,
            ) {
                out.reserve(
                    <Self as alloy_sol_types::EventTopic>::topic_preimage_length(rust),
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposalId,
                    out,
                );
                <BondType as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondType,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.payer,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.payee,
                    out,
                );
            }
            #[inline]
            fn encode_topic(
                rust: &Self::RustType,
            ) -> alloy_sol_types::abi::token::WordToken {
                let mut out = alloy_sol_types::private::Vec::new();
                <Self as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    rust,
                    &mut out,
                );
                alloy_sol_types::abi::token::WordToken(
                    alloy_sol_types::private::keccak256(out),
                )
            }
        }
    };
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`LibBonds`](self) contract instance.

See the [wrapper's documentation](`LibBondsInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> LibBondsInstance<P, N> {
        LibBondsInstance::<P, N>::new(address, provider)
    }
    /**A [`LibBonds`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`LibBonds`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct LibBondsInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for LibBondsInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("LibBondsInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBondsInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`LibBonds`](self) contract instance.

See the [wrapper's documentation](`LibBondsInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            provider: P,
        ) -> Self {
            Self {
                address,
                provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /// Returns a reference to the address.
        #[inline]
        pub const fn address(&self) -> &alloy_sol_types::private::Address {
            &self.address
        }
        /// Sets the address.
        #[inline]
        pub fn set_address(&mut self, address: alloy_sol_types::private::Address) {
            self.address = address;
        }
        /// Sets the address and returns `self`.
        pub fn at(mut self, address: alloy_sol_types::private::Address) -> Self {
            self.set_address(address);
            self
        }
        /// Returns a reference to the provider.
        #[inline]
        pub const fn provider(&self) -> &P {
            &self.provider
        }
    }
    impl<P: ::core::clone::Clone, N> LibBondsInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> LibBondsInstance<P, N> {
            LibBondsInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBondsInstance<P, N> {
        /// Creates a new call builder using this contract instance's provider and address.
        ///
        /// Note that the call can be any function call, not just those defined in this
        /// contract. Prefer using the other methods for building type-safe contract calls.
        pub fn call_builder<C: alloy_sol_types::SolCall>(
            &self,
            call: &C,
        ) -> alloy_contract::SolCallBuilder<&P, C, N> {
            alloy_contract::SolCallBuilder::new_sol(&self.provider, &self.address, call)
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LibBondsInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
    }
}
/**

Generated by the following Solidity interface...
```solidity
library ICheckpointStore {
    struct Checkpoint {
        uint48 blockNumber;
        bytes32 blockHash;
        bytes32 stateRoot;
    }
}

library IInbox {
    struct CoreState {
        uint48 nextProposalId;
        uint48 lastProposalBlockId;
        uint48 lastFinalizedProposalId;
        uint48 lastCheckpointTimestamp;
        bytes32 lastFinalizedTransitionHash;
        bytes32 bondInstructionsHash;
    }
    struct Derivation {
        uint48 originBlockNumber;
        bytes32 originBlockHash;
        uint8 basefeeSharingPctg;
        DerivationSource[] sources;
    }
    struct DerivationSource {
        bool isForcedInclusion;
        LibBlobs.BlobSlice blobSlice;
    }
    struct Proposal {
        uint48 id;
        uint48 timestamp;
        uint48 endOfSubmissionWindowTimestamp;
        address proposer;
        bytes32 coreStateHash;
        bytes32 derivationHash;
    }
    struct ProposeInput {
        uint48 deadline;
        CoreState coreState;
        Proposal[] parentProposals;
        LibBlobs.BlobReference blobReference;
        TransitionRecord[] transitionRecords;
        ICheckpointStore.Checkpoint checkpoint;
        uint8 numForcedInclusions;
    }
    struct ProposedEventPayload {
        Proposal proposal;
        Derivation derivation;
        CoreState coreState;
        LibBonds.BondInstruction[] bondInstructions;
    }
    struct ProveInput {
        Proposal[] proposals;
        Transition[] transitions;
        TransitionMetadata[] metadata;
    }
    struct ProvedEventPayload {
        uint48 proposalId;
        Transition transition;
        TransitionRecord transitionRecord;
        TransitionMetadata metadata;
    }
    struct Transition {
        bytes32 proposalHash;
        bytes32 parentTransitionHash;
        ICheckpointStore.Checkpoint checkpoint;
    }
    struct TransitionMetadata {
        address designatedProver;
        address actualProver;
    }
    struct TransitionRecord {
        uint8 span;
        LibBonds.BondInstruction[] bondInstructions;
        bytes32 transitionHash;
        bytes32 checkpointHash;
    }
}

library LibBlobs {
    struct BlobReference {
        uint16 blobStartIndex;
        uint16 numBlobs;
        uint24 offset;
    }
    struct BlobSlice {
        bytes32[] blobHashes;
        uint24 offset;
        uint48 timestamp;
    }
}

library LibBonds {
    type BondType is uint8;
    struct BondInstruction {
        uint48 proposalId;
        BondType bondType;
        address payer;
        address payee;
    }
}

interface CodecOptimized {
    error InconsistentLengths();
    error InvalidBondType();
    error LengthExceedsUint16();
    error MetadataLengthMismatch();
    error ProposalTransitionLengthMismatch();

    function decodeProposeInput(bytes memory _data) external pure returns (IInbox.ProposeInput memory input_);
    function decodeProposedEvent(bytes memory _data) external pure returns (IInbox.ProposedEventPayload memory payload_);
    function decodeProveInput(bytes memory _data) external pure returns (IInbox.ProveInput memory input_);
    function decodeProvedEvent(bytes memory _data) external pure returns (IInbox.ProvedEventPayload memory payload_);
    function encodeProposeInput(IInbox.ProposeInput memory _input) external pure returns (bytes memory encoded_);
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload) external pure returns (bytes memory encoded_);
    function encodeProveInput(IInbox.ProveInput memory _input) external pure returns (bytes memory encoded_);
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload) external pure returns (bytes memory encoded_);
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external pure returns (bytes32);
    function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32);
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32);
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32);
    function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32);
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord) external pure returns (bytes26);
    function hashTransitionsWithMetadata(IInbox.Transition[] memory _transitions, IInbox.TransitionMetadata[] memory _metadata) external pure returns (bytes32);
}
```

...which was generated by the following JSON ABI:
```json
[
  {
    "type": "function",
    "name": "decodeProposeInput",
    "inputs": [
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "input_",
        "type": "tuple",
        "internalType": "struct IInbox.ProposeInput",
        "components": [
          {
            "name": "deadline",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "coreState",
            "type": "tuple",
            "internalType": "struct IInbox.CoreState",
            "components": [
              {
                "name": "nextProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastCheckpointTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "bondInstructionsHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "parentProposals",
            "type": "tuple[]",
            "internalType": "struct IInbox.Proposal[]",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "blobReference",
            "type": "tuple",
            "internalType": "struct LibBlobs.BlobReference",
            "components": [
              {
                "name": "blobStartIndex",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "numBlobs",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "offset",
                "type": "uint24",
                "internalType": "uint24"
              }
            ]
          },
          {
            "name": "transitionRecords",
            "type": "tuple[]",
            "internalType": "struct IInbox.TransitionRecord[]",
            "components": [
              {
                "name": "span",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "bondInstructions",
                "type": "tuple[]",
                "internalType": "struct LibBonds.BondInstruction[]",
                "components": [
                  {
                    "name": "proposalId",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "bondType",
                    "type": "uint8",
                    "internalType": "enum LibBonds.BondType"
                  },
                  {
                    "name": "payer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "payee",
                    "type": "address",
                    "internalType": "address"
                  }
                ]
              },
              {
                "name": "transitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "checkpoint",
            "type": "tuple",
            "internalType": "struct ICheckpointStore.Checkpoint",
            "components": [
              {
                "name": "blockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "blockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "stateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "numForcedInclusions",
            "type": "uint8",
            "internalType": "uint8"
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "decodeProposedEvent",
    "inputs": [
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "payload_",
        "type": "tuple",
        "internalType": "struct IInbox.ProposedEventPayload",
        "components": [
          {
            "name": "proposal",
            "type": "tuple",
            "internalType": "struct IInbox.Proposal",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "derivation",
            "type": "tuple",
            "internalType": "struct IInbox.Derivation",
            "components": [
              {
                "name": "originBlockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "originBlockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "basefeeSharingPctg",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "sources",
                "type": "tuple[]",
                "internalType": "struct IInbox.DerivationSource[]",
                "components": [
                  {
                    "name": "isForcedInclusion",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "blobSlice",
                    "type": "tuple",
                    "internalType": "struct LibBlobs.BlobSlice",
                    "components": [
                      {
                        "name": "blobHashes",
                        "type": "bytes32[]",
                        "internalType": "bytes32[]"
                      },
                      {
                        "name": "offset",
                        "type": "uint24",
                        "internalType": "uint24"
                      },
                      {
                        "name": "timestamp",
                        "type": "uint48",
                        "internalType": "uint48"
                      }
                    ]
                  }
                ]
              }
            ]
          },
          {
            "name": "coreState",
            "type": "tuple",
            "internalType": "struct IInbox.CoreState",
            "components": [
              {
                "name": "nextProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastCheckpointTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "bondInstructionsHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "bondInstructions",
            "type": "tuple[]",
            "internalType": "struct LibBonds.BondInstruction[]",
            "components": [
              {
                "name": "proposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "bondType",
                "type": "uint8",
                "internalType": "enum LibBonds.BondType"
              },
              {
                "name": "payer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "payee",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "decodeProveInput",
    "inputs": [
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "input_",
        "type": "tuple",
        "internalType": "struct IInbox.ProveInput",
        "components": [
          {
            "name": "proposals",
            "type": "tuple[]",
            "internalType": "struct IInbox.Proposal[]",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "transitions",
            "type": "tuple[]",
            "internalType": "struct IInbox.Transition[]",
            "components": [
              {
                "name": "proposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "parentTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpoint",
                "type": "tuple",
                "internalType": "struct ICheckpointStore.Checkpoint",
                "components": [
                  {
                    "name": "blockNumber",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  },
                  {
                    "name": "stateRoot",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "metadata",
            "type": "tuple[]",
            "internalType": "struct IInbox.TransitionMetadata[]",
            "components": [
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "decodeProvedEvent",
    "inputs": [
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "payload_",
        "type": "tuple",
        "internalType": "struct IInbox.ProvedEventPayload",
        "components": [
          {
            "name": "proposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "transition",
            "type": "tuple",
            "internalType": "struct IInbox.Transition",
            "components": [
              {
                "name": "proposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "parentTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpoint",
                "type": "tuple",
                "internalType": "struct ICheckpointStore.Checkpoint",
                "components": [
                  {
                    "name": "blockNumber",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  },
                  {
                    "name": "stateRoot",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "transitionRecord",
            "type": "tuple",
            "internalType": "struct IInbox.TransitionRecord",
            "components": [
              {
                "name": "span",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "bondInstructions",
                "type": "tuple[]",
                "internalType": "struct LibBonds.BondInstruction[]",
                "components": [
                  {
                    "name": "proposalId",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "bondType",
                    "type": "uint8",
                    "internalType": "enum LibBonds.BondType"
                  },
                  {
                    "name": "payer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "payee",
                    "type": "address",
                    "internalType": "address"
                  }
                ]
              },
              {
                "name": "transitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "metadata",
            "type": "tuple",
            "internalType": "struct IInbox.TransitionMetadata",
            "components": [
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "encodeProposeInput",
    "inputs": [
      {
        "name": "_input",
        "type": "tuple",
        "internalType": "struct IInbox.ProposeInput",
        "components": [
          {
            "name": "deadline",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "coreState",
            "type": "tuple",
            "internalType": "struct IInbox.CoreState",
            "components": [
              {
                "name": "nextProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastCheckpointTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "bondInstructionsHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "parentProposals",
            "type": "tuple[]",
            "internalType": "struct IInbox.Proposal[]",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "blobReference",
            "type": "tuple",
            "internalType": "struct LibBlobs.BlobReference",
            "components": [
              {
                "name": "blobStartIndex",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "numBlobs",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "offset",
                "type": "uint24",
                "internalType": "uint24"
              }
            ]
          },
          {
            "name": "transitionRecords",
            "type": "tuple[]",
            "internalType": "struct IInbox.TransitionRecord[]",
            "components": [
              {
                "name": "span",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "bondInstructions",
                "type": "tuple[]",
                "internalType": "struct LibBonds.BondInstruction[]",
                "components": [
                  {
                    "name": "proposalId",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "bondType",
                    "type": "uint8",
                    "internalType": "enum LibBonds.BondType"
                  },
                  {
                    "name": "payer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "payee",
                    "type": "address",
                    "internalType": "address"
                  }
                ]
              },
              {
                "name": "transitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "checkpoint",
            "type": "tuple",
            "internalType": "struct ICheckpointStore.Checkpoint",
            "components": [
              {
                "name": "blockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "blockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "stateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "numForcedInclusions",
            "type": "uint8",
            "internalType": "uint8"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "encoded_",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "encodeProposedEvent",
    "inputs": [
      {
        "name": "_payload",
        "type": "tuple",
        "internalType": "struct IInbox.ProposedEventPayload",
        "components": [
          {
            "name": "proposal",
            "type": "tuple",
            "internalType": "struct IInbox.Proposal",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "derivation",
            "type": "tuple",
            "internalType": "struct IInbox.Derivation",
            "components": [
              {
                "name": "originBlockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "originBlockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "basefeeSharingPctg",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "sources",
                "type": "tuple[]",
                "internalType": "struct IInbox.DerivationSource[]",
                "components": [
                  {
                    "name": "isForcedInclusion",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "blobSlice",
                    "type": "tuple",
                    "internalType": "struct LibBlobs.BlobSlice",
                    "components": [
                      {
                        "name": "blobHashes",
                        "type": "bytes32[]",
                        "internalType": "bytes32[]"
                      },
                      {
                        "name": "offset",
                        "type": "uint24",
                        "internalType": "uint24"
                      },
                      {
                        "name": "timestamp",
                        "type": "uint48",
                        "internalType": "uint48"
                      }
                    ]
                  }
                ]
              }
            ]
          },
          {
            "name": "coreState",
            "type": "tuple",
            "internalType": "struct IInbox.CoreState",
            "components": [
              {
                "name": "nextProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastCheckpointTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "bondInstructionsHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "bondInstructions",
            "type": "tuple[]",
            "internalType": "struct LibBonds.BondInstruction[]",
            "components": [
              {
                "name": "proposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "bondType",
                "type": "uint8",
                "internalType": "enum LibBonds.BondType"
              },
              {
                "name": "payer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "payee",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "encoded_",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "encodeProveInput",
    "inputs": [
      {
        "name": "_input",
        "type": "tuple",
        "internalType": "struct IInbox.ProveInput",
        "components": [
          {
            "name": "proposals",
            "type": "tuple[]",
            "internalType": "struct IInbox.Proposal[]",
            "components": [
              {
                "name": "id",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endOfSubmissionWindowTimestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "coreStateHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "derivationHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "transitions",
            "type": "tuple[]",
            "internalType": "struct IInbox.Transition[]",
            "components": [
              {
                "name": "proposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "parentTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpoint",
                "type": "tuple",
                "internalType": "struct ICheckpointStore.Checkpoint",
                "components": [
                  {
                    "name": "blockNumber",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  },
                  {
                    "name": "stateRoot",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "metadata",
            "type": "tuple[]",
            "internalType": "struct IInbox.TransitionMetadata[]",
            "components": [
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "encoded_",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "encodeProvedEvent",
    "inputs": [
      {
        "name": "_payload",
        "type": "tuple",
        "internalType": "struct IInbox.ProvedEventPayload",
        "components": [
          {
            "name": "proposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "transition",
            "type": "tuple",
            "internalType": "struct IInbox.Transition",
            "components": [
              {
                "name": "proposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "parentTransitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpoint",
                "type": "tuple",
                "internalType": "struct ICheckpointStore.Checkpoint",
                "components": [
                  {
                    "name": "blockNumber",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  },
                  {
                    "name": "stateRoot",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "transitionRecord",
            "type": "tuple",
            "internalType": "struct IInbox.TransitionRecord",
            "components": [
              {
                "name": "span",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "bondInstructions",
                "type": "tuple[]",
                "internalType": "struct LibBonds.BondInstruction[]",
                "components": [
                  {
                    "name": "proposalId",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "bondType",
                    "type": "uint8",
                    "internalType": "enum LibBonds.BondType"
                  },
                  {
                    "name": "payer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "payee",
                    "type": "address",
                    "internalType": "address"
                  }
                ]
              },
              {
                "name": "transitionHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "metadata",
            "type": "tuple",
            "internalType": "struct IInbox.TransitionMetadata",
            "components": [
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "encoded_",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashCheckpoint",
    "inputs": [
      {
        "name": "_checkpoint",
        "type": "tuple",
        "internalType": "struct ICheckpointStore.Checkpoint",
        "components": [
          {
            "name": "blockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "blockHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "stateRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashCoreState",
    "inputs": [
      {
        "name": "_coreState",
        "type": "tuple",
        "internalType": "struct IInbox.CoreState",
        "components": [
          {
            "name": "nextProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "lastProposalBlockId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "lastFinalizedProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "lastCheckpointTimestamp",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "lastFinalizedTransitionHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashDerivation",
    "inputs": [
      {
        "name": "_derivation",
        "type": "tuple",
        "internalType": "struct IInbox.Derivation",
        "components": [
          {
            "name": "originBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "originBlockHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "basefeeSharingPctg",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "sources",
            "type": "tuple[]",
            "internalType": "struct IInbox.DerivationSource[]",
            "components": [
              {
                "name": "isForcedInclusion",
                "type": "bool",
                "internalType": "bool"
              },
              {
                "name": "blobSlice",
                "type": "tuple",
                "internalType": "struct LibBlobs.BlobSlice",
                "components": [
                  {
                    "name": "blobHashes",
                    "type": "bytes32[]",
                    "internalType": "bytes32[]"
                  },
                  {
                    "name": "offset",
                    "type": "uint24",
                    "internalType": "uint24"
                  },
                  {
                    "name": "timestamp",
                    "type": "uint48",
                    "internalType": "uint48"
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashProposal",
    "inputs": [
      {
        "name": "_proposal",
        "type": "tuple",
        "internalType": "struct IInbox.Proposal",
        "components": [
          {
            "name": "id",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "timestamp",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "endOfSubmissionWindowTimestamp",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "proposer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "coreStateHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "derivationHash",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashTransition",
    "inputs": [
      {
        "name": "_transition",
        "type": "tuple",
        "internalType": "struct IInbox.Transition",
        "components": [
          {
            "name": "proposalHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "parentTransitionHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "checkpoint",
            "type": "tuple",
            "internalType": "struct ICheckpointStore.Checkpoint",
            "components": [
              {
                "name": "blockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "blockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "stateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashTransitionRecord",
    "inputs": [
      {
        "name": "_transitionRecord",
        "type": "tuple",
        "internalType": "struct IInbox.TransitionRecord",
        "components": [
          {
            "name": "span",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "bondInstructions",
            "type": "tuple[]",
            "internalType": "struct LibBonds.BondInstruction[]",
            "components": [
              {
                "name": "proposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "bondType",
                "type": "uint8",
                "internalType": "enum LibBonds.BondType"
              },
              {
                "name": "payer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "payee",
                "type": "address",
                "internalType": "address"
              }
            ]
          },
          {
            "name": "transitionHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "checkpointHash",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes26",
        "internalType": "bytes26"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hashTransitionsWithMetadata",
    "inputs": [
      {
        "name": "_transitions",
        "type": "tuple[]",
        "internalType": "struct IInbox.Transition[]",
        "components": [
          {
            "name": "proposalHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "parentTransitionHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "checkpoint",
            "type": "tuple",
            "internalType": "struct ICheckpointStore.Checkpoint",
            "components": [
              {
                "name": "blockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "blockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "stateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          }
        ]
      },
      {
        "name": "_metadata",
        "type": "tuple[]",
        "internalType": "struct IInbox.TransitionMetadata[]",
        "components": [
          {
            "name": "designatedProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "actualProver",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "error",
    "name": "InconsistentLengths",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidBondType",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LengthExceedsUint16",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MetadataLengthMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ProposalTransitionLengthMismatch",
    "inputs": []
  }
]
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod CodecOptimized {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x6080604052348015600e575f5ffd5b50613fbb8061001c5f395ff3fe608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c806382d7058b11610093578063b8b02e0e11610063578063b8b02e0e1461020c578063dc5a8bf81461021f578063edbacd4414610232578063eedec10214610252575f5ffd5b806382d7058b146101b35780638f6d0e1a146101c6578063a1ec9333146101d9578063afb63ad4146101ec575f5ffd5b806326303962116100ce578063263039621461014d5780635d27cc951461016d5780637989aa101461018d5780637a9a552a146101a0575f5ffd5b80631f397067146100f45780631fe06ab41461011a578063261bf6341461012d575b5f5ffd5b610107610102366004612b45565b61027d565b6040519081526020015b60405180910390f35b610107610128366004612b74565b61029b565b61014061013b366004612b8e565b6102b3565b6040516101119190612bc5565b61016061015b366004612bfa565b6102c6565b6040516101119190612d50565b61018061017b366004612bfa565b610313565b6040516101119190612ea6565b61010761019b36600461300a565b610359565b6101076101ae36600461306b565b610371565b6101406101c1366004613103565b610427565b6101406101d436600461313a565b61043a565b6101076101e7366004612b74565b61044d565b6101ff6101fa366004612bfa565b610465565b6040516101119190613206565b61010761021a3660046132e9565b6104ab565b61014061022d36600461331a565b6104bd565b610245610240366004612bfa565b6104d0565b604051610111919061334b565b6102656102603660046132e9565b610532565b60405165ffffffffffff199091168152602001610111565b5f610295610290368490038401846135db565b610544565b92915050565b5f6102956102ae36849003840184613669565b610578565b60606102956102c183613995565b6105d3565b6102ce612919565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061081392505050565b9392505050565b61031b61298d565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610ac592505050565b5f61029561036c36849003840184613a5e565b611005565b5f61041e8585808060200260200160405190810160405280939291908181526020015f905b828210156103c2576103b360a083028601368190038101906135db565b81526020019060010190610396565b50505050508484808060200260200160405190810160405280939291908181526020015f905b828210156104145761040560408302860136819003810190613ab4565b815260200190600101906103e8565b5050505050611036565b95945050505050565b606061029561043583613cbb565b6111ed565b606061029561044883613d4d565b611566565b5f61029561046036849003840184613dc5565b61177d565b61046d612a06565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506117f492505050565b5f6102956104b883613ddf565b611a65565b60606102956104cb83613e4f565b611bd5565b6104f460405180606001604052806060815260200160608152602001606081525090565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611d3a92505050565b5f61029561053f83613f46565b611fa0565b5f610295825f0151836020015161055e8560400151611005565b604080519384526020840192909252908201526060902090565b805160208083015160408085015160608087015160808089015160a0808b0151875165ffffffffffff9b8c168152988b169989019990995294891695870195909552961690840152938201529182015260c090205f90610295565b60605f6105ed836040015184608001518560a001516120f1565b9050806001600160401b038111156106075761060761344c565b6040519080825280601f01601f191660200182016040528015610631576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c8401528051604090810151831b603285015281516060015190921b6038840152805160800151603e8401525160a00151605e83015284015151909250607e8301906106a39061217c565b60408401515160f01b81526002015f5b8460400151518110156106f1576106e782866040015183815181106106da576106da613f51565b60200260200101516121a2565b91506001016106b3565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b600482015260808401515160079091019061072f9061217c565b60808401515160f01b81526002015f5b84608001515181101561077d57610773828660800151838151811061076657610766613f51565b60200260200101516121f4565b915060010161073f565b5060a0840151515f9065ffffffffffff161580156107a1575060a085015160200151155b80156107b3575060a085015160400151155b90506107cc82826107c557600161227c565b5f5b61227c565b9150806107fb5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b610809828660c0015161227c565b9150505050919050565b61081b612919565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156108e2576108e261344c565b60405190808252806020026020018201604052801561093257816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816109005790505b506040840151602001525f5b8161ffff16811015610abd57825160d01c60068401856040015160200151838151811061096d5761096d613f51565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109b457604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109c9576109c9612c66565b85604001516020015183815181106109e3576109e3613f51565b6020026020010151602001906002811115610a0057610a00612c66565b90816002811115610a1357610a13612c66565b905250835160601c601485018660400151602001518481518110610a3957610a39613f51565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610a7184805160601c91601490910190565b8660400151602001518481518110610a8b57610a8b613f51565b6020026020010151606001819650826001600160a01b03166001600160a01b031681525050505080600101905061093e565b505050919050565b610acd61298d565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610b5b57610b5b61344c565b604051908082528060200260200182016040528015610bbe57816020015b610bab6040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610b795790505b506020840151606001525f5b8161ffff16811015610d8c578251602085015160600151805160019095019460f89290921c91821515919084908110610c0557610c05613f51565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610c3857610c3861344c565b604051908082528060200260200182016040528015610c61578160200160208202803683370190505b508660200151606001518481518110610c7c57610c7c613f51565b6020908102919091018101510151525f5b8161ffff16811015610cf1578551602087018860200151606001518681518110610cb957610cb9613f51565b6020026020010151602001515f01518381518110610cd957610cd9613f51565b60209081029190910101919091529550600101610c8d565b50845160e81c600386018760200151606001518581518110610d1557610d15613f51565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610d5757610d57613f51565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610bca565b5081518351608090810191909152602080840151855160a090810191909152604080860151818801805160d092831c90526046880151815190831c950194909452604c870151845190821c92019190915260528601518351911c606090910152605885015182519093019290925260788401519051909101526098820151609a9092019160f01c8015610abd578061ffff166001600160401b03811115610e3557610e3561344c565b604051908082528060200260200182016040528015610e8557816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f19909201910181610e535790505b5060608501525f5b8161ffff16811015610ffc57835160d01c6006850186606001518381518110610eb857610eb8613f51565b602090810291909101015165ffffffffffff9290921690915280516001909101945060f81c6002811115610eff57604051631ed6413560e31b815260040160405180910390fd5b8060ff166002811115610f1457610f14612c66565b86606001518381518110610f2a57610f2a613f51565b6020026020010151602001906002811115610f4757610f47612c66565b90816002811115610f5a57610f5a612c66565b905250845160601c6014860187606001518481518110610f7c57610f7c613f51565b6020026020010151604001819750826001600160a01b03166001600160a01b03168152505050610fb485805160601c91601490910190565b87606001518481518110610fca57610fca613f51565b6020026020010151606001819750826001600160a01b03166001600160a01b0316815250505050806001019050610e8d565b50505050919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610295565b5f81518351146110595760405163b1f40f7760e01b815260040160405180910390fd5b82515f819003611079575f516020613f665f395f51905f52915050610295565b806001036110dc575f6110be855f8151811061109757611097613f51565b6020026020010151855f815181106110b1576110b1613f51565b6020026020010151612288565b90506110d382825f9182526020526040902090565b92505050610295565b80600203611150575f6110fa855f8151811061109757611097613f51565b90505f61112e8660018151811061111357611113613f51565b6020026020010151866001815181106110b1576110b1613f51565b6040805194855260208501939093529183019190915250606090209050610295565b604080516001830181526002830160051b8101909152602081018290525f5b828110156111c6576111bd82826001016111ae89858151811061119457611194613f51565b60200260200101518986815181106110b1576110b1613f51565b60019190910160051b82015290565b5060010161116f565b50805160051b602082012061041e8280516040516001820160051b83011490151060061b52565b60605f61120683602001516060015184606001516122db565b9050806001600160401b038111156112205761122061344c565b6040519080825280601f01601f19166020018201604052801561124a576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c8301906112b590829061227c565b602085015160600151519091506112cb8161217c565b6112db828260f01b815260020190565b91505f5b8181101561144d5761132183876020015160600151838151811061130557611305613f51565b60200260200101515f015161131a575f61227c565b600161227c565b92505f866020015160600151828151811061133e5761133e613f51565b6020026020010151602001515f01515190506113598161217c565b611369848260f01b815260020190565b93505f5b818110156113cd576113c385896020015160600151858151811061139357611393613f51565b6020026020010151602001515f015183815181106113b3576113b3613f51565b6020026020010151815260200190565b945060010161136d565b506114078488602001516060015184815181106113ec576113ec613f51565b6020026020010151602001516020015160e81b815260030190565b935061144284886020015160600151848151811061142757611427613f51565b6020026020010151602001516040015160d01b815260060190565b9350506001016112df565b5084516080908101518352855160a090810151602080860191909152604080890180515160d090811b83890152815190930151831b6046880152805190910151821b604c870152805160609081015190921b60528701528051909301516058860152915101516078840152850151516098909201916114cb8161217c565b6114db838260f01b815260020190565b92505f5b8181101561155c575f876060015182815181106114fe576114fe613f51565b6020026020010151905061151b85825f015160d01b815260060190565b945061153785826020015160028111156107c7576107c7612c66565b6040820151606090811b82529182015190911b601482015260280193506001016114df565b5050505050919050565b60408101516020015151606090602f0260f701806001600160401b038111156115915761159161344c565b6040519080825280601f01601f1916602001820160405280156115bb576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061162390829061227c565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b6054840152510151516068909101915061166f9061217c565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610abd576116c88286604001516020015183815181106116b2576116b2613f51565b60200260200101515f015160d01b815260060190565b91506117058286604001516020015183815181106116e8576116e8613f51565b60200260200101516020015160028111156107c7576107c7612c66565b915061173c82866040015160200151838151811061172557611725613f51565b60200260200101516040015160601b815260140190565b915061177382866040015160200151838151811061175c5761175c613f51565b60200260200101516060015160601b815260140190565b9150600101611683565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b905061030c8184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b6117fc612a06565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c9301929092526032840151825190821c60409091015260388401518251911c606090910152603e8301518151608090810191909152605e840151915160a00191909152607e8301519083019060f01c806001600160401b0381111561188a5761188a61344c565b6040519080825280602002602001820160405280156118c357816020015b6118b0612ad1565b8152602001906001900390816118a85790505b5060408401525f5b8161ffff1681101561190e576118e08361232b565b856040015183815181106118f6576118f6613f51565b602090810291909101019190915292506001016118cb565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156119675761196761344c565b6040519080825280602002602001820160405280156119c357816020015b6119b060405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816119855790505b5060808501525f5b8161ffff16811015611a0e576119e084612388565b866080015183815181106119f6576119f6613f51565b602090810291909101019190915293506001016119cb565b50825160019384019360f89190911c90819003611a5357835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f03611aae575f516020613f665f395f51905f529150611bb4565b80600103611af757611af0815f1b611ae287606001515f81518110611ad557611ad5613f51565b6020026020010151612499565b5f9182526020526040902090565b9150611bb4565b80600203611b3857611af0815f1b611b1e87606001515f81518110611ad557611ad5613f51565b61055e8860600151600181518110611ad557611ad5613f51565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611b8957611b8082826001016111ae8a606001518581518110611ad557611ad5613f51565b50600101611b57565b50805160051b60208201209250611bb28180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f611bee835f015184602001518560400151612511565b9050806001600160401b03811115611c0857611c0861344c565b6040519080825280601f01601f191660200182016040528015611c32576020820181803683370190505b508351519092506020830190611c479061217c565b83515160f01b81526002015f5b845151811015611c8e57611c8482865f01518381518110611c7757611c77613f51565b6020026020010151612566565b9150600101611c54565b50611c9d84602001515161217c565b60208401515160f01b81526002015f5b846020015151811015611ceb57611ce18286602001518381518110611cd457611cd4613f51565b60200260200101516125a0565b9150600101611cad565b50611cfa84604001515161217c565b5f5b846040015151811015610abd57611d308286604001518381518110611d2357611d23613f51565b60200260200101516125dc565b9150600101611cfc565b611d5e60405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611d8357611d8361344c565b604051908082528060200260200182016040528015611dbc57816020015b611da9612ad1565b815260200190600190039081611da15790505b5083525f5b8161ffff16811015611e0257611dd6836125fd565b8551805184908110611dea57611dea613f51565b60209081029190910101919091529250600101611dc1565b50815160029092019160f01c61ffff82168114611e3257604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611e4e57611e4e61344c565b604051908082528060200260200182016040528015611e8757816020015b611e74612b05565b815260200190600190039081611e6c5790505b5060208501525f5b8161ffff16811015611ed257611ea484612645565b86602001518381518110611eba57611eba613f51565b60209081029190910101919091529350600101611e8f565b508061ffff166001600160401b03811115611eef57611eef61344c565b604051908082528060200260200182016040528015611f3357816020015b604080518082019091525f8082526020820152815260200190600190039081611f0d5790505b5060408501525f5b8161ffff16811015610ffc57604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611f8857611f88613f51565b60209081029190910101919091529350600101611f3b565b6020810151515f908190808203611fc6575f516020613f665f395f51905f5291506120be565b8060010361200157611ffa815f1b611ae286602001515f81518110611fed57611fed613f51565b602002602001015161268f565b91506120be565b8060020361204257611ffa815f1b61202886602001515f81518110611fed57611fed613f51565b61055e8760200151600181518110611fed57611fed613f51565b604080516001830181526002830160051b8101909152602081018290525f5b828110156120935761208a82826001016111ae89602001518581518110611fed57611fed613f51565b50600101612061565b50805160051b602082012092506120bc8180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f9061041e565b8051606b905f9065ffffffffffff1615801561210f57506020830151155b801561211d57506040830151155b90508061212b576046820191505b8451606602820191505f5b84518110156121735784818151811061215157612151613f51565b60200260200101516020015151602f0260430183019250806001019050612136565b50509392505050565b61ffff81111561219f5760405163161e7a6b60e11b815260040160405180910390fd5b50565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a083015160208201908152915060400161030c565b5f61220283835f015161227c565b905061221282602001515161217c565b60208201515160f01b81526002015f5b82602001515181101561226057612256828460200151838151811061224957612249613f51565b60200260200101516126fb565b9150600101612222565b506040828101518252606083015160208301908152910161030c565b5f818353505060010190565b5f61030c835f015184602001516122a28660400151611005565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b60e95f5b835181101561231f578381815181106122fa576122fa613f51565b6020026020010151602001515f015151602002600c01820191508060010190506122df565b509051602f0201919050565b612333612ad1565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b6123b360405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156123df576123df61344c565b60405190808252806020026020018201604052801561242f57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816123fd5790505b5060208401525f5b8161ffff1681101561247a5761244c83612746565b8560200151838151811061246257612462613f51565b60209081029190910101919091529250600101612437565b5050805160408381019190915260208201516060840152919391019150565b5f5f6124ab83602001515f01516127de565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff9092169082015260609020909150612509845f01516124f4575f6124f7565b60015b60ff16825f9182526020526040902090565b949350505050565b5f825184511461253457604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461255657604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b908301908152602683016121d7565b8051825260208082015181840152604080830180515160d01b82860152805190920151604685015290510151606683019081526086830161030c565b805160601b82525f60148301602083015160601b815290506014810161030c565b612605612ad1565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c60408201526026820180516046840161236d565b61264d612b05565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610295825f015165ffffffffffff165f1b836020015160028111156126b7576126b7612c66565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f60068301905061272381836020015160028111156107c7576107c7612c66565b6040830151606090811b825280840151901b60148201908152915060280161030c565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c80600281111561278f5761278f612c66565b836020019060028111156127a5576127a5612c66565b908160028111156127b8576127b8612c66565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f908082036127fe57505f516020613f665f395f51905f5292915050565b806001036128345761030c815f1b845f8151811061281e5761281e613f51565b60200260200101515f9182526020526040902090565b806002036128915761030c815f1b845f8151811061285457612854613f51565b60200260200101518560018151811061286f5761286f613f51565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b828110156128f2576128e982826001018784815181106128d2576128d2613f51565b602002602001015160019190910160051b82015290565b506001016128b0565b50805160051b60208201206125098280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff16815260200161293a612b05565b815260200161296a60405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001612988604080518082019091525f808252602082015290565b905290565b60405180608001604052806129a0612ad1565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160c0810182525f8082526020828101829052928201819052606082018190526080820181905260a08201529101908152602001606081525090565b6040518060e001604052805f65ffffffffffff168152602001612a566040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b815260200160608152602001612a9060405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b815260200160608152602001612ac560405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f815260200161298860405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60a0828403128015612b56575f5ffd5b509092915050565b5f60c08284031215612b6e575f5ffd5b50919050565b5f60c08284031215612b84575f5ffd5b61030c8383612b5e565b5f60208284031215612b9e575f5ffd5b81356001600160401b03811115612bb3575f5ffd5b8201610200818503121561030c575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f5f60208385031215612c0b575f5ffd5b82356001600160401b03811115612c20575f5ffd5b8301601f81018513612c30575f5ffd5b80356001600160401b03811115612c45575f5ffd5b856020828401011115612c56575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f8151808452602084019350602083015f5b82811015612d0557815165ffffffffffff8151168752602081015160038110612cc357634e487b7160e01b5f52602160045260245ffd5b6020888101919091526040828101516001600160a01b03908116918a019190915260609283015116918801919091526080909601959190910190600101612c8c565b5093949350505050565b60ff81511682525f602082015160806020850152612d306080850182612c7a565b905060408301516040850152606083015160608501528091505092915050565b6020815265ffffffffffff82511660208201525f6020830151612da660408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612dc2610140840182612d0f565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015265ffffffffffff60608201511660608301526080810151608083015260a081015160a08301525050565b60208152612eb8602082018351612df2565b6020828101516101c060e0840152805165ffffffffffff166101e084015280820151610200840152604081015160ff16610220840152606001516080610240840152805161026084018190525f929190910190610280600582901b850181019190850190845b81811015612fc45786840361027f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612f895783518252602082019150602084019350600183019250612f66565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612f1e565b50505060408501519150612fdc610100850183612e4c565b6060850151848203601f19016101c0860152915061041e8183612c7a565b5f60608284031215612b6e575f5ffd5b5f6060828403121561301a575f5ffd5b61030c8383612ffa565b5f5f83601f840112613034575f5ffd5b5081356001600160401b0381111561304a575f5ffd5b6020830191508360208260061b8501011115613064575f5ffd5b9250929050565b5f5f5f5f6040858703121561307e575f5ffd5b84356001600160401b03811115613093575f5ffd5b8501601f810187136130a3575f5ffd5b80356001600160401b038111156130b8575f5ffd5b87602060a0830284010111156130cc575f5ffd5b6020918201955093508501356001600160401b038111156130eb575f5ffd5b6130f787828801613024565b95989497509550505050565b5f60208284031215613113575f5ffd5b81356001600160401b03811115613128575f5ffd5b82016101c0818503121561030c575f5ffd5b5f6020828403121561314a575f5ffd5b81356001600160401b0381111561315f575f5ffd5b8201610120818503121561030c575f5ffd5b5f8151808452602084019350602083015f5b82811015612d0557613196868351612df2565b60c0959095019460209190910190600101613183565b5f82825180855260208501945060208160051b830101602085015f5b838110156131fa57601f198584030188526131e4838351612d0f565b60209889019890935091909101906001016131c8565b50909695505050505050565b6020815265ffffffffffff82511660208201525f602083015161322c6040840182612e4c565b506040830151610200610100840152613249610220840182613171565b6060850151805161ffff9081166101208701526020820151166101408601526040015162ffffff166101608501526080850151848203601f190161018086015290915061329682826131ac565b60a0860151805165ffffffffffff166101a087015260208101516101c0870152604001516101e086015260c086015160ff81166102008701529092509050612dea565b5f60808284031215612b6e575f5ffd5b5f602082840312156132f9575f5ffd5b81356001600160401b0381111561330e575f5ffd5b612509848285016132d9565b5f6020828403121561332a575f5ffd5b81356001600160401b0381111561333f575f5ffd5b61250984828501612ffa565b602081525f8251606060208401526133666080840182613171565b602085810151601f19868403016040870152805180845290820193505f92909101905b808310156133dc5783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a082019150602084019350600183019250613389565b506040860151858203601f19016060870152805180835260209182019450910191505f905b808210156134415761342a83855180516001600160a01b03908116835260209182015116910152565b604083019250602084019350600182019150613401565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b03811182821017156134825761348261344c565b60405290565b60405160c081016001600160401b03811182821017156134825761348261344c565b604051608081016001600160401b03811182821017156134825761348261344c565b60405160e081016001600160401b03811182821017156134825761348261344c565b604080519081016001600160401b03811182821017156134825761348261344c565b604051601f8201601f191681016001600160401b03811182821017156135385761353861344c565b604052919050565b803565ffffffffffff81168114613555575f5ffd5b919050565b5f6060828403121561356a575f5ffd5b613572613460565b905061357d82613540565b81526020828101359082015260409182013591810191909152919050565b5f60a082840312156135ab575f5ffd5b6135b3613460565b823581526020808401359082015290506135d0836040840161355a565b604082015292915050565b5f60a082840312156135eb575f5ffd5b61030c838361359b565b5f60c08284031215613605575f5ffd5b61360d613488565b905061361882613540565b815261362660208301613540565b602082015261363760408301613540565b604082015261364860608301613540565b60608201526080828101359082015260a09182013591810191909152919050565b5f60c08284031215613679575f5ffd5b61030c83836135f5565b5f6001600160401b0382111561369b5761369b61344c565b5060051b60200190565b80356001600160a01b0381168114613555575f5ffd5b5f60c082840312156136cb575f5ffd5b6136d3613488565b90506136de82613540565b81526136ec60208301613540565b60208201526136fd60408301613540565b6040820152613648606083016136a5565b5f82601f83011261371d575f5ffd5b813561373061372b82613683565b613510565b80828252602082019150602060c08402860101925085831115613751575f5ffd5b602085015b838110156137785761376887826136bb565b835260209092019160c001613756565b5095945050505050565b803561ffff81168114613555575f5ffd5b803562ffffff81168114613555575f5ffd5b5f606082840312156137b5575f5ffd5b6137bd613460565b90506137c882613782565b81526137d660208301613782565b60208201526135d060408301613793565b803560ff81168114613555575f5ffd5b5f82601f830112613806575f5ffd5b813561381461372b82613683565b8082825260208201915060208360071b860101925085831115613835575f5ffd5b602085015b838110156137785760808188031215613851575f5ffd5b6138596134aa565b61386282613540565b8152602082013560038110613875575f5ffd5b6020820152613886604083016136a5565b6040820152613897606083016136a5565b6060820152835260209092019160800161383a565b5f608082840312156138bc575f5ffd5b6138c46134aa565b90506138cf826137e7565b815260208201356001600160401b038111156138e9575f5ffd5b6138f5848285016137f7565b6020830152506040828101359082015260609182013591810191909152919050565b5f82601f830112613926575f5ffd5b813561393461372b82613683565b8082825260208201915060208360051b860101925085831115613955575f5ffd5b602085015b838110156137785780356001600160401b03811115613977575f5ffd5b613986886020838a01016138ac565b8452506020928301920161395a565b5f61020082360312156139a6575f5ffd5b6139ae6134cc565b6139b783613540565b81526139c636602085016135f5565b602082015260e08301356001600160401b038111156139e3575f5ffd5b6139ef3682860161370e565b604083015250613a033661010085016137a5565b60608201526101608301356001600160401b03811115613a21575f5ffd5b613a2d36828601613917565b608083015250613a4136610180850161355a565b60a0820152613a536101e084016137e7565b60c082015292915050565b5f60608284031215613a6e575f5ffd5b61030c838361355a565b5f60408284031215613a88575f5ffd5b613a906134ee565b9050613a9b826136a5565b8152613aa9602083016136a5565b602082015292915050565b5f60408284031215613ac4575f5ffd5b61030c8383613a78565b5f60808284031215613ade575f5ffd5b613ae66134aa565b9050613af182613540565b815260208281013590820152613b09604083016137e7565b604082015260608201356001600160401b03811115613b26575f5ffd5b8201601f81018413613b36575f5ffd5b8035613b4461372b82613683565b8082825260208201915060208360051b850101925086831115613b65575f5ffd5b602084015b83811015613cab5780356001600160401b03811115613b87575f5ffd5b85016040818a03601f19011215613b9c575f5ffd5b613ba46134ee565b60208201358015158114613bb6575f5ffd5b815260408201356001600160401b03811115613bd0575f5ffd5b6020818401019250506060828b031215613be8575f5ffd5b613bf0613460565b82356001600160401b03811115613c05575f5ffd5b8301601f81018c13613c15575f5ffd5b8035613c2361372b82613683565b8082825260208201915060208360051b85010192508e831115613c44575f5ffd5b6020840193505b82841015613c66578335825260209384019390910190613c4b565b845250613c7891505060208401613793565b6020820152613c8960408401613540565b6040820152806020830152508085525050602083019250602081019050613b6a565b5060608501525091949350505050565b5f6101c08236031215613ccc575f5ffd5b613cd46134aa565b613cde36846136bb565b815260c08301356001600160401b03811115613cf8575f5ffd5b613d0436828601613ace565b602083015250613d173660e085016135f5565b60408201526101a08301356001600160401b03811115613d35575f5ffd5b613d41368286016137f7565b60608301525092915050565b5f6101208236031215613d5e575f5ffd5b613d666134aa565b613d6f83613540565b8152613d7e366020850161359b565b602082015260c08301356001600160401b03811115613d9b575f5ffd5b613da7368286016138ac565b604083015250613dba3660e08501613a78565b606082015292915050565b5f60c08284031215613dd5575f5ffd5b61030c83836136bb565b5f6102953683613ace565b5f82601f830112613df9575f5ffd5b8135613e0761372b82613683565b8082825260208201915060208360061b860101925085831115613e28575f5ffd5b602085015b8381101561377857613e3f8782613a78565b8352602090920191604001613e2d565b5f60608236031215613e5f575f5ffd5b613e67613460565b82356001600160401b03811115613e7c575f5ffd5b613e883682860161370e565b82525060208301356001600160401b03811115613ea3575f5ffd5b830136601f820112613eb3575f5ffd5b8035613ec161372b82613683565b80828252602082019150602060a08402850101925036831115613ee2575f5ffd5b6020840193505b82841015613f0e57613efb368561359b565b825260208201915060a084019350613ee9565b602085015250505060408301356001600160401b03811115613f2e575f5ffd5b613f3a36828601613dea565b60408301525092915050565b5f61029536836138ac565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a264697066735822122006c3885d0468409cbf2299f6630a89f91c55b13c59b02f8609b0706c6fc0a7e064736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa?\xBB\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80c\x82\xD7\x05\x8B\x11a\0\x93W\x80c\xB8\xB0.\x0E\x11a\0cW\x80c\xB8\xB0.\x0E\x14a\x02\x0CW\x80c\xDCZ\x8B\xF8\x14a\x02\x1FW\x80c\xED\xBA\xCDD\x14a\x022W\x80c\xEE\xDE\xC1\x02\x14a\x02RW__\xFD[\x80c\x82\xD7\x05\x8B\x14a\x01\xB3W\x80c\x8Fm\x0E\x1A\x14a\x01\xC6W\x80c\xA1\xEC\x933\x14a\x01\xD9W\x80c\xAF\xB6:\xD4\x14a\x01\xECW__\xFD[\x80c&09b\x11a\0\xCEW\x80c&09b\x14a\x01MW\x80c]'\xCC\x95\x14a\x01mW\x80cy\x89\xAA\x10\x14a\x01\x8DW\x80cz\x9AU*\x14a\x01\xA0W__\xFD[\x80c\x1F9pg\x14a\0\xF4W\x80c\x1F\xE0j\xB4\x14a\x01\x1AW\x80c&\x1B\xF64\x14a\x01-W[__\xFD[a\x01\x07a\x01\x026`\x04a+EV[a\x02}V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x07a\x01(6`\x04a+tV[a\x02\x9BV[a\x01@a\x01;6`\x04a+\x8EV[a\x02\xB3V[`@Qa\x01\x11\x91\x90a+\xC5V[a\x01`a\x01[6`\x04a+\xFAV[a\x02\xC6V[`@Qa\x01\x11\x91\x90a-PV[a\x01\x80a\x01{6`\x04a+\xFAV[a\x03\x13V[`@Qa\x01\x11\x91\x90a.\xA6V[a\x01\x07a\x01\x9B6`\x04a0\nV[a\x03YV[a\x01\x07a\x01\xAE6`\x04a0kV[a\x03qV[a\x01@a\x01\xC16`\x04a1\x03V[a\x04'V[a\x01@a\x01\xD46`\x04a1:V[a\x04:V[a\x01\x07a\x01\xE76`\x04a+tV[a\x04MV[a\x01\xFFa\x01\xFA6`\x04a+\xFAV[a\x04eV[`@Qa\x01\x11\x91\x90a2\x06V[a\x01\x07a\x02\x1A6`\x04a2\xE9V[a\x04\xABV[a\x01@a\x02-6`\x04a3\x1AV[a\x04\xBDV[a\x02Ea\x02@6`\x04a+\xFAV[a\x04\xD0V[`@Qa\x01\x11\x91\x90a3KV[a\x02ea\x02`6`\x04a2\xE9V[a\x052V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x11V[_a\x02\x95a\x02\x906\x84\x90\x03\x84\x01\x84a5\xDBV[a\x05DV[\x92\x91PPV[_a\x02\x95a\x02\xAE6\x84\x90\x03\x84\x01\x84a6iV[a\x05xV[``a\x02\x95a\x02\xC1\x83a9\x95V[a\x05\xD3V[a\x02\xCEa)\x19V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08\x13\x92PPPV[\x93\x92PPPV[a\x03\x1Ba)\x8DV[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\n\xC5\x92PPPV[_a\x02\x95a\x03l6\x84\x90\x03\x84\x01\x84a:^V[a\x10\x05V[_a\x04\x1E\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xC2Wa\x03\xB3`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a5\xDBV[\x81R` \x01\x90`\x01\x01\x90a\x03\x96V[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04\x14Wa\x04\x05`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a:\xB4V[\x81R` \x01\x90`\x01\x01\x90a\x03\xE8V[PPPPPa\x106V[\x95\x94PPPPPV[``a\x02\x95a\x045\x83a<\xBBV[a\x11\xEDV[``a\x02\x95a\x04H\x83a=MV[a\x15fV[_a\x02\x95a\x04`6\x84\x90\x03\x84\x01\x84a=\xC5V[a\x17}V[a\x04ma*\x06V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x17\xF4\x92PPPV[_a\x02\x95a\x04\xB8\x83a=\xDFV[a\x1AeV[``a\x02\x95a\x04\xCB\x83a>OV[a\x1B\xD5V[a\x04\xF4`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1D:\x92PPPV[_a\x02\x95a\x05?\x83a?FV[a\x1F\xA0V[_a\x02\x95\x82_\x01Q\x83` \x01Qa\x05^\x85`@\x01Qa\x10\x05V[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q``\x80\x87\x01Q`\x80\x80\x89\x01Q`\xA0\x80\x8B\x01Q\x87Qe\xFF\xFF\xFF\xFF\xFF\xFF\x9B\x8C\x16\x81R\x98\x8B\x16\x99\x89\x01\x99\x90\x99R\x94\x89\x16\x95\x87\x01\x95\x90\x95R\x96\x16\x90\x84\x01R\x93\x82\x01R\x91\x82\x01R`\xC0\x90 _\x90a\x02\x95V[``_a\x05\xED\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa \xF1V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x07Wa\x06\x07a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x061W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x83\x1B`2\x85\x01R\x81Q``\x01Q\x90\x92\x1B`8\x84\x01R\x80Q`\x80\x01Q`>\x84\x01RQ`\xA0\x01Q`^\x83\x01R\x84\x01QQ\x90\x92P`~\x83\x01\x90a\x06\xA3\x90a!|V[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x06\xF1Wa\x06\xE7\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x06\xDAWa\x06\xDAa?QV[` \x02` \x01\x01Qa!\xA2V[\x91P`\x01\x01a\x06\xB3V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x07/\x90a!|V[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x07}Wa\x07s\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x07fWa\x07fa?QV[` \x02` \x01\x01Qa!\xF4V[\x91P`\x01\x01a\x07?V[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x07\xA1WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x07\xB3WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x07\xCC\x82\x82a\x07\xC5W`\x01a\"|V[_[a\"|V[\x91P\x80a\x07\xFBW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x08\t\x82\x86`\xC0\x01Qa\"|V[\x91PPPP\x91\x90PV[a\x08\x1Ba)\x19V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xE2Wa\x08\xE2a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t2W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\t\0W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xBDW\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\tmWa\tma?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xB4W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xC9Wa\t\xC9a,fV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\xE3Wa\t\xE3a?QV[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\n\0Wa\n\0a,fV[\x90\x81`\x02\x81\x11\x15a\n\x13Wa\n\x13a,fV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n9Wa\n9a?QV[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\nq\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n\x8BWa\n\x8Ba?QV[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\t>V[PPP\x91\x90PV[a\n\xCDa)\x8DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0B[Wa\x0B[a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0B\xBEW\x81` \x01[a\x0B\xAB`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x0ByW\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\r\x8CW\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0C\x05Wa\x0C\x05a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0C8Wa\x0C8a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0CaW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0C|Wa\x0C|a?QV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0C\xF1W\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0C\xB9Wa\x0C\xB9a?QV[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0C\xD9Wa\x0C\xD9a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0C\x8DV[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\r\x15Wa\r\x15a?QV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\rWWa\rWa?QV[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0B\xCAV[P\x81Q\x83Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x84\x01Q\x85Q`\xA0\x90\x81\x01\x91\x90\x91R`@\x80\x86\x01Q\x81\x88\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x88\x01Q\x81Q\x90\x83\x1C\x95\x01\x94\x90\x94R`L\x87\x01Q\x84Q\x90\x82\x1C\x92\x01\x91\x90\x91R`R\x86\x01Q\x83Q\x91\x1C``\x90\x91\x01R`X\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`x\x84\x01Q\x90Q\x90\x91\x01R`\x98\x82\x01Q`\x9A\x90\x92\x01\x91`\xF0\x1C\x80\x15a\n\xBDW\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E5Wa\x0E5a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\x85W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x0ESW\x90P[P``\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xFCW\x83Q`\xD0\x1C`\x06\x85\x01\x86``\x01Q\x83\x81Q\x81\x10a\x0E\xB8Wa\x0E\xB8a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x94P`\xF8\x1C`\x02\x81\x11\x15a\x0E\xFFW`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\x0F\x14Wa\x0F\x14a,fV[\x86``\x01Q\x83\x81Q\x81\x10a\x0F*Wa\x0F*a?QV[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\x0FGWa\x0FGa,fV[\x90\x81`\x02\x81\x11\x15a\x0FZWa\x0FZa,fV[\x90RP\x84Q``\x1C`\x14\x86\x01\x87``\x01Q\x84\x81Q\x81\x10a\x0F|Wa\x0F|a?QV[` \x02` \x01\x01Q`@\x01\x81\x97P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\x0F\xB4\x85\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x87``\x01Q\x84\x81Q\x81\x10a\x0F\xCAWa\x0F\xCAa?QV[` \x02` \x01\x01Q``\x01\x81\x97P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\x0E\x8DV[PPPP\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x95V[_\x81Q\x83Q\x14a\x10YW`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x10yW_Q` a?f_9_Q\x90_R\x91PPa\x02\x95V[\x80`\x01\x03a\x10\xDCW_a\x10\xBE\x85_\x81Q\x81\x10a\x10\x97Wa\x10\x97a?QV[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[` \x02` \x01\x01Qa\"\x88V[\x90Pa\x10\xD3\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x95V[\x80`\x02\x03a\x11PW_a\x10\xFA\x85_\x81Q\x81\x10a\x10\x97Wa\x10\x97a?QV[\x90P_a\x11.\x86`\x01\x81Q\x81\x10a\x11\x13Wa\x11\x13a?QV[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x95V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x11\xC6Wa\x11\xBD\x82\x82`\x01\x01a\x11\xAE\x89\x85\x81Q\x81\x10a\x11\x94Wa\x11\x94a?QV[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11oV[P\x80Q`\x05\x1B` \x82\x01 a\x04\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[``_a\x12\x06\x83` \x01Q``\x01Q\x84``\x01Qa\"\xDBV[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12 Wa\x12 a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x12JW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x12\xB5\x90\x82\x90a\"|V[` \x85\x01Q``\x01QQ\x90\x91Pa\x12\xCB\x81a!|V[a\x12\xDB\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x14MWa\x13!\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x13\x05Wa\x13\x05a?QV[` \x02` \x01\x01Q_\x01Qa\x13\x1AW_a\"|V[`\x01a\"|V[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x13>Wa\x13>a?QV[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x13Y\x81a!|V[a\x13i\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x13\xCDWa\x13\xC3\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x13\x93Wa\x13\x93a?QV[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x13\xB3Wa\x13\xB3a?QV[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x13mV[Pa\x14\x07\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x13\xECWa\x13\xECa?QV[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x14B\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x14'Wa\x14'a?QV[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x12\xDFV[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R`@\x80\x89\x01\x80QQ`\xD0\x90\x81\x1B\x83\x89\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x88\x01R\x80Q\x90\x91\x01Q\x82\x1B`L\x87\x01R\x80Q``\x90\x81\x01Q\x90\x92\x1B`R\x87\x01R\x80Q\x90\x93\x01Q`X\x86\x01R\x91Q\x01Q`x\x84\x01R\x85\x01QQ`\x98\x90\x92\x01\x91a\x14\xCB\x81a!|V[a\x14\xDB\x83\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x92P_[\x81\x81\x10\x15a\x15\\W_\x87``\x01Q\x82\x81Q\x81\x10a\x14\xFEWa\x14\xFEa?QV[` \x02` \x01\x01Q\x90Pa\x15\x1B\x85\x82_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x94Pa\x157\x85\x82` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[`@\x82\x01Q``\x90\x81\x1B\x82R\x91\x82\x01Q\x90\x91\x1B`\x14\x82\x01R`(\x01\x93P`\x01\x01a\x14\xDFV[PPPPP\x91\x90PV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\x91Wa\x15\x91a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x15\xBBW` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x16#\x90\x82\x90a\"|V[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x16o\x90a!|V[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xBDWa\x16\xC8\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x16\xB2Wa\x16\xB2a?QV[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x17\x05\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x16\xE8Wa\x16\xE8a?QV[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[\x91Pa\x17<\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x17%Wa\x17%a?QV[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x17s\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x17\\Wa\x17\\a?QV[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x16\x83V[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x03\x0C\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x17\xFCa*\x06V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x90\x82\x1C`@\x90\x91\x01R`8\x84\x01Q\x82Q\x91\x1C``\x90\x91\x01R`>\x83\x01Q\x81Q`\x80\x90\x81\x01\x91\x90\x91R`^\x84\x01Q\x91Q`\xA0\x01\x91\x90\x91R`~\x83\x01Q\x90\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18\x8AWa\x18\x8Aa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x18\xC3W\x81` \x01[a\x18\xB0a*\xD1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x18\xA8W\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x19\x0EWa\x18\xE0\x83a#+V[\x85`@\x01Q\x83\x81Q\x81\x10a\x18\xF6Wa\x18\xF6a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x18\xCBV[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19gWa\x19ga4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x19\xC3W\x81` \x01[a\x19\xB0`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x19\x85W\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1A\x0EWa\x19\xE0\x84a#\x88V[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x19\xF6Wa\x19\xF6a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x19\xCBV[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x1ASW\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x1A\xAEW_Q` a?f_9_Q\x90_R\x91Pa\x1B\xB4V[\x80`\x01\x03a\x1A\xF7Wa\x1A\xF0\x81_\x1Ba\x1A\xE2\x87``\x01Q_\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[` \x02` \x01\x01Qa$\x99V[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x1B\xB4V[\x80`\x02\x03a\x1B8Wa\x1A\xF0\x81_\x1Ba\x1B\x1E\x87``\x01Q_\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[a\x05^\x88``\x01Q`\x01\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1B\x89Wa\x1B\x80\x82\x82`\x01\x01a\x11\xAE\x8A``\x01Q\x85\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[P`\x01\x01a\x1BWV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1B\xB2\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x1B\xEE\x83_\x01Q\x84` \x01Q\x85`@\x01Qa%\x11V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x08Wa\x1C\x08a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x1C2W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x1CG\x90a!|V[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x1C\x8EWa\x1C\x84\x82\x86_\x01Q\x83\x81Q\x81\x10a\x1CwWa\x1Cwa?QV[` \x02` \x01\x01Qa%fV[\x91P`\x01\x01a\x1CTV[Pa\x1C\x9D\x84` \x01QQa!|V[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x1C\xEBWa\x1C\xE1\x82\x86` \x01Q\x83\x81Q\x81\x10a\x1C\xD4Wa\x1C\xD4a?QV[` \x02` \x01\x01Qa%\xA0V[\x91P`\x01\x01a\x1C\xADV[Pa\x1C\xFA\x84`@\x01QQa!|V[_[\x84`@\x01QQ\x81\x10\x15a\n\xBDWa\x1D0\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1D#Wa\x1D#a?QV[` \x02` \x01\x01Qa%\xDCV[\x91P`\x01\x01a\x1C\xFCV[a\x1D^`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1D\x83Wa\x1D\x83a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1D\xBCW\x81` \x01[a\x1D\xA9a*\xD1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1D\xA1W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1E\x02Wa\x1D\xD6\x83a%\xFDV[\x85Q\x80Q\x84\x90\x81\x10a\x1D\xEAWa\x1D\xEAa?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1D\xC1V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1E2W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1ENWa\x1ENa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1E\x87W\x81` \x01[a\x1Eta+\x05V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1ElW\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1E\xD2Wa\x1E\xA4\x84a&EV[\x86` \x01Q\x83\x81Q\x81\x10a\x1E\xBAWa\x1E\xBAa?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1E\x8FV[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\xEFWa\x1E\xEFa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1F3W\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1F\rW\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xFCW`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1F\x88Wa\x1F\x88a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1F;V[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1F\xC6W_Q` a?f_9_Q\x90_R\x91Pa \xBEV[\x80`\x01\x03a \x01Wa\x1F\xFA\x81_\x1Ba\x1A\xE2\x86` \x01Q_\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[` \x02` \x01\x01Qa&\x8FV[\x91Pa \xBEV[\x80`\x02\x03a BWa\x1F\xFA\x81_\x1Ba (\x86` \x01Q_\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[a\x05^\x87` \x01Q`\x01\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a \x93Wa \x8A\x82\x82`\x01\x01a\x11\xAE\x89` \x01Q\x85\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[P`\x01\x01a aV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa \xBC\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x04\x1EV[\x80Q`k\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a!\x0FWP` \x83\x01Q\x15[\x80\x15a!\x1DWP`@\x83\x01Q\x15[\x90P\x80a!+W`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a!sW\x84\x81\x81Q\x81\x10a!QWa!Qa?QV[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa!6V[PP\x93\x92PPPV[a\xFF\xFF\x81\x11\x15a!\x9FW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x03\x0CV[_a\"\x02\x83\x83_\x01Qa\"|V[\x90Pa\"\x12\x82` \x01QQa!|V[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\"`Wa\"V\x82\x84` \x01Q\x83\x81Q\x81\x10a\"IWa\"Ia?QV[` \x02` \x01\x01Qa&\xFBV[\x91P`\x01\x01a\"\"V[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x03\x0CV[_\x81\x83SPP`\x01\x01\x90V[_a\x03\x0C\x83_\x01Q\x84` \x01Qa\"\xA2\x86`@\x01Qa\x10\x05V[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[`\xE9_[\x83Q\x81\x10\x15a#\x1FW\x83\x81\x81Q\x81\x10a\"\xFAWa\"\xFAa?QV[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\"\xDFV[P\x90Q`/\x02\x01\x91\x90PV[a#3a*\xD1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a#\xB3`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a#\xDFWa#\xDFa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a$/W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a#\xFDW\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a$zWa$L\x83a'FV[\x85` \x01Q\x83\x81Q\x81\x10a$bWa$ba?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a$7V[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a$\xAB\x83` \x01Q_\x01Qa'\xDEV[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa%\t\x84_\x01Qa$\xF4W_a$\xF7V[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[_\x82Q\x84Q\x14a%4W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a%VW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a!\xD7V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x03\x0CV[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x03\x0CV[a&\x05a*\xD1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a#mV[a&Ma+\x05V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x95\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a&\xB7Wa&\xB7a,fV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa'#\x81\x83` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x03\x0CV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a'\x8FWa'\x8Fa,fV[\x83` \x01\x90`\x02\x81\x11\x15a'\xA5Wa'\xA5a,fV[\x90\x81`\x02\x81\x11\x15a'\xB8Wa'\xB8a,fV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a'\xFEWP_Q` a?f_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a(4Wa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a(\x1EWa(\x1Ea?QV[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a(\x91Wa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a(TWa(Ta?QV[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a(oWa(oa?QV[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a(\xF2Wa(\xE9\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a(\xD2Wa(\xD2a?QV[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a(\xB0V[P\x80Q`\x05\x1B` \x82\x01 a%\t\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a):a+\x05V[\x81R` \x01a)j`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a)\x88`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80`\x80\x01`@R\x80a)\xA0a*\xD1V[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01\x81\x90R`\xA0\x82\x01R\x91\x01\x90\x81R` \x01``\x81RP\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a*V`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a*\x90`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a*\xC5`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a)\x88`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a+VW__\xFD[P\x90\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a+nW__\xFD[P\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a+\x84W__\xFD[a\x03\x0C\x83\x83a+^V[_` \x82\x84\x03\x12\x15a+\x9EW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xB3W__\xFD[\x82\x01a\x02\0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[__` \x83\x85\x03\x12\x15a,\x0BW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a, W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a,0W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a,EW__\xFD[\x85` \x82\x84\x01\x01\x11\x15a,VW__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a-\x05W\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x87R` \x81\x01Q`\x03\x81\x10a,\xC3WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x88\x81\x01\x91\x90\x91R`@\x82\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x8A\x01\x91\x90\x91R``\x92\x83\x01Q\x16\x91\x88\x01\x91\x90\x91R`\x80\x90\x96\x01\x95\x91\x90\x91\x01\x90`\x01\x01a,\x8CV[P\x93\x94\x93PPPPV[`\xFF\x81Q\x16\x82R_` \x82\x01Q`\x80` \x85\x01Ra-0`\x80\x85\x01\x82a,zV[\x90P`@\x83\x01Q`@\x85\x01R``\x83\x01Q``\x85\x01R\x80\x91PP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa-\xA6`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra-\xC2a\x01@\x84\x01\x82a-\x0FV[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[` \x81Ra.\xB8` \x82\x01\x83Qa-\xF2V[` \x82\x81\x01Qa\x01\xC0`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xE0\x84\x01R\x80\x82\x01Qa\x02\0\x84\x01R`@\x81\x01Q`\xFF\x16a\x02 \x84\x01R``\x01Q`\x80a\x02@\x84\x01R\x80Qa\x02`\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02\x80`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a/\xC4W\x86\x84\x03a\x02\x7F\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a/\x89W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa/fV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a/\x1EV[PPP`@\x85\x01Q\x91Pa/\xDCa\x01\0\x85\x01\x83a.LV[``\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\xC0\x86\x01R\x91Pa\x04\x1E\x81\x83a,zV[_``\x82\x84\x03\x12\x15a+nW__\xFD[_``\x82\x84\x03\x12\x15a0\x1AW__\xFD[a\x03\x0C\x83\x83a/\xFAV[__\x83`\x1F\x84\x01\x12a04W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0JW__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a0dW__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a0~W__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a0\x93W__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a0\xA3W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xB8W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a0\xCCW__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xEBW__\xFD[a0\xF7\x87\x82\x88\x01a0$V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a1\x13W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1(W__\xFD[\x82\x01a\x01\xC0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_` \x82\x84\x03\x12\x15a1JW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1_W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a-\x05Wa1\x96\x86\x83Qa-\xF2V[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a1\x83V[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a1\xFAW`\x1F\x19\x85\x84\x03\x01\x88Ra1\xE4\x83\x83Qa-\x0FV[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a1\xC8V[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa2,`@\x84\x01\x82a.LV[P`@\x83\x01Qa\x02\0a\x01\0\x84\x01Ra2Ia\x02 \x84\x01\x82a1qV[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01 \x87\x01R` \x82\x01Q\x16a\x01@\x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01`\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\x80\x86\x01R\x90\x91Pa2\x96\x82\x82a1\xACV[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x87\x01R` \x81\x01Qa\x01\xC0\x87\x01R`@\x01Qa\x01\xE0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x02\0\x87\x01R\x90\x92P\x90Pa-\xEAV[_`\x80\x82\x84\x03\x12\x15a+nW__\xFD[_` \x82\x84\x03\x12\x15a2\xF9W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3\x0EW__\xFD[a%\t\x84\x82\x85\x01a2\xD9V[_` \x82\x84\x03\x12\x15a3*W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3?W__\xFD[a%\t\x84\x82\x85\x01a/\xFAV[` \x81R_\x82Q``` \x84\x01Ra3f`\x80\x84\x01\x82a1qV[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a3\xDCW\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa3\x89V[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a4AWa4*\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa4\x01V[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@R\x90V[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a58Wa58a4LV[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a5jW__\xFD[a5ra4`V[\x90Pa5}\x82a5@V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a5\xABW__\xFD[a5\xB3a4`V[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa5\xD0\x83`@\x84\x01a5ZV[`@\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a5\xEBW__\xFD[a\x03\x0C\x83\x83a5\x9BV[_`\xC0\x82\x84\x03\x12\x15a6\x05W__\xFD[a6\ra4\x88V[\x90Pa6\x18\x82a5@V[\x81Ra6&` \x83\x01a5@V[` \x82\x01Ra67`@\x83\x01a5@V[`@\x82\x01Ra6H``\x83\x01a5@V[``\x82\x01R`\x80\x82\x81\x015\x90\x82\x01R`\xA0\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a6yW__\xFD[a\x03\x0C\x83\x83a5\xF5V[_`\x01`\x01`@\x1B\x03\x82\x11\x15a6\x9BWa6\x9Ba4LV[P`\x05\x1B` \x01\x90V[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a5UW__\xFD[_`\xC0\x82\x84\x03\x12\x15a6\xCBW__\xFD[a6\xD3a4\x88V[\x90Pa6\xDE\x82a5@V[\x81Ra6\xEC` \x83\x01a5@V[` \x82\x01Ra6\xFD`@\x83\x01a5@V[`@\x82\x01Ra6H``\x83\x01a6\xA5V[_\x82`\x1F\x83\x01\x12a7\x1DW__\xFD[\x815a70a7+\x82a6\x83V[a5\x10V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a7QW__\xFD[` \x85\x01[\x83\x81\x10\x15a7xWa7h\x87\x82a6\xBBV[\x83R` \x90\x92\x01\x91`\xC0\x01a7VV[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[_``\x82\x84\x03\x12\x15a7\xB5W__\xFD[a7\xBDa4`V[\x90Pa7\xC8\x82a7\x82V[\x81Ra7\xD6` \x83\x01a7\x82V[` \x82\x01Ra5\xD0`@\x83\x01a7\x93V[\x805`\xFF\x81\x16\x81\x14a5UW__\xFD[_\x82`\x1F\x83\x01\x12a8\x06W__\xFD[\x815a8\x14a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a85W__\xFD[` \x85\x01[\x83\x81\x10\x15a7xW`\x80\x81\x88\x03\x12\x15a8QW__\xFD[a8Ya4\xAAV[a8b\x82a5@V[\x81R` \x82\x015`\x03\x81\x10a8uW__\xFD[` \x82\x01Ra8\x86`@\x83\x01a6\xA5V[`@\x82\x01Ra8\x97``\x83\x01a6\xA5V[``\x82\x01R\x83R` \x90\x92\x01\x91`\x80\x01a8:V[_`\x80\x82\x84\x03\x12\x15a8\xBCW__\xFD[a8\xC4a4\xAAV[\x90Pa8\xCF\x82a7\xE7V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xE9W__\xFD[a8\xF5\x84\x82\x85\x01a7\xF7V[` \x83\x01RP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a9&W__\xFD[\x815a94a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a9UW__\xFD[` \x85\x01[\x83\x81\x10\x15a7xW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a9wW__\xFD[a9\x86\x88` \x83\x8A\x01\x01a8\xACV[\x84RP` \x92\x83\x01\x92\x01a9ZV[_a\x02\0\x826\x03\x12\x15a9\xA6W__\xFD[a9\xAEa4\xCCV[a9\xB7\x83a5@V[\x81Ra9\xC66` \x85\x01a5\xF5V[` \x82\x01R`\xE0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a9\xE3W__\xFD[a9\xEF6\x82\x86\x01a7\x0EV[`@\x83\x01RPa:\x036a\x01\0\x85\x01a7\xA5V[``\x82\x01Ra\x01`\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:!W__\xFD[a:-6\x82\x86\x01a9\x17V[`\x80\x83\x01RPa:A6a\x01\x80\x85\x01a5ZV[`\xA0\x82\x01Ra:Sa\x01\xE0\x84\x01a7\xE7V[`\xC0\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a:nW__\xFD[a\x03\x0C\x83\x83a5ZV[_`@\x82\x84\x03\x12\x15a:\x88W__\xFD[a:\x90a4\xEEV[\x90Pa:\x9B\x82a6\xA5V[\x81Ra:\xA9` \x83\x01a6\xA5V[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a:\xC4W__\xFD[a\x03\x0C\x83\x83a:xV[_`\x80\x82\x84\x03\x12\x15a:\xDEW__\xFD[a:\xE6a4\xAAV[\x90Pa:\xF1\x82a5@V[\x81R` \x82\x81\x015\x90\x82\x01Ra;\t`@\x83\x01a7\xE7V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;&W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a;6W__\xFD[\x805a;Da7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a;eW__\xFD[` \x84\x01[\x83\x81\x10\x15a<\xABW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a;\x87W__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a;\x9CW__\xFD[a;\xA4a4\xEEV[` \x82\x015\x80\x15\x15\x81\x14a;\xB6W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xD0W__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a;\xE8W__\xFD[a;\xF0a4`V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a<\x05W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a<\x15W__\xFD[\x805a<#a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a<DW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a<fW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a<KV[\x84RPa<x\x91PP` \x84\x01a7\x93V[` \x82\x01Ra<\x89`@\x84\x01a5@V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa;jV[P``\x85\x01RP\x91\x94\x93PPPPV[_a\x01\xC0\x826\x03\x12\x15a<\xCCW__\xFD[a<\xD4a4\xAAV[a<\xDE6\x84a6\xBBV[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a<\xF8W__\xFD[a=\x046\x82\x86\x01a:\xCEV[` \x83\x01RPa=\x176`\xE0\x85\x01a5\xF5V[`@\x82\x01Ra\x01\xA0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a=5W__\xFD[a=A6\x82\x86\x01a7\xF7V[``\x83\x01RP\x92\x91PPV[_a\x01 \x826\x03\x12\x15a=^W__\xFD[a=fa4\xAAV[a=o\x83a5@V[\x81Ra=~6` \x85\x01a5\x9BV[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a=\x9BW__\xFD[a=\xA76\x82\x86\x01a8\xACV[`@\x83\x01RPa=\xBA6`\xE0\x85\x01a:xV[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a=\xD5W__\xFD[a\x03\x0C\x83\x83a6\xBBV[_a\x02\x956\x83a:\xCEV[_\x82`\x1F\x83\x01\x12a=\xF9W__\xFD[\x815a>\x07a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a>(W__\xFD[` \x85\x01[\x83\x81\x10\x15a7xWa>?\x87\x82a:xV[\x83R` \x90\x92\x01\x91`@\x01a>-V[_``\x826\x03\x12\x15a>_W__\xFD[a>ga4`V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a>|W__\xFD[a>\x886\x82\x86\x01a7\x0EV[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a>\xA3W__\xFD[\x83\x016`\x1F\x82\x01\x12a>\xB3W__\xFD[\x805a>\xC1a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a>\xE2W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a?\x0EWa>\xFB6\x85a5\x9BV[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa>\xE9V[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a?.W__\xFD[a?:6\x82\x86\x01a=\xEAV[`@\x83\x01RP\x92\x91PPV[_a\x02\x956\x83a8\xACV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \x06\xC3\x88]\x04h@\x9C\xBF\"\x99\xF6c\n\x89\xF9\x1CU\xB1<Y\xB0/\x86\t\xB0plo\xC0\xA7\xE0dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c806382d7058b11610093578063b8b02e0e11610063578063b8b02e0e1461020c578063dc5a8bf81461021f578063edbacd4414610232578063eedec10214610252575f5ffd5b806382d7058b146101b35780638f6d0e1a146101c6578063a1ec9333146101d9578063afb63ad4146101ec575f5ffd5b806326303962116100ce578063263039621461014d5780635d27cc951461016d5780637989aa101461018d5780637a9a552a146101a0575f5ffd5b80631f397067146100f45780631fe06ab41461011a578063261bf6341461012d575b5f5ffd5b610107610102366004612b45565b61027d565b6040519081526020015b60405180910390f35b610107610128366004612b74565b61029b565b61014061013b366004612b8e565b6102b3565b6040516101119190612bc5565b61016061015b366004612bfa565b6102c6565b6040516101119190612d50565b61018061017b366004612bfa565b610313565b6040516101119190612ea6565b61010761019b36600461300a565b610359565b6101076101ae36600461306b565b610371565b6101406101c1366004613103565b610427565b6101406101d436600461313a565b61043a565b6101076101e7366004612b74565b61044d565b6101ff6101fa366004612bfa565b610465565b6040516101119190613206565b61010761021a3660046132e9565b6104ab565b61014061022d36600461331a565b6104bd565b610245610240366004612bfa565b6104d0565b604051610111919061334b565b6102656102603660046132e9565b610532565b60405165ffffffffffff199091168152602001610111565b5f610295610290368490038401846135db565b610544565b92915050565b5f6102956102ae36849003840184613669565b610578565b60606102956102c183613995565b6105d3565b6102ce612919565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061081392505050565b9392505050565b61031b61298d565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610ac592505050565b5f61029561036c36849003840184613a5e565b611005565b5f61041e8585808060200260200160405190810160405280939291908181526020015f905b828210156103c2576103b360a083028601368190038101906135db565b81526020019060010190610396565b50505050508484808060200260200160405190810160405280939291908181526020015f905b828210156104145761040560408302860136819003810190613ab4565b815260200190600101906103e8565b5050505050611036565b95945050505050565b606061029561043583613cbb565b6111ed565b606061029561044883613d4d565b611566565b5f61029561046036849003840184613dc5565b61177d565b61046d612a06565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506117f492505050565b5f6102956104b883613ddf565b611a65565b60606102956104cb83613e4f565b611bd5565b6104f460405180606001604052806060815260200160608152602001606081525090565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611d3a92505050565b5f61029561053f83613f46565b611fa0565b5f610295825f0151836020015161055e8560400151611005565b604080519384526020840192909252908201526060902090565b805160208083015160408085015160608087015160808089015160a0808b0151875165ffffffffffff9b8c168152988b169989019990995294891695870195909552961690840152938201529182015260c090205f90610295565b60605f6105ed836040015184608001518560a001516120f1565b9050806001600160401b038111156106075761060761344c565b6040519080825280601f01601f191660200182016040528015610631576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c8401528051604090810151831b603285015281516060015190921b6038840152805160800151603e8401525160a00151605e83015284015151909250607e8301906106a39061217c565b60408401515160f01b81526002015f5b8460400151518110156106f1576106e782866040015183815181106106da576106da613f51565b60200260200101516121a2565b91506001016106b3565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b600482015260808401515160079091019061072f9061217c565b60808401515160f01b81526002015f5b84608001515181101561077d57610773828660800151838151811061076657610766613f51565b60200260200101516121f4565b915060010161073f565b5060a0840151515f9065ffffffffffff161580156107a1575060a085015160200151155b80156107b3575060a085015160400151155b90506107cc82826107c557600161227c565b5f5b61227c565b9150806107fb5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b610809828660c0015161227c565b9150505050919050565b61081b612919565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156108e2576108e261344c565b60405190808252806020026020018201604052801561093257816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816109005790505b506040840151602001525f5b8161ffff16811015610abd57825160d01c60068401856040015160200151838151811061096d5761096d613f51565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109b457604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109c9576109c9612c66565b85604001516020015183815181106109e3576109e3613f51565b6020026020010151602001906002811115610a0057610a00612c66565b90816002811115610a1357610a13612c66565b905250835160601c601485018660400151602001518481518110610a3957610a39613f51565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610a7184805160601c91601490910190565b8660400151602001518481518110610a8b57610a8b613f51565b6020026020010151606001819650826001600160a01b03166001600160a01b031681525050505080600101905061093e565b505050919050565b610acd61298d565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610b5b57610b5b61344c565b604051908082528060200260200182016040528015610bbe57816020015b610bab6040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610b795790505b506020840151606001525f5b8161ffff16811015610d8c578251602085015160600151805160019095019460f89290921c91821515919084908110610c0557610c05613f51565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610c3857610c3861344c565b604051908082528060200260200182016040528015610c61578160200160208202803683370190505b508660200151606001518481518110610c7c57610c7c613f51565b6020908102919091018101510151525f5b8161ffff16811015610cf1578551602087018860200151606001518681518110610cb957610cb9613f51565b6020026020010151602001515f01518381518110610cd957610cd9613f51565b60209081029190910101919091529550600101610c8d565b50845160e81c600386018760200151606001518581518110610d1557610d15613f51565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610d5757610d57613f51565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610bca565b5081518351608090810191909152602080840151855160a090810191909152604080860151818801805160d092831c90526046880151815190831c950194909452604c870151845190821c92019190915260528601518351911c606090910152605885015182519093019290925260788401519051909101526098820151609a9092019160f01c8015610abd578061ffff166001600160401b03811115610e3557610e3561344c565b604051908082528060200260200182016040528015610e8557816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f19909201910181610e535790505b5060608501525f5b8161ffff16811015610ffc57835160d01c6006850186606001518381518110610eb857610eb8613f51565b602090810291909101015165ffffffffffff9290921690915280516001909101945060f81c6002811115610eff57604051631ed6413560e31b815260040160405180910390fd5b8060ff166002811115610f1457610f14612c66565b86606001518381518110610f2a57610f2a613f51565b6020026020010151602001906002811115610f4757610f47612c66565b90816002811115610f5a57610f5a612c66565b905250845160601c6014860187606001518481518110610f7c57610f7c613f51565b6020026020010151604001819750826001600160a01b03166001600160a01b03168152505050610fb485805160601c91601490910190565b87606001518481518110610fca57610fca613f51565b6020026020010151606001819750826001600160a01b03166001600160a01b0316815250505050806001019050610e8d565b50505050919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610295565b5f81518351146110595760405163b1f40f7760e01b815260040160405180910390fd5b82515f819003611079575f516020613f665f395f51905f52915050610295565b806001036110dc575f6110be855f8151811061109757611097613f51565b6020026020010151855f815181106110b1576110b1613f51565b6020026020010151612288565b90506110d382825f9182526020526040902090565b92505050610295565b80600203611150575f6110fa855f8151811061109757611097613f51565b90505f61112e8660018151811061111357611113613f51565b6020026020010151866001815181106110b1576110b1613f51565b6040805194855260208501939093529183019190915250606090209050610295565b604080516001830181526002830160051b8101909152602081018290525f5b828110156111c6576111bd82826001016111ae89858151811061119457611194613f51565b60200260200101518986815181106110b1576110b1613f51565b60019190910160051b82015290565b5060010161116f565b50805160051b602082012061041e8280516040516001820160051b83011490151060061b52565b60605f61120683602001516060015184606001516122db565b9050806001600160401b038111156112205761122061344c565b6040519080825280601f01601f19166020018201604052801561124a576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c8301906112b590829061227c565b602085015160600151519091506112cb8161217c565b6112db828260f01b815260020190565b91505f5b8181101561144d5761132183876020015160600151838151811061130557611305613f51565b60200260200101515f015161131a575f61227c565b600161227c565b92505f866020015160600151828151811061133e5761133e613f51565b6020026020010151602001515f01515190506113598161217c565b611369848260f01b815260020190565b93505f5b818110156113cd576113c385896020015160600151858151811061139357611393613f51565b6020026020010151602001515f015183815181106113b3576113b3613f51565b6020026020010151815260200190565b945060010161136d565b506114078488602001516060015184815181106113ec576113ec613f51565b6020026020010151602001516020015160e81b815260030190565b935061144284886020015160600151848151811061142757611427613f51565b6020026020010151602001516040015160d01b815260060190565b9350506001016112df565b5084516080908101518352855160a090810151602080860191909152604080890180515160d090811b83890152815190930151831b6046880152805190910151821b604c870152805160609081015190921b60528701528051909301516058860152915101516078840152850151516098909201916114cb8161217c565b6114db838260f01b815260020190565b92505f5b8181101561155c575f876060015182815181106114fe576114fe613f51565b6020026020010151905061151b85825f015160d01b815260060190565b945061153785826020015160028111156107c7576107c7612c66565b6040820151606090811b82529182015190911b601482015260280193506001016114df565b5050505050919050565b60408101516020015151606090602f0260f701806001600160401b038111156115915761159161344c565b6040519080825280601f01601f1916602001820160405280156115bb576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061162390829061227c565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b6054840152510151516068909101915061166f9061217c565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610abd576116c88286604001516020015183815181106116b2576116b2613f51565b60200260200101515f015160d01b815260060190565b91506117058286604001516020015183815181106116e8576116e8613f51565b60200260200101516020015160028111156107c7576107c7612c66565b915061173c82866040015160200151838151811061172557611725613f51565b60200260200101516040015160601b815260140190565b915061177382866040015160200151838151811061175c5761175c613f51565b60200260200101516060015160601b815260140190565b9150600101611683565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b905061030c8184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b6117fc612a06565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c9301929092526032840151825190821c60409091015260388401518251911c606090910152603e8301518151608090810191909152605e840151915160a00191909152607e8301519083019060f01c806001600160401b0381111561188a5761188a61344c565b6040519080825280602002602001820160405280156118c357816020015b6118b0612ad1565b8152602001906001900390816118a85790505b5060408401525f5b8161ffff1681101561190e576118e08361232b565b856040015183815181106118f6576118f6613f51565b602090810291909101019190915292506001016118cb565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156119675761196761344c565b6040519080825280602002602001820160405280156119c357816020015b6119b060405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816119855790505b5060808501525f5b8161ffff16811015611a0e576119e084612388565b866080015183815181106119f6576119f6613f51565b602090810291909101019190915293506001016119cb565b50825160019384019360f89190911c90819003611a5357835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f03611aae575f516020613f665f395f51905f529150611bb4565b80600103611af757611af0815f1b611ae287606001515f81518110611ad557611ad5613f51565b6020026020010151612499565b5f9182526020526040902090565b9150611bb4565b80600203611b3857611af0815f1b611b1e87606001515f81518110611ad557611ad5613f51565b61055e8860600151600181518110611ad557611ad5613f51565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611b8957611b8082826001016111ae8a606001518581518110611ad557611ad5613f51565b50600101611b57565b50805160051b60208201209250611bb28180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f611bee835f015184602001518560400151612511565b9050806001600160401b03811115611c0857611c0861344c565b6040519080825280601f01601f191660200182016040528015611c32576020820181803683370190505b508351519092506020830190611c479061217c565b83515160f01b81526002015f5b845151811015611c8e57611c8482865f01518381518110611c7757611c77613f51565b6020026020010151612566565b9150600101611c54565b50611c9d84602001515161217c565b60208401515160f01b81526002015f5b846020015151811015611ceb57611ce18286602001518381518110611cd457611cd4613f51565b60200260200101516125a0565b9150600101611cad565b50611cfa84604001515161217c565b5f5b846040015151811015610abd57611d308286604001518381518110611d2357611d23613f51565b60200260200101516125dc565b9150600101611cfc565b611d5e60405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611d8357611d8361344c565b604051908082528060200260200182016040528015611dbc57816020015b611da9612ad1565b815260200190600190039081611da15790505b5083525f5b8161ffff16811015611e0257611dd6836125fd565b8551805184908110611dea57611dea613f51565b60209081029190910101919091529250600101611dc1565b50815160029092019160f01c61ffff82168114611e3257604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611e4e57611e4e61344c565b604051908082528060200260200182016040528015611e8757816020015b611e74612b05565b815260200190600190039081611e6c5790505b5060208501525f5b8161ffff16811015611ed257611ea484612645565b86602001518381518110611eba57611eba613f51565b60209081029190910101919091529350600101611e8f565b508061ffff166001600160401b03811115611eef57611eef61344c565b604051908082528060200260200182016040528015611f3357816020015b604080518082019091525f8082526020820152815260200190600190039081611f0d5790505b5060408501525f5b8161ffff16811015610ffc57604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611f8857611f88613f51565b60209081029190910101919091529350600101611f3b565b6020810151515f908190808203611fc6575f516020613f665f395f51905f5291506120be565b8060010361200157611ffa815f1b611ae286602001515f81518110611fed57611fed613f51565b602002602001015161268f565b91506120be565b8060020361204257611ffa815f1b61202886602001515f81518110611fed57611fed613f51565b61055e8760200151600181518110611fed57611fed613f51565b604080516001830181526002830160051b8101909152602081018290525f5b828110156120935761208a82826001016111ae89602001518581518110611fed57611fed613f51565b50600101612061565b50805160051b602082012092506120bc8180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f9061041e565b8051606b905f9065ffffffffffff1615801561210f57506020830151155b801561211d57506040830151155b90508061212b576046820191505b8451606602820191505f5b84518110156121735784818151811061215157612151613f51565b60200260200101516020015151602f0260430183019250806001019050612136565b50509392505050565b61ffff81111561219f5760405163161e7a6b60e11b815260040160405180910390fd5b50565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a083015160208201908152915060400161030c565b5f61220283835f015161227c565b905061221282602001515161217c565b60208201515160f01b81526002015f5b82602001515181101561226057612256828460200151838151811061224957612249613f51565b60200260200101516126fb565b9150600101612222565b506040828101518252606083015160208301908152910161030c565b5f818353505060010190565b5f61030c835f015184602001516122a28660400151611005565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b60e95f5b835181101561231f578381815181106122fa576122fa613f51565b6020026020010151602001515f015151602002600c01820191508060010190506122df565b509051602f0201919050565b612333612ad1565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b6123b360405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156123df576123df61344c565b60405190808252806020026020018201604052801561242f57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816123fd5790505b5060208401525f5b8161ffff1681101561247a5761244c83612746565b8560200151838151811061246257612462613f51565b60209081029190910101919091529250600101612437565b5050805160408381019190915260208201516060840152919391019150565b5f5f6124ab83602001515f01516127de565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff9092169082015260609020909150612509845f01516124f4575f6124f7565b60015b60ff16825f9182526020526040902090565b949350505050565b5f825184511461253457604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461255657604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b908301908152602683016121d7565b8051825260208082015181840152604080830180515160d01b82860152805190920151604685015290510151606683019081526086830161030c565b805160601b82525f60148301602083015160601b815290506014810161030c565b612605612ad1565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c60408201526026820180516046840161236d565b61264d612b05565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610295825f015165ffffffffffff165f1b836020015160028111156126b7576126b7612c66565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f60068301905061272381836020015160028111156107c7576107c7612c66565b6040830151606090811b825280840151901b60148201908152915060280161030c565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c80600281111561278f5761278f612c66565b836020019060028111156127a5576127a5612c66565b908160028111156127b8576127b8612c66565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f908082036127fe57505f516020613f665f395f51905f5292915050565b806001036128345761030c815f1b845f8151811061281e5761281e613f51565b60200260200101515f9182526020526040902090565b806002036128915761030c815f1b845f8151811061285457612854613f51565b60200260200101518560018151811061286f5761286f613f51565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b828110156128f2576128e982826001018784815181106128d2576128d2613f51565b602002602001015160019190910160051b82015290565b506001016128b0565b50805160051b60208201206125098280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff16815260200161293a612b05565b815260200161296a60405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001612988604080518082019091525f808252602082015290565b905290565b60405180608001604052806129a0612ad1565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160c0810182525f8082526020828101829052928201819052606082018190526080820181905260a08201529101908152602001606081525090565b6040518060e001604052805f65ffffffffffff168152602001612a566040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b815260200160608152602001612a9060405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b815260200160608152602001612ac560405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f815260200161298860405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60a0828403128015612b56575f5ffd5b509092915050565b5f60c08284031215612b6e575f5ffd5b50919050565b5f60c08284031215612b84575f5ffd5b61030c8383612b5e565b5f60208284031215612b9e575f5ffd5b81356001600160401b03811115612bb3575f5ffd5b8201610200818503121561030c575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f5f60208385031215612c0b575f5ffd5b82356001600160401b03811115612c20575f5ffd5b8301601f81018513612c30575f5ffd5b80356001600160401b03811115612c45575f5ffd5b856020828401011115612c56575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f8151808452602084019350602083015f5b82811015612d0557815165ffffffffffff8151168752602081015160038110612cc357634e487b7160e01b5f52602160045260245ffd5b6020888101919091526040828101516001600160a01b03908116918a019190915260609283015116918801919091526080909601959190910190600101612c8c565b5093949350505050565b60ff81511682525f602082015160806020850152612d306080850182612c7a565b905060408301516040850152606083015160608501528091505092915050565b6020815265ffffffffffff82511660208201525f6020830151612da660408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612dc2610140840182612d0f565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015265ffffffffffff60608201511660608301526080810151608083015260a081015160a08301525050565b60208152612eb8602082018351612df2565b6020828101516101c060e0840152805165ffffffffffff166101e084015280820151610200840152604081015160ff16610220840152606001516080610240840152805161026084018190525f929190910190610280600582901b850181019190850190845b81811015612fc45786840361027f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612f895783518252602082019150602084019350600183019250612f66565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612f1e565b50505060408501519150612fdc610100850183612e4c565b6060850151848203601f19016101c0860152915061041e8183612c7a565b5f60608284031215612b6e575f5ffd5b5f6060828403121561301a575f5ffd5b61030c8383612ffa565b5f5f83601f840112613034575f5ffd5b5081356001600160401b0381111561304a575f5ffd5b6020830191508360208260061b8501011115613064575f5ffd5b9250929050565b5f5f5f5f6040858703121561307e575f5ffd5b84356001600160401b03811115613093575f5ffd5b8501601f810187136130a3575f5ffd5b80356001600160401b038111156130b8575f5ffd5b87602060a0830284010111156130cc575f5ffd5b6020918201955093508501356001600160401b038111156130eb575f5ffd5b6130f787828801613024565b95989497509550505050565b5f60208284031215613113575f5ffd5b81356001600160401b03811115613128575f5ffd5b82016101c0818503121561030c575f5ffd5b5f6020828403121561314a575f5ffd5b81356001600160401b0381111561315f575f5ffd5b8201610120818503121561030c575f5ffd5b5f8151808452602084019350602083015f5b82811015612d0557613196868351612df2565b60c0959095019460209190910190600101613183565b5f82825180855260208501945060208160051b830101602085015f5b838110156131fa57601f198584030188526131e4838351612d0f565b60209889019890935091909101906001016131c8565b50909695505050505050565b6020815265ffffffffffff82511660208201525f602083015161322c6040840182612e4c565b506040830151610200610100840152613249610220840182613171565b6060850151805161ffff9081166101208701526020820151166101408601526040015162ffffff166101608501526080850151848203601f190161018086015290915061329682826131ac565b60a0860151805165ffffffffffff166101a087015260208101516101c0870152604001516101e086015260c086015160ff81166102008701529092509050612dea565b5f60808284031215612b6e575f5ffd5b5f602082840312156132f9575f5ffd5b81356001600160401b0381111561330e575f5ffd5b612509848285016132d9565b5f6020828403121561332a575f5ffd5b81356001600160401b0381111561333f575f5ffd5b61250984828501612ffa565b602081525f8251606060208401526133666080840182613171565b602085810151601f19868403016040870152805180845290820193505f92909101905b808310156133dc5783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a082019150602084019350600183019250613389565b506040860151858203601f19016060870152805180835260209182019450910191505f905b808210156134415761342a83855180516001600160a01b03908116835260209182015116910152565b604083019250602084019350600182019150613401565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b03811182821017156134825761348261344c565b60405290565b60405160c081016001600160401b03811182821017156134825761348261344c565b604051608081016001600160401b03811182821017156134825761348261344c565b60405160e081016001600160401b03811182821017156134825761348261344c565b604080519081016001600160401b03811182821017156134825761348261344c565b604051601f8201601f191681016001600160401b03811182821017156135385761353861344c565b604052919050565b803565ffffffffffff81168114613555575f5ffd5b919050565b5f6060828403121561356a575f5ffd5b613572613460565b905061357d82613540565b81526020828101359082015260409182013591810191909152919050565b5f60a082840312156135ab575f5ffd5b6135b3613460565b823581526020808401359082015290506135d0836040840161355a565b604082015292915050565b5f60a082840312156135eb575f5ffd5b61030c838361359b565b5f60c08284031215613605575f5ffd5b61360d613488565b905061361882613540565b815261362660208301613540565b602082015261363760408301613540565b604082015261364860608301613540565b60608201526080828101359082015260a09182013591810191909152919050565b5f60c08284031215613679575f5ffd5b61030c83836135f5565b5f6001600160401b0382111561369b5761369b61344c565b5060051b60200190565b80356001600160a01b0381168114613555575f5ffd5b5f60c082840312156136cb575f5ffd5b6136d3613488565b90506136de82613540565b81526136ec60208301613540565b60208201526136fd60408301613540565b6040820152613648606083016136a5565b5f82601f83011261371d575f5ffd5b813561373061372b82613683565b613510565b80828252602082019150602060c08402860101925085831115613751575f5ffd5b602085015b838110156137785761376887826136bb565b835260209092019160c001613756565b5095945050505050565b803561ffff81168114613555575f5ffd5b803562ffffff81168114613555575f5ffd5b5f606082840312156137b5575f5ffd5b6137bd613460565b90506137c882613782565b81526137d660208301613782565b60208201526135d060408301613793565b803560ff81168114613555575f5ffd5b5f82601f830112613806575f5ffd5b813561381461372b82613683565b8082825260208201915060208360071b860101925085831115613835575f5ffd5b602085015b838110156137785760808188031215613851575f5ffd5b6138596134aa565b61386282613540565b8152602082013560038110613875575f5ffd5b6020820152613886604083016136a5565b6040820152613897606083016136a5565b6060820152835260209092019160800161383a565b5f608082840312156138bc575f5ffd5b6138c46134aa565b90506138cf826137e7565b815260208201356001600160401b038111156138e9575f5ffd5b6138f5848285016137f7565b6020830152506040828101359082015260609182013591810191909152919050565b5f82601f830112613926575f5ffd5b813561393461372b82613683565b8082825260208201915060208360051b860101925085831115613955575f5ffd5b602085015b838110156137785780356001600160401b03811115613977575f5ffd5b613986886020838a01016138ac565b8452506020928301920161395a565b5f61020082360312156139a6575f5ffd5b6139ae6134cc565b6139b783613540565b81526139c636602085016135f5565b602082015260e08301356001600160401b038111156139e3575f5ffd5b6139ef3682860161370e565b604083015250613a033661010085016137a5565b60608201526101608301356001600160401b03811115613a21575f5ffd5b613a2d36828601613917565b608083015250613a4136610180850161355a565b60a0820152613a536101e084016137e7565b60c082015292915050565b5f60608284031215613a6e575f5ffd5b61030c838361355a565b5f60408284031215613a88575f5ffd5b613a906134ee565b9050613a9b826136a5565b8152613aa9602083016136a5565b602082015292915050565b5f60408284031215613ac4575f5ffd5b61030c8383613a78565b5f60808284031215613ade575f5ffd5b613ae66134aa565b9050613af182613540565b815260208281013590820152613b09604083016137e7565b604082015260608201356001600160401b03811115613b26575f5ffd5b8201601f81018413613b36575f5ffd5b8035613b4461372b82613683565b8082825260208201915060208360051b850101925086831115613b65575f5ffd5b602084015b83811015613cab5780356001600160401b03811115613b87575f5ffd5b85016040818a03601f19011215613b9c575f5ffd5b613ba46134ee565b60208201358015158114613bb6575f5ffd5b815260408201356001600160401b03811115613bd0575f5ffd5b6020818401019250506060828b031215613be8575f5ffd5b613bf0613460565b82356001600160401b03811115613c05575f5ffd5b8301601f81018c13613c15575f5ffd5b8035613c2361372b82613683565b8082825260208201915060208360051b85010192508e831115613c44575f5ffd5b6020840193505b82841015613c66578335825260209384019390910190613c4b565b845250613c7891505060208401613793565b6020820152613c8960408401613540565b6040820152806020830152508085525050602083019250602081019050613b6a565b5060608501525091949350505050565b5f6101c08236031215613ccc575f5ffd5b613cd46134aa565b613cde36846136bb565b815260c08301356001600160401b03811115613cf8575f5ffd5b613d0436828601613ace565b602083015250613d173660e085016135f5565b60408201526101a08301356001600160401b03811115613d35575f5ffd5b613d41368286016137f7565b60608301525092915050565b5f6101208236031215613d5e575f5ffd5b613d666134aa565b613d6f83613540565b8152613d7e366020850161359b565b602082015260c08301356001600160401b03811115613d9b575f5ffd5b613da7368286016138ac565b604083015250613dba3660e08501613a78565b606082015292915050565b5f60c08284031215613dd5575f5ffd5b61030c83836136bb565b5f6102953683613ace565b5f82601f830112613df9575f5ffd5b8135613e0761372b82613683565b8082825260208201915060208360061b860101925085831115613e28575f5ffd5b602085015b8381101561377857613e3f8782613a78565b8352602090920191604001613e2d565b5f60608236031215613e5f575f5ffd5b613e67613460565b82356001600160401b03811115613e7c575f5ffd5b613e883682860161370e565b82525060208301356001600160401b03811115613ea3575f5ffd5b830136601f820112613eb3575f5ffd5b8035613ec161372b82613683565b80828252602082019150602060a08402850101925036831115613ee2575f5ffd5b6020840193505b82841015613f0e57613efb368561359b565b825260208201915060a084019350613ee9565b602085015250505060408301356001600160401b03811115613f2e575f5ffd5b613f3a36828601613dea565b60408301525092915050565b5f61029536836138ac565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a264697066735822122006c3885d0468409cbf2299f6630a89f91c55b13c59b02f8609b0706c6fc0a7e064736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80c\x82\xD7\x05\x8B\x11a\0\x93W\x80c\xB8\xB0.\x0E\x11a\0cW\x80c\xB8\xB0.\x0E\x14a\x02\x0CW\x80c\xDCZ\x8B\xF8\x14a\x02\x1FW\x80c\xED\xBA\xCDD\x14a\x022W\x80c\xEE\xDE\xC1\x02\x14a\x02RW__\xFD[\x80c\x82\xD7\x05\x8B\x14a\x01\xB3W\x80c\x8Fm\x0E\x1A\x14a\x01\xC6W\x80c\xA1\xEC\x933\x14a\x01\xD9W\x80c\xAF\xB6:\xD4\x14a\x01\xECW__\xFD[\x80c&09b\x11a\0\xCEW\x80c&09b\x14a\x01MW\x80c]'\xCC\x95\x14a\x01mW\x80cy\x89\xAA\x10\x14a\x01\x8DW\x80cz\x9AU*\x14a\x01\xA0W__\xFD[\x80c\x1F9pg\x14a\0\xF4W\x80c\x1F\xE0j\xB4\x14a\x01\x1AW\x80c&\x1B\xF64\x14a\x01-W[__\xFD[a\x01\x07a\x01\x026`\x04a+EV[a\x02}V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x07a\x01(6`\x04a+tV[a\x02\x9BV[a\x01@a\x01;6`\x04a+\x8EV[a\x02\xB3V[`@Qa\x01\x11\x91\x90a+\xC5V[a\x01`a\x01[6`\x04a+\xFAV[a\x02\xC6V[`@Qa\x01\x11\x91\x90a-PV[a\x01\x80a\x01{6`\x04a+\xFAV[a\x03\x13V[`@Qa\x01\x11\x91\x90a.\xA6V[a\x01\x07a\x01\x9B6`\x04a0\nV[a\x03YV[a\x01\x07a\x01\xAE6`\x04a0kV[a\x03qV[a\x01@a\x01\xC16`\x04a1\x03V[a\x04'V[a\x01@a\x01\xD46`\x04a1:V[a\x04:V[a\x01\x07a\x01\xE76`\x04a+tV[a\x04MV[a\x01\xFFa\x01\xFA6`\x04a+\xFAV[a\x04eV[`@Qa\x01\x11\x91\x90a2\x06V[a\x01\x07a\x02\x1A6`\x04a2\xE9V[a\x04\xABV[a\x01@a\x02-6`\x04a3\x1AV[a\x04\xBDV[a\x02Ea\x02@6`\x04a+\xFAV[a\x04\xD0V[`@Qa\x01\x11\x91\x90a3KV[a\x02ea\x02`6`\x04a2\xE9V[a\x052V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x11V[_a\x02\x95a\x02\x906\x84\x90\x03\x84\x01\x84a5\xDBV[a\x05DV[\x92\x91PPV[_a\x02\x95a\x02\xAE6\x84\x90\x03\x84\x01\x84a6iV[a\x05xV[``a\x02\x95a\x02\xC1\x83a9\x95V[a\x05\xD3V[a\x02\xCEa)\x19V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08\x13\x92PPPV[\x93\x92PPPV[a\x03\x1Ba)\x8DV[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\n\xC5\x92PPPV[_a\x02\x95a\x03l6\x84\x90\x03\x84\x01\x84a:^V[a\x10\x05V[_a\x04\x1E\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xC2Wa\x03\xB3`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a5\xDBV[\x81R` \x01\x90`\x01\x01\x90a\x03\x96V[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04\x14Wa\x04\x05`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a:\xB4V[\x81R` \x01\x90`\x01\x01\x90a\x03\xE8V[PPPPPa\x106V[\x95\x94PPPPPV[``a\x02\x95a\x045\x83a<\xBBV[a\x11\xEDV[``a\x02\x95a\x04H\x83a=MV[a\x15fV[_a\x02\x95a\x04`6\x84\x90\x03\x84\x01\x84a=\xC5V[a\x17}V[a\x04ma*\x06V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x17\xF4\x92PPPV[_a\x02\x95a\x04\xB8\x83a=\xDFV[a\x1AeV[``a\x02\x95a\x04\xCB\x83a>OV[a\x1B\xD5V[a\x04\xF4`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1D:\x92PPPV[_a\x02\x95a\x05?\x83a?FV[a\x1F\xA0V[_a\x02\x95\x82_\x01Q\x83` \x01Qa\x05^\x85`@\x01Qa\x10\x05V[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q``\x80\x87\x01Q`\x80\x80\x89\x01Q`\xA0\x80\x8B\x01Q\x87Qe\xFF\xFF\xFF\xFF\xFF\xFF\x9B\x8C\x16\x81R\x98\x8B\x16\x99\x89\x01\x99\x90\x99R\x94\x89\x16\x95\x87\x01\x95\x90\x95R\x96\x16\x90\x84\x01R\x93\x82\x01R\x91\x82\x01R`\xC0\x90 _\x90a\x02\x95V[``_a\x05\xED\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa \xF1V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x07Wa\x06\x07a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x061W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x83\x1B`2\x85\x01R\x81Q``\x01Q\x90\x92\x1B`8\x84\x01R\x80Q`\x80\x01Q`>\x84\x01RQ`\xA0\x01Q`^\x83\x01R\x84\x01QQ\x90\x92P`~\x83\x01\x90a\x06\xA3\x90a!|V[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x06\xF1Wa\x06\xE7\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x06\xDAWa\x06\xDAa?QV[` \x02` \x01\x01Qa!\xA2V[\x91P`\x01\x01a\x06\xB3V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x07/\x90a!|V[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x07}Wa\x07s\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x07fWa\x07fa?QV[` \x02` \x01\x01Qa!\xF4V[\x91P`\x01\x01a\x07?V[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x07\xA1WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x07\xB3WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x07\xCC\x82\x82a\x07\xC5W`\x01a\"|V[_[a\"|V[\x91P\x80a\x07\xFBW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x08\t\x82\x86`\xC0\x01Qa\"|V[\x91PPPP\x91\x90PV[a\x08\x1Ba)\x19V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xE2Wa\x08\xE2a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t2W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\t\0W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xBDW\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\tmWa\tma?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xB4W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xC9Wa\t\xC9a,fV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\xE3Wa\t\xE3a?QV[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\n\0Wa\n\0a,fV[\x90\x81`\x02\x81\x11\x15a\n\x13Wa\n\x13a,fV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n9Wa\n9a?QV[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\nq\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n\x8BWa\n\x8Ba?QV[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\t>V[PPP\x91\x90PV[a\n\xCDa)\x8DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0B[Wa\x0B[a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0B\xBEW\x81` \x01[a\x0B\xAB`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x0ByW\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\r\x8CW\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0C\x05Wa\x0C\x05a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0C8Wa\x0C8a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0CaW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0C|Wa\x0C|a?QV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0C\xF1W\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0C\xB9Wa\x0C\xB9a?QV[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0C\xD9Wa\x0C\xD9a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0C\x8DV[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\r\x15Wa\r\x15a?QV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\rWWa\rWa?QV[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0B\xCAV[P\x81Q\x83Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x84\x01Q\x85Q`\xA0\x90\x81\x01\x91\x90\x91R`@\x80\x86\x01Q\x81\x88\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x88\x01Q\x81Q\x90\x83\x1C\x95\x01\x94\x90\x94R`L\x87\x01Q\x84Q\x90\x82\x1C\x92\x01\x91\x90\x91R`R\x86\x01Q\x83Q\x91\x1C``\x90\x91\x01R`X\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`x\x84\x01Q\x90Q\x90\x91\x01R`\x98\x82\x01Q`\x9A\x90\x92\x01\x91`\xF0\x1C\x80\x15a\n\xBDW\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E5Wa\x0E5a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\x85W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x0ESW\x90P[P``\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xFCW\x83Q`\xD0\x1C`\x06\x85\x01\x86``\x01Q\x83\x81Q\x81\x10a\x0E\xB8Wa\x0E\xB8a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x94P`\xF8\x1C`\x02\x81\x11\x15a\x0E\xFFW`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\x0F\x14Wa\x0F\x14a,fV[\x86``\x01Q\x83\x81Q\x81\x10a\x0F*Wa\x0F*a?QV[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\x0FGWa\x0FGa,fV[\x90\x81`\x02\x81\x11\x15a\x0FZWa\x0FZa,fV[\x90RP\x84Q``\x1C`\x14\x86\x01\x87``\x01Q\x84\x81Q\x81\x10a\x0F|Wa\x0F|a?QV[` \x02` \x01\x01Q`@\x01\x81\x97P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\x0F\xB4\x85\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x87``\x01Q\x84\x81Q\x81\x10a\x0F\xCAWa\x0F\xCAa?QV[` \x02` \x01\x01Q``\x01\x81\x97P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\x0E\x8DV[PPPP\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x95V[_\x81Q\x83Q\x14a\x10YW`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x10yW_Q` a?f_9_Q\x90_R\x91PPa\x02\x95V[\x80`\x01\x03a\x10\xDCW_a\x10\xBE\x85_\x81Q\x81\x10a\x10\x97Wa\x10\x97a?QV[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[` \x02` \x01\x01Qa\"\x88V[\x90Pa\x10\xD3\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x95V[\x80`\x02\x03a\x11PW_a\x10\xFA\x85_\x81Q\x81\x10a\x10\x97Wa\x10\x97a?QV[\x90P_a\x11.\x86`\x01\x81Q\x81\x10a\x11\x13Wa\x11\x13a?QV[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x95V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x11\xC6Wa\x11\xBD\x82\x82`\x01\x01a\x11\xAE\x89\x85\x81Q\x81\x10a\x11\x94Wa\x11\x94a?QV[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x10\xB1Wa\x10\xB1a?QV[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11oV[P\x80Q`\x05\x1B` \x82\x01 a\x04\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[``_a\x12\x06\x83` \x01Q``\x01Q\x84``\x01Qa\"\xDBV[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12 Wa\x12 a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x12JW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x12\xB5\x90\x82\x90a\"|V[` \x85\x01Q``\x01QQ\x90\x91Pa\x12\xCB\x81a!|V[a\x12\xDB\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x14MWa\x13!\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x13\x05Wa\x13\x05a?QV[` \x02` \x01\x01Q_\x01Qa\x13\x1AW_a\"|V[`\x01a\"|V[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x13>Wa\x13>a?QV[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x13Y\x81a!|V[a\x13i\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x13\xCDWa\x13\xC3\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x13\x93Wa\x13\x93a?QV[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x13\xB3Wa\x13\xB3a?QV[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x13mV[Pa\x14\x07\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x13\xECWa\x13\xECa?QV[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x14B\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x14'Wa\x14'a?QV[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x12\xDFV[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R`@\x80\x89\x01\x80QQ`\xD0\x90\x81\x1B\x83\x89\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x88\x01R\x80Q\x90\x91\x01Q\x82\x1B`L\x87\x01R\x80Q``\x90\x81\x01Q\x90\x92\x1B`R\x87\x01R\x80Q\x90\x93\x01Q`X\x86\x01R\x91Q\x01Q`x\x84\x01R\x85\x01QQ`\x98\x90\x92\x01\x91a\x14\xCB\x81a!|V[a\x14\xDB\x83\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x92P_[\x81\x81\x10\x15a\x15\\W_\x87``\x01Q\x82\x81Q\x81\x10a\x14\xFEWa\x14\xFEa?QV[` \x02` \x01\x01Q\x90Pa\x15\x1B\x85\x82_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x94Pa\x157\x85\x82` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[`@\x82\x01Q``\x90\x81\x1B\x82R\x91\x82\x01Q\x90\x91\x1B`\x14\x82\x01R`(\x01\x93P`\x01\x01a\x14\xDFV[PPPPP\x91\x90PV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\x91Wa\x15\x91a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x15\xBBW` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x16#\x90\x82\x90a\"|V[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x16o\x90a!|V[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xBDWa\x16\xC8\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x16\xB2Wa\x16\xB2a?QV[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x17\x05\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x16\xE8Wa\x16\xE8a?QV[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[\x91Pa\x17<\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x17%Wa\x17%a?QV[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x17s\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x17\\Wa\x17\\a?QV[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x16\x83V[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x03\x0C\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x17\xFCa*\x06V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x90\x82\x1C`@\x90\x91\x01R`8\x84\x01Q\x82Q\x91\x1C``\x90\x91\x01R`>\x83\x01Q\x81Q`\x80\x90\x81\x01\x91\x90\x91R`^\x84\x01Q\x91Q`\xA0\x01\x91\x90\x91R`~\x83\x01Q\x90\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18\x8AWa\x18\x8Aa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x18\xC3W\x81` \x01[a\x18\xB0a*\xD1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x18\xA8W\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x19\x0EWa\x18\xE0\x83a#+V[\x85`@\x01Q\x83\x81Q\x81\x10a\x18\xF6Wa\x18\xF6a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x18\xCBV[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19gWa\x19ga4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x19\xC3W\x81` \x01[a\x19\xB0`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x19\x85W\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1A\x0EWa\x19\xE0\x84a#\x88V[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x19\xF6Wa\x19\xF6a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x19\xCBV[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x1ASW\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x1A\xAEW_Q` a?f_9_Q\x90_R\x91Pa\x1B\xB4V[\x80`\x01\x03a\x1A\xF7Wa\x1A\xF0\x81_\x1Ba\x1A\xE2\x87``\x01Q_\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[` \x02` \x01\x01Qa$\x99V[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x1B\xB4V[\x80`\x02\x03a\x1B8Wa\x1A\xF0\x81_\x1Ba\x1B\x1E\x87``\x01Q_\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[a\x05^\x88``\x01Q`\x01\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1B\x89Wa\x1B\x80\x82\x82`\x01\x01a\x11\xAE\x8A``\x01Q\x85\x81Q\x81\x10a\x1A\xD5Wa\x1A\xD5a?QV[P`\x01\x01a\x1BWV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1B\xB2\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x1B\xEE\x83_\x01Q\x84` \x01Q\x85`@\x01Qa%\x11V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x08Wa\x1C\x08a4LV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x1C2W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x1CG\x90a!|V[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x1C\x8EWa\x1C\x84\x82\x86_\x01Q\x83\x81Q\x81\x10a\x1CwWa\x1Cwa?QV[` \x02` \x01\x01Qa%fV[\x91P`\x01\x01a\x1CTV[Pa\x1C\x9D\x84` \x01QQa!|V[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x1C\xEBWa\x1C\xE1\x82\x86` \x01Q\x83\x81Q\x81\x10a\x1C\xD4Wa\x1C\xD4a?QV[` \x02` \x01\x01Qa%\xA0V[\x91P`\x01\x01a\x1C\xADV[Pa\x1C\xFA\x84`@\x01QQa!|V[_[\x84`@\x01QQ\x81\x10\x15a\n\xBDWa\x1D0\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1D#Wa\x1D#a?QV[` \x02` \x01\x01Qa%\xDCV[\x91P`\x01\x01a\x1C\xFCV[a\x1D^`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1D\x83Wa\x1D\x83a4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1D\xBCW\x81` \x01[a\x1D\xA9a*\xD1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1D\xA1W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1E\x02Wa\x1D\xD6\x83a%\xFDV[\x85Q\x80Q\x84\x90\x81\x10a\x1D\xEAWa\x1D\xEAa?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1D\xC1V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1E2W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1ENWa\x1ENa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1E\x87W\x81` \x01[a\x1Eta+\x05V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1ElW\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1E\xD2Wa\x1E\xA4\x84a&EV[\x86` \x01Q\x83\x81Q\x81\x10a\x1E\xBAWa\x1E\xBAa?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1E\x8FV[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\xEFWa\x1E\xEFa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1F3W\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1F\rW\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xFCW`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1F\x88Wa\x1F\x88a?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1F;V[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1F\xC6W_Q` a?f_9_Q\x90_R\x91Pa \xBEV[\x80`\x01\x03a \x01Wa\x1F\xFA\x81_\x1Ba\x1A\xE2\x86` \x01Q_\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[` \x02` \x01\x01Qa&\x8FV[\x91Pa \xBEV[\x80`\x02\x03a BWa\x1F\xFA\x81_\x1Ba (\x86` \x01Q_\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[a\x05^\x87` \x01Q`\x01\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a \x93Wa \x8A\x82\x82`\x01\x01a\x11\xAE\x89` \x01Q\x85\x81Q\x81\x10a\x1F\xEDWa\x1F\xEDa?QV[P`\x01\x01a aV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa \xBC\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x04\x1EV[\x80Q`k\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a!\x0FWP` \x83\x01Q\x15[\x80\x15a!\x1DWP`@\x83\x01Q\x15[\x90P\x80a!+W`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a!sW\x84\x81\x81Q\x81\x10a!QWa!Qa?QV[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa!6V[PP\x93\x92PPPV[a\xFF\xFF\x81\x11\x15a!\x9FW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x03\x0CV[_a\"\x02\x83\x83_\x01Qa\"|V[\x90Pa\"\x12\x82` \x01QQa!|V[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\"`Wa\"V\x82\x84` \x01Q\x83\x81Q\x81\x10a\"IWa\"Ia?QV[` \x02` \x01\x01Qa&\xFBV[\x91P`\x01\x01a\"\"V[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x03\x0CV[_\x81\x83SPP`\x01\x01\x90V[_a\x03\x0C\x83_\x01Q\x84` \x01Qa\"\xA2\x86`@\x01Qa\x10\x05V[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[`\xE9_[\x83Q\x81\x10\x15a#\x1FW\x83\x81\x81Q\x81\x10a\"\xFAWa\"\xFAa?QV[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\"\xDFV[P\x90Q`/\x02\x01\x91\x90PV[a#3a*\xD1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a#\xB3`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a#\xDFWa#\xDFa4LV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a$/W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a#\xFDW\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a$zWa$L\x83a'FV[\x85` \x01Q\x83\x81Q\x81\x10a$bWa$ba?QV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a$7V[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a$\xAB\x83` \x01Q_\x01Qa'\xDEV[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa%\t\x84_\x01Qa$\xF4W_a$\xF7V[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[_\x82Q\x84Q\x14a%4W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a%VW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a!\xD7V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x03\x0CV[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x03\x0CV[a&\x05a*\xD1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a#mV[a&Ma+\x05V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x95\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a&\xB7Wa&\xB7a,fV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa'#\x81\x83` \x01Q`\x02\x81\x11\x15a\x07\xC7Wa\x07\xC7a,fV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x03\x0CV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a'\x8FWa'\x8Fa,fV[\x83` \x01\x90`\x02\x81\x11\x15a'\xA5Wa'\xA5a,fV[\x90\x81`\x02\x81\x11\x15a'\xB8Wa'\xB8a,fV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a'\xFEWP_Q` a?f_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a(4Wa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a(\x1EWa(\x1Ea?QV[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a(\x91Wa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a(TWa(Ta?QV[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a(oWa(oa?QV[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a(\xF2Wa(\xE9\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a(\xD2Wa(\xD2a?QV[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a(\xB0V[P\x80Q`\x05\x1B` \x82\x01 a%\t\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a):a+\x05V[\x81R` \x01a)j`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a)\x88`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80`\x80\x01`@R\x80a)\xA0a*\xD1V[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01\x81\x90R`\xA0\x82\x01R\x91\x01\x90\x81R` \x01``\x81RP\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a*V`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a*\x90`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a*\xC5`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a)\x88`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a+VW__\xFD[P\x90\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a+nW__\xFD[P\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a+\x84W__\xFD[a\x03\x0C\x83\x83a+^V[_` \x82\x84\x03\x12\x15a+\x9EW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xB3W__\xFD[\x82\x01a\x02\0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[__` \x83\x85\x03\x12\x15a,\x0BW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a, W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a,0W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a,EW__\xFD[\x85` \x82\x84\x01\x01\x11\x15a,VW__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a-\x05W\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x87R` \x81\x01Q`\x03\x81\x10a,\xC3WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x88\x81\x01\x91\x90\x91R`@\x82\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x8A\x01\x91\x90\x91R``\x92\x83\x01Q\x16\x91\x88\x01\x91\x90\x91R`\x80\x90\x96\x01\x95\x91\x90\x91\x01\x90`\x01\x01a,\x8CV[P\x93\x94\x93PPPPV[`\xFF\x81Q\x16\x82R_` \x82\x01Q`\x80` \x85\x01Ra-0`\x80\x85\x01\x82a,zV[\x90P`@\x83\x01Q`@\x85\x01R``\x83\x01Q``\x85\x01R\x80\x91PP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa-\xA6`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra-\xC2a\x01@\x84\x01\x82a-\x0FV[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[` \x81Ra.\xB8` \x82\x01\x83Qa-\xF2V[` \x82\x81\x01Qa\x01\xC0`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xE0\x84\x01R\x80\x82\x01Qa\x02\0\x84\x01R`@\x81\x01Q`\xFF\x16a\x02 \x84\x01R``\x01Q`\x80a\x02@\x84\x01R\x80Qa\x02`\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02\x80`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a/\xC4W\x86\x84\x03a\x02\x7F\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a/\x89W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa/fV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a/\x1EV[PPP`@\x85\x01Q\x91Pa/\xDCa\x01\0\x85\x01\x83a.LV[``\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\xC0\x86\x01R\x91Pa\x04\x1E\x81\x83a,zV[_``\x82\x84\x03\x12\x15a+nW__\xFD[_``\x82\x84\x03\x12\x15a0\x1AW__\xFD[a\x03\x0C\x83\x83a/\xFAV[__\x83`\x1F\x84\x01\x12a04W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0JW__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a0dW__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a0~W__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a0\x93W__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a0\xA3W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xB8W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a0\xCCW__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xEBW__\xFD[a0\xF7\x87\x82\x88\x01a0$V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a1\x13W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1(W__\xFD[\x82\x01a\x01\xC0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_` \x82\x84\x03\x12\x15a1JW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1_W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a-\x05Wa1\x96\x86\x83Qa-\xF2V[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a1\x83V[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a1\xFAW`\x1F\x19\x85\x84\x03\x01\x88Ra1\xE4\x83\x83Qa-\x0FV[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a1\xC8V[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa2,`@\x84\x01\x82a.LV[P`@\x83\x01Qa\x02\0a\x01\0\x84\x01Ra2Ia\x02 \x84\x01\x82a1qV[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01 \x87\x01R` \x82\x01Q\x16a\x01@\x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01`\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\x80\x86\x01R\x90\x91Pa2\x96\x82\x82a1\xACV[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x87\x01R` \x81\x01Qa\x01\xC0\x87\x01R`@\x01Qa\x01\xE0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x02\0\x87\x01R\x90\x92P\x90Pa-\xEAV[_`\x80\x82\x84\x03\x12\x15a+nW__\xFD[_` \x82\x84\x03\x12\x15a2\xF9W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3\x0EW__\xFD[a%\t\x84\x82\x85\x01a2\xD9V[_` \x82\x84\x03\x12\x15a3*W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3?W__\xFD[a%\t\x84\x82\x85\x01a/\xFAV[` \x81R_\x82Q``` \x84\x01Ra3f`\x80\x84\x01\x82a1qV[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a3\xDCW\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa3\x89V[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a4AWa4*\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa4\x01V[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@R\x90V[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\x82Wa4\x82a4LV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a58Wa58a4LV[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a5jW__\xFD[a5ra4`V[\x90Pa5}\x82a5@V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a5\xABW__\xFD[a5\xB3a4`V[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa5\xD0\x83`@\x84\x01a5ZV[`@\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a5\xEBW__\xFD[a\x03\x0C\x83\x83a5\x9BV[_`\xC0\x82\x84\x03\x12\x15a6\x05W__\xFD[a6\ra4\x88V[\x90Pa6\x18\x82a5@V[\x81Ra6&` \x83\x01a5@V[` \x82\x01Ra67`@\x83\x01a5@V[`@\x82\x01Ra6H``\x83\x01a5@V[``\x82\x01R`\x80\x82\x81\x015\x90\x82\x01R`\xA0\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a6yW__\xFD[a\x03\x0C\x83\x83a5\xF5V[_`\x01`\x01`@\x1B\x03\x82\x11\x15a6\x9BWa6\x9Ba4LV[P`\x05\x1B` \x01\x90V[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a5UW__\xFD[_`\xC0\x82\x84\x03\x12\x15a6\xCBW__\xFD[a6\xD3a4\x88V[\x90Pa6\xDE\x82a5@V[\x81Ra6\xEC` \x83\x01a5@V[` \x82\x01Ra6\xFD`@\x83\x01a5@V[`@\x82\x01Ra6H``\x83\x01a6\xA5V[_\x82`\x1F\x83\x01\x12a7\x1DW__\xFD[\x815a70a7+\x82a6\x83V[a5\x10V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a7QW__\xFD[` \x85\x01[\x83\x81\x10\x15a7xWa7h\x87\x82a6\xBBV[\x83R` \x90\x92\x01\x91`\xC0\x01a7VV[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a5UW__\xFD[_``\x82\x84\x03\x12\x15a7\xB5W__\xFD[a7\xBDa4`V[\x90Pa7\xC8\x82a7\x82V[\x81Ra7\xD6` \x83\x01a7\x82V[` \x82\x01Ra5\xD0`@\x83\x01a7\x93V[\x805`\xFF\x81\x16\x81\x14a5UW__\xFD[_\x82`\x1F\x83\x01\x12a8\x06W__\xFD[\x815a8\x14a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a85W__\xFD[` \x85\x01[\x83\x81\x10\x15a7xW`\x80\x81\x88\x03\x12\x15a8QW__\xFD[a8Ya4\xAAV[a8b\x82a5@V[\x81R` \x82\x015`\x03\x81\x10a8uW__\xFD[` \x82\x01Ra8\x86`@\x83\x01a6\xA5V[`@\x82\x01Ra8\x97``\x83\x01a6\xA5V[``\x82\x01R\x83R` \x90\x92\x01\x91`\x80\x01a8:V[_`\x80\x82\x84\x03\x12\x15a8\xBCW__\xFD[a8\xC4a4\xAAV[\x90Pa8\xCF\x82a7\xE7V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xE9W__\xFD[a8\xF5\x84\x82\x85\x01a7\xF7V[` \x83\x01RP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a9&W__\xFD[\x815a94a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a9UW__\xFD[` \x85\x01[\x83\x81\x10\x15a7xW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a9wW__\xFD[a9\x86\x88` \x83\x8A\x01\x01a8\xACV[\x84RP` \x92\x83\x01\x92\x01a9ZV[_a\x02\0\x826\x03\x12\x15a9\xA6W__\xFD[a9\xAEa4\xCCV[a9\xB7\x83a5@V[\x81Ra9\xC66` \x85\x01a5\xF5V[` \x82\x01R`\xE0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a9\xE3W__\xFD[a9\xEF6\x82\x86\x01a7\x0EV[`@\x83\x01RPa:\x036a\x01\0\x85\x01a7\xA5V[``\x82\x01Ra\x01`\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:!W__\xFD[a:-6\x82\x86\x01a9\x17V[`\x80\x83\x01RPa:A6a\x01\x80\x85\x01a5ZV[`\xA0\x82\x01Ra:Sa\x01\xE0\x84\x01a7\xE7V[`\xC0\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a:nW__\xFD[a\x03\x0C\x83\x83a5ZV[_`@\x82\x84\x03\x12\x15a:\x88W__\xFD[a:\x90a4\xEEV[\x90Pa:\x9B\x82a6\xA5V[\x81Ra:\xA9` \x83\x01a6\xA5V[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a:\xC4W__\xFD[a\x03\x0C\x83\x83a:xV[_`\x80\x82\x84\x03\x12\x15a:\xDEW__\xFD[a:\xE6a4\xAAV[\x90Pa:\xF1\x82a5@V[\x81R` \x82\x81\x015\x90\x82\x01Ra;\t`@\x83\x01a7\xE7V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;&W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a;6W__\xFD[\x805a;Da7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a;eW__\xFD[` \x84\x01[\x83\x81\x10\x15a<\xABW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a;\x87W__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a;\x9CW__\xFD[a;\xA4a4\xEEV[` \x82\x015\x80\x15\x15\x81\x14a;\xB6W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xD0W__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a;\xE8W__\xFD[a;\xF0a4`V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a<\x05W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a<\x15W__\xFD[\x805a<#a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a<DW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a<fW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a<KV[\x84RPa<x\x91PP` \x84\x01a7\x93V[` \x82\x01Ra<\x89`@\x84\x01a5@V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa;jV[P``\x85\x01RP\x91\x94\x93PPPPV[_a\x01\xC0\x826\x03\x12\x15a<\xCCW__\xFD[a<\xD4a4\xAAV[a<\xDE6\x84a6\xBBV[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a<\xF8W__\xFD[a=\x046\x82\x86\x01a:\xCEV[` \x83\x01RPa=\x176`\xE0\x85\x01a5\xF5V[`@\x82\x01Ra\x01\xA0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a=5W__\xFD[a=A6\x82\x86\x01a7\xF7V[``\x83\x01RP\x92\x91PPV[_a\x01 \x826\x03\x12\x15a=^W__\xFD[a=fa4\xAAV[a=o\x83a5@V[\x81Ra=~6` \x85\x01a5\x9BV[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a=\x9BW__\xFD[a=\xA76\x82\x86\x01a8\xACV[`@\x83\x01RPa=\xBA6`\xE0\x85\x01a:xV[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a=\xD5W__\xFD[a\x03\x0C\x83\x83a6\xBBV[_a\x02\x956\x83a:\xCEV[_\x82`\x1F\x83\x01\x12a=\xF9W__\xFD[\x815a>\x07a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a>(W__\xFD[` \x85\x01[\x83\x81\x10\x15a7xWa>?\x87\x82a:xV[\x83R` \x90\x92\x01\x91`@\x01a>-V[_``\x826\x03\x12\x15a>_W__\xFD[a>ga4`V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a>|W__\xFD[a>\x886\x82\x86\x01a7\x0EV[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a>\xA3W__\xFD[\x83\x016`\x1F\x82\x01\x12a>\xB3W__\xFD[\x805a>\xC1a7+\x82a6\x83V[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a>\xE2W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a?\x0EWa>\xFB6\x85a5\x9BV[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa>\xE9V[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a?.W__\xFD[a?:6\x82\x86\x01a=\xEAV[`@\x83\x01RP\x92\x91PPV[_a\x02\x956\x83a8\xACV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \x06\xC3\x88]\x04h@\x9C\xBF\"\x99\xF6c\n\x89\xF9\x1CU\xB1<Y\xB0/\x86\t\xB0plo\xC0\xA7\xE0dsolcC\0\x08\x1E\x003",
    );
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `InconsistentLengths()` and selector `0xb1f40f77`.
```solidity
error InconsistentLengths();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InconsistentLengths;
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = ();
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = ();
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<InconsistentLengths> for UnderlyingRustTuple<'_> {
            fn from(value: InconsistentLengths) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InconsistentLengths {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InconsistentLengths {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InconsistentLengths()";
            const SELECTOR: [u8; 4] = [177u8, 244u8, 15u8, 119u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                ()
            }
            #[inline]
            fn abi_decode_raw_validate(data: &[u8]) -> alloy_sol_types::Result<Self> {
                <Self::Parameters<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Self::new)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `InvalidBondType()` and selector `0xf6b209a8`.
```solidity
error InvalidBondType();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidBondType;
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = ();
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = ();
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<InvalidBondType> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidBondType) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidBondType {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidBondType {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidBondType()";
            const SELECTOR: [u8; 4] = [246u8, 178u8, 9u8, 168u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                ()
            }
            #[inline]
            fn abi_decode_raw_validate(data: &[u8]) -> alloy_sol_types::Result<Self> {
                <Self::Parameters<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Self::new)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `LengthExceedsUint16()` and selector `0x2c3cf4d6`.
```solidity
error LengthExceedsUint16();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LengthExceedsUint16;
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = ();
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = ();
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<LengthExceedsUint16> for UnderlyingRustTuple<'_> {
            fn from(value: LengthExceedsUint16) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for LengthExceedsUint16 {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for LengthExceedsUint16 {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "LengthExceedsUint16()";
            const SELECTOR: [u8; 4] = [44u8, 60u8, 244u8, 214u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                ()
            }
            #[inline]
            fn abi_decode_raw_validate(data: &[u8]) -> alloy_sol_types::Result<Self> {
                <Self::Parameters<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Self::new)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `MetadataLengthMismatch()` and selector `0x3e5e64c4`.
```solidity
error MetadataLengthMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct MetadataLengthMismatch;
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = ();
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = ();
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<MetadataLengthMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: MetadataLengthMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for MetadataLengthMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for MetadataLengthMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "MetadataLengthMismatch()";
            const SELECTOR: [u8; 4] = [62u8, 94u8, 100u8, 196u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                ()
            }
            #[inline]
            fn abi_decode_raw_validate(data: &[u8]) -> alloy_sol_types::Result<Self> {
                <Self::Parameters<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Self::new)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `ProposalTransitionLengthMismatch()` and selector `0x5c167d7e`.
```solidity
error ProposalTransitionLengthMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposalTransitionLengthMismatch;
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[doc(hidden)]
        type UnderlyingSolTuple<'a> = ();
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = ();
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<ProposalTransitionLengthMismatch>
        for UnderlyingRustTuple<'_> {
            fn from(value: ProposalTransitionLengthMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for ProposalTransitionLengthMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ProposalTransitionLengthMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ProposalTransitionLengthMismatch()";
            const SELECTOR: [u8; 4] = [92u8, 22u8, 125u8, 126u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                ()
            }
            #[inline]
            fn abi_decode_raw_validate(data: &[u8]) -> alloy_sol_types::Result<Self> {
                <Self::Parameters<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Self::new)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `decodeProposeInput(bytes)` and selector `0xafb63ad4`.
```solidity
function decodeProposeInput(bytes memory _data) external pure returns (IInbox.ProposeInput memory input_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProposeInputCall {
        #[allow(missing_docs)]
        pub _data: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`decodeProposeInput(bytes)`](decodeProposeInputCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProposeInputReturn {
        #[allow(missing_docs)]
        pub input_: <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProposeInputCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProposeInputCall) -> Self {
                    (value._data,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProposeInputCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _data: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProposeInput,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProposeInputReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProposeInputReturn) -> Self {
                    (value.input_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProposeInputReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { input_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for decodeProposeInputCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Bytes,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IInbox::ProposeInput,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "decodeProposeInput(bytes)";
            const SELECTOR: [u8; 4] = [175u8, 182u8, 58u8, 212u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (<IInbox::ProposeInput as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: decodeProposeInputReturn = r.into();
                        r.input_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: decodeProposeInputReturn = r.into();
                        r.input_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `decodeProposedEvent(bytes)` and selector `0x5d27cc95`.
```solidity
function decodeProposedEvent(bytes memory _data) external pure returns (IInbox.ProposedEventPayload memory payload_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProposedEventCall {
        #[allow(missing_docs)]
        pub _data: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`decodeProposedEvent(bytes)`](decodeProposedEventCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProposedEventReturn {
        #[allow(missing_docs)]
        pub payload_: <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProposedEventCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProposedEventCall) -> Self {
                    (value._data,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProposedEventCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _data: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProposedEventPayload,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProposedEventReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProposedEventReturn) -> Self {
                    (value.payload_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProposedEventReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { payload_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for decodeProposedEventCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Bytes,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IInbox::ProposedEventPayload,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "decodeProposedEvent(bytes)";
            const SELECTOR: [u8; 4] = [93u8, 39u8, 204u8, 149u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <IInbox::ProposedEventPayload as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: decodeProposedEventReturn = r.into();
                        r.payload_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: decodeProposedEventReturn = r.into();
                        r.payload_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `decodeProveInput(bytes)` and selector `0xedbacd44`.
```solidity
function decodeProveInput(bytes memory _data) external pure returns (IInbox.ProveInput memory input_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProveInputCall {
        #[allow(missing_docs)]
        pub _data: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`decodeProveInput(bytes)`](decodeProveInputCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProveInputReturn {
        #[allow(missing_docs)]
        pub input_: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProveInputCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProveInputCall) -> Self {
                    (value._data,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProveInputCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _data: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProveInput,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProveInputReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProveInputReturn) -> Self {
                    (value.input_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProveInputReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { input_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for decodeProveInputCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Bytes,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IInbox::ProveInput as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IInbox::ProveInput,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "decodeProveInput(bytes)";
            const SELECTOR: [u8; 4] = [237u8, 186u8, 205u8, 68u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (<IInbox::ProveInput as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: decodeProveInputReturn = r.into();
                        r.input_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: decodeProveInputReturn = r.into();
                        r.input_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `decodeProvedEvent(bytes)` and selector `0x26303962`.
```solidity
function decodeProvedEvent(bytes memory _data) external pure returns (IInbox.ProvedEventPayload memory payload_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProvedEventCall {
        #[allow(missing_docs)]
        pub _data: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`decodeProvedEvent(bytes)`](decodeProvedEventCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct decodeProvedEventReturn {
        #[allow(missing_docs)]
        pub payload_: <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProvedEventCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProvedEventCall) -> Self {
                    (value._data,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProvedEventCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _data: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProvedEventPayload,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<decodeProvedEventReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: decodeProvedEventReturn) -> Self {
                    (value.payload_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for decodeProvedEventReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { payload_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for decodeProvedEventCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Bytes,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IInbox::ProvedEventPayload,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "decodeProvedEvent(bytes)";
            const SELECTOR: [u8; 4] = [38u8, 48u8, 57u8, 98u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <IInbox::ProvedEventPayload as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: decodeProvedEventReturn = r.into();
                        r.payload_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: decodeProvedEventReturn = r.into();
                        r.payload_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `encodeProposeInput((uint48,(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))` and selector `0x261bf634`.
```solidity
function encodeProposeInput(IInbox.ProposeInput memory _input) external pure returns (bytes memory encoded_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProposeInputCall {
        #[allow(missing_docs)]
        pub _input: <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`encodeProposeInput((uint48,(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))`](encodeProposeInputCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProposeInputReturn {
        #[allow(missing_docs)]
        pub encoded_: alloy::sol_types::private::Bytes,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProposeInput,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProposeInputCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProposeInputCall) -> Self {
                    (value._input,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProposeInputCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _input: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProposeInputReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProposeInputReturn) -> Self {
                    (value.encoded_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProposeInputReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { encoded_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for encodeProposeInputCall {
            type Parameters<'a> = (IInbox::ProposeInput,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Bytes;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "encodeProposeInput((uint48,(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))";
            const SELECTOR: [u8; 4] = [38u8, 27u8, 246u8, 52u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::ProposeInput as alloy_sol_types::SolType>::tokenize(
                        &self._input,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: encodeProposeInputReturn = r.into();
                        r.encoded_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: encodeProposeInputReturn = r.into();
                        r.encoded_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint8,address,address)[]))` and selector `0x82d7058b`.
```solidity
function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload) external pure returns (bytes memory encoded_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProposedEventCall {
        #[allow(missing_docs)]
        pub _payload: <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint8,address,address)[]))`](encodeProposedEventCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProposedEventReturn {
        #[allow(missing_docs)]
        pub encoded_: alloy::sol_types::private::Bytes,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProposedEventPayload,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProposedEventCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProposedEventCall) -> Self {
                    (value._payload,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProposedEventCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _payload: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProposedEventReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProposedEventReturn) -> Self {
                    (value.encoded_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProposedEventReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { encoded_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for encodeProposedEventCall {
            type Parameters<'a> = (IInbox::ProposedEventPayload,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Bytes;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32),(uint48,uint8,address,address)[]))";
            const SELECTOR: [u8; 4] = [130u8, 215u8, 5u8, 139u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::ProposedEventPayload as alloy_sol_types::SolType>::tokenize(
                        &self._payload,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: encodeProposedEventReturn = r.into();
                        r.encoded_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: encodeProposedEventReturn = r.into();
                        r.encoded_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))` and selector `0xdc5a8bf8`.
```solidity
function encodeProveInput(IInbox.ProveInput memory _input) external pure returns (bytes memory encoded_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProveInputCall {
        #[allow(missing_docs)]
        pub _input: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))`](encodeProveInputCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProveInputReturn {
        #[allow(missing_docs)]
        pub encoded_: alloy::sol_types::private::Bytes,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProveInput,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProveInputCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProveInputCall) -> Self {
                    (value._input,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProveInputCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _input: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProveInputReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProveInputReturn) -> Self {
                    (value.encoded_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProveInputReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { encoded_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for encodeProveInputCall {
            type Parameters<'a> = (IInbox::ProveInput,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Bytes;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))";
            const SELECTOR: [u8; 4] = [220u8, 90u8, 139u8, 248u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::ProveInput as alloy_sol_types::SolType>::tokenize(
                        &self._input,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: encodeProveInputReturn = r.into();
                        r.encoded_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: encodeProveInputReturn = r.into();
                        r.encoded_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))` and selector `0x8f6d0e1a`.
```solidity
function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload) external pure returns (bytes memory encoded_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProvedEventCall {
        #[allow(missing_docs)]
        pub _payload: <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))`](encodeProvedEventCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeProvedEventReturn {
        #[allow(missing_docs)]
        pub encoded_: alloy::sol_types::private::Bytes,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::ProvedEventPayload,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProvedEventCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProvedEventCall) -> Self {
                    (value._payload,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProvedEventCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _payload: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Bytes,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<encodeProvedEventReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeProvedEventReturn) -> Self {
                    (value.encoded_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeProvedEventReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { encoded_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for encodeProvedEventCall {
            type Parameters<'a> = (IInbox::ProvedEventPayload,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Bytes;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))";
            const SELECTOR: [u8; 4] = [143u8, 109u8, 14u8, 26u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::ProvedEventPayload as alloy_sol_types::SolType>::tokenize(
                        &self._payload,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        ret,
                    ),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: encodeProvedEventReturn = r.into();
                        r.encoded_
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: encodeProvedEventReturn = r.into();
                        r.encoded_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashCheckpoint((uint48,bytes32,bytes32))` and selector `0x7989aa10`.
```solidity
function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCheckpointCall {
        #[allow(missing_docs)]
        pub _checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashCheckpoint((uint48,bytes32,bytes32))`](hashCheckpointCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCheckpointReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ICheckpointStore::Checkpoint,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashCheckpointCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashCheckpointCall) -> Self {
                    (value._checkpoint,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashCheckpointCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _checkpoint: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashCheckpointReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashCheckpointReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashCheckpointReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashCheckpointCall {
            type Parameters<'a> = (ICheckpointStore::Checkpoint,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashCheckpoint((uint48,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [121u8, 137u8, 170u8, 16u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::tokenize(
                        &self._checkpoint,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashCheckpointReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashCheckpointReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashCoreState((uint48,uint48,uint48,uint48,bytes32,bytes32))` and selector `0x1fe06ab4`.
```solidity
function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCoreStateCall {
        #[allow(missing_docs)]
        pub _coreState: <IInbox::CoreState as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashCoreState((uint48,uint48,uint48,uint48,bytes32,bytes32))`](hashCoreStateCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCoreStateReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::CoreState,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::CoreState as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashCoreStateCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashCoreStateCall) -> Self {
                    (value._coreState,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashCoreStateCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _coreState: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashCoreStateReturn> for UnderlyingRustTuple<'_> {
                fn from(value: hashCoreStateReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashCoreStateReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashCoreStateCall {
            type Parameters<'a> = (IInbox::CoreState,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashCoreState((uint48,uint48,uint48,uint48,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [31u8, 224u8, 106u8, 180u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::CoreState as alloy_sol_types::SolType>::tokenize(
                        &self._coreState,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashCoreStateReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashCoreStateReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))` and selector `0xb8b02e0e`.
```solidity
function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashDerivationCall {
        #[allow(missing_docs)]
        pub _derivation: <IInbox::Derivation as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))`](hashDerivationCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashDerivationReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::Derivation,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::Derivation as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashDerivationCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashDerivationCall) -> Self {
                    (value._derivation,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashDerivationCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _derivation: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashDerivationReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashDerivationReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashDerivationReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashDerivationCall {
            type Parameters<'a> = (IInbox::Derivation,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))";
            const SELECTOR: [u8; 4] = [184u8, 176u8, 46u8, 14u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::Derivation as alloy_sol_types::SolType>::tokenize(
                        &self._derivation,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashDerivationReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashDerivationReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashProposal((uint48,uint48,uint48,address,bytes32,bytes32))` and selector `0xa1ec9333`.
```solidity
function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashProposalCall {
        #[allow(missing_docs)]
        pub _proposal: <IInbox::Proposal as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashProposal((uint48,uint48,uint48,address,bytes32,bytes32))`](hashProposalCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashProposalReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::Proposal,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::Proposal as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashProposalCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashProposalCall) -> Self {
                    (value._proposal,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashProposalCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _proposal: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashProposalReturn> for UnderlyingRustTuple<'_> {
                fn from(value: hashProposalReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashProposalReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashProposalCall {
            type Parameters<'a> = (IInbox::Proposal,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashProposal((uint48,uint48,uint48,address,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [161u8, 236u8, 147u8, 51u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::Proposal as alloy_sol_types::SolType>::tokenize(
                        &self._proposal,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashProposalReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashProposalReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)))` and selector `0x1f397067`.
```solidity
function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionCall {
        #[allow(missing_docs)]
        pub _transition: <IInbox::Transition as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)))`](hashTransitionCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::Transition,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::Transition as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionCall) -> Self {
                    (value._transition,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashTransitionCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _transition: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashTransitionCall {
            type Parameters<'a> = (IInbox::Transition,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)))";
            const SELECTOR: [u8; 4] = [31u8, 57u8, 112u8, 103u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::Transition as alloy_sol_types::SolType>::tokenize(
                        &self._transition,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashTransitionReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashTransitionReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32))` and selector `0xeedec102`.
```solidity
function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord) external pure returns (bytes26);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionRecordCall {
        #[allow(missing_docs)]
        pub _transitionRecord: <IInbox::TransitionRecord as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32))`](hashTransitionRecordCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionRecordReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<26>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IInbox::TransitionRecord,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::TransitionRecord as alloy::sol_types::SolType>::RustType,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionRecordCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionRecordCall) -> Self {
                    (value._transitionRecord,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionRecordCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _transitionRecord: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<26>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionRecordReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionRecordReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionRecordReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashTransitionRecordCall {
            type Parameters<'a> = (IInbox::TransitionRecord,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<26>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [238u8, 222u8, 193u8, 2u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::TransitionRecord as alloy_sol_types::SolType>::tokenize(
                        &self._transitionRecord,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        26,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashTransitionRecordReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashTransitionRecordReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashTransitionsWithMetadata((bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[])` and selector `0x7a9a552a`.
```solidity
function hashTransitionsWithMetadata(IInbox.Transition[] memory _transitions, IInbox.TransitionMetadata[] memory _metadata) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionsWithMetadataCall {
        #[allow(missing_docs)]
        pub _transitions: alloy::sol_types::private::Vec<
            <IInbox::Transition as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub _metadata: alloy::sol_types::private::Vec<
            <IInbox::TransitionMetadata as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashTransitionsWithMetadata((bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[])`](hashTransitionsWithMetadataCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionsWithMetadataReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::FixedBytes<32>,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Array<IInbox::Transition>,
                alloy::sol_types::sol_data::Array<IInbox::TransitionMetadata>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Vec<
                    <IInbox::Transition as alloy::sol_types::SolType>::RustType,
                >,
                alloy::sol_types::private::Vec<
                    <IInbox::TransitionMetadata as alloy::sol_types::SolType>::RustType,
                >,
            );
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionsWithMetadataCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionsWithMetadataCall) -> Self {
                    (value._transitions, value._metadata)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionsWithMetadataCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _transitions: tuple.0,
                        _metadata: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::FixedBytes<32>,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<hashTransitionsWithMetadataReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionsWithMetadataReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionsWithMetadataReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashTransitionsWithMetadataCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Array<IInbox::Transition>,
                alloy::sol_types::sol_data::Array<IInbox::TransitionMetadata>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashTransitionsWithMetadata((bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[])";
            const SELECTOR: [u8; 4] = [122u8, 154u8, 85u8, 42u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Array<
                        IInbox::Transition,
                    > as alloy_sol_types::SolType>::tokenize(&self._transitions),
                    <alloy::sol_types::sol_data::Array<
                        IInbox::TransitionMetadata,
                    > as alloy_sol_types::SolType>::tokenize(&self._metadata),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: hashTransitionsWithMetadataReturn = r.into();
                        r._0
                    })
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(|r| {
                        let r: hashTransitionsWithMetadataReturn = r.into();
                        r._0
                    })
            }
        }
    };
    ///Container for all the [`CodecOptimized`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum CodecOptimizedCalls {
        #[allow(missing_docs)]
        decodeProposeInput(decodeProposeInputCall),
        #[allow(missing_docs)]
        decodeProposedEvent(decodeProposedEventCall),
        #[allow(missing_docs)]
        decodeProveInput(decodeProveInputCall),
        #[allow(missing_docs)]
        decodeProvedEvent(decodeProvedEventCall),
        #[allow(missing_docs)]
        encodeProposeInput(encodeProposeInputCall),
        #[allow(missing_docs)]
        encodeProposedEvent(encodeProposedEventCall),
        #[allow(missing_docs)]
        encodeProveInput(encodeProveInputCall),
        #[allow(missing_docs)]
        encodeProvedEvent(encodeProvedEventCall),
        #[allow(missing_docs)]
        hashCheckpoint(hashCheckpointCall),
        #[allow(missing_docs)]
        hashCoreState(hashCoreStateCall),
        #[allow(missing_docs)]
        hashDerivation(hashDerivationCall),
        #[allow(missing_docs)]
        hashProposal(hashProposalCall),
        #[allow(missing_docs)]
        hashTransition(hashTransitionCall),
        #[allow(missing_docs)]
        hashTransitionRecord(hashTransitionRecordCall),
        #[allow(missing_docs)]
        hashTransitionsWithMetadata(hashTransitionsWithMetadataCall),
    }
    #[automatically_derived]
    impl CodecOptimizedCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [31u8, 57u8, 112u8, 103u8],
            [31u8, 224u8, 106u8, 180u8],
            [38u8, 27u8, 246u8, 52u8],
            [38u8, 48u8, 57u8, 98u8],
            [93u8, 39u8, 204u8, 149u8],
            [121u8, 137u8, 170u8, 16u8],
            [122u8, 154u8, 85u8, 42u8],
            [130u8, 215u8, 5u8, 139u8],
            [143u8, 109u8, 14u8, 26u8],
            [161u8, 236u8, 147u8, 51u8],
            [175u8, 182u8, 58u8, 212u8],
            [184u8, 176u8, 46u8, 14u8],
            [220u8, 90u8, 139u8, 248u8],
            [237u8, 186u8, 205u8, 68u8],
            [238u8, 222u8, 193u8, 2u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecOptimizedCalls {
        const NAME: &'static str = "CodecOptimizedCalls";
        const MIN_DATA_LENGTH: usize = 32usize;
        const COUNT: usize = 15usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::decodeProposeInput(_) => {
                    <decodeProposeInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::decodeProposedEvent(_) => {
                    <decodeProposedEventCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::decodeProveInput(_) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::decodeProvedEvent(_) => {
                    <decodeProvedEventCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProposeInput(_) => {
                    <encodeProposeInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProposedEvent(_) => {
                    <encodeProposedEventCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProveInput(_) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProvedEvent(_) => {
                    <encodeProvedEventCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashCheckpoint(_) => {
                    <hashCheckpointCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashCoreState(_) => {
                    <hashCoreStateCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashDerivation(_) => {
                    <hashDerivationCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashProposal(_) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashTransition(_) => {
                    <hashTransitionCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashTransitionRecord(_) => {
                    <hashTransitionRecordCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashTransitionsWithMetadata(_) => {
                    <hashTransitionsWithMetadataCall as alloy_sol_types::SolCall>::SELECTOR
                }
            }
        }
        #[inline]
        fn selector_at(i: usize) -> ::core::option::Option<[u8; 4]> {
            Self::SELECTORS.get(i).copied()
        }
        #[inline]
        fn valid_selector(selector: [u8; 4]) -> bool {
            Self::SELECTORS.binary_search(&selector).is_ok()
        }
        #[inline]
        #[allow(non_snake_case)]
        fn abi_decode_raw(
            selector: [u8; 4],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            static DECODE_SHIMS: &[fn(
                &[u8],
            ) -> alloy_sol_types::Result<CodecOptimizedCalls>] = &[
                {
                    fn hashTransition(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransition)
                    }
                    hashTransition
                },
                {
                    fn hashCoreState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashCoreStateCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashCoreState)
                    }
                    hashCoreState
                },
                {
                    fn encodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProposeInput)
                    }
                    encodeProposeInput
                },
                {
                    fn decodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProvedEvent)
                    }
                    decodeProvedEvent
                },
                {
                    fn decodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProposedEvent)
                    }
                    decodeProposedEvent
                },
                {
                    fn hashCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashCheckpoint)
                    }
                    hashCheckpoint
                },
                {
                    fn hashTransitionsWithMetadata(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionsWithMetadataCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitionsWithMetadata)
                    }
                    hashTransitionsWithMetadata
                },
                {
                    fn encodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProposedEvent)
                    }
                    encodeProposedEvent
                },
                {
                    fn encodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProvedEvent)
                    }
                    encodeProvedEvent
                },
                {
                    fn hashProposal(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashProposal)
                    }
                    hashProposal
                },
                {
                    fn decodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProposeInput)
                    }
                    decodeProposeInput
                },
                {
                    fn hashDerivation(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashDerivationCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashDerivation)
                    }
                    hashDerivation
                },
                {
                    fn encodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProveInput)
                    }
                    encodeProveInput
                },
                {
                    fn decodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProveInput)
                    }
                    decodeProveInput
                },
                {
                    fn hashTransitionRecord(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionRecordCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitionRecord)
                    }
                    hashTransitionRecord
                },
            ];
            let Ok(idx) = Self::SELECTORS.binary_search(&selector) else {
                return Err(
                    alloy_sol_types::Error::unknown_selector(
                        <Self as alloy_sol_types::SolInterface>::NAME,
                        selector,
                    ),
                );
            };
            DECODE_SHIMS[idx](data)
        }
        #[inline]
        #[allow(non_snake_case)]
        fn abi_decode_raw_validate(
            selector: [u8; 4],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            static DECODE_VALIDATE_SHIMS: &[fn(
                &[u8],
            ) -> alloy_sol_types::Result<CodecOptimizedCalls>] = &[
                {
                    fn hashTransition(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransition)
                    }
                    hashTransition
                },
                {
                    fn hashCoreState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashCoreStateCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashCoreState)
                    }
                    hashCoreState
                },
                {
                    fn encodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProposeInput)
                    }
                    encodeProposeInput
                },
                {
                    fn decodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProvedEvent)
                    }
                    decodeProvedEvent
                },
                {
                    fn decodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProposedEvent)
                    }
                    decodeProposedEvent
                },
                {
                    fn hashCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashCheckpoint)
                    }
                    hashCheckpoint
                },
                {
                    fn hashTransitionsWithMetadata(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionsWithMetadataCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitionsWithMetadata)
                    }
                    hashTransitionsWithMetadata
                },
                {
                    fn encodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProposedEvent)
                    }
                    encodeProposedEvent
                },
                {
                    fn encodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProvedEvent)
                    }
                    encodeProvedEvent
                },
                {
                    fn hashProposal(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashProposal)
                    }
                    hashProposal
                },
                {
                    fn decodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProposeInput)
                    }
                    decodeProposeInput
                },
                {
                    fn hashDerivation(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashDerivationCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashDerivation)
                    }
                    hashDerivation
                },
                {
                    fn encodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <encodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::encodeProveInput)
                    }
                    encodeProveInput
                },
                {
                    fn decodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <decodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::decodeProveInput)
                    }
                    decodeProveInput
                },
                {
                    fn hashTransitionRecord(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionRecordCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitionRecord)
                    }
                    hashTransitionRecord
                },
            ];
            let Ok(idx) = Self::SELECTORS.binary_search(&selector) else {
                return Err(
                    alloy_sol_types::Error::unknown_selector(
                        <Self as alloy_sol_types::SolInterface>::NAME,
                        selector,
                    ),
                );
            };
            DECODE_VALIDATE_SHIMS[idx](data)
        }
        #[inline]
        fn abi_encoded_size(&self) -> usize {
            match self {
                Self::decodeProposeInput(inner) => {
                    <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::decodeProposedEvent(inner) => {
                    <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::decodeProveInput(inner) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::decodeProvedEvent(inner) => {
                    <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProposeInput(inner) => {
                    <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProposedEvent(inner) => {
                    <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProveInput(inner) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProvedEvent(inner) => {
                    <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashCheckpoint(inner) => {
                    <hashCheckpointCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashCoreState(inner) => {
                    <hashCoreStateCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashDerivation(inner) => {
                    <hashDerivationCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashProposal(inner) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashTransition(inner) => {
                    <hashTransitionCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashTransitionRecord(inner) => {
                    <hashTransitionRecordCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashTransitionsWithMetadata(inner) => {
                    <hashTransitionsWithMetadataCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::decodeProposeInput(inner) => {
                    <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::decodeProposedEvent(inner) => {
                    <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::decodeProveInput(inner) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::decodeProvedEvent(inner) => {
                    <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::encodeProposeInput(inner) => {
                    <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::encodeProposedEvent(inner) => {
                    <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::encodeProveInput(inner) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::encodeProvedEvent(inner) => {
                    <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashCheckpoint(inner) => {
                    <hashCheckpointCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashCoreState(inner) => {
                    <hashCoreStateCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashDerivation(inner) => {
                    <hashDerivationCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashProposal(inner) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashTransition(inner) => {
                    <hashTransitionCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashTransitionRecord(inner) => {
                    <hashTransitionRecordCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::hashTransitionsWithMetadata(inner) => {
                    <hashTransitionsWithMetadataCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`CodecOptimized`](self) custom errors.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum CodecOptimizedErrors {
        #[allow(missing_docs)]
        InconsistentLengths(InconsistentLengths),
        #[allow(missing_docs)]
        InvalidBondType(InvalidBondType),
        #[allow(missing_docs)]
        LengthExceedsUint16(LengthExceedsUint16),
        #[allow(missing_docs)]
        MetadataLengthMismatch(MetadataLengthMismatch),
        #[allow(missing_docs)]
        ProposalTransitionLengthMismatch(ProposalTransitionLengthMismatch),
    }
    #[automatically_derived]
    impl CodecOptimizedErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [44u8, 60u8, 244u8, 214u8],
            [62u8, 94u8, 100u8, 196u8],
            [92u8, 22u8, 125u8, 126u8],
            [177u8, 244u8, 15u8, 119u8],
            [246u8, 178u8, 9u8, 168u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecOptimizedErrors {
        const NAME: &'static str = "CodecOptimizedErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 5usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::InconsistentLengths(_) => {
                    <InconsistentLengths as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidBondType(_) => {
                    <InvalidBondType as alloy_sol_types::SolError>::SELECTOR
                }
                Self::LengthExceedsUint16(_) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::SELECTOR
                }
                Self::MetadataLengthMismatch(_) => {
                    <MetadataLengthMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ProposalTransitionLengthMismatch(_) => {
                    <ProposalTransitionLengthMismatch as alloy_sol_types::SolError>::SELECTOR
                }
            }
        }
        #[inline]
        fn selector_at(i: usize) -> ::core::option::Option<[u8; 4]> {
            Self::SELECTORS.get(i).copied()
        }
        #[inline]
        fn valid_selector(selector: [u8; 4]) -> bool {
            Self::SELECTORS.binary_search(&selector).is_ok()
        }
        #[inline]
        #[allow(non_snake_case)]
        fn abi_decode_raw(
            selector: [u8; 4],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            static DECODE_SHIMS: &[fn(
                &[u8],
            ) -> alloy_sol_types::Result<CodecOptimizedErrors>] = &[
                {
                    fn LengthExceedsUint16(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedErrors::LengthExceedsUint16)
                    }
                    LengthExceedsUint16
                },
                {
                    fn MetadataLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <MetadataLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedErrors::MetadataLengthMismatch)
                    }
                    MetadataLengthMismatch
                },
                {
                    fn ProposalTransitionLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <ProposalTransitionLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedErrors::ProposalTransitionLengthMismatch)
                    }
                    ProposalTransitionLengthMismatch
                },
                {
                    fn InconsistentLengths(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <InconsistentLengths as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedErrors::InconsistentLengths)
                    }
                    InconsistentLengths
                },
                {
                    fn InvalidBondType(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <InvalidBondType as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedErrors::InvalidBondType)
                    }
                    InvalidBondType
                },
            ];
            let Ok(idx) = Self::SELECTORS.binary_search(&selector) else {
                return Err(
                    alloy_sol_types::Error::unknown_selector(
                        <Self as alloy_sol_types::SolInterface>::NAME,
                        selector,
                    ),
                );
            };
            DECODE_SHIMS[idx](data)
        }
        #[inline]
        #[allow(non_snake_case)]
        fn abi_decode_raw_validate(
            selector: [u8; 4],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            static DECODE_VALIDATE_SHIMS: &[fn(
                &[u8],
            ) -> alloy_sol_types::Result<CodecOptimizedErrors>] = &[
                {
                    fn LengthExceedsUint16(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedErrors::LengthExceedsUint16)
                    }
                    LengthExceedsUint16
                },
                {
                    fn MetadataLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <MetadataLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedErrors::MetadataLengthMismatch)
                    }
                    MetadataLengthMismatch
                },
                {
                    fn ProposalTransitionLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <ProposalTransitionLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedErrors::ProposalTransitionLengthMismatch)
                    }
                    ProposalTransitionLengthMismatch
                },
                {
                    fn InconsistentLengths(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <InconsistentLengths as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedErrors::InconsistentLengths)
                    }
                    InconsistentLengths
                },
                {
                    fn InvalidBondType(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedErrors> {
                        <InvalidBondType as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedErrors::InvalidBondType)
                    }
                    InvalidBondType
                },
            ];
            let Ok(idx) = Self::SELECTORS.binary_search(&selector) else {
                return Err(
                    alloy_sol_types::Error::unknown_selector(
                        <Self as alloy_sol_types::SolInterface>::NAME,
                        selector,
                    ),
                );
            };
            DECODE_VALIDATE_SHIMS[idx](data)
        }
        #[inline]
        fn abi_encoded_size(&self) -> usize {
            match self {
                Self::InconsistentLengths(inner) => {
                    <InconsistentLengths as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidBondType(inner) => {
                    <InvalidBondType as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::LengthExceedsUint16(inner) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::MetadataLengthMismatch(inner) => {
                    <MetadataLengthMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ProposalTransitionLengthMismatch(inner) => {
                    <ProposalTransitionLengthMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::InconsistentLengths(inner) => {
                    <InconsistentLengths as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidBondType(inner) => {
                    <InvalidBondType as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::LengthExceedsUint16(inner) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::MetadataLengthMismatch(inner) => {
                    <MetadataLengthMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ProposalTransitionLengthMismatch(inner) => {
                    <ProposalTransitionLengthMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`CodecOptimized`](self) contract instance.

See the [wrapper's documentation](`CodecOptimizedInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> CodecOptimizedInstance<P, N> {
        CodecOptimizedInstance::<P, N>::new(address, provider)
    }
    /**Deploys this contract using the given `provider` and constructor arguments, if any.

Returns a new instance of the contract, if the deployment was successful.

For more fine-grained control over the deployment process, use [`deploy_builder`] instead.*/
    #[inline]
    pub fn deploy<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        provider: P,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<CodecOptimizedInstance<P, N>>,
    > {
        CodecOptimizedInstance::<P, N>::deploy(provider)
    }
    /**Creates a `RawCallBuilder` for deploying this contract using the given `provider`
and constructor arguments, if any.

This is a simple wrapper around creating a `RawCallBuilder` with the data set to
the bytecode concatenated with the constructor's ABI-encoded arguments.*/
    #[inline]
    pub fn deploy_builder<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(provider: P) -> alloy_contract::RawCallBuilder<P, N> {
        CodecOptimizedInstance::<P, N>::deploy_builder(provider)
    }
    /**A [`CodecOptimized`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`CodecOptimized`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct CodecOptimizedInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for CodecOptimizedInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("CodecOptimizedInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > CodecOptimizedInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`CodecOptimized`](self) contract instance.

See the [wrapper's documentation](`CodecOptimizedInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            provider: P,
        ) -> Self {
            Self {
                address,
                provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /**Deploys this contract using the given `provider` and constructor arguments, if any.

Returns a new instance of the contract, if the deployment was successful.

For more fine-grained control over the deployment process, use [`deploy_builder`] instead.*/
        #[inline]
        pub async fn deploy(
            provider: P,
        ) -> alloy_contract::Result<CodecOptimizedInstance<P, N>> {
            let call_builder = Self::deploy_builder(provider);
            let contract_address = call_builder.deploy().await?;
            Ok(Self::new(contract_address, call_builder.provider))
        }
        /**Creates a `RawCallBuilder` for deploying this contract using the given `provider`
and constructor arguments, if any.

This is a simple wrapper around creating a `RawCallBuilder` with the data set to
the bytecode concatenated with the constructor's ABI-encoded arguments.*/
        #[inline]
        pub fn deploy_builder(provider: P) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                provider,
                ::core::clone::Clone::clone(&BYTECODE),
            )
        }
        /// Returns a reference to the address.
        #[inline]
        pub const fn address(&self) -> &alloy_sol_types::private::Address {
            &self.address
        }
        /// Sets the address.
        #[inline]
        pub fn set_address(&mut self, address: alloy_sol_types::private::Address) {
            self.address = address;
        }
        /// Sets the address and returns `self`.
        pub fn at(mut self, address: alloy_sol_types::private::Address) -> Self {
            self.set_address(address);
            self
        }
        /// Returns a reference to the provider.
        #[inline]
        pub const fn provider(&self) -> &P {
            &self.provider
        }
    }
    impl<P: ::core::clone::Clone, N> CodecOptimizedInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> CodecOptimizedInstance<P, N> {
            CodecOptimizedInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > CodecOptimizedInstance<P, N> {
        /// Creates a new call builder using this contract instance's provider and address.
        ///
        /// Note that the call can be any function call, not just those defined in this
        /// contract. Prefer using the other methods for building type-safe contract calls.
        pub fn call_builder<C: alloy_sol_types::SolCall>(
            &self,
            call: &C,
        ) -> alloy_contract::SolCallBuilder<&P, C, N> {
            alloy_contract::SolCallBuilder::new_sol(&self.provider, &self.address, call)
        }
        ///Creates a new call builder for the [`decodeProposeInput`] function.
        pub fn decodeProposeInput(
            &self,
            _data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, decodeProposeInputCall, N> {
            self.call_builder(&decodeProposeInputCall { _data })
        }
        ///Creates a new call builder for the [`decodeProposedEvent`] function.
        pub fn decodeProposedEvent(
            &self,
            _data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, decodeProposedEventCall, N> {
            self.call_builder(&decodeProposedEventCall { _data })
        }
        ///Creates a new call builder for the [`decodeProveInput`] function.
        pub fn decodeProveInput(
            &self,
            _data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, decodeProveInputCall, N> {
            self.call_builder(&decodeProveInputCall { _data })
        }
        ///Creates a new call builder for the [`decodeProvedEvent`] function.
        pub fn decodeProvedEvent(
            &self,
            _data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, decodeProvedEventCall, N> {
            self.call_builder(&decodeProvedEventCall { _data })
        }
        ///Creates a new call builder for the [`encodeProposeInput`] function.
        pub fn encodeProposeInput(
            &self,
            _input: <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProposeInputCall, N> {
            self.call_builder(&encodeProposeInputCall { _input })
        }
        ///Creates a new call builder for the [`encodeProposedEvent`] function.
        pub fn encodeProposedEvent(
            &self,
            _payload: <IInbox::ProposedEventPayload as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProposedEventCall, N> {
            self.call_builder(
                &encodeProposedEventCall {
                    _payload,
                },
            )
        }
        ///Creates a new call builder for the [`encodeProveInput`] function.
        pub fn encodeProveInput(
            &self,
            _input: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProveInputCall, N> {
            self.call_builder(&encodeProveInputCall { _input })
        }
        ///Creates a new call builder for the [`encodeProvedEvent`] function.
        pub fn encodeProvedEvent(
            &self,
            _payload: <IInbox::ProvedEventPayload as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProvedEventCall, N> {
            self.call_builder(&encodeProvedEventCall { _payload })
        }
        ///Creates a new call builder for the [`hashCheckpoint`] function.
        pub fn hashCheckpoint(
            &self,
            _checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashCheckpointCall, N> {
            self.call_builder(&hashCheckpointCall { _checkpoint })
        }
        ///Creates a new call builder for the [`hashCoreState`] function.
        pub fn hashCoreState(
            &self,
            _coreState: <IInbox::CoreState as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashCoreStateCall, N> {
            self.call_builder(&hashCoreStateCall { _coreState })
        }
        ///Creates a new call builder for the [`hashDerivation`] function.
        pub fn hashDerivation(
            &self,
            _derivation: <IInbox::Derivation as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashDerivationCall, N> {
            self.call_builder(&hashDerivationCall { _derivation })
        }
        ///Creates a new call builder for the [`hashProposal`] function.
        pub fn hashProposal(
            &self,
            _proposal: <IInbox::Proposal as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashProposalCall, N> {
            self.call_builder(&hashProposalCall { _proposal })
        }
        ///Creates a new call builder for the [`hashTransition`] function.
        pub fn hashTransition(
            &self,
            _transition: <IInbox::Transition as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashTransitionCall, N> {
            self.call_builder(&hashTransitionCall { _transition })
        }
        ///Creates a new call builder for the [`hashTransitionRecord`] function.
        pub fn hashTransitionRecord(
            &self,
            _transitionRecord: <IInbox::TransitionRecord as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashTransitionRecordCall, N> {
            self.call_builder(
                &hashTransitionRecordCall {
                    _transitionRecord,
                },
            )
        }
        ///Creates a new call builder for the [`hashTransitionsWithMetadata`] function.
        pub fn hashTransitionsWithMetadata(
            &self,
            _transitions: alloy::sol_types::private::Vec<
                <IInbox::Transition as alloy::sol_types::SolType>::RustType,
            >,
            _metadata: alloy::sol_types::private::Vec<
                <IInbox::TransitionMetadata as alloy::sol_types::SolType>::RustType,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, hashTransitionsWithMetadataCall, N> {
            self.call_builder(
                &hashTransitionsWithMetadataCall {
                    _transitions,
                    _metadata,
                },
            )
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > CodecOptimizedInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
    }
}
