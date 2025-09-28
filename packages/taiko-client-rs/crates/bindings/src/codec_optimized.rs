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
    struct CoreState { uint48 nextProposalId; uint48 nextProposalBlockId; uint48 lastFinalizedProposalId; bytes32 lastFinalizedTransitionHash; bytes32 bondInstructionsHash; }
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
struct CoreState { uint48 nextProposalId; uint48 nextProposalBlockId; uint48 lastFinalizedProposalId; bytes32 lastFinalizedTransitionHash; bytes32 bondInstructionsHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct CoreState {
        #[allow(missing_docs)]
        pub nextProposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub nextProposalBlockId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastFinalizedProposalId: alloy::sol_types::private::primitives::aliases::U48,
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
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
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
                    value.nextProposalBlockId,
                    value.lastFinalizedProposalId,
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
                    nextProposalBlockId: tuple.1,
                    lastFinalizedProposalId: tuple.2,
                    lastFinalizedTransitionHash: tuple.3,
                    bondInstructionsHash: tuple.4,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.nextProposalBlockId),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.lastFinalizedProposalId,
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
                    "CoreState(uint48 nextProposalId,uint48 nextProposalBlockId,uint48 lastFinalizedProposalId,bytes32 lastFinalizedTransitionHash,bytes32 bondInstructionsHash)",
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
                            &self.nextProposalBlockId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastFinalizedProposalId,
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
                        &rust.nextProposalBlockId,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastFinalizedProposalId,
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
                    &rust.nextProposalBlockId,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastFinalizedProposalId,
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
        uint48 nextProposalBlockId;
        uint48 lastFinalizedProposalId;
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
                "name": "nextProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
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
                "name": "nextProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
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
                "name": "nextProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
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
                "name": "nextProposalBlockId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "lastFinalizedProposalId",
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
            "name": "nextProposalBlockId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "lastFinalizedProposalId",
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
    ///0x6080604052348015600e575f5ffd5b50613c6c8061001c5f395ff3fe608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c80637a9a552a11610093578063b8b02e0e11610063578063b8b02e0e14610210578063dc5a8bf814610223578063edbacd4414610236578063eedec10214610256575f5ffd5b80637a9a552a146101b75780638f6d0e1a146101ca578063a1ec9333146101dd578063afb63ad4146101f0575f5ffd5b80632b41c9ca116100ce5780632b41c9ca1461015e5780635d27cc95146101715780636f8a5cff146101915780637989aa10146101a4575f5ffd5b80630b093b8b146100f45780631f3970671461011d578063263039621461013e575b5f5ffd5b610107610102366004612842565b610281565b6040516101149190612879565b60405180910390f35b61013061012b3660046128be565b61029a565b604051908152602001610114565b61015161014c3660046128d8565b6102b2565b6040516101149190612a21565b61010761016c366004612ac3565b6102ff565b61018461017f3660046128d8565b610312565b6040516101149190612b9c565b61013061019f3660046128be565b610358565b6101306101b2366004612ce2565b610370565b6101306101c5366004612d43565b610388565b6101076101d8366004612ddb565b61043e565b6101306101eb366004612e12565b610451565b6102036101fe3660046128d8565b610469565b6040516101149190612eca565b61013061021e366004612fac565b6104af565b610107610231366004612fdd565b6104c1565b6102496102443660046128d8565b6104d4565b604051610114919061300e565b610269610264366004612fac565b610536565b60405165ffffffffffff199091168152602001610114565b606061029461028f83613558565b610548565b92915050565b5f6102946102ad36849003840184613635565b61080e565b6102ba61262e565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061084292505050565b9392505050565b606061029461030d836138ac565b610af4565b61031a6126a2565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610d1c92505050565b5f61029461036b36849003840184613974565b611046565b5f6102946103833684900384018461398e565b6110a7565b5f6104358585808060200260200160405190810160405280939291908181526020015f905b828210156103d9576103ca60a08302860136819003810190613635565b815260200190600101906103ad565b50505050508484808060200260200160405190810160405280939291908181526020015f905b8282101561042b5761041c604083028601368190038101906139e4565b815260200190600101906103ff565b50505050506110d8565b95945050505050565b606061029461044c836139fe565b61128f565b5f61029461046436849003840184613a76565b6114a6565b61047161270a565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061151d92505050565b5f6102946104bc83613a90565b611777565b60606102946104cf83613b00565b6118e7565b6104f860405180606001604052806060815260200160608152602001606081525090565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611a4c92505050565b5f61029461054383613bf7565b611cbb565b60605f61055c836020015160600151611e0c565b9050806001600160401b038111156105765761057661310f565b6040519080825280601f01601f1916602001820160405280156105a0576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c83019061060b908290611e56565b6020850151606001515190915061062181611e62565b610631828260f01b815260020190565b91505f5b818110156107a45761067883876020015160600151838151811061065b5761065b613c02565b60200260200101515f0151610670575f611e56565b60015b611e56565b92505f866020015160600151828151811061069557610695613c02565b6020026020010151602001515f01515190506106b081611e62565b6106c0848260f01b815260020190565b93505f5b818110156107245761071a8589602001516060015185815181106106ea576106ea613c02565b6020026020010151602001515f0151838151811061070a5761070a613c02565b6020026020010151815260200190565b94506001016106c4565b5061075e84886020015160600151848151811061074357610743613c02565b6020026020010151602001516020015160e81b815260030190565b935061079984886020015160600151848151811061077e5761077e613c02565b6020026020010151602001516040015160d01b815260060190565b935050600101610635565b5084516080908101518352855160a00151602080850191909152604080880180515160d090811b83880152815190930151831b604687015280519091015190911b604c850152805160600151605285015251015160728301908152916092015b9150505050919050565b5f610294825f0151836020015161082885604001516110a7565b604080519384526020840192909252908201526060902090565b61084a61262e565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156109115761091161310f565b60405190808252806020026020018201604052801561096157816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f1990920191018161092f5790505b506040840151602001525f5b8161ffff16811015610aec57825160d01c60068401856040015160200151838151811061099c5761099c613c02565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109e357604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109f8576109f8612944565b8560400151602001518381518110610a1257610a12613c02565b6020026020010151602001906002811115610a2f57610a2f612944565b90816002811115610a4257610a42612944565b905250835160601c601485018660400151602001518481518110610a6857610a68613c02565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610aa084805160601c91601490910190565b8660400151602001518481518110610aba57610aba613c02565b6020026020010151606001819650826001600160a01b03166001600160a01b031681525050505080600101905061096d565b505050919050565b60605f610b0e836040015184608001518560a00151611e88565b9050806001600160401b03811115610b2857610b2861310f565b6040519080825280601f01601f191660200182016040528015610b52576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c840152805160409081015190921b6032840152805160600151603884015251608001516058830152840151519092506078830190610bb790611e62565b60408401515160f01b81526002015f5b846040015151811015610c0557610bfb8286604001518381518110610bee57610bee613c02565b6020026020010151611f13565b9150600101610bc7565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b6004820152608084015151600790910190610c4390611e62565b60808401515160f01b81526002015f5b846080015151811015610c9157610c878286608001518381518110610c7a57610c7a613c02565b6020026020010151611f65565b9150600101610c53565b5060a0840151515f9065ffffffffffff16158015610cb5575060a085015160200151155b8015610cc7575060a085015160400151155b9050610cdf8282610cd9576001611e56565b5f611e56565b915080610d0e5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b610804828660c00151611e56565b610d246126a2565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610db257610db261310f565b604051908082528060200260200182016040528015610e1557816020015b610e026040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610dd05790505b506020840151606001525f5b8161ffff16811015610fe3578251602085015160600151805160019095019460f89290921c91821515919084908110610e5c57610e5c613c02565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610e8f57610e8f61310f565b604051908082528060200260200182016040528015610eb8578160200160208202803683370190505b508660200151606001518481518110610ed357610ed3613c02565b6020908102919091018101510151525f5b8161ffff16811015610f48578551602087018860200151606001518681518110610f1057610f10613c02565b6020026020010151602001515f01518381518110610f3057610f30613c02565b60209081029190910101919091529550600101610ee4565b50845160e81c600386018760200151606001518581518110610f6c57610f6c613c02565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610fae57610fae613c02565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610e21565b505080518251608090810191909152602080830151845160a00152604080840151818601805160d092831c90526046860151815190831c940193909352604c8501518351911c910152605283015181516060015260729092015191510152919050565b5f610294825f015165ffffffffffff165f1b836020015165ffffffffffff165f1b846040015165ffffffffffff165f1b85606001518660800151604080519586526020860194909452928401919091526060830152608082015260a0902090565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610294565b5f81518351146110fb5760405163b1f40f7760e01b815260040160405180910390fd5b82515f81900361111b575f516020613c175f395f51905f52915050610294565b8060010361117e575f611160855f8151811061113957611139613c02565b6020026020010151855f8151811061115357611153613c02565b6020026020010151611fed565b905061117582825f9182526020526040902090565b92505050610294565b806002036111f2575f61119c855f8151811061113957611139613c02565b90505f6111d0866001815181106111b5576111b5613c02565b60200260200101518660018151811061115357611153613c02565b6040805194855260208501939093529183019190915250606090209050610294565b604080516001830181526002830160051b8101909152602081018290525f5b828110156112685761125f828260010161125089858151811061123657611236613c02565b602002602001015189868151811061115357611153613c02565b60019190910160051b82015290565b50600101611211565b50805160051b60208201206104358280516040516001820160051b83011490151060061b52565b60408101516020015151606090602f0260f701806001600160401b038111156112ba576112ba61310f565b6040519080825280601f01601f1916602001820160405280156112e4576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061134c908290611e56565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b6054840152510151516068909101915061139890611e62565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610aec576113f18286604001516020015183815181106113db576113db613c02565b60200260200101515f015160d01b815260060190565b915061142e82866040015160200151838151811061141157611411613c02565b602002602001015160200151600281111561067357610673612944565b915061146582866040015160200151838151811061144e5761144e613c02565b60200260200101516040015160601b815260140190565b915061149c82866040015160200151838151811061148557611485613c02565b60200260200101516060015160601b815260140190565b91506001016113ac565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b90506102f88184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b61152561270a565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c93019290925260328401518251911c604090910152603883015181516060015260588301519051608001526078820151607a83019060f01c806001600160401b0381111561159c5761159c61310f565b6040519080825280602002602001820160405280156115d557816020015b6115c26127ce565b8152602001906001900390816115ba5790505b5060408401525f5b8161ffff16811015611620576115f283612040565b8560400151838151811061160857611608613c02565b602090810291909101019190915292506001016115dd565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156116795761167961310f565b6040519080825280602002602001820160405280156116d557816020015b6116c260405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816116975790505b5060808501525f5b8161ffff16811015611720576116f28461209d565b8660800151838151811061170857611708613c02565b602090810291909101019190915293506001016116dd565b50825160019384019360f89190911c9081900361176557835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f036117c0575f516020613c175f395f51905f5291506118c6565b8060010361180957611802815f1b6117f487606001515f815181106117e7576117e7613c02565b60200260200101516121ae565b5f9182526020526040902090565b91506118c6565b8060020361184a57611802815f1b61183087606001515f815181106117e7576117e7613c02565b61082888606001516001815181106117e7576117e7613c02565b604080516001830181526002830160051b8101909152602081018290525f5b8281101561189b5761189282826001016112508a6060015185815181106117e7576117e7613c02565b50600101611869565b50805160051b602082012092506118c48180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f611900835f015184602001518560400151612226565b9050806001600160401b0381111561191a5761191a61310f565b6040519080825280601f01601f191660200182016040528015611944576020820181803683370190505b50835151909250602083019061195990611e62565b83515160f01b81526002015f5b8451518110156119a05761199682865f0151838151811061198957611989613c02565b602002602001015161227b565b9150600101611966565b506119af846020015151611e62565b60208401515160f01b81526002015f5b8460200151518110156119fd576119f382866020015183815181106119e6576119e6613c02565b60200260200101516122b5565b91506001016119bf565b50611a0c846040015151611e62565b5f5b846040015151811015610aec57611a428286604001518381518110611a3557611a35613c02565b60200260200101516122f1565b9150600101611a0e565b611a7060405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611a9557611a9561310f565b604051908082528060200260200182016040528015611ace57816020015b611abb6127ce565b815260200190600190039081611ab35790505b5083525f5b8161ffff16811015611b1457611ae883612312565b8551805184908110611afc57611afc613c02565b60209081029190910101919091529250600101611ad3565b50815160029092019160f01c61ffff82168114611b4457604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611b6057611b6061310f565b604051908082528060200260200182016040528015611b9957816020015b611b86612802565b815260200190600190039081611b7e5790505b5060208501525f5b8161ffff16811015611be457611bb68461235a565b86602001518381518110611bcc57611bcc613c02565b60209081029190910101919091529350600101611ba1565b508061ffff166001600160401b03811115611c0157611c0161310f565b604051908082528060200260200182016040528015611c4557816020015b604080518082019091525f8082526020820152815260200190600190039081611c1f5790505b5060408501525f5b8161ffff16811015611cb257604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611c9a57611c9a613c02565b60209081029190910101919091529350600101611c4d565b50505050919050565b6020810151515f908190808203611ce1575f516020613c175f395f51905f529150611dd9565b80600103611d1c57611d15815f1b6117f486602001515f81518110611d0857611d08613c02565b60200260200101516123a4565b9150611dd9565b80600203611d5d57611d15815f1b611d4386602001515f81518110611d0857611d08613c02565b6108288760200151600181518110611d0857611d08613c02565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611dae57611da5828260010161125089602001518581518110611d0857611d08613c02565b50600101611d7c565b50805160051b60208201209250611dd78180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f90610435565b60e15f5b8251811015611e5057828181518110611e2b57611e2b613c02565b6020026020010151602001515f015151602002600c0182019150806001019050611e10565b50919050565b5f818353505060010190565b61ffff811115611e855760405163161e7a6b60e11b815260040160405180910390fd5b50565b80516065905f9065ffffffffffff16158015611ea657506020830151155b8015611eb457506040830151155b905080611ec2576046820191505b8451606602820191505f5b8451811015611f0a57848181518110611ee857611ee8613c02565b60200260200101516020015151602f0260430183019250806001019050611ecd565b50509392505050565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a08301516020820190815291506040016102f8565b5f611f7383835f0151611e56565b9050611f83826020015151611e62565b60208201515160f01b81526002015f5b826020015151811015611fd157611fc78284602001518381518110611fba57611fba613c02565b6020026020010151612410565b9150600101611f93565b50604082810151825260608301516020830190815291016102f8565b5f6102f8835f0151846020015161200786604001516110a7565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b6120486127ce565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b6120c860405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156120f4576120f461310f565b60405190808252806020026020018201604052801561214457816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816121125790505b5060208401525f5b8161ffff1681101561218f576121618361245b565b8560200151838151811061217757612177613c02565b6020908102919091010191909152925060010161214c565b5050805160408381019190915260208201516060840152919391019150565b5f5f6121c083602001515f01516124f3565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff909216908201526060902090915061221e845f0151612209575f61220c565b60015b60ff16825f9182526020526040902090565b949350505050565b5f825184511461224957604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461226b57604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b90830190815260268301611f48565b8051825260208082015181840152604080830180515160d01b8286015280519092015160468501529051015160668301908152608683016102f8565b805160601b82525f60148301602083015160601b81529050601481016102f8565b61231a6127ce565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c604082015260268201805160468401612082565b612362612802565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610294825f015165ffffffffffff165f1b836020015160028111156123cc576123cc612944565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f600683019050612438818360200151600281111561067357610673612944565b6040830151606090811b825280840151901b6014820190815291506028016102f8565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c8060028111156124a4576124a4612944565b836020019060028111156124ba576124ba612944565b908160028111156124cd576124cd612944565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f9080820361251357505f516020613c175f395f51905f5292915050565b80600103612549576102f8815f1b845f8151811061253357612533613c02565b60200260200101515f9182526020526040902090565b806002036125a6576102f8815f1b845f8151811061256957612569613c02565b60200260200101518560018151811061258457612584613c02565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b82811015612607576125fe82826001018784815181106125e7576125e7613c02565b602002602001015160019190910160051b82015290565b506001016125c5565b50805160051b602082012061221e8280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff16815260200161264f612802565b815260200161267f60405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815260200161269d604080518082019091525f808252602082015290565b905290565b60405180606001604052806126b56127ce565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160a0810182525f808252602082810182905292820181905260608201819052608082015291015290565b6040518060e001604052805f65ffffffffffff1681526020016127536040805160a0810182525f8082526020820181905291810182905260608101829052608081019190915290565b81526020016060815260200161278d60405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b8152602001606081526020016127c260405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f815260200161269d60405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60208284031215612852575f5ffd5b81356001600160401b03811115612867575f5ffd5b820161018081850312156102f8575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f60a08284031215611e50575f5ffd5b5f60a082840312156128ce575f5ffd5b6102f883836128ae565b5f5f602083850312156128e9575f5ffd5b82356001600160401b038111156128fe575f5ffd5b8301601f8101851361290e575f5ffd5b80356001600160401b03811115612923575f5ffd5b856020828401011115612934575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f6080830160ff835116845260208301516080602086015281815180845260a0870191506020830193505f92505b80831015612a0057835165ffffffffffff81511683526020810151600381106129bd57634e487b7160e01b5f52602160045260245ffd5b8060208501525060018060a01b03604082015116604084015260018060a01b03606082015116606084015250608082019150602084019350600183019250612986565b50604085015160408701526060850151606087015280935050505092915050565b6020815265ffffffffffff82511660208201525f6020830151612a7760408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612a93610140840182612958565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b5f60208284031215612ad3575f5ffd5b81356001600160401b03811115612ae8575f5ffd5b82016101e081850312156102f8575f5ffd5b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260608101516060830152608081015160808301525050565b60208152612bae602082018351612afa565b60208281015161018060e0840152805165ffffffffffff166101a0840152808201516101c0840152604081015160ff166101e0840152606001516080610200840152805161022084018190525f929190910190610240600582901b850181019190850190845b81811015612cba5786840361023f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612c7f5783518252602082019150602084019350600183019250612c5c565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612c14565b5050506040850151915061221e610100850183612b54565b5f60608284031215611e50575f5ffd5b5f60608284031215612cf2575f5ffd5b6102f88383612cd2565b5f5f83601f840112612d0c575f5ffd5b5081356001600160401b03811115612d22575f5ffd5b6020830191508360208260061b8501011115612d3c575f5ffd5b9250929050565b5f5f5f5f60408587031215612d56575f5ffd5b84356001600160401b03811115612d6b575f5ffd5b8501601f81018713612d7b575f5ffd5b80356001600160401b03811115612d90575f5ffd5b87602060a083028401011115612da4575f5ffd5b6020918201955093508501356001600160401b03811115612dc3575f5ffd5b612dcf87828801612cfc565b95989497509550505050565b5f60208284031215612deb575f5ffd5b81356001600160401b03811115612e00575f5ffd5b820161012081850312156102f8575f5ffd5b5f60c0828403128015612e23575f5ffd5b509092915050565b5f8151808452602084019350602083015f5b82811015612e6657612e50868351612afa565b60c0959095019460209190910190600101612e3d565b5093949350505050565b5f82825180855260208501945060208160051b830101602085015f5b83811015612ebe57601f19858403018852612ea8838351612958565b6020988901989093509190910190600101612e8c565b50909695505050505050565b6020815265ffffffffffff82511660208201525f6020830151612ef06040840182612b54565b5060408301516101e060e0840152612f0c610200840182612e2b565b6060850151805161ffff9081166101008701526020820151166101208601526040015162ffffff166101408501526080850151848203601f1901610160860152909150612f598282612e70565b60a0860151805165ffffffffffff1661018087015260208101516101a0870152604001516101c086015260c086015160ff81166101e08701529092509050612abb565b5f60808284031215611e50575f5ffd5b5f60208284031215612fbc575f5ffd5b81356001600160401b03811115612fd1575f5ffd5b61221e84828501612f9c565b5f60208284031215612fed575f5ffd5b81356001600160401b03811115613002575f5ffd5b61221e84828501612cd2565b602081525f8251606060208401526130296080840182612e2b565b602085810151601f19868403016040870152805180845290820193505f92909101905b8083101561309f5783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a08201915060208401935060018301925061304c565b506040860151858203601f19016060870152805180835260209182019450910191505f905b80821015613104576130ed83855180516001600160a01b03908116835260209182015116910152565b6040830192506020840193506001820191506130c4565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156131455761314561310f565b60405290565b604080519081016001600160401b03811182821017156131455761314561310f565b604051606081016001600160401b03811182821017156131455761314561310f565b60405160e081016001600160401b03811182821017156131455761314561310f565b604051601f8201601f191681016001600160401b03811182821017156131d9576131d961310f565b604052919050565b803565ffffffffffff811681146131f6575f5ffd5b919050565b80356001600160a01b03811681146131f6575f5ffd5b5f60c08284031215613221575f5ffd5b60405160c081016001600160401b03811182821017156132435761324361310f565b604052905080613252836131e1565b8152613260602084016131e1565b6020820152613271604084016131e1565b6040820152613282606084016131fb565b60608201526080838101359082015260a092830135920191909152919050565b803560ff811681146131f6575f5ffd5b5f6001600160401b038211156132ca576132ca61310f565b5060051b60200190565b803562ffffff811681146131f6575f5ffd5b5f608082840312156132f6575f5ffd5b6132fe613123565b9050613309826131e1565b815260208281013590820152613321604083016132a2565b604082015260608201356001600160401b0381111561333e575f5ffd5b8201601f8101841361334e575f5ffd5b803561336161335c826132b2565b6131b1565b8082825260208201915060208360051b850101925086831115613382575f5ffd5b602084015b838110156134c85780356001600160401b038111156133a4575f5ffd5b85016040818a03601f190112156133b9575f5ffd5b6133c161314b565b602082013580151581146133d3575f5ffd5b815260408201356001600160401b038111156133ed575f5ffd5b6020818401019250506060828b031215613405575f5ffd5b61340d61316d565b82356001600160401b03811115613422575f5ffd5b8301601f81018c13613432575f5ffd5b803561344061335c826132b2565b8082825260208201915060208360051b85010192508e831115613461575f5ffd5b6020840193505b82841015613483578335825260209384019390910190613468565b845250613495915050602084016132d4565b60208201526134a6604084016131e1565b6040820152806020830152508085525050602083019250602081019050613387565b5060608501525091949350505050565b5f60a082840312156134e8575f5ffd5b60405160a081016001600160401b038111828210171561350a5761350a61310f565b604052905080613519836131e1565b8152613527602084016131e1565b6020820152613538604084016131e1565b604082015260608381013590820152608092830135920191909152919050565b5f6101808236031215613569575f5ffd5b61357161316d565b61357b3684613211565b815260c08301356001600160401b03811115613595575f5ffd5b6135a1368286016132e6565b6020830152506135b43660e085016134d8565b604082015292915050565b5f606082840312156135cf575f5ffd5b6135d761316d565b90506135e2826131e1565b81526020828101359082015260409182013591810191909152919050565b5f60a08284031215613610575f5ffd5b61361861316d565b823581526020808401359082015290506135b483604084016135bf565b5f60a08284031215613645575f5ffd5b6102f88383613600565b5f82601f83011261365e575f5ffd5b813561366c61335c826132b2565b80828252602082019150602060c0840286010192508583111561368d575f5ffd5b602085015b838110156136b4576136a48782613211565b835260209092019160c001613692565b5095945050505050565b803561ffff811681146131f6575f5ffd5b5f606082840312156136df575f5ffd5b6136e761316d565b90506136f2826136be565b8152613700602083016136be565b60208201526135b4604083016132d4565b5f60808284031215613721575f5ffd5b613729613123565b9050613734826132a2565b815260208201356001600160401b0381111561374e575f5ffd5b8201601f8101841361375e575f5ffd5b803561376c61335c826132b2565b8082825260208201915060208360071b85010192508683111561378d575f5ffd5b6020840193505b8284101561380a57608084880312156137ab575f5ffd5b6137b3613123565b6137bc856131e1565b81526020850135600381106137cf575f5ffd5b60208201526137e0604086016131fb565b60408201526137f1606086016131fb565b6060820152825260809390930192602090910190613794565b60208501525050506040828101359082015260609182013591810191909152919050565b5f82601f83011261383d575f5ffd5b813561384b61335c826132b2565b8082825260208201915060208360051b86010192508583111561386c575f5ffd5b602085015b838110156136b45780356001600160401b0381111561388e575f5ffd5b61389d886020838a0101613711565b84525060209283019201613871565b5f6101e082360312156138bd575f5ffd5b6138c561318f565b6138ce836131e1565b81526138dd36602085016134d8565b602082015260c08301356001600160401b038111156138fa575f5ffd5b6139063682860161364f565b6040830152506139193660e085016136cf565b60608201526101408301356001600160401b03811115613937575f5ffd5b6139433682860161382e565b6080830152506139573661016085016135bf565b60a08201526139696101c084016132a2565b60c082015292915050565b5f60a08284031215613984575f5ffd5b6102f883836134d8565b5f6060828403121561399e575f5ffd5b6102f883836135bf565b5f604082840312156139b8575f5ffd5b6139c061314b565b90506139cb826131fb565b81526139d9602083016131fb565b602082015292915050565b5f604082840312156139f4575f5ffd5b6102f883836139a8565b5f6101208236031215613a0f575f5ffd5b613a17613123565b613a20836131e1565b8152613a2f3660208501613600565b602082015260c08301356001600160401b03811115613a4c575f5ffd5b613a5836828601613711565b604083015250613a6b3660e085016139a8565b606082015292915050565b5f60c08284031215613a86575f5ffd5b6102f88383613211565b5f61029436836132e6565b5f82601f830112613aaa575f5ffd5b8135613ab861335c826132b2565b8082825260208201915060208360061b860101925085831115613ad9575f5ffd5b602085015b838110156136b457613af087826139a8565b8352602090920191604001613ade565b5f60608236031215613b10575f5ffd5b613b1861316d565b82356001600160401b03811115613b2d575f5ffd5b613b393682860161364f565b82525060208301356001600160401b03811115613b54575f5ffd5b830136601f820112613b64575f5ffd5b8035613b7261335c826132b2565b80828252602082019150602060a08402850101925036831115613b93575f5ffd5b6020840193505b82841015613bbf57613bac3685613600565b825260208201915060a084019350613b9a565b602085015250505060408301356001600160401b03811115613bdf575f5ffd5b613beb36828601613a9b565b60408301525092915050565b5f6102943683613711565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a264697066735822122090a08da46474a794e595da3336daaa54b6c121ddc6aaabf47b5a1e00556d090a64736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa<l\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80cz\x9AU*\x11a\0\x93W\x80c\xB8\xB0.\x0E\x11a\0cW\x80c\xB8\xB0.\x0E\x14a\x02\x10W\x80c\xDCZ\x8B\xF8\x14a\x02#W\x80c\xED\xBA\xCDD\x14a\x026W\x80c\xEE\xDE\xC1\x02\x14a\x02VW__\xFD[\x80cz\x9AU*\x14a\x01\xB7W\x80c\x8Fm\x0E\x1A\x14a\x01\xCAW\x80c\xA1\xEC\x933\x14a\x01\xDDW\x80c\xAF\xB6:\xD4\x14a\x01\xF0W__\xFD[\x80c+A\xC9\xCA\x11a\0\xCEW\x80c+A\xC9\xCA\x14a\x01^W\x80c]'\xCC\x95\x14a\x01qW\x80co\x8A\\\xFF\x14a\x01\x91W\x80cy\x89\xAA\x10\x14a\x01\xA4W__\xFD[\x80c\x0B\t;\x8B\x14a\0\xF4W\x80c\x1F9pg\x14a\x01\x1DW\x80c&09b\x14a\x01>W[__\xFD[a\x01\x07a\x01\x026`\x04a(BV[a\x02\x81V[`@Qa\x01\x14\x91\x90a(yV[`@Q\x80\x91\x03\x90\xF3[a\x010a\x01+6`\x04a(\xBEV[a\x02\x9AV[`@Q\x90\x81R` \x01a\x01\x14V[a\x01Qa\x01L6`\x04a(\xD8V[a\x02\xB2V[`@Qa\x01\x14\x91\x90a*!V[a\x01\x07a\x01l6`\x04a*\xC3V[a\x02\xFFV[a\x01\x84a\x01\x7F6`\x04a(\xD8V[a\x03\x12V[`@Qa\x01\x14\x91\x90a+\x9CV[a\x010a\x01\x9F6`\x04a(\xBEV[a\x03XV[a\x010a\x01\xB26`\x04a,\xE2V[a\x03pV[a\x010a\x01\xC56`\x04a-CV[a\x03\x88V[a\x01\x07a\x01\xD86`\x04a-\xDBV[a\x04>V[a\x010a\x01\xEB6`\x04a.\x12V[a\x04QV[a\x02\x03a\x01\xFE6`\x04a(\xD8V[a\x04iV[`@Qa\x01\x14\x91\x90a.\xCAV[a\x010a\x02\x1E6`\x04a/\xACV[a\x04\xAFV[a\x01\x07a\x0216`\x04a/\xDDV[a\x04\xC1V[a\x02Ia\x02D6`\x04a(\xD8V[a\x04\xD4V[`@Qa\x01\x14\x91\x90a0\x0EV[a\x02ia\x02d6`\x04a/\xACV[a\x056V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x14V[``a\x02\x94a\x02\x8F\x83a5XV[a\x05HV[\x92\x91PPV[_a\x02\x94a\x02\xAD6\x84\x90\x03\x84\x01\x84a65V[a\x08\x0EV[a\x02\xBAa&.V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08B\x92PPPV[\x93\x92PPPV[``a\x02\x94a\x03\r\x83a8\xACV[a\n\xF4V[a\x03\x1Aa&\xA2V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\r\x1C\x92PPPV[_a\x02\x94a\x03k6\x84\x90\x03\x84\x01\x84a9tV[a\x10FV[_a\x02\x94a\x03\x836\x84\x90\x03\x84\x01\x84a9\x8EV[a\x10\xA7V[_a\x045\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xD9Wa\x03\xCA`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a65V[\x81R` \x01\x90`\x01\x01\x90a\x03\xADV[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04+Wa\x04\x1C`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a9\xE4V[\x81R` \x01\x90`\x01\x01\x90a\x03\xFFV[PPPPPa\x10\xD8V[\x95\x94PPPPPV[``a\x02\x94a\x04L\x83a9\xFEV[a\x12\x8FV[_a\x02\x94a\x04d6\x84\x90\x03\x84\x01\x84a:vV[a\x14\xA6V[a\x04qa'\nV[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x15\x1D\x92PPPV[_a\x02\x94a\x04\xBC\x83a:\x90V[a\x17wV[``a\x02\x94a\x04\xCF\x83a;\0V[a\x18\xE7V[a\x04\xF8`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1AL\x92PPPV[_a\x02\x94a\x05C\x83a;\xF7V[a\x1C\xBBV[``_a\x05\\\x83` \x01Q``\x01Qa\x1E\x0CV[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x05vWa\x05va1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x05\xA0W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x06\x0B\x90\x82\x90a\x1EVV[` \x85\x01Q``\x01QQ\x90\x91Pa\x06!\x81a\x1EbV[a\x061\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x07\xA4Wa\x06x\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x06[Wa\x06[a<\x02V[` \x02` \x01\x01Q_\x01Qa\x06pW_a\x1EVV[`\x01[a\x1EVV[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x06\x95Wa\x06\x95a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x06\xB0\x81a\x1EbV[a\x06\xC0\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x07$Wa\x07\x1A\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x06\xEAWa\x06\xEAa<\x02V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x07\nWa\x07\na<\x02V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x06\xC4V[Pa\x07^\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x07CWa\x07Ca<\x02V[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x07\x99\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x07~Wa\x07~a<\x02V[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x065V[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x01Q` \x80\x85\x01\x91\x90\x91R`@\x80\x88\x01\x80QQ`\xD0\x90\x81\x1B\x83\x88\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x87\x01R\x80Q\x90\x91\x01Q\x90\x91\x1B`L\x85\x01R\x80Q``\x01Q`R\x85\x01RQ\x01Q`r\x83\x01\x90\x81R\x91`\x92\x01[\x91PPPP\x91\x90PV[_a\x02\x94\x82_\x01Q\x83` \x01Qa\x08(\x85`@\x01Qa\x10\xA7V[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[a\x08Ja&.V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\x11Wa\t\x11a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\taW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\t/W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xECW\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\x9CWa\t\x9Ca<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xE3W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xF8Wa\t\xF8a)DV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\n\x12Wa\n\x12a<\x02V[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\n/Wa\n/a)DV[\x90\x81`\x02\x81\x11\x15a\nBWa\nBa)DV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\nhWa\nha<\x02V[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\n\xA0\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n\xBAWa\n\xBAa<\x02V[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\tmV[PPP\x91\x90PV[``_a\x0B\x0E\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa\x1E\x88V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0B(Wa\x0B(a1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0BRW` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x90\x92\x1B`2\x84\x01R\x80Q``\x01Q`8\x84\x01RQ`\x80\x01Q`X\x83\x01R\x84\x01QQ\x90\x92P`x\x83\x01\x90a\x0B\xB7\x90a\x1EbV[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x0C\x05Wa\x0B\xFB\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x0B\xEEWa\x0B\xEEa<\x02V[` \x02` \x01\x01Qa\x1F\x13V[\x91P`\x01\x01a\x0B\xC7V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x0CC\x90a\x1EbV[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x0C\x91Wa\x0C\x87\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x0CzWa\x0Cza<\x02V[` \x02` \x01\x01Qa\x1FeV[\x91P`\x01\x01a\x0CSV[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x0C\xB5WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x0C\xC7WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x0C\xDF\x82\x82a\x0C\xD9W`\x01a\x1EVV[_a\x1EVV[\x91P\x80a\r\x0EW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x08\x04\x82\x86`\xC0\x01Qa\x1EVV[a\r$a&\xA2V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\r\xB2Wa\r\xB2a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\x15W\x81` \x01[a\x0E\x02`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\r\xD0W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xE3W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0E\\Wa\x0E\\a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E\x8FWa\x0E\x8Fa1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\xB8W\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0E\xD3Wa\x0E\xD3a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0FHW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0F\x10Wa\x0F\x10a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0F0Wa\x0F0a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0E\xE4V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0FlWa\x0Fla<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0F\xAEWa\x0F\xAEa<\x02V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0E!V[PP\x80Q\x82Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x83\x01Q\x84Q`\xA0\x01R`@\x80\x84\x01Q\x81\x86\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x86\x01Q\x81Q\x90\x83\x1C\x94\x01\x93\x90\x93R`L\x85\x01Q\x83Q\x91\x1C\x91\x01R`R\x83\x01Q\x81Q``\x01R`r\x90\x92\x01Q\x91Q\x01R\x91\x90PV[_a\x02\x94\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x84`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x85``\x01Q\x86`\x80\x01Q`@\x80Q\x95\x86R` \x86\x01\x94\x90\x94R\x92\x84\x01\x91\x90\x91R``\x83\x01R`\x80\x82\x01R`\xA0\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x94V[_\x81Q\x83Q\x14a\x10\xFBW`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x11\x1BW_Q` a<\x17_9_Q\x90_R\x91PPa\x02\x94V[\x80`\x01\x03a\x11~W_a\x11`\x85_\x81Q\x81\x10a\x119Wa\x119a<\x02V[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[` \x02` \x01\x01Qa\x1F\xEDV[\x90Pa\x11u\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x94V[\x80`\x02\x03a\x11\xF2W_a\x11\x9C\x85_\x81Q\x81\x10a\x119Wa\x119a<\x02V[\x90P_a\x11\xD0\x86`\x01\x81Q\x81\x10a\x11\xB5Wa\x11\xB5a<\x02V[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x94V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x12hWa\x12_\x82\x82`\x01\x01a\x12P\x89\x85\x81Q\x81\x10a\x126Wa\x126a<\x02V[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x12\x11V[P\x80Q`\x05\x1B` \x82\x01 a\x045\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12\xBAWa\x12\xBAa1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x12\xE4W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x13L\x90\x82\x90a\x1EVV[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x13\x98\x90a\x1EbV[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xECWa\x13\xF1\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x13\xDBWa\x13\xDBa<\x02V[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x14.\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14\x11Wa\x14\x11a<\x02V[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x06sWa\x06sa)DV[\x91Pa\x14e\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14NWa\x14Na<\x02V[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x14\x9C\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14\x85Wa\x14\x85a<\x02V[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x13\xACV[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x02\xF8\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x15%a'\nV[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x91\x1C`@\x90\x91\x01R`8\x83\x01Q\x81Q``\x01R`X\x83\x01Q\x90Q`\x80\x01R`x\x82\x01Q`z\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\x9CWa\x15\x9Ca1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x15\xD5W\x81` \x01[a\x15\xC2a'\xCEV[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x15\xBAW\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x16 Wa\x15\xF2\x83a @V[\x85`@\x01Q\x83\x81Q\x81\x10a\x16\x08Wa\x16\x08a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x15\xDDV[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16yWa\x16ya1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x16\xD5W\x81` \x01[a\x16\xC2`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x16\x97W\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x17 Wa\x16\xF2\x84a \x9DV[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x17\x08Wa\x17\x08a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x16\xDDV[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x17eW\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x17\xC0W_Q` a<\x17_9_Q\x90_R\x91Pa\x18\xC6V[\x80`\x01\x03a\x18\tWa\x18\x02\x81_\x1Ba\x17\xF4\x87``\x01Q_\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[` \x02` \x01\x01Qa!\xAEV[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x18\xC6V[\x80`\x02\x03a\x18JWa\x18\x02\x81_\x1Ba\x180\x87``\x01Q_\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[a\x08(\x88``\x01Q`\x01\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x18\x9BWa\x18\x92\x82\x82`\x01\x01a\x12P\x8A``\x01Q\x85\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[P`\x01\x01a\x18iV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x18\xC4\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x19\0\x83_\x01Q\x84` \x01Q\x85`@\x01Qa\"&V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x1AWa\x19\x1Aa1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x19DW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x19Y\x90a\x1EbV[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x19\xA0Wa\x19\x96\x82\x86_\x01Q\x83\x81Q\x81\x10a\x19\x89Wa\x19\x89a<\x02V[` \x02` \x01\x01Qa\"{V[\x91P`\x01\x01a\x19fV[Pa\x19\xAF\x84` \x01QQa\x1EbV[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x19\xFDWa\x19\xF3\x82\x86` \x01Q\x83\x81Q\x81\x10a\x19\xE6Wa\x19\xE6a<\x02V[` \x02` \x01\x01Qa\"\xB5V[\x91P`\x01\x01a\x19\xBFV[Pa\x1A\x0C\x84`@\x01QQa\x1EbV[_[\x84`@\x01QQ\x81\x10\x15a\n\xECWa\x1AB\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1A5Wa\x1A5a<\x02V[` \x02` \x01\x01Qa\"\xF1V[\x91P`\x01\x01a\x1A\x0EV[a\x1Ap`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\x95Wa\x1A\x95a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1A\xCEW\x81` \x01[a\x1A\xBBa'\xCEV[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1A\xB3W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\x14Wa\x1A\xE8\x83a#\x12V[\x85Q\x80Q\x84\x90\x81\x10a\x1A\xFCWa\x1A\xFCa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1A\xD3V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1BDW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B`Wa\x1B`a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1B\x99W\x81` \x01[a\x1B\x86a(\x02V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1B~W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\xE4Wa\x1B\xB6\x84a#ZV[\x86` \x01Q\x83\x81Q\x81\x10a\x1B\xCCWa\x1B\xCCa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1B\xA1V[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x01Wa\x1C\x01a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1CEW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1C\x1FW\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1C\xB2W`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1C\x9AWa\x1C\x9Aa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1CMV[PPPP\x91\x90PV[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1C\xE1W_Q` a<\x17_9_Q\x90_R\x91Pa\x1D\xD9V[\x80`\x01\x03a\x1D\x1CWa\x1D\x15\x81_\x1Ba\x17\xF4\x86` \x01Q_\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[` \x02` \x01\x01Qa#\xA4V[\x91Pa\x1D\xD9V[\x80`\x02\x03a\x1D]Wa\x1D\x15\x81_\x1Ba\x1DC\x86` \x01Q_\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[a\x08(\x87` \x01Q`\x01\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1D\xAEWa\x1D\xA5\x82\x82`\x01\x01a\x12P\x89` \x01Q\x85\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[P`\x01\x01a\x1D|V[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1D\xD7\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x045V[`\xE1_[\x82Q\x81\x10\x15a\x1EPW\x82\x81\x81Q\x81\x10a\x1E+Wa\x1E+a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x1E\x10V[P\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x1E\x85W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`e\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x1E\xA6WP` \x83\x01Q\x15[\x80\x15a\x1E\xB4WP`@\x83\x01Q\x15[\x90P\x80a\x1E\xC2W`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a\x1F\nW\x84\x81\x81Q\x81\x10a\x1E\xE8Wa\x1E\xE8a<\x02V[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa\x1E\xCDV[PP\x93\x92PPPV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x02\xF8V[_a\x1Fs\x83\x83_\x01Qa\x1EVV[\x90Pa\x1F\x83\x82` \x01QQa\x1EbV[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\x1F\xD1Wa\x1F\xC7\x82\x84` \x01Q\x83\x81Q\x81\x10a\x1F\xBAWa\x1F\xBAa<\x02V[` \x02` \x01\x01Qa$\x10V[\x91P`\x01\x01a\x1F\x93V[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x02\xF8V[_a\x02\xF8\x83_\x01Q\x84` \x01Qa \x07\x86`@\x01Qa\x10\xA7V[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[a Ha'\xCEV[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a \xC8`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a \xF4Wa \xF4a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a!DW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a!\x12W\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a!\x8FWa!a\x83a$[V[\x85` \x01Q\x83\x81Q\x81\x10a!wWa!wa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a!LV[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a!\xC0\x83` \x01Q_\x01Qa$\xF3V[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa\"\x1E\x84_\x01Qa\"\tW_a\"\x0CV[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[_\x82Q\x84Q\x14a\"IW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a\"kW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a\x1FHV[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x02\xF8V[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x02\xF8V[a#\x1Aa'\xCEV[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a \x82V[a#ba(\x02V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x94\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a#\xCCWa#\xCCa)DV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa$8\x81\x83` \x01Q`\x02\x81\x11\x15a\x06sWa\x06sa)DV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x02\xF8V[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a$\xA4Wa$\xA4a)DV[\x83` \x01\x90`\x02\x81\x11\x15a$\xBAWa$\xBAa)DV[\x90\x81`\x02\x81\x11\x15a$\xCDWa$\xCDa)DV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a%\x13WP_Q` a<\x17_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a%IWa\x02\xF8\x81_\x1B\x84_\x81Q\x81\x10a%3Wa%3a<\x02V[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a%\xA6Wa\x02\xF8\x81_\x1B\x84_\x81Q\x81\x10a%iWa%ia<\x02V[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a%\x84Wa%\x84a<\x02V[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a&\x07Wa%\xFE\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a%\xE7Wa%\xE7a<\x02V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a%\xC5V[P\x80Q`\x05\x1B` \x82\x01 a\"\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a&Oa(\x02V[\x81R` \x01a&\x7F`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a&\x9D`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80``\x01`@R\x80a&\xB5a'\xCEV[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a'S`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a'\x8D`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a'\xC2`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a&\x9D`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_` \x82\x84\x03\x12\x15a(RW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a(gW__\xFD[\x82\x01a\x01\x80\x81\x85\x03\x12\x15a\x02\xF8W__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a\x1EPW__\xFD[_`\xA0\x82\x84\x03\x12\x15a(\xCEW__\xFD[a\x02\xF8\x83\x83a(\xAEV[__` \x83\x85\x03\x12\x15a(\xE9W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a(\xFEW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a)\x0EW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a)#W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a)4W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_`\x80\x83\x01`\xFF\x83Q\x16\x84R` \x83\x01Q`\x80` \x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P` \x83\x01\x93P_\x92P[\x80\x83\x10\x15a*\0W\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x83R` \x81\x01Q`\x03\x81\x10a)\xBDWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x80` \x85\x01RP`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa)\x86V[P`@\x85\x01Q`@\x87\x01R``\x85\x01Q``\x87\x01R\x80\x93PPPP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa*w`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra*\x93a\x01@\x84\x01\x82a)XV[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[_` \x82\x84\x03\x12\x15a*\xD3W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a*\xE8W__\xFD[\x82\x01a\x01\xE0\x81\x85\x03\x12\x15a\x02\xF8W__\xFD[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R``\x81\x01Q``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01RPPV[` \x81Ra+\xAE` \x82\x01\x83Qa*\xFAV[` \x82\x81\x01Qa\x01\x80`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x84\x01R\x80\x82\x01Qa\x01\xC0\x84\x01R`@\x81\x01Q`\xFF\x16a\x01\xE0\x84\x01R``\x01Q`\x80a\x02\0\x84\x01R\x80Qa\x02 \x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02@`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a,\xBAW\x86\x84\x03a\x02?\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a,\x7FW\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa,\\V[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a,\x14V[PPP`@\x85\x01Q\x91Pa\"\x1Ea\x01\0\x85\x01\x83a+TV[_``\x82\x84\x03\x12\x15a\x1EPW__\xFD[_``\x82\x84\x03\x12\x15a,\xF2W__\xFD[a\x02\xF8\x83\x83a,\xD2V[__\x83`\x1F\x84\x01\x12a-\x0CW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-\"W__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a-<W__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a-VW__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a-kW__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a-{W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x90W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a-\xA4W__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xC3W__\xFD[a-\xCF\x87\x82\x88\x01a,\xFCV[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a-\xEBW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a.\0W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x02\xF8W__\xFD[_`\xC0\x82\x84\x03\x12\x80\x15a.#W__\xFD[P\x90\x92\x91PPV[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a.fWa.P\x86\x83Qa*\xFAV[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a.=V[P\x93\x94\x93PPPPV[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a.\xBEW`\x1F\x19\x85\x84\x03\x01\x88Ra.\xA8\x83\x83Qa)XV[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a.\x8CV[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa.\xF0`@\x84\x01\x82a+TV[P`@\x83\x01Qa\x01\xE0`\xE0\x84\x01Ra/\x0Ca\x02\0\x84\x01\x82a.+V[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01@\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01`\x86\x01R\x90\x91Pa/Y\x82\x82a.pV[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\x80\x87\x01R` \x81\x01Qa\x01\xA0\x87\x01R`@\x01Qa\x01\xC0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x01\xE0\x87\x01R\x90\x92P\x90Pa*\xBBV[_`\x80\x82\x84\x03\x12\x15a\x1EPW__\xFD[_` \x82\x84\x03\x12\x15a/\xBCW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xD1W__\xFD[a\"\x1E\x84\x82\x85\x01a/\x9CV[_` \x82\x84\x03\x12\x15a/\xEDW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0\x02W__\xFD[a\"\x1E\x84\x82\x85\x01a,\xD2V[` \x81R_\x82Q``` \x84\x01Ra0)`\x80\x84\x01\x82a.+V[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a0\x9FW\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa0LV[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a1\x04Wa0\xED\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa0\xC4V[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@R\x90V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1\xD9Wa1\xD9a1\x0FV[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a1\xF6W__\xFD[_`\xC0\x82\x84\x03\x12\x15a2!W__\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a2CWa2Ca1\x0FV[`@R\x90P\x80a2R\x83a1\xE1V[\x81Ra2`` \x84\x01a1\xE1V[` \x82\x01Ra2q`@\x84\x01a1\xE1V[`@\x82\x01Ra2\x82``\x84\x01a1\xFBV[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01R`\xA0\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[\x805`\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_`\x01`\x01`@\x1B\x03\x82\x11\x15a2\xCAWa2\xCAa1\x0FV[P`\x05\x1B` \x01\x90V[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_`\x80\x82\x84\x03\x12\x15a2\xF6W__\xFD[a2\xFEa1#V[\x90Pa3\t\x82a1\xE1V[\x81R` \x82\x81\x015\x90\x82\x01Ra3!`@\x83\x01a2\xA2V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3>W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a3NW__\xFD[\x805a3aa3\\\x82a2\xB2V[a1\xB1V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a3\x82W__\xFD[` \x84\x01[\x83\x81\x10\x15a4\xC8W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xA4W__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a3\xB9W__\xFD[a3\xC1a1KV[` \x82\x015\x80\x15\x15\x81\x14a3\xD3W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xEDW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a4\x05W__\xFD[a4\ra1mV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a4\"W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a42W__\xFD[\x805a4@a3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a4aW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a4\x83W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a4hV[\x84RPa4\x95\x91PP` \x84\x01a2\xD4V[` \x82\x01Ra4\xA6`@\x84\x01a1\xE1V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa3\x87V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x15a4\xE8W__\xFD[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a5\nWa5\na1\x0FV[`@R\x90P\x80a5\x19\x83a1\xE1V[\x81Ra5'` \x84\x01a1\xE1V[` \x82\x01Ra58`@\x84\x01a1\xE1V[`@\x82\x01R``\x83\x81\x015\x90\x82\x01R`\x80\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[_a\x01\x80\x826\x03\x12\x15a5iW__\xFD[a5qa1mV[a5{6\x84a2\x11V[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5\x95W__\xFD[a5\xA16\x82\x86\x01a2\xE6V[` \x83\x01RPa5\xB46`\xE0\x85\x01a4\xD8V[`@\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a5\xCFW__\xFD[a5\xD7a1mV[\x90Pa5\xE2\x82a1\xE1V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a6\x10W__\xFD[a6\x18a1mV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa5\xB4\x83`@\x84\x01a5\xBFV[_`\xA0\x82\x84\x03\x12\x15a6EW__\xFD[a\x02\xF8\x83\x83a6\0V[_\x82`\x1F\x83\x01\x12a6^W__\xFD[\x815a6la3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a6\x8DW__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4Wa6\xA4\x87\x82a2\x11V[\x83R` \x90\x92\x01\x91`\xC0\x01a6\x92V[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_``\x82\x84\x03\x12\x15a6\xDFW__\xFD[a6\xE7a1mV[\x90Pa6\xF2\x82a6\xBEV[\x81Ra7\0` \x83\x01a6\xBEV[` \x82\x01Ra5\xB4`@\x83\x01a2\xD4V[_`\x80\x82\x84\x03\x12\x15a7!W__\xFD[a7)a1#V[\x90Pa74\x82a2\xA2V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a7NW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a7^W__\xFD[\x805a7la3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a7\x8DW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a8\nW`\x80\x84\x88\x03\x12\x15a7\xABW__\xFD[a7\xB3a1#V[a7\xBC\x85a1\xE1V[\x81R` \x85\x015`\x03\x81\x10a7\xCFW__\xFD[` \x82\x01Ra7\xE0`@\x86\x01a1\xFBV[`@\x82\x01Ra7\xF1``\x86\x01a1\xFBV[``\x82\x01R\x82R`\x80\x93\x90\x93\x01\x92` \x90\x91\x01\x90a7\x94V[` \x85\x01RPPP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a8=W__\xFD[\x815a8Ka3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a8lW__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x8EW__\xFD[a8\x9D\x88` \x83\x8A\x01\x01a7\x11V[\x84RP` \x92\x83\x01\x92\x01a8qV[_a\x01\xE0\x826\x03\x12\x15a8\xBDW__\xFD[a8\xC5a1\x8FV[a8\xCE\x83a1\xE1V[\x81Ra8\xDD6` \x85\x01a4\xD8V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xFAW__\xFD[a9\x066\x82\x86\x01a6OV[`@\x83\x01RPa9\x196`\xE0\x85\x01a6\xCFV[``\x82\x01Ra\x01@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a97W__\xFD[a9C6\x82\x86\x01a8.V[`\x80\x83\x01RPa9W6a\x01`\x85\x01a5\xBFV[`\xA0\x82\x01Ra9ia\x01\xC0\x84\x01a2\xA2V[`\xC0\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a9\x84W__\xFD[a\x02\xF8\x83\x83a4\xD8V[_``\x82\x84\x03\x12\x15a9\x9EW__\xFD[a\x02\xF8\x83\x83a5\xBFV[_`@\x82\x84\x03\x12\x15a9\xB8W__\xFD[a9\xC0a1KV[\x90Pa9\xCB\x82a1\xFBV[\x81Ra9\xD9` \x83\x01a1\xFBV[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a9\xF4W__\xFD[a\x02\xF8\x83\x83a9\xA8V[_a\x01 \x826\x03\x12\x15a:\x0FW__\xFD[a:\x17a1#V[a: \x83a1\xE1V[\x81Ra:/6` \x85\x01a6\0V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:LW__\xFD[a:X6\x82\x86\x01a7\x11V[`@\x83\x01RPa:k6`\xE0\x85\x01a9\xA8V[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a:\x86W__\xFD[a\x02\xF8\x83\x83a2\x11V[_a\x02\x946\x83a2\xE6V[_\x82`\x1F\x83\x01\x12a:\xAAW__\xFD[\x815a:\xB8a3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a:\xD9W__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4Wa:\xF0\x87\x82a9\xA8V[\x83R` \x90\x92\x01\x91`@\x01a:\xDEV[_``\x826\x03\x12\x15a;\x10W__\xFD[a;\x18a1mV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a;-W__\xFD[a;96\x82\x86\x01a6OV[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;TW__\xFD[\x83\x016`\x1F\x82\x01\x12a;dW__\xFD[\x805a;ra3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a;\x93W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a;\xBFWa;\xAC6\x85a6\0V[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa;\x9AV[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xDFW__\xFD[a;\xEB6\x82\x86\x01a:\x9BV[`@\x83\x01RP\x92\x91PPV[_a\x02\x946\x83a7\x11V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \x90\xA0\x8D\xA4dt\xA7\x94\xE5\x95\xDA36\xDA\xAAT\xB6\xC1!\xDD\xC6\xAA\xAB\xF4{Z\x1E\0Um\t\ndsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b50600436106100f0575f3560e01c80637a9a552a11610093578063b8b02e0e11610063578063b8b02e0e14610210578063dc5a8bf814610223578063edbacd4414610236578063eedec10214610256575f5ffd5b80637a9a552a146101b75780638f6d0e1a146101ca578063a1ec9333146101dd578063afb63ad4146101f0575f5ffd5b80632b41c9ca116100ce5780632b41c9ca1461015e5780635d27cc95146101715780636f8a5cff146101915780637989aa10146101a4575f5ffd5b80630b093b8b146100f45780631f3970671461011d578063263039621461013e575b5f5ffd5b610107610102366004612842565b610281565b6040516101149190612879565b60405180910390f35b61013061012b3660046128be565b61029a565b604051908152602001610114565b61015161014c3660046128d8565b6102b2565b6040516101149190612a21565b61010761016c366004612ac3565b6102ff565b61018461017f3660046128d8565b610312565b6040516101149190612b9c565b61013061019f3660046128be565b610358565b6101306101b2366004612ce2565b610370565b6101306101c5366004612d43565b610388565b6101076101d8366004612ddb565b61043e565b6101306101eb366004612e12565b610451565b6102036101fe3660046128d8565b610469565b6040516101149190612eca565b61013061021e366004612fac565b6104af565b610107610231366004612fdd565b6104c1565b6102496102443660046128d8565b6104d4565b604051610114919061300e565b610269610264366004612fac565b610536565b60405165ffffffffffff199091168152602001610114565b606061029461028f83613558565b610548565b92915050565b5f6102946102ad36849003840184613635565b61080e565b6102ba61262e565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061084292505050565b9392505050565b606061029461030d836138ac565b610af4565b61031a6126a2565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610d1c92505050565b5f61029461036b36849003840184613974565b611046565b5f6102946103833684900384018461398e565b6110a7565b5f6104358585808060200260200160405190810160405280939291908181526020015f905b828210156103d9576103ca60a08302860136819003810190613635565b815260200190600101906103ad565b50505050508484808060200260200160405190810160405280939291908181526020015f905b8282101561042b5761041c604083028601368190038101906139e4565b815260200190600101906103ff565b50505050506110d8565b95945050505050565b606061029461044c836139fe565b61128f565b5f61029461046436849003840184613a76565b6114a6565b61047161270a565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061151d92505050565b5f6102946104bc83613a90565b611777565b60606102946104cf83613b00565b6118e7565b6104f860405180606001604052806060815260200160608152602001606081525090565b6102f883838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611a4c92505050565b5f61029461054383613bf7565b611cbb565b60605f61055c836020015160600151611e0c565b9050806001600160401b038111156105765761057661310f565b6040519080825280601f01601f1916602001820160405280156105a0576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c83019061060b908290611e56565b6020850151606001515190915061062181611e62565b610631828260f01b815260020190565b91505f5b818110156107a45761067883876020015160600151838151811061065b5761065b613c02565b60200260200101515f0151610670575f611e56565b60015b611e56565b92505f866020015160600151828151811061069557610695613c02565b6020026020010151602001515f01515190506106b081611e62565b6106c0848260f01b815260020190565b93505f5b818110156107245761071a8589602001516060015185815181106106ea576106ea613c02565b6020026020010151602001515f0151838151811061070a5761070a613c02565b6020026020010151815260200190565b94506001016106c4565b5061075e84886020015160600151848151811061074357610743613c02565b6020026020010151602001516020015160e81b815260030190565b935061079984886020015160600151848151811061077e5761077e613c02565b6020026020010151602001516040015160d01b815260060190565b935050600101610635565b5084516080908101518352855160a00151602080850191909152604080880180515160d090811b83880152815190930151831b604687015280519091015190911b604c850152805160600151605285015251015160728301908152916092015b9150505050919050565b5f610294825f0151836020015161082885604001516110a7565b604080519384526020840192909252908201526060902090565b61084a61262e565b60208281015160d090811c8352602684015183830180519190915260468501518151840152606685015181516040908101519190931c9052606c8501518151830151840152608c850151905182015182015260ac840151818401805160f89290921c90915260ad85015181519092019190915260cd840151905160609081019190915260ed840151818401805191831c9091526101018501519051911c91015261011582015161011783019060f01c806001600160401b038111156109115761091161310f565b60405190808252806020026020018201604052801561096157816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f1990920191018161092f5790505b506040840151602001525f5b8161ffff16811015610aec57825160d01c60068401856040015160200151838151811061099c5761099c613c02565b602090810291909101015165ffffffffffff9290921690915280516001909101935060f81c60028111156109e357604051631ed6413560e31b815260040160405180910390fd5b8060ff1660028111156109f8576109f8612944565b8560400151602001518381518110610a1257610a12613c02565b6020026020010151602001906002811115610a2f57610a2f612944565b90816002811115610a4257610a42612944565b905250835160601c601485018660400151602001518481518110610a6857610a68613c02565b6020026020010151604001819650826001600160a01b03166001600160a01b03168152505050610aa084805160601c91601490910190565b8660400151602001518481518110610aba57610aba613c02565b6020026020010151606001819650826001600160a01b03166001600160a01b031681525050505080600101905061096d565b505050919050565b60605f610b0e836040015184608001518560a00151611e88565b9050806001600160401b03811115610b2857610b2861310f565b6040519080825280601f01601f191660200182016040528015610b52576020820181803683370190505b50835160d090811b602083810191909152808601805151831b6026850152805190910151821b602c840152805160409081015190921b6032840152805160600151603884015251608001516058830152840151519092506078830190610bb790611e62565b60408401515160f01b81526002015f5b846040015151811015610c0557610bfb8286604001518381518110610bee57610bee613c02565b6020026020010151611f13565b9150600101610bc7565b506060840180515160f090811b8352815160200151901b6002830152516040015160e81b6004820152608084015151600790910190610c4390611e62565b60808401515160f01b81526002015f5b846080015151811015610c9157610c878286608001518381518110610c7a57610c7a613c02565b6020026020010151611f65565b9150600101610c53565b5060a0840151515f9065ffffffffffff16158015610cb5575060a085015160200151155b8015610cc7575060a085015160400151155b9050610cdf8282610cd9576001611e56565b5f611e56565b915080610d0e5760a0850180515160d01b83528051602001516006840152516040015160268301526046909101905b610804828660c00151611e56565b610d246126a2565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b03811115610db257610db261310f565b604051908082528060200260200182016040528015610e1557816020015b610e026040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b815260200190600190039081610dd05790505b506020840151606001525f5b8161ffff16811015610fe3578251602085015160600151805160019095019460f89290921c91821515919084908110610e5c57610e5c613c02565b60209081029190910101519015159052835160029094019360f01c806001600160401b03811115610e8f57610e8f61310f565b604051908082528060200260200182016040528015610eb8578160200160208202803683370190505b508660200151606001518481518110610ed357610ed3613c02565b6020908102919091018101510151525f5b8161ffff16811015610f48578551602087018860200151606001518681518110610f1057610f10613c02565b6020026020010151602001515f01518381518110610f3057610f30613c02565b60209081029190910101919091529550600101610ee4565b50845160e81c600386018760200151606001518581518110610f6c57610f6c613c02565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610fae57610fae613c02565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610e21565b505080518251608090810191909152602080830151845160a00152604080840151818601805160d092831c90526046860151815190831c940193909352604c8501518351911c910152605283015181516060015260729092015191510152919050565b5f610294825f015165ffffffffffff165f1b836020015165ffffffffffff165f1b846040015165ffffffffffff165f1b85606001518660800151604080519586526020860194909452928401919091526060830152608082015260a0902090565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f90610294565b5f81518351146110fb5760405163b1f40f7760e01b815260040160405180910390fd5b82515f81900361111b575f516020613c175f395f51905f52915050610294565b8060010361117e575f611160855f8151811061113957611139613c02565b6020026020010151855f8151811061115357611153613c02565b6020026020010151611fed565b905061117582825f9182526020526040902090565b92505050610294565b806002036111f2575f61119c855f8151811061113957611139613c02565b90505f6111d0866001815181106111b5576111b5613c02565b60200260200101518660018151811061115357611153613c02565b6040805194855260208501939093529183019190915250606090209050610294565b604080516001830181526002830160051b8101909152602081018290525f5b828110156112685761125f828260010161125089858151811061123657611236613c02565b602002602001015189868151811061115357611153613c02565b60019190910160051b82015290565b50600101611211565b50805160051b60208201206104358280516040516001820160051b83011490151060061b52565b60408101516020015151606090602f0260f701806001600160401b038111156112ba576112ba61310f565b6040519080825280601f01601f1916602001820160405280156112e4576020820181803683370190505b50835160d090811b60208381019190915280860180515160268501528051820151604685015280516040908101515190931b6066850152805183015190910151606c84015251810151810151608c8301528401515190925060ac83019061134c908290611e56565b6040858101805182015183528051606090810151602080860191909152818901805151831b948601949094529251830151901b6054840152510151516068909101915061139890611e62565b6040840151602001515160f01b81526002015f5b84604001516020015151811015610aec576113f18286604001516020015183815181106113db576113db613c02565b60200260200101515f015160d01b815260060190565b915061142e82866040015160200151838151811061141157611411613c02565b602002602001015160200151600281111561067357610673612944565b915061146582866040015160200151838151811061144e5761144e613c02565b60200260200101516040015160601b815260140190565b915061149c82866040015160200151838151811061148557611485613c02565b60200260200101516060015160601b815260140190565b91506001016113ac565b5f5f6070836040015165ffffffffffff16901b60a0846020015165ffffffffffff16901b60d0855f015165ffffffffffff16901b17175f1b90506102f88184606001516001600160a01b03165f1b85608001518660a001516040805194855260208501939093529183015260608201526080902090565b61152561270a565b60208281015160d090811c83526026840151838301805191831c909152602c850151815190831c93019290925260328401518251911c604090910152603883015181516060015260588301519051608001526078820151607a83019060f01c806001600160401b0381111561159c5761159c61310f565b6040519080825280602002602001820160405280156115d557816020015b6115c26127ce565b8152602001906001900390816115ba5790505b5060408401525f5b8161ffff16811015611620576115f283612040565b8560400151838151811061160857611608613c02565b602090810291909101019190915292506001016115dd565b50815160608401805160f092831c90526002840151815190831c6020909101526004840151905160e89190911c604091909101526007830151600990930192901c806001600160401b038111156116795761167961310f565b6040519080825280602002602001820160405280156116d557816020015b6116c260405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b8152602001906001900390816116975790505b5060808501525f5b8161ffff16811015611720576116f28461209d565b8660800151838151811061170857611708613c02565b602090810291909101019190915293506001016116dd565b50825160019384019360f89190911c9081900361176557835160a08601805160d09290921c909152600685015181516020015260268501519051604001526046909301925b5050905160f81c60c083015250919050565b5f5f60c0836040015160ff16901b60d0845f015165ffffffffffff16901b175f1b90505f5f8460600151519050805f036117c0575f516020613c175f395f51905f5291506118c6565b8060010361180957611802815f1b6117f487606001515f815181106117e7576117e7613c02565b60200260200101516121ae565b5f9182526020526040902090565b91506118c6565b8060020361184a57611802815f1b61183087606001515f815181106117e7576117e7613c02565b61082888606001516001815181106117e7576117e7613c02565b604080516001830181526002830160051b8101909152602081018290525f5b8281101561189b5761189282826001016112508a6060015185815181106117e7576117e7613c02565b50600101611869565b50805160051b602082012092506118c48180516040516001820160051b83011490151060061b52565b505b50602093840151604080519384529483015292810192909252506060902090565b60605f611900835f015184602001518560400151612226565b9050806001600160401b0381111561191a5761191a61310f565b6040519080825280601f01601f191660200182016040528015611944576020820181803683370190505b50835151909250602083019061195990611e62565b83515160f01b81526002015f5b8451518110156119a05761199682865f0151838151811061198957611989613c02565b602002602001015161227b565b9150600101611966565b506119af846020015151611e62565b60208401515160f01b81526002015f5b8460200151518110156119fd576119f382866020015183815181106119e6576119e6613c02565b60200260200101516122b5565b91506001016119bf565b50611a0c846040015151611e62565b5f5b846040015151811015610aec57611a428286604001518381518110611a3557611a35613c02565b60200260200101516122f1565b9150600101611a0e565b611a7060405180606001604052806060815260200160608152602001606081525090565b6020820151602283019060f01c806001600160401b03811115611a9557611a9561310f565b604051908082528060200260200182016040528015611ace57816020015b611abb6127ce565b815260200190600190039081611ab35790505b5083525f5b8161ffff16811015611b1457611ae883612312565b8551805184908110611afc57611afc613c02565b60209081029190910101919091529250600101611ad3565b50815160029092019160f01c61ffff82168114611b4457604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b03811115611b6057611b6061310f565b604051908082528060200260200182016040528015611b9957816020015b611b86612802565b815260200190600190039081611b7e5790505b5060208501525f5b8161ffff16811015611be457611bb68461235a565b86602001518381518110611bcc57611bcc613c02565b60209081029190910101919091529350600101611ba1565b508061ffff166001600160401b03811115611c0157611c0161310f565b604051908082528060200260200182016040528015611c4557816020015b604080518082019091525f8082526020820152815260200190600190039081611c1f5790505b5060408501525f5b8161ffff16811015611cb257604080518082019091525f808252602082019081528551606090811c83526014870151901c90526028850186604001518381518110611c9a57611c9a613c02565b60209081029190910101919091529350600101611c4d565b50505050919050565b6020810151515f908190808203611ce1575f516020613c175f395f51905f529150611dd9565b80600103611d1c57611d15815f1b6117f486602001515f81518110611d0857611d08613c02565b60200260200101516123a4565b9150611dd9565b80600203611d5d57611d15815f1b611d4386602001515f81518110611d0857611d08613c02565b6108288760200151600181518110611d0857611d08613c02565b604080516001830181526002830160051b8101909152602081018290525f5b82811015611dae57611da5828260010161125089602001518581518110611d0857611d08613c02565b50600101611d7c565b50805160051b60208201209250611dd78180516040516001820160051b83011490151060061b52565b505b8351604080860151606080880151835160ff90951685526020850187905292840191909152820152608090205f90610435565b60e15f5b8251811015611e5057828181518110611e2b57611e2b613c02565b6020026020010151602001515f015151602002600c0182019150806001019050611e10565b50919050565b5f818353505060010190565b61ffff811115611e855760405163161e7a6b60e11b815260040160405180910390fd5b50565b80516065905f9065ffffffffffff16158015611ea657506020830151155b8015611eb457506040830151155b905080611ec2576046820191505b8451606602820191505f5b8451811015611f0a57848181518110611ee857611ee8613c02565b60200260200101516020015151602f0260430183019250806001019050611ecd565b50509392505050565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b60128301908152602683015b6080830151815260a08301516020820190815291506040016102f8565b5f611f7383835f0151611e56565b9050611f83826020015151611e62565b60208201515160f01b81526002015f5b826020015151811015611fd157611fc78284602001518381518110611fba57611fba613c02565b6020026020010151612410565b9150600101611f93565b50604082810151825260608301516020830190815291016102f8565b5f6102f8835f0151846020015161200786604001516110a7565b855160208088015160408051968752918601949094528401919091526001600160a01b03908116606084015216608082015260a0902090565b6120486127ce565b815160d090811c82526006830151811c6020830152600c830151901c60408201526012820151606090811c90820152602682018051604684015b6080840191909152805160a084015291936020909201925050565b6120c860405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815160f81c81526001820151600383019060f01c806001600160401b038111156120f4576120f461310f565b60405190808252806020026020018201604052801561214457816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816121125790505b5060208401525f5b8161ffff1681101561218f576121618361245b565b8560200151838151811061217757612177613c02565b6020908102919091010191909152925060010161214c565b5050805160408381019190915260208201516060840152919391019150565b5f5f6121c083602001515f01516124f3565b60208085015180820151604091820151825185815262ffffff9092169382019390935265ffffffffffff909216908201526060902090915061221e845f0151612209575f61220c565b60015b60ff16825f9182526020526040902090565b949350505050565b5f825184511461224957604051632e0b3ebf60e11b815260040160405180910390fd5b825182511461226b57604051630f97993160e21b815260040160405180910390fd5b5050905161011402600401919050565b805160d090811b8352606080830151901b6006840152602080830151821b601a850152604083015190911b90830190815260268301611f48565b8051825260208082015181840152604080830180515160d01b8286015280519092015160468501529051015160668301908152608683016102f8565b805160601b82525f60148301602083015160601b81529050601481016102f8565b61231a6127ce565b815160d090811c82526006830151606090811c90830152601a830151811c602080840191909152830151901c604082015260268201805160468401612082565b612362612802565b8151815260208083015182820152604080840151818401805160d09290921c909152604685015181519093019290925260668401519151015291608690910190565b5f610294825f015165ffffffffffff165f1b836020015160028111156123cc576123cc612944565b60ff165f1b84604001516001600160a01b03165f1b85606001516001600160a01b03165f1b6040805194855260208501939093529183015260608201526080902090565b805160d01b82525f600683019050612438818360200151600281111561067357610673612944565b6040830151606090811b825280840151901b6014820190815291506028016102f8565b604080516080810182525f808252602082018190529181018290526060810191909152815160d01c81526006820151600783019060f81c8060028111156124a4576124a4612944565b836020019060028111156124ba576124ba612944565b908160028111156124cd576124cd612944565b905250508051606090811c60408401526014820151811c90830152909260289091019150565b80515f9080820361251357505f516020613c175f395f51905f5292915050565b80600103612549576102f8815f1b845f8151811061253357612533613c02565b60200260200101515f9182526020526040902090565b806002036125a6576102f8815f1b845f8151811061256957612569613c02565b60200260200101518560018151811061258457612584613c02565b6020026020010151604080519384526020840192909252908201526060902090565b604080516001830181526002830160051b8101909152602081018290525f5b82811015612607576125fe82826001018784815181106125e7576125e7613c02565b602002602001015160019190910160051b82015290565b506001016125c5565b50805160051b602082012061221e8280516040516001820160051b83011490151060061b52565b60405180608001604052805f65ffffffffffff16815260200161264f612802565b815260200161267f60405180608001604052805f60ff168152602001606081526020015f81526020015f81525090565b815260200161269d604080518082019091525f808252602082015290565b905290565b60405180606001604052806126b56127ce565b8152604080516080810182525f80825260208281018290529282015260608082015291019081526040805160a0810182525f808252602082810182905292820181905260608201819052608082015291015290565b6040518060e001604052805f65ffffffffffff1681526020016127536040805160a0810182525f8082526020820181905291810182905260608101829052608081019190915290565b81526020016060815260200161278d60405180606001604052805f61ffff1681526020015f61ffff1681526020015f62ffffff1681525090565b8152602001606081526020016127c260405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f60209091015290565b6040805160c0810182525f80825260208201819052918101829052606081018290526080810182905260a081019190915290565b60405180606001604052805f81526020015f815260200161269d60405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f60208284031215612852575f5ffd5b81356001600160401b03811115612867575f5ffd5b820161018081850312156102f8575f5ffd5b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f60a08284031215611e50575f5ffd5b5f60a082840312156128ce575f5ffd5b6102f883836128ae565b5f5f602083850312156128e9575f5ffd5b82356001600160401b038111156128fe575f5ffd5b8301601f8101851361290e575f5ffd5b80356001600160401b03811115612923575f5ffd5b856020828401011115612934575f5ffd5b6020919091019590945092505050565b634e487b7160e01b5f52602160045260245ffd5b5f6080830160ff835116845260208301516080602086015281815180845260a0870191506020830193505f92505b80831015612a0057835165ffffffffffff81511683526020810151600381106129bd57634e487b7160e01b5f52602160045260245ffd5b8060208501525060018060a01b03604082015116604084015260018060a01b03606082015116606084015250608082019150602084019350600183019250612986565b50604085015160408701526060850151606087015280935050505092915050565b6020815265ffffffffffff82511660208201525f6020830151612a7760408401828051825260208082015181840152604091820151805165ffffffffffff16838501529081015160608401520151608090910152565b50604083015161012060e0840152612a93610140840182612958565b606085015180516001600160a01b039081166101008701526020820151166101208601529091505b509392505050565b5f60208284031215612ad3575f5ffd5b81356001600160401b03811115612ae8575f5ffd5b82016101e081850312156102f8575f5ffd5b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b0360608201511660608301526080810151608083015260a081015160a08301525050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260608101516060830152608081015160808301525050565b60208152612bae602082018351612afa565b60208281015161018060e0840152805165ffffffffffff166101a0840152808201516101c0840152604081015160ff166101e0840152606001516080610200840152805161022084018190525f929190910190610240600582901b850181019190850190845b81811015612cba5786840361023f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b80831015612c7f5783518252602082019150602084019350600183019250612c5c565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101612c14565b5050506040850151915061221e610100850183612b54565b5f60608284031215611e50575f5ffd5b5f60608284031215612cf2575f5ffd5b6102f88383612cd2565b5f5f83601f840112612d0c575f5ffd5b5081356001600160401b03811115612d22575f5ffd5b6020830191508360208260061b8501011115612d3c575f5ffd5b9250929050565b5f5f5f5f60408587031215612d56575f5ffd5b84356001600160401b03811115612d6b575f5ffd5b8501601f81018713612d7b575f5ffd5b80356001600160401b03811115612d90575f5ffd5b87602060a083028401011115612da4575f5ffd5b6020918201955093508501356001600160401b03811115612dc3575f5ffd5b612dcf87828801612cfc565b95989497509550505050565b5f60208284031215612deb575f5ffd5b81356001600160401b03811115612e00575f5ffd5b820161012081850312156102f8575f5ffd5b5f60c0828403128015612e23575f5ffd5b509092915050565b5f8151808452602084019350602083015f5b82811015612e6657612e50868351612afa565b60c0959095019460209190910190600101612e3d565b5093949350505050565b5f82825180855260208501945060208160051b830101602085015f5b83811015612ebe57601f19858403018852612ea8838351612958565b6020988901989093509190910190600101612e8c565b50909695505050505050565b6020815265ffffffffffff82511660208201525f6020830151612ef06040840182612b54565b5060408301516101e060e0840152612f0c610200840182612e2b565b6060850151805161ffff9081166101008701526020820151166101208601526040015162ffffff166101408501526080850151848203601f1901610160860152909150612f598282612e70565b60a0860151805165ffffffffffff1661018087015260208101516101a0870152604001516101c086015260c086015160ff81166101e08701529092509050612abb565b5f60808284031215611e50575f5ffd5b5f60208284031215612fbc575f5ffd5b81356001600160401b03811115612fd1575f5ffd5b61221e84828501612f9c565b5f60208284031215612fed575f5ffd5b81356001600160401b03811115613002575f5ffd5b61221e84828501612cd2565b602081525f8251606060208401526130296080840182612e2b565b602085810151601f19868403016040870152805180845290820193505f92909101905b8083101561309f5783518051835260208082015181850152604091820151805165ffffffffffff16838601529081015160608501520151608083015260a08201915060208401935060018301925061304c565b506040860151858203601f19016060870152805180835260209182019450910191505f905b80821015613104576130ed83855180516001600160a01b03908116835260209182015116910152565b6040830192506020840193506001820191506130c4565b509095945050505050565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156131455761314561310f565b60405290565b604080519081016001600160401b03811182821017156131455761314561310f565b604051606081016001600160401b03811182821017156131455761314561310f565b60405160e081016001600160401b03811182821017156131455761314561310f565b604051601f8201601f191681016001600160401b03811182821017156131d9576131d961310f565b604052919050565b803565ffffffffffff811681146131f6575f5ffd5b919050565b80356001600160a01b03811681146131f6575f5ffd5b5f60c08284031215613221575f5ffd5b60405160c081016001600160401b03811182821017156132435761324361310f565b604052905080613252836131e1565b8152613260602084016131e1565b6020820152613271604084016131e1565b6040820152613282606084016131fb565b60608201526080838101359082015260a092830135920191909152919050565b803560ff811681146131f6575f5ffd5b5f6001600160401b038211156132ca576132ca61310f565b5060051b60200190565b803562ffffff811681146131f6575f5ffd5b5f608082840312156132f6575f5ffd5b6132fe613123565b9050613309826131e1565b815260208281013590820152613321604083016132a2565b604082015260608201356001600160401b0381111561333e575f5ffd5b8201601f8101841361334e575f5ffd5b803561336161335c826132b2565b6131b1565b8082825260208201915060208360051b850101925086831115613382575f5ffd5b602084015b838110156134c85780356001600160401b038111156133a4575f5ffd5b85016040818a03601f190112156133b9575f5ffd5b6133c161314b565b602082013580151581146133d3575f5ffd5b815260408201356001600160401b038111156133ed575f5ffd5b6020818401019250506060828b031215613405575f5ffd5b61340d61316d565b82356001600160401b03811115613422575f5ffd5b8301601f81018c13613432575f5ffd5b803561344061335c826132b2565b8082825260208201915060208360051b85010192508e831115613461575f5ffd5b6020840193505b82841015613483578335825260209384019390910190613468565b845250613495915050602084016132d4565b60208201526134a6604084016131e1565b6040820152806020830152508085525050602083019250602081019050613387565b5060608501525091949350505050565b5f60a082840312156134e8575f5ffd5b60405160a081016001600160401b038111828210171561350a5761350a61310f565b604052905080613519836131e1565b8152613527602084016131e1565b6020820152613538604084016131e1565b604082015260608381013590820152608092830135920191909152919050565b5f6101808236031215613569575f5ffd5b61357161316d565b61357b3684613211565b815260c08301356001600160401b03811115613595575f5ffd5b6135a1368286016132e6565b6020830152506135b43660e085016134d8565b604082015292915050565b5f606082840312156135cf575f5ffd5b6135d761316d565b90506135e2826131e1565b81526020828101359082015260409182013591810191909152919050565b5f60a08284031215613610575f5ffd5b61361861316d565b823581526020808401359082015290506135b483604084016135bf565b5f60a08284031215613645575f5ffd5b6102f88383613600565b5f82601f83011261365e575f5ffd5b813561366c61335c826132b2565b80828252602082019150602060c0840286010192508583111561368d575f5ffd5b602085015b838110156136b4576136a48782613211565b835260209092019160c001613692565b5095945050505050565b803561ffff811681146131f6575f5ffd5b5f606082840312156136df575f5ffd5b6136e761316d565b90506136f2826136be565b8152613700602083016136be565b60208201526135b4604083016132d4565b5f60808284031215613721575f5ffd5b613729613123565b9050613734826132a2565b815260208201356001600160401b0381111561374e575f5ffd5b8201601f8101841361375e575f5ffd5b803561376c61335c826132b2565b8082825260208201915060208360071b85010192508683111561378d575f5ffd5b6020840193505b8284101561380a57608084880312156137ab575f5ffd5b6137b3613123565b6137bc856131e1565b81526020850135600381106137cf575f5ffd5b60208201526137e0604086016131fb565b60408201526137f1606086016131fb565b6060820152825260809390930192602090910190613794565b60208501525050506040828101359082015260609182013591810191909152919050565b5f82601f83011261383d575f5ffd5b813561384b61335c826132b2565b8082825260208201915060208360051b86010192508583111561386c575f5ffd5b602085015b838110156136b45780356001600160401b0381111561388e575f5ffd5b61389d886020838a0101613711565b84525060209283019201613871565b5f6101e082360312156138bd575f5ffd5b6138c561318f565b6138ce836131e1565b81526138dd36602085016134d8565b602082015260c08301356001600160401b038111156138fa575f5ffd5b6139063682860161364f565b6040830152506139193660e085016136cf565b60608201526101408301356001600160401b03811115613937575f5ffd5b6139433682860161382e565b6080830152506139573661016085016135bf565b60a08201526139696101c084016132a2565b60c082015292915050565b5f60a08284031215613984575f5ffd5b6102f883836134d8565b5f6060828403121561399e575f5ffd5b6102f883836135bf565b5f604082840312156139b8575f5ffd5b6139c061314b565b90506139cb826131fb565b81526139d9602083016131fb565b602082015292915050565b5f604082840312156139f4575f5ffd5b6102f883836139a8565b5f6101208236031215613a0f575f5ffd5b613a17613123565b613a20836131e1565b8152613a2f3660208501613600565b602082015260c08301356001600160401b03811115613a4c575f5ffd5b613a5836828601613711565b604083015250613a6b3660e085016139a8565b606082015292915050565b5f60c08284031215613a86575f5ffd5b6102f88383613211565b5f61029436836132e6565b5f82601f830112613aaa575f5ffd5b8135613ab861335c826132b2565b8082825260208201915060208360061b860101925085831115613ad9575f5ffd5b602085015b838110156136b457613af087826139a8565b8352602090920191604001613ade565b5f60608236031215613b10575f5ffd5b613b1861316d565b82356001600160401b03811115613b2d575f5ffd5b613b393682860161364f565b82525060208301356001600160401b03811115613b54575f5ffd5b830136601f820112613b64575f5ffd5b8035613b7261335c826132b2565b80828252602082019150602060a08402850101925036831115613b93575f5ffd5b6020840193505b82841015613bbf57613bac3685613600565b825260208201915060a084019350613b9a565b602085015250505060408301356001600160401b03811115613bdf575f5ffd5b613beb36828601613a9b565b60408301525092915050565b5f6102943683613711565b634e487b7160e01b5f52603260045260245ffdfec5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a264697066735822122090a08da46474a794e595da3336daaa54b6c121ddc6aaabf47b5a1e00556d090a64736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xF0W_5`\xE0\x1C\x80cz\x9AU*\x11a\0\x93W\x80c\xB8\xB0.\x0E\x11a\0cW\x80c\xB8\xB0.\x0E\x14a\x02\x10W\x80c\xDCZ\x8B\xF8\x14a\x02#W\x80c\xED\xBA\xCDD\x14a\x026W\x80c\xEE\xDE\xC1\x02\x14a\x02VW__\xFD[\x80cz\x9AU*\x14a\x01\xB7W\x80c\x8Fm\x0E\x1A\x14a\x01\xCAW\x80c\xA1\xEC\x933\x14a\x01\xDDW\x80c\xAF\xB6:\xD4\x14a\x01\xF0W__\xFD[\x80c+A\xC9\xCA\x11a\0\xCEW\x80c+A\xC9\xCA\x14a\x01^W\x80c]'\xCC\x95\x14a\x01qW\x80co\x8A\\\xFF\x14a\x01\x91W\x80cy\x89\xAA\x10\x14a\x01\xA4W__\xFD[\x80c\x0B\t;\x8B\x14a\0\xF4W\x80c\x1F9pg\x14a\x01\x1DW\x80c&09b\x14a\x01>W[__\xFD[a\x01\x07a\x01\x026`\x04a(BV[a\x02\x81V[`@Qa\x01\x14\x91\x90a(yV[`@Q\x80\x91\x03\x90\xF3[a\x010a\x01+6`\x04a(\xBEV[a\x02\x9AV[`@Q\x90\x81R` \x01a\x01\x14V[a\x01Qa\x01L6`\x04a(\xD8V[a\x02\xB2V[`@Qa\x01\x14\x91\x90a*!V[a\x01\x07a\x01l6`\x04a*\xC3V[a\x02\xFFV[a\x01\x84a\x01\x7F6`\x04a(\xD8V[a\x03\x12V[`@Qa\x01\x14\x91\x90a+\x9CV[a\x010a\x01\x9F6`\x04a(\xBEV[a\x03XV[a\x010a\x01\xB26`\x04a,\xE2V[a\x03pV[a\x010a\x01\xC56`\x04a-CV[a\x03\x88V[a\x01\x07a\x01\xD86`\x04a-\xDBV[a\x04>V[a\x010a\x01\xEB6`\x04a.\x12V[a\x04QV[a\x02\x03a\x01\xFE6`\x04a(\xD8V[a\x04iV[`@Qa\x01\x14\x91\x90a.\xCAV[a\x010a\x02\x1E6`\x04a/\xACV[a\x04\xAFV[a\x01\x07a\x0216`\x04a/\xDDV[a\x04\xC1V[a\x02Ia\x02D6`\x04a(\xD8V[a\x04\xD4V[`@Qa\x01\x14\x91\x90a0\x0EV[a\x02ia\x02d6`\x04a/\xACV[a\x056V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x01\x14V[``a\x02\x94a\x02\x8F\x83a5XV[a\x05HV[\x92\x91PPV[_a\x02\x94a\x02\xAD6\x84\x90\x03\x84\x01\x84a65V[a\x08\x0EV[a\x02\xBAa&.V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08B\x92PPPV[\x93\x92PPPV[``a\x02\x94a\x03\r\x83a8\xACV[a\n\xF4V[a\x03\x1Aa&\xA2V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\r\x1C\x92PPPV[_a\x02\x94a\x03k6\x84\x90\x03\x84\x01\x84a9tV[a\x10FV[_a\x02\x94a\x03\x836\x84\x90\x03\x84\x01\x84a9\x8EV[a\x10\xA7V[_a\x045\x85\x85\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x03\xD9Wa\x03\xCA`\xA0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a65V[\x81R` \x01\x90`\x01\x01\x90a\x03\xADV[PPPPP\x84\x84\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x04+Wa\x04\x1C`@\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a9\xE4V[\x81R` \x01\x90`\x01\x01\x90a\x03\xFFV[PPPPPa\x10\xD8V[\x95\x94PPPPPV[``a\x02\x94a\x04L\x83a9\xFEV[a\x12\x8FV[_a\x02\x94a\x04d6\x84\x90\x03\x84\x01\x84a:vV[a\x14\xA6V[a\x04qa'\nV[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x15\x1D\x92PPPV[_a\x02\x94a\x04\xBC\x83a:\x90V[a\x17wV[``a\x02\x94a\x04\xCF\x83a;\0V[a\x18\xE7V[a\x04\xF8`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[a\x02\xF8\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x1AL\x92PPPV[_a\x02\x94a\x05C\x83a;\xF7V[a\x1C\xBBV[``_a\x05\\\x83` \x01Q``\x01Qa\x1E\x0CV[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x05vWa\x05va1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x05\xA0W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x06\x0B\x90\x82\x90a\x1EVV[` \x85\x01Q``\x01QQ\x90\x91Pa\x06!\x81a\x1EbV[a\x061\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x07\xA4Wa\x06x\x83\x87` \x01Q``\x01Q\x83\x81Q\x81\x10a\x06[Wa\x06[a<\x02V[` \x02` \x01\x01Q_\x01Qa\x06pW_a\x1EVV[`\x01[a\x1EVV[\x92P_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x06\x95Wa\x06\x95a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01QQ\x90Pa\x06\xB0\x81a\x1EbV[a\x06\xC0\x84\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x93P_[\x81\x81\x10\x15a\x07$Wa\x07\x1A\x85\x89` \x01Q``\x01Q\x85\x81Q\x81\x10a\x06\xEAWa\x06\xEAa<\x02V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x07\nWa\x07\na<\x02V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x94P`\x01\x01a\x06\xC4V[Pa\x07^\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x07CWa\x07Ca<\x02V[` \x02` \x01\x01Q` \x01Q` \x01Q`\xE8\x1B\x81R`\x03\x01\x90V[\x93Pa\x07\x99\x84\x88` \x01Q``\x01Q\x84\x81Q\x81\x10a\x07~Wa\x07~a<\x02V[` \x02` \x01\x01Q` \x01Q`@\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x93PP`\x01\x01a\x065V[P\x84Q`\x80\x90\x81\x01Q\x83R\x85Q`\xA0\x01Q` \x80\x85\x01\x91\x90\x91R`@\x80\x88\x01\x80QQ`\xD0\x90\x81\x1B\x83\x88\x01R\x81Q\x90\x93\x01Q\x83\x1B`F\x87\x01R\x80Q\x90\x91\x01Q\x90\x91\x1B`L\x85\x01R\x80Q``\x01Q`R\x85\x01RQ\x01Q`r\x83\x01\x90\x81R\x91`\x92\x01[\x91PPPP\x91\x90PV[_a\x02\x94\x82_\x01Q\x83` \x01Qa\x08(\x85`@\x01Qa\x10\xA7V[`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[a\x08Ja&.V[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x81Q\x83\x01Q\x84\x01R`\x8C\x85\x01Q\x90Q\x82\x01Q\x82\x01R`\xAC\x84\x01Q\x81\x84\x01\x80Q`\xF8\x92\x90\x92\x1C\x90\x91R`\xAD\x85\x01Q\x81Q\x90\x92\x01\x91\x90\x91R`\xCD\x84\x01Q\x90Q``\x90\x81\x01\x91\x90\x91R`\xED\x84\x01Q\x81\x84\x01\x80Q\x91\x83\x1C\x90\x91Ra\x01\x01\x85\x01Q\x90Q\x91\x1C\x91\x01Ra\x01\x15\x82\x01Qa\x01\x17\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\x11Wa\t\x11a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\taW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\t/W\x90P[P`@\x84\x01Q` \x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\xECW\x82Q`\xD0\x1C`\x06\x84\x01\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\t\x9CWa\t\x9Ca<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x90\x91R\x80Q`\x01\x90\x91\x01\x93P`\xF8\x1C`\x02\x81\x11\x15a\t\xE3W`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\t\xF8Wa\t\xF8a)DV[\x85`@\x01Q` \x01Q\x83\x81Q\x81\x10a\n\x12Wa\n\x12a<\x02V[` \x02` \x01\x01Q` \x01\x90`\x02\x81\x11\x15a\n/Wa\n/a)DV[\x90\x81`\x02\x81\x11\x15a\nBWa\nBa)DV[\x90RP\x83Q``\x1C`\x14\x85\x01\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\nhWa\nha<\x02V[` \x02` \x01\x01Q`@\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPa\n\xA0\x84\x80Q``\x1C\x91`\x14\x90\x91\x01\x90V[\x86`@\x01Q` \x01Q\x84\x81Q\x81\x10a\n\xBAWa\n\xBAa<\x02V[` \x02` \x01\x01Q``\x01\x81\x96P\x82`\x01`\x01`\xA0\x1B\x03\x16`\x01`\x01`\xA0\x1B\x03\x16\x81RPPPP\x80`\x01\x01\x90Pa\tmV[PPP\x91\x90PV[``_a\x0B\x0E\x83`@\x01Q\x84`\x80\x01Q\x85`\xA0\x01Qa\x1E\x88V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0B(Wa\x0B(a1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0BRW` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ\x83\x1B`&\x85\x01R\x80Q\x90\x91\x01Q\x82\x1B`,\x84\x01R\x80Q`@\x90\x81\x01Q\x90\x92\x1B`2\x84\x01R\x80Q``\x01Q`8\x84\x01RQ`\x80\x01Q`X\x83\x01R\x84\x01QQ\x90\x92P`x\x83\x01\x90a\x0B\xB7\x90a\x1EbV[`@\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01QQ\x81\x10\x15a\x0C\x05Wa\x0B\xFB\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x0B\xEEWa\x0B\xEEa<\x02V[` \x02` \x01\x01Qa\x1F\x13V[\x91P`\x01\x01a\x0B\xC7V[P``\x84\x01\x80QQ`\xF0\x90\x81\x1B\x83R\x81Q` \x01Q\x90\x1B`\x02\x83\x01RQ`@\x01Q`\xE8\x1B`\x04\x82\x01R`\x80\x84\x01QQ`\x07\x90\x91\x01\x90a\x0CC\x90a\x1EbV[`\x80\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`\x80\x01QQ\x81\x10\x15a\x0C\x91Wa\x0C\x87\x82\x86`\x80\x01Q\x83\x81Q\x81\x10a\x0CzWa\x0Cza<\x02V[` \x02` \x01\x01Qa\x1FeV[\x91P`\x01\x01a\x0CSV[P`\xA0\x84\x01QQ_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x0C\xB5WP`\xA0\x85\x01Q` \x01Q\x15[\x80\x15a\x0C\xC7WP`\xA0\x85\x01Q`@\x01Q\x15[\x90Pa\x0C\xDF\x82\x82a\x0C\xD9W`\x01a\x1EVV[_a\x1EVV[\x91P\x80a\r\x0EW`\xA0\x85\x01\x80QQ`\xD0\x1B\x83R\x80Q` \x01Q`\x06\x84\x01RQ`@\x01Q`&\x83\x01R`F\x90\x91\x01\x90[a\x08\x04\x82\x86`\xC0\x01Qa\x1EVV[a\r$a&\xA2V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\r\xB2Wa\r\xB2a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\x15W\x81` \x01[a\x0E\x02`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\r\xD0W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0F\xE3W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x0E\\Wa\x0E\\a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E\x8FWa\x0E\x8Fa1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x0E\xB8W\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\x0E\xD3Wa\x0E\xD3a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0FHW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\x0F\x10Wa\x0F\x10a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0F0Wa\x0F0a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\x0E\xE4V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0FlWa\x0Fla<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0F\xAEWa\x0F\xAEa<\x02V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x0E!V[PP\x80Q\x82Q`\x80\x90\x81\x01\x91\x90\x91R` \x80\x83\x01Q\x84Q`\xA0\x01R`@\x80\x84\x01Q\x81\x86\x01\x80Q`\xD0\x92\x83\x1C\x90R`F\x86\x01Q\x81Q\x90\x83\x1C\x94\x01\x93\x90\x93R`L\x85\x01Q\x83Q\x91\x1C\x91\x01R`R\x83\x01Q\x81Q``\x01R`r\x90\x92\x01Q\x91Q\x01R\x91\x90PV[_a\x02\x94\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x84`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x85``\x01Q\x86`\x80\x01Q`@\x80Q\x95\x86R` \x86\x01\x94\x90\x94R\x92\x84\x01\x91\x90\x91R``\x83\x01R`\x80\x82\x01R`\xA0\x90 \x90V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\x94V[_\x81Q\x83Q\x14a\x10\xFBW`@Qc\xB1\xF4\x0Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q_\x81\x90\x03a\x11\x1BW_Q` a<\x17_9_Q\x90_R\x91PPa\x02\x94V[\x80`\x01\x03a\x11~W_a\x11`\x85_\x81Q\x81\x10a\x119Wa\x119a<\x02V[` \x02` \x01\x01Q\x85_\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[` \x02` \x01\x01Qa\x1F\xEDV[\x90Pa\x11u\x82\x82_\x91\x82R` R`@\x90 \x90V[\x92PPPa\x02\x94V[\x80`\x02\x03a\x11\xF2W_a\x11\x9C\x85_\x81Q\x81\x10a\x119Wa\x119a<\x02V[\x90P_a\x11\xD0\x86`\x01\x81Q\x81\x10a\x11\xB5Wa\x11\xB5a<\x02V[` \x02` \x01\x01Q\x86`\x01\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01\x91\x90\x91RP``\x90 \x90Pa\x02\x94V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x12hWa\x12_\x82\x82`\x01\x01a\x12P\x89\x85\x81Q\x81\x10a\x126Wa\x126a<\x02V[` \x02` \x01\x01Q\x89\x86\x81Q\x81\x10a\x11SWa\x11Sa<\x02V[`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x12\x11V[P\x80Q`\x05\x1B` \x82\x01 a\x045\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@\x81\x01Q` \x01QQ``\x90`/\x02`\xF7\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x12\xBAWa\x12\xBAa1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x12\xE4W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x85\x01R\x80Q\x82\x01Q`F\x85\x01R\x80Q`@\x90\x81\x01QQ\x90\x93\x1B`f\x85\x01R\x80Q\x83\x01Q\x90\x91\x01Q`l\x84\x01RQ\x81\x01Q\x81\x01Q`\x8C\x83\x01R\x84\x01QQ\x90\x92P`\xAC\x83\x01\x90a\x13L\x90\x82\x90a\x1EVV[`@\x85\x81\x01\x80Q\x82\x01Q\x83R\x80Q``\x90\x81\x01Q` \x80\x86\x01\x91\x90\x91R\x81\x89\x01\x80QQ\x83\x1B\x94\x86\x01\x94\x90\x94R\x92Q\x83\x01Q\x90\x1B`T\x84\x01RQ\x01QQ`h\x90\x91\x01\x91Pa\x13\x98\x90a\x1EbV[`@\x84\x01Q` \x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84`@\x01Q` \x01QQ\x81\x10\x15a\n\xECWa\x13\xF1\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x13\xDBWa\x13\xDBa<\x02V[` \x02` \x01\x01Q_\x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x14.\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14\x11Wa\x14\x11a<\x02V[` \x02` \x01\x01Q` \x01Q`\x02\x81\x11\x15a\x06sWa\x06sa)DV[\x91Pa\x14e\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14NWa\x14Na<\x02V[` \x02` \x01\x01Q`@\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x14\x9C\x82\x86`@\x01Q` \x01Q\x83\x81Q\x81\x10a\x14\x85Wa\x14\x85a<\x02V[` \x02` \x01\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[\x91P`\x01\x01a\x13\xACV[__`p\x83`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xA0\x84` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B`\xD0\x85_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17\x17_\x1B\x90Pa\x02\xF8\x81\x84``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85`\x80\x01Q\x86`\xA0\x01Q`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[a\x15%a'\nV[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x83\x1C\x90\x91R`,\x85\x01Q\x81Q\x90\x83\x1C\x93\x01\x92\x90\x92R`2\x84\x01Q\x82Q\x91\x1C`@\x90\x91\x01R`8\x83\x01Q\x81Q``\x01R`X\x83\x01Q\x90Q`\x80\x01R`x\x82\x01Q`z\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\x9CWa\x15\x9Ca1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x15\xD5W\x81` \x01[a\x15\xC2a'\xCEV[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x15\xBAW\x90P[P`@\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x16 Wa\x15\xF2\x83a @V[\x85`@\x01Q\x83\x81Q\x81\x10a\x16\x08Wa\x16\x08a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x15\xDDV[P\x81Q``\x84\x01\x80Q`\xF0\x92\x83\x1C\x90R`\x02\x84\x01Q\x81Q\x90\x83\x1C` \x90\x91\x01R`\x04\x84\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x90\x91\x01R`\x07\x83\x01Q`\t\x90\x93\x01\x92\x90\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16yWa\x16ya1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x16\xD5W\x81` \x01[a\x16\xC2`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x16\x97W\x90P[P`\x80\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x17 Wa\x16\xF2\x84a \x9DV[\x86`\x80\x01Q\x83\x81Q\x81\x10a\x17\x08Wa\x17\x08a<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x16\xDDV[P\x82Q`\x01\x93\x84\x01\x93`\xF8\x91\x90\x91\x1C\x90\x81\x90\x03a\x17eW\x83Q`\xA0\x86\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x85\x01Q\x81Q` \x01R`&\x85\x01Q\x90Q`@\x01R`F\x90\x93\x01\x92[PP\x90Q`\xF8\x1C`\xC0\x83\x01RP\x91\x90PV[__`\xC0\x83`@\x01Q`\xFF\x16\x90\x1B`\xD0\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x1B\x17_\x1B\x90P__\x84``\x01QQ\x90P\x80_\x03a\x17\xC0W_Q` a<\x17_9_Q\x90_R\x91Pa\x18\xC6V[\x80`\x01\x03a\x18\tWa\x18\x02\x81_\x1Ba\x17\xF4\x87``\x01Q_\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[` \x02` \x01\x01Qa!\xAEV[_\x91\x82R` R`@\x90 \x90V[\x91Pa\x18\xC6V[\x80`\x02\x03a\x18JWa\x18\x02\x81_\x1Ba\x180\x87``\x01Q_\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[a\x08(\x88``\x01Q`\x01\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x18\x9BWa\x18\x92\x82\x82`\x01\x01a\x12P\x8A``\x01Q\x85\x81Q\x81\x10a\x17\xE7Wa\x17\xE7a<\x02V[P`\x01\x01a\x18iV[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x18\xC4\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[P` \x93\x84\x01Q`@\x80Q\x93\x84R\x94\x83\x01R\x92\x81\x01\x92\x90\x92RP``\x90 \x90V[``_a\x19\0\x83_\x01Q\x84` \x01Q\x85`@\x01Qa\"&V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x1AWa\x19\x1Aa1\x0FV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x19DW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x19Y\x90a\x1EbV[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x19\xA0Wa\x19\x96\x82\x86_\x01Q\x83\x81Q\x81\x10a\x19\x89Wa\x19\x89a<\x02V[` \x02` \x01\x01Qa\"{V[\x91P`\x01\x01a\x19fV[Pa\x19\xAF\x84` \x01QQa\x1EbV[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\x19\xFDWa\x19\xF3\x82\x86` \x01Q\x83\x81Q\x81\x10a\x19\xE6Wa\x19\xE6a<\x02V[` \x02` \x01\x01Qa\"\xB5V[\x91P`\x01\x01a\x19\xBFV[Pa\x1A\x0C\x84`@\x01QQa\x1EbV[_[\x84`@\x01QQ\x81\x10\x15a\n\xECWa\x1AB\x82\x86`@\x01Q\x83\x81Q\x81\x10a\x1A5Wa\x1A5a<\x02V[` \x02` \x01\x01Qa\"\xF1V[\x91P`\x01\x01a\x1A\x0EV[a\x1Ap`@Q\x80``\x01`@R\x80``\x81R` \x01``\x81R` \x01``\x81RP\x90V[` \x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\x95Wa\x1A\x95a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1A\xCEW\x81` \x01[a\x1A\xBBa'\xCEV[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1A\xB3W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\x14Wa\x1A\xE8\x83a#\x12V[\x85Q\x80Q\x84\x90\x81\x10a\x1A\xFCWa\x1A\xFCa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x1A\xD3V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x1BDW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B`Wa\x1B`a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1B\x99W\x81` \x01[a\x1B\x86a(\x02V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1B~W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1B\xE4Wa\x1B\xB6\x84a#ZV[\x86` \x01Q\x83\x81Q\x81\x10a\x1B\xCCWa\x1B\xCCa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1B\xA1V[P\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\x01Wa\x1C\x01a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x1CEW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x1C\x1FW\x90P[P`@\x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x1C\xB2W`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01\x90\x81R\x85Q``\x90\x81\x1C\x83R`\x14\x87\x01Q\x90\x1C\x90R`(\x85\x01\x86`@\x01Q\x83\x81Q\x81\x10a\x1C\x9AWa\x1C\x9Aa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x1CMV[PPPP\x91\x90PV[` \x81\x01QQ_\x90\x81\x90\x80\x82\x03a\x1C\xE1W_Q` a<\x17_9_Q\x90_R\x91Pa\x1D\xD9V[\x80`\x01\x03a\x1D\x1CWa\x1D\x15\x81_\x1Ba\x17\xF4\x86` \x01Q_\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[` \x02` \x01\x01Qa#\xA4V[\x91Pa\x1D\xD9V[\x80`\x02\x03a\x1D]Wa\x1D\x15\x81_\x1Ba\x1DC\x86` \x01Q_\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[a\x08(\x87` \x01Q`\x01\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a\x1D\xAEWa\x1D\xA5\x82\x82`\x01\x01a\x12P\x89` \x01Q\x85\x81Q\x81\x10a\x1D\x08Wa\x1D\x08a<\x02V[P`\x01\x01a\x1D|V[P\x80Q`\x05\x1B` \x82\x01 \x92Pa\x1D\xD7\x81\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[P[\x83Q`@\x80\x86\x01Q``\x80\x88\x01Q\x83Q`\xFF\x90\x95\x16\x85R` \x85\x01\x87\x90R\x92\x84\x01\x91\x90\x91R\x82\x01R`\x80\x90 _\x90a\x045V[`\xE1_[\x82Q\x81\x10\x15a\x1EPW\x82\x81\x81Q\x81\x10a\x1E+Wa\x1E+a<\x02V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x1E\x10V[P\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x1E\x85W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q`e\x90_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15a\x1E\xA6WP` \x83\x01Q\x15[\x80\x15a\x1E\xB4WP`@\x83\x01Q\x15[\x90P\x80a\x1E\xC2W`F\x82\x01\x91P[\x84Q`f\x02\x82\x01\x91P_[\x84Q\x81\x10\x15a\x1F\nW\x84\x81\x81Q\x81\x10a\x1E\xE8Wa\x1E\xE8a<\x02V[` \x02` \x01\x01Q` \x01QQ`/\x02`C\x01\x83\x01\x92P\x80`\x01\x01\x90Pa\x1E\xCDV[PP\x93\x92PPPV[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01\x90\x81R`&\x83\x01[`\x80\x83\x01Q\x81R`\xA0\x83\x01Q` \x82\x01\x90\x81R\x91P`@\x01a\x02\xF8V[_a\x1Fs\x83\x83_\x01Qa\x1EVV[\x90Pa\x1F\x83\x82` \x01QQa\x1EbV[` \x82\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x82` \x01QQ\x81\x10\x15a\x1F\xD1Wa\x1F\xC7\x82\x84` \x01Q\x83\x81Q\x81\x10a\x1F\xBAWa\x1F\xBAa<\x02V[` \x02` \x01\x01Qa$\x10V[\x91P`\x01\x01a\x1F\x93V[P`@\x82\x81\x01Q\x82R``\x83\x01Q` \x83\x01\x90\x81R\x91\x01a\x02\xF8V[_a\x02\xF8\x83_\x01Q\x84` \x01Qa \x07\x86`@\x01Qa\x10\xA7V[\x85Q` \x80\x88\x01Q`@\x80Q\x96\x87R\x91\x86\x01\x94\x90\x94R\x84\x01\x91\x90\x91R`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x84\x01R\x16`\x80\x82\x01R`\xA0\x90 \x90V[a Ha'\xCEV[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q\x81\x1C` \x83\x01R`\x0C\x83\x01Q\x90\x1C`@\x82\x01R`\x12\x82\x01Q``\x90\x81\x1C\x90\x82\x01R`&\x82\x01\x80Q`F\x84\x01[`\x80\x84\x01\x91\x90\x91R\x80Q`\xA0\x84\x01R\x91\x93` \x90\x92\x01\x92PPV[a \xC8`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81Q`\xF8\x1C\x81R`\x01\x82\x01Q`\x03\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a \xF4Wa \xF4a1\x0FV[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a!DW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a!\x12W\x90P[P` \x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a!\x8FWa!a\x83a$[V[\x85` \x01Q\x83\x81Q\x81\x10a!wWa!wa<\x02V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a!LV[PP\x80Q`@\x83\x81\x01\x91\x90\x91R` \x82\x01Q``\x84\x01R\x91\x93\x91\x01\x91PV[__a!\xC0\x83` \x01Q_\x01Qa$\xF3V[` \x80\x85\x01Q\x80\x82\x01Q`@\x91\x82\x01Q\x82Q\x85\x81Rb\xFF\xFF\xFF\x90\x92\x16\x93\x82\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x92\x16\x90\x82\x01R``\x90 \x90\x91Pa\"\x1E\x84_\x01Qa\"\tW_a\"\x0CV[`\x01[`\xFF\x16\x82_\x91\x82R` R`@\x90 \x90V[\x94\x93PPPPV[_\x82Q\x84Q\x14a\"IW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82Q\x82Q\x14a\"kW`@Qc\x0F\x97\x991`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP\x90Qa\x01\x14\x02`\x04\x01\x91\x90PV[\x80Q`\xD0\x90\x81\x1B\x83R``\x80\x83\x01Q\x90\x1B`\x06\x84\x01R` \x80\x83\x01Q\x82\x1B`\x1A\x85\x01R`@\x83\x01Q\x90\x91\x1B\x90\x83\x01\x90\x81R`&\x83\x01a\x1FHV[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01\x90\x81R`\x86\x83\x01a\x02\xF8V[\x80Q``\x1B\x82R_`\x14\x83\x01` \x83\x01Q``\x1B\x81R\x90P`\x14\x81\x01a\x02\xF8V[a#\x1Aa'\xCEV[\x81Q`\xD0\x90\x81\x1C\x82R`\x06\x83\x01Q``\x90\x81\x1C\x90\x83\x01R`\x1A\x83\x01Q\x81\x1C` \x80\x84\x01\x91\x90\x91R\x83\x01Q\x90\x1C`@\x82\x01R`&\x82\x01\x80Q`F\x84\x01a \x82V[a#ba(\x02V[\x81Q\x81R` \x80\x83\x01Q\x82\x82\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R\x91`\x86\x90\x91\x01\x90V[_a\x02\x94\x82_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x1B\x83` \x01Q`\x02\x81\x11\x15a#\xCCWa#\xCCa)DV[`\xFF\x16_\x1B\x84`@\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B\x85``\x01Q`\x01`\x01`\xA0\x1B\x03\x16_\x1B`@\x80Q\x94\x85R` \x85\x01\x93\x90\x93R\x91\x83\x01R``\x82\x01R`\x80\x90 \x90V[\x80Q`\xD0\x1B\x82R_`\x06\x83\x01\x90Pa$8\x81\x83` \x01Q`\x02\x81\x11\x15a\x06sWa\x06sa)DV[`@\x83\x01Q``\x90\x81\x1B\x82R\x80\x84\x01Q\x90\x1B`\x14\x82\x01\x90\x81R\x91P`(\x01a\x02\xF8V[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x81Q`\xD0\x1C\x81R`\x06\x82\x01Q`\x07\x83\x01\x90`\xF8\x1C\x80`\x02\x81\x11\x15a$\xA4Wa$\xA4a)DV[\x83` \x01\x90`\x02\x81\x11\x15a$\xBAWa$\xBAa)DV[\x90\x81`\x02\x81\x11\x15a$\xCDWa$\xCDa)DV[\x90RPP\x80Q``\x90\x81\x1C`@\x84\x01R`\x14\x82\x01Q\x81\x1C\x90\x83\x01R\x90\x92`(\x90\x91\x01\x91PV[\x80Q_\x90\x80\x82\x03a%\x13WP_Q` a<\x17_9_Q\x90_R\x92\x91PPV[\x80`\x01\x03a%IWa\x02\xF8\x81_\x1B\x84_\x81Q\x81\x10a%3Wa%3a<\x02V[` \x02` \x01\x01Q_\x91\x82R` R`@\x90 \x90V[\x80`\x02\x03a%\xA6Wa\x02\xF8\x81_\x1B\x84_\x81Q\x81\x10a%iWa%ia<\x02V[` \x02` \x01\x01Q\x85`\x01\x81Q\x81\x10a%\x84Wa%\x84a<\x02V[` \x02` \x01\x01Q`@\x80Q\x93\x84R` \x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 \x90V[`@\x80Q`\x01\x83\x01\x81R`\x02\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x81\x01\x82\x90R_[\x82\x81\x10\x15a&\x07Wa%\xFE\x82\x82`\x01\x01\x87\x84\x81Q\x81\x10a%\xE7Wa%\xE7a<\x02V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a%\xC5V[P\x80Q`\x05\x1B` \x82\x01 a\"\x1E\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a&Oa(\x02V[\x81R` \x01a&\x7F`@Q\x80`\x80\x01`@R\x80_`\xFF\x16\x81R` \x01``\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R` \x01a&\x9D`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x90V[\x90R\x90V[`@Q\x80``\x01`@R\x80a&\xB5a'\xCEV[\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01\x90\x81R`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a'S`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R\x90V[\x81R` \x01``\x81R` \x01a'\x8D`@Q\x80``\x01`@R\x80_a\xFF\xFF\x16\x81R` \x01_a\xFF\xFF\x16\x81R` \x01_b\xFF\xFF\xFF\x16\x81RP\x90V[\x81R` \x01``\x81R` \x01a'\xC2`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x90\x91\x01R\x90V[`@\x80Q`\xC0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x91\x90\x91R\x90V[`@Q\x80``\x01`@R\x80_\x81R` \x01_\x81R` \x01a&\x9D`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[_` \x82\x84\x03\x12\x15a(RW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a(gW__\xFD[\x82\x01a\x01\x80\x81\x85\x03\x12\x15a\x02\xF8W__\xFD[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a\x1EPW__\xFD[_`\xA0\x82\x84\x03\x12\x15a(\xCEW__\xFD[a\x02\xF8\x83\x83a(\xAEV[__` \x83\x85\x03\x12\x15a(\xE9W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a(\xFEW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a)\x0EW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a)#W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a)4W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_`\x80\x83\x01`\xFF\x83Q\x16\x84R` \x83\x01Q`\x80` \x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P` \x83\x01\x93P_\x92P[\x80\x83\x10\x15a*\0W\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x83R` \x81\x01Q`\x03\x81\x10a)\xBDWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x80` \x85\x01RP`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa)\x86V[P`@\x85\x01Q`@\x87\x01R``\x85\x01Q``\x87\x01R\x80\x93PPPP\x92\x91PPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa*w`@\x84\x01\x82\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x85\x01R\x90\x81\x01Q``\x84\x01R\x01Q`\x80\x90\x91\x01RV[P`@\x83\x01Qa\x01 `\xE0\x84\x01Ra*\x93a\x01@\x84\x01\x82a)XV[``\x85\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R\x90\x91P[P\x93\x92PPPV[_` \x82\x84\x03\x12\x15a*\xD3W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a*\xE8W__\xFD[\x82\x01a\x01\xE0\x81\x85\x03\x12\x15a\x02\xF8W__\xFD[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01R`\xA0\x81\x01Q`\xA0\x83\x01RPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R``\x81\x01Q``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01RPPV[` \x81Ra+\xAE` \x82\x01\x83Qa*\xFAV[` \x82\x81\x01Qa\x01\x80`\xE0\x84\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\xA0\x84\x01R\x80\x82\x01Qa\x01\xC0\x84\x01R`@\x81\x01Q`\xFF\x16a\x01\xE0\x84\x01R``\x01Q`\x80a\x02\0\x84\x01R\x80Qa\x02 \x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x02@`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a,\xBAW\x86\x84\x03a\x02?\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a,\x7FW\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa,\\V[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a,\x14V[PPP`@\x85\x01Q\x91Pa\"\x1Ea\x01\0\x85\x01\x83a+TV[_``\x82\x84\x03\x12\x15a\x1EPW__\xFD[_``\x82\x84\x03\x12\x15a,\xF2W__\xFD[a\x02\xF8\x83\x83a,\xD2V[__\x83`\x1F\x84\x01\x12a-\x0CW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-\"W__\xFD[` \x83\x01\x91P\x83` \x82`\x06\x1B\x85\x01\x01\x11\x15a-<W__\xFD[\x92P\x92\x90PV[____`@\x85\x87\x03\x12\x15a-VW__\xFD[\x845`\x01`\x01`@\x1B\x03\x81\x11\x15a-kW__\xFD[\x85\x01`\x1F\x81\x01\x87\x13a-{W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x90W__\xFD[\x87` `\xA0\x83\x02\x84\x01\x01\x11\x15a-\xA4W__\xFD[` \x91\x82\x01\x95P\x93P\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xC3W__\xFD[a-\xCF\x87\x82\x88\x01a,\xFCV[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a-\xEBW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a.\0W__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x02\xF8W__\xFD[_`\xC0\x82\x84\x03\x12\x80\x15a.#W__\xFD[P\x90\x92\x91PPV[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a.fWa.P\x86\x83Qa*\xFAV[`\xC0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a.=V[P\x93\x94\x93PPPPV[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a.\xBEW`\x1F\x19\x85\x84\x03\x01\x88Ra.\xA8\x83\x83Qa)XV[` \x98\x89\x01\x98\x90\x93P\x91\x90\x91\x01\x90`\x01\x01a.\x8CV[P\x90\x96\x95PPPPPPV[` \x81Re\xFF\xFF\xFF\xFF\xFF\xFF\x82Q\x16` \x82\x01R_` \x83\x01Qa.\xF0`@\x84\x01\x82a+TV[P`@\x83\x01Qa\x01\xE0`\xE0\x84\x01Ra/\x0Ca\x02\0\x84\x01\x82a.+V[``\x85\x01Q\x80Qa\xFF\xFF\x90\x81\x16a\x01\0\x87\x01R` \x82\x01Q\x16a\x01 \x86\x01R`@\x01Qb\xFF\xFF\xFF\x16a\x01@\x85\x01R`\x80\x85\x01Q\x84\x82\x03`\x1F\x19\x01a\x01`\x86\x01R\x90\x91Pa/Y\x82\x82a.pV[`\xA0\x86\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x01\x80\x87\x01R` \x81\x01Qa\x01\xA0\x87\x01R`@\x01Qa\x01\xC0\x86\x01R`\xC0\x86\x01Q`\xFF\x81\x16a\x01\xE0\x87\x01R\x90\x92P\x90Pa*\xBBV[_`\x80\x82\x84\x03\x12\x15a\x1EPW__\xFD[_` \x82\x84\x03\x12\x15a/\xBCW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xD1W__\xFD[a\"\x1E\x84\x82\x85\x01a/\x9CV[_` \x82\x84\x03\x12\x15a/\xEDW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0\x02W__\xFD[a\"\x1E\x84\x82\x85\x01a,\xD2V[` \x81R_\x82Q``` \x84\x01Ra0)`\x80\x84\x01\x82a.+V[` \x85\x81\x01Q`\x1F\x19\x86\x84\x03\x01`@\x87\x01R\x80Q\x80\x84R\x90\x82\x01\x93P_\x92\x90\x91\x01\x90[\x80\x83\x10\x15a0\x9FW\x83Q\x80Q\x83R` \x80\x82\x01Q\x81\x85\x01R`@\x91\x82\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x86\x01R\x90\x81\x01Q``\x85\x01R\x01Q`\x80\x83\x01R`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa0LV[P`@\x86\x01Q\x85\x82\x03`\x1F\x19\x01``\x87\x01R\x80Q\x80\x83R` \x91\x82\x01\x94P\x91\x01\x91P_\x90[\x80\x82\x10\x15a1\x04Wa0\xED\x83\x85Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x83R` \x91\x82\x01Q\x16\x91\x01RV[`@\x83\x01\x92P` \x84\x01\x93P`\x01\x82\x01\x91Pa0\xC4V[P\x90\x95\x94PPPPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@R\x90V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1EWa1Ea1\x0FV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a1\xD9Wa1\xD9a1\x0FV[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a1\xF6W__\xFD[_`\xC0\x82\x84\x03\x12\x15a2!W__\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a2CWa2Ca1\x0FV[`@R\x90P\x80a2R\x83a1\xE1V[\x81Ra2`` \x84\x01a1\xE1V[` \x82\x01Ra2q`@\x84\x01a1\xE1V[`@\x82\x01Ra2\x82``\x84\x01a1\xFBV[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01R`\xA0\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[\x805`\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_`\x01`\x01`@\x1B\x03\x82\x11\x15a2\xCAWa2\xCAa1\x0FV[P`\x05\x1B` \x01\x90V[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_`\x80\x82\x84\x03\x12\x15a2\xF6W__\xFD[a2\xFEa1#V[\x90Pa3\t\x82a1\xE1V[\x81R` \x82\x81\x015\x90\x82\x01Ra3!`@\x83\x01a2\xA2V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3>W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a3NW__\xFD[\x805a3aa3\\\x82a2\xB2V[a1\xB1V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a3\x82W__\xFD[` \x84\x01[\x83\x81\x10\x15a4\xC8W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xA4W__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a3\xB9W__\xFD[a3\xC1a1KV[` \x82\x015\x80\x15\x15\x81\x14a3\xD3W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xEDW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a4\x05W__\xFD[a4\ra1mV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a4\"W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a42W__\xFD[\x805a4@a3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a4aW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a4\x83W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a4hV[\x84RPa4\x95\x91PP` \x84\x01a2\xD4V[` \x82\x01Ra4\xA6`@\x84\x01a1\xE1V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa3\x87V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x15a4\xE8W__\xFD[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a5\nWa5\na1\x0FV[`@R\x90P\x80a5\x19\x83a1\xE1V[\x81Ra5'` \x84\x01a1\xE1V[` \x82\x01Ra58`@\x84\x01a1\xE1V[`@\x82\x01R``\x83\x81\x015\x90\x82\x01R`\x80\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[_a\x01\x80\x826\x03\x12\x15a5iW__\xFD[a5qa1mV[a5{6\x84a2\x11V[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5\x95W__\xFD[a5\xA16\x82\x86\x01a2\xE6V[` \x83\x01RPa5\xB46`\xE0\x85\x01a4\xD8V[`@\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a5\xCFW__\xFD[a5\xD7a1mV[\x90Pa5\xE2\x82a1\xE1V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xA0\x82\x84\x03\x12\x15a6\x10W__\xFD[a6\x18a1mV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa5\xB4\x83`@\x84\x01a5\xBFV[_`\xA0\x82\x84\x03\x12\x15a6EW__\xFD[a\x02\xF8\x83\x83a6\0V[_\x82`\x1F\x83\x01\x12a6^W__\xFD[\x815a6la3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` `\xC0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a6\x8DW__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4Wa6\xA4\x87\x82a2\x11V[\x83R` \x90\x92\x01\x91`\xC0\x01a6\x92V[P\x95\x94PPPPPV[\x805a\xFF\xFF\x81\x16\x81\x14a1\xF6W__\xFD[_``\x82\x84\x03\x12\x15a6\xDFW__\xFD[a6\xE7a1mV[\x90Pa6\xF2\x82a6\xBEV[\x81Ra7\0` \x83\x01a6\xBEV[` \x82\x01Ra5\xB4`@\x83\x01a2\xD4V[_`\x80\x82\x84\x03\x12\x15a7!W__\xFD[a7)a1#V[\x90Pa74\x82a2\xA2V[\x81R` \x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a7NW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a7^W__\xFD[\x805a7la3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a7\x8DW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a8\nW`\x80\x84\x88\x03\x12\x15a7\xABW__\xFD[a7\xB3a1#V[a7\xBC\x85a1\xE1V[\x81R` \x85\x015`\x03\x81\x10a7\xCFW__\xFD[` \x82\x01Ra7\xE0`@\x86\x01a1\xFBV[`@\x82\x01Ra7\xF1``\x86\x01a1\xFBV[``\x82\x01R\x82R`\x80\x93\x90\x93\x01\x92` \x90\x91\x01\x90a7\x94V[` \x85\x01RPPP`@\x82\x81\x015\x90\x82\x01R``\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_\x82`\x1F\x83\x01\x12a8=W__\xFD[\x815a8Ka3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a8lW__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a8\x8EW__\xFD[a8\x9D\x88` \x83\x8A\x01\x01a7\x11V[\x84RP` \x92\x83\x01\x92\x01a8qV[_a\x01\xE0\x826\x03\x12\x15a8\xBDW__\xFD[a8\xC5a1\x8FV[a8\xCE\x83a1\xE1V[\x81Ra8\xDD6` \x85\x01a4\xD8V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a8\xFAW__\xFD[a9\x066\x82\x86\x01a6OV[`@\x83\x01RPa9\x196`\xE0\x85\x01a6\xCFV[``\x82\x01Ra\x01@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a97W__\xFD[a9C6\x82\x86\x01a8.V[`\x80\x83\x01RPa9W6a\x01`\x85\x01a5\xBFV[`\xA0\x82\x01Ra9ia\x01\xC0\x84\x01a2\xA2V[`\xC0\x82\x01R\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a9\x84W__\xFD[a\x02\xF8\x83\x83a4\xD8V[_``\x82\x84\x03\x12\x15a9\x9EW__\xFD[a\x02\xF8\x83\x83a5\xBFV[_`@\x82\x84\x03\x12\x15a9\xB8W__\xFD[a9\xC0a1KV[\x90Pa9\xCB\x82a1\xFBV[\x81Ra9\xD9` \x83\x01a1\xFBV[` \x82\x01R\x92\x91PPV[_`@\x82\x84\x03\x12\x15a9\xF4W__\xFD[a\x02\xF8\x83\x83a9\xA8V[_a\x01 \x826\x03\x12\x15a:\x0FW__\xFD[a:\x17a1#V[a: \x83a1\xE1V[\x81Ra:/6` \x85\x01a6\0V[` \x82\x01R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a:LW__\xFD[a:X6\x82\x86\x01a7\x11V[`@\x83\x01RPa:k6`\xE0\x85\x01a9\xA8V[``\x82\x01R\x92\x91PPV[_`\xC0\x82\x84\x03\x12\x15a:\x86W__\xFD[a\x02\xF8\x83\x83a2\x11V[_a\x02\x946\x83a2\xE6V[_\x82`\x1F\x83\x01\x12a:\xAAW__\xFD[\x815a:\xB8a3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x06\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a:\xD9W__\xFD[` \x85\x01[\x83\x81\x10\x15a6\xB4Wa:\xF0\x87\x82a9\xA8V[\x83R` \x90\x92\x01\x91`@\x01a:\xDEV[_``\x826\x03\x12\x15a;\x10W__\xFD[a;\x18a1mV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a;-W__\xFD[a;96\x82\x86\x01a6OV[\x82RP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;TW__\xFD[\x83\x016`\x1F\x82\x01\x12a;dW__\xFD[\x805a;ra3\\\x82a2\xB2V[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a;\x93W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a;\xBFWa;\xAC6\x85a6\0V[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa;\x9AV[` \x85\x01RPPP`@\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;\xDFW__\xFD[a;\xEB6\x82\x86\x01a:\x9BV[`@\x83\x01RP\x92\x91PPV[_a\x02\x946\x83a7\x11V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xC5\xD2F\x01\x86\xF7#<\x92~}\xB2\xDC\xC7\x03\xC0\xE5\0\xB6S\xCA\x82';{\xFA\xD8\x04]\x85\xA4p\xA2dipfsX\"\x12 \x90\xA0\x8D\xA4dt\xA7\x94\xE5\x95\xDA36\xDA\xAAT\xB6\xC1!\xDD\xC6\xAA\xAB\xF4{Z\x1E\0Um\t\ndsolcC\0\x08\x1E\x003",
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
    /**Function with signature `encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))` and selector `0x2b41c9ca`.
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
    ///Container type for the return parameters of the [`encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))`](encodeProposeInputCall) function.
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
            const SIGNATURE: &'static str = "encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))";
            const SELECTOR: [u8; 4] = [43u8, 65u8, 201u8, 202u8];
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
    /**Function with signature `encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,bytes32,bytes32)))` and selector `0x0b093b8b`.
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
    ///Container type for the return parameters of the [`encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,bytes32,bytes32)))`](encodeProposedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]),(uint48,uint48,uint48,bytes32,bytes32)))";
            const SELECTOR: [u8; 4] = [11u8, 9u8, 59u8, 139u8];
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
    /**Function with signature `hashCoreState((uint48,uint48,uint48,bytes32,bytes32))` and selector `0x6f8a5cff`.
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
    ///Container type for the return parameters of the [`hashCoreState((uint48,uint48,uint48,bytes32,bytes32))`](hashCoreStateCall) function.
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
            const SIGNATURE: &'static str = "hashCoreState((uint48,uint48,uint48,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [111u8, 138u8, 92u8, 255u8];
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
            [11u8, 9u8, 59u8, 139u8],
            [31u8, 57u8, 112u8, 103u8],
            [38u8, 48u8, 57u8, 98u8],
            [43u8, 65u8, 201u8, 202u8],
            [93u8, 39u8, 204u8, 149u8],
            [111u8, 138u8, 92u8, 255u8],
            [121u8, 137u8, 170u8, 16u8],
            [122u8, 154u8, 85u8, 42u8],
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
