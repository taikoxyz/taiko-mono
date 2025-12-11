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
    struct Derivation { uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
    struct DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
    struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 parentProposalHash; bytes32 derivationHash; }
    struct ProposeInput { uint48 deadline; LibBlobs.BlobReference blobReference; uint8 numForcedInclusions; }
    struct ProposedEventPayload { Proposal proposal; Derivation derivation; }
    struct ProveInput { uint48 firstProposalId; bytes32 firstProposalParentCheckpointHash; address actualProver; Transition[] transitions; ICheckpointStore.Checkpoint lastCheckpoint; }
    struct ProvedEventPayload { ProveInput input; }
    struct Transition { address proposer; address designatedProver; uint48 timestamp; bytes32 checkpointHash; }
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
struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 parentProposalHash; bytes32 derivationHash; }
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
        pub parentProposalHash: alloy::sol_types::private::FixedBytes<32>,
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
                    value.parentProposalHash,
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
                    parentProposalHash: tuple.4,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.parentProposalHash),
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
                    "Proposal(uint48 id,uint48 timestamp,uint48 endOfSubmissionWindowTimestamp,address proposer,bytes32 parentProposalHash,bytes32 derivationHash)",
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
                            &self.parentProposalHash,
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
                        &rust.parentProposalHash,
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
                    &rust.parentProposalHash,
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
struct ProveInput { uint48 firstProposalId; bytes32 firstProposalParentCheckpointHash; address actualProver; Transition[] transitions; ICheckpointStore.Checkpoint lastCheckpoint; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProveInput {
        #[allow(missing_docs)]
        pub firstProposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub firstProposalParentCheckpointHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub actualProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub transitions: alloy::sol_types::private::Vec<
            <Transition as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub lastCheckpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
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
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Array<Transition>,
            ICheckpointStore::Checkpoint,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::Vec<
                <Transition as alloy::sol_types::SolType>::RustType,
            >,
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
        impl ::core::convert::From<ProveInput> for UnderlyingRustTuple<'_> {
            fn from(value: ProveInput) -> Self {
                (
                    value.firstProposalId,
                    value.firstProposalParentCheckpointHash,
                    value.actualProver,
                    value.transitions,
                    value.lastCheckpoint,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProveInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    firstProposalId: tuple.0,
                    firstProposalParentCheckpointHash: tuple.1,
                    actualProver: tuple.2,
                    transitions: tuple.3,
                    lastCheckpoint: tuple.4,
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.firstProposalId),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.firstProposalParentCheckpointHash,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.actualProver,
                    ),
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::tokenize(&self.transitions),
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::tokenize(
                        &self.lastCheckpoint,
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
                    "ProveInput(uint48 firstProposalId,bytes32 firstProposalParentCheckpointHash,address actualProver,Transition[] transitions,Checkpoint lastCheckpoint)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.firstProposalId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.firstProposalParentCheckpointHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.actualProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.transitions)
                        .0,
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastCheckpoint,
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
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.firstProposalId,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.firstProposalParentCheckpointHash,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.actualProver,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitions,
                    )
                    + <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastCheckpoint,
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
                    &rust.firstProposalId,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.firstProposalParentCheckpointHash,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.actualProver,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    Transition,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitions,
                    out,
                );
                <ICheckpointStore::Checkpoint as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastCheckpoint,
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
struct ProvedEventPayload { ProveInput input; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProvedEventPayload {
        #[allow(missing_docs)]
        pub input: <ProveInput as alloy::sol_types::SolType>::RustType,
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
        type UnderlyingSolTuple<'a> = (ProveInput,);
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            <ProveInput as alloy::sol_types::SolType>::RustType,
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
                (value.input,)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProvedEventPayload {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self { input: tuple.0 }
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
                (<ProveInput as alloy_sol_types::SolType>::tokenize(&self.input),)
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
                    "ProvedEventPayload(ProveInput input)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <ProveInput as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <ProveInput as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                <ProveInput as alloy_sol_types::SolType>::eip712_data_word(&self.input)
                    .0
                    .to_vec()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProvedEventPayload {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <ProveInput as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.input,
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
                <ProveInput as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.input,
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
struct Transition { address proposer; address designatedProver; uint48 timestamp; bytes32 checkpointHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Transition {
        #[allow(missing_docs)]
        pub proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub designatedProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub timestamp: alloy::sol_types::private::primitives::aliases::U48,
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
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Address,
            alloy::sol_types::private::Address,
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
        impl ::core::convert::From<Transition> for UnderlyingRustTuple<'_> {
            fn from(value: Transition) -> Self {
                (
                    value.proposer,
                    value.designatedProver,
                    value.timestamp,
                    value.checkpointHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Transition {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposer: tuple.0,
                    designatedProver: tuple.1,
                    timestamp: tuple.2,
                    checkpointHash: tuple.3,
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.proposer,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
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
                    "Transition(address proposer,address designatedProver,uint48 timestamp,bytes32 checkpointHash)",
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
                            &self.proposer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.designatedProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.timestamp)
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
        impl alloy_sol_types::EventTopic for Transition {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposer,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.designatedProver,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.timestamp,
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
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposer,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.designatedProver,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.timestamp,
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
        bytes32 parentProposalHash;
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
        uint48 firstProposalId;
        bytes32 firstProposalParentCheckpointHash;
        address actualProver;
        Transition[] transitions;
        ICheckpointStore.Checkpoint lastCheckpoint;
    }
    struct ProvedEventPayload {
        ProveInput input;
    }
    struct Transition {
        address proposer;
        address designatedProver;
        uint48 timestamp;
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

interface Codec {
    error LengthExceedsUint16();

    function decodeProposeInput(bytes memory _data) external pure returns (IInbox.ProposeInput memory input_);
    function decodeProposedEvent(bytes memory _data) external pure returns (IInbox.ProposedEventPayload memory payload_);
    function decodeProveInput(bytes memory _data) external pure returns (IInbox.ProveInput memory input_);
    function decodeProvedEvent(bytes memory _data) external pure returns (IInbox.ProvedEventPayload memory payload_);
    function encodeProposeInput(IInbox.ProposeInput memory _input) external pure returns (bytes memory encoded_);
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload) external pure returns (bytes memory encoded_);
    function encodeProveInput(IInbox.ProveInput memory _input) external pure returns (bytes memory encoded_);
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload) external pure returns (bytes memory encoded_);
    function hashBondInstruction(LibBonds.BondInstruction memory _bondInstruction) external pure returns (bytes32);
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external pure returns (bytes32);
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32);
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32);
    function hashProveInput(bytes32 _lastProposalHash, IInbox.ProveInput memory _input) external pure returns (bytes32);
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
                "name": "parentProposalHash",
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
            "name": "firstProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "firstProposalParentCheckpointHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "actualProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "transitions",
            "type": "tuple[]",
            "internalType": "struct IInbox.Transition[]",
            "components": [
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "lastCheckpoint",
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
            "name": "input",
            "type": "tuple",
            "internalType": "struct IInbox.ProveInput",
            "components": [
              {
                "name": "firstProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "firstProposalParentCheckpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "transitions",
                "type": "tuple[]",
                "internalType": "struct IInbox.Transition[]",
                "components": [
                  {
                    "name": "proposer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "designatedProver",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "timestamp",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "checkpointHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              },
              {
                "name": "lastCheckpoint",
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
                "name": "parentProposalHash",
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
            "name": "firstProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "firstProposalParentCheckpointHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "actualProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "transitions",
            "type": "tuple[]",
            "internalType": "struct IInbox.Transition[]",
            "components": [
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "lastCheckpoint",
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
            "name": "input",
            "type": "tuple",
            "internalType": "struct IInbox.ProveInput",
            "components": [
              {
                "name": "firstProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "firstProposalParentCheckpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "transitions",
                "type": "tuple[]",
                "internalType": "struct IInbox.Transition[]",
                "components": [
                  {
                    "name": "proposer",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "designatedProver",
                    "type": "address",
                    "internalType": "address"
                  },
                  {
                    "name": "timestamp",
                    "type": "uint48",
                    "internalType": "uint48"
                  },
                  {
                    "name": "checkpointHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              },
              {
                "name": "lastCheckpoint",
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
    "name": "hashBondInstruction",
    "inputs": [
      {
        "name": "_bondInstruction",
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
            "name": "parentProposalHash",
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
    "name": "hashProveInput",
    "inputs": [
      {
        "name": "_lastProposalHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_input",
        "type": "tuple",
        "internalType": "struct IInbox.ProveInput",
        "components": [
          {
            "name": "firstProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "firstProposalParentCheckpointHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "actualProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "transitions",
            "type": "tuple[]",
            "internalType": "struct IInbox.Transition[]",
            "components": [
              {
                "name": "proposer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "designatedProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "checkpointHash",
                "type": "bytes32",
                "internalType": "bytes32"
              }
            ]
          },
          {
            "name": "lastCheckpoint",
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
    "type": "error",
    "name": "LengthExceedsUint16",
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
pub mod Codec {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x6080604052348015600e575f5ffd5b5061215b8061001c5f395ff3fe608060405234801561000f575f5ffd5b50600436106100cb575f3560e01c80637989aa1011610088578063afb63ad411610063578063afb63ad4146101b8578063b09f589a14610218578063b8b02e0e1461022b578063edbacd441461023e575f5ffd5b80637989aa101461017f578063a1ec933314610192578063a4aeca67146101a5575f5ffd5b806326303962146100cf5780632f1969b0146100f857806339c54aa114610118578063566bdcb91461012b5780635a2136151461013e5780635d27cc951461015f575b5f5ffd5b6100e26100dd3660046114d7565b61025e565b6040516100ef9190611625565b60405180910390f35b61010b610106366004611647565b6102ad565b6040516100ef9190611660565b61010b610126366004611695565b6102c6565b61010b6101393660046116db565b6102d9565b61015161014c36600461171c565b6102ec565b6040519081526020016100ef565b61017261016d3660046114d7565b610304565b6040516100ef919061183a565b61015161018d3660046118b4565b61034a565b6101516101a03660046118c5565b610362565b61010b6101b33660046116db565b61037a565b6101cb6101c63660046114d7565b61038d565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a0016100ef565b6101516102263660046118d6565b610404565b610151610239366004611919565b610417565b61025161024c3660046114d7565b610429565b6040516100ef919061194a565b610266611400565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061046f92505050565b90505b92915050565b60606102a76102c136849003840184611a7b565b6105a0565b60606102a76102d483611cb2565b610617565b60606102a76102e783611d11565b610734565b5f6102a76102ff36849003840184611d1c565b610838565b61030c611418565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061086792505050565b5f6102a761035d36849003840184611d80565b610b47565b5f6102a761037536849003840184611e2b565b610bab565b60606102a761038883612032565b610c1c565b6103c660408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610dfd92505050565b5f6102a48361041284611d11565b610e86565b5f6102a761042483612086565b610fef565b610431611479565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506111e892505050565b610477611400565b602082810151825160d09190911c905260268301518251909101526046820151815160609190911c604090910152605a820151605c83019060f01c806001600160401b038111156104ca576104ca61195c565b60405190808252806020026020018201604052801561051a57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816104e85790505b508351606001525f5b8161ffff168110156105685761053883611300565b85516060015180518490811061055057610550612091565b60209081029190910101919091529250600101610523565b50508051825160809081015160d09290921c909152600682015183518201516020015260269091015182519091015160400152919050565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d82019061060f90829061134f565b905050919050565b805160609081015151604e02608201806001600160401b0381111561063e5761063e61195c565b6040519080825280601f01601f191660200182016040528015610668576020820181803683370190505b5083515160d01b602080830191909152845101516026820152835160400151606090811b60468301528451015151909250605a8301906106a79061135b565b8351606001515160f01b81526002015f5b845160600151518110156106fa576106f082865f01516060015183815181106106e3576106e3612091565b6020026020010151611381565b91506001016106b8565b5083516080908101515160d01b82528451810151602001516006830152845101516040015160268201908152906046015b90505050919050565b60608181015151604e02608201806001600160401b038111156107595761075961195c565b6040519080825280601f01601f191660200182016040528015610783576020820181803683370190505b50835160d01b60208281019190915284015160268201526040840151606090811b604683015284015151909250605a8301906107be9061135b565b60608401515160f01b81526002015f5b84606001515181101561080b576107f582866060015183815181106106e3576106e3612091565b50610801604e836120a5565b91506001016107ce565b506080840180515160d01b825280516020015160068301525160400151602682019081529060460161072b565b5f8160405160200161084a91906120c4565b604051602081830303815290604052805190602001209050919050565b61086f611418565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c908201526046850151845160800152606685015184840180519190931c9052606c850151825190930192909252608c840151905160f89190911c910152608d820151608f83019060f01c806001600160401b038111156109085761090861195c565b60405190808252806020026020018201604052801561096b57816020015b6109586040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b8152602001906001900390816109265790505b506020840151606001525f5b8161ffff16811015610b39578251602085015160600151805160019095019460f89290921c918215159190849081106109b2576109b2612091565b60209081029190910101519015159052835160029094019360f01c806001600160401b038111156109e5576109e561195c565b604051908082528060200260200182016040528015610a0e578160200160208202803683370190505b508660200151606001518481518110610a2957610a29612091565b6020908102919091018101510151525f5b8161ffff16811015610a9e578551602087018860200151606001518681518110610a6657610a66612091565b6020026020010151602001515f01518381518110610a8657610a86612091565b60209081029190910101919091529550600101610a3a565b50845160e81c600386018760200151606001518581518110610ac257610ac2612091565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610b0457610b04612091565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610977565b505051815160a00152919050565b604080516003815260808101909152815165ffffffffffff1660208201525f906020830151604082015260408301516060820152805b50805160051b6020820120610ba48280516040516001820160051b83011490151060061b52565b9392505050565b604080516006815260e08101909152815165ffffffffffff1660208201525f90602083015165ffffffffffff166040820152604083015165ffffffffffff16606082015260608301516001600160a01b03166080820152608083015160a082015260a083015160c082015280610b7d565b60605f610c308360200151606001516113b6565b9050806001600160401b03811115610c4a57610c4a61195c565b6040519080825280601f01601f191660200182016040528015610c74576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b81850152865160800151604685015281870180515190931b6066850152825190910151606c84015290510151909250608c830190610cea90829061134f565b60208501516060015151909150610d008161135b565b610d10828260f01b815260020190565b91505f5b81811015610ded575f8660200151606001518281518110610d3757610d37612091565b60200260200101519050610d5a84825f0151610d53575f61134f565b600161134f565b60208201515151909450610d6d8161135b565b610d7d858260f01b815260020190565b94505f5b81811015610dc057610db68684602001515f01518381518110610da657610da6612091565b6020026020010151815260200190565b9550600101610d81565b5050602090810180519091015160e81b8452516040015160d01b6003840152600990920191600101610d14565b5050925160a00151909252919050565b610e3660408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b606081015180515f9190600a600482020183610eb28260408051828152600190920160051b8201905290565b602081018890529050604080820152855165ffffffffffff1660608201526020860151608082015260408601516001600160a01b031660a082015260e060c082015260808601515165ffffffffffff1660e08201526080860151602001516101008201526080860151604001516101208201526101408101839052600a5f5b84811015610fbc575f868281518110610f4c57610f4c612091565b602090810291909101015180516001600160a01b03166001850160051b860152905060208101516001600160a01b03166002840160051b850152604081015165ffffffffffff166003840160051b85015260608101516004840160051b8501525060049190910190600101610f31565b50815160051b6020830120610fe38380516040516001820160051b83011490151060061b52565b98975050505050505050565b606081015180515f919060068101835b8281101561103b5783818151811061101957611019612091565b6020026020010151602001515f01515160060182019150806001019050610fff565b50604080518281526001830160051b8101909152602080820152855165ffffffffffff16604082015260208601516060820152604086015160ff166080820152608060a082015260c0810183905260068381015f5b858110156111c1575f8782815181106110ab576110ab612091565b602002602001015190506110d4858386016005878703901b5f1b60019190910160051b82015290565b506110fd8584835f01516110e8575f6110eb565b60015b60ff1660019190910160051b82015290565b5060406002840160051b86015260606003840160051b86015260028301602080830151015162ffffff166002820160051b87015260208201516040015165ffffffffffff166003820160051b87015260208201515180516004830160051b8801819052600383015f5b828110156111aa576111a18a82846001010186848151811061118a5761118a612091565b602002602001015160019190910160051b82015290565b50600101611166565b500160019081019550939093019250611090915050565b50825160051b6020840120610fe38480516040516001820160051b83011490151060061b52565b6111f0611479565b60208281015160d01c8252602683015190820152604682015160601c6040820152605a820151605c83019060f01c806001600160401b038111156112365761123661195c565b60405190808252806020026020018201604052801561128657816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816112545790505b5060608401525f5b8161ffff168110156112d1576112a383611300565b856060015183815181106112b9576112b9612091565b6020908102919091010191909152925060010161128e565b5050805160808301805160d09290921c9091526006820151815160200152602690910151905160400152919050565b604080516080810182525f8082526020820181815292820181815260608084019283528551811c84526014860151901c909352602884015160d01c909252602e83015190915291604e90910190565b5f818353505060010190565b61ffff81111561137e5760405163161e7a6b60e11b815260040160405180910390fd5b50565b8051606090811b83526020820151811b6014840152604082015160d01b6028840152810151602e8301908152604e83016102a4565b608f5f5b82518110156113fa578281815181106113d5576113d5612091565b6020026020010151602001515f015151602002600c01820191508060010190506113ba565b50919050565b6040518060200160405280611413611479565b905290565b60408051610100810182525f918101828152606082018390526080820183905260a0820183905260c0820183905260e08201929092529081908152604080516080810182525f80825260208281018290529282015260608082015291015290565b6040518060a001604052805f65ffffffffffff1681526020015f81526020015f6001600160a01b031681526020016060815260200161141360405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f5f602083850312156114e8575f5ffd5b82356001600160401b038111156114fd575f5ffd5b8301601f8101851361150d575f5ffd5b80356001600160401b03811115611522575f5ffd5b856020828401011115611533575f5ffd5b6020919091019590945092505050565b805165ffffffffffff168252602080820151818401526040808301516001600160a01b03169084015260608083015160e091850182905280519185018290525f92019082906101008601905b808310156115eb57835160018060a01b03815116835260018060a01b03602082015116602084015265ffffffffffff6040820151166040840152606081015160608401525060808201915060208401935060018301925061158f565b506080850151925061161c6080870184805165ffffffffffff16825260208082015190830152604090810151910152565b95945050505050565b602081525f825160208084015261163f6040840182611543565b949350505050565b5f60a0828403128015611658575f5ffd5b509092915050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f602082840312156116a5575f5ffd5b81356001600160401b038111156116ba575f5ffd5b820160208185031215610ba4575f5ffd5b5f60e082840312156113fa575f5ffd5b5f602082840312156116eb575f5ffd5b81356001600160401b03811115611700575f5ffd5b61163f848285016116cb565b5f608082840312156113fa575f5ffd5b5f6080828403121561172c575f5ffd5b6102a4838361170c565b5f6080830165ffffffffffff83511684526020830151602085015260ff604084015116604085015260608301516080606086015281815180845260a08701915060a08160051b88010193506020830192505f5b8181101561182e57878503609f19018352835180511515865260209081015160408288018190528151606091890191909152805160a08901819052919201905f9060c08901905b808310156117f357835182526020820191506020840193506001830192506117d0565b5060208481015162ffffff1660608b015260409094015165ffffffffffff166080909901989098525050938401939290920191600101611789565b50929695505050505050565b602081525f825165ffffffffffff815116602084015265ffffffffffff602082015116604084015265ffffffffffff604082015116606084015260018060a01b036060820151166080840152608081015160a084015260a081015160c084015250602083015160e08084015261163f610100840182611736565b5f6060828403128015611658575f5ffd5b5f60c0828403128015611658575f5ffd5b5f5f604083850312156118e7575f5ffd5b8235915060208301356001600160401b03811115611903575f5ffd5b61190f858286016116cb565b9150509250929050565b5f60208284031215611929575f5ffd5b81356001600160401b0381111561193e575f5ffd5b61163f8482850161170c565b602081525f6102a46020830184611543565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b03811182821017156119925761199261195c565b60405290565b60405160a081016001600160401b03811182821017156119925761199261195c565b604051608081016001600160401b03811182821017156119925761199261195c565b604080519081016001600160401b03811182821017156119925761199261195c565b604051601f8201601f191681016001600160401b0381118282101715611a2657611a2661195c565b604052919050565b803565ffffffffffff81168114611a43575f5ffd5b919050565b803561ffff81168114611a43575f5ffd5b803562ffffff81168114611a43575f5ffd5b803560ff81168114611a43575f5ffd5b5f81830360a081128015611a8d575f5ffd5b50611a96611970565b611a9f84611a2e565b81526060601f1983011215611ab2575f5ffd5b611aba611970565b9150611ac860208501611a48565b8252611ad660408501611a48565b6020830152611ae760608501611a59565b6040830152816020820152611afe60808501611a6b565b6040820152949350505050565b80356001600160a01b0381168114611a43575f5ffd5b5f6001600160401b03821115611b3957611b3961195c565b5060051b60200190565b5f60608284031215611b53575f5ffd5b611b5b611970565b9050611b6682611a2e565b81526020828101359082015260409182013591810191909152919050565b5f60e08284031215611b94575f5ffd5b611b9c611998565b9050611ba782611a2e565b815260208281013590820152611bbf60408301611b0b565b604082015260608201356001600160401b03811115611bdc575f5ffd5b8201601f81018413611bec575f5ffd5b8035611bff611bfa82611b21565b6119fe565b8082825260208201915060208360071b850101925086831115611c20575f5ffd5b6020840193505b82841015611c905760808488031215611c3e575f5ffd5b611c466119ba565b611c4f85611b0b565b8152611c5d60208601611b0b565b6020820152611c6e60408601611a2e565b6040820152606085810135908201528252608090930192602090910190611c27565b80606086015250505050611ca78360808401611b43565b608082015292915050565b5f60208236031215611cc2575f5ffd5b604051602081016001600160401b0381118282101715611ce457611ce461195c565b60405282356001600160401b03811115611cfc575f5ffd5b611d0836828601611b84565b82525092915050565b5f6102a73683611b84565b5f6080828403128015611d2d575f5ffd5b50611d366119ba565b611d3f83611a2e565b8152602083013560038110611d52575f5ffd5b6020820152611d6360408401611b0b565b6040820152611d7460608401611b0b565b60608201529392505050565b5f60608284031215611d90575f5ffd5b6102a48383611b43565b5f60c08284031215611daa575f5ffd5b60405160c081016001600160401b0381118282101715611dcc57611dcc61195c565b604052905080611ddb83611a2e565b8152611de960208401611a2e565b6020820152611dfa60408401611a2e565b6040820152611e0b60608401611b0b565b60608201526080838101359082015260a092830135920191909152919050565b5f60c08284031215611e3b575f5ffd5b6102a48383611d9a565b5f60808284031215611e55575f5ffd5b611e5d6119ba565b9050611e6882611a2e565b815260208281013590820152611e8060408301611a6b565b604082015260608201356001600160401b03811115611e9d575f5ffd5b8201601f81018413611ead575f5ffd5b8035611ebb611bfa82611b21565b8082825260208201915060208360051b850101925086831115611edc575f5ffd5b602084015b838110156120225780356001600160401b03811115611efe575f5ffd5b85016040818a03601f19011215611f13575f5ffd5b611f1b6119dc565b60208201358015158114611f2d575f5ffd5b815260408201356001600160401b03811115611f47575f5ffd5b6020818401019250506060828b031215611f5f575f5ffd5b611f67611970565b82356001600160401b03811115611f7c575f5ffd5b8301601f81018c13611f8c575f5ffd5b8035611f9a611bfa82611b21565b8082825260208201915060208360051b85010192508e831115611fbb575f5ffd5b6020840193505b82841015611fdd578335825260209384019390910190611fc2565b845250611fef91505060208401611a59565b602082015261200060408401611a2e565b6040820152806020830152508085525050602083019250602081019050611ee1565b5060608501525091949350505050565b5f60e08236031215612042575f5ffd5b61204a6119dc565b6120543684611d9a565b815260c08301356001600160401b0381111561206e575f5ffd5b61207a36828601611e45565b60208301525092915050565b5f6102a73683611e45565b634e487b7160e01b5f52603260045260245ffd5b808201808211156102a757634e487b7160e01b5f52601160045260245ffd5b815165ffffffffffff16815260208201516080820190600381106120f657634e487b7160e01b5f52602160045260245ffd5b60208301526040838101516001600160a01b03908116918401919091526060938401511692909101919091529056fea26469706673582212201ea4e25d96895bf184b327076c6b0903cc9e67d7527a253cf64f83ee6699870064736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa![\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xCBW_5`\xE0\x1C\x80cy\x89\xAA\x10\x11a\0\x88W\x80c\xAF\xB6:\xD4\x11a\0cW\x80c\xAF\xB6:\xD4\x14a\x01\xB8W\x80c\xB0\x9FX\x9A\x14a\x02\x18W\x80c\xB8\xB0.\x0E\x14a\x02+W\x80c\xED\xBA\xCDD\x14a\x02>W__\xFD[\x80cy\x89\xAA\x10\x14a\x01\x7FW\x80c\xA1\xEC\x933\x14a\x01\x92W\x80c\xA4\xAE\xCAg\x14a\x01\xA5W__\xFD[\x80c&09b\x14a\0\xCFW\x80c/\x19i\xB0\x14a\0\xF8W\x80c9\xC5J\xA1\x14a\x01\x18W\x80cVk\xDC\xB9\x14a\x01+W\x80cZ!6\x15\x14a\x01>W\x80c]'\xCC\x95\x14a\x01_W[__\xFD[a\0\xE2a\0\xDD6`\x04a\x14\xD7V[a\x02^V[`@Qa\0\xEF\x91\x90a\x16%V[`@Q\x80\x91\x03\x90\xF3[a\x01\x0Ba\x01\x066`\x04a\x16GV[a\x02\xADV[`@Qa\0\xEF\x91\x90a\x16`V[a\x01\x0Ba\x01&6`\x04a\x16\x95V[a\x02\xC6V[a\x01\x0Ba\x0196`\x04a\x16\xDBV[a\x02\xD9V[a\x01Qa\x01L6`\x04a\x17\x1CV[a\x02\xECV[`@Q\x90\x81R` \x01a\0\xEFV[a\x01ra\x01m6`\x04a\x14\xD7V[a\x03\x04V[`@Qa\0\xEF\x91\x90a\x18:V[a\x01Qa\x01\x8D6`\x04a\x18\xB4V[a\x03JV[a\x01Qa\x01\xA06`\x04a\x18\xC5V[a\x03bV[a\x01\x0Ba\x01\xB36`\x04a\x16\xDBV[a\x03zV[a\x01\xCBa\x01\xC66`\x04a\x14\xD7V[a\x03\x8DV[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\0\xEFV[a\x01Qa\x02&6`\x04a\x18\xD6V[a\x04\x04V[a\x01Qa\x0296`\x04a\x19\x19V[a\x04\x17V[a\x02Qa\x02L6`\x04a\x14\xD7V[a\x04)V[`@Qa\0\xEF\x91\x90a\x19JV[a\x02fa\x14\0V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x04o\x92PPPV[\x90P[\x92\x91PPV[``a\x02\xA7a\x02\xC16\x84\x90\x03\x84\x01\x84a\x1A{V[a\x05\xA0V[``a\x02\xA7a\x02\xD4\x83a\x1C\xB2V[a\x06\x17V[``a\x02\xA7a\x02\xE7\x83a\x1D\x11V[a\x074V[_a\x02\xA7a\x02\xFF6\x84\x90\x03\x84\x01\x84a\x1D\x1CV[a\x088V[a\x03\x0Ca\x14\x18V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08g\x92PPPV[_a\x02\xA7a\x03]6\x84\x90\x03\x84\x01\x84a\x1D\x80V[a\x0BGV[_a\x02\xA7a\x03u6\x84\x90\x03\x84\x01\x84a\x1E+V[a\x0B\xABV[``a\x02\xA7a\x03\x88\x83a 2V[a\x0C\x1CV[a\x03\xC6`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\r\xFD\x92PPPV[_a\x02\xA4\x83a\x04\x12\x84a\x1D\x11V[a\x0E\x86V[_a\x02\xA7a\x04$\x83a \x86V[a\x0F\xEFV[a\x041a\x14yV[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x11\xE8\x92PPPV[a\x04wa\x14\0V[` \x82\x81\x01Q\x82Q`\xD0\x91\x90\x91\x1C\x90R`&\x83\x01Q\x82Q\x90\x91\x01R`F\x82\x01Q\x81Q``\x91\x90\x91\x1C`@\x90\x91\x01R`Z\x82\x01Q`\\\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x04\xCAWa\x04\xCAa\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x05\x1AW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x04\xE8W\x90P[P\x83Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x05hWa\x058\x83a\x13\0V[\x85Q``\x01Q\x80Q\x84\x90\x81\x10a\x05PWa\x05Pa \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x05#V[PP\x80Q\x82Q`\x80\x90\x81\x01Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x82\x01Q\x83Q\x82\x01Q` \x01R`&\x90\x91\x01Q\x82Q\x90\x91\x01Q`@\x01R\x91\x90PV[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x06\x0F\x90\x82\x90a\x13OV[\x90PP\x91\x90PV[\x80Q``\x90\x81\x01QQ`N\x02`\x82\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06>Wa\x06>a\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x06hW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x1B` \x80\x83\x01\x91\x90\x91R\x84Q\x01Q`&\x82\x01R\x83Q`@\x01Q``\x90\x81\x1B`F\x83\x01R\x84Q\x01QQ\x90\x92P`Z\x83\x01\x90a\x06\xA7\x90a\x13[V[\x83Q``\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84Q``\x01QQ\x81\x10\x15a\x06\xFAWa\x06\xF0\x82\x86_\x01Q``\x01Q\x83\x81Q\x81\x10a\x06\xE3Wa\x06\xE3a \x91V[` \x02` \x01\x01Qa\x13\x81V[\x91P`\x01\x01a\x06\xB8V[P\x83Q`\x80\x90\x81\x01QQ`\xD0\x1B\x82R\x84Q\x81\x01Q` \x01Q`\x06\x83\x01R\x84Q\x01Q`@\x01Q`&\x82\x01\x90\x81R\x90`F\x01[\x90PPP\x91\x90PV[``\x81\x81\x01QQ`N\x02`\x82\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x07YWa\x07Ya\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x07\x83W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x1B` \x82\x81\x01\x91\x90\x91R\x84\x01Q`&\x82\x01R`@\x84\x01Q``\x90\x81\x1B`F\x83\x01R\x84\x01QQ\x90\x92P`Z\x83\x01\x90a\x07\xBE\x90a\x13[V[``\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84``\x01QQ\x81\x10\x15a\x08\x0BWa\x07\xF5\x82\x86``\x01Q\x83\x81Q\x81\x10a\x06\xE3Wa\x06\xE3a \x91V[Pa\x08\x01`N\x83a \xA5V[\x91P`\x01\x01a\x07\xCEV[P`\x80\x84\x01\x80QQ`\xD0\x1B\x82R\x80Q` \x01Q`\x06\x83\x01RQ`@\x01Q`&\x82\x01\x90\x81R\x90`F\x01a\x07+V[_\x81`@Q` \x01a\x08J\x91\x90a \xC4V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[a\x08oa\x14\x18V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84Q`\x80\x01R`f\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`\x8C\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`\x8D\x82\x01Q`\x8F\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\x08Wa\t\x08a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\tkW\x81` \x01[a\tX`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\t&W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0B9W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\t\xB2Wa\t\xB2a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xE5Wa\t\xE5a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\n\x0EW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\n)Wa\n)a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\x9EW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\nfWa\nfa \x91V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\n\x86Wa\n\x86a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\n:V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\n\xC2Wa\n\xC2a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0B\x04Wa\x0B\x04a \x91V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\twV[PPQ\x81Q`\xA0\x01R\x91\x90PV[`@\x80Q`\x03\x81R`\x80\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Q`@\x82\x01R`@\x83\x01Q``\x82\x01R\x80[P\x80Q`\x05\x1B` \x82\x01 a\x0B\xA4\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x93\x92PPPV[`@\x80Q`\x06\x81R`\xE0\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x80\x82\x01R`\x80\x83\x01Q`\xA0\x82\x01R`\xA0\x83\x01Q`\xC0\x82\x01R\x80a\x0B}V[``_a\x0C0\x83` \x01Q``\x01Qa\x13\xB6V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0CJWa\x0CJa\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0CtW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x86Q`\x80\x01Q`F\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`f\x85\x01R\x82Q\x90\x91\x01Q`l\x84\x01R\x90Q\x01Q\x90\x92P`\x8C\x83\x01\x90a\x0C\xEA\x90\x82\x90a\x13OV[` \x85\x01Q``\x01QQ\x90\x91Pa\r\0\x81a\x13[V[a\r\x10\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\r\xEDW_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\r7Wa\r7a \x91V[` \x02` \x01\x01Q\x90Pa\rZ\x84\x82_\x01Qa\rSW_a\x13OV[`\x01a\x13OV[` \x82\x01QQQ\x90\x94Pa\rm\x81a\x13[V[a\r}\x85\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x94P_[\x81\x81\x10\x15a\r\xC0Wa\r\xB6\x86\x84` \x01Q_\x01Q\x83\x81Q\x81\x10a\r\xA6Wa\r\xA6a \x91V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x95P`\x01\x01a\r\x81V[PP` \x90\x81\x01\x80Q\x90\x91\x01Q`\xE8\x1B\x84RQ`@\x01Q`\xD0\x1B`\x03\x84\x01R`\t\x90\x92\x01\x91`\x01\x01a\r\x14V[PP\x92Q`\xA0\x01Q\x90\x92R\x91\x90PV[a\x0E6`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[``\x81\x01Q\x80Q_\x91\x90`\n`\x04\x82\x02\x01\x83a\x0E\xB2\x82`@\x80Q\x82\x81R`\x01\x90\x92\x01`\x05\x1B\x82\x01\x90R\x90V[` \x81\x01\x88\x90R\x90P`@\x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R` \x86\x01Q`\x80\x82\x01R`@\x86\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\xA0\x82\x01R`\xE0`\xC0\x82\x01R`\x80\x86\x01QQe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xE0\x82\x01R`\x80\x86\x01Q` \x01Qa\x01\0\x82\x01R`\x80\x86\x01Q`@\x01Qa\x01 \x82\x01Ra\x01@\x81\x01\x83\x90R`\n_[\x84\x81\x10\x15a\x0F\xBCW_\x86\x82\x81Q\x81\x10a\x0FLWa\x0FLa \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16`\x01\x85\x01`\x05\x1B\x86\x01R\x90P` \x81\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x02\x84\x01`\x05\x1B\x85\x01R`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x84\x01`\x05\x1B\x85\x01R``\x81\x01Q`\x04\x84\x01`\x05\x1B\x85\x01RP`\x04\x91\x90\x91\x01\x90`\x01\x01a\x0F1V[P\x81Q`\x05\x1B` \x83\x01 a\x0F\xE3\x83\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x98\x97PPPPPPPPV[``\x81\x01Q\x80Q_\x91\x90`\x06\x81\x01\x83[\x82\x81\x10\x15a\x10;W\x83\x81\x81Q\x81\x10a\x10\x19Wa\x10\x19a \x91V[` \x02` \x01\x01Q` \x01Q_\x01QQ`\x06\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x0F\xFFV[P`@\x80Q\x82\x81R`\x01\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\xFF\x16`\x80\x82\x01R`\x80`\xA0\x82\x01R`\xC0\x81\x01\x83\x90R`\x06\x83\x81\x01_[\x85\x81\x10\x15a\x11\xC1W_\x87\x82\x81Q\x81\x10a\x10\xABWa\x10\xABa \x91V[` \x02` \x01\x01Q\x90Pa\x10\xD4\x85\x83\x86\x01`\x05\x87\x87\x03\x90\x1B_\x1B`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[Pa\x10\xFD\x85\x84\x83_\x01Qa\x10\xE8W_a\x10\xEBV[`\x01[`\xFF\x16`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`@`\x02\x84\x01`\x05\x1B\x86\x01R```\x03\x84\x01`\x05\x1B\x86\x01R`\x02\x83\x01` \x80\x83\x01Q\x01Qb\xFF\xFF\xFF\x16`\x02\x82\x01`\x05\x1B\x87\x01R` \x82\x01Q`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x82\x01`\x05\x1B\x87\x01R` \x82\x01QQ\x80Q`\x04\x83\x01`\x05\x1B\x88\x01\x81\x90R`\x03\x83\x01_[\x82\x81\x10\x15a\x11\xAAWa\x11\xA1\x8A\x82\x84`\x01\x01\x01\x86\x84\x81Q\x81\x10a\x11\x8AWa\x11\x8Aa \x91V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11fV[P\x01`\x01\x90\x81\x01\x95P\x93\x90\x93\x01\x92Pa\x10\x90\x91PPV[P\x82Q`\x05\x1B` \x84\x01 a\x0F\xE3\x84\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[a\x11\xF0a\x14yV[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x90\x82\x01R`F\x82\x01Q``\x1C`@\x82\x01R`Z\x82\x01Q`\\\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x126Wa\x126a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x12\x86W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x12TW\x90P[P``\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x12\xD1Wa\x12\xA3\x83a\x13\0V[\x85``\x01Q\x83\x81Q\x81\x10a\x12\xB9Wa\x12\xB9a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x12\x8EV[PP\x80Q`\x80\x83\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x82\x01Q\x81Q` \x01R`&\x90\x91\x01Q\x90Q`@\x01R\x91\x90PV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x92\x83R\x85Q\x81\x1C\x84R`\x14\x86\x01Q\x90\x1C\x90\x93R`(\x84\x01Q`\xD0\x1C\x90\x92R`.\x83\x01Q\x90\x91R\x91`N\x90\x91\x01\x90V[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x13~W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q``\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x14\x84\x01R`@\x82\x01Q`\xD0\x1B`(\x84\x01R\x81\x01Q`.\x83\x01\x90\x81R`N\x83\x01a\x02\xA4V[`\x8F_[\x82Q\x81\x10\x15a\x13\xFAW\x82\x81\x81Q\x81\x10a\x13\xD5Wa\x13\xD5a \x91V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x13\xBAV[P\x91\x90PV[`@Q\x80` \x01`@R\x80a\x14\x13a\x14yV[\x90R\x90V[`@\x80Qa\x01\0\x81\x01\x82R_\x91\x81\x01\x82\x81R``\x82\x01\x83\x90R`\x80\x82\x01\x83\x90R`\xA0\x82\x01\x83\x90R`\xC0\x82\x01\x83\x90R`\xE0\x82\x01\x92\x90\x92R\x90\x81\x90\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xA0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01``\x81R` \x01a\x14\x13`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[__` \x83\x85\x03\x12\x15a\x14\xE8W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x14\xFDW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x15\rW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\"W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\x153W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x84\x01R``\x80\x83\x01Q`\xE0\x91\x85\x01\x82\x90R\x80Q\x91\x85\x01\x82\x90R_\x92\x01\x90\x82\x90a\x01\0\x86\x01\x90[\x80\x83\x10\x15a\x15\xEBW\x83Q`\x01\x80`\xA0\x1B\x03\x81Q\x16\x83R`\x01\x80`\xA0\x1B\x03` \x82\x01Q\x16` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x84\x01R``\x81\x01Q``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x15\x8FV[P`\x80\x85\x01Q\x92Pa\x16\x1C`\x80\x87\x01\x84\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82R` \x80\x82\x01Q\x90\x83\x01R`@\x90\x81\x01Q\x91\x01RV[\x95\x94PPPPPV[` \x81R_\x82Q` \x80\x84\x01Ra\x16?`@\x84\x01\x82a\x15CV[\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[P\x90\x92\x91PPV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_` \x82\x84\x03\x12\x15a\x16\xA5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\xBAW__\xFD[\x82\x01` \x81\x85\x03\x12\x15a\x0B\xA4W__\xFD[_`\xE0\x82\x84\x03\x12\x15a\x13\xFAW__\xFD[_` \x82\x84\x03\x12\x15a\x16\xEBW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17\0W__\xFD[a\x16?\x84\x82\x85\x01a\x16\xCBV[_`\x80\x82\x84\x03\x12\x15a\x13\xFAW__\xFD[_`\x80\x82\x84\x03\x12\x15a\x17,W__\xFD[a\x02\xA4\x83\x83a\x17\x0CV[_`\x80\x83\x01e\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x84R` \x83\x01Q` \x85\x01R`\xFF`@\x84\x01Q\x16`@\x85\x01R``\x83\x01Q`\x80``\x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P`\xA0\x81`\x05\x1B\x88\x01\x01\x93P` \x83\x01\x92P_[\x81\x81\x10\x15a\x18.W\x87\x85\x03`\x9F\x19\x01\x83R\x83Q\x80Q\x15\x15\x86R` \x90\x81\x01Q`@\x82\x88\x01\x81\x90R\x81Q``\x91\x89\x01\x91\x90\x91R\x80Q`\xA0\x89\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x89\x01\x90[\x80\x83\x10\x15a\x17\xF3W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x17\xD0V[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8B\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x99\x01\x98\x90\x98RPP\x93\x84\x01\x93\x92\x90\x92\x01\x91`\x01\x01a\x17\x89V[P\x92\x96\x95PPPPPPV[` \x81R_\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16`@\x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16``\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16`\x80\x84\x01R`\x80\x81\x01Q`\xA0\x84\x01R`\xA0\x81\x01Q`\xC0\x84\x01RP` \x83\x01Q`\xE0\x80\x84\x01Ra\x16?a\x01\0\x84\x01\x82a\x176V[_``\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[_`\xC0\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[__`@\x83\x85\x03\x12\x15a\x18\xE7W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x03W__\xFD[a\x19\x0F\x85\x82\x86\x01a\x16\xCBV[\x91PP\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a\x19)W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19>W__\xFD[a\x16?\x84\x82\x85\x01a\x17\x0CV[` \x81R_a\x02\xA4` \x83\x01\x84a\x15CV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1A&Wa\x1A&a\x19\\V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x805`\xFF\x81\x16\x81\x14a\x1ACW__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x1A\x8DW__\xFD[Pa\x1A\x96a\x19pV[a\x1A\x9F\x84a\x1A.V[\x81R```\x1F\x19\x83\x01\x12\x15a\x1A\xB2W__\xFD[a\x1A\xBAa\x19pV[\x91Pa\x1A\xC8` \x85\x01a\x1AHV[\x82Ra\x1A\xD6`@\x85\x01a\x1AHV[` \x83\x01Ra\x1A\xE7``\x85\x01a\x1AYV[`@\x83\x01R\x81` \x82\x01Ra\x1A\xFE`\x80\x85\x01a\x1AkV[`@\x82\x01R\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x1ACW__\xFD[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1B9Wa\x1B9a\x19\\V[P`\x05\x1B` \x01\x90V[_``\x82\x84\x03\x12\x15a\x1BSW__\xFD[a\x1B[a\x19pV[\x90Pa\x1Bf\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xE0\x82\x84\x03\x12\x15a\x1B\x94W__\xFD[a\x1B\x9Ca\x19\x98V[\x90Pa\x1B\xA7\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1B\xBF`@\x83\x01a\x1B\x0BV[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B\xDCW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1B\xECW__\xFD[\x805a\x1B\xFFa\x1B\xFA\x82a\x1B!V[a\x19\xFEV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a\x1C W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x1C\x90W`\x80\x84\x88\x03\x12\x15a\x1C>W__\xFD[a\x1CFa\x19\xBAV[a\x1CO\x85a\x1B\x0BV[\x81Ra\x1C]` \x86\x01a\x1B\x0BV[` \x82\x01Ra\x1Cn`@\x86\x01a\x1A.V[`@\x82\x01R``\x85\x81\x015\x90\x82\x01R\x82R`\x80\x90\x93\x01\x92` \x90\x91\x01\x90a\x1C'V[\x80``\x86\x01RPPPPa\x1C\xA7\x83`\x80\x84\x01a\x1BCV[`\x80\x82\x01R\x92\x91PPV[_` \x826\x03\x12\x15a\x1C\xC2W__\xFD[`@Q` \x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\xE4Wa\x1C\xE4a\x19\\V[`@R\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\xFCW__\xFD[a\x1D\x086\x82\x86\x01a\x1B\x84V[\x82RP\x92\x91PPV[_a\x02\xA76\x83a\x1B\x84V[_`\x80\x82\x84\x03\x12\x80\x15a\x1D-W__\xFD[Pa\x1D6a\x19\xBAV[a\x1D?\x83a\x1A.V[\x81R` \x83\x015`\x03\x81\x10a\x1DRW__\xFD[` \x82\x01Ra\x1Dc`@\x84\x01a\x1B\x0BV[`@\x82\x01Ra\x1Dt``\x84\x01a\x1B\x0BV[``\x82\x01R\x93\x92PPPV[_``\x82\x84\x03\x12\x15a\x1D\x90W__\xFD[a\x02\xA4\x83\x83a\x1BCV[_`\xC0\x82\x84\x03\x12\x15a\x1D\xAAW__\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1D\xCCWa\x1D\xCCa\x19\\V[`@R\x90P\x80a\x1D\xDB\x83a\x1A.V[\x81Ra\x1D\xE9` \x84\x01a\x1A.V[` \x82\x01Ra\x1D\xFA`@\x84\x01a\x1A.V[`@\x82\x01Ra\x1E\x0B``\x84\x01a\x1B\x0BV[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01R`\xA0\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a\x1E;W__\xFD[a\x02\xA4\x83\x83a\x1D\x9AV[_`\x80\x82\x84\x03\x12\x15a\x1EUW__\xFD[a\x1E]a\x19\xBAV[\x90Pa\x1Eh\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1E\x80`@\x83\x01a\x1AkV[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\x9DW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1E\xADW__\xFD[\x805a\x1E\xBBa\x1B\xFA\x82a\x1B!V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a\x1E\xDCW__\xFD[` \x84\x01[\x83\x81\x10\x15a \"W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\xFEW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a\x1F\x13W__\xFD[a\x1F\x1Ba\x19\xDCV[` \x82\x015\x80\x15\x15\x81\x14a\x1F-W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1FGW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a\x1F_W__\xFD[a\x1Fga\x19pV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1F|W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a\x1F\x8CW__\xFD[\x805a\x1F\x9Aa\x1B\xFA\x82a\x1B!V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a\x1F\xBBW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x1F\xDDW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a\x1F\xC2V[\x84RPa\x1F\xEF\x91PP` \x84\x01a\x1AYV[` \x82\x01Ra \0`@\x84\x01a\x1A.V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa\x1E\xE1V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xE0\x826\x03\x12\x15a BW__\xFD[a Ja\x19\xDCV[a T6\x84a\x1D\x9AV[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a nW__\xFD[a z6\x82\x86\x01a\x1EEV[` \x83\x01RP\x92\x91PPV[_a\x02\xA76\x83a\x1EEV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x02\xA7WcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x82\x01Q`\x80\x82\x01\x90`\x03\x81\x10a \xF6WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x83\x01R`@\x83\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x84\x01\x91\x90\x91R``\x93\x84\x01Q\x16\x92\x90\x91\x01\x91\x90\x91R\x90V\xFE\xA2dipfsX\"\x12 \x1E\xA4\xE2]\x96\x89[\xF1\x84\xB3'\x07lk\t\x03\xCC\x9Eg\xD7Rz%<\xF6O\x83\xEEf\x99\x87\0dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b50600436106100cb575f3560e01c80637989aa1011610088578063afb63ad411610063578063afb63ad4146101b8578063b09f589a14610218578063b8b02e0e1461022b578063edbacd441461023e575f5ffd5b80637989aa101461017f578063a1ec933314610192578063a4aeca67146101a5575f5ffd5b806326303962146100cf5780632f1969b0146100f857806339c54aa114610118578063566bdcb91461012b5780635a2136151461013e5780635d27cc951461015f575b5f5ffd5b6100e26100dd3660046114d7565b61025e565b6040516100ef9190611625565b60405180910390f35b61010b610106366004611647565b6102ad565b6040516100ef9190611660565b61010b610126366004611695565b6102c6565b61010b6101393660046116db565b6102d9565b61015161014c36600461171c565b6102ec565b6040519081526020016100ef565b61017261016d3660046114d7565b610304565b6040516100ef919061183a565b61015161018d3660046118b4565b61034a565b6101516101a03660046118c5565b610362565b61010b6101b33660046116db565b61037a565b6101cb6101c63660046114d7565b61038d565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a0016100ef565b6101516102263660046118d6565b610404565b610151610239366004611919565b610417565b61025161024c3660046114d7565b610429565b6040516100ef919061194a565b610266611400565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061046f92505050565b90505b92915050565b60606102a76102c136849003840184611a7b565b6105a0565b60606102a76102d483611cb2565b610617565b60606102a76102e783611d11565b610734565b5f6102a76102ff36849003840184611d1c565b610838565b61030c611418565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061086792505050565b5f6102a761035d36849003840184611d80565b610b47565b5f6102a761037536849003840184611e2b565b610bab565b60606102a761038883612032565b610c1c565b6103c660408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610dfd92505050565b5f6102a48361041284611d11565b610e86565b5f6102a761042483612086565b610fef565b610431611479565b6102a483838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506111e892505050565b610477611400565b602082810151825160d09190911c905260268301518251909101526046820151815160609190911c604090910152605a820151605c83019060f01c806001600160401b038111156104ca576104ca61195c565b60405190808252806020026020018201604052801561051a57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816104e85790505b508351606001525f5b8161ffff168110156105685761053883611300565b85516060015180518490811061055057610550612091565b60209081029190910101919091529250600101610523565b50508051825160809081015160d09290921c909152600682015183518201516020015260269091015182519091015160400152919050565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d82019061060f90829061134f565b905050919050565b805160609081015151604e02608201806001600160401b0381111561063e5761063e61195c565b6040519080825280601f01601f191660200182016040528015610668576020820181803683370190505b5083515160d01b602080830191909152845101516026820152835160400151606090811b60468301528451015151909250605a8301906106a79061135b565b8351606001515160f01b81526002015f5b845160600151518110156106fa576106f082865f01516060015183815181106106e3576106e3612091565b6020026020010151611381565b91506001016106b8565b5083516080908101515160d01b82528451810151602001516006830152845101516040015160268201908152906046015b90505050919050565b60608181015151604e02608201806001600160401b038111156107595761075961195c565b6040519080825280601f01601f191660200182016040528015610783576020820181803683370190505b50835160d01b60208281019190915284015160268201526040840151606090811b604683015284015151909250605a8301906107be9061135b565b60608401515160f01b81526002015f5b84606001515181101561080b576107f582866060015183815181106106e3576106e3612091565b50610801604e836120a5565b91506001016107ce565b506080840180515160d01b825280516020015160068301525160400151602682019081529060460161072b565b5f8160405160200161084a91906120c4565b604051602081830303815290604052805190602001209050919050565b61086f611418565b602082810151825160d091821c905260268401518351606091821c910152603a840151835190821c90830152604080850151845190831c908201526046850151845160800152606685015184840180519190931c9052606c850151825190930192909252608c840151905160f89190911c910152608d820151608f83019060f01c806001600160401b038111156109085761090861195c565b60405190808252806020026020018201604052801561096b57816020015b6109586040805180820182525f8082528251606080820185528152602081810183905293810191909152909182015290565b8152602001906001900390816109265790505b506020840151606001525f5b8161ffff16811015610b39578251602085015160600151805160019095019460f89290921c918215159190849081106109b2576109b2612091565b60209081029190910101519015159052835160029094019360f01c806001600160401b038111156109e5576109e561195c565b604051908082528060200260200182016040528015610a0e578160200160208202803683370190505b508660200151606001518481518110610a2957610a29612091565b6020908102919091018101510151525f5b8161ffff16811015610a9e578551602087018860200151606001518681518110610a6657610a66612091565b6020026020010151602001515f01518381518110610a8657610a86612091565b60209081029190910101919091529550600101610a3a565b50845160e81c600386018760200151606001518581518110610ac257610ac2612091565b60209081029190910181015181015162ffffff909316920191909152805190955060d01c600686018760200151606001518581518110610b0457610b04612091565b6020026020010151602001516040018197508265ffffffffffff1665ffffffffffff1681525050505050806001019050610977565b505051815160a00152919050565b604080516003815260808101909152815165ffffffffffff1660208201525f906020830151604082015260408301516060820152805b50805160051b6020820120610ba48280516040516001820160051b83011490151060061b52565b9392505050565b604080516006815260e08101909152815165ffffffffffff1660208201525f90602083015165ffffffffffff166040820152604083015165ffffffffffff16606082015260608301516001600160a01b03166080820152608083015160a082015260a083015160c082015280610b7d565b60605f610c308360200151606001516113b6565b9050806001600160401b03811115610c4a57610c4a61195c565b6040519080825280601f01601f191660200182016040528015610c74576020820181803683370190505b5083515160d090811b6020838101919091528551606090810151901b60268401528551810151821b603a8401528551604090810151831b81850152865160800151604685015281870180515190931b6066850152825190910151606c84015290510151909250608c830190610cea90829061134f565b60208501516060015151909150610d008161135b565b610d10828260f01b815260020190565b91505f5b81811015610ded575f8660200151606001518281518110610d3757610d37612091565b60200260200101519050610d5a84825f0151610d53575f61134f565b600161134f565b60208201515151909450610d6d8161135b565b610d7d858260f01b815260020190565b94505f5b81811015610dc057610db68684602001515f01518381518110610da657610da6612091565b6020026020010151815260200190565b9550600101610d81565b5050602090810180519091015160e81b8452516040015160d01b6003840152600990920191600101610d14565b5050925160a00151909252919050565b610e3660408051606080820183525f80835283519182018452808252602082810182905293820152909182019081525f60209091015290565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b606081015180515f9190600a600482020183610eb28260408051828152600190920160051b8201905290565b602081018890529050604080820152855165ffffffffffff1660608201526020860151608082015260408601516001600160a01b031660a082015260e060c082015260808601515165ffffffffffff1660e08201526080860151602001516101008201526080860151604001516101208201526101408101839052600a5f5b84811015610fbc575f868281518110610f4c57610f4c612091565b602090810291909101015180516001600160a01b03166001850160051b860152905060208101516001600160a01b03166002840160051b850152604081015165ffffffffffff166003840160051b85015260608101516004840160051b8501525060049190910190600101610f31565b50815160051b6020830120610fe38380516040516001820160051b83011490151060061b52565b98975050505050505050565b606081015180515f919060068101835b8281101561103b5783818151811061101957611019612091565b6020026020010151602001515f01515160060182019150806001019050610fff565b50604080518281526001830160051b8101909152602080820152855165ffffffffffff16604082015260208601516060820152604086015160ff166080820152608060a082015260c0810183905260068381015f5b858110156111c1575f8782815181106110ab576110ab612091565b602002602001015190506110d4858386016005878703901b5f1b60019190910160051b82015290565b506110fd8584835f01516110e8575f6110eb565b60015b60ff1660019190910160051b82015290565b5060406002840160051b86015260606003840160051b86015260028301602080830151015162ffffff166002820160051b87015260208201516040015165ffffffffffff166003820160051b87015260208201515180516004830160051b8801819052600383015f5b828110156111aa576111a18a82846001010186848151811061118a5761118a612091565b602002602001015160019190910160051b82015290565b50600101611166565b500160019081019550939093019250611090915050565b50825160051b6020840120610fe38480516040516001820160051b83011490151060061b52565b6111f0611479565b60208281015160d01c8252602683015190820152604682015160601c6040820152605a820151605c83019060f01c806001600160401b038111156112365761123661195c565b60405190808252806020026020018201604052801561128657816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816112545790505b5060608401525f5b8161ffff168110156112d1576112a383611300565b856060015183815181106112b9576112b9612091565b6020908102919091010191909152925060010161128e565b5050805160808301805160d09290921c9091526006820151815160200152602690910151905160400152919050565b604080516080810182525f8082526020820181815292820181815260608084019283528551811c84526014860151901c909352602884015160d01c909252602e83015190915291604e90910190565b5f818353505060010190565b61ffff81111561137e5760405163161e7a6b60e11b815260040160405180910390fd5b50565b8051606090811b83526020820151811b6014840152604082015160d01b6028840152810151602e8301908152604e83016102a4565b608f5f5b82518110156113fa578281815181106113d5576113d5612091565b6020026020010151602001515f015151602002600c01820191508060010190506113ba565b50919050565b6040518060200160405280611413611479565b905290565b60408051610100810182525f918101828152606082018390526080820183905260a0820183905260c0820183905260e08201929092529081908152604080516080810182525f80825260208281018290529282015260608082015291015290565b6040518060a001604052805f65ffffffffffff1681526020015f81526020015f6001600160a01b031681526020016060815260200161141360405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b5f5f602083850312156114e8575f5ffd5b82356001600160401b038111156114fd575f5ffd5b8301601f8101851361150d575f5ffd5b80356001600160401b03811115611522575f5ffd5b856020828401011115611533575f5ffd5b6020919091019590945092505050565b805165ffffffffffff168252602080820151818401526040808301516001600160a01b03169084015260608083015160e091850182905280519185018290525f92019082906101008601905b808310156115eb57835160018060a01b03815116835260018060a01b03602082015116602084015265ffffffffffff6040820151166040840152606081015160608401525060808201915060208401935060018301925061158f565b506080850151925061161c6080870184805165ffffffffffff16825260208082015190830152604090810151910152565b95945050505050565b602081525f825160208084015261163f6040840182611543565b949350505050565b5f60a0828403128015611658575f5ffd5b509092915050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f602082840312156116a5575f5ffd5b81356001600160401b038111156116ba575f5ffd5b820160208185031215610ba4575f5ffd5b5f60e082840312156113fa575f5ffd5b5f602082840312156116eb575f5ffd5b81356001600160401b03811115611700575f5ffd5b61163f848285016116cb565b5f608082840312156113fa575f5ffd5b5f6080828403121561172c575f5ffd5b6102a4838361170c565b5f6080830165ffffffffffff83511684526020830151602085015260ff604084015116604085015260608301516080606086015281815180845260a08701915060a08160051b88010193506020830192505f5b8181101561182e57878503609f19018352835180511515865260209081015160408288018190528151606091890191909152805160a08901819052919201905f9060c08901905b808310156117f357835182526020820191506020840193506001830192506117d0565b5060208481015162ffffff1660608b015260409094015165ffffffffffff166080909901989098525050938401939290920191600101611789565b50929695505050505050565b602081525f825165ffffffffffff815116602084015265ffffffffffff602082015116604084015265ffffffffffff604082015116606084015260018060a01b036060820151166080840152608081015160a084015260a081015160c084015250602083015160e08084015261163f610100840182611736565b5f6060828403128015611658575f5ffd5b5f60c0828403128015611658575f5ffd5b5f5f604083850312156118e7575f5ffd5b8235915060208301356001600160401b03811115611903575f5ffd5b61190f858286016116cb565b9150509250929050565b5f60208284031215611929575f5ffd5b81356001600160401b0381111561193e575f5ffd5b61163f8482850161170c565b602081525f6102a46020830184611543565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b03811182821017156119925761199261195c565b60405290565b60405160a081016001600160401b03811182821017156119925761199261195c565b604051608081016001600160401b03811182821017156119925761199261195c565b604080519081016001600160401b03811182821017156119925761199261195c565b604051601f8201601f191681016001600160401b0381118282101715611a2657611a2661195c565b604052919050565b803565ffffffffffff81168114611a43575f5ffd5b919050565b803561ffff81168114611a43575f5ffd5b803562ffffff81168114611a43575f5ffd5b803560ff81168114611a43575f5ffd5b5f81830360a081128015611a8d575f5ffd5b50611a96611970565b611a9f84611a2e565b81526060601f1983011215611ab2575f5ffd5b611aba611970565b9150611ac860208501611a48565b8252611ad660408501611a48565b6020830152611ae760608501611a59565b6040830152816020820152611afe60808501611a6b565b6040820152949350505050565b80356001600160a01b0381168114611a43575f5ffd5b5f6001600160401b03821115611b3957611b3961195c565b5060051b60200190565b5f60608284031215611b53575f5ffd5b611b5b611970565b9050611b6682611a2e565b81526020828101359082015260409182013591810191909152919050565b5f60e08284031215611b94575f5ffd5b611b9c611998565b9050611ba782611a2e565b815260208281013590820152611bbf60408301611b0b565b604082015260608201356001600160401b03811115611bdc575f5ffd5b8201601f81018413611bec575f5ffd5b8035611bff611bfa82611b21565b6119fe565b8082825260208201915060208360071b850101925086831115611c20575f5ffd5b6020840193505b82841015611c905760808488031215611c3e575f5ffd5b611c466119ba565b611c4f85611b0b565b8152611c5d60208601611b0b565b6020820152611c6e60408601611a2e565b6040820152606085810135908201528252608090930192602090910190611c27565b80606086015250505050611ca78360808401611b43565b608082015292915050565b5f60208236031215611cc2575f5ffd5b604051602081016001600160401b0381118282101715611ce457611ce461195c565b60405282356001600160401b03811115611cfc575f5ffd5b611d0836828601611b84565b82525092915050565b5f6102a73683611b84565b5f6080828403128015611d2d575f5ffd5b50611d366119ba565b611d3f83611a2e565b8152602083013560038110611d52575f5ffd5b6020820152611d6360408401611b0b565b6040820152611d7460608401611b0b565b60608201529392505050565b5f60608284031215611d90575f5ffd5b6102a48383611b43565b5f60c08284031215611daa575f5ffd5b60405160c081016001600160401b0381118282101715611dcc57611dcc61195c565b604052905080611ddb83611a2e565b8152611de960208401611a2e565b6020820152611dfa60408401611a2e565b6040820152611e0b60608401611b0b565b60608201526080838101359082015260a092830135920191909152919050565b5f60c08284031215611e3b575f5ffd5b6102a48383611d9a565b5f60808284031215611e55575f5ffd5b611e5d6119ba565b9050611e6882611a2e565b815260208281013590820152611e8060408301611a6b565b604082015260608201356001600160401b03811115611e9d575f5ffd5b8201601f81018413611ead575f5ffd5b8035611ebb611bfa82611b21565b8082825260208201915060208360051b850101925086831115611edc575f5ffd5b602084015b838110156120225780356001600160401b03811115611efe575f5ffd5b85016040818a03601f19011215611f13575f5ffd5b611f1b6119dc565b60208201358015158114611f2d575f5ffd5b815260408201356001600160401b03811115611f47575f5ffd5b6020818401019250506060828b031215611f5f575f5ffd5b611f67611970565b82356001600160401b03811115611f7c575f5ffd5b8301601f81018c13611f8c575f5ffd5b8035611f9a611bfa82611b21565b8082825260208201915060208360051b85010192508e831115611fbb575f5ffd5b6020840193505b82841015611fdd578335825260209384019390910190611fc2565b845250611fef91505060208401611a59565b602082015261200060408401611a2e565b6040820152806020830152508085525050602083019250602081019050611ee1565b5060608501525091949350505050565b5f60e08236031215612042575f5ffd5b61204a6119dc565b6120543684611d9a565b815260c08301356001600160401b0381111561206e575f5ffd5b61207a36828601611e45565b60208301525092915050565b5f6102a73683611e45565b634e487b7160e01b5f52603260045260245ffd5b808201808211156102a757634e487b7160e01b5f52601160045260245ffd5b815165ffffffffffff16815260208201516080820190600381106120f657634e487b7160e01b5f52602160045260245ffd5b60208301526040838101516001600160a01b03908116918401919091526060938401511692909101919091529056fea26469706673582212201ea4e25d96895bf184b327076c6b0903cc9e67d7527a253cf64f83ee6699870064736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0\xCBW_5`\xE0\x1C\x80cy\x89\xAA\x10\x11a\0\x88W\x80c\xAF\xB6:\xD4\x11a\0cW\x80c\xAF\xB6:\xD4\x14a\x01\xB8W\x80c\xB0\x9FX\x9A\x14a\x02\x18W\x80c\xB8\xB0.\x0E\x14a\x02+W\x80c\xED\xBA\xCDD\x14a\x02>W__\xFD[\x80cy\x89\xAA\x10\x14a\x01\x7FW\x80c\xA1\xEC\x933\x14a\x01\x92W\x80c\xA4\xAE\xCAg\x14a\x01\xA5W__\xFD[\x80c&09b\x14a\0\xCFW\x80c/\x19i\xB0\x14a\0\xF8W\x80c9\xC5J\xA1\x14a\x01\x18W\x80cVk\xDC\xB9\x14a\x01+W\x80cZ!6\x15\x14a\x01>W\x80c]'\xCC\x95\x14a\x01_W[__\xFD[a\0\xE2a\0\xDD6`\x04a\x14\xD7V[a\x02^V[`@Qa\0\xEF\x91\x90a\x16%V[`@Q\x80\x91\x03\x90\xF3[a\x01\x0Ba\x01\x066`\x04a\x16GV[a\x02\xADV[`@Qa\0\xEF\x91\x90a\x16`V[a\x01\x0Ba\x01&6`\x04a\x16\x95V[a\x02\xC6V[a\x01\x0Ba\x0196`\x04a\x16\xDBV[a\x02\xD9V[a\x01Qa\x01L6`\x04a\x17\x1CV[a\x02\xECV[`@Q\x90\x81R` \x01a\0\xEFV[a\x01ra\x01m6`\x04a\x14\xD7V[a\x03\x04V[`@Qa\0\xEF\x91\x90a\x18:V[a\x01Qa\x01\x8D6`\x04a\x18\xB4V[a\x03JV[a\x01Qa\x01\xA06`\x04a\x18\xC5V[a\x03bV[a\x01\x0Ba\x01\xB36`\x04a\x16\xDBV[a\x03zV[a\x01\xCBa\x01\xC66`\x04a\x14\xD7V[a\x03\x8DV[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\0\xEFV[a\x01Qa\x02&6`\x04a\x18\xD6V[a\x04\x04V[a\x01Qa\x0296`\x04a\x19\x19V[a\x04\x17V[a\x02Qa\x02L6`\x04a\x14\xD7V[a\x04)V[`@Qa\0\xEF\x91\x90a\x19JV[a\x02fa\x14\0V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x04o\x92PPPV[\x90P[\x92\x91PPV[``a\x02\xA7a\x02\xC16\x84\x90\x03\x84\x01\x84a\x1A{V[a\x05\xA0V[``a\x02\xA7a\x02\xD4\x83a\x1C\xB2V[a\x06\x17V[``a\x02\xA7a\x02\xE7\x83a\x1D\x11V[a\x074V[_a\x02\xA7a\x02\xFF6\x84\x90\x03\x84\x01\x84a\x1D\x1CV[a\x088V[a\x03\x0Ca\x14\x18V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x08g\x92PPPV[_a\x02\xA7a\x03]6\x84\x90\x03\x84\x01\x84a\x1D\x80V[a\x0BGV[_a\x02\xA7a\x03u6\x84\x90\x03\x84\x01\x84a\x1E+V[a\x0B\xABV[``a\x02\xA7a\x03\x88\x83a 2V[a\x0C\x1CV[a\x03\xC6`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\r\xFD\x92PPPV[_a\x02\xA4\x83a\x04\x12\x84a\x1D\x11V[a\x0E\x86V[_a\x02\xA7a\x04$\x83a \x86V[a\x0F\xEFV[a\x041a\x14yV[a\x02\xA4\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x11\xE8\x92PPPV[a\x04wa\x14\0V[` \x82\x81\x01Q\x82Q`\xD0\x91\x90\x91\x1C\x90R`&\x83\x01Q\x82Q\x90\x91\x01R`F\x82\x01Q\x81Q``\x91\x90\x91\x1C`@\x90\x91\x01R`Z\x82\x01Q`\\\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x04\xCAWa\x04\xCAa\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x05\x1AW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x04\xE8W\x90P[P\x83Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x05hWa\x058\x83a\x13\0V[\x85Q``\x01Q\x80Q\x84\x90\x81\x10a\x05PWa\x05Pa \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x05#V[PP\x80Q\x82Q`\x80\x90\x81\x01Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x82\x01Q\x83Q\x82\x01Q` \x01R`&\x90\x91\x01Q\x82Q\x90\x91\x01Q`@\x01R\x91\x90PV[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x06\x0F\x90\x82\x90a\x13OV[\x90PP\x91\x90PV[\x80Q``\x90\x81\x01QQ`N\x02`\x82\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06>Wa\x06>a\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x06hW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x1B` \x80\x83\x01\x91\x90\x91R\x84Q\x01Q`&\x82\x01R\x83Q`@\x01Q``\x90\x81\x1B`F\x83\x01R\x84Q\x01QQ\x90\x92P`Z\x83\x01\x90a\x06\xA7\x90a\x13[V[\x83Q``\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84Q``\x01QQ\x81\x10\x15a\x06\xFAWa\x06\xF0\x82\x86_\x01Q``\x01Q\x83\x81Q\x81\x10a\x06\xE3Wa\x06\xE3a \x91V[` \x02` \x01\x01Qa\x13\x81V[\x91P`\x01\x01a\x06\xB8V[P\x83Q`\x80\x90\x81\x01QQ`\xD0\x1B\x82R\x84Q\x81\x01Q` \x01Q`\x06\x83\x01R\x84Q\x01Q`@\x01Q`&\x82\x01\x90\x81R\x90`F\x01[\x90PPP\x91\x90PV[``\x81\x81\x01QQ`N\x02`\x82\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x07YWa\x07Ya\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x07\x83W` \x82\x01\x81\x806\x837\x01\x90P[P\x83Q`\xD0\x1B` \x82\x81\x01\x91\x90\x91R\x84\x01Q`&\x82\x01R`@\x84\x01Q``\x90\x81\x1B`F\x83\x01R\x84\x01QQ\x90\x92P`Z\x83\x01\x90a\x07\xBE\x90a\x13[V[``\x84\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x84``\x01QQ\x81\x10\x15a\x08\x0BWa\x07\xF5\x82\x86``\x01Q\x83\x81Q\x81\x10a\x06\xE3Wa\x06\xE3a \x91V[Pa\x08\x01`N\x83a \xA5V[\x91P`\x01\x01a\x07\xCEV[P`\x80\x84\x01\x80QQ`\xD0\x1B\x82R\x80Q` \x01Q`\x06\x83\x01RQ`@\x01Q`&\x82\x01\x90\x81R\x90`F\x01a\x07+V[_\x81`@Q` \x01a\x08J\x91\x90a \xC4V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[a\x08oa\x14\x18V[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q``\x91\x82\x1C\x91\x01R`:\x84\x01Q\x83Q\x90\x82\x1C\x90\x83\x01R`@\x80\x85\x01Q\x84Q\x90\x83\x1C\x90\x82\x01R`F\x85\x01Q\x84Q`\x80\x01R`f\x85\x01Q\x84\x84\x01\x80Q\x91\x90\x93\x1C\x90R`l\x85\x01Q\x82Q\x90\x93\x01\x92\x90\x92R`\x8C\x84\x01Q\x90Q`\xF8\x91\x90\x91\x1C\x91\x01R`\x8D\x82\x01Q`\x8F\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\x08Wa\t\x08a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\tkW\x81` \x01[a\tX`@\x80Q\x80\x82\x01\x82R_\x80\x82R\x82Q``\x80\x82\x01\x85R\x81R` \x81\x81\x01\x83\x90R\x93\x81\x01\x91\x90\x91R\x90\x91\x82\x01R\x90V[\x81R` \x01\x90`\x01\x90\x03\x90\x81a\t&W\x90P[P` \x84\x01Q``\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x0B9W\x82Q` \x85\x01Q``\x01Q\x80Q`\x01\x90\x95\x01\x94`\xF8\x92\x90\x92\x1C\x91\x82\x15\x15\x91\x90\x84\x90\x81\x10a\t\xB2Wa\t\xB2a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x90\x15\x15\x90R\x83Q`\x02\x90\x94\x01\x93`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xE5Wa\t\xE5a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\n\x0EW\x81` \x01` \x82\x02\x806\x837\x01\x90P[P\x86` \x01Q``\x01Q\x84\x81Q\x81\x10a\n)Wa\n)a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x01QR_[\x81a\xFF\xFF\x16\x81\x10\x15a\n\x9EW\x85Q` \x87\x01\x88` \x01Q``\x01Q\x86\x81Q\x81\x10a\nfWa\nfa \x91V[` \x02` \x01\x01Q` \x01Q_\x01Q\x83\x81Q\x81\x10a\n\x86Wa\n\x86a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x95P`\x01\x01a\n:V[P\x84Q`\xE8\x1C`\x03\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\n\xC2Wa\n\xC2a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q\x81\x01Qb\xFF\xFF\xFF\x90\x93\x16\x92\x01\x91\x90\x91R\x80Q\x90\x95P`\xD0\x1C`\x06\x86\x01\x87` \x01Q``\x01Q\x85\x81Q\x81\x10a\x0B\x04Wa\x0B\x04a \x91V[` \x02` \x01\x01Q` \x01Q`@\x01\x81\x97P\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81RPPPPP\x80`\x01\x01\x90Pa\twV[PPQ\x81Q`\xA0\x01R\x91\x90PV[`@\x80Q`\x03\x81R`\x80\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Q`@\x82\x01R`@\x83\x01Q``\x82\x01R\x80[P\x80Q`\x05\x1B` \x82\x01 a\x0B\xA4\x82\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x93\x92PPPV[`@\x80Q`\x06\x81R`\xE0\x81\x01\x90\x91R\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16` \x82\x01R_\x90` \x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x80\x82\x01R`\x80\x83\x01Q`\xA0\x82\x01R`\xA0\x83\x01Q`\xC0\x82\x01R\x80a\x0B}V[``_a\x0C0\x83` \x01Q``\x01Qa\x13\xB6V[\x90P\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0CJWa\x0CJa\x19\\V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x0CtW` \x82\x01\x81\x806\x837\x01\x90P[P\x83QQ`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x85Q``\x90\x81\x01Q\x90\x1B`&\x84\x01R\x85Q\x81\x01Q\x82\x1B`:\x84\x01R\x85Q`@\x90\x81\x01Q\x83\x1B\x81\x85\x01R\x86Q`\x80\x01Q`F\x85\x01R\x81\x87\x01\x80QQ\x90\x93\x1B`f\x85\x01R\x82Q\x90\x91\x01Q`l\x84\x01R\x90Q\x01Q\x90\x92P`\x8C\x83\x01\x90a\x0C\xEA\x90\x82\x90a\x13OV[` \x85\x01Q``\x01QQ\x90\x91Pa\r\0\x81a\x13[V[a\r\x10\x82\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x91P_[\x81\x81\x10\x15a\r\xEDW_\x86` \x01Q``\x01Q\x82\x81Q\x81\x10a\r7Wa\r7a \x91V[` \x02` \x01\x01Q\x90Pa\rZ\x84\x82_\x01Qa\rSW_a\x13OV[`\x01a\x13OV[` \x82\x01QQQ\x90\x94Pa\rm\x81a\x13[V[a\r}\x85\x82`\xF0\x1B\x81R`\x02\x01\x90V[\x94P_[\x81\x81\x10\x15a\r\xC0Wa\r\xB6\x86\x84` \x01Q_\x01Q\x83\x81Q\x81\x10a\r\xA6Wa\r\xA6a \x91V[` \x02` \x01\x01Q\x81R` \x01\x90V[\x95P`\x01\x01a\r\x81V[PP` \x90\x81\x01\x80Q\x90\x91\x01Q`\xE8\x1B\x84RQ`@\x01Q`\xD0\x1B`\x03\x84\x01R`\t\x90\x92\x01\x91`\x01\x01a\r\x14V[PP\x92Q`\xA0\x01Q\x90\x92R\x91\x90PV[a\x0E6`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90\x81R_` \x90\x91\x01R\x90V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[``\x81\x01Q\x80Q_\x91\x90`\n`\x04\x82\x02\x01\x83a\x0E\xB2\x82`@\x80Q\x82\x81R`\x01\x90\x92\x01`\x05\x1B\x82\x01\x90R\x90V[` \x81\x01\x88\x90R\x90P`@\x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R` \x86\x01Q`\x80\x82\x01R`@\x86\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\xA0\x82\x01R`\xE0`\xC0\x82\x01R`\x80\x86\x01QQe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xE0\x82\x01R`\x80\x86\x01Q` \x01Qa\x01\0\x82\x01R`\x80\x86\x01Q`@\x01Qa\x01 \x82\x01Ra\x01@\x81\x01\x83\x90R`\n_[\x84\x81\x10\x15a\x0F\xBCW_\x86\x82\x81Q\x81\x10a\x0FLWa\x0FLa \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16`\x01\x85\x01`\x05\x1B\x86\x01R\x90P` \x81\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x02\x84\x01`\x05\x1B\x85\x01R`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x84\x01`\x05\x1B\x85\x01R``\x81\x01Q`\x04\x84\x01`\x05\x1B\x85\x01RP`\x04\x91\x90\x91\x01\x90`\x01\x01a\x0F1V[P\x81Q`\x05\x1B` \x83\x01 a\x0F\xE3\x83\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x98\x97PPPPPPPPV[``\x81\x01Q\x80Q_\x91\x90`\x06\x81\x01\x83[\x82\x81\x10\x15a\x10;W\x83\x81\x81Q\x81\x10a\x10\x19Wa\x10\x19a \x91V[` \x02` \x01\x01Q` \x01Q_\x01QQ`\x06\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x0F\xFFV[P`@\x80Q\x82\x81R`\x01\x83\x01`\x05\x1B\x81\x01\x90\x91R` \x80\x82\x01R\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\xFF\x16`\x80\x82\x01R`\x80`\xA0\x82\x01R`\xC0\x81\x01\x83\x90R`\x06\x83\x81\x01_[\x85\x81\x10\x15a\x11\xC1W_\x87\x82\x81Q\x81\x10a\x10\xABWa\x10\xABa \x91V[` \x02` \x01\x01Q\x90Pa\x10\xD4\x85\x83\x86\x01`\x05\x87\x87\x03\x90\x1B_\x1B`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[Pa\x10\xFD\x85\x84\x83_\x01Qa\x10\xE8W_a\x10\xEBV[`\x01[`\xFF\x16`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`@`\x02\x84\x01`\x05\x1B\x86\x01R```\x03\x84\x01`\x05\x1B\x86\x01R`\x02\x83\x01` \x80\x83\x01Q\x01Qb\xFF\xFF\xFF\x16`\x02\x82\x01`\x05\x1B\x87\x01R` \x82\x01Q`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x82\x01`\x05\x1B\x87\x01R` \x82\x01QQ\x80Q`\x04\x83\x01`\x05\x1B\x88\x01\x81\x90R`\x03\x83\x01_[\x82\x81\x10\x15a\x11\xAAWa\x11\xA1\x8A\x82\x84`\x01\x01\x01\x86\x84\x81Q\x81\x10a\x11\x8AWa\x11\x8Aa \x91V[` \x02` \x01\x01Q`\x01\x91\x90\x91\x01`\x05\x1B\x82\x01R\x90V[P`\x01\x01a\x11fV[P\x01`\x01\x90\x81\x01\x95P\x93\x90\x93\x01\x92Pa\x10\x90\x91PPV[P\x82Q`\x05\x1B` \x84\x01 a\x0F\xE3\x84\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[a\x11\xF0a\x14yV[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x90\x82\x01R`F\x82\x01Q``\x1C`@\x82\x01R`Z\x82\x01Q`\\\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x126Wa\x126a\x19\\V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x12\x86W\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x12TW\x90P[P``\x84\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x12\xD1Wa\x12\xA3\x83a\x13\0V[\x85``\x01Q\x83\x81Q\x81\x10a\x12\xB9Wa\x12\xB9a \x91V[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x12\x8EV[PP\x80Q`\x80\x83\x01\x80Q`\xD0\x92\x90\x92\x1C\x90\x91R`\x06\x82\x01Q\x81Q` \x01R`&\x90\x91\x01Q\x90Q`@\x01R\x91\x90PV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x92\x83R\x85Q\x81\x1C\x84R`\x14\x86\x01Q\x90\x1C\x90\x93R`(\x84\x01Q`\xD0\x1C\x90\x92R`.\x83\x01Q\x90\x91R\x91`N\x90\x91\x01\x90V[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x13~W`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q``\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x14\x84\x01R`@\x82\x01Q`\xD0\x1B`(\x84\x01R\x81\x01Q`.\x83\x01\x90\x81R`N\x83\x01a\x02\xA4V[`\x8F_[\x82Q\x81\x10\x15a\x13\xFAW\x82\x81\x81Q\x81\x10a\x13\xD5Wa\x13\xD5a \x91V[` \x02` \x01\x01Q` \x01Q_\x01QQ` \x02`\x0C\x01\x82\x01\x91P\x80`\x01\x01\x90Pa\x13\xBAV[P\x91\x90PV[`@Q\x80` \x01`@R\x80a\x14\x13a\x14yV[\x90R\x90V[`@\x80Qa\x01\0\x81\x01\x82R_\x91\x81\x01\x82\x81R``\x82\x01\x83\x90R`\x80\x82\x01\x83\x90R`\xA0\x82\x01\x83\x90R`\xC0\x82\x01\x83\x90R`\xE0\x82\x01\x92\x90\x92R\x90\x81\x90\x81R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x81\x01\x82\x90R\x92\x82\x01R``\x80\x82\x01R\x91\x01R\x90V[`@Q\x80`\xA0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01``\x81R` \x01a\x14\x13`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[__` \x83\x85\x03\x12\x15a\x14\xE8W__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x14\xFDW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\x15\rW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x15\"W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\x153W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82R` \x80\x82\x01Q\x81\x84\x01R`@\x80\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x84\x01R``\x80\x83\x01Q`\xE0\x91\x85\x01\x82\x90R\x80Q\x91\x85\x01\x82\x90R_\x92\x01\x90\x82\x90a\x01\0\x86\x01\x90[\x80\x83\x10\x15a\x15\xEBW\x83Q`\x01\x80`\xA0\x1B\x03\x81Q\x16\x83R`\x01\x80`\xA0\x1B\x03` \x82\x01Q\x16` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16`@\x84\x01R``\x81\x01Q``\x84\x01RP`\x80\x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x15\x8FV[P`\x80\x85\x01Q\x92Pa\x16\x1C`\x80\x87\x01\x84\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x82R` \x80\x82\x01Q\x90\x83\x01R`@\x90\x81\x01Q\x91\x01RV[\x95\x94PPPPPV[` \x81R_\x82Q` \x80\x84\x01Ra\x16?`@\x84\x01\x82a\x15CV[\x94\x93PPPPV[_`\xA0\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[P\x90\x92\x91PPV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_` \x82\x84\x03\x12\x15a\x16\xA5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\xBAW__\xFD[\x82\x01` \x81\x85\x03\x12\x15a\x0B\xA4W__\xFD[_`\xE0\x82\x84\x03\x12\x15a\x13\xFAW__\xFD[_` \x82\x84\x03\x12\x15a\x16\xEBW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17\0W__\xFD[a\x16?\x84\x82\x85\x01a\x16\xCBV[_`\x80\x82\x84\x03\x12\x15a\x13\xFAW__\xFD[_`\x80\x82\x84\x03\x12\x15a\x17,W__\xFD[a\x02\xA4\x83\x83a\x17\x0CV[_`\x80\x83\x01e\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x84R` \x83\x01Q` \x85\x01R`\xFF`@\x84\x01Q\x16`@\x85\x01R``\x83\x01Q`\x80``\x86\x01R\x81\x81Q\x80\x84R`\xA0\x87\x01\x91P`\xA0\x81`\x05\x1B\x88\x01\x01\x93P` \x83\x01\x92P_[\x81\x81\x10\x15a\x18.W\x87\x85\x03`\x9F\x19\x01\x83R\x83Q\x80Q\x15\x15\x86R` \x90\x81\x01Q`@\x82\x88\x01\x81\x90R\x81Q``\x91\x89\x01\x91\x90\x91R\x80Q`\xA0\x89\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x89\x01\x90[\x80\x83\x10\x15a\x17\xF3W\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x17\xD0V[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x8B\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x99\x01\x98\x90\x98RPP\x93\x84\x01\x93\x92\x90\x92\x01\x91`\x01\x01a\x17\x89V[P\x92\x96\x95PPPPPPV[` \x81R_\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16`@\x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x82\x01Q\x16``\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16`\x80\x84\x01R`\x80\x81\x01Q`\xA0\x84\x01R`\xA0\x81\x01Q`\xC0\x84\x01RP` \x83\x01Q`\xE0\x80\x84\x01Ra\x16?a\x01\0\x84\x01\x82a\x176V[_``\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[_`\xC0\x82\x84\x03\x12\x80\x15a\x16XW__\xFD[__`@\x83\x85\x03\x12\x15a\x18\xE7W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\x03W__\xFD[a\x19\x0F\x85\x82\x86\x01a\x16\xCBV[\x91PP\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a\x19)W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19>W__\xFD[a\x16?\x84\x82\x85\x01a\x17\x0CV[` \x81R_a\x02\xA4` \x83\x01\x84a\x15CV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x19\x92Wa\x19\x92a\x19\\V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1A&Wa\x1A&a\x19\\V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x1ACW__\xFD[\x805`\xFF\x81\x16\x81\x14a\x1ACW__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x1A\x8DW__\xFD[Pa\x1A\x96a\x19pV[a\x1A\x9F\x84a\x1A.V[\x81R```\x1F\x19\x83\x01\x12\x15a\x1A\xB2W__\xFD[a\x1A\xBAa\x19pV[\x91Pa\x1A\xC8` \x85\x01a\x1AHV[\x82Ra\x1A\xD6`@\x85\x01a\x1AHV[` \x83\x01Ra\x1A\xE7``\x85\x01a\x1AYV[`@\x83\x01R\x81` \x82\x01Ra\x1A\xFE`\x80\x85\x01a\x1AkV[`@\x82\x01R\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x1ACW__\xFD[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1B9Wa\x1B9a\x19\\V[P`\x05\x1B` \x01\x90V[_``\x82\x84\x03\x12\x15a\x1BSW__\xFD[a\x1B[a\x19pV[\x90Pa\x1Bf\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01R`@\x91\x82\x015\x91\x81\x01\x91\x90\x91R\x91\x90PV[_`\xE0\x82\x84\x03\x12\x15a\x1B\x94W__\xFD[a\x1B\x9Ca\x19\x98V[\x90Pa\x1B\xA7\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1B\xBF`@\x83\x01a\x1B\x0BV[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1B\xDCW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1B\xECW__\xFD[\x805a\x1B\xFFa\x1B\xFA\x82a\x1B!V[a\x19\xFEV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a\x1C W__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x1C\x90W`\x80\x84\x88\x03\x12\x15a\x1C>W__\xFD[a\x1CFa\x19\xBAV[a\x1CO\x85a\x1B\x0BV[\x81Ra\x1C]` \x86\x01a\x1B\x0BV[` \x82\x01Ra\x1Cn`@\x86\x01a\x1A.V[`@\x82\x01R``\x85\x81\x015\x90\x82\x01R\x82R`\x80\x90\x93\x01\x92` \x90\x91\x01\x90a\x1C'V[\x80``\x86\x01RPPPPa\x1C\xA7\x83`\x80\x84\x01a\x1BCV[`\x80\x82\x01R\x92\x91PPV[_` \x826\x03\x12\x15a\x1C\xC2W__\xFD[`@Q` \x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1C\xE4Wa\x1C\xE4a\x19\\V[`@R\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1C\xFCW__\xFD[a\x1D\x086\x82\x86\x01a\x1B\x84V[\x82RP\x92\x91PPV[_a\x02\xA76\x83a\x1B\x84V[_`\x80\x82\x84\x03\x12\x80\x15a\x1D-W__\xFD[Pa\x1D6a\x19\xBAV[a\x1D?\x83a\x1A.V[\x81R` \x83\x015`\x03\x81\x10a\x1DRW__\xFD[` \x82\x01Ra\x1Dc`@\x84\x01a\x1B\x0BV[`@\x82\x01Ra\x1Dt``\x84\x01a\x1B\x0BV[``\x82\x01R\x93\x92PPPV[_``\x82\x84\x03\x12\x15a\x1D\x90W__\xFD[a\x02\xA4\x83\x83a\x1BCV[_`\xC0\x82\x84\x03\x12\x15a\x1D\xAAW__\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x1D\xCCWa\x1D\xCCa\x19\\V[`@R\x90P\x80a\x1D\xDB\x83a\x1A.V[\x81Ra\x1D\xE9` \x84\x01a\x1A.V[` \x82\x01Ra\x1D\xFA`@\x84\x01a\x1A.V[`@\x82\x01Ra\x1E\x0B``\x84\x01a\x1B\x0BV[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01R`\xA0\x92\x83\x015\x92\x01\x91\x90\x91R\x91\x90PV[_`\xC0\x82\x84\x03\x12\x15a\x1E;W__\xFD[a\x02\xA4\x83\x83a\x1D\x9AV[_`\x80\x82\x84\x03\x12\x15a\x1EUW__\xFD[a\x1E]a\x19\xBAV[\x90Pa\x1Eh\x82a\x1A.V[\x81R` \x82\x81\x015\x90\x82\x01Ra\x1E\x80`@\x83\x01a\x1AkV[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\x9DW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x1E\xADW__\xFD[\x805a\x1E\xBBa\x1B\xFA\x82a\x1B!V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a\x1E\xDCW__\xFD[` \x84\x01[\x83\x81\x10\x15a \"W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1E\xFEW__\xFD[\x85\x01`@\x81\x8A\x03`\x1F\x19\x01\x12\x15a\x1F\x13W__\xFD[a\x1F\x1Ba\x19\xDCV[` \x82\x015\x80\x15\x15\x81\x14a\x1F-W__\xFD[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1FGW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8B\x03\x12\x15a\x1F_W__\xFD[a\x1Fga\x19pV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1F|W__\xFD[\x83\x01`\x1F\x81\x01\x8C\x13a\x1F\x8CW__\xFD[\x805a\x1F\x9Aa\x1B\xFA\x82a\x1B!V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8E\x83\x11\x15a\x1F\xBBW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x1F\xDDW\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a\x1F\xC2V[\x84RPa\x1F\xEF\x91PP` \x84\x01a\x1AYV[` \x82\x01Ra \0`@\x84\x01a\x1A.V[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa\x1E\xE1V[P``\x85\x01RP\x91\x94\x93PPPPV[_`\xE0\x826\x03\x12\x15a BW__\xFD[a Ja\x19\xDCV[a T6\x84a\x1D\x9AV[\x81R`\xC0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a nW__\xFD[a z6\x82\x86\x01a\x1EEV[` \x83\x01RP\x92\x91PPV[_a\x02\xA76\x83a\x1EEV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x02\xA7WcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x82\x01Q`\x80\x82\x01\x90`\x03\x81\x10a \xF6WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x83\x01R`@\x83\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x84\x01\x91\x90\x91R``\x93\x84\x01Q\x16\x92\x90\x91\x01\x91\x90\x91R\x90V\xFE\xA2dipfsX\"\x12 \x1E\xA4\xE2]\x96\x89[\xF1\x84\xB3'\x07lk\t\x03\xCC\x9Eg\xD7Rz%<\xF6O\x83\xEEf\x99\x87\0dsolcC\0\x08\x1E\x003",
    );
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
    /**Function with signature `encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))` and selector `0xa4aeca67`.
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
    ///Container type for the return parameters of the [`encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))`](encodeProposedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])))";
            const SELECTOR: [u8; 4] = [164u8, 174u8, 202u8, 103u8];
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
    /**Function with signature `encodeProveInput((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))` and selector `0x566bdcb9`.
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
    ///Container type for the return parameters of the [`encodeProveInput((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))`](encodeProveInputCall) function.
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
            const SIGNATURE: &'static str = "encodeProveInput((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))";
            const SELECTOR: [u8; 4] = [86u8, 107u8, 220u8, 185u8];
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
    /**Function with signature `encodeProvedEvent(((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32))))` and selector `0x39c54aa1`.
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
    ///Container type for the return parameters of the [`encodeProvedEvent(((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32))))`](encodeProvedEventCall) function.
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
            const SIGNATURE: &'static str = "encodeProvedEvent(((uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32))))";
            const SELECTOR: [u8; 4] = [57u8, 197u8, 74u8, 161u8];
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
    #[derive()]
    /**Function with signature `hashBondInstruction((uint48,uint8,address,address))` and selector `0x5a213615`.
```solidity
function hashBondInstruction(LibBonds.BondInstruction memory _bondInstruction) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashBondInstructionCall {
        #[allow(missing_docs)]
        pub _bondInstruction: <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashBondInstruction((uint48,uint8,address,address))`](hashBondInstructionCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashBondInstructionReturn {
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
            type UnderlyingSolTuple<'a> = (LibBonds::BondInstruction,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<hashBondInstructionCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashBondInstructionCall) -> Self {
                    (value._bondInstruction,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashBondInstructionCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _bondInstruction: tuple.0 }
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
            impl ::core::convert::From<hashBondInstructionReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashBondInstructionReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashBondInstructionReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashBondInstructionCall {
            type Parameters<'a> = (LibBonds::BondInstruction,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashBondInstruction((uint48,uint8,address,address))";
            const SELECTOR: [u8; 4] = [90u8, 33u8, 54u8, 21u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <LibBonds::BondInstruction as alloy_sol_types::SolType>::tokenize(
                        &self._bondInstruction,
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
                        let r: hashBondInstructionReturn = r.into();
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
                        let r: hashBondInstructionReturn = r.into();
                        r._0
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
    #[derive()]
    /**Function with signature `hashProveInput(bytes32,(uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))` and selector `0xb09f589a`.
```solidity
function hashProveInput(bytes32 _lastProposalHash, IInbox.ProveInput memory _input) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashProveInputCall {
        #[allow(missing_docs)]
        pub _lastProposalHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _input: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashProveInput(bytes32,(uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))`](hashProveInputCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashProveInputReturn {
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
                alloy::sol_types::sol_data::FixedBytes<32>,
                IInbox::ProveInput,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::FixedBytes<32>,
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
            impl ::core::convert::From<hashProveInputCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashProveInputCall) -> Self {
                    (value._lastProposalHash, value._input)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashProveInputCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _lastProposalHash: tuple.0,
                        _input: tuple.1,
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
            impl ::core::convert::From<hashProveInputReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashProveInputReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashProveInputReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashProveInputCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                IInbox::ProveInput,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashProveInput(bytes32,(uint48,bytes32,address,(address,address,uint48,bytes32)[],(uint48,bytes32,bytes32)))";
            const SELECTOR: [u8; 4] = [176u8, 159u8, 88u8, 154u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._lastProposalHash),
                    <IInbox::ProveInput as alloy_sol_types::SolType>::tokenize(
                        &self._input,
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
                        let r: hashProveInputReturn = r.into();
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
                        let r: hashProveInputReturn = r.into();
                        r._0
                    })
            }
        }
    };
    ///Container for all the [`Codec`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum CodecCalls {
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
        hashBondInstruction(hashBondInstructionCall),
        #[allow(missing_docs)]
        hashCheckpoint(hashCheckpointCall),
        #[allow(missing_docs)]
        hashDerivation(hashDerivationCall),
        #[allow(missing_docs)]
        hashProposal(hashProposalCall),
        #[allow(missing_docs)]
        hashProveInput(hashProveInputCall),
    }
    #[automatically_derived]
    impl CodecCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [38u8, 48u8, 57u8, 98u8],
            [47u8, 25u8, 105u8, 176u8],
            [57u8, 197u8, 74u8, 161u8],
            [86u8, 107u8, 220u8, 185u8],
            [90u8, 33u8, 54u8, 21u8],
            [93u8, 39u8, 204u8, 149u8],
            [121u8, 137u8, 170u8, 16u8],
            [161u8, 236u8, 147u8, 51u8],
            [164u8, 174u8, 202u8, 103u8],
            [175u8, 182u8, 58u8, 212u8],
            [176u8, 159u8, 88u8, 154u8],
            [184u8, 176u8, 46u8, 14u8],
            [237u8, 186u8, 205u8, 68u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecCalls {
        const NAME: &'static str = "CodecCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 13usize;
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
                Self::hashBondInstruction(_) => {
                    <hashBondInstructionCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashCheckpoint(_) => {
                    <hashCheckpointCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashDerivation(_) => {
                    <hashDerivationCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashProposal(_) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashProveInput(_) => {
                    <hashProveInputCall as alloy_sol_types::SolCall>::SELECTOR
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
            static DECODE_SHIMS: &[fn(&[u8]) -> alloy_sol_types::Result<CodecCalls>] = &[
                {
                    fn decodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::decodeProvedEvent)
                    }
                    decodeProvedEvent
                },
                {
                    fn encodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::encodeProposeInput)
                    }
                    encodeProposeInput
                },
                {
                    fn encodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::encodeProvedEvent)
                    }
                    encodeProvedEvent
                },
                {
                    fn encodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::encodeProveInput)
                    }
                    encodeProveInput
                },
                {
                    fn hashBondInstruction(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashBondInstructionCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashBondInstruction)
                    }
                    hashBondInstruction
                },
                {
                    fn decodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::decodeProposedEvent)
                    }
                    decodeProposedEvent
                },
                {
                    fn hashCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashCheckpoint)
                    }
                    hashCheckpoint
                },
                {
                    fn hashProposal(data: &[u8]) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashProposal)
                    }
                    hashProposal
                },
                {
                    fn encodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::encodeProposedEvent)
                    }
                    encodeProposedEvent
                },
                {
                    fn decodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::decodeProposeInput)
                    }
                    decodeProposeInput
                },
                {
                    fn hashProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashProveInput)
                    }
                    hashProveInput
                },
                {
                    fn hashDerivation(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashDerivationCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashDerivation)
                    }
                    hashDerivation
                },
                {
                    fn decodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::decodeProveInput)
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
            ) -> alloy_sol_types::Result<CodecCalls>] = &[
                {
                    fn decodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::decodeProvedEvent)
                    }
                    decodeProvedEvent
                },
                {
                    fn encodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::encodeProposeInput)
                    }
                    encodeProposeInput
                },
                {
                    fn encodeProvedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProvedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::encodeProvedEvent)
                    }
                    encodeProvedEvent
                },
                {
                    fn encodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::encodeProveInput)
                    }
                    encodeProveInput
                },
                {
                    fn hashBondInstruction(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashBondInstructionCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashBondInstruction)
                    }
                    hashBondInstruction
                },
                {
                    fn decodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::decodeProposedEvent)
                    }
                    decodeProposedEvent
                },
                {
                    fn hashCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashCheckpoint)
                    }
                    hashCheckpoint
                },
                {
                    fn hashProposal(data: &[u8]) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashProposal)
                    }
                    hashProposal
                },
                {
                    fn encodeProposedEvent(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <encodeProposedEventCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::encodeProposedEvent)
                    }
                    encodeProposedEvent
                },
                {
                    fn decodeProposeInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProposeInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::decodeProposeInput)
                    }
                    decodeProposeInput
                },
                {
                    fn hashProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashProveInput)
                    }
                    hashProveInput
                },
                {
                    fn hashDerivation(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashDerivationCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashDerivation)
                    }
                    hashDerivation
                },
                {
                    fn decodeProveInput(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <decodeProveInputCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::decodeProveInput)
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
                Self::hashBondInstruction(inner) => {
                    <hashBondInstructionCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashCheckpoint(inner) => {
                    <hashCheckpointCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::hashProveInput(inner) => {
                    <hashProveInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::hashBondInstruction(inner) => {
                    <hashBondInstructionCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::hashProveInput(inner) => {
                    <hashProveInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`Codec`](self) custom errors.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum CodecErrors {
        #[allow(missing_docs)]
        LengthExceedsUint16(LengthExceedsUint16),
    }
    #[automatically_derived]
    impl CodecErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[[44u8, 60u8, 244u8, 214u8]];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecErrors {
        const NAME: &'static str = "CodecErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 1usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::LengthExceedsUint16(_) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::SELECTOR
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
            static DECODE_SHIMS: &[fn(&[u8]) -> alloy_sol_types::Result<CodecErrors>] = &[
                {
                    fn LengthExceedsUint16(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecErrors> {
                        <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(CodecErrors::LengthExceedsUint16)
                    }
                    LengthExceedsUint16
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
            ) -> alloy_sol_types::Result<CodecErrors>] = &[
                {
                    fn LengthExceedsUint16(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecErrors> {
                        <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecErrors::LengthExceedsUint16)
                    }
                    LengthExceedsUint16
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
                Self::LengthExceedsUint16(inner) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::LengthExceedsUint16(inner) => {
                    <LengthExceedsUint16 as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`Codec`](self) contract instance.

See the [wrapper's documentation](`CodecInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(address: alloy_sol_types::private::Address, provider: P) -> CodecInstance<P, N> {
        CodecInstance::<P, N>::new(address, provider)
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
        Output = alloy_contract::Result<CodecInstance<P, N>>,
    > {
        CodecInstance::<P, N>::deploy(provider)
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
        CodecInstance::<P, N>::deploy_builder(provider)
    }
    /**A [`Codec`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`Codec`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct CodecInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for CodecInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("CodecInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > CodecInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`Codec`](self) contract instance.

See the [wrapper's documentation](`CodecInstance`) for more details.*/
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
        pub async fn deploy(provider: P) -> alloy_contract::Result<CodecInstance<P, N>> {
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
    impl<P: ::core::clone::Clone, N> CodecInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> CodecInstance<P, N> {
            CodecInstance {
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
    > CodecInstance<P, N> {
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
        ///Creates a new call builder for the [`hashBondInstruction`] function.
        pub fn hashBondInstruction(
            &self,
            _bondInstruction: <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashBondInstructionCall, N> {
            self.call_builder(
                &hashBondInstructionCall {
                    _bondInstruction,
                },
            )
        }
        ///Creates a new call builder for the [`hashCheckpoint`] function.
        pub fn hashCheckpoint(
            &self,
            _checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashCheckpointCall, N> {
            self.call_builder(&hashCheckpointCall { _checkpoint })
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
        ///Creates a new call builder for the [`hashProveInput`] function.
        pub fn hashProveInput(
            &self,
            _lastProposalHash: alloy::sol_types::private::FixedBytes<32>,
            _input: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashProveInputCall, N> {
            self.call_builder(
                &hashProveInputCall {
                    _lastProposalHash,
                    _input,
                },
            )
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > CodecInstance<P, N> {
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
