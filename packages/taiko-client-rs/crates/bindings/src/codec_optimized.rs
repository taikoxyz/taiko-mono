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
    struct CoreState { uint48 nextProposalId; uint48 lastProposalBlockId; uint48 lastFinalizedProposalId; uint48 lastFinalizedTimestamp; uint48 lastCheckpointTimestamp; bytes32 lastFinalizedTransitionHash; }
    struct Derivation { uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
    struct DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
    struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 derivationHash; }
    struct ProposeInput { uint48 deadline; LibBlobs.BlobReference blobReference; uint8 numForcedInclusions; }
    struct ProposedEventPayload { Proposal proposal; Derivation derivation; }
    struct ProveInput { Proposal[] proposals; Transition[] transitions; bool syncCheckpoint; }
    struct ProvedEventPayload { uint48 proposalId; Transition transition; LibBonds.BondInstruction bondInstruction; bytes32 bondSignal; }
    struct Transition { bytes32 proposalHash; bytes32 parentTransitionHash; ICheckpointStore.Checkpoint checkpoint; address designatedProver; address actualProver; }
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
struct CoreState { uint48 nextProposalId; uint48 lastProposalBlockId; uint48 lastFinalizedProposalId; uint48 lastFinalizedTimestamp; uint48 lastCheckpointTimestamp; bytes32 lastFinalizedTransitionHash; }
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
        pub lastFinalizedTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastCheckpointTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lastFinalizedTransitionHash: alloy::sol_types::private::FixedBytes<32>,
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
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
                    value.lastFinalizedTimestamp,
                    value.lastCheckpointTimestamp,
                    value.lastFinalizedTransitionHash,
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
                    lastFinalizedTimestamp: tuple.3,
                    lastCheckpointTimestamp: tuple.4,
                    lastFinalizedTransitionHash: tuple.5,
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
                        &self.lastFinalizedTimestamp,
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
                    "CoreState(uint48 nextProposalId,uint48 lastProposalBlockId,uint48 lastFinalizedProposalId,uint48 lastFinalizedTimestamp,uint48 lastCheckpointTimestamp,bytes32 lastFinalizedTransitionHash)",
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
                            &self.lastFinalizedTimestamp,
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
                        &rust.lastFinalizedTimestamp,
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
                    &rust.lastFinalizedTimestamp,
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
struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 derivationHash; }
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
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::Address,
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
                    derivationHash: tuple.4,
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
                    "Proposal(uint48 id,uint48 timestamp,uint48 endOfSubmissionWindowTimestamp,address proposer,bytes32 derivationHash)",
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct ProposeInput { uint48 deadline; LibBlobs.BlobReference blobReference; uint8 numForcedInclusions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposeInput {
        #[allow(missing_docs)]
        pub deadline: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub blobReference: <LibBlobs::BlobReference as alloy::sol_types::SolType>::RustType,
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
            LibBlobs::BlobReference,
            alloy::sol_types::sol_data::Uint<8>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            <LibBlobs::BlobReference as alloy::sol_types::SolType>::RustType,
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
                (value.deadline, value.blobReference, value.numForcedInclusions)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposeInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    deadline: tuple.0,
                    blobReference: tuple.1,
                    numForcedInclusions: tuple.2,
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
                    <LibBlobs::BlobReference as alloy_sol_types::SolType>::tokenize(
                        &self.blobReference,
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
                    "ProposeInput(uint48 deadline,BlobReference blobReference,uint8 numForcedInclusions)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <LibBlobs::BlobReference as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LibBlobs::BlobReference as alloy_sol_types::SolStruct>::eip712_components(),
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
                    <LibBlobs::BlobReference as alloy_sol_types::SolType>::eip712_data_word(
                            &self.blobReference,
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
                    + <LibBlobs::BlobReference as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blobReference,
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
                <LibBlobs::BlobReference as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blobReference,
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
struct ProposedEventPayload { Proposal proposal; Derivation derivation; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposedEventPayload {
        #[allow(missing_docs)]
        pub proposal: <Proposal as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub derivation: <Derivation as alloy::sol_types::SolType>::RustType,
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
        type UnderlyingSolTuple<'a> = (Proposal, Derivation);
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            <Proposal as alloy::sol_types::SolType>::RustType,
            <Derivation as alloy::sol_types::SolType>::RustType,
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
                (value.proposal, value.derivation)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposedEventPayload {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposal: tuple.0,
                    derivation: tuple.1,
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
                    "ProposedEventPayload(Proposal proposal,Derivation derivation)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(2);
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
struct ProveInput { Proposal[] proposals; Transition[] transitions; bool syncCheckpoint; }
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
        pub syncCheckpoint: bool,
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
            alloy::sol_types::sol_data::Bool,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Vec<
                <Proposal as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::Vec<
                <Transition as alloy::sol_types::SolType>::RustType,
            >,
            bool,
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
                (value.proposals, value.transitions, value.syncCheckpoint)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProveInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposals: tuple.0,
                    transitions: tuple.1,
                    syncCheckpoint: tuple.2,
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
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.syncCheckpoint,
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
                    "ProveInput(Proposal[] proposals,Transition[] transitions,bool syncCheckpoint)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(2);
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
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.syncCheckpoint,
                        )
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
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.syncCheckpoint,
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
                <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.syncCheckpoint,
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
struct ProvedEventPayload { uint48 proposalId; Transition transition; LibBonds.BondInstruction bondInstruction; bytes32 bondSignal; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProvedEventPayload {
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub transition: <Transition as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub bondInstruction: <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub bondSignal: alloy::sol_types::private::FixedBytes<32>,
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
            LibBonds::BondInstruction,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            <Transition as alloy::sol_types::SolType>::RustType,
            <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
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
        impl ::core::convert::From<ProvedEventPayload> for UnderlyingRustTuple<'_> {
            fn from(value: ProvedEventPayload) -> Self {
                (
                    value.proposalId,
                    value.transition,
                    value.bondInstruction,
                    value.bondSignal,
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
                    bondInstruction: tuple.2,
                    bondSignal: tuple.3,
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
                    <LibBonds::BondInstruction as alloy_sol_types::SolType>::tokenize(
                        &self.bondInstruction,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondSignal),
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
                    "ProvedEventPayload(uint48 proposalId,Transition transition,BondInstruction bondInstruction,bytes32 bondSignal)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(2);
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
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalId)
                        .0,
                    <Transition as alloy_sol_types::SolType>::eip712_data_word(
                            &self.transition,
                        )
                        .0,
                    <LibBonds::BondInstruction as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstruction,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.bondSignal)
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
                    + <LibBonds::BondInstruction as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstruction,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondSignal,
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
                <LibBonds::BondInstruction as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondInstruction,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondSignal,
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
struct Transition { bytes32 proposalHash; bytes32 parentTransitionHash; ICheckpointStore.Checkpoint checkpoint; address designatedProver; address actualProver; }
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
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            ICheckpointStore::Checkpoint,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Address,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
            <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
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
        impl ::core::convert::From<Transition> for UnderlyingRustTuple<'_> {
            fn from(value: Transition) -> Self {
                (
                    value.proposalHash,
                    value.parentTransitionHash,
                    value.checkpoint,
                    value.designatedProver,
                    value.actualProver,
                )
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
                    designatedProver: tuple.3,
                    actualProver: tuple.4,
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
                    "Transition(bytes32 proposalHash,bytes32 parentTransitionHash,Checkpoint checkpoint,address designatedProver,address actualProver)",
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
        uint48 lastFinalizedTimestamp;
        uint48 lastCheckpointTimestamp;
        bytes32 lastFinalizedTransitionHash;
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
        bytes32 derivationHash;
    }
    struct ProposeInput {
        uint48 deadline;
        LibBlobs.BlobReference blobReference;
        uint8 numForcedInclusions;
    }
    struct ProposedEventPayload {
        Proposal proposal;
        Derivation derivation;
    }
    struct ProveInput {
        Proposal[] proposals;
        Transition[] transitions;
        bool syncCheckpoint;
    }
    struct ProvedEventPayload {
        uint48 proposalId;
        Transition transition;
        LibBonds.BondInstruction bondInstruction;
        bytes32 bondSignal;
    }
    struct Transition {
        bytes32 proposalHash;
        bytes32 parentTransitionHash;
        ICheckpointStore.Checkpoint checkpoint;
        address designatedProver;
        address actualProver;
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
    error InvalidBondType();
    error LengthExceedsUint16();
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
    function hashTransitions(IInbox.Transition[] memory _transitions) external pure returns (bytes32);
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
              },
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
          },
          {
            "name": "syncCheckpoint",
            "type": "bool",
            "internalType": "bool"
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
              },
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
          },
          {
            "name": "bondInstruction",
            "type": "tuple",
            "internalType": "struct LibBonds.BondInstruction",
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
            "name": "bondSignal",
            "type": "bytes32",
            "internalType": "bytes32"
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
              },
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
          },
          {
            "name": "syncCheckpoint",
            "type": "bool",
            "internalType": "bool"
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
              },
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
          },
          {
            "name": "bondInstruction",
            "type": "tuple",
            "internalType": "struct LibBonds.BondInstruction",
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
            "name": "bondSignal",
            "type": "bytes32",
            "internalType": "bytes32"
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
            "name": "lastFinalizedTimestamp",
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
          },
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
    "type": "function",
    "name": "hashTransitions",
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
          },
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
    ///0x6080604052348015600e575f5ffd5b506124888061001c5f395ff3fe608060405234801561000f575f5ffd5b50600436106100e5575f3560e01c806371989c7611610088578063a3f5bb4b11610063578063a3f5bb4b146101e1578063afb63ad4146101f4578063b8b02e0e14610254578063edbacd4414610267575f5ffd5b806371989c76146101a85780637989aa10146101bb57806385b627a2146101ce575f5ffd5b80632833bf29116100c35780632833bf29146101425780632f1969b0146101555780635d27cc95146101755780636576348314610195575f5ffd5b8063012b5fd7146100e9578063217b8da01461010f5780632630396214610122575b5f5ffd5b6100fc6100f7366004611652565b610287565b6040519081526020015b60405180910390f35b6100fc61011d3660046116d1565b6102eb565b6101356101303660046116eb565b610303565b60405161010691906117b6565b6100fc610150366004611849565b610349565b610168610163366004611872565b610361565b604051610106919061188c565b6101886101833660046116eb565b61037a565b6040516101069190611911565b6101686101a3366004611a38565b6103c0565b6101686101b6366004611a81565b6103d3565b6100fc6101c9366004611ab2565b6103e6565b6100fc6101dc366004611872565b6103fe565b6101686101ef366004611acc565b610416565b6102076102023660046116eb565b61042f565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a001610106565b6100fc610262366004611ade565b6104a6565b61027a6102753660046116eb565b6104b8565b6040516101069190611b59565b5f6102e28383808060200260200160405190810160405280939291908181526020015f905b828210156102d8576102c960e08302860136819003810190611d85565b815260200190600101906102ac565b5050505050610511565b90505b92915050565b5f6102e56102fe36849003840184611d9f565b610540565b61030b611553565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506105b892505050565b5f6102e561035c36849003840184611d85565b6106ea565b60606102e561037536849003840184611e6b565b6106fc565b61038261158d565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061077392505050565b60606102e56103ce83612182565b610a48565b60606102e56103e183612245565b610c1f565b5f6102e56103f936849003840184612323565b610d4d565b5f6102e56104113684900384018461233d565b610d7e565b60606102e561042a36849003840184612357565b610e0c565b61046860408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610f0592505050565b5f6102e56104b383612413565b610f8e565b604080516060808201835280825260208201525f918101919091526102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061119392505050565b5f81604051602001610523919061241e565b604051602081830303815290604052805190602001209050919050565b5f8160405160200161052391905f60c08201905065ffffffffffff835116825265ffffffffffff602084015116602083015265ffffffffffff604084015116604083015265ffffffffffff606084015116606083015265ffffffffffff608084015116608083015260a083015160a083015292915050565b6105c0611553565b60208281015160d090811c83526026840151838301805191909152604685015181518401526066850151815160409081015191841c909152606c860151825182015190940193909352608c850151815184015184015260ac8501518151606091821c9082015260c0860151915191901c60809091015260d48401519183015191901c905260da82015160db83019060f81c600281111561067357604051631ed6413560e31b815260040160405180910390fd5b8060ff166002811115610688576106886117a2565b83604001516020019060028111156106a2576106a26117a2565b908160028111156106b5576106b56117a2565b90525050805160408381018051606093841c9201919091526014830151905190821c9082015260289091015190820152919050565b5f816040516020016105239190612430565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d82019061076b9082906113ac565b905050919050565b61077b61158d565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b0381111561080957610809611be0565b60405190808252806020026020018201604052801561086c57816020015b6108596040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b8152602001906001900390816108275790505b506020840151606001525f5b8161ffff16811015610a3a578251602085015160600151805160019095019460f89290921c918215159190849081106108b3576108b361243e565b60209081029190910101519015159052835160029094019360f01c806001600160401b038111156108e6576108e6611be0565b60405190808252806020026020018201604052801561090f578160200160208202803683370190505b50866020015160600151848151811061092a5761092a61243e565b6020908102919091018101510151525f5b8161ffff1681101561099f5785516020870188602001516060015186815181106109675761096761243e565b6020026020010151602001515f015183815181106109875761098761243e565b6020908102919091010191909152955060010161093b565b50845160e81c6003860187602001516060015185815181106109c3576109c361243e565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610a0557610a0561243e565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610878565b505051815160800152919050565b60605f610a5c8360200151606001516113b8565b9050806001600160401b03811115610a7657610a76611be0565b6040519080825280601f01601f191660200182016040528015610aa0576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c830190610b0b9082906113ac565b60208501516060015151909150610b2181611402565b610b31828260f01b815260020190565b91505f5b81811015610c0f575f8660200151606001518281518110610b5857610b5861243e565b60200260200101519050610b7c84825f0151610b74575f6113ac565b60015b6113ac565b60208201515151909450610b8f81611402565b610b9f858260f01b815260020190565b94505f5b81811015610be257610bd88684602001515f01518381518110610bc857610bc861243e565b6020026020010151815260200190565b9550600101610ba3565b5050602090810180519091015160e81b8452516040015160d01b6003840152600990920191600101610b35565b5050925160800151909252919050565b60605f610c33835f01518460200151611428565b9050806001600160401b03811115610c4d57610c4d611be0565b6040519080825280601f01601f191660200182016040528015610c77576020820181803683370190505b508351519092506020830190610c8c90611402565b83515160f01b81526002015f5b845151811015610cd357610cc982865f01518381518110610cbc57610cbc61243e565b6020026020010151611457565b9150600101610c99565b50610ce2846020015151611402565b60208401515160f01b81526002015f5b846020015151811015610d3057610d268286602001518381518110610d1957610d1961243e565b602002602001015161149a565b9150600101610cf2565b50610d44818560400151610b74575f6113ac565b90505050919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f906102e5565b604080516005815260c08101909152815165ffffffffffff1660208201525f90602083015165ffffffffffff166040820152604083015165ffffffffffff16606082015260608301516001600160a01b03166080820152608083015160a0820152805160051b6020820120610e058280516040516001820160051b83011490151060061b52565b9392505050565b6040805161010380825261014082019092526060916020820181803683375050835160d090811b602084810191909152808601805151602686015280518201516046860152805160409081015151841b60668701528151810151830151606c8701528151810151810151608c8701528151606090810151811b60ac88015291516080015190911b60c0860152860180515190921b60d4850152905101519192505060da820190610ec99082906002811115610b7757610b776117a2565b604080850151015160601b81529050601481019050610ef68184604001516060015160601b815260140190565b60608401518152905050919050565b610f3e60408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b606081015180515f919060068101835b82811015610fda57838181518110610fb857610fb861243e565b6020026020010151602001515f01515160060182019150806001019050610f9e565b50604080518281526001830160051b8101909152602080820152855165ffffffffffff16604082015260208601516060820152604086015160ff166080820152608060a082015260c0810183905260068381015f5b85811015611160575f87828151811061104a5761104a61243e565b60200260200101519050611073858386016005878703901b5f1b60019190910160051b82015290565b5061109c8584835f0151611087575f61108a565b60015b60ff1660019190910160051b82015290565b5060406002840160051b86015260606003840160051b86015260028301602080830151015162ffffff166002820160051b87015260208201516040015165ffffffffffff166003820160051b87015260208201515180516004830160051b8801819052600383015f5b82811015611149576111408a8284600101018684815181106111295761112961243e565b602002602001015160019190910160051b82015290565b50600101611105565b50016001908101955093909301925061102f915050565b50825160051b60208401206111878480516040516001820160051b83011490151060061b52565b98975050505050505050565b60408051606080820183528082526020808301919091525f9282019290925290820151602283019060f01c806001600160401b038111156111d6576111d6611be0565b60405190808252806020026020018201604052801561122d57816020015b6040805160a0810182525f808252602080830182905292820181905260608201819052608082015282525f199092019101816111f45790505b5083525f5b8161ffff168110156112c8576040805160a0810182525f80825260208201818152928201818152606080840183815260808501938452885160d090811c865260068a0151811c909652600c89015190951c9091526012870151901c90925260268501519091526046840185518051849081106112b0576112b061243e565b60209081029190910101919091529250600101611232565b50815160029092019160f01c61ffff821681146112f857604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b0381111561131457611314611be0565b60405190808252806020026020018201604052801561134d57816020015b61133a6115e6565b8152602001906001900390816113325790505b5060208501525f5b8161ffff168110156113985761136a846114ef565b866020015183815181106113805761138061243e565b60209081029190910101919091529350600101611355565b5050905160f81c1515604083015250919050565b5f818353505060010190565b606f5f5b82518110156113fc578281815181106113d7576113d761243e565b6020026020010151602001515f015151602002600c01820191508060010190506113bc565b50919050565b61ffff8111156114255760405163161e7a6b60e11b815260040160405180910390fd5b50565b5f815183511461144b57604051632e0b3ebf60e11b815260040160405180910390fd5b50505160f40260050190565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b6012830152608081015160268301908152604683016102e2565b8051825260208082015181840152604080830180515160d01b828601528051909201516046850152905101516066830152606080820151811b60868401526080820151901b609a830190815260ae83016102e2565b6114f76115e6565b8151815260208083015181830152604080840151818401805160d09290921c90915260468501518151909301929092526066840151915101526086820151606090811c81830152609a830151901c60808201529160ae90910190565b60405180608001604052805f65ffffffffffff1681526020016115746115e6565b8152602001611581611639565b81526020015f81525090565b6040805160e0810182525f918101828152606082018390526080820183905260a0820183905260c08201929092529081908152604080516080810182525f80825260208281018290529282015260608082015291015290565b6040518060a001604052805f81526020015f815260200161162660405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f6020820181905260409091015290565b60408051608081019091525f8082526020820190611626565b5f5f60208385031215611663575f5ffd5b82356001600160401b03811115611678575f5ffd5b8301601f81018513611688575f5ffd5b80356001600160401b0381111561169d575f5ffd5b85602060e0830284010111156116b1575f5ffd5b6020919091019590945092505050565b5f60c082840312156113fc575f5ffd5b5f60c082840312156116e1575f5ffd5b6102e283836116c1565b5f5f602083850312156116fc575f5ffd5b82356001600160401b03811115611711575f5ffd5b8301601f81018513611721575f5ffd5b80356001600160401b03811115611736575f5ffd5b8560208284010111156116b1575f5ffd5b8051825260208082015181840152604080830151805165ffffffffffff168286015291820151606080860191909152910151608080850191909152908201516001600160a01b0390811660a08501529101511660c090910152565b634e487b7160e01b5f52602160045260245ffd5b815165ffffffffffff1681526020808301516101a08301916117da90840182611747565b50604083015165ffffffffffff81511661010084015260208101516003811061181157634e487b7160e01b5f52602160045260245ffd5b61012084015260408101516001600160a01b039081166101408501526060918201511661016084015292909201516101809091015290565b5f60e082840312801561185a575f5ffd5b509092915050565b5f60a082840312156113fc575f5ffd5b5f60a08284031215611882575f5ffd5b6102e28383611862565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b036060820151166060830152608081015160808301525050565b602081526119236020820183516118c1565b60208281015160c083810152805165ffffffffffff1660e084015280820151610100840152604081015160ff16610120840152606001516080610140840152805161016084018190525f929190910190610180600582901b850181019190850190845b81811015611a2c5786840361017f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b808310156119f157835182526020820191506020840193506001830192506119ce565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101611986565b50919695505050505050565b5f60208284031215611a48575f5ffd5b81356001600160401b03811115611a5d575f5ffd5b611a69848285016116c1565b949350505050565b5f606082840312156113fc575f5ffd5b5f60208284031215611a91575f5ffd5b81356001600160401b03811115611aa6575f5ffd5b611a6984828501611a71565b5f60608284031215611ac2575f5ffd5b6102e28383611a71565b5f6101a082840312801561185a575f5ffd5b5f60208284031215611aee575f5ffd5b81356001600160401b03811115611b03575f5ffd5b820160808185031215610e05575f5ffd5b5f8151808452602084019350602083015f5b82811015611b4f57611b39868351611747565b60e0959095019460209190910190600101611b26565b5093949350505050565b602080825282516060838301528051608084018190525f929190910190829060a08501905b80831015611ba857611b918285516118c1565b60a082019150602084019350600183019250611b7e565b506020860151858203601f190160408701529250611bc68184611b14565b925050506040840151151560608401528091505092915050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b0381118282101715611c1657611c16611be0565b60405290565b60405160a081016001600160401b0381118282101715611c1657611c16611be0565b604051608081016001600160401b0381118282101715611c1657611c16611be0565b604080519081016001600160401b0381118282101715611c1657611c16611be0565b604051601f8201601f191681016001600160401b0381118282101715611caa57611caa611be0565b604052919050565b803565ffffffffffff81168114611cc7575f5ffd5b919050565b5f60608284031215611cdc575f5ffd5b611ce4611bf4565b9050611cef82611cb2565b81526020828101359082015260409182013591810191909152919050565b80356001600160a01b0381168114611cc7575f5ffd5b5f60e08284031215611d33575f5ffd5b611d3b611c1c565b82358152602080840135908201529050611d588360408401611ccc565b6040820152611d6960a08301611d0d565b6060820152611d7a60c08301611d0d565b608082015292915050565b5f60e08284031215611d95575f5ffd5b6102e28383611d23565b5f60c0828403128015611db0575f5ffd5b5060405160c081016001600160401b0381118282101715611dd357611dd3611be0565b604052611ddf83611cb2565b8152611ded60208401611cb2565b6020820152611dfe60408401611cb2565b6040820152611e0f60608401611cb2565b6060820152611e2060808401611cb2565b608082015260a0928301359281019290925250919050565b803561ffff81168114611cc7575f5ffd5b803562ffffff81168114611cc7575f5ffd5b803560ff81168114611cc7575f5ffd5b5f81830360a081128015611e7d575f5ffd5b50611e86611bf4565b611e8f84611cb2565b81526060601f1983011215611ea2575f5ffd5b611eaa611bf4565b9150611eb860208501611e38565b8252611ec660408501611e38565b6020830152611ed760608501611e49565b6040830152816020820152611eee60808501611e5b565b6040820152949350505050565b5f60a08284031215611f0b575f5ffd5b611f13611c1c565b9050611f1e82611cb2565b8152611f2c60208301611cb2565b6020820152611f3d60408301611cb2565b6040820152611f4e60608301611d0d565b606082015260809182013591810191909152919050565b5f6001600160401b03821115611f7d57611f7d611be0565b5060051b60200190565b80358015158114611cc7575f5ffd5b5f60808284031215611fa6575f5ffd5b611fae611c3e565b9050611fb982611cb2565b815260208281013590820152611fd160408301611e5b565b604082015260608201356001600160401b03811115611fee575f5ffd5b8201601f81018413611ffe575f5ffd5b803561201161200c82611f65565b611c82565b8082825260208201915060208360051b850101925086831115612032575f5ffd5b602084015b838110156121725780356001600160401b03811115612054575f5ffd5b85016040818a03601f19011215612069575f5ffd5b612071611c60565b61207d60208301611f87565b815260408201356001600160401b03811115612097575f5ffd5b6020818401019250506060828b0312156120af575f5ffd5b6120b7611bf4565b82356001600160401b038111156120cc575f5ffd5b8301601f81018c136120dc575f5ffd5b80356120ea61200c82611f65565b8082825260208201915060208360051b85010192508e83111561210b575f5ffd5b6020840193505b8284101561212d578335825260209384019390910190612112565b84525061213f91505060208401611e49565b602082015261215060408401611cb2565b6040820152806020830152508085525050602083019250602081019050612037565b5060608501525091949350505050565b5f60c08236031215612192575f5ffd5b61219a611c60565b6121a43684611efb565b815260a08301356001600160401b038111156121be575f5ffd5b6121ca36828601611f96565b60208301525092915050565b5f82601f8301126121e5575f5ffd5b81356121f361200c82611f65565b80828252602082019150602060e08402860101925085831115612214575f5ffd5b602085015b8381101561223b5761222b8782611d23565b835260209092019160e001612219565b5095945050505050565b5f60608236031215612255575f5ffd5b61225d611bf4565b82356001600160401b03811115612272575f5ffd5b830136601f820112612282575f5ffd5b803561229061200c82611f65565b80828252602082019150602060a084028501019250368311156122b1575f5ffd5b6020840193505b828410156122dd576122ca3685611efb565b825260208201915060a0840193506122b8565b845250505060208301356001600160401b038111156122fa575f5ffd5b612306368286016121d6565b60208301525061231860408401611f87565b604082015292915050565b5f60608284031215612333575f5ffd5b6102e28383611ccc565b5f60a0828403121561234d575f5ffd5b6102e28383611efb565b5f8183036101a08112801561236a575f5ffd5b50612373611c3e565b61237c84611cb2565b815261238b8560208601611d23565b6020820152608060ff19830112156123a1575f5ffd5b6123a9611c3e565b91506123b86101008501611cb2565b8252610120840135600381106123cc575f5ffd5b60208301526123de6101408501611d0d565b60408301526123f06101608501611d0d565b606083810191909152604082019290925261018093909301359083015250919050565b5f6102e53683611f96565b602081525f6102e26020830184611b14565b60e081016102e58284611747565b634e487b7160e01b5f52603260045260245ffdfea2646970667358221220d99a3240d47537677c4b3ccec44b91d9e32c278e2550c20370eb62110eb3abb664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa$\x88\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xE5W_5`\xE0\x1C\x80cq\x98\x9Cv\x11a\0\x88W\x80c\xA3\xF5\xBBK\x11a\0cW\x80c\xA3\xF5\xBBK\x14a\x01\xE1W\x80c\xAF\xB6:\xD4\x14a\x01\xF4W\x80c\xB8\xB0.\x0E\x14a\x02TW\x80c\xED\xBA\xCDD\x14a\x02gW__\xFD[\x80cq\x98\x9Cv\x14a\x01\xA8W\x80cy\x89\xAA\x10\x14a\x01\xBBW\x80c\x85\xB6'\xA2\x14a\x01\xCEW__\xFD[\x80c(3\xBF)\x11a\0\xC3W\x80c(3\xBF)\x14a\x01BW\x80c/\x19i\xB0\x14a\x01UW\x80c]'\xCC\x95\x14a\x01uW\x80cev4\x83\x14a\x01\x95W__\xFD[\x80c\x01+_\xD7\x14a\0\xE9W\x80c!{\x8D\xA0\x14a\x01\x0FW\x80c&09b\x14a\x01\"W[__\xFD[a\0\xFCa\0\xF76`\x04a\x16RV[a\x02\x87V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\0\xFCa\x01\x1D6`\x04a\x16\xD1V[a\x02\xEBV[a\x015a\x0106`\x04a\x16\xEBV[a\x03\x03V[`@Qa\x01\x06\x91\x90a\x17\xB6V[a\0\xFCa\x01P6`\x04a\x18IV[a\x03IV[a\x01ha\x01c6`\x04a\x18rV[a\x03aV[`@Qa\x01\x06\x91\x90a\x18\x8CV[a\x01\x88a\x01\x836`\x04a\x16\xEBV[a\x03zV[`@Qa\x01\x06\x91\x90a\x19\x11V[a\x01ha\x01\xA36`\x04a\x1A8V[a\x03\xC0V[a\x01ha\x01\xB66`\x04a\x1A\x81V[a\x03\xD3V[a\0\xFCa\x01\xC96`\x04a\x1A\xB2V[a\x03\xE6V[a\0\xFCa\x01\xDC6`\x04a\x18rV[a\x03\xFEV[a\x01ha\x01\xEF6`\x04a\x1A\xCCV[a\x04\x16V[a\x02\x07a\x02\x026`\x04a\x16\xEBV[a\x04/V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\x01\x06V[a\0\xFCa\x02b6`\x04a\x1A\xDEV[a\x04\xA6V[a\x02za\x02u6`\x04a\x16\xEBV[a\x04\xB8V[`@Qa\x01\x06\x91\x90a\x1BYV[_a\x02\xE2\x83\x83\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x02\xD8Wa\x02\xC9`\xE0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a\x1D\x85V[\x81R` \x01\x90`\x01\x01\x90a\x02\xACV[PPPPPa\x05\x11V[\x90P[\x92\x91PPV[_a\x02\xE5a\x02\xFE6\x84\x90\x03\x84\x01\x84a\x1D\x9FV[a\x05@V[a\x03\x0Ba\x15SV[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x05\xB8\x92PPPV[_a\x02\xE5a\x03\\6\x84\x90\x03\x84\x01\x84a\x1D\x85V[a\x06\xEAV[``a\x02\xE5a\x03u6\x84\x90\x03\x84\x01\x84a\x1EkV[a\x06\xFCV[a\x03\x82a\x15\x8DV[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x07s\x92PPPV[``a\x02\xE5a\x03\xCE\x83a!\x82V[a\nHV[``a\x02\xE5a\x03\xE1\x83a\"EV[a\x0C\x1FV[_a\x02\xE5a\x03\xF96\x84\x90\x03\x84\x01\x84a##V[a\rMV[_a\x02\xE5a\x04\x116\x84\x90\x03\x84\x01\x84a#=V[a\r~V[``a\x02\xE5a\x04*6\x84\x90\x03\x84\x01\x84a#WV[a\x0E\x0CV[a\x04h`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x0F\x05\x92PPPV[_a\x02\xE5a\x04\xB3\x83a$\x13V[a\x0F\x8EV[`@\x80Q``\x80\x82\x01\x83R\x80\x82R` \x82\x01R_\x91\x81\x01\x91\x90\x91Ra\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x11\x93\x92PPPV[_\x81`@Q` \x01a\x05#\x91\x90a$\x1EV[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[_\x81`@Q` \x01a\x05#\x91\x90_`\xC0\x82\x01\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x84\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x84\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x84\x01Q\x16``\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x84\x01Q\x16`\x80\x83\x01R`\xA0\x83\x01Q`\xA0\x83\x01R\x92\x91PPV[a\x05\xC0a\x15SV[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x84\x1C\x90\x91R`l\x86\x01Q\x82Q\x82\x01Q\x90\x94\x01\x93\x90\x93R`\x8C\x85\x01Q\x81Q\x84\x01Q\x84\x01R`\xAC\x85\x01Q\x81Q``\x91\x82\x1C\x90\x82\x01R`\xC0\x86\x01Q\x91Q\x91\x90\x1C`\x80\x90\x91\x01R`\xD4\x84\x01Q\x91\x83\x01Q\x91\x90\x1C\x90R`\xDA\x82\x01Q`\xDB\x83\x01\x90`\xF8\x1C`\x02\x81\x11\x15a\x06sW`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\x06\x88Wa\x06\x88a\x17\xA2V[\x83`@\x01Q` \x01\x90`\x02\x81\x11\x15a\x06\xA2Wa\x06\xA2a\x17\xA2V[\x90\x81`\x02\x81\x11\x15a\x06\xB5Wa\x06\xB5a\x17\xA2V[\x90RPP\x80Q`@\x83\x81\x01\x80Q``\x93\x84\x1C\x92\x01\x91\x90\x91R`\x14\x83\x01Q\x90Q\x90\x82\x1C\x90\x82\x01R`(\x90\x91\x01Q\x90\x82\x01R\x91\x90PV[_\x81`@Q` \x01a\x05#\x91\x90a$0V[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x07k\x90\x82\x90a\x13\xACV[\x90PP\x91\x90PV[a\x07{a\x15\x8DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\tWa\x08\ta\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x08lW\x81` \x01[a\x08Y`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x08'W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n:W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x08\xB3Wa\x08\xB3a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xE6Wa\x08\xE6a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t\x0FW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\t*Wa\t*a$>V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\t\x9FW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\tgWa\tga$>V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\t\x87Wa\t\x87a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\t;V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\t\xC3Wa\t\xC3a$>V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\n\x05Wa\n\x05a$>V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x08xV[PPQ\x81Q`\x80\x01R\x91\x90PV[``_a\n\\\x83` \x01Q``\x01Qa\x13\xB8V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\nvWa\nva\x1B\xE0V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\n\xA0W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x0B\x0B\x90\x82\x90a\x13\xACV[` \x85\x01Q``\x01QQ\x90\x91Pa\x0B!\x81a\x14\x02V[a\x0B1\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x0C\x0FW_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x0BXWa\x0BXa$>V[` \x02` \x01\x01Q\x90Pa\x0B|\x84\x82_\x01Qa\x0BtW_a\x13\xACV[`\x01[a\x13\xACV[` \x82\x01QQQ\x90\x94Pa\x0B\x8F\x81a\x14\x02V[a\x0B\x9F\x85\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x94P_[\x81\x81\x10\x15a\x0B\xE2Wa\x0B\xD8\x86\x84` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0B\xC8Wa\x0B\xC8a$>V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x95P`\x01\x01a\x0B\xA3V[PP` \x90\x81\x01\x80Q\x90\x91\x01Q`\xE8\x1B\x84RQ`@\x01Q`\xD0\x1B`\x03\x84\x01R`\t\x90\x92\x01\x91`\x01\x01a\x0B5V[PP\x92Q`\x80\x01Q\x90\x92R\x91\x90PV[``_a\x0C3\x83_\x01Q\x84` \x01Qa\x14(V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0CMWa\x0CMa\x1B\xE0V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0CwW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x0C\x8C\x90a\x14\x02V[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x0C\xD3Wa\x0C\xC9\x82\x86_\x01Q\x83\x81Q\x81\x10a\x0C\xBCWa\x0C\xBCa$>V[` \x02` \x01\x01Qa\x14WV[\x91P`\x01\x01a\x0C\x99V[Pa\x0C\xE2\x84` \x01QQa\x14\x02V[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\r0Wa\r&\x82\x86` \x01Q\x83\x81Q\x81\x10a\r\x19Wa\r\x19a$>V[` \x02` \x01\x01Qa\x14\x9AV[\x91P`\x01\x01a\x0C\xF2V[Pa\rD\x81\x85`@\x01Qa\x0BtW_a\x13\xACV[\x90PPP\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\xE5V[`@\x80Q`\x05\x81R`\xC0\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x80\x82\x01R`\x80\x83\x01Q`\xA0\x82\x01R\x80Q`\x05\x1B` \x82\x01 a\x0E\x05\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x93\x92PPPV[`@\x80Qa\x01\x03\x80\x82Ra\x01@\x82\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x90\x81\x1B` \x84\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x86\x01R\x80Q\x82\x01Q`F\x86\x01R\x80Q`@\x90\x81\x01QQ\x84\x1B`f\x87\x01R\x81Q\x81\x01Q\x83\x01Q`l\x87\x01R\x81Q\x81\x01Q\x81\x01Q`\x8C\x87\x01R\x81Q``\x90\x81\x01Q\x81\x1B`\xAC\x88\x01R\x91Q`\x80\x01Q\x90\x91\x1B`\xC0\x86\x01R\x86\x01\x80QQ\x90\x92\x1B`\xD4\x85\x01R\x90Q\x01Q\x91\x92PP`\xDA\x82\x01\x90a\x0E\xC9\x90\x82\x90`\x02\x81\x11\x15a\x0BwWa\x0Bwa\x17\xA2V[`@\x80\x85\x01Q\x01Q``\x1B\x81R\x90P`\x14\x81\x01\x90Pa\x0E\xF6\x81\x84`@\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[``\x84\x01Q\x81R\x90PP\x91\x90PV[a\x0F>`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[``\x81\x01Q\x80Q_\x91\x90`\x06\x81\x01\x83[\x82\x81\x10\x15a\x0F\xDAW\x83\x81\x81Q\x81\x10a\x0F\xB8Wa\x0F\xB8a$>V[` \x02` \x01\x01Q` \x01Q_\x01QQ`\x06\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x0F\x9EV[P`@\x80Q\x82\x81R`\x01\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\xFF\x16`\x80\x82\x01R`\x80`\xA0\x82\x01R`\xC0\x81\x01\x83\x90R`\x06\x83\x81\x01_[\x85\x81\x10\x15a\x11`W_\x87\x82\x81Q\x81\x10a\x10JWa\x10Ja$>V[` \x02` \x01\x01Q\x90Pa\x10s\x85\x83\x86\x01`\x05\x87\x87\x03\x90\x1B_\x1B`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[Pa\x10\x9C\x85\x84\x83_\x01Qa\x10\x87W_a\x10\x8AV[`\x01[`\xFF\x16`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`@`\x02\x84\x01`\x05\x1B\x86\x01R```\x03\x84\x01`\x05\x1B\x86\x01R`\x02\x83\x01` \x80\x83\x01Q\x01Qb\xFF\xFF\xFF\x16`\x02\x82\x01`\x05\x1B\x87\x01R` \x82\x01Q`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x82\x01`\x05\x1B\x87\x01R` \x82\x01QQ\x80Q`\x04\x83\x01`\x05\x1B\x88\x01\x81\x90R`\x03\x83\x01_[\x82\x81\x10\x15a\x11IWa\x11@\x8A\x82\x84`\x01\x01\x01\x86\x84\x81Q\x81\x10a\x11)Wa\x11)a$>V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11\x05V[P\x01`\x01\x90\x81\x01\x95P\x93\x90\x93\x01\x92Pa\x10/\x91PPV[P\x82Q`\x05\x1B` \x84\x01 a\x11\x87\x84\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x98\x97PPPPPPPPV[`@\x80Q``\x80\x82\x01\x83R\x80\x82R` \x80\x83\x01\x91\x90\x91R_\x92\x82\x01\x92\x90\x92R\x90\x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x11\xD6Wa\x11\xD6a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x12-W\x81` \x01[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x11\xF4W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x12\xC8W`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x83\x81R`\x80\x85\x01\x93\x84R\x88Q`\xD0\x90\x81\x1C\x86R`\x06\x8A\x01Q\x81\x1C\x90\x96R`\x0C\x89\x01Q\x90\x95\x1C\x90\x91R`\x12\x87\x01Q\x90\x1C\x90\x92R`&\x85\x01Q\x90\x91R`F\x84\x01\x85Q\x80Q\x84\x90\x81\x10a\x12\xB0Wa\x12\xB0a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x122V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x12\xF8W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x13\x14Wa\x13\x14a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x13MW\x81` \x01[a\x13:a\x15\xE6V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x132W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x13\x98Wa\x13j\x84a\x14\xEFV[\x86` \x01Q\x83\x81Q\x81\x10a\x13\x80Wa\x13\x80a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x13UV[PP\x90Q`\xF8\x1C\x15\x15`@\x83\x01RP\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[`o_[\x82Q\x81\x10\x15a\x13\xFCW\x82\x81\x81Q\x81\x10a\x13\xD7Wa\x13\xD7a$>V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x13\xBCV[P\x91\x90PV[a\xFF\xFF\x81\x11\x15a\x14%W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[_\x81Q\x83Q\x14a\x14KW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPQ`\xF4\x02`\x05\x01\x90V[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01R`\x80\x81\x01Q`&\x83\x01\x90\x81R`F\x83\x01a\x02\xE2V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01R``\x80\x82\x01Q\x81\x1B`\x86\x84\x01R`\x80\x82\x01Q\x90\x1B`\x9A\x83\x01\x90\x81R`\xAE\x83\x01a\x02\xE2V[a\x14\xF7a\x15\xE6V[\x81Q\x81R` \x80\x83\x01Q\x81\x83\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R`\x86\x82\x01Q``\x90\x81\x1C\x81\x83\x01R`\x9A\x83\x01Q\x90\x1C`\x80\x82\x01R\x91`\xAE\x90\x91\x01\x90V[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a\x15ta\x15\xE6V[\x81R` \x01a\x15\x81a\x169V[\x81R` \x01_\x81RP\x90V[`@\x80Q`\xE0\x81\x01\x82R_\x91\x81\x01\x82\x81R``\x82\x01\x83\x90R`\x80\x82\x01\x83\x90R`\xA0\x82\x01\x83\x90R`\xC0\x82\x01\x92\x90\x92R\x90\x81\x90\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xA0\x01`@R\x80_\x81R` \x01_\x81R` \x01a\x16&`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x82\x01\x81\x90R`@\x90\x91\x01R\x90V[`@\x80Q`\x80\x81\x01\x90\x91R_\x80\x82R` \x82\x01\x90a\x16&V[__` \x83\x85\x03\x12\x15a\x16cW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16xW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x16\x88W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x9DW__\xFD[\x85` `\xE0\x83\x02\x84\x01\x01\x11\x15a\x16\xB1W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_`\xC0\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_`\xC0\x82\x84\x03\x12\x15a\x16\xE1W__\xFD[a\x02\xE2\x83\x83a\x16\xC1V[__` \x83\x85\x03\x12\x15a\x16\xFCW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17\x11W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x17!W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x176W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\x16\xB1W__\xFD[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82\x86\x01R\x91\x82\x01Q``\x80\x86\x01\x91\x90\x91R\x91\x01Q`\x80\x80\x85\x01\x91\x90\x91R\x90\x82\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16`\xA0\x85\x01R\x91\x01Q\x16`\xC0\x90\x91\x01RV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x83\x01Qa\x01\xA0\x83\x01\x91a\x17\xDA\x90\x84\x01\x82a\x17GV[P`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16a\x01\0\x84\x01R` \x81\x01Q`\x03\x81\x10a\x18\x11WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[a\x01 \x84\x01R`@\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01@\x85\x01R``\x91\x82\x01Q\x16a\x01`\x84\x01R\x92\x90\x92\x01Qa\x01\x80\x90\x91\x01R\x90V[_`\xE0\x82\x84\x03\x12\x80\x15a\x18ZW__\xFD[P\x90\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_`\xA0\x82\x84\x03\x12\x15a\x18\x82W__\xFD[a\x02\xE2\x83\x83a\x18bV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01RPPV[` \x81Ra\x19#` \x82\x01\x83Qa\x18\xC1V[` \x82\x81\x01Q`\xC0\x83\x81\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xE0\x84\x01R\x80\x82\x01Qa\x01\0\x84\x01R`@\x81\x01Q`\xFF\x16a\x01 \x84\x01R``\x01Q`\x80a\x01@\x84\x01R\x80Qa\x01`\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x01\x80`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a\x1A,W\x86\x84\x03a\x01\x7F\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a\x19\xF1W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x19\xCEV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a\x19\x86V[P\x91\x96\x95PPPPPPV[_` \x82\x84\x03\x12\x15a\x1AHW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A]W__\xFD[a\x1Ai\x84\x82\x85\x01a\x16\xC1V[\x94\x93PPPPV[_``\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\x91W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\xA6W__\xFD[a\x1Ai\x84\x82\x85\x01a\x1AqV[_``\x82\x84\x03\x12\x15a\x1A\xC2W__\xFD[a\x02\xE2\x83\x83a\x1AqV[_a\x01\xA0\x82\x84\x03\x12\x80\x15a\x18ZW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\xEEW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B\x03W__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a\x0E\x05W__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a\x1BOWa\x1B9\x86\x83Qa\x17GV[`\xE0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a\x1B&V[P\x93\x94\x93PPPPV[` \x80\x82R\x82Q``\x83\x83\x01R\x80Q`\x80\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90\x82\x90`\xA0\x85\x01\x90[\x80\x83\x10\x15a\x1B\xA8Wa\x1B\x91\x82\x85Qa\x18\xC1V[`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x1B~V[P` \x86\x01Q\x85\x82\x03`\x1F\x19\x01`@\x87\x01R\x92Pa\x1B\xC6\x81\x84a\x1B\x14V[\x92PPP`@\x84\x01Q\x15\x15``\x84\x01R\x80\x91PP\x92\x91PPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\xAAWa\x1C\xAAa\x1B\xE0V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a\x1C\xDCW__\xFD[a\x1C\xE4a\x1B\xF4V[\x90Pa\x1C\xEF\x82a\x1C\xB2V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x1C\xC7W__\xFD[_`\xE0\x82\x84\x03\x12\x15a\x1D3W__\xFD[a\x1D;a\x1C\x1CV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa\x1DX\x83`@\x84\x01a\x1C\xCCV[`@\x82\x01Ra\x1Di`\xA0\x83\x01a\x1D\rV[``\x82\x01Ra\x1Dz`\xC0\x83\x01a\x1D\rV[`\x80\x82\x01R\x92\x91PPV[_`\xE0\x82\x84\x03\x12\x15a\x1D\x95W__\xFD[a\x02\xE2\x83\x83a\x1D#V[_`\xC0\x82\x84\x03\x12\x80\x15a\x1D\xB0W__\xFD[P`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1D\xD3Wa\x1D\xD3a\x1B\xE0V[`@Ra\x1D\xDF\x83a\x1C\xB2V[\x81Ra\x1D\xED` \x84\x01a\x1C\xB2V[` \x82\x01Ra\x1D\xFE`@\x84\x01a\x1C\xB2V[`@\x82\x01Ra\x1E\x0F``\x84\x01a\x1C\xB2V[``\x82\x01Ra\x1E `\x80\x84\x01a\x1C\xB2V[`\x80\x82\x01R`\xA0\x92\x83\x015\x92\x81\x01\x92\x90\x92RP\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x805`\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x1E}W__\xFD[Pa\x1E\x86a\x1B\xF4V[a\x1E\x8F\x84a\x1C\xB2V[\x81R```\x1F\x19\x83\x01\x12\x15a\x1E\xA2W__\xFD[a\x1E\xAAa\x1B\xF4V[\x91Pa\x1E\xB8` \x85\x01a\x1E8V[\x82Ra\x1E\xC6`@\x85\x01a\x1E8V[` \x83\x01Ra\x1E\xD7``\x85\x01a\x1EIV[`@\x83\x01R\x81` \x82\x01Ra\x1E\xEE`\x80\x85\x01a\x1E[V[`@\x82\x01R\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x15a\x1F\x0BW__\xFD[a\x1F\x13a\x1C\x1CV[\x90Pa\x1F\x1E\x82a\x1C\xB2V[\x81Ra\x1F,` \x83\x01a\x1C\xB2V[` \x82\x01Ra\x1F=`@\x83\x01a\x1C\xB2V[`@\x82\x01Ra\x1FN``\x83\x01a\x1D\rV[``\x82\x01R`\x80\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1F}Wa\x1F}a\x1B\xE0V[P`\x05\x1B` \x01\x90V[\x805\x80\x15\x15\x81\x14a\x1C\xC7W__\xFD[_`\x80\x82\x84\x03\x12\x15a\x1F\xA6W__\xFD[a\x1F\xAEa\x1C>V[\x90Pa\x1F\xB9\x82a\x1C\xB2V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1F\xD1`@\x83\x01a\x1E[V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1F\xEEW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1F\xFEW__\xFD[\x805a \x11a \x0C\x82a\x1FeV[a\x1C\x82V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a 2W__\xFD[` \x84\x01[\x83\x81\x10\x15a!rW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a TW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a iW__\xFD[a qa\x1C`V[a }` \x83\x01a\x1F\x87V[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a \x97W__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a \xAFW__\xFD[a \xB7a\x1B\xF4V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a \xCCW__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a \xDCW__\xFD[\x805a \xEAa \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a!\x0BW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a!-W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a!\x12V[\x84RPa!?\x91PP` \x84\x01a\x1EIV[` \x82\x01Ra!P`@\x84\x01a\x1C\xB2V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa 7V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xC0\x826\x03\x12\x15a!\x92W__\xFD[a!\x9Aa\x1C`V[a!\xA46\x84a\x1E\xFBV[\x81R`\xA0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a!\xBEW__\xFD[a!\xCA6\x82\x86\x01a\x1F\x96V[` \x83\x01RP\x92\x91PPV[_\x82`\x1F\x83\x01\x12a!\xE5W__\xFD[\x815a!\xF3a \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` `\xE0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a\"\x14W__\xFD[` \x85\x01[\x83\x81\x10\x15a\";Wa\"+\x87\x82a\x1D#V[\x83R` \x90\x92\x01\x91`\xE0\x01a\"\x19V[P\x95\x94PPPPPV[_``\x826\x03\x12\x15a\"UW__\xFD[a\"]a\x1B\xF4V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\"rW__\xFD[\x83\x016`\x1F\x82\x01\x12a\"\x82W__\xFD[\x805a\"\x90a \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a\"\xB1W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\"\xDDWa\"\xCA6\x85a\x1E\xFBV[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa\"\xB8V[\x84RPPP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\"\xFAW__\xFD[a#\x066\x82\x86\x01a!\xD6V[` \x83\x01RPa#\x18`@\x84\x01a\x1F\x87V[`@\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a#3W__\xFD[a\x02\xE2\x83\x83a\x1C\xCCV[_`\xA0\x82\x84\x03\x12\x15a#MW__\xFD[a\x02\xE2\x83\x83a\x1E\xFBV[_\x81\x83\x03a\x01\xA0\x81\x12\x80\x15a#jW__\xFD[Pa#sa\x1C>V[a#|\x84a\x1C\xB2V[\x81Ra#\x8B\x85` \x86\x01a\x1D#V[` \x82\x01R`\x80`\xFF\x19\x83\x01\x12\x15a#\xA1W__\xFD[a#\xA9a\x1C>V[\x91Pa#\xB8a\x01\0\x85\x01a\x1C\xB2V[\x82Ra\x01 \x84\x015`\x03\x81\x10a#\xCCW__\xFD[` \x83\x01Ra#\xDEa\x01@\x85\x01a\x1D\rV[`@\x83\x01Ra#\xF0a\x01`\x85\x01a\x1D\rV[``\x83\x81\x01\x91\x90\x91R`@\x82\x01\x92\x90\x92Ra\x01\x80\x93\x90\x93\x015\x90\x83\x01RP\x91\x90PV[_a\x02\xE56\x83a\x1F\x96V[` \x81R_a\x02\xE2` \x83\x01\x84a\x1B\x14V[`\xE0\x81\x01a\x02\xE5\x82\x84a\x17GV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xA2dipfsX\"\x12 \xD9\x9A2@\xD4u7g|K<\xCE\xC4K\x91\xD9\xE3,'\x8E%P\xC2\x03p\xEBb\x11\x0E\xB3\xAB\xB6dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b50600436106100e5575f3560e01c806371989c7611610088578063a3f5bb4b11610063578063a3f5bb4b146101e1578063afb63ad4146101f4578063b8b02e0e14610254578063edbacd4414610267575f5ffd5b806371989c76146101a85780637989aa10146101bb57806385b627a2146101ce575f5ffd5b80632833bf29116100c35780632833bf29146101425780632f1969b0146101555780635d27cc95146101755780636576348314610195575f5ffd5b8063012b5fd7146100e9578063217b8da01461010f5780632630396214610122575b5f5ffd5b6100fc6100f7366004611652565b610287565b6040519081526020015b60405180910390f35b6100fc61011d3660046116d1565b6102eb565b6101356101303660046116eb565b610303565b60405161010691906117b6565b6100fc610150366004611849565b610349565b610168610163366004611872565b610361565b604051610106919061188c565b6101886101833660046116eb565b61037a565b6040516101069190611911565b6101686101a3366004611a38565b6103c0565b6101686101b6366004611a81565b6103d3565b6100fc6101c9366004611ab2565b6103e6565b6100fc6101dc366004611872565b6103fe565b6101686101ef366004611acc565b610416565b6102076102023660046116eb565b61042f565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a001610106565b6100fc610262366004611ade565b6104a6565b61027a6102753660046116eb565b6104b8565b6040516101069190611b59565b5f6102e28383808060200260200160405190810160405280939291908181526020015f905b828210156102d8576102c960e08302860136819003810190611d85565b815260200190600101906102ac565b5050505050610511565b90505b92915050565b5f6102e56102fe36849003840184611d9f565b610540565b61030b611553565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506105b892505050565b5f6102e561035c36849003840184611d85565b6106ea565b60606102e561037536849003840184611e6b565b6106fc565b61038261158d565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061077392505050565b60606102e56103ce83612182565b610a48565b60606102e56103e183612245565b610c1f565b5f6102e56103f936849003840184612323565b610d4d565b5f6102e56104113684900384018461233d565b610d7e565b60606102e561042a36849003840184612357565b610e0c565b61046860408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b6102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610f0592505050565b5f6102e56104b383612413565b610f8e565b604080516060808201835280825260208201525f918101919091526102e283838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061119392505050565b5f81604051602001610523919061241e565b604051602081830303815290604052805190602001209050919050565b5f8160405160200161052391905f60c08201905065ffffffffffff835116825265ffffffffffff602084015116602083015265ffffffffffff604084015116604083015265ffffffffffff606084015116606083015265ffffffffffff608084015116608083015260a083015160a083015292915050565b6105c0611553565b60208281015160d090811c83526026840151838301805191909152604685015181518401526066850151815160409081015191841c909152606c860151825182015190940193909352608c850151815184015184015260ac8501518151606091821c9082015260c0860151915191901c60809091015260d48401519183015191901c905260da82015160db83019060f81c600281111561067357604051631ed6413560e31b815260040160405180910390fd5b8060ff166002811115610688576106886117a2565b83604001516020019060028111156106a2576106a26117a2565b908160028111156106b5576106b56117a2565b90525050805160408381018051606093841c9201919091526014830151905190821c9082015260289091015190820152919050565b5f816040516020016105239190612430565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d82019061076b9082906113ac565b905050919050565b61077b61158d565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c90820152604685015184840180519190931c9052604c850151825190930192909252606c840151905160f89190911c910152606d820151606f83019060f01c806001600160401b0381111561080957610809611be0565b60405190808252806020026020018201604052801561086c57816020015b6108596040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b8152602001906001900390816108275790505b506020840151606001525f5b8161ffff16811015610a3a578251602085015160600151805160019095019460f89290921c918215159190849081106108b3576108b361243e565b60209081029190910101519015159052835160029094019360f01c806001600160401b038111156108e6576108e6611be0565b60405190808252806020026020018201604052801561090f578160200160208202803683370190505b50866020015160600151848151811061092a5761092a61243e565b6020908102919091018101510151525f5b8161ffff1681101561099f5785516020870188602001516060015186815181106109675761096761243e565b6020026020010151602001515f015183815181106109875761098761243e565b6020908102919091010191909152955060010161093b565b50845160e81c6003860187602001516060015185815181106109c3576109c361243e565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610a0557610a0561243e565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610878565b505051815160800152919050565b60605f610a5c8360200151606001516113b8565b9050806001600160401b03811115610a7657610a76611be0565b6040519080825280601f01601f191660200182016040528015610aa0576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b8185015281870180515190931b6046850152825190910151604c84015290510151909250606c830190610b0b9082906113ac565b60208501516060015151909150610b2181611402565b610b31828260f01b815260020190565b91505f5b81811015610c0f575f8660200151606001518281518110610b5857610b5861243e565b60200260200101519050610b7c84825f0151610b74575f6113ac565b60015b6113ac565b60208201515151909450610b8f81611402565b610b9f858260f01b815260020190565b94505f5b81811015610be257610bd88684602001515f01518381518110610bc857610bc861243e565b6020026020010151815260200190565b9550600101610ba3565b5050602090810180519091015160e81b8452516040015160d01b6003840152600990920191600101610b35565b5050925160800151909252919050565b60605f610c33835f01518460200151611428565b9050806001600160401b03811115610c4d57610c4d611be0565b6040519080825280601f01601f191660200182016040528015610c77576020820181803683370190505b508351519092506020830190610c8c90611402565b83515160f01b81526002015f5b845151811015610cd357610cc982865f01518381518110610cbc57610cbc61243e565b6020026020010151611457565b9150600101610c99565b50610ce2846020015151611402565b60208401515160f01b81526002015f5b846020015151811015610d3057610d268286602001518381518110610d1957610d1961243e565b602002602001015161149a565b9150600101610cf2565b50610d44818560400151610b74575f6113ac565b90505050919050565b8051602080830151604080850151815165ffffffffffff909516855292840191909152820152606090205f906102e5565b604080516005815260c08101909152815165ffffffffffff1660208201525f90602083015165ffffffffffff166040820152604083015165ffffffffffff16606082015260608301516001600160a01b03166080820152608083015160a0820152805160051b6020820120610e058280516040516001820160051b83011490151060061b52565b9392505050565b6040805161010380825261014082019092526060916020820181803683375050835160d090811b602084810191909152808601805151602686015280518201516046860152805160409081015151841b60668701528151810151830151606c8701528151810151810151608c8701528151606090810151811b60ac88015291516080015190911b60c0860152860180515190921b60d4850152905101519192505060da820190610ec99082906002811115610b7757610b776117a2565b604080850151015160601b81529050601481019050610ef68184604001516060015160601b815260140190565b60608401518152905050919050565b610f3e60408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b606081015180515f919060068101835b82811015610fda57838181518110610fb857610fb861243e565b6020026020010151602001515f01515160060182019150806001019050610f9e565b50604080518281526001830160051b8101909152602080820152855165ffffffffffff16604082015260208601516060820152604086015160ff166080820152608060a082015260c0810183905260068381015f5b85811015611160575f87828151811061104a5761104a61243e565b60200260200101519050611073858386016005878703901b5f1b60019190910160051b82015290565b5061109c8584835f0151611087575f61108a565b60015b60ff1660019190910160051b82015290565b5060406002840160051b86015260606003840160051b86015260028301602080830151015162ffffff166002820160051b87015260208201516040015165ffffffffffff166003820160051b87015260208201515180516004830160051b8801819052600383015f5b82811015611149576111408a8284600101018684815181106111295761112961243e565b602002602001015160019190910160051b82015290565b50600101611105565b50016001908101955093909301925061102f915050565b50825160051b60208401206111878480516040516001820160051b83011490151060061b52565b98975050505050505050565b60408051606080820183528082526020808301919091525f9282019290925290820151602283019060f01c806001600160401b038111156111d6576111d6611be0565b60405190808252806020026020018201604052801561122d57816020015b6040805160a0810182525f808252602080830182905292820181905260608201819052608082015282525f199092019101816111f45790505b5083525f5b8161ffff168110156112c8576040805160a0810182525f80825260208201818152928201818152606080840183815260808501938452885160d090811c865260068a0151811c909652600c89015190951c9091526012870151901c90925260268501519091526046840185518051849081106112b0576112b061243e565b60209081029190910101919091529250600101611232565b50815160029092019160f01c61ffff821681146112f857604051632e0b3ebf60e11b815260040160405180910390fd5b8061ffff166001600160401b0381111561131457611314611be0565b60405190808252806020026020018201604052801561134d57816020015b61133a6115e6565b8152602001906001900390816113325790505b5060208501525f5b8161ffff168110156113985761136a846114ef565b866020015183815181106113805761138061243e565b60209081029190910101919091529350600101611355565b5050905160f81c1515604083015250919050565b5f818353505060010190565b606f5f5b82518110156113fc578281815181106113d7576113d761243e565b6020026020010151602001515f015151602002600c01820191508060010190506113bc565b50919050565b61ffff8111156114255760405163161e7a6b60e11b815260040160405180910390fd5b50565b5f815183511461144b57604051632e0b3ebf60e11b815260040160405180910390fd5b50505160f40260050190565b805160d090811b83526020820151811b60068401526040820151901b600c830152606080820151901b6012830152608081015160268301908152604683016102e2565b8051825260208082015181840152604080830180515160d01b828601528051909201516046850152905101516066830152606080820151811b60868401526080820151901b609a830190815260ae83016102e2565b6114f76115e6565b8151815260208083015181830152604080840151818401805160d09290921c90915260468501518151909301929092526066840151915101526086820151606090811c81830152609a830151901c60808201529160ae90910190565b60405180608001604052805f65ffffffffffff1681526020016115746115e6565b8152602001611581611639565b81526020015f81525090565b6040805160e0810182525f918101828152606082018390526080820183905260a0820183905260c08201929092529081908152604080516080810182525f80825260208281018290529282015260608082015291015290565b6040518060a001604052805f81526020015f815260200161162660405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b81525f6020820181905260409091015290565b60408051608081019091525f8082526020820190611626565b5f5f60208385031215611663575f5ffd5b82356001600160401b03811115611678575f5ffd5b8301601f81018513611688575f5ffd5b80356001600160401b0381111561169d575f5ffd5b85602060e0830284010111156116b1575f5ffd5b6020919091019590945092505050565b5f60c082840312156113fc575f5ffd5b5f60c082840312156116e1575f5ffd5b6102e283836116c1565b5f5f602083850312156116fc575f5ffd5b82356001600160401b03811115611711575f5ffd5b8301601f81018513611721575f5ffd5b80356001600160401b03811115611736575f5ffd5b8560208284010111156116b1575f5ffd5b8051825260208082015181840152604080830151805165ffffffffffff168286015291820151606080860191909152910151608080850191909152908201516001600160a01b0390811660a08501529101511660c090910152565b634e487b7160e01b5f52602160045260245ffd5b815165ffffffffffff1681526020808301516101a08301916117da90840182611747565b50604083015165ffffffffffff81511661010084015260208101516003811061181157634e487b7160e01b5f52602160045260245ffd5b61012084015260408101516001600160a01b039081166101408501526060918201511661016084015292909201516101809091015290565b5f60e082840312801561185a575f5ffd5b509092915050565b5f60a082840312156113fc575f5ffd5b5f60a08284031215611882575f5ffd5b6102e28383611862565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b65ffffffffffff815116825265ffffffffffff602082015116602083015265ffffffffffff604082015116604083015260018060a01b036060820151166060830152608081015160808301525050565b602081526119236020820183516118c1565b60208281015160c083810152805165ffffffffffff1660e084015280820151610100840152604081015160ff16610120840152606001516080610140840152805161016084018190525f929190910190610180600582901b850181019190850190845b81811015611a2c5786840361017f19018352845180511515855260209081015160408287018190528151606091880191909152805160a08801819052919201905f9060c08801905b808310156119f157835182526020820191506020840193506001830192506119ce565b5060208481015162ffffff1660608a015260409094015165ffffffffffff166080909801979097525050948501949290920191600101611986565b50919695505050505050565b5f60208284031215611a48575f5ffd5b81356001600160401b03811115611a5d575f5ffd5b611a69848285016116c1565b949350505050565b5f606082840312156113fc575f5ffd5b5f60208284031215611a91575f5ffd5b81356001600160401b03811115611aa6575f5ffd5b611a6984828501611a71565b5f60608284031215611ac2575f5ffd5b6102e28383611a71565b5f6101a082840312801561185a575f5ffd5b5f60208284031215611aee575f5ffd5b81356001600160401b03811115611b03575f5ffd5b820160808185031215610e05575f5ffd5b5f8151808452602084019350602083015f5b82811015611b4f57611b39868351611747565b60e0959095019460209190910190600101611b26565b5093949350505050565b602080825282516060838301528051608084018190525f929190910190829060a08501905b80831015611ba857611b918285516118c1565b60a082019150602084019350600183019250611b7e565b506020860151858203601f190160408701529250611bc68184611b14565b925050506040840151151560608401528091505092915050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b0381118282101715611c1657611c16611be0565b60405290565b60405160a081016001600160401b0381118282101715611c1657611c16611be0565b604051608081016001600160401b0381118282101715611c1657611c16611be0565b604080519081016001600160401b0381118282101715611c1657611c16611be0565b604051601f8201601f191681016001600160401b0381118282101715611caa57611caa611be0565b604052919050565b803565ffffffffffff81168114611cc7575f5ffd5b919050565b5f60608284031215611cdc575f5ffd5b611ce4611bf4565b9050611cef82611cb2565b81526020828101359082015260409182013591810191909152919050565b80356001600160a01b0381168114611cc7575f5ffd5b5f60e08284031215611d33575f5ffd5b611d3b611c1c565b82358152602080840135908201529050611d588360408401611ccc565b6040820152611d6960a08301611d0d565b6060820152611d7a60c08301611d0d565b608082015292915050565b5f60e08284031215611d95575f5ffd5b6102e28383611d23565b5f60c0828403128015611db0575f5ffd5b5060405160c081016001600160401b0381118282101715611dd357611dd3611be0565b604052611ddf83611cb2565b8152611ded60208401611cb2565b6020820152611dfe60408401611cb2565b6040820152611e0f60608401611cb2565b6060820152611e2060808401611cb2565b608082015260a0928301359281019290925250919050565b803561ffff81168114611cc7575f5ffd5b803562ffffff81168114611cc7575f5ffd5b803560ff81168114611cc7575f5ffd5b5f81830360a081128015611e7d575f5ffd5b50611e86611bf4565b611e8f84611cb2565b81526060601f1983011215611ea2575f5ffd5b611eaa611bf4565b9150611eb860208501611e38565b8252611ec660408501611e38565b6020830152611ed760608501611e49565b6040830152816020820152611eee60808501611e5b565b6040820152949350505050565b5f60a08284031215611f0b575f5ffd5b611f13611c1c565b9050611f1e82611cb2565b8152611f2c60208301611cb2565b6020820152611f3d60408301611cb2565b6040820152611f4e60608301611d0d565b606082015260809182013591810191909152919050565b5f6001600160401b03821115611f7d57611f7d611be0565b5060051b60200190565b80358015158114611cc7575f5ffd5b5f60808284031215611fa6575f5ffd5b611fae611c3e565b9050611fb982611cb2565b815260208281013590820152611fd160408301611e5b565b604082015260608201356001600160401b03811115611fee575f5ffd5b8201601f81018413611ffe575f5ffd5b803561201161200c82611f65565b611c82565b8082825260208201915060208360051b850101925086831115612032575f5ffd5b602084015b838110156121725780356001600160401b03811115612054575f5ffd5b85016040818a03601f19011215612069575f5ffd5b612071611c60565b61207d60208301611f87565b815260408201356001600160401b03811115612097575f5ffd5b6020818401019250506060828b0312156120af575f5ffd5b6120b7611bf4565b82356001600160401b038111156120cc575f5ffd5b8301601f81018c136120dc575f5ffd5b80356120ea61200c82611f65565b8082825260208201915060208360051b85010192508e83111561210b575f5ffd5b6020840193505b8284101561212d578335825260209384019390910190612112565b84525061213f91505060208401611e49565b602082015261215060408401611cb2565b6040820152806020830152508085525050602083019250602081019050612037565b5060608501525091949350505050565b5f60c08236031215612192575f5ffd5b61219a611c60565b6121a43684611efb565b815260a08301356001600160401b038111156121be575f5ffd5b6121ca36828601611f96565b60208301525092915050565b5f82601f8301126121e5575f5ffd5b81356121f361200c82611f65565b80828252602082019150602060e08402860101925085831115612214575f5ffd5b602085015b8381101561223b5761222b8782611d23565b835260209092019160e001612219565b5095945050505050565b5f60608236031215612255575f5ffd5b61225d611bf4565b82356001600160401b03811115612272575f5ffd5b830136601f820112612282575f5ffd5b803561229061200c82611f65565b80828252602082019150602060a084028501019250368311156122b1575f5ffd5b6020840193505b828410156122dd576122ca3685611efb565b825260208201915060a0840193506122b8565b845250505060208301356001600160401b038111156122fa575f5ffd5b612306368286016121d6565b60208301525061231860408401611f87565b604082015292915050565b5f60608284031215612333575f5ffd5b6102e28383611ccc565b5f60a0828403121561234d575f5ffd5b6102e28383611efb565b5f8183036101a08112801561236a575f5ffd5b50612373611c3e565b61237c84611cb2565b815261238b8560208601611d23565b6020820152608060ff19830112156123a1575f5ffd5b6123a9611c3e565b91506123b86101008501611cb2565b8252610120840135600381106123cc575f5ffd5b60208301526123de6101408501611d0d565b60408301526123f06101608501611d0d565b606083810191909152604082019290925261018093909301359083015250919050565b5f6102e53683611f96565b602081525f6102e26020830184611b14565b60e081016102e58284611747565b634e487b7160e01b5f52603260045260245ffdfea2646970667358221220d99a3240d47537677c4b3ccec44b91d9e32c278e2550c20370eb62110eb3abb664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xE5W_5`\xE0\x1C\x80cq\x98\x9Cv\x11a\0\x88W\x80c\xA3\xF5\xBBK\x11a\0cW\x80c\xA3\xF5\xBBK\x14a\x01\xE1W\x80c\xAF\xB6:\xD4\x14a\x01\xF4W\x80c\xB8\xB0.\x0E\x14a\x02TW\x80c\xED\xBA\xCDD\x14a\x02gW__\xFD[\x80cq\x98\x9Cv\x14a\x01\xA8W\x80cy\x89\xAA\x10\x14a\x01\xBBW\x80c\x85\xB6'\xA2\x14a\x01\xCEW__\xFD[\x80c(3\xBF)\x11a\0\xC3W\x80c(3\xBF)\x14a\x01BW\x80c/\x19i\xB0\x14a\x01UW\x80c]'\xCC\x95\x14a\x01uW\x80cev4\x83\x14a\x01\x95W__\xFD[\x80c\x01+_\xD7\x14a\0\xE9W\x80c!{\x8D\xA0\x14a\x01\x0FW\x80c&09b\x14a\x01\"W[__\xFD[a\0\xFCa\0\xF76`\x04a\x16RV[a\x02\x87V[`@Q\x90\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[a\0\xFCa\x01\x1D6`\x04a\x16\xD1V[a\x02\xEBV[a\x015a\x0106`\x04a\x16\xEBV[a\x03\x03V[`@Qa\x01\x06\x91\x90a\x17\xB6V[a\0\xFCa\x01P6`\x04a\x18IV[a\x03IV[a\x01ha\x01c6`\x04a\x18rV[a\x03aV[`@Qa\x01\x06\x91\x90a\x18\x8CV[a\x01\x88a\x01\x836`\x04a\x16\xEBV[a\x03zV[`@Qa\x01\x06\x91\x90a\x19\x11V[a\x01ha\x01\xA36`\x04a\x1A8V[a\x03\xC0V[a\x01ha\x01\xB66`\x04a\x1A\x81V[a\x03\xD3V[a\0\xFCa\x01\xC96`\x04a\x1A\xB2V[a\x03\xE6V[a\0\xFCa\x01\xDC6`\x04a\x18rV[a\x03\xFEV[a\x01ha\x01\xEF6`\x04a\x1A\xCCV[a\x04\x16V[a\x02\x07a\x02\x026`\x04a\x16\xEBV[a\x04/V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\x01\x06V[a\0\xFCa\x02b6`\x04a\x1A\xDEV[a\x04\xA6V[a\x02za\x02u6`\x04a\x16\xEBV[a\x04\xB8V[`@Qa\x01\x06\x91\x90a\x1BYV[_a\x02\xE2\x83\x83\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x02\xD8Wa\x02\xC9`\xE0\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a\x1D\x85V[\x81R` \x01\x90`\x01\x01\x90a\x02\xACV[PPPPPa\x05\x11V[\x90P[\x92\x91PPV[_a\x02\xE5a\x02\xFE6\x84\x90\x03\x84\x01\x84a\x1D\x9FV[a\x05@V[a\x03\x0Ba\x15SV[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x05\xB8\x92PPPV[_a\x02\xE5a\x03\\6\x84\x90\x03\x84\x01\x84a\x1D\x85V[a\x06\xEAV[``a\x02\xE5a\x03u6\x84\x90\x03\x84\x01\x84a\x1EkV[a\x06\xFCV[a\x03\x82a\x15\x8DV[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x07s\x92PPPV[``a\x02\xE5a\x03\xCE\x83a!\x82V[a\nHV[``a\x02\xE5a\x03\xE1\x83a\"EV[a\x0C\x1FV[_a\x02\xE5a\x03\xF96\x84\x90\x03\x84\x01\x84a##V[a\rMV[_a\x02\xE5a\x04\x116\x84\x90\x03\x84\x01\x84a#=V[a\r~V[``a\x02\xE5a\x04*6\x84\x90\x03\x84\x01\x84a#WV[a\x0E\x0CV[a\x04h`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[a\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x0F\x05\x92PPPV[_a\x02\xE5a\x04\xB3\x83a$\x13V[a\x0F\x8EV[`@\x80Q``\x80\x82\x01\x83R\x80\x82R` \x82\x01R_\x91\x81\x01\x91\x90\x91Ra\x02\xE2\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x11\x93\x92PPPV[_\x81`@Q` \x01a\x05#\x91\x90a$\x1EV[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[_\x81`@Q` \x01a\x05#\x91\x90_`\xC0\x82\x01\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x84\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x84\x01Q\x16`@\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF``\x84\x01Q\x16``\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x84\x01Q\x16`\x80\x83\x01R`\xA0\x83\x01Q`\xA0\x83\x01R\x92\x91PPV[a\x05\xC0a\x15SV[` \x82\x81\x01Q`\xD0\x90\x81\x1C\x83R`&\x84\x01Q\x83\x83\x01\x80Q\x91\x90\x91R`F\x85\x01Q\x81Q\x84\x01R`f\x85\x01Q\x81Q`@\x90\x81\x01Q\x91\x84\x1C\x90\x91R`l\x86\x01Q\x82Q\x82\x01Q\x90\x94\x01\x93\x90\x93R`\x8C\x85\x01Q\x81Q\x84\x01Q\x84\x01R`\xAC\x85\x01Q\x81Q``\x91\x82\x1C\x90\x82\x01R`\xC0\x86\x01Q\x91Q\x91\x90\x1C`\x80\x90\x91\x01R`\xD4\x84\x01Q\x91\x83\x01Q\x91\x90\x1C\x90R`\xDA\x82\x01Q`\xDB\x83\x01\x90`\xF8\x1C`\x02\x81\x11\x15a\x06sW`@Qc\x1E\xD6A5`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\xFF\x16`\x02\x81\x11\x15a\x06\x88Wa\x06\x88a\x17\xA2V[\x83`@\x01Q` \x01\x90`\x02\x81\x11\x15a\x06\xA2Wa\x06\xA2a\x17\xA2V[\x90\x81`\x02\x81\x11\x15a\x06\xB5Wa\x06\xB5a\x17\xA2V[\x90RPP\x80Q`@\x83\x81\x01\x80Q``\x93\x84\x1C\x92\x01\x91\x90\x91R`\x14\x83\x01Q\x90Q\x90\x82\x1C\x90\x82\x01R`(\x90\x91\x01Q\x90\x82\x01R\x91\x90PV[_\x81`@Q` \x01a\x05#\x91\x90a$0V[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x07k\x90\x82\x90a\x13\xACV[\x90PP\x91\x90PV[a\x07{a\x15\x8DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`L\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`l\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`m\x82\x01Q`o\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\tWa\x08\ta\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x08lW\x81` \x01[a\x08Y`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x08'W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\n:W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\x08\xB3Wa\x08\xB3a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x08\xE6Wa\x08\xE6a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\t\x0FW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\t*Wa\t*a$>V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\t\x9FW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\tgWa\tga$>V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\t\x87Wa\t\x87a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\t;V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\t\xC3Wa\t\xC3a$>V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\n\x05Wa\n\x05a$>V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\x08xV[PPQ\x81Q`\x80\x01R\x91\x90PV[``_a\n\\\x83` \x01Q``\x01Qa\x13\xB8V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\nvWa\nva\x1B\xE0V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\n\xA0W` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`F\x85\x01R\x82Q\x90\x91\x01Q`L\x84\x01R\x90Q\x01Q\x90\x92P`l\x83\x01\x90a\x0B\x0B\x90\x82\x90a\x13\xACV[` \x85\x01Q``\x01QQ\x90\x91Pa\x0B!\x81a\x14\x02V[a\x0B1\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\x0C\x0FW_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\x0BXWa\x0BXa$>V[` \x02` \x01\x01Q\x90Pa\x0B|\x84\x82_\x01Qa\x0BtW_a\x13\xACV[`\x01[a\x13\xACV[` \x82\x01QQQ\x90\x94Pa\x0B\x8F\x81a\x14\x02V[a\x0B\x9F\x85\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x94P_[\x81\x81\x10\x15a\x0B\xE2Wa\x0B\xD8\x86\x84` \x01Q_\x01Q\x83\x81Q\x81\x10a\x0B\xC8Wa\x0B\xC8a$>V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x95P`\x01\x01a\x0B\xA3V[PP` \x90\x81\x01\x80Q\x90\x91\x01Q`\xE8\x1B\x84RQ`@\x01Q`\xD0\x1B`\x03\x84\x01R`\t\x90\x92\x01\x91`\x01\x01a\x0B5V[PP\x92Q`\x80\x01Q\x90\x92R\x91\x90PV[``_a\x0C3\x83_\x01Q\x84` \x01Qa\x14(V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0CMWa\x0CMa\x1B\xE0V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0CwW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ\x90\x92P` \x83\x01\x90a\x0C\x8C\x90a\x14\x02V[\x83QQ`\xF0\x1B\x81R`\x02\x01_[\x84QQ\x81\x10\x15a\x0C\xD3Wa\x0C\xC9\x82\x86_\x01Q\x83\x81Q\x81\x10a\x0C\xBCWa\x0C\xBCa$>V[` \x02` \x01\x01Qa\x14WV[\x91P`\x01\x01a\x0C\x99V[Pa\x0C\xE2\x84` \x01QQa\x14\x02V[` \x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84` \x01QQ\x81\x10\x15a\r0Wa\r&\x82\x86` \x01Q\x83\x81Q\x81\x10a\r\x19Wa\r\x19a$>V[` \x02` \x01\x01Qa\x14\x9AV[\x91P`\x01\x01a\x0C\xF2V[Pa\rD\x81\x85`@\x01Qa\x0BtW_a\x13\xACV[\x90PPP\x91\x90PV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R\x92\x84\x01\x91\x90\x91R\x82\x01R``\x90 _\x90a\x02\xE5V[`@\x80Q`\x05\x81R`\xC0\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x80\x82\x01R`\x80\x83\x01Q`\xA0\x82\x01R\x80Q`\x05\x1B` \x82\x01 a\x0E\x05\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x93\x92PPPV[`@\x80Qa\x01\x03\x80\x82Ra\x01@\x82\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x90\x81\x1B` \x84\x81\x01\x91\x90\x91R\x80\x86\x01\x80QQ`&\x86\x01R\x80Q\x82\x01Q`F\x86\x01R\x80Q`@\x90\x81\x01QQ\x84\x1B`f\x87\x01R\x81Q\x81\x01Q\x83\x01Q`l\x87\x01R\x81Q\x81\x01Q\x81\x01Q`\x8C\x87\x01R\x81Q``\x90\x81\x01Q\x81\x1B`\xAC\x88\x01R\x91Q`\x80\x01Q\x90\x91\x1B`\xC0\x86\x01R\x86\x01\x80QQ\x90\x92\x1B`\xD4\x85\x01R\x90Q\x01Q\x91\x92PP`\xDA\x82\x01\x90a\x0E\xC9\x90\x82\x90`\x02\x81\x11\x15a\x0BwWa\x0Bwa\x17\xA2V[`@\x80\x85\x01Q\x01Q``\x1B\x81R\x90P`\x14\x81\x01\x90Pa\x0E\xF6\x81\x84`@\x01Q``\x01Q``\x1B\x81R`\x14\x01\x90V[``\x84\x01Q\x81R\x90PP\x91\x90PV[a\x0F>`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[``\x81\x01Q\x80Q_\x91\x90`\x06\x81\x01\x83[\x82\x81\x10\x15a\x0F\xDAW\x83\x81\x81Q\x81\x10a\x0F\xB8Wa\x0F\xB8a$>V[` \x02` \x01\x01Q` \x01Q_\x01QQ`\x06\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x0F\x9EV[P`@\x80Q\x82\x81R`\x01\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\xFF\x16`\x80\x82\x01R`\x80`\xA0\x82\x01R`\xC0\x81\x01\x83\x90R`\x06\x83\x81\x01_[\x85\x81\x10\x15a\x11`W_\x87\x82\x81Q\x81\x10a\x10JWa\x10Ja$>V[` \x02` \x01\x01Q\x90Pa\x10s\x85\x83\x86\x01`\x05\x87\x87\x03\x90\x1B_\x1B`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[Pa\x10\x9C\x85\x84\x83_\x01Qa\x10\x87W_a\x10\x8AV[`\x01[`\xFF\x16`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`@`\x02\x84\x01`\x05\x1B\x86\x01R```\x03\x84\x01`\x05\x1B\x86\x01R`\x02\x83\x01` \x80\x83\x01Q\x01Qb\xFF\xFF\xFF\x16`\x02\x82\x01`\x05\x1B\x87\x01R` \x82\x01Q`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x82\x01`\x05\x1B\x87\x01R` \x82\x01QQ\x80Q`\x04\x83\x01`\x05\x1B\x88\x01\x81\x90R`\x03\x83\x01_[\x82\x81\x10\x15a\x11IWa\x11@\x8A\x82\x84`\x01\x01\x01\x86\x84\x81Q\x81\x10a\x11)Wa\x11)a$>V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11\x05V[P\x01`\x01\x90\x81\x01\x95P\x93\x90\x93\x01\x92Pa\x10/\x91PPV[P\x82Q`\x05\x1B` \x84\x01 a\x11\x87\x84\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x98\x97PPPPPPPPV[`@\x80Q``\x80\x82\x01\x83R\x80\x82R` \x80\x83\x01\x91\x90\x91R_\x92\x82\x01\x92\x90\x92R\x90\x82\x01Q`\"\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x11\xD6Wa\x11\xD6a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x12-W\x81` \x01[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01\x81\x90R`\x80\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x11\xF4W\x90P[P\x83R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x12\xC8W`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x83\x81R`\x80\x85\x01\x93\x84R\x88Q`\xD0\x90\x81\x1C\x86R`\x06\x8A\x01Q\x81\x1C\x90\x96R`\x0C\x89\x01Q\x90\x95\x1C\x90\x91R`\x12\x87\x01Q\x90\x1C\x90\x92R`&\x85\x01Q\x90\x91R`F\x84\x01\x85Q\x80Q\x84\x90\x81\x10a\x12\xB0Wa\x12\xB0a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x122V[P\x81Q`\x02\x90\x92\x01\x91`\xF0\x1Ca\xFF\xFF\x82\x16\x81\x14a\x12\xF8W`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80a\xFF\xFF\x16`\x01`\x01`@\x1B\x03\x81\x11\x15a\x13\x14Wa\x13\x14a\x1B\xE0V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x13MW\x81` \x01[a\x13:a\x15\xE6V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\x132W\x90P[P` \x85\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x13\x98Wa\x13j\x84a\x14\xEFV[\x86` \x01Q\x83\x81Q\x81\x10a\x13\x80Wa\x13\x80a$>V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x93P`\x01\x01a\x13UV[PP\x90Q`\xF8\x1C\x15\x15`@\x83\x01RP\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[`o_[\x82Q\x81\x10\x15a\x13\xFCW\x82\x81\x81Q\x81\x10a\x13\xD7Wa\x13\xD7a$>V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x13\xBCV[P\x91\x90PV[a\xFF\xFF\x81\x11\x15a\x14%W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[_\x81Q\x83Q\x14a\x14KW`@Qc.\x0B>\xBF`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPQ`\xF4\x02`\x05\x01\x90V[\x80Q`\xD0\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x06\x84\x01R`@\x82\x01Q\x90\x1B`\x0C\x83\x01R``\x80\x82\x01Q\x90\x1B`\x12\x83\x01R`\x80\x81\x01Q`&\x83\x01\x90\x81R`F\x83\x01a\x02\xE2V[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01\x80QQ`\xD0\x1B\x82\x86\x01R\x80Q\x90\x92\x01Q`F\x85\x01R\x90Q\x01Q`f\x83\x01R``\x80\x82\x01Q\x81\x1B`\x86\x84\x01R`\x80\x82\x01Q\x90\x1B`\x9A\x83\x01\x90\x81R`\xAE\x83\x01a\x02\xE2V[a\x14\xF7a\x15\xE6V[\x81Q\x81R` \x80\x83\x01Q\x81\x83\x01R`@\x80\x84\x01Q\x81\x84\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`F\x85\x01Q\x81Q\x90\x93\x01\x92\x90\x92R`f\x84\x01Q\x91Q\x01R`\x86\x82\x01Q``\x90\x81\x1C\x81\x83\x01R`\x9A\x83\x01Q\x90\x1C`\x80\x82\x01R\x91`\xAE\x90\x91\x01\x90V[`@Q\x80`\x80\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01a\x15ta\x15\xE6V[\x81R` \x01a\x15\x81a\x169V[\x81R` \x01_\x81RP\x90V[`@\x80Q`\xE0\x81\x01\x82R_\x91\x81\x01\x82\x81R``\x82\x01\x83\x90R`\x80\x82\x01\x83\x90R`\xA0\x82\x01\x83\x90R`\xC0\x82\x01\x92\x90\x92R\x90\x81\x90\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xA0\x01`@R\x80_\x81R` \x01_\x81R` \x01a\x16&`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x81R_` \x82\x01\x81\x90R`@\x90\x91\x01R\x90V[`@\x80Q`\x80\x81\x01\x90\x91R_\x80\x82R` \x82\x01\x90a\x16&V[__` \x83\x85\x03\x12\x15a\x16cW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16xW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x16\x88W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x9DW__\xFD[\x85` `\xE0\x83\x02\x84\x01\x01\x11\x15a\x16\xB1W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_`\xC0\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_`\xC0\x82\x84\x03\x12\x15a\x16\xE1W__\xFD[a\x02\xE2\x83\x83a\x16\xC1V[__` \x83\x85\x03\x12\x15a\x16\xFCW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17\x11W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x17!W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x176W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\x16\xB1W__\xFD[\x80Q\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01Q\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82\x86\x01R\x91\x82\x01Q``\x80\x86\x01\x91\x90\x91R\x91\x01Q`\x80\x80\x85\x01\x91\x90\x91R\x90\x82\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16`\xA0\x85\x01R\x91\x01Q\x16`\xC0\x90\x91\x01RV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x83\x01Qa\x01\xA0\x83\x01\x91a\x17\xDA\x90\x84\x01\x82a\x17GV[P`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16a\x01\0\x84\x01R` \x81\x01Q`\x03\x81\x10a\x18\x11WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[a\x01 \x84\x01R`@\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16a\x01@\x85\x01R``\x91\x82\x01Q\x16a\x01`\x84\x01R\x92\x90\x92\x01Qa\x01\x80\x90\x91\x01R\x90V[_`\xE0\x82\x84\x03\x12\x80\x15a\x18ZW__\xFD[P\x90\x92\x91PPV[_`\xA0\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_`\xA0\x82\x84\x03\x12\x15a\x18\x82W__\xFD[a\x02\xE2\x83\x83a\x18bV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x83\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16``\x83\x01R`\x80\x81\x01Q`\x80\x83\x01RPPV[` \x81Ra\x19#` \x82\x01\x83Qa\x18\xC1V[` \x82\x81\x01Q`\xC0\x83\x81\x01R\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xE0\x84\x01R\x80\x82\x01Qa\x01\0\x84\x01R`@\x81\x01Q`\xFF\x16a\x01 \x84\x01R``\x01Q`\x80a\x01@\x84\x01R\x80Qa\x01`\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90a\x01\x80`\x05\x82\x90\x1B\x85\x01\x81\x01\x91\x90\x85\x01\x90\x84[\x81\x81\x10\x15a\x1A,W\x86\x84\x03a\x01\x7F\x19\x01\x83R\x84Q\x80Q\x15\x15\x85R` \x90\x81\x01Q`@\x82\x87\x01\x81\x90R\x81Q``\x91\x88\x01\x91\x90\x91R\x80Q`\xA0\x88\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x88\x01\x90[\x80\x83\x10\x15a\x19\xF1W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x19\xCEV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8A\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x98\x01\x97\x90\x97RPP\x94\x85\x01\x94\x92\x90\x92\x01\x91`\x01\x01a\x19\x86V[P\x91\x96\x95PPPPPPV[_` \x82\x84\x03\x12\x15a\x1AHW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A]W__\xFD[a\x1Ai\x84\x82\x85\x01a\x16\xC1V[\x94\x93PPPPV[_``\x82\x84\x03\x12\x15a\x13\xFCW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\x91W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1A\xA6W__\xFD[a\x1Ai\x84\x82\x85\x01a\x1AqV[_``\x82\x84\x03\x12\x15a\x1A\xC2W__\xFD[a\x02\xE2\x83\x83a\x1AqV[_a\x01\xA0\x82\x84\x03\x12\x80\x15a\x18ZW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\xEEW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B\x03W__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a\x0E\x05W__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a\x1BOWa\x1B9\x86\x83Qa\x17GV[`\xE0\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a\x1B&V[P\x93\x94\x93PPPPV[` \x80\x82R\x82Q``\x83\x83\x01R\x80Q`\x80\x84\x01\x81\x90R_\x92\x91\x90\x91\x01\x90\x82\x90`\xA0\x85\x01\x90[\x80\x83\x10\x15a\x1B\xA8Wa\x1B\x91\x82\x85Qa\x18\xC1V[`\xA0\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x1B~V[P` \x86\x01Q\x85\x82\x03`\x1F\x19\x01`@\x87\x01R\x92Pa\x1B\xC6\x81\x84a\x1B\x14V[\x92PPP`@\x84\x01Q\x15\x15``\x84\x01R\x80\x91PP\x92\x91PPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\x16Wa\x1C\x16a\x1B\xE0V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\xAAWa\x1C\xAAa\x1B\xE0V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x91\x90PV[_``\x82\x84\x03\x12\x15a\x1C\xDCW__\xFD[a\x1C\xE4a\x1B\xF4V[\x90Pa\x1C\xEF\x82a\x1C\xB2V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x1C\xC7W__\xFD[_`\xE0\x82\x84\x03\x12\x15a\x1D3W__\xFD[a\x1D;a\x1C\x1CV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90Pa\x1DX\x83`@\x84\x01a\x1C\xCCV[`@\x82\x01Ra\x1Di`\xA0\x83\x01a\x1D\rV[``\x82\x01Ra\x1Dz`\xC0\x83\x01a\x1D\rV[`\x80\x82\x01R\x92\x91PPV[_`\xE0\x82\x84\x03\x12\x15a\x1D\x95W__\xFD[a\x02\xE2\x83\x83a\x1D#V[_`\xC0\x82\x84\x03\x12\x80\x15a\x1D\xB0W__\xFD[P`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1D\xD3Wa\x1D\xD3a\x1B\xE0V[`@Ra\x1D\xDF\x83a\x1C\xB2V[\x81Ra\x1D\xED` \x84\x01a\x1C\xB2V[` \x82\x01Ra\x1D\xFE`@\x84\x01a\x1C\xB2V[`@\x82\x01Ra\x1E\x0F``\x84\x01a\x1C\xB2V[``\x82\x01Ra\x1E `\x80\x84\x01a\x1C\xB2V[`\x80\x82\x01R`\xA0\x92\x83\x015\x92\x81\x01\x92\x90\x92RP\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[\x805`\xFF\x81\x16\x81\x14a\x1C\xC7W__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x1E}W__\xFD[Pa\x1E\x86a\x1B\xF4V[a\x1E\x8F\x84a\x1C\xB2V[\x81R```\x1F\x19\x83\x01\x12\x15a\x1E\xA2W__\xFD[a\x1E\xAAa\x1B\xF4V[\x91Pa\x1E\xB8` \x85\x01a\x1E8V[\x82Ra\x1E\xC6`@\x85\x01a\x1E8V[` \x83\x01Ra\x1E\xD7``\x85\x01a\x1EIV[`@\x83\x01R\x81` \x82\x01Ra\x1E\xEE`\x80\x85\x01a\x1E[V[`@\x82\x01R\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x15a\x1F\x0BW__\xFD[a\x1F\x13a\x1C\x1CV[\x90Pa\x1F\x1E\x82a\x1C\xB2V[\x81Ra\x1F,` \x83\x01a\x1C\xB2V[` \x82\x01Ra\x1F=`@\x83\x01a\x1C\xB2V[`@\x82\x01Ra\x1FN``\x83\x01a\x1D\rV[``\x82\x01R`\x80\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1F}Wa\x1F}a\x1B\xE0V[P`\x05\x1B` \x01\x90V[\x805\x80\x15\x15\x81\x14a\x1C\xC7W__\xFD[_`\x80\x82\x84\x03\x12\x15a\x1F\xA6W__\xFD[a\x1F\xAEa\x1C>V[\x90Pa\x1F\xB9\x82a\x1C\xB2V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1F\xD1`@\x83\x01a\x1E[V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1F\xEEW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1F\xFEW__\xFD[\x805a \x11a \x0C\x82a\x1FeV[a\x1C\x82V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a 2W__\xFD[` \x84\x01[\x83\x81\x10\x15a!rW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a TW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a iW__\xFD[a qa\x1C`V[a }` \x83\x01a\x1F\x87V[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a \x97W__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a \xAFW__\xFD[a \xB7a\x1B\xF4V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a \xCCW__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a \xDCW__\xFD[\x805a \xEAa \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a!\x0BW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a!-W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a!\x12V[\x84RPa!?\x91PP` \x84\x01a\x1EIV[` \x82\x01Ra!P`@\x84\x01a\x1C\xB2V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa 7V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xC0\x826\x03\x12\x15a!\x92W__\xFD[a!\x9Aa\x1C`V[a!\xA46\x84a\x1E\xFBV[\x81R`\xA0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a!\xBEW__\xFD[a!\xCA6\x82\x86\x01a\x1F\x96V[` \x83\x01RP\x92\x91PPV[_\x82`\x1F\x83\x01\x12a!\xE5W__\xFD[\x815a!\xF3a \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` `\xE0\x84\x02\x86\x01\x01\x92P\x85\x83\x11\x15a\"\x14W__\xFD[` \x85\x01[\x83\x81\x10\x15a\";Wa\"+\x87\x82a\x1D#V[\x83R` \x90\x92\x01\x91`\xE0\x01a\"\x19V[P\x95\x94PPPPPV[_``\x826\x03\x12\x15a\"UW__\xFD[a\"]a\x1B\xF4V[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\"rW__\xFD[\x83\x016`\x1F\x82\x01\x12a\"\x82W__\xFD[\x805a\"\x90a \x0C\x82a\x1FeV[\x80\x82\x82R` \x82\x01\x91P` `\xA0\x84\x02\x85\x01\x01\x92P6\x83\x11\x15a\"\xB1W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\"\xDDWa\"\xCA6\x85a\x1E\xFBV[\x82R` \x82\x01\x91P`\xA0\x84\x01\x93Pa\"\xB8V[\x84RPPP` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\"\xFAW__\xFD[a#\x066\x82\x86\x01a!\xD6V[` \x83\x01RPa#\x18`@\x84\x01a\x1F\x87V[`@\x82\x01R\x92\x91PPV[_``\x82\x84\x03\x12\x15a#3W__\xFD[a\x02\xE2\x83\x83a\x1C\xCCV[_`\xA0\x82\x84\x03\x12\x15a#MW__\xFD[a\x02\xE2\x83\x83a\x1E\xFBV[_\x81\x83\x03a\x01\xA0\x81\x12\x80\x15a#jW__\xFD[Pa#sa\x1C>V[a#|\x84a\x1C\xB2V[\x81Ra#\x8B\x85` \x86\x01a\x1D#V[` \x82\x01R`\x80`\xFF\x19\x83\x01\x12\x15a#\xA1W__\xFD[a#\xA9a\x1C>V[\x91Pa#\xB8a\x01\0\x85\x01a\x1C\xB2V[\x82Ra\x01 \x84\x015`\x03\x81\x10a#\xCCW__\xFD[` \x83\x01Ra#\xDEa\x01@\x85\x01a\x1D\rV[`@\x83\x01Ra#\xF0a\x01`\x85\x01a\x1D\rV[``\x83\x81\x01\x91\x90\x91R`@\x82\x01\x92\x90\x92Ra\x01\x80\x93\x90\x93\x015\x90\x83\x01RP\x91\x90PV[_a\x02\xE56\x83a\x1F\x96V[` \x81R_a\x02\xE2` \x83\x01\x84a\x1B\x14V[`\xE0\x81\x01a\x02\xE5\x82\x84a\x17GV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xA2dipfsX\"\x12 \xD9\x9A2@\xD4u7g|K<\xCE\xC4K\x91\xD9\xE3,'\x8E%P\xC2\x03p\xEBb\x11\x0E\xB3\xAB\xB6dsolcC\0\x08\x1E\x003",
    );
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `encodeProposeInput((uint48,(uint16,uint16,uint24),uint8))` and selector `0x2f1969b0`.
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
    ///Container type for the return parameters of the [`encodeProposeInput((uint48,(uint16,uint16,uint24),uint8))`](encodeProposeInputCall) function.
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
            const SIGNATURE: &'static str = "encodeProposeInput((uint48,(uint16,uint16,uint24),uint8))";
            const SELECTOR: [u8; 4] = [47u8, 25u8, 105u8, 176u8];
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
    /**Function with signature `encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))` and selector `0x65763483`.
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
    ///Container type for the return parameters of the [`encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))`](encodeProposedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))";
            const SELECTOR: [u8; 4] = [101u8, 118u8, 52u8, 131u8];
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
    /**Function with signature `encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],bool))` and selector `0x71989c76`.
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
    ///Container type for the return parameters of the [`encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],bool))`](encodeProveInputCall) function.
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
            const SIGNATURE: &'static str = "encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],bool))";
            const SELECTOR: [u8; 4] = [113u8, 152u8, 156u8, 118u8];
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
    /**Function with signature `encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32))` and selector `0xa3f5bb4b`.
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
    ///Container type for the return parameters of the [`encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32))`](encodeProvedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32))";
            const SELECTOR: [u8; 4] = [163u8, 245u8, 187u8, 75u8];
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
    /**Function with signature `hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32))` and selector `0x217b8da0`.
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
    ///Container type for the return parameters of the [`hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32))`](hashCoreStateCall) function.
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
            const SIGNATURE: &'static str = "hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32))";
            const SELECTOR: [u8; 4] = [33u8, 123u8, 141u8, 160u8];
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
    /**Function with signature `hashProposal((uint48,uint48,uint48,address,bytes32))` and selector `0x85b627a2`.
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
    ///Container type for the return parameters of the [`hashProposal((uint48,uint48,uint48,address,bytes32))`](hashProposalCall) function.
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
            const SIGNATURE: &'static str = "hashProposal((uint48,uint48,uint48,address,bytes32))";
            const SELECTOR: [u8; 4] = [133u8, 182u8, 39u8, 162u8];
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
    /**Function with signature `hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address))` and selector `0x2833bf29`.
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
    ///Container type for the return parameters of the [`hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address))`](hashTransitionCall) function.
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
            const SIGNATURE: &'static str = "hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address))";
            const SELECTOR: [u8; 4] = [40u8, 51u8, 191u8, 41u8];
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[])` and selector `0x012b5fd7`.
```solidity
function hashTransitions(IInbox.Transition[] memory _transitions) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionsCall {
        #[allow(missing_docs)]
        pub _transitions: alloy::sol_types::private::Vec<
            <IInbox::Transition as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[])`](hashTransitionsCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashTransitionsReturn {
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
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Vec<
                    <IInbox::Transition as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<hashTransitionsCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionsCall) -> Self {
                    (value._transitions,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashTransitionsCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _transitions: tuple.0 }
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
            impl ::core::convert::From<hashTransitionsReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashTransitionsReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashTransitionsReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashTransitionsCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Array<IInbox::Transition>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[])";
            const SELECTOR: [u8; 4] = [1u8, 43u8, 95u8, 215u8];
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
                        let r: hashTransitionsReturn = r.into();
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
                        let r: hashTransitionsReturn = r.into();
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
        hashTransitions(hashTransitionsCall),
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
            [1u8, 43u8, 95u8, 215u8],
            [33u8, 123u8, 141u8, 160u8],
            [38u8, 48u8, 57u8, 98u8],
            [40u8, 51u8, 191u8, 41u8],
            [47u8, 25u8, 105u8, 176u8],
            [93u8, 39u8, 204u8, 149u8],
            [101u8, 118u8, 52u8, 131u8],
            [113u8, 152u8, 156u8, 118u8],
            [121u8, 137u8, 170u8, 16u8],
            [133u8, 182u8, 39u8, 162u8],
            [163u8, 245u8, 187u8, 75u8],
            [175u8, 182u8, 58u8, 212u8],
            [184u8, 176u8, 46u8, 14u8],
            [237u8, 186u8, 205u8, 68u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecOptimizedCalls {
        const NAME: &'static str = "CodecOptimizedCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 14usize;
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
                Self::hashTransitions(_) => {
                    <hashTransitionsCall as alloy_sol_types::SolCall>::SELECTOR
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
                    fn hashTransitions(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionsCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitions)
                    }
                    hashTransitions
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
                    fn hashTransitions(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecOptimizedCalls> {
                        <hashTransitionsCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecOptimizedCalls::hashTransitions)
                    }
                    hashTransitions
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
                Self::hashTransitions(inner) => {
                    <hashTransitionsCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::hashTransitions(inner) => {
                    <hashTransitionsCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
        InvalidBondType(InvalidBondType),
        #[allow(missing_docs)]
        LengthExceedsUint16(LengthExceedsUint16),
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
            [92u8, 22u8, 125u8, 126u8],
            [246u8, 178u8, 9u8, 168u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecOptimizedErrors {
        const NAME: &'static str = "CodecOptimizedErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 3usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::InvalidBondType(_) => {
                    <InvalidBondType as alloy_sol_types::SolError>::SELECTOR
                }
                Self::LengthExceedsUint16(_) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::SELECTOR
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
        ///Creates a new call builder for the [`hashTransitions`] function.
        pub fn hashTransitions(
            &self,
            _transitions: alloy::sol_types::private::Vec<
                <IInbox::Transition as alloy::sol_types::SolType>::RustType,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, hashTransitionsCall, N> {
            self.call_builder(
                &hashTransitionsCall {
                    _transitions,
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
