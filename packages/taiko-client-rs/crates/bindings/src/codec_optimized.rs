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
    struct ProposedEventPayload { Proposal proposal; Derivation derivation; CoreState coreState; }
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct ProposedEventPayload { Proposal proposal; Derivation derivation; CoreState coreState; }
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
        type UnderlyingSolTuple<'a> = (Proposal, Derivation, CoreState);
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            <Proposal as alloy::sol_types::SolType>::RustType,
            <Derivation as alloy::sol_types::SolType>::RustType,
            <CoreState as alloy::sol_types::SolType>::RustType,
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
                (value.proposal, value.derivation, value.coreState)
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
                    "ProposedEventPayload(Proposal proposal,Derivation derivation,CoreState coreState)",
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
    ///0x6080604052348015600e575f5ffd5b50613c6b8061001c5f395ff3fe608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c80638f6d0e1a11610093578063d771d39811610063578063d771d3981461020c578063dc5a8bf81461021f578063edbacd4414610232578063eedec10214610252575f5ffd5b80638f6d0e1a146101b3578063a1ec9333146101c6578063afb63ad4146101d9578063b8b02e0e146101f9575f5ffd5b806326303962116100ce578063263039621461014d5780635d27cc951461016d5780637989aa101461018d5780637a9a552a146101a0575f5ffd5b80631f397067146100f45780631fe06ab41461011a578063261bf6341461012d575b5f5ffd5b610107610102366004612855565b61027d565b6040519081526020015b60405180910390f35b61010761012836600461287e565b61029b565b61014061013b366004612898565b6102b3565b60405161011191906128cf565b61016061015b366004612904565b6102c6565b6040516101119190612a4d565b61018061017b366004612904565b610313565b6040516101119190612ba3565b61010761019b366004612ce9565b610359565b6101076101ae366004612d4a565b610371565b6101406101c1366004612de2565b610427565b6101076101d436600461287e565b61043a565b6101ec6101e7366004612904565b610452565b6040516101119190612eb8565b610107610207366004612f9b565b610498565b61014061021a366004612fcc565b6104aa565b61014061022d366004613003565b6104bd565b610245610240366004612904565b6104d0565b6040516101119190613034565b610265610260366004612f9b565b610532565b60405165ffffffffffff199091168152602001610111565b5f610295610290368490038401846132c4565b610544565b92915050565b5f6102956102ae36849003840184613352565b610578565b60606102956102c18361367b565b6105d3565b6102ce612633565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061080692505050565b9392505050565b61031b6126a7565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610ab892505050565b5f61029561036c36849003840184613744565b610dea565b5f61041e8585808060200260200160405190810160405280939291908181526020015f905b828210156103c2576103b360a083028601368190038101906132c4565b81526020019060010190610396565b50505050508484808060200260200160405190810160405280939291908181526020015f905b82821015610414576104056040830286013681900381019061379a565b815260200190600101906103e8565b5050505050610e1b565b95945050505050565b6060610295610435836137b4565b610fd2565b5f61029561044d3684900384018461382c565b6111e9565b61045a612716565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061126092505050565b5f6102956104a583613a33565b6114ba565b60606102956104b883613a3e565b61162a565b60606102956104cb83613aff565b6118ec565b6104f460405180606001604052806060815260200160608152602001606081525090565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611a5192505050565b5f61029561053f83613bf6565b611cc0565b5f610295825f0151836020015161055e8560400151610dea565b604080519384526020840192909252908201526060902090565b805160208083015160408085015160608087015160808089015160a0808b0151875165ffffffffffff9b8c168152988b169989019990995294891695870195909552961690840152938201529182015260c090205f90610295565b60605f6105ed836040015184608001518560a00151611e11565b9050806001600160401b0381111561060757610607613135565b6040519080825280601f01601f191660200182016040528015610631576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c840152805160409081015190921b603284015280516080015160388401525160a00151605883015284015151909250607883019061069690611e9c565b60408401515160f01b81526002015f5b8460400151518110156106e4576106da82866040015183815181106106cd576106cd613c01565b6020026020010151611ec2565b91506001016106a6565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b600482015260808401515160079091019061072290611e9c565b60808401515160f01b81526002015f5b84608001515181101561077057610766828660800151838151811061075957610759613c01565b6020026020010151611f14565b9150600101610732565b5060a0840151515f9065ffffffffffff16158015610794575060a085015160200151155b80156107a6575060a085015160400151155b90506107bf82826107b8576001611f9c565b5f5b611f9c565b9150806107ee5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b6107fc828660c00151611f9c565b9150505050919050565b61080e612633565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156108d5576108d5613135565b60405190808252806020026020018201604052801561092557816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816108f35790505b506040840151602001525f5b8161ffff16811015610ab057825160d01c60068401856040015160200151838151811061096057610960613c01565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109a757604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109bc576109bc612970565b85604001516020015183815181106109d6576109d6613c01565b60200260200101516020019060028111156109f3576109f3612970565b90816002811115610a0657610a06612970565b905250835160601c601485018660400151602001518481518110610a2c57610a2c613c01565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610a6484805160601c91601490910190565b8660400151602001518481518110610a7e57610a7e613c01565b6020026020010151606001819650826001600160a01b03166001600160a01b0316815250505050806001019050610931565b505050919050565b610ac06126a7565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610b4e57610b4e613135565b604051908082528060200260200182016040528015610bb157816020015b610b9e6040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610b6c5790505b506020840151606001525f5b8161ffff16811015610d7f578251602085015160600151805160019095019460f89290921c91821515919084908110610bf857610bf8613c01565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610c2b57610c2b613135565b604051908082528060200260200182016040528015610c54578160200160208202803683370190505b508660200151606001518481518110610c6f57610c6f613c01565b6020908102919091018101510151525f5b8161ffff16811015610ce4578551602087018860200151606001518681518110610cac57610cac613c01565b6020026020010151602001515f01518381518110610ccc57610ccc613c01565b60209081029190910101919091529550600101610c80565b50845160e81c600386018760200151606001518581518110610d0857610d08613c01565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610d4a57610d4a613c01565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610bbd565b505080518251608090810191909152602080830151845160a090810191909152604080850151818701805160d092831c90526046870151815190831c950194909452604c8601518451911c910152605284015182519093019290925260729092015191510152919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610295565b5f8151835114610e3e5760405163b1f40f7760e01b815260040160405180910390fd5b82515f819003610e5e575f516020613c165f395f51905f52915050610295565b80600103610ec1575f610ea3855f81518110610e7c57610e7c613c01565b6020026020010151855f81518110610e9657610e96613c01565b6020026020010151611fa8565b9050610eb882825f9182526020526040902090565b92505050610295565b80600203610f35575f610edf855f81518110610e7c57610e7c613c01565b90505f610f1386600181518110610ef857610ef8613c01565b602002602001015186600181518110610e9657610e96613c01565b6040805194855260208501939093529183019190915250606090209050610295565b604080516001830181526002830160051b8101909152602081018290525f5b82811015610fab57610fa28282600101610f93898581518110610f7957610f79613c01565b6020026020010151898681518110610e9657610e96613c01565b60019190910160051b82015290565b50600101610f54565b50805160051b602082012061041e8280516040516001820160051b83011490151060061b52565b60408101516020015151606090602f0260f701806001600160401b03811115610ffd57610ffd613135565b6040519080825280601f01601f191660200182016040528015611027576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061108f908290611f9c565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b605484015251015151606890910191506110db90611e9c565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610ab05761113482866040015160200151838151811061111e5761111e613c01565b60200260200101515f015160d01b815260060190565b915061117182866040015160200151838151811061115457611154613c01565b60200260200101516020015160028111156107ba576107ba612970565b91506111a882866040015160200151838151811061119157611191613c01565b60200260200101516040015160601b815260140190565b91506111df8286604001516020015183815181106111c8576111c8613c01565b60200260200101516060015160601b815260140190565b91506001016110ef565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b905061030c8184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b611268612716565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c93019290925260328401518251911c60409091015260388301518151608001526058830151905160a001526078820151607a83019060f01c806001600160401b038111156112df576112df613135565b60405190808252806020026020018201604052801561131857816020015b6113056127e1565b8152602001906001900390816112fd5790505b5060408401525f5b8161ffff168110156113635761133583611ffb565b8560400151838151811061134b5761134b613c01565b60209081029190910101919091529250600101611320565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156113bc576113bc613135565b60405190808252806020026020018201604052801561141857816020015b61140560405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816113da5790505b5060808501525f5b8161ffff168110156114635761143584612058565b8660800151838151811061144b5761144b613c01565b60209081029190910101919091529350600101611420565b50825160019384019360f89190911c908190036114a857835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f03611503575f516020613c165f395f51905f529150611609565b8060010361154c57611545815f1b61153787606001515f8151811061152a5761152a613c01565b6020026020010151612169565b5f9182526020526040902090565b9150611609565b8060020361158d57611545815f1b61157387606001515f8151811061152a5761152a613c01565b61055e886060015160018151811061152a5761152a613c01565b604080516001830181526002830160051b8101909152602081018290525f5b828110156115de576115d58282600101610f938a60600151858151811061152a5761152a613c01565b506001016115ac565b50805160051b602082012092506116078180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f61163e8360200151606001516121e1565b9050806001600160401b0381111561165857611658613135565b6040519080825280601f01601f191660200182016040528015611682576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c8301906116ed908290611f9c565b6020850151606001515190915061170381611e9c565b611713828260f01b815260020190565b91505f5b818110156118855761175983876020015160600151838151811061173d5761173d613c01565b60200260200101515f0151611752575f611f9c565b6001611f9c565b92505f866020015160600151828151811061177657611776613c01565b6020026020010151602001515f015151905061179181611e9c565b6117a1848260f01b815260020190565b93505f5b81811015611805576117fb8589602001516060015185815181106117cb576117cb613c01565b6020026020010151602001515f015183815181106117eb576117eb613c01565b6020026020010151815260200190565b94506001016117a5565b5061183f84886020015160600151848151811061182457611824613c01565b6020026020010151602001516020015160e81b815260030190565b935061187a84886020015160600151848151811061185f5761185f613c01565b6020026020010151602001516040015160d01b815260060190565b935050600101611717565b5084516080908101518352855160a090810151602080860191909152604080890180515160d090811b83890152815190930151831b604688015280519091015190911b604c86015280519092015160528501529051015160728301908152916092016107fc565b60605f611905835f01518460200151856040015161222b565b9050806001600160401b0381111561191f5761191f613135565b6040519080825280601f01601f191660200182016040528015611949576020820181803683370190505b50835151909250602083019061195e90611e9c565b83515160f01b81526002015f5b8451518110156119a55761199b82865f0151838151811061198e5761198e613c01565b6020026020010151612280565b915060010161196b565b506119b4846020015151611e9c565b60208401515160f01b81526002015f5b846020015151811015611a02576119f882866020015183815181106119eb576119eb613c01565b60200260200101516122ba565b91506001016119c4565b50611a11846040015151611e9c565b5f5b846040015151811015610ab057611a478286604001518381518110611a3a57611a3a613c01565b60200260200101516122f6565b9150600101611a13565b611a7560405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611a9a57611a9a613135565b604051908082528060200260200182016040528015611ad357816020015b611ac06127e1565b815260200190600190039081611ab85790505b5083525f5b8161ffff16811015611b1957611aed83612317565b8551805184908110611b0157611b01613c01565b60209081029190910101919091529250600101611ad8565b50815160029092019160f01c61ffff82168114611b4957604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611b6557611b65613135565b604051908082528060200260200182016040528015611b9e57816020015b611b8b612815565b815260200190600190039081611b835790505b5060208501525f5b8161ffff16811015611be957611bbb8461235f565b86602001518381518110611bd157611bd1613c01565b60209081029190910101919091529350600101611ba6565b508061ffff166001600160401b03811115611c0657611c06613135565b604051908082528060200260200182016040528015611c4a57816020015b604080518082019091525f8082526020820152815260200190600190039081611c245790505b5060408501525f5b8161ffff16811015611cb757604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611c9f57611c9f613c01565b60209081029190910101919091529350600101611c52565b50505050919050565b6020810151515f908190808203611ce6575f516020613c165f395f51905f529150611dde565b80600103611d2157611d1a815f1b61153786602001515f81518110611d0d57611d0d613c01565b60200260200101516123a9565b9150611dde565b80600203611d6257611d1a815f1b611d4886602001515f81518110611d0d57611d0d613c01565b61055e8760200151600181518110611d0d57611d0d613c01565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611db357611daa8282600101610f9389602001518581518110611d0d57611d0d613c01565b50600101611d81565b50805160051b60208201209250611ddc8180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f9061041e565b80516065905f9065ffffffffffff16158015611e2f57506020830151155b8015611e3d57506040830151155b905080611e4b576046820191505b8451606602820191505f5b8451811015611e9357848181518110611e7157611e71613c01565b60200260200101516020015151602f0260430183019250806001019050611e56565b50509392505050565b61ffff811115611ebf5760405163161e7a6b60e11b815260040160405180910390fd5b50565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a083015160208201908152915060400161030c565b5f611f2283835f0151611f9c565b9050611f32826020015151611e9c565b60208201515160f01b81526002015f5b826020015151811015611f8057611f768284602001518381518110611f6957611f69613c01565b6020026020010151612415565b9150600101611f42565b506040828101518252606083015160208301908152910161030c565b5f818353505060010190565b5f61030c835f01518460200151611fc28660400151610dea565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b6120036127e1565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b61208360405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156120af576120af613135565b6040519080825280602002602001820160405280156120ff57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816120cd5790505b5060208401525f5b8161ffff1681101561214a5761211c83612460565b8560200151838151811061213257612132613c01565b60209081029190910101919091529250600101612107565b5050805160408381019190915260208201516060840152919391019150565b5f5f61217b83602001515f01516124f8565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff90921690820152606090209091506121d9845f01516121c4575f6121c7565b60015b60ff16825f9182526020526040902090565b949350505050565b60e15f5b82518110156122255782818151811061220057612200613c01565b6020026020010151602001515f015151602002600c01820191508060010190506121e5565b50919050565b5f825184511461224e57604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461227057604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b90830190815260268301611ef7565b8051825260208082015181840152604080830180515160d01b82860152805190920151604685015290510151606683019081526086830161030c565b805160601b82525f60148301602083015160601b815290506014810161030c565b61231f6127e1565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c60408201526026820180516046840161203d565b612367612815565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610295825f015165ffffffffffff165f1b836020015160028111156123d1576123d1612970565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f60068301905061243d81836020015160028111156107ba576107ba612970565b6040830151606090811b825280840151901b60148201908152915060280161030c565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c8060028111156124a9576124a9612970565b836020019060028111156124bf576124bf612970565b908160028111156124d2576124d2612970565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f9080820361251857505f516020613c165f395f51905f5292915050565b8060010361254e5761030c815f1b845f8151811061253857612538613c01565b60200260200101515f9182526020526040902090565b806002036125ab5761030c815f1b845f8151811061256e5761256e613c01565b60200260200101518560018151811061258957612589613c01565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b8281101561260c5761260382826001018784815181106125ec576125ec613c01565b602002602001015160019190910160051b82015290565b506001016125ca565b50805160051b60208201206121d98280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff168152602001612654612815565b815260200161268460405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b81526020016126a2604080518082019091525f808252602082015290565b905290565b60405180606001604052806126ba6127e1565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160c0810182525f8082526020828101829052928201819052606082018190526080820181905260a082015291015290565b6040518060e001604052805f65ffffffffffff1681526020016127666040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b8152602001606081526020016127a060405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b8152602001606081526020016127d560405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f81526020016126a260405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60a0828403128015612866575f5ffd5b509092915050565b5f60c08284031215612225575f5ffd5b5f60c0828403121561288e575f5ffd5b61030c838361286e565b5f602082840312156128a8575f5ffd5b81356001600160401b038111156128bd575f5ffd5b8201610200818503121561030c575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f5f60208385031215612915575f5ffd5b82356001600160401b0381111561292a575f5ffd5b8301601f8101851361293a575f5ffd5b80356001600160401b0381111561294f575f5ffd5b856020828401011115612960575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f6080830160ff835116845260208301516080602086015281815180845260a0870191506020830193505f92505b80831015612a2c57835165ffffffffffff81511683526020810151600381106129e957634e487b7160e01b5f52602160045260245ffd5b8060208501525060018060a01b03604082015116604084015260018060a01b036060820151166060840152506080820191506020840193506001830192506129b2565b50604085015160408701526060850151606087015280935050505092915050565b6020815265ffffffffffff82511660208201525f6020830151612aa360408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612abf610140840182612984565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015265ffffffffffff60608201511660608301526080810151608083015260a081015160a08301525050565b60208152612bb5602082018351612aef565b6020828101516101a060e0840152805165ffffffffffff166101c0840152808201516101e0840152604081015160ff16610200840152606001516080610220840152805161024084018190525f929190910190610260600582901b850181019190850190845b81811015612cc15786840361025f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612c865783518252602082019150602084019350600183019250612c63565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612c1b565b505050604085015191506121d9610100850183612b49565b5f60608284031215612225575f5ffd5b5f60608284031215612cf9575f5ffd5b61030c8383612cd9565b5f5f83601f840112612d13575f5ffd5b5081356001600160401b03811115612d29575f5ffd5b6020830191508360208260061b8501011115612d43575f5ffd5b9250929050565b5f5f5f5f60408587031215612d5d575f5ffd5b84356001600160401b03811115612d72575f5ffd5b8501601f81018713612d82575f5ffd5b80356001600160401b03811115612d97575f5ffd5b87602060a083028401011115612dab575f5ffd5b6020918201955093508501356001600160401b03811115612dca575f5ffd5b612dd687828801612d03565b95989497509550505050565b5f60208284031215612df2575f5ffd5b81356001600160401b03811115612e07575f5ffd5b8201610120818503121561030c575f5ffd5b5f8151808452602084019350602083015f5b82811015612e5457612e3e868351612aef565b60c0959095019460209190910190600101612e2b565b5093949350505050565b5f82825180855260208501945060208160051b830101602085015f5b83811015612eac57601f19858403018852612e96838351612984565b6020988901989093509190910190600101612e7a565b50909695505050505050565b6020815265ffffffffffff82511660208201525f6020830151612ede6040840182612b49565b506040830151610200610100840152612efb610220840182612e19565b6060850151805161ffff9081166101208701526020820151166101408601526040015162ffffff166101608501526080850151848203601f1901610180860152909150612f488282612e5e565b60a0860151805165ffffffffffff166101a087015260208101516101c0870152604001516101e086015260c086015160ff81166102008701529092509050612ae7565b5f60808284031215612225575f5ffd5b5f60208284031215612fab575f5ffd5b81356001600160401b03811115612fc0575f5ffd5b6121d984828501612f8b565b5f60208284031215612fdc575f5ffd5b81356001600160401b03811115612ff1575f5ffd5b82016101a0818503121561030c575f5ffd5b5f60208284031215613013575f5ffd5b81356001600160401b03811115613028575f5ffd5b6121d984828501612cd9565b602081525f82516060602084015261304f6080840182612e19565b602085810151601f19868403016040870152805180845290820193505f92909101905b808310156130c55783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a082019150602084019350600183019250613072565b506040860151858203601f19016060870152805180835260209182019450910191505f905b8082101561312a5761311383855180516001600160a01b03908116835260209182015116910152565b6040830192506020840193506001820191506130ea565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b038111828210171561316b5761316b613135565b60405290565b60405160c081016001600160401b038111828210171561316b5761316b613135565b604051608081016001600160401b038111828210171561316b5761316b613135565b60405160e081016001600160401b038111828210171561316b5761316b613135565b604080519081016001600160401b038111828210171561316b5761316b613135565b604051601f8201601f191681016001600160401b038111828210171561322157613221613135565b604052919050565b803565ffffffffffff8116811461323e575f5ffd5b919050565b5f60608284031215613253575f5ffd5b61325b613149565b905061326682613229565b81526020828101359082015260409182013591810191909152919050565b5f60a08284031215613294575f5ffd5b61329c613149565b823581526020808401359082015290506132b98360408401613243565b604082015292915050565b5f60a082840312156132d4575f5ffd5b61030c8383613284565b5f60c082840312156132ee575f5ffd5b6132f6613171565b905061330182613229565b815261330f60208301613229565b602082015261332060408301613229565b604082015261333160608301613229565b60608201526080828101359082015260a09182013591810191909152919050565b5f60c08284031215613362575f5ffd5b61030c83836132de565b5f6001600160401b0382111561338457613384613135565b5060051b60200190565b80356001600160a01b038116811461323e575f5ffd5b5f60c082840312156133b4575f5ffd5b6133bc613171565b90506133c782613229565b81526133d560208301613229565b60208201526133e660408301613229565b60408201526133316060830161338e565b5f82601f830112613406575f5ffd5b81356134196134148261336c565b6131f9565b80828252602082019150602060c0840286010192508583111561343a575f5ffd5b602085015b838110156134615761345187826133a4565b835260209092019160c00161343f565b5095945050505050565b803561ffff8116811461323e575f5ffd5b803562ffffff8116811461323e575f5ffd5b5f6060828403121561349e575f5ffd5b6134a6613149565b90506134b18261346b565b81526134bf6020830161346b565b60208201526132b96040830161347c565b803560ff8116811461323e575f5ffd5b5f608082840312156134f0575f5ffd5b6134f8613193565b9050613503826134d0565b815260208201356001600160401b0381111561351d575f5ffd5b8201601f8101841361352d575f5ffd5b803561353b6134148261336c565b8082825260208201915060208360071b85010192508683111561355c575f5ffd5b6020840193505b828410156135d9576080848803121561357a575f5ffd5b613582613193565b61358b85613229565b815260208501356003811061359e575f5ffd5b60208201526135af6040860161338e565b60408201526135c06060860161338e565b6060820152825260809390930192602090910190613563565b60208501525050506040828101359082015260609182013591810191909152919050565b5f82601f83011261360c575f5ffd5b813561361a6134148261336c565b8082825260208201915060208360051b86010192508583111561363b575f5ffd5b602085015b838110156134615780356001600160401b0381111561365d575f5ffd5b61366c886020838a01016134e0565b84525060209283019201613640565b5f610200823603121561368c575f5ffd5b6136946131b5565b61369d83613229565b81526136ac36602085016132de565b602082015260e08301356001600160401b038111156136c9575f5ffd5b6136d5368286016133f7565b6040830152506136e936610100850161348e565b60608201526101608301356001600160401b03811115613707575f5ffd5b613713368286016135fd565b608083015250613727366101808501613243565b60a08201526137396101e084016134d0565b60c082015292915050565b5f60608284031215613754575f5ffd5b61030c8383613243565b5f6040828403121561376e575f5ffd5b6137766131d7565b90506137818261338e565b815261378f6020830161338e565b602082015292915050565b5f604082840312156137aa575f5ffd5b61030c838361375e565b5f61012082360312156137c5575f5ffd5b6137cd613193565b6137d683613229565b81526137e53660208501613284565b602082015260c08301356001600160401b03811115613802575f5ffd5b61380e368286016134e0565b6040830152506138213660e0850161375e565b606082015292915050565b5f60c0828403121561383c575f5ffd5b61030c83836133a4565b5f60808284031215613856575f5ffd5b61385e613193565b905061386982613229565b815260208281013590820152613881604083016134d0565b604082015260608201356001600160401b0381111561389e575f5ffd5b8201601f810184136138ae575f5ffd5b80356138bc6134148261336c565b8082825260208201915060208360051b8501019250868311156138dd575f5ffd5b602084015b83811015613a235780356001600160401b038111156138ff575f5ffd5b85016040818a03601f19011215613914575f5ffd5b61391c6131d7565b6020820135801515811461392e575f5ffd5b815260408201356001600160401b03811115613948575f5ffd5b6020818401019250506060828b031215613960575f5ffd5b613968613149565b82356001600160401b0381111561397d575f5ffd5b8301601f81018c1361398d575f5ffd5b803561399b6134148261336c565b8082825260208201915060208360051b85010192508e8311156139bc575f5ffd5b6020840193505b828410156139de5783358252602093840193909101906139c3565b8452506139f09150506020840161347c565b6020820152613a0160408401613229565b60408201528060208301525080855250506020830192506020810190506138e2565b5060608501525091949350505050565b5f6102953683613846565b5f6101a08236031215613a4f575f5ffd5b613a57613149565b613a6136846133a4565b815260c08301356001600160401b03811115613a7b575f5ffd5b613a8736828601613846565b6020830152506132b93660e085016132de565b5f82601f830112613aa9575f5ffd5b8135613ab76134148261336c565b8082825260208201915060208360061b860101925085831115613ad8575f5ffd5b602085015b8381101561346157613aef878261375e565b8352602090920191604001613add565b5f60608236031215613b0f575f5ffd5b613b17613149565b82356001600160401b03811115613b2c575f5ffd5b613b38368286016133f7565b82525060208301356001600160401b03811115613b53575f5ffd5b830136601f820112613b63575f5ffd5b8035613b716134148261336c565b80828252602082019150602060a08402850101925036831115613b92575f5ffd5b6020840193505b82841015613bbe57613bab3685613284565b825260208201915060a084019350613b99565b602085015250505060408301356001600160401b03811115613bde575f5ffd5b613bea36828601613a9a565b60408301525092915050565b5f61029536836134e0565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a2646970667358221220d2dfe9cde85c83476731e9265ef6898e0fee33a8545c454b07dd77c3584e3f9664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa<k\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80c\x8Fm\x0E\x1A\x11a\0\x93W\x80c\xD7q\xD3\x98\x11a\0cW\x80c\xD7q\xD3\x98\x14a\x02\x0CW\x80c\xDCZ\x8B\xF8\x14a\x02\x1FW\x80c\xED\xBA\xCDD\x14a\x022W\x80c\xEE\xDE\xC1\x02\x14a\x02RW__\xFD[\x80c\x8Fm\x0E\x1A\x14a\x01\xB3W\x80c\xA1\xEC\x933\x14a\x01\xC6W\x80c\xAF\xB6:\xD4\x14a\x01\xD9W\x80c\xB8\xB0.\x0E\x14a\x01\xF9W__\xFD[\x80c&09b\x11a\0\xCEW\x80c&09b\x14a\x01MW\x80c]'\xCC\x95\x14a\x01mW\x80cy\x89\xAA\x10\x14a\x01\x8DW\x80cz\x9AU*\x14a\x01\xA0W__\xFD[\x80c\x1F9pg\x14a\0\xF4W\x80c\x1F\xE0j\xB4\x14a\x01\x1AW\x80c&\x1B\xF64\x14a\x01-W[__\xFD[a\x01\x07a\x01\x026`\x04a(UV[a\x02}V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x07a\x01(6`\x04a(~V[a\x02\x9BV[a\x01@a\x01;6`\x04a(\x98V[a\x02\xB3V[`@Qa\x01\x11\x91\x90a(\xCFV[a\x01`a\x01[6`\x04a)\x04V[a\x02\xC6V[`@Qa\x01\x11\x91\x90a*MV[a\x01\x80a\x01{6`\x04a)\x04V[a\x03\x13V[`@Qa\x01\x11\x91\x90a+\xA3V[a\x01\x07a\x01\x9B6`\x04a,\xE9V[a\x03YV[a\x01\x07a\x01\xAE6`\x04a-JV[a\x03qV[a\x01@a\x01\xC16`\x04a-\xE2V[a\x04'V[a\x01\x07a\x01\xD46`\x04a(~V[a\x04:V[a\x01\xECa\x01\xE76`\x04a)\x04V[a\x04RV[`@Qa\x01\x11\x91\x90a.\xB8V[a\x01\x07a\x02\x076`\x04a/\x9BV[a\x04\x98V[a\x01@a\x02\x1A6`\x04a/\xCCV[a\x04\xAAV[a\x01@a\x02-6`\x04a0\x03V[a\x04\xBDV[a\x02Ea\x02@6`\x04a)\x04V[a\x04\xD0V[`@Qa\x01\x11\x91\x90a04V[a\x02ea\x02`6`\x04a/\x9BV[a\x052V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x11V[_a\x02\x95a\x02\x906\x84\x90\x03\x84\x01\x84a2\xC4V[a\x05DV[\x92\x91PPV[_a\x02\x95a\x02\xAE6\x84\x90\x03\x84\x01\x84a3RV[a\x05xV[``a\x02\x95a\x02\xC1\x83a6{V[a\x05\xD3V[a\x02\xCEa&3V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08\x06\x92PPPV[\x93\x92PPPV[a\x03\x1Ba&\xA7V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\n\xB8\x92PPPV[_a\x02\x95a\x03l6\x84\x90\x03\x84\x01\x84a7DV[a\r\xEAV[_a\x04\x1E\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xC2Wa\x03\xB3`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a2\xC4V[\x81R` \x01\x90`\x01\x01\x90a\x03\x96V[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04\x14Wa\x04\x05`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a7\x9AV[\x81R` \x01\x90`\x01\x01\x90a\x03\xE8V[PPPPPa\x0E\x1BV[\x95\x94PPPPPV[``a\x02\x95a\x045\x83a7\xB4V[a\x0F\xD2V[_a\x02\x95a\x04M6\x84\x90\x03\x84\x01\x84a8,V[a\x11\xE9V[a\x04Za'\x16V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x12`\x92PPPV[_a\x02\x95a\x04\xA5\x83a:3V[a\x14\xBAV[``a\x02\x95a\x04\xB8\x83a:>V[a\x16*V[``a\x02\x95a\x04\xCB\x83a:\xFFV[a\x18\xECV[a\x04\xF4`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1AQ\x92PPPV[_a\x02\x95a\x05?\x83a;\xF6V[a\x1C\xC0V[_a\x02\x95\x82_\x01Q\x83` \x01Qa\x05^\x85`@\x01Qa\r\xEAV[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q``\x80\x87\x01Q`\x80\x80\x89\x01Q`\xA0\x80\x8B\x01Q\x87Qe\xFF\xFF\xFF\xFF\xFF\xFF\x9B\x8C\x16\x81R\x98\x8B\x16\x99\x89\x01\x99\x90\x99R\x94\x89\x16\x95\x87\x01\x95\x90\x95R\x96\x16\x90\x84\x01R\x93\x82\x01R\x91\x82\x01R`\xC0\x90 _\x90a\x02\x95V[``_a\x05\xED\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa\x1E\x11V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x07Wa\x06\x07a15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x061W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x90\x92\x1B`2\x84\x01R\x80Q`\x80\x01Q`8\x84\x01RQ`\xA0\x01Q`X\x83\x01R\x84\x01QQ\x90\x92P`x\x83\x01\x90a\x06\x96\x90a\x1E\x9CV[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x06\xE4Wa\x06\xDA\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x06\xCDWa\x06\xCDa<\x01V[` \x02` \x01\x01Qa\x1E\xC2V[\x91P`\x01\x01a\x06\xA6V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x07\"\x90a\x1E\x9CV[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x07pWa\x07f\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x07YWa\x07Ya<\x01V[` \x02` \x01\x01Qa\x1F\x14V[\x91P`\x01\x01a\x072V[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x07\x94WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x07\xA6WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x07\xBF\x82\x82a\x07\xB8W`\x01a\x1F\x9CV[_[a\x1F\x9CV[\x91P\x80a\x07\xEEW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x07\xFC\x82\x86`\xC0\x01Qa\x1F\x9CV[\x91PPPP\x91\x90PV[a\x08\x0Ea&3V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xD5Wa\x08\xD5a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t%W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x08\xF3W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xB0W\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t`Wa\t`a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xA7W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xBCWa\t\xBCa)pV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\xD6Wa\t\xD6a<\x01V[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\t\xF3Wa\t\xF3a)pV[\x90\x81`\x02\x81\x11\x15a\n\x06Wa\n\x06a)pV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n,Wa\n,a<\x01V[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\nd\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n~Wa\n~a<\x01V[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\t1V[PPP\x91\x90PV[a\n\xC0a&\xA7V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0BNWa\x0BNa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0B\xB1W\x81` \x01[a\x0B\x9E`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x0BlW\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\r\x7FW\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0B\xF8Wa\x0B\xF8a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0C+Wa\x0C+a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0CTW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0CoWa\x0Coa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0C\xE4W\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0C\xACWa\x0C\xACa<\x01V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0C\xCCWa\x0C\xCCa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0C\x80V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\r\x08Wa\r\x08a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\rJWa\rJa<\x01V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0B\xBDV[PP\x80Q\x82Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x83\x01Q\x84Q`\xA0\x90\x81\x01\x91\x90\x91R`@\x80\x85\x01Q\x81\x87\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x87\x01Q\x81Q\x90\x83\x1C\x95\x01\x94\x90\x94R`L\x86\x01Q\x84Q\x91\x1C\x91\x01R`R\x84\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`r\x90\x92\x01Q\x91Q\x01R\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x95V[_\x81Q\x83Q\x14a\x0E>W`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x0E^W_Q` a<\x16_9_Q\x90_R\x91PPa\x02\x95V[\x80`\x01\x03a\x0E\xC1W_a\x0E\xA3\x85_\x81Q\x81\x10a\x0E|Wa\x0E|a<\x01V[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[` \x02` \x01\x01Qa\x1F\xA8V[\x90Pa\x0E\xB8\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x95V[\x80`\x02\x03a\x0F5W_a\x0E\xDF\x85_\x81Q\x81\x10a\x0E|Wa\x0E|a<\x01V[\x90P_a\x0F\x13\x86`\x01\x81Q\x81\x10a\x0E\xF8Wa\x0E\xF8a<\x01V[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x95V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x0F\xABWa\x0F\xA2\x82\x82`\x01\x01a\x0F\x93\x89\x85\x81Q\x81\x10a\x0FyWa\x0Fya<\x01V[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x0FTV[P\x80Q`\x05\x1B` \x82\x01 a\x04\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0F\xFDWa\x0F\xFDa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x10'W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x10\x8F\x90\x82\x90a\x1F\x9CV[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x10\xDB\x90a\x1E\x9CV[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xB0Wa\x114\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\x1EWa\x11\x1Ea<\x01V[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x11q\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11TWa\x11Ta<\x01V[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x07\xBAWa\x07\xBAa)pV[\x91Pa\x11\xA8\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\x91Wa\x11\x91a<\x01V[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x11\xDF\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\xC8Wa\x11\xC8a<\x01V[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x10\xEFV[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x03\x0C\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x12ha'\x16V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x91\x1C`@\x90\x91\x01R`8\x83\x01Q\x81Q`\x80\x01R`X\x83\x01Q\x90Q`\xA0\x01R`x\x82\x01Q`z\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12\xDFWa\x12\xDFa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x13\x18W\x81` \x01[a\x13\x05a'\xE1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x12\xFDW\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x13cWa\x135\x83a\x1F\xFBV[\x85`@\x01Q\x83\x81Q\x81\x10a\x13KWa\x13Ka<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x13 V[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x13\xBCWa\x13\xBCa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x14\x18W\x81` \x01[a\x14\x05`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x13\xDAW\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x14cWa\x145\x84a XV[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x14KWa\x14Ka<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x14 V[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x14\xA8W\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x15\x03W_Q` a<\x16_9_Q\x90_R\x91Pa\x16\tV[\x80`\x01\x03a\x15LWa\x15E\x81_\x1Ba\x157\x87``\x01Q_\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[` \x02` \x01\x01Qa!iV[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x16\tV[\x80`\x02\x03a\x15\x8DWa\x15E\x81_\x1Ba\x15s\x87``\x01Q_\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[a\x05^\x88``\x01Q`\x01\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x15\xDEWa\x15\xD5\x82\x82`\x01\x01a\x0F\x93\x8A``\x01Q\x85\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[P`\x01\x01a\x15\xACV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x16\x07\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x16>\x83` \x01Q``\x01Qa!\xE1V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16XWa\x16Xa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x16\x82W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x16\xED\x90\x82\x90a\x1F\x9CV[` \x85\x01Q``\x01QQ\x90\x91Pa\x17\x03\x81a\x1E\x9CV[a\x17\x13\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x18\x85Wa\x17Y\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x17=Wa\x17=a<\x01V[` \x02` \x01\x01Q_\x01Qa\x17RW_a\x1F\x9CV[`\x01a\x1F\x9CV[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x17vWa\x17va<\x01V[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x17\x91\x81a\x1E\x9CV[a\x17\xA1\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x18\x05Wa\x17\xFB\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x17\xCBWa\x17\xCBa<\x01V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x17\xEBWa\x17\xEBa<\x01V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x17\xA5V[Pa\x18?\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x18$Wa\x18$a<\x01V[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x18z\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x18_Wa\x18_a<\x01V[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x17\x17V[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R`@\x80\x89\x01\x80QQ`\xD0\x90\x81\x1B\x83\x89\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x88\x01R\x80Q\x90\x91\x01Q\x90\x91\x1B`L\x86\x01R\x80Q\x90\x92\x01Q`R\x85\x01R\x90Q\x01Q`r\x83\x01\x90\x81R\x91`\x92\x01a\x07\xFCV[``_a\x19\x05\x83_\x01Q\x84` \x01Q\x85`@\x01Qa\"+V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x1FWa\x19\x1Fa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x19IW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x19^\x90a\x1E\x9CV[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x19\xA5Wa\x19\x9B\x82\x86_\x01Q\x83\x81Q\x81\x10a\x19\x8EWa\x19\x8Ea<\x01V[` \x02` \x01\x01Qa\"\x80V[\x91P`\x01\x01a\x19kV[Pa\x19\xB4\x84` \x01QQa\x1E\x9CV[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x1A\x02Wa\x19\xF8\x82\x86` \x01Q\x83\x81Q\x81\x10a\x19\xEBWa\x19\xEBa<\x01V[` \x02` \x01\x01Qa\"\xBAV[\x91P`\x01\x01a\x19\xC4V[Pa\x1A\x11\x84`@\x01QQa\x1E\x9CV[_[\x84`@\x01QQ\x81\x10\x15a\n\xB0Wa\x1AG\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1A:Wa\x1A:a<\x01V[` \x02` \x01\x01Qa\"\xF6V[\x91P`\x01\x01a\x1A\x13V[a\x1Au`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\x9AWa\x1A\x9Aa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1A\xD3W\x81` \x01[a\x1A\xC0a'\xE1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1A\xB8W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\x19Wa\x1A\xED\x83a#\x17V[\x85Q\x80Q\x84\x90\x81\x10a\x1B\x01Wa\x1B\x01a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1A\xD8V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1BIW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1BeWa\x1Bea15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1B\x9EW\x81` \x01[a\x1B\x8Ba(\x15V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1B\x83W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\xE9Wa\x1B\xBB\x84a#_V[\x86` \x01Q\x83\x81Q\x81\x10a\x1B\xD1Wa\x1B\xD1a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1B\xA6V[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x06Wa\x1C\x06a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1CJW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1C$W\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1C\xB7W`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1C\x9FWa\x1C\x9Fa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1CRV[PPPP\x91\x90PV[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1C\xE6W_Q` a<\x16_9_Q\x90_R\x91Pa\x1D\xDEV[\x80`\x01\x03a\x1D!Wa\x1D\x1A\x81_\x1Ba\x157\x86` \x01Q_\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[` \x02` \x01\x01Qa#\xA9V[\x91Pa\x1D\xDEV[\x80`\x02\x03a\x1DbWa\x1D\x1A\x81_\x1Ba\x1DH\x86` \x01Q_\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[a\x05^\x87` \x01Q`\x01\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1D\xB3Wa\x1D\xAA\x82\x82`\x01\x01a\x0F\x93\x89` \x01Q\x85\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[P`\x01\x01a\x1D\x81V[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1D\xDC\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x04\x1EV[\x80Q`e\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x1E/WP` \x83\x01Q\x15[\x80\x15a\x1E=WP`@\x83\x01Q\x15[\x90P\x80a\x1EKW`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a\x1E\x93W\x84\x81\x81Q\x81\x10a\x1EqWa\x1Eqa<\x01V[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa\x1EVV[PP\x93\x92PPPV[a\xFF\xFF\x81\x11\x15a\x1E\xBFW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x03\x0CV[_a\x1F\"\x83\x83_\x01Qa\x1F\x9CV[\x90Pa\x1F2\x82` \x01QQa\x1E\x9CV[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\x1F\x80Wa\x1Fv\x82\x84` \x01Q\x83\x81Q\x81\x10a\x1FiWa\x1Fia<\x01V[` \x02` \x01\x01Qa$\x15V[\x91P`\x01\x01a\x1FBV[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x03\x0CV[_\x81\x83SPP`\x01\x01\x90V[_a\x03\x0C\x83_\x01Q\x84` \x01Qa\x1F\xC2\x86`@\x01Qa\r\xEAV[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[a \x03a'\xE1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a \x83`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a \xAFWa \xAFa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a \xFFW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a \xCDW\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a!JWa!\x1C\x83a$`V[\x85` \x01Q\x83\x81Q\x81\x10a!2Wa!2a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a!\x07V[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a!{\x83` \x01Q_\x01Qa$\xF8V[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa!\xD9\x84_\x01Qa!\xC4W_a!\xC7V[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[`\xE1_[\x82Q\x81\x10\x15a\"%W\x82\x81\x81Q\x81\x10a\"\0Wa\"\0a<\x01V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa!\xE5V[P\x91\x90PV[_\x82Q\x84Q\x14a\"NW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a\"pW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a\x1E\xF7V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x03\x0CV[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x03\x0CV[a#\x1Fa'\xE1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a =V[a#ga(\x15V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x95\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a#\xD1Wa#\xD1a)pV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa$=\x81\x83` \x01Q`\x02\x81\x11\x15a\x07\xBAWa\x07\xBAa)pV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x03\x0CV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a$\xA9Wa$\xA9a)pV[\x83` \x01\x90`\x02\x81\x11\x15a$\xBFWa$\xBFa)pV[\x90\x81`\x02\x81\x11\x15a$\xD2Wa$\xD2a)pV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a%\x18WP_Q` a<\x16_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a%NWa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a%8Wa%8a<\x01V[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a%\xABWa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a%nWa%na<\x01V[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a%\x89Wa%\x89a<\x01V[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a&\x0CWa&\x03\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a%\xECWa%\xECa<\x01V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a%\xCAV[P\x80Q`\x05\x1B` \x82\x01 a!\xD9\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a&Ta(\x15V[\x81R` \x01a&\x84`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a&\xA2`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80``\x01`@R\x80a&\xBAa'\xE1V[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01\x81\x90R`\xA0\x82\x01R\x91\x01R\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a'f`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a'\xA0`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a'\xD5`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a&\xA2`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a(fW__\xFD[P\x90\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a\"%W__\xFD[_`\xC0\x82\x84\x03\x12\x15a(\x8EW__\xFD[a\x03\x0C\x83\x83a(nV[_` \x82\x84\x03\x12\x15a(\xA8W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a(\xBDW__\xFD[\x82\x01a\x02\0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[__` \x83\x85\x03\x12\x15a)\x15W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a)*W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a):W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a)OW__\xFD[\x85` \x82\x84\x01\x01\x11\x15a)`W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_`\x80\x83\x01`\xFF\x83Q\x16\x84R` \x83\x01Q`\x80` \x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P` \x83\x01\x93P_\x92P[\x80\x83\x10\x15a*,W\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x83R` \x81\x01Q`\x03\x81\x10a)\xE9WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x80` \x85\x01RP`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa)\xB2V[P`@\x85\x01Q`@\x87\x01R``\x85\x01Q``\x87\x01R\x80\x93PPPP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa*\xA3`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra*\xBFa\x01@\x84\x01\x82a)\x84V[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[` \x81Ra+\xB5` \x82\x01\x83Qa*\xEFV[` \x82\x81\x01Qa\x01\xA0`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xC0\x84\x01R\x80\x82\x01Qa\x01\xE0\x84\x01R`@\x81\x01Q`\xFF\x16a\x02\0\x84\x01R``\x01Q`\x80a\x02 \x84\x01R\x80Qa\x02@\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02``\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a,\xC1W\x86\x84\x03a\x02_\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a,\x86W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa,cV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a,\x1BV[PPP`@\x85\x01Q\x91Pa!\xD9a\x01\0\x85\x01\x83a+IV[_``\x82\x84\x03\x12\x15a\"%W__\xFD[_``\x82\x84\x03\x12\x15a,\xF9W__\xFD[a\x03\x0C\x83\x83a,\xD9V[__\x83`\x1F\x84\x01\x12a-\x13W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-)W__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a-CW__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a-]W__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a-rW__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a-\x82W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x97W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a-\xABW__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xCAW__\xFD[a-\xD6\x87\x82\x88\x01a-\x03V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a-\xF2W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a.\x07W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a.TWa.>\x86\x83Qa*\xEFV[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a.+V[P\x93\x94\x93PPPPV[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a.\xACW`\x1F\x19\x85\x84\x03\x01\x88Ra.\x96\x83\x83Qa)\x84V[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a.zV[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa.\xDE`@\x84\x01\x82a+IV[P`@\x83\x01Qa\x02\0a\x01\0\x84\x01Ra.\xFBa\x02 \x84\x01\x82a.\x19V[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01 \x87\x01R` \x82\x01Q\x16a\x01@\x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01`\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\x80\x86\x01R\x90\x91Pa/H\x82\x82a.^V[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x87\x01R` \x81\x01Qa\x01\xC0\x87\x01R`@\x01Qa\x01\xE0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x02\0\x87\x01R\x90\x92P\x90Pa*\xE7V[_`\x80\x82\x84\x03\x12\x15a\"%W__\xFD[_` \x82\x84\x03\x12\x15a/\xABW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xC0W__\xFD[a!\xD9\x84\x82\x85\x01a/\x8BV[_` \x82\x84\x03\x12\x15a/\xDCW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xF1W__\xFD[\x82\x01a\x01\xA0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_` \x82\x84\x03\x12\x15a0\x13W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0(W__\xFD[a!\xD9\x84\x82\x85\x01a,\xD9V[` \x81R_\x82Q``` \x84\x01Ra0O`\x80\x84\x01\x82a.\x19V[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a0\xC5W\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa0rV[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a1*Wa1\x13\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa0\xEAV[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@R\x90V[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a2!Wa2!a15V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a2SW__\xFD[a2[a1IV[\x90Pa2f\x82a2)V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a2\x94W__\xFD[a2\x9Ca1IV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa2\xB9\x83`@\x84\x01a2CV[`@\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a2\xD4W__\xFD[a\x03\x0C\x83\x83a2\x84V[_`\xC0\x82\x84\x03\x12\x15a2\xEEW__\xFD[a2\xF6a1qV[\x90Pa3\x01\x82a2)V[\x81Ra3\x0F` \x83\x01a2)V[` \x82\x01Ra3 `@\x83\x01a2)V[`@\x82\x01Ra31``\x83\x01a2)V[``\x82\x01R`\x80\x82\x81\x015\x90\x82\x01R`\xA0\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a3bW__\xFD[a\x03\x0C\x83\x83a2\xDEV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a3\x84Wa3\x84a15V[P`\x05\x1B` \x01\x90V[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a2>W__\xFD[_`\xC0\x82\x84\x03\x12\x15a3\xB4W__\xFD[a3\xBCa1qV[\x90Pa3\xC7\x82a2)V[\x81Ra3\xD5` \x83\x01a2)V[` \x82\x01Ra3\xE6`@\x83\x01a2)V[`@\x82\x01Ra31``\x83\x01a3\x8EV[_\x82`\x1F\x83\x01\x12a4\x06W__\xFD[\x815a4\x19a4\x14\x82a3lV[a1\xF9V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a4:W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aWa4Q\x87\x82a3\xA4V[\x83R` \x90\x92\x01\x91`\xC0\x01a4?V[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[_``\x82\x84\x03\x12\x15a4\x9EW__\xFD[a4\xA6a1IV[\x90Pa4\xB1\x82a4kV[\x81Ra4\xBF` \x83\x01a4kV[` \x82\x01Ra2\xB9`@\x83\x01a4|V[\x805`\xFF\x81\x16\x81\x14a2>W__\xFD[_`\x80\x82\x84\x03\x12\x15a4\xF0W__\xFD[a4\xF8a1\x93V[\x90Pa5\x03\x82a4\xD0V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5\x1DW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a5-W__\xFD[\x805a5;a4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a5\\W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a5\xD9W`\x80\x84\x88\x03\x12\x15a5zW__\xFD[a5\x82a1\x93V[a5\x8B\x85a2)V[\x81R` \x85\x015`\x03\x81\x10a5\x9EW__\xFD[` \x82\x01Ra5\xAF`@\x86\x01a3\x8EV[`@\x82\x01Ra5\xC0``\x86\x01a3\x8EV[``\x82\x01R\x82R`\x80\x93\x90\x93\x01\x92` \x90\x91\x01\x90a5cV[` \x85\x01RPPP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a6\x0CW__\xFD[\x815a6\x1Aa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a6;W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a6]W__\xFD[a6l\x88` \x83\x8A\x01\x01a4\xE0V[\x84RP` \x92\x83\x01\x92\x01a6@V[_a\x02\0\x826\x03\x12\x15a6\x8CW__\xFD[a6\x94a1\xB5V[a6\x9D\x83a2)V[\x81Ra6\xAC6` \x85\x01a2\xDEV[` \x82\x01R`\xE0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a6\xC9W__\xFD[a6\xD56\x82\x86\x01a3\xF7V[`@\x83\x01RPa6\xE96a\x01\0\x85\x01a4\x8EV[``\x82\x01Ra\x01`\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a7\x07W__\xFD[a7\x136\x82\x86\x01a5\xFDV[`\x80\x83\x01RPa7'6a\x01\x80\x85\x01a2CV[`\xA0\x82\x01Ra79a\x01\xE0\x84\x01a4\xD0V[`\xC0\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a7TW__\xFD[a\x03\x0C\x83\x83a2CV[_`@\x82\x84\x03\x12\x15a7nW__\xFD[a7va1\xD7V[\x90Pa7\x81\x82a3\x8EV[\x81Ra7\x8F` \x83\x01a3\x8EV[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a7\xAAW__\xFD[a\x03\x0C\x83\x83a7^V[_a\x01 \x826\x03\x12\x15a7\xC5W__\xFD[a7\xCDa1\x93V[a7\xD6\x83a2)V[\x81Ra7\xE56` \x85\x01a2\x84V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x02W__\xFD[a8\x0E6\x82\x86\x01a4\xE0V[`@\x83\x01RPa8!6`\xE0\x85\x01a7^V[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a8<W__\xFD[a\x03\x0C\x83\x83a3\xA4V[_`\x80\x82\x84\x03\x12\x15a8VW__\xFD[a8^a1\x93V[\x90Pa8i\x82a2)V[\x81R` \x82\x81\x015\x90\x82\x01Ra8\x81`@\x83\x01a4\xD0V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x9EW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a8\xAEW__\xFD[\x805a8\xBCa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a8\xDDW__\xFD[` \x84\x01[\x83\x81\x10\x15a:#W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xFFW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a9\x14W__\xFD[a9\x1Ca1\xD7V[` \x82\x015\x80\x15\x15\x81\x14a9.W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a9HW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a9`W__\xFD[a9ha1IV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a9}W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a9\x8DW__\xFD[\x805a9\x9Ba4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a9\xBCW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a9\xDEW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a9\xC3V[\x84RPa9\xF0\x91PP` \x84\x01a4|V[` \x82\x01Ra:\x01`@\x84\x01a2)V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa8\xE2V[P``\x85\x01RP\x91\x94\x93PPPPV[_a\x02\x956\x83a8FV[_a\x01\xA0\x826\x03\x12\x15a:OW__\xFD[a:Wa1IV[a:a6\x84a3\xA4V[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:{W__\xFD[a:\x876\x82\x86\x01a8FV[` \x83\x01RPa2\xB96`\xE0\x85\x01a2\xDEV[_\x82`\x1F\x83\x01\x12a:\xA9W__\xFD[\x815a:\xB7a4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a:\xD8W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aWa:\xEF\x87\x82a7^V[\x83R` \x90\x92\x01\x91`@\x01a:\xDDV[_``\x826\x03\x12\x15a;\x0FW__\xFD[a;\x17a1IV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a;,W__\xFD[a;86\x82\x86\x01a3\xF7V[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;SW__\xFD[\x83\x016`\x1F\x82\x01\x12a;cW__\xFD[\x805a;qa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a;\x92W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a;\xBEWa;\xAB6\x85a2\x84V[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa;\x99V[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xDEW__\xFD[a;\xEA6\x82\x86\x01a:\x9AV[`@\x83\x01RP\x92\x91PPV[_a\x02\x956\x83a4\xE0V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \xD2\xDF\xE9\xCD\xE8\\\x83Gg1\xE9&^\xF6\x89\x8E\x0F\xEE3\xA8T\\EK\x07\xDDw\xC3XN?\x96dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c80638f6d0e1a11610093578063d771d39811610063578063d771d3981461020c578063dc5a8bf81461021f578063edbacd4414610232578063eedec10214610252575f5ffd5b80638f6d0e1a146101b3578063a1ec9333146101c6578063afb63ad4146101d9578063b8b02e0e146101f9575f5ffd5b806326303962116100ce578063263039621461014d5780635d27cc951461016d5780637989aa101461018d5780637a9a552a146101a0575f5ffd5b80631f397067146100f45780631fe06ab41461011a578063261bf6341461012d575b5f5ffd5b610107610102366004612855565b61027d565b6040519081526020015b60405180910390f35b61010761012836600461287e565b61029b565b61014061013b366004612898565b6102b3565b60405161011191906128cf565b61016061015b366004612904565b6102c6565b6040516101119190612a4d565b61018061017b366004612904565b610313565b6040516101119190612ba3565b61010761019b366004612ce9565b610359565b6101076101ae366004612d4a565b610371565b6101406101c1366004612de2565b610427565b6101076101d436600461287e565b61043a565b6101ec6101e7366004612904565b610452565b6040516101119190612eb8565b610107610207366004612f9b565b610498565b61014061021a366004612fcc565b6104aa565b61014061022d366004613003565b6104bd565b610245610240366004612904565b6104d0565b6040516101119190613034565b610265610260366004612f9b565b610532565b60405165ffffffffffff199091168152602001610111565b5f610295610290368490038401846132c4565b610544565b92915050565b5f6102956102ae36849003840184613352565b610578565b60606102956102c18361367b565b6105d3565b6102ce612633565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061080692505050565b9392505050565b61031b6126a7565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610ab892505050565b5f61029561036c36849003840184613744565b610dea565b5f61041e8585808060200260200160405190810160405280939291908181526020015f905b828210156103c2576103b360a083028601368190038101906132c4565b81526020019060010190610396565b50505050508484808060200260200160405190810160405280939291908181526020015f905b82821015610414576104056040830286013681900381019061379a565b815260200190600101906103e8565b5050505050610e1b565b95945050505050565b6060610295610435836137b4565b610fd2565b5f61029561044d3684900384018461382c565b6111e9565b61045a612716565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061126092505050565b5f6102956104a583613a33565b6114ba565b60606102956104b883613a3e565b61162a565b60606102956104cb83613aff565b6118ec565b6104f460405180606001604052806060815260200160608152602001606081525090565b61030c83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611a5192505050565b5f61029561053f83613bf6565b611cc0565b5f610295825f0151836020015161055e8560400151610dea565b604080519384526020840192909252908201526060902090565b805160208083015160408085015160608087015160808089015160a0808b0151875165ffffffffffff9b8c168152988b169989019990995294891695870195909552961690840152938201529182015260c090205f90610295565b60605f6105ed836040015184608001518560a00151611e11565b9050806001600160401b0381111561060757610607613135565b6040519080825280601f01601f191660200182016040528015610631576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c840152805160409081015190921b603284015280516080015160388401525160a00151605883015284015151909250607883019061069690611e9c565b60408401515160f01b81526002015f5b8460400151518110156106e4576106da82866040015183815181106106cd576106cd613c01565b6020026020010151611ec2565b91506001016106a6565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b600482015260808401515160079091019061072290611e9c565b60808401515160f01b81526002015f5b84608001515181101561077057610766828660800151838151811061075957610759613c01565b6020026020010151611f14565b9150600101610732565b5060a0840151515f9065ffffffffffff16158015610794575060a085015160200151155b80156107a6575060a085015160400151155b90506107bf82826107b8576001611f9c565b5f5b611f9c565b9150806107ee5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b6107fc828660c00151611f9c565b9150505050919050565b61080e612633565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156108d5576108d5613135565b60405190808252806020026020018201604052801561092557816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816108f35790505b506040840151602001525f5b8161ffff16811015610ab057825160d01c60068401856040015160200151838151811061096057610960613c01565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109a757604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109bc576109bc612970565b85604001516020015183815181106109d6576109d6613c01565b60200260200101516020019060028111156109f3576109f3612970565b90816002811115610a0657610a06612970565b905250835160601c601485018660400151602001518481518110610a2c57610a2c613c01565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610a6484805160601c91601490910190565b8660400151602001518481518110610a7e57610a7e613c01565b6020026020010151606001819650826001600160a01b03166001600160a01b0316815250505050806001019050610931565b505050919050565b610ac06126a7565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610b4e57610b4e613135565b604051908082528060200260200182016040528015610bb157816020015b610b9e6040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610b6c5790505b506020840151606001525f5b8161ffff16811015610d7f578251602085015160600151805160019095019460f89290921c91821515919084908110610bf857610bf8613c01565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610c2b57610c2b613135565b604051908082528060200260200182016040528015610c54578160200160208202803683370190505b508660200151606001518481518110610c6f57610c6f613c01565b6020908102919091018101510151525f5b8161ffff16811015610ce4578551602087018860200151606001518681518110610cac57610cac613c01565b6020026020010151602001515f01518381518110610ccc57610ccc613c01565b60209081029190910101919091529550600101610c80565b50845160e81c600386018760200151606001518581518110610d0857610d08613c01565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610d4a57610d4a613c01565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610bbd565b505080518251608090810191909152602080830151845160a090810191909152604080850151818701805160d092831c90526046870151815190831c950194909452604c8601518451911c910152605284015182519093019290925260729092015191510152919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610295565b5f8151835114610e3e5760405163b1f40f7760e01b815260040160405180910390fd5b82515f819003610e5e575f516020613c165f395f51905f52915050610295565b80600103610ec1575f610ea3855f81518110610e7c57610e7c613c01565b6020026020010151855f81518110610e9657610e96613c01565b6020026020010151611fa8565b9050610eb882825f9182526020526040902090565b92505050610295565b80600203610f35575f610edf855f81518110610e7c57610e7c613c01565b90505f610f1386600181518110610ef857610ef8613c01565b602002602001015186600181518110610e9657610e96613c01565b6040805194855260208501939093529183019190915250606090209050610295565b604080516001830181526002830160051b8101909152602081018290525f5b82811015610fab57610fa28282600101610f93898581518110610f7957610f79613c01565b6020026020010151898681518110610e9657610e96613c01565b60019190910160051b82015290565b50600101610f54565b50805160051b602082012061041e8280516040516001820160051b83011490151060061b52565b60408101516020015151606090602f0260f701806001600160401b03811115610ffd57610ffd613135565b6040519080825280601f01601f191660200182016040528015611027576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061108f908290611f9c565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b605484015251015151606890910191506110db90611e9c565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610ab05761113482866040015160200151838151811061111e5761111e613c01565b60200260200101515f015160d01b815260060190565b915061117182866040015160200151838151811061115457611154613c01565b60200260200101516020015160028111156107ba576107ba612970565b91506111a882866040015160200151838151811061119157611191613c01565b60200260200101516040015160601b815260140190565b91506111df8286604001516020015183815181106111c8576111c8613c01565b60200260200101516060015160601b815260140190565b91506001016110ef565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b905061030c8184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b611268612716565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c93019290925260328401518251911c60409091015260388301518151608001526058830151905160a001526078820151607a83019060f01c806001600160401b038111156112df576112df613135565b60405190808252806020026020018201604052801561131857816020015b6113056127e1565b8152602001906001900390816112fd5790505b5060408401525f5b8161ffff168110156113635761133583611ffb565b8560400151838151811061134b5761134b613c01565b60209081029190910101919091529250600101611320565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156113bc576113bc613135565b60405190808252806020026020018201604052801561141857816020015b61140560405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816113da5790505b5060808501525f5b8161ffff168110156114635761143584612058565b8660800151838151811061144b5761144b613c01565b60209081029190910101919091529350600101611420565b50825160019384019360f89190911c908190036114a857835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f03611503575f516020613c165f395f51905f529150611609565b8060010361154c57611545815f1b61153787606001515f8151811061152a5761152a613c01565b6020026020010151612169565b5f9182526020526040902090565b9150611609565b8060020361158d57611545815f1b61157387606001515f8151811061152a5761152a613c01565b61055e886060015160018151811061152a5761152a613c01565b604080516001830181526002830160051b8101909152602081018290525f5b828110156115de576115d58282600101610f938a60600151858151811061152a5761152a613c01565b506001016115ac565b50805160051b602082012092506116078180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f61163e8360200151606001516121e1565b9050806001600160401b0381111561165857611658613135565b6040519080825280601f01601f191660200182016040528015611682576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c8301906116ed908290611f9c565b6020850151606001515190915061170381611e9c565b611713828260f01b815260020190565b91505f5b818110156118855761175983876020015160600151838151811061173d5761173d613c01565b60200260200101515f0151611752575f611f9c565b6001611f9c565b92505f866020015160600151828151811061177657611776613c01565b6020026020010151602001515f015151905061179181611e9c565b6117a1848260f01b815260020190565b93505f5b81811015611805576117fb8589602001516060015185815181106117cb576117cb613c01565b6020026020010151602001515f015183815181106117eb576117eb613c01565b6020026020010151815260200190565b94506001016117a5565b5061183f84886020015160600151848151811061182457611824613c01565b6020026020010151602001516020015160e81b815260030190565b935061187a84886020015160600151848151811061185f5761185f613c01565b6020026020010151602001516040015160d01b815260060190565b935050600101611717565b5084516080908101518352855160a090810151602080860191909152604080890180515160d090811b83890152815190930151831b604688015280519091015190911b604c86015280519092015160528501529051015160728301908152916092016107fc565b60605f611905835f01518460200151856040015161222b565b9050806001600160401b0381111561191f5761191f613135565b6040519080825280601f01601f191660200182016040528015611949576020820181803683370190505b50835151909250602083019061195e90611e9c565b83515160f01b81526002015f5b8451518110156119a55761199b82865f0151838151811061198e5761198e613c01565b6020026020010151612280565b915060010161196b565b506119b4846020015151611e9c565b60208401515160f01b81526002015f5b846020015151811015611a02576119f882866020015183815181106119eb576119eb613c01565b60200260200101516122ba565b91506001016119c4565b50611a11846040015151611e9c565b5f5b846040015151811015610ab057611a478286604001518381518110611a3a57611a3a613c01565b60200260200101516122f6565b9150600101611a13565b611a7560405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611a9a57611a9a613135565b604051908082528060200260200182016040528015611ad357816020015b611ac06127e1565b815260200190600190039081611ab85790505b5083525f5b8161ffff16811015611b1957611aed83612317565b8551805184908110611b0157611b01613c01565b60209081029190910101919091529250600101611ad8565b50815160029092019160f01c61ffff82168114611b4957604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611b6557611b65613135565b604051908082528060200260200182016040528015611b9e57816020015b611b8b612815565b815260200190600190039081611b835790505b5060208501525f5b8161ffff16811015611be957611bbb8461235f565b86602001518381518110611bd157611bd1613c01565b60209081029190910101919091529350600101611ba6565b508061ffff166001600160401b03811115611c0657611c06613135565b604051908082528060200260200182016040528015611c4a57816020015b604080518082019091525f8082526020820152815260200190600190039081611c245790505b5060408501525f5b8161ffff16811015611cb757604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611c9f57611c9f613c01565b60209081029190910101919091529350600101611c52565b50505050919050565b6020810151515f908190808203611ce6575f516020613c165f395f51905f529150611dde565b80600103611d2157611d1a815f1b61153786602001515f81518110611d0d57611d0d613c01565b60200260200101516123a9565b9150611dde565b80600203611d6257611d1a815f1b611d4886602001515f81518110611d0d57611d0d613c01565b61055e8760200151600181518110611d0d57611d0d613c01565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611db357611daa8282600101610f9389602001518581518110611d0d57611d0d613c01565b50600101611d81565b50805160051b60208201209250611ddc8180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f9061041e565b80516065905f9065ffffffffffff16158015611e2f57506020830151155b8015611e3d57506040830151155b905080611e4b576046820191505b8451606602820191505f5b8451811015611e9357848181518110611e7157611e71613c01565b60200260200101516020015151602f0260430183019250806001019050611e56565b50509392505050565b61ffff811115611ebf5760405163161e7a6b60e11b815260040160405180910390fd5b50565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a083015160208201908152915060400161030c565b5f611f2283835f0151611f9c565b9050611f32826020015151611e9c565b60208201515160f01b81526002015f5b826020015151811015611f8057611f768284602001518381518110611f6957611f69613c01565b6020026020010151612415565b9150600101611f42565b506040828101518252606083015160208301908152910161030c565b5f818353505060010190565b5f61030c835f01518460200151611fc28660400151610dea565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b6120036127e1565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b61208360405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156120af576120af613135565b6040519080825280602002602001820160405280156120ff57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816120cd5790505b5060208401525f5b8161ffff1681101561214a5761211c83612460565b8560200151838151811061213257612132613c01565b60209081029190910101919091529250600101612107565b5050805160408381019190915260208201516060840152919391019150565b5f5f61217b83602001515f01516124f8565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff90921690820152606090209091506121d9845f01516121c4575f6121c7565b60015b60ff16825f9182526020526040902090565b949350505050565b60e15f5b82518110156122255782818151811061220057612200613c01565b6020026020010151602001515f015151602002600c01820191508060010190506121e5565b50919050565b5f825184511461224e57604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461227057604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b90830190815260268301611ef7565b8051825260208082015181840152604080830180515160d01b82860152805190920151604685015290510151606683019081526086830161030c565b805160601b82525f60148301602083015160601b815290506014810161030c565b61231f6127e1565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c60408201526026820180516046840161203d565b612367612815565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610295825f015165ffffffffffff165f1b836020015160028111156123d1576123d1612970565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f60068301905061243d81836020015160028111156107ba576107ba612970565b6040830151606090811b825280840151901b60148201908152915060280161030c565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c8060028111156124a9576124a9612970565b836020019060028111156124bf576124bf612970565b908160028111156124d2576124d2612970565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f9080820361251857505f516020613c165f395f51905f5292915050565b8060010361254e5761030c815f1b845f8151811061253857612538613c01565b60200260200101515f9182526020526040902090565b806002036125ab5761030c815f1b845f8151811061256e5761256e613c01565b60200260200101518560018151811061258957612589613c01565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b8281101561260c5761260382826001018784815181106125ec576125ec613c01565b602002602001015160019190910160051b82015290565b506001016125ca565b50805160051b60208201206121d98280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff168152602001612654612815565b815260200161268460405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b81526020016126a2604080518082019091525f808252602082015290565b905290565b60405180606001604052806126ba6127e1565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160c0810182525f8082526020828101829052928201819052606082018190526080820181905260a082015291015290565b6040518060e001604052805f65ffffffffffff1681526020016127666040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b8152602001606081526020016127a060405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b8152602001606081526020016127d560405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f81526020016126a260405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60a0828403128015612866575f5ffd5b509092915050565b5f60c08284031215612225575f5ffd5b5f60c0828403121561288e575f5ffd5b61030c838361286e565b5f602082840312156128a8575f5ffd5b81356001600160401b038111156128bd575f5ffd5b8201610200818503121561030c575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f5f60208385031215612915575f5ffd5b82356001600160401b0381111561292a575f5ffd5b8301601f8101851361293a575f5ffd5b80356001600160401b0381111561294f575f5ffd5b856020828401011115612960575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f6080830160ff835116845260208301516080602086015281815180845260a0870191506020830193505f92505b80831015612a2c57835165ffffffffffff81511683526020810151600381106129e957634e487b7160e01b5f52602160045260245ffd5b8060208501525060018060a01b03604082015116604084015260018060a01b036060820151166060840152506080820191506020840193506001830192506129b2565b50604085015160408701526060850151606087015280935050505092915050565b6020815265ffffffffffff82511660208201525f6020830151612aa360408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612abf610140840182612984565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015265ffffffffffff60608201511660608301526080810151608083015260a081015160a08301525050565b60208152612bb5602082018351612aef565b6020828101516101a060e0840152805165ffffffffffff166101c0840152808201516101e0840152604081015160ff16610200840152606001516080610220840152805161024084018190525f929190910190610260600582901b850181019190850190845b81811015612cc15786840361025f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612c865783518252602082019150602084019350600183019250612c63565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612c1b565b505050604085015191506121d9610100850183612b49565b5f60608284031215612225575f5ffd5b5f60608284031215612cf9575f5ffd5b61030c8383612cd9565b5f5f83601f840112612d13575f5ffd5b5081356001600160401b03811115612d29575f5ffd5b6020830191508360208260061b8501011115612d43575f5ffd5b9250929050565b5f5f5f5f60408587031215612d5d575f5ffd5b84356001600160401b03811115612d72575f5ffd5b8501601f81018713612d82575f5ffd5b80356001600160401b03811115612d97575f5ffd5b87602060a083028401011115612dab575f5ffd5b6020918201955093508501356001600160401b03811115612dca575f5ffd5b612dd687828801612d03565b95989497509550505050565b5f60208284031215612df2575f5ffd5b81356001600160401b03811115612e07575f5ffd5b8201610120818503121561030c575f5ffd5b5f8151808452602084019350602083015f5b82811015612e5457612e3e868351612aef565b60c0959095019460209190910190600101612e2b565b5093949350505050565b5f82825180855260208501945060208160051b830101602085015f5b83811015612eac57601f19858403018852612e96838351612984565b6020988901989093509190910190600101612e7a565b50909695505050505050565b6020815265ffffffffffff82511660208201525f6020830151612ede6040840182612b49565b506040830151610200610100840152612efb610220840182612e19565b6060850151805161ffff9081166101208701526020820151166101408601526040015162ffffff166101608501526080850151848203601f1901610180860152909150612f488282612e5e565b60a0860151805165ffffffffffff166101a087015260208101516101c0870152604001516101e086015260c086015160ff81166102008701529092509050612ae7565b5f60808284031215612225575f5ffd5b5f60208284031215612fab575f5ffd5b81356001600160401b03811115612fc0575f5ffd5b6121d984828501612f8b565b5f60208284031215612fdc575f5ffd5b81356001600160401b03811115612ff1575f5ffd5b82016101a0818503121561030c575f5ffd5b5f60208284031215613013575f5ffd5b81356001600160401b03811115613028575f5ffd5b6121d984828501612cd9565b602081525f82516060602084015261304f6080840182612e19565b602085810151601f19868403016040870152805180845290820193505f92909101905b808310156130c55783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a082019150602084019350600183019250613072565b506040860151858203601f19016060870152805180835260209182019450910191505f905b8082101561312a5761311383855180516001600160a01b03908116835260209182015116910152565b6040830192506020840193506001820191506130ea565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b038111828210171561316b5761316b613135565b60405290565b60405160c081016001600160401b038111828210171561316b5761316b613135565b604051608081016001600160401b038111828210171561316b5761316b613135565b60405160e081016001600160401b038111828210171561316b5761316b613135565b604080519081016001600160401b038111828210171561316b5761316b613135565b604051601f8201601f191681016001600160401b038111828210171561322157613221613135565b604052919050565b803565ffffffffffff8116811461323e575f5ffd5b919050565b5f60608284031215613253575f5ffd5b61325b613149565b905061326682613229565b81526020828101359082015260409182013591810191909152919050565b5f60a08284031215613294575f5ffd5b61329c613149565b823581526020808401359082015290506132b98360408401613243565b604082015292915050565b5f60a082840312156132d4575f5ffd5b61030c8383613284565b5f60c082840312156132ee575f5ffd5b6132f6613171565b905061330182613229565b815261330f60208301613229565b602082015261332060408301613229565b604082015261333160608301613229565b60608201526080828101359082015260a09182013591810191909152919050565b5f60c08284031215613362575f5ffd5b61030c83836132de565b5f6001600160401b0382111561338457613384613135565b5060051b60200190565b80356001600160a01b038116811461323e575f5ffd5b5f60c082840312156133b4575f5ffd5b6133bc613171565b90506133c782613229565b81526133d560208301613229565b60208201526133e660408301613229565b60408201526133316060830161338e565b5f82601f830112613406575f5ffd5b81356134196134148261336c565b6131f9565b80828252602082019150602060c0840286010192508583111561343a575f5ffd5b602085015b838110156134615761345187826133a4565b835260209092019160c00161343f565b5095945050505050565b803561ffff8116811461323e575f5ffd5b803562ffffff8116811461323e575f5ffd5b5f6060828403121561349e575f5ffd5b6134a6613149565b90506134b18261346b565b81526134bf6020830161346b565b60208201526132b96040830161347c565b803560ff8116811461323e575f5ffd5b5f608082840312156134f0575f5ffd5b6134f8613193565b9050613503826134d0565b815260208201356001600160401b0381111561351d575f5ffd5b8201601f8101841361352d575f5ffd5b803561353b6134148261336c565b8082825260208201915060208360071b85010192508683111561355c575f5ffd5b6020840193505b828410156135d9576080848803121561357a575f5ffd5b613582613193565b61358b85613229565b815260208501356003811061359e575f5ffd5b60208201526135af6040860161338e565b60408201526135c06060860161338e565b6060820152825260809390930192602090910190613563565b60208501525050506040828101359082015260609182013591810191909152919050565b5f82601f83011261360c575f5ffd5b813561361a6134148261336c565b8082825260208201915060208360051b86010192508583111561363b575f5ffd5b602085015b838110156134615780356001600160401b0381111561365d575f5ffd5b61366c886020838a01016134e0565b84525060209283019201613640565b5f610200823603121561368c575f5ffd5b6136946131b5565b61369d83613229565b81526136ac36602085016132de565b602082015260e08301356001600160401b038111156136c9575f5ffd5b6136d5368286016133f7565b6040830152506136e936610100850161348e565b60608201526101608301356001600160401b03811115613707575f5ffd5b613713368286016135fd565b608083015250613727366101808501613243565b60a08201526137396101e084016134d0565b60c082015292915050565b5f60608284031215613754575f5ffd5b61030c8383613243565b5f6040828403121561376e575f5ffd5b6137766131d7565b90506137818261338e565b815261378f6020830161338e565b602082015292915050565b5f604082840312156137aa575f5ffd5b61030c838361375e565b5f61012082360312156137c5575f5ffd5b6137cd613193565b6137d683613229565b81526137e53660208501613284565b602082015260c08301356001600160401b03811115613802575f5ffd5b61380e368286016134e0565b6040830152506138213660e0850161375e565b606082015292915050565b5f60c0828403121561383c575f5ffd5b61030c83836133a4565b5f60808284031215613856575f5ffd5b61385e613193565b905061386982613229565b815260208281013590820152613881604083016134d0565b604082015260608201356001600160401b0381111561389e575f5ffd5b8201601f810184136138ae575f5ffd5b80356138bc6134148261336c565b8082825260208201915060208360051b8501019250868311156138dd575f5ffd5b602084015b83811015613a235780356001600160401b038111156138ff575f5ffd5b85016040818a03601f19011215613914575f5ffd5b61391c6131d7565b6020820135801515811461392e575f5ffd5b815260408201356001600160401b03811115613948575f5ffd5b6020818401019250506060828b031215613960575f5ffd5b613968613149565b82356001600160401b0381111561397d575f5ffd5b8301601f81018c1361398d575f5ffd5b803561399b6134148261336c565b8082825260208201915060208360051b85010192508e8311156139bc575f5ffd5b6020840193505b828410156139de5783358252602093840193909101906139c3565b8452506139f09150506020840161347c565b6020820152613a0160408401613229565b60408201528060208301525080855250506020830192506020810190506138e2565b5060608501525091949350505050565b5f6102953683613846565b5f6101a08236031215613a4f575f5ffd5b613a57613149565b613a6136846133a4565b815260c08301356001600160401b03811115613a7b575f5ffd5b613a8736828601613846565b6020830152506132b93660e085016132de565b5f82601f830112613aa9575f5ffd5b8135613ab76134148261336c565b8082825260208201915060208360061b860101925085831115613ad8575f5ffd5b602085015b8381101561346157613aef878261375e565b8352602090920191604001613add565b5f60608236031215613b0f575f5ffd5b613b17613149565b82356001600160401b03811115613b2c575f5ffd5b613b38368286016133f7565b82525060208301356001600160401b03811115613b53575f5ffd5b830136601f820112613b63575f5ffd5b8035613b716134148261336c565b80828252602082019150602060a08402850101925036831115613b92575f5ffd5b6020840193505b82841015613bbe57613bab3685613284565b825260208201915060a084019350613b99565b602085015250505060408301356001600160401b03811115613bde575f5ffd5b613bea36828601613a9a565b60408301525092915050565b5f61029536836134e0565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a2646970667358221220d2dfe9cde85c83476731e9265ef6898e0fee33a8545c454b07dd77c3584e3f9664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80c\x8Fm\x0E\x1A\x11a\0\x93W\x80c\xD7q\xD3\x98\x11a\0cW\x80c\xD7q\xD3\x98\x14a\x02\x0CW\x80c\xDCZ\x8B\xF8\x14a\x02\x1FW\x80c\xED\xBA\xCDD\x14a\x022W\x80c\xEE\xDE\xC1\x02\x14a\x02RW__\xFD[\x80c\x8Fm\x0E\x1A\x14a\x01\xB3W\x80c\xA1\xEC\x933\x14a\x01\xC6W\x80c\xAF\xB6:\xD4\x14a\x01\xD9W\x80c\xB8\xB0.\x0E\x14a\x01\xF9W__\xFD[\x80c&09b\x11a\0\xCEW\x80c&09b\x14a\x01MW\x80c]'\xCC\x95\x14a\x01mW\x80cy\x89\xAA\x10\x14a\x01\x8DW\x80cz\x9AU*\x14a\x01\xA0W__\xFD[\x80c\x1F9pg\x14a\0\xF4W\x80c\x1F\xE0j\xB4\x14a\x01\x1AW\x80c&\x1B\xF64\x14a\x01-W[__\xFD[a\x01\x07a\x01\x026`\x04a(UV[a\x02}V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x07a\x01(6`\x04a(~V[a\x02\x9BV[a\x01@a\x01;6`\x04a(\x98V[a\x02\xB3V[`@Qa\x01\x11\x91\x90a(\xCFV[a\x01`a\x01[6`\x04a)\x04V[a\x02\xC6V[`@Qa\x01\x11\x91\x90a*MV[a\x01\x80a\x01{6`\x04a)\x04V[a\x03\x13V[`@Qa\x01\x11\x91\x90a+\xA3V[a\x01\x07a\x01\x9B6`\x04a,\xE9V[a\x03YV[a\x01\x07a\x01\xAE6`\x04a-JV[a\x03qV[a\x01@a\x01\xC16`\x04a-\xE2V[a\x04'V[a\x01\x07a\x01\xD46`\x04a(~V[a\x04:V[a\x01\xECa\x01\xE76`\x04a)\x04V[a\x04RV[`@Qa\x01\x11\x91\x90a.\xB8V[a\x01\x07a\x02\x076`\x04a/\x9BV[a\x04\x98V[a\x01@a\x02\x1A6`\x04a/\xCCV[a\x04\xAAV[a\x01@a\x02-6`\x04a0\x03V[a\x04\xBDV[a\x02Ea\x02@6`\x04a)\x04V[a\x04\xD0V[`@Qa\x01\x11\x91\x90a04V[a\x02ea\x02`6`\x04a/\x9BV[a\x052V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x11V[_a\x02\x95a\x02\x906\x84\x90\x03\x84\x01\x84a2\xC4V[a\x05DV[\x92\x91PPV[_a\x02\x95a\x02\xAE6\x84\x90\x03\x84\x01\x84a3RV[a\x05xV[``a\x02\x95a\x02\xC1\x83a6{V[a\x05\xD3V[a\x02\xCEa&3V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08\x06\x92PPPV[\x93\x92PPPV[a\x03\x1Ba&\xA7V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\n\xB8\x92PPPV[_a\x02\x95a\x03l6\x84\x90\x03\x84\x01\x84a7DV[a\r\xEAV[_a\x04\x1E\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xC2Wa\x03\xB3`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a2\xC4V[\x81R` \x01\x90`\x01\x01\x90a\x03\x96V[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04\x14Wa\x04\x05`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a7\x9AV[\x81R` \x01\x90`\x01\x01\x90a\x03\xE8V[PPPPPa\x0E\x1BV[\x95\x94PPPPPV[``a\x02\x95a\x045\x83a7\xB4V[a\x0F\xD2V[_a\x02\x95a\x04M6\x84\x90\x03\x84\x01\x84a8,V[a\x11\xE9V[a\x04Za'\x16V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x12`\x92PPPV[_a\x02\x95a\x04\xA5\x83a:3V[a\x14\xBAV[``a\x02\x95a\x04\xB8\x83a:>V[a\x16*V[``a\x02\x95a\x04\xCB\x83a:\xFFV[a\x18\xECV[a\x04\xF4`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x03\x0C\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1AQ\x92PPPV[_a\x02\x95a\x05?\x83a;\xF6V[a\x1C\xC0V[_a\x02\x95\x82_\x01Q\x83` \x01Qa\x05^\x85`@\x01Qa\r\xEAV[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q``\x80\x87\x01Q`\x80\x80\x89\x01Q`\xA0\x80\x8B\x01Q\x87Qe\xFF\xFF\xFF\xFF\xFF\xFF\x9B\x8C\x16\x81R\x98\x8B\x16\x99\x89\x01\x99\x90\x99R\x94\x89\x16\x95\x87\x01\x95\x90\x95R\x96\x16\x90\x84\x01R\x93\x82\x01R\x91\x82\x01R`\xC0\x90 _\x90a\x02\x95V[``_a\x05\xED\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa\x1E\x11V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x07Wa\x06\x07a15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x061W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x90\x92\x1B`2\x84\x01R\x80Q`\x80\x01Q`8\x84\x01RQ`\xA0\x01Q`X\x83\x01R\x84\x01QQ\x90\x92P`x\x83\x01\x90a\x06\x96\x90a\x1E\x9CV[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x06\xE4Wa\x06\xDA\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x06\xCDWa\x06\xCDa<\x01V[` \x02` \x01\x01Qa\x1E\xC2V[\x91P`\x01\x01a\x06\xA6V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x07\"\x90a\x1E\x9CV[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x07pWa\x07f\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x07YWa\x07Ya<\x01V[` \x02` \x01\x01Qa\x1F\x14V[\x91P`\x01\x01a\x072V[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x07\x94WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x07\xA6WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x07\xBF\x82\x82a\x07\xB8W`\x01a\x1F\x9CV[_[a\x1F\x9CV[\x91P\x80a\x07\xEEW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x07\xFC\x82\x86`\xC0\x01Qa\x1F\x9CV[\x91PPPP\x91\x90PV[a\x08\x0Ea&3V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xD5Wa\x08\xD5a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t%W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x08\xF3W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xB0W\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t`Wa\t`a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xA7W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xBCWa\t\xBCa)pV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\xD6Wa\t\xD6a<\x01V[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\t\xF3Wa\t\xF3a)pV[\x90\x81`\x02\x81\x11\x15a\n\x06Wa\n\x06a)pV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n,Wa\n,a<\x01V[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\nd\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n~Wa\n~a<\x01V[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\t1V[PPP\x91\x90PV[a\n\xC0a&\xA7V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0BNWa\x0BNa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0B\xB1W\x81` \x01[a\x0B\x9E`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x0BlW\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\r\x7FW\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0B\xF8Wa\x0B\xF8a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0C+Wa\x0C+a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0CTW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0CoWa\x0Coa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0C\xE4W\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0C\xACWa\x0C\xACa<\x01V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0C\xCCWa\x0C\xCCa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0C\x80V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\r\x08Wa\r\x08a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\rJWa\rJa<\x01V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0B\xBDV[PP\x80Q\x82Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x83\x01Q\x84Q`\xA0\x90\x81\x01\x91\x90\x91R`@\x80\x85\x01Q\x81\x87\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x87\x01Q\x81Q\x90\x83\x1C\x95\x01\x94\x90\x94R`L\x86\x01Q\x84Q\x91\x1C\x91\x01R`R\x84\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`r\x90\x92\x01Q\x91Q\x01R\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x95V[_\x81Q\x83Q\x14a\x0E>W`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x0E^W_Q` a<\x16_9_Q\x90_R\x91PPa\x02\x95V[\x80`\x01\x03a\x0E\xC1W_a\x0E\xA3\x85_\x81Q\x81\x10a\x0E|Wa\x0E|a<\x01V[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[` \x02` \x01\x01Qa\x1F\xA8V[\x90Pa\x0E\xB8\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x95V[\x80`\x02\x03a\x0F5W_a\x0E\xDF\x85_\x81Q\x81\x10a\x0E|Wa\x0E|a<\x01V[\x90P_a\x0F\x13\x86`\x01\x81Q\x81\x10a\x0E\xF8Wa\x0E\xF8a<\x01V[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x95V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x0F\xABWa\x0F\xA2\x82\x82`\x01\x01a\x0F\x93\x89\x85\x81Q\x81\x10a\x0FyWa\x0Fya<\x01V[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x0E\x96Wa\x0E\x96a<\x01V[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x0FTV[P\x80Q`\x05\x1B` \x82\x01 a\x04\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0F\xFDWa\x0F\xFDa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x10'W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x10\x8F\x90\x82\x90a\x1F\x9CV[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x10\xDB\x90a\x1E\x9CV[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xB0Wa\x114\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\x1EWa\x11\x1Ea<\x01V[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x11q\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11TWa\x11Ta<\x01V[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x07\xBAWa\x07\xBAa)pV[\x91Pa\x11\xA8\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\x91Wa\x11\x91a<\x01V[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x11\xDF\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x11\xC8Wa\x11\xC8a<\x01V[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x10\xEFV[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x03\x0C\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x12ha'\x16V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x91\x1C`@\x90\x91\x01R`8\x83\x01Q\x81Q`\x80\x01R`X\x83\x01Q\x90Q`\xA0\x01R`x\x82\x01Q`z\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12\xDFWa\x12\xDFa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x13\x18W\x81` \x01[a\x13\x05a'\xE1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x12\xFDW\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x13cWa\x135\x83a\x1F\xFBV[\x85`@\x01Q\x83\x81Q\x81\x10a\x13KWa\x13Ka<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x13 V[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x13\xBCWa\x13\xBCa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x14\x18W\x81` \x01[a\x14\x05`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x13\xDAW\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x14cWa\x145\x84a XV[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x14KWa\x14Ka<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x14 V[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x14\xA8W\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x15\x03W_Q` a<\x16_9_Q\x90_R\x91Pa\x16\tV[\x80`\x01\x03a\x15LWa\x15E\x81_\x1Ba\x157\x87``\x01Q_\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[` \x02` \x01\x01Qa!iV[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x16\tV[\x80`\x02\x03a\x15\x8DWa\x15E\x81_\x1Ba\x15s\x87``\x01Q_\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[a\x05^\x88``\x01Q`\x01\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x15\xDEWa\x15\xD5\x82\x82`\x01\x01a\x0F\x93\x8A``\x01Q\x85\x81Q\x81\x10a\x15*Wa\x15*a<\x01V[P`\x01\x01a\x15\xACV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x16\x07\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x16>\x83` \x01Q``\x01Qa!\xE1V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16XWa\x16Xa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x16\x82W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x16\xED\x90\x82\x90a\x1F\x9CV[` \x85\x01Q``\x01QQ\x90\x91Pa\x17\x03\x81a\x1E\x9CV[a\x17\x13\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x18\x85Wa\x17Y\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x17=Wa\x17=a<\x01V[` \x02` \x01\x01Q_\x01Qa\x17RW_a\x1F\x9CV[`\x01a\x1F\x9CV[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x17vWa\x17va<\x01V[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x17\x91\x81a\x1E\x9CV[a\x17\xA1\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x18\x05Wa\x17\xFB\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x17\xCBWa\x17\xCBa<\x01V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x17\xEBWa\x17\xEBa<\x01V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x17\xA5V[Pa\x18?\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x18$Wa\x18$a<\x01V[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x18z\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x18_Wa\x18_a<\x01V[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x17\x17V[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R`@\x80\x89\x01\x80QQ`\xD0\x90\x81\x1B\x83\x89\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x88\x01R\x80Q\x90\x91\x01Q\x90\x91\x1B`L\x86\x01R\x80Q\x90\x92\x01Q`R\x85\x01R\x90Q\x01Q`r\x83\x01\x90\x81R\x91`\x92\x01a\x07\xFCV[``_a\x19\x05\x83_\x01Q\x84` \x01Q\x85`@\x01Qa\"+V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x1FWa\x19\x1Fa15V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x19IW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x19^\x90a\x1E\x9CV[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x19\xA5Wa\x19\x9B\x82\x86_\x01Q\x83\x81Q\x81\x10a\x19\x8EWa\x19\x8Ea<\x01V[` \x02` \x01\x01Qa\"\x80V[\x91P`\x01\x01a\x19kV[Pa\x19\xB4\x84` \x01QQa\x1E\x9CV[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x1A\x02Wa\x19\xF8\x82\x86` \x01Q\x83\x81Q\x81\x10a\x19\xEBWa\x19\xEBa<\x01V[` \x02` \x01\x01Qa\"\xBAV[\x91P`\x01\x01a\x19\xC4V[Pa\x1A\x11\x84`@\x01QQa\x1E\x9CV[_[\x84`@\x01QQ\x81\x10\x15a\n\xB0Wa\x1AG\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1A:Wa\x1A:a<\x01V[` \x02` \x01\x01Qa\"\xF6V[\x91P`\x01\x01a\x1A\x13V[a\x1Au`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\x9AWa\x1A\x9Aa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1A\xD3W\x81` \x01[a\x1A\xC0a'\xE1V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1A\xB8W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\x19Wa\x1A\xED\x83a#\x17V[\x85Q\x80Q\x84\x90\x81\x10a\x1B\x01Wa\x1B\x01a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1A\xD8V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1BIW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1BeWa\x1Bea15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1B\x9EW\x81` \x01[a\x1B\x8Ba(\x15V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1B\x83W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\xE9Wa\x1B\xBB\x84a#_V[\x86` \x01Q\x83\x81Q\x81\x10a\x1B\xD1Wa\x1B\xD1a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1B\xA6V[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x06Wa\x1C\x06a15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1CJW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1C$W\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1C\xB7W`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1C\x9FWa\x1C\x9Fa<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1CRV[PPPP\x91\x90PV[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1C\xE6W_Q` a<\x16_9_Q\x90_R\x91Pa\x1D\xDEV[\x80`\x01\x03a\x1D!Wa\x1D\x1A\x81_\x1Ba\x157\x86` \x01Q_\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[` \x02` \x01\x01Qa#\xA9V[\x91Pa\x1D\xDEV[\x80`\x02\x03a\x1DbWa\x1D\x1A\x81_\x1Ba\x1DH\x86` \x01Q_\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[a\x05^\x87` \x01Q`\x01\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1D\xB3Wa\x1D\xAA\x82\x82`\x01\x01a\x0F\x93\x89` \x01Q\x85\x81Q\x81\x10a\x1D\rWa\x1D\ra<\x01V[P`\x01\x01a\x1D\x81V[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1D\xDC\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x04\x1EV[\x80Q`e\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x1E/WP` \x83\x01Q\x15[\x80\x15a\x1E=WP`@\x83\x01Q\x15[\x90P\x80a\x1EKW`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a\x1E\x93W\x84\x81\x81Q\x81\x10a\x1EqWa\x1Eqa<\x01V[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa\x1EVV[PP\x93\x92PPPV[a\xFF\xFF\x81\x11\x15a\x1E\xBFW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x03\x0CV[_a\x1F\"\x83\x83_\x01Qa\x1F\x9CV[\x90Pa\x1F2\x82` \x01QQa\x1E\x9CV[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\x1F\x80Wa\x1Fv\x82\x84` \x01Q\x83\x81Q\x81\x10a\x1FiWa\x1Fia<\x01V[` \x02` \x01\x01Qa$\x15V[\x91P`\x01\x01a\x1FBV[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x03\x0CV[_\x81\x83SPP`\x01\x01\x90V[_a\x03\x0C\x83_\x01Q\x84` \x01Qa\x1F\xC2\x86`@\x01Qa\r\xEAV[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[a \x03a'\xE1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a \x83`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a \xAFWa \xAFa15V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a \xFFW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a \xCDW\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a!JWa!\x1C\x83a$`V[\x85` \x01Q\x83\x81Q\x81\x10a!2Wa!2a<\x01V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a!\x07V[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a!{\x83` \x01Q_\x01Qa$\xF8V[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa!\xD9\x84_\x01Qa!\xC4W_a!\xC7V[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[`\xE1_[\x82Q\x81\x10\x15a\"%W\x82\x81\x81Q\x81\x10a\"\0Wa\"\0a<\x01V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa!\xE5V[P\x91\x90PV[_\x82Q\x84Q\x14a\"NW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a\"pW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a\x1E\xF7V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x03\x0CV[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x03\x0CV[a#\x1Fa'\xE1V[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a =V[a#ga(\x15V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x95\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a#\xD1Wa#\xD1a)pV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa$=\x81\x83` \x01Q`\x02\x81\x11\x15a\x07\xBAWa\x07\xBAa)pV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x03\x0CV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a$\xA9Wa$\xA9a)pV[\x83` \x01\x90`\x02\x81\x11\x15a$\xBFWa$\xBFa)pV[\x90\x81`\x02\x81\x11\x15a$\xD2Wa$\xD2a)pV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a%\x18WP_Q` a<\x16_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a%NWa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a%8Wa%8a<\x01V[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a%\xABWa\x03\x0C\x81_\x1B\x84_\x81Q\x81\x10a%nWa%na<\x01V[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a%\x89Wa%\x89a<\x01V[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a&\x0CWa&\x03\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a%\xECWa%\xECa<\x01V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a%\xCAV[P\x80Q`\x05\x1B` \x82\x01 a!\xD9\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a&Ta(\x15V[\x81R` \x01a&\x84`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a&\xA2`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80``\x01`@R\x80a&\xBAa'\xE1V[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01\x81\x90R`\xA0\x82\x01R\x91\x01R\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a'f`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a'\xA0`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a'\xD5`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a&\xA2`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a(fW__\xFD[P\x90\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a\"%W__\xFD[_`\xC0\x82\x84\x03\x12\x15a(\x8EW__\xFD[a\x03\x0C\x83\x83a(nV[_` \x82\x84\x03\x12\x15a(\xA8W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a(\xBDW__\xFD[\x82\x01a\x02\0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[__` \x83\x85\x03\x12\x15a)\x15W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a)*W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a):W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a)OW__\xFD[\x85` \x82\x84\x01\x01\x11\x15a)`W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_`\x80\x83\x01`\xFF\x83Q\x16\x84R` \x83\x01Q`\x80` \x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P` \x83\x01\x93P_\x92P[\x80\x83\x10\x15a*,W\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x83R` \x81\x01Q`\x03\x81\x10a)\xE9WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x80` \x85\x01RP`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa)\xB2V[P`@\x85\x01Q`@\x87\x01R``\x85\x01Q``\x87\x01R\x80\x93PPPP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa*\xA3`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra*\xBFa\x01@\x84\x01\x82a)\x84V[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[` \x81Ra+\xB5` \x82\x01\x83Qa*\xEFV[` \x82\x81\x01Qa\x01\xA0`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xC0\x84\x01R\x80\x82\x01Qa\x01\xE0\x84\x01R`@\x81\x01Q`\xFF\x16a\x02\0\x84\x01R``\x01Q`\x80a\x02 \x84\x01R\x80Qa\x02@\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02``\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a,\xC1W\x86\x84\x03a\x02_\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a,\x86W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa,cV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a,\x1BV[PPP`@\x85\x01Q\x91Pa!\xD9a\x01\0\x85\x01\x83a+IV[_``\x82\x84\x03\x12\x15a\"%W__\xFD[_``\x82\x84\x03\x12\x15a,\xF9W__\xFD[a\x03\x0C\x83\x83a,\xD9V[__\x83`\x1F\x84\x01\x12a-\x13W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-)W__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a-CW__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a-]W__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a-rW__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a-\x82W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x97W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a-\xABW__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xCAW__\xFD[a-\xD6\x87\x82\x88\x01a-\x03V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a-\xF2W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a.\x07W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a.TWa.>\x86\x83Qa*\xEFV[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a.+V[P\x93\x94\x93PPPPV[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a.\xACW`\x1F\x19\x85\x84\x03\x01\x88Ra.\x96\x83\x83Qa)\x84V[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a.zV[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa.\xDE`@\x84\x01\x82a+IV[P`@\x83\x01Qa\x02\0a\x01\0\x84\x01Ra.\xFBa\x02 \x84\x01\x82a.\x19V[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01 \x87\x01R` \x82\x01Q\x16a\x01@\x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01`\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01\x80\x86\x01R\x90\x91Pa/H\x82\x82a.^V[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x87\x01R` \x81\x01Qa\x01\xC0\x87\x01R`@\x01Qa\x01\xE0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x02\0\x87\x01R\x90\x92P\x90Pa*\xE7V[_`\x80\x82\x84\x03\x12\x15a\"%W__\xFD[_` \x82\x84\x03\x12\x15a/\xABW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xC0W__\xFD[a!\xD9\x84\x82\x85\x01a/\x8BV[_` \x82\x84\x03\x12\x15a/\xDCW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xF1W__\xFD[\x82\x01a\x01\xA0\x81\x85\x03\x12\x15a\x03\x0CW__\xFD[_` \x82\x84\x03\x12\x15a0\x13W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0(W__\xFD[a!\xD9\x84\x82\x85\x01a,\xD9V[` \x81R_\x82Q``` \x84\x01Ra0O`\x80\x84\x01\x82a.\x19V[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a0\xC5W\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa0rV[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a1*Wa1\x13\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa0\xEAV[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@R\x90V[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1kWa1ka15V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a2!Wa2!a15V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a2SW__\xFD[a2[a1IV[\x90Pa2f\x82a2)V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a2\x94W__\xFD[a2\x9Ca1IV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa2\xB9\x83`@\x84\x01a2CV[`@\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a2\xD4W__\xFD[a\x03\x0C\x83\x83a2\x84V[_`\xC0\x82\x84\x03\x12\x15a2\xEEW__\xFD[a2\xF6a1qV[\x90Pa3\x01\x82a2)V[\x81Ra3\x0F` \x83\x01a2)V[` \x82\x01Ra3 `@\x83\x01a2)V[`@\x82\x01Ra31``\x83\x01a2)V[``\x82\x01R`\x80\x82\x81\x015\x90\x82\x01R`\xA0\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a3bW__\xFD[a\x03\x0C\x83\x83a2\xDEV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a3\x84Wa3\x84a15V[P`\x05\x1B` \x01\x90V[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a2>W__\xFD[_`\xC0\x82\x84\x03\x12\x15a3\xB4W__\xFD[a3\xBCa1qV[\x90Pa3\xC7\x82a2)V[\x81Ra3\xD5` \x83\x01a2)V[` \x82\x01Ra3\xE6`@\x83\x01a2)V[`@\x82\x01Ra31``\x83\x01a3\x8EV[_\x82`\x1F\x83\x01\x12a4\x06W__\xFD[\x815a4\x19a4\x14\x82a3lV[a1\xF9V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a4:W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aWa4Q\x87\x82a3\xA4V[\x83R` \x90\x92\x01\x91`\xC0\x01a4?V[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a2>W__\xFD[_``\x82\x84\x03\x12\x15a4\x9EW__\xFD[a4\xA6a1IV[\x90Pa4\xB1\x82a4kV[\x81Ra4\xBF` \x83\x01a4kV[` \x82\x01Ra2\xB9`@\x83\x01a4|V[\x805`\xFF\x81\x16\x81\x14a2>W__\xFD[_`\x80\x82\x84\x03\x12\x15a4\xF0W__\xFD[a4\xF8a1\x93V[\x90Pa5\x03\x82a4\xD0V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5\x1DW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a5-W__\xFD[\x805a5;a4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a5\\W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a5\xD9W`\x80\x84\x88\x03\x12\x15a5zW__\xFD[a5\x82a1\x93V[a5\x8B\x85a2)V[\x81R` \x85\x015`\x03\x81\x10a5\x9EW__\xFD[` \x82\x01Ra5\xAF`@\x86\x01a3\x8EV[`@\x82\x01Ra5\xC0``\x86\x01a3\x8EV[``\x82\x01R\x82R`\x80\x93\x90\x93\x01\x92` \x90\x91\x01\x90a5cV[` \x85\x01RPPP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a6\x0CW__\xFD[\x815a6\x1Aa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a6;W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a6]W__\xFD[a6l\x88` \x83\x8A\x01\x01a4\xE0V[\x84RP` \x92\x83\x01\x92\x01a6@V[_a\x02\0\x826\x03\x12\x15a6\x8CW__\xFD[a6\x94a1\xB5V[a6\x9D\x83a2)V[\x81Ra6\xAC6` \x85\x01a2\xDEV[` \x82\x01R`\xE0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a6\xC9W__\xFD[a6\xD56\x82\x86\x01a3\xF7V[`@\x83\x01RPa6\xE96a\x01\0\x85\x01a4\x8EV[``\x82\x01Ra\x01`\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a7\x07W__\xFD[a7\x136\x82\x86\x01a5\xFDV[`\x80\x83\x01RPa7'6a\x01\x80\x85\x01a2CV[`\xA0\x82\x01Ra79a\x01\xE0\x84\x01a4\xD0V[`\xC0\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a7TW__\xFD[a\x03\x0C\x83\x83a2CV[_`@\x82\x84\x03\x12\x15a7nW__\xFD[a7va1\xD7V[\x90Pa7\x81\x82a3\x8EV[\x81Ra7\x8F` \x83\x01a3\x8EV[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a7\xAAW__\xFD[a\x03\x0C\x83\x83a7^V[_a\x01 \x826\x03\x12\x15a7\xC5W__\xFD[a7\xCDa1\x93V[a7\xD6\x83a2)V[\x81Ra7\xE56` \x85\x01a2\x84V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x02W__\xFD[a8\x0E6\x82\x86\x01a4\xE0V[`@\x83\x01RPa8!6`\xE0\x85\x01a7^V[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a8<W__\xFD[a\x03\x0C\x83\x83a3\xA4V[_`\x80\x82\x84\x03\x12\x15a8VW__\xFD[a8^a1\x93V[\x90Pa8i\x82a2)V[\x81R` \x82\x81\x015\x90\x82\x01Ra8\x81`@\x83\x01a4\xD0V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x9EW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a8\xAEW__\xFD[\x805a8\xBCa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a8\xDDW__\xFD[` \x84\x01[\x83\x81\x10\x15a:#W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xFFW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a9\x14W__\xFD[a9\x1Ca1\xD7V[` \x82\x015\x80\x15\x15\x81\x14a9.W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a9HW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a9`W__\xFD[a9ha1IV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a9}W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a9\x8DW__\xFD[\x805a9\x9Ba4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a9\xBCW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a9\xDEW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a9\xC3V[\x84RPa9\xF0\x91PP` \x84\x01a4|V[` \x82\x01Ra:\x01`@\x84\x01a2)V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa8\xE2V[P``\x85\x01RP\x91\x94\x93PPPPV[_a\x02\x956\x83a8FV[_a\x01\xA0\x826\x03\x12\x15a:OW__\xFD[a:Wa1IV[a:a6\x84a3\xA4V[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:{W__\xFD[a:\x876\x82\x86\x01a8FV[` \x83\x01RPa2\xB96`\xE0\x85\x01a2\xDEV[_\x82`\x1F\x83\x01\x12a:\xA9W__\xFD[\x815a:\xB7a4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a:\xD8W__\xFD[` \x85\x01[\x83\x81\x10\x15a4aWa:\xEF\x87\x82a7^V[\x83R` \x90\x92\x01\x91`@\x01a:\xDDV[_``\x826\x03\x12\x15a;\x0FW__\xFD[a;\x17a1IV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a;,W__\xFD[a;86\x82\x86\x01a3\xF7V[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;SW__\xFD[\x83\x016`\x1F\x82\x01\x12a;cW__\xFD[\x805a;qa4\x14\x82a3lV[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a;\x92W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a;\xBEWa;\xAB6\x85a2\x84V[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa;\x99V[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xDEW__\xFD[a;\xEA6\x82\x86\x01a:\x9AV[`@\x83\x01RP\x92\x91PPV[_a\x02\x956\x83a4\xE0V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \xD2\xDF\xE9\xCD\xE8\\\x83Gg1\xE9&^\xF6\x89\x8E\x0F\xEE3\xA8T\\EK\x07\xDDw\xC3XN?\x96dsolcC\0\x08\x1E\x003",
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
    /**Function with signature `encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32)))` and selector `0xd771d398`.
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
    ///Container type for the return parameters of the [`encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32)))`](encodeProposedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,uint48,bytes32,bytes32)))";
            const SELECTOR: [u8; 4] = [215u8, 113u8, 211u8, 152u8];
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
            [143u8, 109u8, 14u8, 26u8],
            [161u8, 236u8, 147u8, 51u8],
            [175u8, 182u8, 58u8, 212u8],
            [184u8, 176u8, 46u8, 14u8],
            [215u8, 113u8, 211u8, 152u8],
            [220u8, 90u8, 139u8, 248u8],
            [237u8, 186u8, 205u8, 68u8],
            [238u8, 222u8, 193u8, 2u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecOptimizedCalls {
        const NAME: &'static str = "CodecOptimizedCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
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
