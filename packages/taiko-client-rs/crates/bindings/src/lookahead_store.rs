///Module containing a contract's types and functions.
/**

```solidity
library IBlacklist {
    struct BlacklistConfig { uint256 blacklistDelay; uint256 unblacklistDelay; }
    struct BlacklistTimestamps { uint48 blacklistedAt; uint48 unBlacklistedAt; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod IBlacklist {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BlacklistConfig { uint256 blacklistDelay; uint256 unblacklistDelay; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlacklistConfig {
        #[allow(missing_docs)]
        pub blacklistDelay: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub unblacklistDelay: alloy::sol_types::private::primitives::aliases::U256,
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
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::Uint<256>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U256,
            alloy::sol_types::private::primitives::aliases::U256,
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
        impl ::core::convert::From<BlacklistConfig> for UnderlyingRustTuple<'_> {
            fn from(value: BlacklistConfig) -> Self {
                (value.blacklistDelay, value.unblacklistDelay)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlacklistConfig {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blacklistDelay: tuple.0,
                    unblacklistDelay: tuple.1,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlacklistConfig {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlacklistConfig {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.blacklistDelay),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.unblacklistDelay),
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
        impl alloy_sol_types::SolType for BlacklistConfig {
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
        impl alloy_sol_types::SolStruct for BlacklistConfig {
            const NAME: &'static str = "BlacklistConfig";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlacklistConfig(uint256 blacklistDelay,uint256 unblacklistDelay)",
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
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.blacklistDelay,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.unblacklistDelay,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlacklistConfig {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blacklistDelay,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.unblacklistDelay,
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
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.blacklistDelay,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.unblacklistDelay,
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
struct BlacklistTimestamps { uint48 blacklistedAt; uint48 unBlacklistedAt; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlacklistTimestamps {
        #[allow(missing_docs)]
        pub blacklistedAt: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub unBlacklistedAt: alloy::sol_types::private::primitives::aliases::U48,
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
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
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
        impl ::core::convert::From<BlacklistTimestamps> for UnderlyingRustTuple<'_> {
            fn from(value: BlacklistTimestamps) -> Self {
                (value.blacklistedAt, value.unBlacklistedAt)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlacklistTimestamps {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blacklistedAt: tuple.0,
                    unBlacklistedAt: tuple.1,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlacklistTimestamps {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlacklistTimestamps {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.blacklistedAt),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.unBlacklistedAt),
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
        impl alloy_sol_types::SolType for BlacklistTimestamps {
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
        impl alloy_sol_types::SolStruct for BlacklistTimestamps {
            const NAME: &'static str = "BlacklistTimestamps";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlacklistTimestamps(uint48 blacklistedAt,uint48 unBlacklistedAt)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blacklistedAt)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.unBlacklistedAt,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlacklistTimestamps {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blacklistedAt,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.unBlacklistedAt,
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
                    &rust.blacklistedAt,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.unBlacklistedAt,
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
    /**Creates a new wrapper around an on-chain [`IBlacklist`](self) contract instance.

See the [wrapper's documentation](`IBlacklistInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> IBlacklistInstance<P, N> {
        IBlacklistInstance::<P, N>::new(address, provider)
    }
    /**A [`IBlacklist`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`IBlacklist`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct IBlacklistInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for IBlacklistInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("IBlacklistInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > IBlacklistInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`IBlacklist`](self) contract instance.

See the [wrapper's documentation](`IBlacklistInstance`) for more details.*/
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
    impl<P: ::core::clone::Clone, N> IBlacklistInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> IBlacklistInstance<P, N> {
            IBlacklistInstance {
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
    > IBlacklistInstance<P, N> {
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
    > IBlacklistInstance<P, N> {
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
library ILookaheadStore {
    struct LookaheadData { uint256 slotIndex; bytes32 registrationRoot; LookaheadSlot[] currLookahead; LookaheadSlot[] nextLookahead; bytes commitmentSignature; }
    struct LookaheadSlot { address committer; uint256 timestamp; bytes32 registrationRoot; uint256 validatorLeafIndex; }
    struct LookaheadStoreConfig { uint16 lookaheadBufferSize; uint80 minCollateralForPosting; uint80 minCollateralForPreconfing; }
    struct ProposerContext { bool isFallback; address proposer; uint256 submissionWindowStart; uint256 submissionWindowEnd; LookaheadSlot lookaheadSlot; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod ILookaheadStore {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct LookaheadData { uint256 slotIndex; bytes32 registrationRoot; LookaheadSlot[] currLookahead; LookaheadSlot[] nextLookahead; bytes commitmentSignature; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadData {
        #[allow(missing_docs)]
        pub slotIndex: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub registrationRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub currLookahead: alloy::sol_types::private::Vec<
            <LookaheadSlot as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub nextLookahead: alloy::sol_types::private::Vec<
            <LookaheadSlot as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub commitmentSignature: alloy::sol_types::private::Bytes,
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
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Array<LookaheadSlot>,
            alloy::sol_types::sol_data::Array<LookaheadSlot>,
            alloy::sol_types::sol_data::Bytes,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U256,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::Vec<
                <LookaheadSlot as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::Vec<
                <LookaheadSlot as alloy::sol_types::SolType>::RustType,
            >,
            alloy::sol_types::private::Bytes,
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
        impl ::core::convert::From<LookaheadData> for UnderlyingRustTuple<'_> {
            fn from(value: LookaheadData) -> Self {
                (
                    value.slotIndex,
                    value.registrationRoot,
                    value.currLookahead,
                    value.nextLookahead,
                    value.commitmentSignature,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for LookaheadData {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    slotIndex: tuple.0,
                    registrationRoot: tuple.1,
                    currLookahead: tuple.2,
                    nextLookahead: tuple.3,
                    commitmentSignature: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for LookaheadData {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for LookaheadData {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.slotIndex),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.registrationRoot),
                    <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::SolType>::tokenize(&self.currLookahead),
                    <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::SolType>::tokenize(&self.nextLookahead),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.commitmentSignature,
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
        impl alloy_sol_types::SolType for LookaheadData {
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
        impl alloy_sol_types::SolStruct for LookaheadData {
            const NAME: &'static str = "LookaheadData";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "LookaheadData(uint256 slotIndex,bytes32 registrationRoot,LookaheadSlot[] currLookahead,LookaheadSlot[] nextLookahead,bytes commitmentSignature)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(2);
                components
                    .push(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
                    .push(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.slotIndex)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.registrationRoot,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.currLookahead)
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.nextLookahead)
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.commitmentSignature,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for LookaheadData {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.slotIndex,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.registrationRoot,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.currLookahead,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        LookaheadSlot,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.nextLookahead,
                    )
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.commitmentSignature,
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
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.slotIndex,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.registrationRoot,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    LookaheadSlot,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.currLookahead,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    LookaheadSlot,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.nextLookahead,
                    out,
                );
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.commitmentSignature,
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
struct LookaheadSlot { address committer; uint256 timestamp; bytes32 registrationRoot; uint256 validatorLeafIndex; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadSlot {
        #[allow(missing_docs)]
        pub committer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub timestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub registrationRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub validatorLeafIndex: alloy::sol_types::private::primitives::aliases::U256,
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
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Uint<256>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Address,
            alloy::sol_types::private::primitives::aliases::U256,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::primitives::aliases::U256,
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
        impl ::core::convert::From<LookaheadSlot> for UnderlyingRustTuple<'_> {
            fn from(value: LookaheadSlot) -> Self {
                (
                    value.committer,
                    value.timestamp,
                    value.registrationRoot,
                    value.validatorLeafIndex,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for LookaheadSlot {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    committer: tuple.0,
                    timestamp: tuple.1,
                    registrationRoot: tuple.2,
                    validatorLeafIndex: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for LookaheadSlot {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for LookaheadSlot {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.committer,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.registrationRoot),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.validatorLeafIndex),
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
        impl alloy_sol_types::SolType for LookaheadSlot {
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
        impl alloy_sol_types::SolStruct for LookaheadSlot {
            const NAME: &'static str = "LookaheadSlot";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "LookaheadSlot(address committer,uint256 timestamp,bytes32 registrationRoot,uint256 validatorLeafIndex)",
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
                            &self.committer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.timestamp)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.registrationRoot,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.validatorLeafIndex,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for LookaheadSlot {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.committer,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.timestamp,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.registrationRoot,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.validatorLeafIndex,
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
                    &rust.committer,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.timestamp,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.registrationRoot,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.validatorLeafIndex,
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
struct LookaheadStoreConfig { uint16 lookaheadBufferSize; uint80 minCollateralForPosting; uint80 minCollateralForPreconfing; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadStoreConfig {
        #[allow(missing_docs)]
        pub lookaheadBufferSize: u16,
        #[allow(missing_docs)]
        pub minCollateralForPosting: alloy::sol_types::private::primitives::aliases::U80,
        #[allow(missing_docs)]
        pub minCollateralForPreconfing: alloy::sol_types::private::primitives::aliases::U80,
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
            alloy::sol_types::sol_data::Uint<80>,
            alloy::sol_types::sol_data::Uint<80>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            u16,
            alloy::sol_types::private::primitives::aliases::U80,
            alloy::sol_types::private::primitives::aliases::U80,
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
        impl ::core::convert::From<LookaheadStoreConfig> for UnderlyingRustTuple<'_> {
            fn from(value: LookaheadStoreConfig) -> Self {
                (
                    value.lookaheadBufferSize,
                    value.minCollateralForPosting,
                    value.minCollateralForPreconfing,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for LookaheadStoreConfig {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    lookaheadBufferSize: tuple.0,
                    minCollateralForPosting: tuple.1,
                    minCollateralForPreconfing: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for LookaheadStoreConfig {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for LookaheadStoreConfig {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self.lookaheadBufferSize),
                    <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.minCollateralForPosting,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.minCollateralForPreconfing,
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
        impl alloy_sol_types::SolType for LookaheadStoreConfig {
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
        impl alloy_sol_types::SolStruct for LookaheadStoreConfig {
            const NAME: &'static str = "LookaheadStoreConfig";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "LookaheadStoreConfig(uint16 lookaheadBufferSize,uint80 minCollateralForPosting,uint80 minCollateralForPreconfing)",
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
                            &self.lookaheadBufferSize,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.minCollateralForPosting,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.minCollateralForPreconfing,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for LookaheadStoreConfig {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lookaheadBufferSize,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.minCollateralForPosting,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        80,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.minCollateralForPreconfing,
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
                    &rust.lookaheadBufferSize,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    80,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.minCollateralForPosting,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    80,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.minCollateralForPreconfing,
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
struct ProposerContext { bool isFallback; address proposer; uint256 submissionWindowStart; uint256 submissionWindowEnd; LookaheadSlot lookaheadSlot; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposerContext {
        #[allow(missing_docs)]
        pub isFallback: bool,
        #[allow(missing_docs)]
        pub proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub submissionWindowStart: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub submissionWindowEnd: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub lookaheadSlot: <LookaheadSlot as alloy::sol_types::SolType>::RustType,
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
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::Uint<256>,
            LookaheadSlot,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            bool,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::primitives::aliases::U256,
            alloy::sol_types::private::primitives::aliases::U256,
            <LookaheadSlot as alloy::sol_types::SolType>::RustType,
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
        impl ::core::convert::From<ProposerContext> for UnderlyingRustTuple<'_> {
            fn from(value: ProposerContext) -> Self {
                (
                    value.isFallback,
                    value.proposer,
                    value.submissionWindowStart,
                    value.submissionWindowEnd,
                    value.lookaheadSlot,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposerContext {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    isFallback: tuple.0,
                    proposer: tuple.1,
                    submissionWindowStart: tuple.2,
                    submissionWindowEnd: tuple.3,
                    lookaheadSlot: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProposerContext {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProposerContext {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isFallback,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.proposer,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.submissionWindowStart,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.submissionWindowEnd),
                    <LookaheadSlot as alloy_sol_types::SolType>::tokenize(
                        &self.lookaheadSlot,
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
        impl alloy_sol_types::SolType for ProposerContext {
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
        impl alloy_sol_types::SolStruct for ProposerContext {
            const NAME: &'static str = "ProposerContext";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProposerContext(bool isFallback,address proposer,uint256 submissionWindowStart,uint256 submissionWindowEnd,LookaheadSlot lookaheadSlot)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <LookaheadSlot as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.isFallback,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proposer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.submissionWindowStart,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.submissionWindowEnd,
                        )
                        .0,
                    <LookaheadSlot as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lookaheadSlot,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProposerContext {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.isFallback,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposer,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.submissionWindowStart,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.submissionWindowEnd,
                    )
                    + <LookaheadSlot as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lookaheadSlot,
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
                    &rust.isFallback,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposer,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.submissionWindowStart,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.submissionWindowEnd,
                    out,
                );
                <LookaheadSlot as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lookaheadSlot,
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
    /**Creates a new wrapper around an on-chain [`ILookaheadStore`](self) contract instance.

See the [wrapper's documentation](`ILookaheadStoreInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> ILookaheadStoreInstance<P, N> {
        ILookaheadStoreInstance::<P, N>::new(address, provider)
    }
    /**A [`ILookaheadStore`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`ILookaheadStore`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct ILookaheadStoreInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for ILookaheadStoreInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("ILookaheadStoreInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ILookaheadStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ILookaheadStore`](self) contract instance.

See the [wrapper's documentation](`ILookaheadStoreInstance`) for more details.*/
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
    impl<P: ::core::clone::Clone, N> ILookaheadStoreInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> ILookaheadStoreInstance<P, N> {
            ILookaheadStoreInstance {
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
    > ILookaheadStoreInstance<P, N> {
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
    > ILookaheadStoreInstance<P, N> {
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
library IBlacklist {
    struct BlacklistConfig {
        uint256 blacklistDelay;
        uint256 unblacklistDelay;
    }
    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }
}

library ILookaheadStore {
    struct LookaheadData {
        uint256 slotIndex;
        bytes32 registrationRoot;
        LookaheadSlot[] currLookahead;
        LookaheadSlot[] nextLookahead;
        bytes commitmentSignature;
    }
    struct LookaheadSlot {
        address committer;
        uint256 timestamp;
        bytes32 registrationRoot;
        uint256 validatorLeafIndex;
    }
    struct LookaheadStoreConfig {
        uint16 lookaheadBufferSize;
        uint80 minCollateralForPosting;
        uint80 minCollateralForPreconfing;
    }
    struct ProposerContext {
        bool isFallback;
        address proposer;
        uint256 submissionWindowStart;
        uint256 submissionWindowEnd;
        LookaheadSlot lookaheadSlot;
    }
}

interface LookaheadStore {
    error ACCESS_DENIED();
    error BlacklistDelayNotMet();
    error CommitmentSignerMismatch();
    error CommitterMismatch();
    error FUNC_NOT_IMPLEMENTED();
    error INVALID_PAUSE_STATUS();
    error InvalidLookahead();
    error InvalidLookaheadEpoch();
    error InvalidLookaheadTimestamp();
    error InvalidProposer();
    error InvalidSlotIndex();
    error InvalidSlotTimestamp();
    error InvalidValidatorLeafIndex();
    error LookaheadNotRequired();
    error NotInbox();
    error NotOverseer();
    error OperatorAlreadyBlacklisted();
    error OperatorHasBeenBlacklisted();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error OperatorHasNotOptedIn();
    error OperatorHasNotRegistered();
    error OperatorHasUnregistered();
    error OperatorNotBlacklisted();
    error OverseerAlreadyExists();
    error OverseerDoesNotExist();
    error ProposerIsNotFallbackPreconfer();
    error ProposerIsNotPreconfer();
    error REENTRANT_CALL();
    error SlotTimestampIsNotIncrementing();
    error UnblacklistDelayNotMet();
    error ZERO_ADDRESS();
    error ZERO_VALUE();

    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);
    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Initialized(uint8 version);
    event LookaheadPosted(uint256 indexed epochTimestamp, bytes32 lookaheadHash, ILookaheadStore.LookaheadSlot[] lookaheadSlots);
    event OverseersAdded(address[] overseers);
    event OverseersRemoved(address[] overseers);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    constructor(address _urc, address _lookaheadSlasher, address _preconfSlasher, address _inbox, address _preconfWhitelist, address[] _overseers);

    function acceptOwnership() external;
    function addOverseers(address[] memory _overseers) external;
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external;
    function calculateLookaheadHash(uint256 _epochTimestamp, ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots) external pure returns (bytes26);
    function checkProposer(address _proposer, bytes memory _lookaheadData) external returns (uint48);
    function getBlacklist(bytes32 operatorRegistrationRoot) external view returns (IBlacklist.BlacklistTimestamps memory);
    function getBlacklistConfig() external pure returns (IBlacklist.BlacklistConfig memory);
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26 hash_);
    function getLookaheadStoreConfig() external pure returns (ILookaheadStore.LookaheadStoreConfig memory);
    function getProposerContext(ILookaheadStore.LookaheadData memory _data, uint256 _epochTimestamp) external view returns (ILookaheadStore.ProposerContext memory context_);
    function impl() external view returns (address);
    function inNonReentrant() external view returns (bool);
    function inbox() external view returns (address);
    function init(address _owner) external;
    function isLookaheadOperatorValid(uint256 _epochTimestamp, bytes32 _registrationRoot) external view returns (bool);
    function isLookaheadPosterValid(uint256 _epochTimestamp, bytes32 _registrationRoot) external view returns (bool);
    function isLookaheadRequired() external view returns (bool);
    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool);
    function lookahead(uint256 epochTimestamp_mod_lookaheadBufferSize) external view returns (uint48 epochTimestamp, bytes26 lookaheadHash);
    function lookaheadSlasher() external view returns (address);
    function overseers(address overseer) external view returns (bool isOverseer);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function preconfSlasher() external view returns (address);
    function preconfWhitelist() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function removeOverseers(address[] memory _overseers) external;
    function renounceOwnership() external;
    function resolver() external view returns (address);
    function transferOwnership(address newOwner) external;
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external;
    function unpause() external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function urc() external view returns (address);
}
```

...which was generated by the following JSON ABI:
```json
[
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_urc",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_lookaheadSlasher",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_preconfSlasher",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_inbox",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_preconfWhitelist",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_overseers",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "acceptOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addOverseers",
    "inputs": [
      {
        "name": "_overseers",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "blacklistOperator",
    "inputs": [
      {
        "name": "_operatorRegistrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "calculateLookaheadHash",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_lookaheadSlots",
        "type": "tuple[]",
        "internalType": "struct ILookaheadStore.LookaheadSlot[]",
        "components": [
          {
            "name": "committer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "timestamp",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "registrationRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "validatorLeafIndex",
            "type": "uint256",
            "internalType": "uint256"
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
    "name": "checkProposer",
    "inputs": [
      {
        "name": "_proposer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_lookaheadData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getBlacklist",
    "inputs": [
      {
        "name": "operatorRegistrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IBlacklist.BlacklistTimestamps",
        "components": [
          {
            "name": "blacklistedAt",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "unBlacklistedAt",
            "type": "uint48",
            "internalType": "uint48"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBlacklistConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IBlacklist.BlacklistConfig",
        "components": [
          {
            "name": "blacklistDelay",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "unblacklistDelay",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getLookaheadHash",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "hash_",
        "type": "bytes26",
        "internalType": "bytes26"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getLookaheadStoreConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ILookaheadStore.LookaheadStoreConfig",
        "components": [
          {
            "name": "lookaheadBufferSize",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "minCollateralForPosting",
            "type": "uint80",
            "internalType": "uint80"
          },
          {
            "name": "minCollateralForPreconfing",
            "type": "uint80",
            "internalType": "uint80"
          }
        ]
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getProposerContext",
    "inputs": [
      {
        "name": "_data",
        "type": "tuple",
        "internalType": "struct ILookaheadStore.LookaheadData",
        "components": [
          {
            "name": "slotIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "registrationRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "currLookahead",
            "type": "tuple[]",
            "internalType": "struct ILookaheadStore.LookaheadSlot[]",
            "components": [
              {
                "name": "committer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "registrationRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "validatorLeafIndex",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "nextLookahead",
            "type": "tuple[]",
            "internalType": "struct ILookaheadStore.LookaheadSlot[]",
            "components": [
              {
                "name": "committer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "registrationRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "validatorLeafIndex",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "commitmentSignature",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      },
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "context_",
        "type": "tuple",
        "internalType": "struct ILookaheadStore.ProposerContext",
        "components": [
          {
            "name": "isFallback",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "proposer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "submissionWindowStart",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "submissionWindowEnd",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "lookaheadSlot",
            "type": "tuple",
            "internalType": "struct ILookaheadStore.LookaheadSlot",
            "components": [
              {
                "name": "committer",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "timestamp",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "registrationRoot",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "validatorLeafIndex",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "impl",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "inNonReentrant",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "inbox",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "init",
    "inputs": [
      {
        "name": "_owner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isLookaheadOperatorValid",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_registrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isLookaheadPosterValid",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_registrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isLookaheadRequired",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isOperatorBlacklisted",
    "inputs": [
      {
        "name": "operatorRegistrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lookahead",
    "inputs": [
      {
        "name": "epochTimestamp_mod_lookaheadBufferSize",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "epochTimestamp",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "lookaheadHash",
        "type": "bytes26",
        "internalType": "bytes26"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lookaheadSlasher",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "overseers",
    "inputs": [
      {
        "name": "overseer",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "isOverseer",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pendingOwner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "preconfSlasher",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "preconfWhitelist",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "proxiableUUID",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "removeOverseers",
    "inputs": [
      {
        "name": "_overseers",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "resolver",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "unblacklistOperator",
    "inputs": [
      {
        "name": "_operatorRegistrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "upgradeTo",
    "inputs": [
      {
        "name": "newImplementation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "upgradeToAndCall",
    "inputs": [
      {
        "name": "newImplementation",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "urc",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IRegistry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "AdminChanged",
    "inputs": [
      {
        "name": "previousAdmin",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "newAdmin",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BeaconUpgraded",
    "inputs": [
      {
        "name": "beacon",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Blacklisted",
    "inputs": [
      {
        "name": "operatorRegistrationRoot",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "timestamp",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "LookaheadPosted",
    "inputs": [
      {
        "name": "epochTimestamp",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "lookaheadHash",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "lookaheadSlots",
        "type": "tuple[]",
        "indexed": false,
        "internalType": "struct ILookaheadStore.LookaheadSlot[]",
        "components": [
          {
            "name": "committer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "timestamp",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "registrationRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "validatorLeafIndex",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OverseersAdded",
    "inputs": [
      {
        "name": "overseers",
        "type": "address[]",
        "indexed": false,
        "internalType": "address[]"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OverseersRemoved",
    "inputs": [
      {
        "name": "overseers",
        "type": "address[]",
        "indexed": false,
        "internalType": "address[]"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferStarted",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Unblacklisted",
    "inputs": [
      {
        "name": "operatorRegistrationRoot",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "timestamp",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Upgraded",
    "inputs": [
      {
        "name": "implementation",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ACCESS_DENIED",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BlacklistDelayNotMet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CommitmentSignerMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CommitterMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FUNC_NOT_IMPLEMENTED",
    "inputs": []
  },
  {
    "type": "error",
    "name": "INVALID_PAUSE_STATUS",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidLookahead",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidLookaheadEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidLookaheadTimestamp",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidProposer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSlotIndex",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSlotTimestamp",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidValidatorLeafIndex",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LookaheadNotRequired",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInbox",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotOverseer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorAlreadyBlacklisted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasBeenBlacklisted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasBeenSlashed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasInsufficientCollateral",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasNotOptedIn",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasNotRegistered",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorHasUnregistered",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OperatorNotBlacklisted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OverseerAlreadyExists",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OverseerDoesNotExist",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ProposerIsNotFallbackPreconfer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ProposerIsNotPreconfer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "REENTRANT_CALL",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SlotTimestampIsNotIncrementing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnblacklistDelayNotMet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZERO_ADDRESS",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZERO_VALUE",
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
pub mod LookaheadStore {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x61016060405230608052348015610014575f5ffd5b50604051613973380380613973833981016040819052610033916101b3565b805f5b815181101561008e5760015f5f848481518110610055576100556102d0565b6020908102919091018101516001600160a01b031682528101919091526040015f20805460ff1916911515919091179055600101610036565b5061009990506100c5565b506001600160a01b0394851660c05292841660e0529083166101005282166101205216610140526102e4565b603254610100900460ff16156101315760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b60325460ff90811614610182576032805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b80516001600160a01b038116811461019a575f5ffd5b919050565b634e487b7160e01b5f52604160045260245ffd5b5f5f5f5f5f5f60c087890312156101c8575f5ffd5b6101d187610184565b95506101df60208801610184565b94506101ed60408801610184565b93506101fb60608801610184565b925061020960808801610184565b60a08801519092506001600160401b03811115610224575f5ffd5b8701601f81018913610234575f5ffd5b80516001600160401b0381111561024d5761024d61019f565b604051600582901b90603f8201601f191681016001600160401b038111828210171561027b5761027b61019f565b60405291825260208184018101929081018c841115610298575f5ffd5b6020850194505b838510156102be576102b085610184565b81526020948501940161029f565b50809450505050509295509295509295565b634e487b7160e01b5f52603260045260245ffd5b60805160a05160c05160e0516101005161012051610140516135dc6103975f395f81816107080152818161166b015261176601525f81816107f7015261101e01525f8181610758015281816113c7015261256801525f81816103d70152818161143801526126eb01525f818161042a01528181611cf501528181611e500152611f0a01525f61022401525f8181610bc301528181610c0301528181610ce501528181610d250152610d9c01526135dc5ff3fe608060405260043610610212575f3560e01c80638da5cb5b1161011e578063d3cbd83e116100a8578063f1c27dad1161006d578063f1c27dad14610799578063f2fde38b146107c7578063fb0e722b146107e6578063fd40a5fe14610819578063fd527be81461086e575f5ffd5b8063d3cbd83e146106d8578063d91f24f1146106f7578063e30c39781461072a578063e45f2fc314610747578063e4689d641461077a575f5ffd5b8063a486e0dd116100ee578063a486e0dd146105df578063ac0004da14610645578063ae41501a1461067b578063b44b2d521461069a578063cc809990146106b9575f5ffd5b80638da5cb5b146104d3578063937aaa9b146104f05780639fe786ab14610536578063a2651bb7146105c0575f5ffd5b806352d1902d1161019f578063715018a61161016f578063715018a61461044c57806372f84a1d1461046057806379ba5097146104975780638456cb59146104ab5780638abf6077146104bf575f5ffd5b806352d1902d146103a45780635bf4ea85146103c65780635c975abb146103f95780635ddc9e8d14610419575f5ffd5b80633075db56116101e55780633075db56146102c5578063312bcde3146102d95780633659cfe61461035e5780633f4ba83a1461037d5780634f1ef28614610391575f5ffd5b806304f3bcec1461021657806306418f051461026157806319ab453c1461028257806323c0b1ab146102a1575b5f5ffd5b348015610221575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b34801561026c575f5ffd5b5061028061027b366004612bcf565b6108b9565b005b34801561028d575f5ffd5b5061028061029c366004612bfa565b6109fc565b3480156102ac575f5ffd5b506102b5610b15565b6040519015158152602001610258565b3480156102d0575f5ffd5b506102b5610b6d565b3480156102e4575f5ffd5b506102f86102f3366004612e9e565b610b85565b604080518251151581526020808401516001600160a01b03908116828401528484015183850152606080860151818501526080958601518051909216958401959095529081015160a08301529182015160c082015291015160e082015261010001610258565b348015610369575f5ffd5b50610280610378366004612bfa565b610bb9565b348015610388575f5ffd5b50610280610c80565b61028061039f366004612edf565b610cdb565b3480156103af575f5ffd5b506103b8610d90565b604051908152602001610258565b3480156103d1575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610404575f5ffd5b506102b560fb54610100900460ff1660021490565b348015610424575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610457575f5ffd5b50610280610e41565b34801561046b575f5ffd5b5061047f61047a366004612f2b565b610e52565b60405165ffffffffffff199091168152602001610258565b3480156104a2575f5ffd5b50610280610e66565b3480156104b6575f5ffd5b50610280610edd565b3480156104ca575f5ffd5b50610244610f32565b3480156104de575f5ffd5b506065546001600160a01b0316610244565b3480156104fb575f5ffd5b506040805180820182525f80825260209182015281518083018352620151808082529082018181528351918252519181019190915201610258565b348015610541575f5ffd5b5061059a610550366004612bcf565b604080518082019091525f8082526020820152505f9081526001602090815260409182902082518084019093525465ffffffffffff8082168452600160301b909104169082015290565b60408051825165ffffffffffff9081168252602093840151169281019290925201610258565b3480156105cb575f5ffd5b506102806105da366004612f64565b610f40565b3480156105ea575f5ffd5b5061061f6105f9366004612bcf565b61012d6020525f908152604090205465ffffffffffff811690600160301b900460301b82565b6040805165ffffffffffff909316835265ffffffffffff19909116602083015201610258565b348015610650575f5ffd5b5061066461065f366004612fd3565b611012565b60405165ffffffffffff9091168152602001610258565b348015610686575f5ffd5b5061047f610695366004612bcf565b611142565b3480156106a5575f5ffd5b506102806106b4366004612f64565b611196565b3480156106c4575f5ffd5b506102806106d3366004612bcf565b611263565b3480156106e3575f5ffd5b506102b56106f2366004613051565b6113a9565b348015610702575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610735575f5ffd5b506097546001600160a01b0316610244565b348015610752575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610785575f5ffd5b506102b5610794366004613051565b6113f7565b3480156107a4575f5ffd5b506102b56107b3366004612bfa565b5f6020819052908152604090205460ff1681565b3480156107d2575f5ffd5b506102806107e1366004612bfa565b61145c565b3480156107f1575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610824575f5ffd5b506102b5610833366004612bcf565b5f9081526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b348015610879575f5ffd5b506108826114cd565b60408051825161ffff1681526020808401516001600160501b03908116918301919091529282015190921690820152606001610258565b335f9081526020819052604090205460ff166108e85760405163ac9d87cd60e01b815260040160405180910390fd5b5f8181526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416918301829052111561093d57604051631996476b60e01b815260040160405180910390fd5b6040805180820182525f8082526020918201528151808301909252620151808083529082015251602082015161097b919065ffffffffffff16613085565b421161099a5760405163a282931f60e01b815260040160405180910390fd5b5f82815260016020908152604091829020805465ffffffffffff19164265ffffffffffff16908117909155915191825283917f1a878b2bf8680c02f7d79c199a61adbe8744e8ccb0f17e36229b619331fa2e1391015b60405180910390a25050565b603254610100900460ff1615808015610a1c5750603254600160ff909116105b80610a365750303b158015610a36575060325460ff166001145b610a9e5760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b60648201526084015b60405180910390fd5b6032805460ff191660011790558015610ac1576032805461ff0019166101001790555b610aca8261150a565b8015610b11576032805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498906020015b60405180910390a15b5050565b5f5f610b205f611569565b65ffffffffffff169050804203610b38575f91505090565b5f610b45600c6020613098565b610b4f9083613085565b905080610b5b826115ed565b5465ffffffffffff1614159392505050565b5f6002610b7c60fb5460ff1690565b60ff1614905090565b610b8d612b6c565b5f610b9a600c6020613098565b610ba49084613085565b9050610bb184848361161d565b949350505050565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610c015760405162461bcd60e51b8152600401610a95906130af565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610c336117ca565b6001600160a01b031614610c595760405162461bcd60e51b8152600401610a95906130fb565b610c62816117e5565b604080515f80825260208201909252610c7d918391906117ed565b50565b610c8861195c565b610c9c60fb805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610cd9335f61198d565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610d235760405162461bcd60e51b8152600401610a95906130af565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610d556117ca565b6001600160a01b031614610d7b5760405162461bcd60e51b8152600401610a95906130fb565b610d84826117e5565b610b11828260016117ed565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610e2f5760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a95565b505f5160206135605f395f51905f5290565b610e49611991565b610cd95f6119eb565b5f610e5d8383611a04565b90505b92915050565b60975433906001600160a01b03168114610ed45760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a95565b610c7d816119eb565b610ee5611a36565b60fb805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610cd933600161198d565b5f610f3b6117ca565b905090565b610f48611991565b5f5b81811015610fe0575f838383818110610f6557610f65613147565b9050602002016020810190610f7a9190612bfa565b6001600160a01b0381165f9081526020819052604090205490915060ff1615610fb657604051634461492f60e01b815260040160405180910390fd5b6001600160a01b03165f908152602081905260409020805460ff1916600190811790915501610f4a565b507fdae2150d49d9cb1220fb4c279436b69ecffa40b1b64025e396b6be5d830b81348282604051610b0892919061315b565b5f336001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461105c576040516372109f7760e01b815260040160405180910390fd5b5f6110698385018561319d565b905061107481611a68565b5f61107d611a9a565b65ffffffffffff1690505f611094600c6020613098565b61109e9083613085565b90505f6110ac84848461161d565b905080602001516001600160a01b0316886001600160a01b0316146110e45760405163409b320f60e11b815260040160405180910390fd5b8060400151421180156110fb575080606001514211155b611118576040516345cb0af960e01b815260040160405180910390fd5b611126838560400151611aa4565b611131828286611aea565b6060015193505050505b9392505050565b5f5f61114d836115ed565b60408051808201909152905465ffffffffffff8116808352600160301b90910460301b65ffffffffffff1916602083015290915083900361119057806020015191505b50919050565b61119e611991565b5f5b81811015611231575f8383838181106111bb576111bb613147565b90506020020160208101906111d09190612bfa565b6001600160a01b0381165f9081526020819052604090205490915060ff1661120b576040516341d0c73760e01b815260040160405180910390fd5b6001600160a01b03165f908152602081905260409020805460ff191690556001016111a0565b507faec1dfa3221b7c426e6164e08ca6811a59e70d4fc97d7e4efecc7f2f8ac4ba708282604051610b0892919061315b565b335f9081526020819052604090205460ff166112925760405163ac9d87cd60e01b815260040160405180910390fd5b5f8181526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416918301829052116112e657604051630ec1127960e01b815260040160405180910390fd5b6040805180820182525f80825260209182015281518083019092526201518080835291018190528151611321919065ffffffffffff16613085565b4211611340576040516399d3faf960e01b815260040160405180910390fd5b5f8281526001602090815260409182902080546bffffffffffff0000000000001916600160301b4265ffffffffffff1690810291909117909155915191825283917f9682ae3fb79c10948116fe2a224cca9025fb76716477d713dfec766d8bccee1791016109f0565b5f826113eb81846113b86114cd565b604001516001600160501b03167f0000000000000000000000000000000000000000000000000000000000000000611b39565b50600195945050505050565b5f80611405600c6020613098565b611410906002613098565b61141a90856131ce565b90506113eb81846114296114cd565b602001516001600160501b03167f0000000000000000000000000000000000000000000000000000000000000000611c7c565b611464611991565b609780546001600160a01b0383166001600160a01b031990911681179091556114956065546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b60408051606080820183525f808352602080840182905292840152825190810183526101f78152670de0b6b3a76400009181018290529182015290565b603254610100900460ff166115315760405162461bcd60e51b8152600401610a95906131e1565b611539612004565b6115576001600160a01b0382161561155157816119eb565b336119eb565b5060fb805461ff001916610100179055565b5f5f6115744661202b565b90505f61158182426131ce565b90505f611590600c6020613098565b61159c600c6020613098565b6115a69084613240565b6115b09190613098565b90506115e46115c1600c6020613098565b6115cb9087613098565b6115d58386613085565b6115df9190613085565b612086565b95945050505050565b5f61012d5f6115fa6114cd565b516116099061ffff1685613253565b81526020019081526020015f209050919050565b611625612b6c565b8360400151515f036116425761163b83836120f0565b9050611662565b83516001016116555761163b8483612119565b61165f84846121d9565b90505b8051156116fc577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663343f0a686040518163ffffffff1660e01b8152600401602060405180830381865afa1580156116c5573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906116e99190613266565b6001600160a01b0316602082015261113b565b6117438160800151604001515f9081526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b156117af576001815260408051630687e14d60e31b815290516001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169163343f0a689160048083019260209291908290030181865afa1580156116c5573d5f5f3e3d5ffd5b6080810151516001600160a01b031660208201529392505050565b5f5160206135605f395f51905f52546001600160a01b031690565b610c7d611991565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff16156118255761182083612270565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa92505050801561187f575060408051601f3d908101601f1916820190925261187c91810190613281565b60015b6118e25760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a95565b5f5160206135605f395f51905f5281146119505760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a95565b5061182083838361230b565b61197060fb54610100900460ff1660021490565b610cd95760405163bae6e2a960e01b815260040160405180910390fd5b610b115b6065546001600160a01b03163314610cd95760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a95565b609780546001600160a01b0319169055610c7d8161232f565b5f8282604051602001611a18929190613304565b60405160208183030381529060405280519060200120905092915050565b611a4a60fb54610100900460ff1660021490565b15610cd95760405163bae6e2a960e01b815260040160405180910390fd5b80515f191480611a7d57506040810151518151105b610c7d57604051633628a81b60e01b815260040160405180910390fd5b5f610f3b5f611569565b5f611aae83611142565b905065ffffffffffff19811615611aca57611820838383612380565b8151156118205760405163eaf82a2560e01b815260040160405180910390fd5b5f611af484611142565b905065ffffffffffff19811615611b285781515f1914611b145750505050565b611b2384836060015183612380565b611b33565b611b338484846123b9565b50505050565b60408051610100810182525f80825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e0810191909152604080516080810182525f8082526020820181905291810182905260608101919091525f611ba9600c6020613098565b611bb4906002613098565b611bbe90886131ce565b9050611bcc81878787611c7c565b5f88815260016020908152604080832081518083019092525465ffffffffffff808216808452600160301b9092041692820192909252939650919450901580611c1d5750815165ffffffffffff1683105b90505f826020015165ffffffffffff165f14158015611c47575083836020015165ffffffffffff16105b90508180611c525750805b611c6f57604051636a6081d160e11b815260040160405180910390fd5b5050505094509492505050565b60408051610100810182525f80825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e0810191909152604080516080810182525f8082526020820181905291810182905260608101919091526040516324d9127b60e21b8152600481018690527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03169063936449ec9060240161010060405180830381865afa158015611d43573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611d67919061336c565b9150816060015165ffffffffffff165f14158015611d90575085826060015165ffffffffffff16105b611dad576040516369fe1ffb60e11b815260040160405180910390fd5b608082015165ffffffffffff9081161480611dd3575085826080015165ffffffffffff16115b611df05760405163a552ab4960e01b815260040160405180910390fd5b60a082015165ffffffffffff161580611e145750858260a0015165ffffffffffff16115b611e3157604051634c94192f60e01b815260040160405180910390fd5b60405163090e1eed60e21b815260048101869052602481018790525f907f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316906324387bb490604401602060405180830381865afa158015611e9d573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611ec19190613281565b905084811015611ee45760405163c41f0d0f60e01b815260040160405180910390fd5b604051632d0c58c960e11b8152600481018790526001600160a01b0385811660248301527f00000000000000000000000000000000000000000000000000000000000000001690635a18b19290604401608060405180830381865afa158015611f4f573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611f739190613412565b9150816020015165ffffffffffff165f14158015611f9c575086826020015165ffffffffffff16105b611fb957604051636fe7bcdb60e11b815260040160405180910390fd5b604082015165ffffffffffff161580611fdd575086826040015165ffffffffffff16115b611ffa57604051636fe7bcdb60e11b815260040160405180910390fd5b5094509492505050565b603254610100900460ff16610cd95760405162461bcd60e51b8152600401610a95906131e1565b5f6001820361203f5750635fc63057919050565b614268820361205357506365156ac0919050565b6401a2140cff820361206a57506366755d6c919050565b62088bb0820361207f57506367d81118919050565b505f919050565b5f65ffffffffffff8211156120ec5760405162461bcd60e51b815260206004820152602660248201527f53616665436173743a2076616c756520646f65736e27742066697420696e203460448201526538206269747360d01b6064820152608401610a95565b5090565b6120f8612b6c565b600181526040810183905261210e600c836131ce565b606082015292915050565b612121612b6c565b60408301518051612134906001906131ce565b8151811061214457612144613147565b6020026020010151602001518160400181815250508260600151515f0361217e5760018152612174600c836131ce565b6060820152610e60565b5f8082526060840151805190919061219857612198613147565b60200260200101516020015181606001818152505082606001515f815181106121c3576121c3613147565b6020026020010151816080018190525092915050565b6121e1612b6c565b5f815260408301518351815181106121fb576121fb613147565b602090810291909101810151608083018190520151606082015282515f0361223257612228600c836131ce565b6040820152610e60565b60408301518351612245906001906131ce565b8151811061225557612255613147565b60200260200101516020015181604001818152505092915050565b6001600160a01b0381163b6122dd5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a95565b5f5160206135605f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b6123148361242b565b5f825111806123205750805b1561182057611b33838361246a565b606580546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f61238b8484611a04565b905065ffffffffffff1982811690821614611b335760405163eaf82a2560e01b815260040160405180910390fd5b8060800151515f036123f25781516123e45760405163047677f560e21b815260040160405180910390fd5b611b3383826060015161248f565b5f6124008260600151612676565b905061241684836020015183856080015161271d565b61242484836060015161248f565b5050505050565b61243481612270565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060610e5d8383604051806060016040528060278152602001613580602791396127c3565b5f612498610b15565b6124b557604051630d45c1ad60e21b815260040160405180910390fd5b600b1983015f6124c36114cd565b604001516001600160501b031690505f5b84518110156125f9575f8582815181106124f0576124f0613147565b602002602001015190508381602001511161251e57604051635c03141b60e11b815260040160405180910390fd5b600c87826020015103816125345761253461322c565b06156125535760405163971cce8f60e01b815260040160405180910390fd5b806020015193505f5f61258c898460400151877f0000000000000000000000000000000000000000000000000000000000000000611b39565b91509150816040015161ffff168360600151106125bc57604051636016a6f360e01b815260040160405180910390fd5b805183516001600160a01b039081169116146125eb57604051630a519d8d60e31b815260040160405180910390fd5b5050508060010190506124d4565b506101808501821061261e576040516396ace79b60e01b815260040160405180910390fd5b505061262a8383611a04565b90506126368382612837565b827fae9b6437ad267553afbf07550405458fc43f11f8c50037a3f6b4d7937064cc0a8284604051612668929190613473565b60405180910390a292915050565b6126aa60405180606001604052805f6001600160401b03168152602001606081526020015f6001600160a01b031681525090565b60405180606001604052805f6001600160401b03168152602001836040516020016126d59190613494565b60405160208183030381529060405281526020017f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03168152509050919050565b5f61272a600c6020613098565b612735906002613098565b61273f90866131ce565b90505f61274f82866114296114cd565b9150505f6127838560405160200161276791906134d4565b6040516020818303038152906040528051906020012085612860565b9050815f01516001600160a01b0316816001600160a01b0316146127ba5760405163157df6a560e21b815260040160405180910390fd5b50505050505050565b60605f5f856001600160a01b0316856040516127df9190613523565b5f60405180830381855af49150503d805f8114612817576040519150601f19603f3d011682016040523d82523d5f602084013e61281c565b606091505b509150915061282d86838387612882565b9695505050505050565b5f612841836115ed565b60309290921c600160301b0265ffffffffffff90931692909217905550565b5f5f5f61286d85856128fa565b9150915061287a8161293c565b509392505050565b606083156128f05782515f036128e9576001600160a01b0385163b6128e95760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a95565b5081610bb1565b610bb18383612a85565b5f5f825160410361292e576020830151604084015160608501515f1a61292287828585612aaf565b94509450505050612935565b505f905060025b9250929050565b5f81600481111561294f5761294f613539565b036129575750565b600181600481111561296b5761296b613539565b036129b85760405162461bcd60e51b815260206004820152601860248201527f45434453413a20696e76616c6964207369676e617475726500000000000000006044820152606401610a95565b60028160048111156129cc576129cc613539565b03612a195760405162461bcd60e51b815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e677468006044820152606401610a95565b6003816004811115612a2d57612a2d613539565b03610c7d5760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c604482015261756560f01b6064820152608401610a95565b815115612a955781518083602001fd5b8060405162461bcd60e51b8152600401610a95919061354d565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115612ae457505f90506003612b63565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612b35573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612b5d575f60019250925050612b63565b91505f90505b94509492505050565b6040518060a001604052805f151581526020015f6001600160a01b031681526020015f81526020015f8152602001612bca60405180608001604052805f6001600160a01b031681526020015f81526020015f81526020015f81525090565b905290565b5f60208284031215612bdf575f5ffd5b5035919050565b6001600160a01b0381168114610c7d575f5ffd5b5f60208284031215612c0a575f5ffd5b813561113b81612be6565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b0381118282101715612c4b57612c4b612c15565b60405290565b60405160a081016001600160401b0381118282101715612c4b57612c4b612c15565b60405161010081016001600160401b0381118282101715612c4b57612c4b612c15565b604051601f8201601f191681016001600160401b0381118282101715612cbe57612cbe612c15565b604052919050565b5f82601f830112612cd5575f5ffd5b81356001600160401b03811115612cee57612cee612c15565b612cfd60208260051b01612c96565b8082825260208201915060208360071b860101925085831115612d1e575f5ffd5b602085015b83811015612d7d5760808188031215612d3a575f5ffd5b612d42612c29565b8135612d4d81612be6565b81526020828101358183015260408084013590830152606080840135908301529084529290920191608001612d23565b5095945050505050565b5f82601f830112612d96575f5ffd5b81356001600160401b03811115612daf57612daf612c15565b612dc2601f8201601f1916602001612c96565b818152846020838601011115612dd6575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f60a08284031215612e02575f5ffd5b612e0a612c51565b8235815260208084013590820152905060408201356001600160401b03811115612e32575f5ffd5b612e3e84828501612cc6565b60408301525060608201356001600160401b03811115612e5c575f5ffd5b612e6884828501612cc6565b60608301525060808201356001600160401b03811115612e86575f5ffd5b612e9284828501612d87565b60808301525092915050565b5f5f60408385031215612eaf575f5ffd5b82356001600160401b03811115612ec4575f5ffd5b612ed085828601612df2565b95602094909401359450505050565b5f5f60408385031215612ef0575f5ffd5b8235612efb81612be6565b915060208301356001600160401b03811115612f15575f5ffd5b612f2185828601612d87565b9150509250929050565b5f5f60408385031215612f3c575f5ffd5b8235915060208301356001600160401b03811115612f58575f5ffd5b612f2185828601612cc6565b5f5f60208385031215612f75575f5ffd5b82356001600160401b03811115612f8a575f5ffd5b8301601f81018513612f9a575f5ffd5b80356001600160401b03811115612faf575f5ffd5b8560208260051b8401011115612fc3575f5ffd5b6020919091019590945092505050565b5f5f5f60408486031215612fe5575f5ffd5b8335612ff081612be6565b925060208401356001600160401b0381111561300a575f5ffd5b8401601f8101861361301a575f5ffd5b80356001600160401b0381111561302f575f5ffd5b866020828401011115613040575f5ffd5b939660209190910195509293505050565b5f5f60408385031215613062575f5ffd5b50508035926020909101359150565b634e487b7160e01b5f52601160045260245ffd5b80820180821115610e6057610e60613071565b8082028115828204841417610e6057610e60613071565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b634e487b7160e01b5f52603260045260245ffd5b602080825281018290525f8360408301825b85811015612d7d57823561318081612be6565b6001600160a01b031682526020928301929091019060010161316d565b5f602082840312156131ad575f5ffd5b81356001600160401b038111156131c2575f5ffd5b610bb184828501612df2565b81810381811115610e6057610e60613071565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b634e487b7160e01b5f52601260045260245ffd5b5f8261324e5761324e61322c565b500490565b5f826132615761326161322c565b500690565b5f60208284031215613276575f5ffd5b815161113b81612be6565b5f60208284031215613291575f5ffd5b5051919050565b5f8151808452602084019350602083015f5b828110156132fa576132e486835180516001600160a01b031682526020808201519083015260408082015190830152606090810151910152565b60809590950194602091909101906001016132aa565b5093949350505050565b828152604060208201525f610bb16040830184613298565b80516001600160501b0381168114613332575f5ffd5b919050565b805161ffff81168114613332575f5ffd5b805165ffffffffffff81168114613332575f5ffd5b80518015158114613332575f5ffd5b5f61010082840312801561337e575f5ffd5b50613387612c73565b825161339281612be6565b81526133a06020840161331c565b60208201526133b160408401613337565b60408201526133c260608401613348565b60608201526133d360808401613348565b60808201526133e460a08401613348565b60a08201526133f560c0840161335d565b60c082015261340660e0840161335d565b60e08201529392505050565b5f6080828403128015613423575f5ffd5b5061342c612c29565b825161343781612be6565b815261344560208401613348565b602082015261345660408401613348565b60408201526134676060840161335d565b60608201529392505050565b65ffffffffffff1983168152604060208201525f610bb16040830184613298565b602081525f610e5d6020830184613298565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081526001600160401b0382511660208201525f60208301516060604084015261350260808401826134a6565b604094909401516001600160a01b0316606093909301929092525090919050565b5f82518060208501845e5f920191825250919050565b634e487b7160e01b5f52602160045260245ffd5b602081525f610e5d60208301846134a656fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212206c6a5038ef0698e3b9db9036abe217b9afe83908f73e0a871b820aca8511d98564736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01``@R0`\x80R4\x80\x15a\0\x14W__\xFD[P`@Qa9s8\x03\x80a9s\x839\x81\x01`@\x81\x90Ra\x003\x91a\x01\xB3V[\x80_[\x81Q\x81\x10\x15a\0\x8EW`\x01__\x84\x84\x81Q\x81\x10a\0UWa\0Ua\x02\xD0V[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x82R\x81\x01\x91\x90\x91R`@\x01_ \x80T`\xFF\x19\x16\x91\x15\x15\x91\x90\x91\x17\x90U`\x01\x01a\x006V[Pa\0\x99\x90Pa\0\xC5V[P`\x01`\x01`\xA0\x1B\x03\x94\x85\x16`\xC0R\x92\x84\x16`\xE0R\x90\x83\x16a\x01\0R\x82\x16a\x01 R\x16a\x01@Ra\x02\xE4V[`2Ta\x01\0\x90\x04`\xFF\x16\x15a\x011W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FInitializable: contract is initi`D\x82\x01Rfalizing`\xC8\x1B`d\x82\x01R`\x84\x01`@Q\x80\x91\x03\x90\xFD[`2T`\xFF\x90\x81\x16\x14a\x01\x82W`2\x80T`\xFF\x19\x16`\xFF\x90\x81\x17\x90\x91U`@Q\x90\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[V[\x80Q`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x01\x9AW__\xFD[\x91\x90PV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[______`\xC0\x87\x89\x03\x12\x15a\x01\xC8W__\xFD[a\x01\xD1\x87a\x01\x84V[\x95Pa\x01\xDF` \x88\x01a\x01\x84V[\x94Pa\x01\xED`@\x88\x01a\x01\x84V[\x93Pa\x01\xFB``\x88\x01a\x01\x84V[\x92Pa\x02\t`\x80\x88\x01a\x01\x84V[`\xA0\x88\x01Q\x90\x92P`\x01`\x01`@\x1B\x03\x81\x11\x15a\x02$W__\xFD[\x87\x01`\x1F\x81\x01\x89\x13a\x024W__\xFD[\x80Q`\x01`\x01`@\x1B\x03\x81\x11\x15a\x02MWa\x02Ma\x01\x9FV[`@Q`\x05\x82\x90\x1B\x90`?\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x02{Wa\x02{a\x01\x9FV[`@R\x91\x82R` \x81\x84\x01\x81\x01\x92\x90\x81\x01\x8C\x84\x11\x15a\x02\x98W__\xFD[` \x85\x01\x94P[\x83\x85\x10\x15a\x02\xBEWa\x02\xB0\x85a\x01\x84V[\x81R` \x94\x85\x01\x94\x01a\x02\x9FV[P\x80\x94PPPPP\x92\x95P\x92\x95P\x92\x95V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x01 Qa\x01@Qa5\xDCa\x03\x97_9_\x81\x81a\x07\x08\x01R\x81\x81a\x16k\x01Ra\x17f\x01R_\x81\x81a\x07\xF7\x01Ra\x10\x1E\x01R_\x81\x81a\x07X\x01R\x81\x81a\x13\xC7\x01Ra%h\x01R_\x81\x81a\x03\xD7\x01R\x81\x81a\x148\x01Ra&\xEB\x01R_\x81\x81a\x04*\x01R\x81\x81a\x1C\xF5\x01R\x81\x81a\x1EP\x01Ra\x1F\n\x01R_a\x02$\x01R_\x81\x81a\x0B\xC3\x01R\x81\x81a\x0C\x03\x01R\x81\x81a\x0C\xE5\x01R\x81\x81a\r%\x01Ra\r\x9C\x01Ra5\xDC_\xF3\xFE`\x80`@R`\x046\x10a\x02\x12W_5`\xE0\x1C\x80c\x8D\xA5\xCB[\x11a\x01\x1EW\x80c\xD3\xCB\xD8>\x11a\0\xA8W\x80c\xF1\xC2}\xAD\x11a\0mW\x80c\xF1\xC2}\xAD\x14a\x07\x99W\x80c\xF2\xFD\xE3\x8B\x14a\x07\xC7W\x80c\xFB\x0Er+\x14a\x07\xE6W\x80c\xFD@\xA5\xFE\x14a\x08\x19W\x80c\xFDR{\xE8\x14a\x08nW__\xFD[\x80c\xD3\xCB\xD8>\x14a\x06\xD8W\x80c\xD9\x1F$\xF1\x14a\x06\xF7W\x80c\xE3\x0C9x\x14a\x07*W\x80c\xE4_/\xC3\x14a\x07GW\x80c\xE4h\x9Dd\x14a\x07zW__\xFD[\x80c\xA4\x86\xE0\xDD\x11a\0\xEEW\x80c\xA4\x86\xE0\xDD\x14a\x05\xDFW\x80c\xAC\0\x04\xDA\x14a\x06EW\x80c\xAEAP\x1A\x14a\x06{W\x80c\xB4K-R\x14a\x06\x9AW\x80c\xCC\x80\x99\x90\x14a\x06\xB9W__\xFD[\x80c\x8D\xA5\xCB[\x14a\x04\xD3W\x80c\x93z\xAA\x9B\x14a\x04\xF0W\x80c\x9F\xE7\x86\xAB\x14a\x056W\x80c\xA2e\x1B\xB7\x14a\x05\xC0W__\xFD[\x80cR\xD1\x90-\x11a\x01\x9FW\x80cqP\x18\xA6\x11a\x01oW\x80cqP\x18\xA6\x14a\x04LW\x80cr\xF8J\x1D\x14a\x04`W\x80cy\xBAP\x97\x14a\x04\x97W\x80c\x84V\xCBY\x14a\x04\xABW\x80c\x8A\xBF`w\x14a\x04\xBFW__\xFD[\x80cR\xD1\x90-\x14a\x03\xA4W\x80c[\xF4\xEA\x85\x14a\x03\xC6W\x80c\\\x97Z\xBB\x14a\x03\xF9W\x80c]\xDC\x9E\x8D\x14a\x04\x19W__\xFD[\x80c0u\xDBV\x11a\x01\xE5W\x80c0u\xDBV\x14a\x02\xC5W\x80c1+\xCD\xE3\x14a\x02\xD9W\x80c6Y\xCF\xE6\x14a\x03^W\x80c?K\xA8:\x14a\x03}W\x80cO\x1E\xF2\x86\x14a\x03\x91W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02\x16W\x80c\x06A\x8F\x05\x14a\x02aW\x80c\x19\xABE<\x14a\x02\x82W\x80c#\xC0\xB1\xAB\x14a\x02\xA1W[__\xFD[4\x80\x15a\x02!W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02lW__\xFD[Pa\x02\x80a\x02{6`\x04a+\xCFV[a\x08\xB9V[\0[4\x80\x15a\x02\x8DW__\xFD[Pa\x02\x80a\x02\x9C6`\x04a+\xFAV[a\t\xFCV[4\x80\x15a\x02\xACW__\xFD[Pa\x02\xB5a\x0B\x15V[`@Q\x90\x15\x15\x81R` \x01a\x02XV[4\x80\x15a\x02\xD0W__\xFD[Pa\x02\xB5a\x0BmV[4\x80\x15a\x02\xE4W__\xFD[Pa\x02\xF8a\x02\xF36`\x04a.\x9EV[a\x0B\x85V[`@\x80Q\x82Q\x15\x15\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x82\x84\x01R\x84\x84\x01Q\x83\x85\x01R``\x80\x86\x01Q\x81\x85\x01R`\x80\x95\x86\x01Q\x80Q\x90\x92\x16\x95\x84\x01\x95\x90\x95R\x90\x81\x01Q`\xA0\x83\x01R\x91\x82\x01Q`\xC0\x82\x01R\x91\x01Q`\xE0\x82\x01Ra\x01\0\x01a\x02XV[4\x80\x15a\x03iW__\xFD[Pa\x02\x80a\x03x6`\x04a+\xFAV[a\x0B\xB9V[4\x80\x15a\x03\x88W__\xFD[Pa\x02\x80a\x0C\x80V[a\x02\x80a\x03\x9F6`\x04a.\xDFV[a\x0C\xDBV[4\x80\x15a\x03\xAFW__\xFD[Pa\x03\xB8a\r\x90V[`@Q\x90\x81R` \x01a\x02XV[4\x80\x15a\x03\xD1W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\x04W__\xFD[Pa\x02\xB5`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04$W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04WW__\xFD[Pa\x02\x80a\x0EAV[4\x80\x15a\x04kW__\xFD[Pa\x04\x7Fa\x04z6`\x04a/+V[a\x0ERV[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x02XV[4\x80\x15a\x04\xA2W__\xFD[Pa\x02\x80a\x0EfV[4\x80\x15a\x04\xB6W__\xFD[Pa\x02\x80a\x0E\xDDV[4\x80\x15a\x04\xCAW__\xFD[Pa\x02Da\x0F2V[4\x80\x15a\x04\xDEW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x02DV[4\x80\x15a\x04\xFBW__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Rb\x01Q\x80\x80\x82R\x90\x82\x01\x81\x81R\x83Q\x91\x82RQ\x91\x81\x01\x91\x90\x91R\x01a\x02XV[4\x80\x15a\x05AW__\xFD[Pa\x05\x9Aa\x05P6`\x04a+\xCFV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01RP_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x84R`\x01`0\x1B\x90\x91\x04\x16\x90\x82\x01R\x90V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x93\x84\x01Q\x16\x92\x81\x01\x92\x90\x92R\x01a\x02XV[4\x80\x15a\x05\xCBW__\xFD[Pa\x02\x80a\x05\xDA6`\x04a/dV[a\x0F@V[4\x80\x15a\x05\xEAW__\xFD[Pa\x06\x1Fa\x05\xF96`\x04a+\xCFV[a\x01-` R_\x90\x81R`@\x90 Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x90`\x01`0\x1B\x90\x04`0\x1B\x82V[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x83Re\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16` \x83\x01R\x01a\x02XV[4\x80\x15a\x06PW__\xFD[Pa\x06da\x06_6`\x04a/\xD3V[a\x10\x12V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02XV[4\x80\x15a\x06\x86W__\xFD[Pa\x04\x7Fa\x06\x956`\x04a+\xCFV[a\x11BV[4\x80\x15a\x06\xA5W__\xFD[Pa\x02\x80a\x06\xB46`\x04a/dV[a\x11\x96V[4\x80\x15a\x06\xC4W__\xFD[Pa\x02\x80a\x06\xD36`\x04a+\xCFV[a\x12cV[4\x80\x15a\x06\xE3W__\xFD[Pa\x02\xB5a\x06\xF26`\x04a0QV[a\x13\xA9V[4\x80\x15a\x07\x02W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x075W__\xFD[P`\x97T`\x01`\x01`\xA0\x1B\x03\x16a\x02DV[4\x80\x15a\x07RW__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07\x85W__\xFD[Pa\x02\xB5a\x07\x946`\x04a0QV[a\x13\xF7V[4\x80\x15a\x07\xA4W__\xFD[Pa\x02\xB5a\x07\xB36`\x04a+\xFAV[_` \x81\x90R\x90\x81R`@\x90 T`\xFF\x16\x81V[4\x80\x15a\x07\xD2W__\xFD[Pa\x02\x80a\x07\xE16`\x04a+\xFAV[a\x14\\V[4\x80\x15a\x07\xF1W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x08$W__\xFD[Pa\x02\xB5a\x0836`\x04a+\xCFV[_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[4\x80\x15a\x08yW__\xFD[Pa\x08\x82a\x14\xCDV[`@\x80Q\x82Qa\xFF\xFF\x16\x81R` \x80\x84\x01Q`\x01`\x01`P\x1B\x03\x90\x81\x16\x91\x83\x01\x91\x90\x91R\x92\x82\x01Q\x90\x92\x16\x90\x82\x01R``\x01a\x02XV[3_\x90\x81R` \x81\x90R`@\x90 T`\xFF\x16a\x08\xE8W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11\x15a\t=W`@Qc\x19\x96Gk`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x90\x82\x01RQ` \x82\x01Qa\t{\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a0\x85V[B\x11a\t\x9AW`@Qc\xA2\x82\x93\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16Be\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x1A\x87\x8B+\xF8h\x0C\x02\xF7\xD7\x9C\x19\x9Aa\xAD\xBE\x87D\xE8\xCC\xB0\xF1~6\"\x9Ba\x931\xFA.\x13\x91\x01[`@Q\x80\x91\x03\x90\xA2PPV[`2Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\n\x1CWP`2T`\x01`\xFF\x90\x91\x16\x10[\x80a\n6WP0;\x15\x80\x15a\n6WP`2T`\xFF\x16`\x01\x14[a\n\x9EW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[`2\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\n\xC1W`2\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\n\xCA\x82a\x15\nV[\x80\x15a\x0B\x11W`2\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01[`@Q\x80\x91\x03\x90\xA1[PPV[__a\x0B _a\x15iV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P\x80B\x03a\x0B8W_\x91PP\x90V[_a\x0BE`\x0C` a0\x98V[a\x0BO\x90\x83a0\x85V[\x90P\x80a\x0B[\x82a\x15\xEDV[Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x93\x92PPPV[_`\x02a\x0B|`\xFBT`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[a\x0B\x8Da+lV[_a\x0B\x9A`\x0C` a0\x98V[a\x0B\xA4\x90\x84a0\x85V[\x90Pa\x0B\xB1\x84\x84\x83a\x16\x1DV[\x94\x93PPPPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x0C\x01W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xAFV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0C3a\x17\xCAV[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0CYW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xFBV[a\x0Cb\x81a\x17\xE5V[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x0C}\x91\x83\x91\x90a\x17\xEDV[PV[a\x0C\x88a\x19\\V[a\x0C\x9C`\xFB\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0C\xD93_a\x19\x8DV[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\r#W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xAFV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\rUa\x17\xCAV[`\x01`\x01`\xA0\x1B\x03\x16\x14a\r{W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xFBV[a\r\x84\x82a\x17\xE5V[a\x0B\x11\x82\x82`\x01a\x17\xEDV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0E/W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x95V[P_Q` a5`_9_Q\x90_R\x90V[a\x0EIa\x19\x91V[a\x0C\xD9_a\x19\xEBV[_a\x0E]\x83\x83a\x1A\x04V[\x90P[\x92\x91PPV[`\x97T3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0E\xD4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x95V[a\x0C}\x81a\x19\xEBV[a\x0E\xE5a\x1A6V[`\xFB\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0C\xD93`\x01a\x19\x8DV[_a\x0F;a\x17\xCAV[\x90P\x90V[a\x0FHa\x19\x91V[_[\x81\x81\x10\x15a\x0F\xE0W_\x83\x83\x83\x81\x81\x10a\x0FeWa\x0Fea1GV[\x90P` \x02\x01` \x81\x01\x90a\x0Fz\x91\x90a+\xFAV[`\x01`\x01`\xA0\x1B\x03\x81\x16_\x90\x81R` \x81\x90R`@\x90 T\x90\x91P`\xFF\x16\x15a\x0F\xB6W`@QcDaI/`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x16_\x90\x81R` \x81\x90R`@\x90 \x80T`\xFF\x19\x16`\x01\x90\x81\x17\x90\x91U\x01a\x0FJV[P\x7F\xDA\xE2\x15\rI\xD9\xCB\x12 \xFBL'\x946\xB6\x9E\xCF\xFA@\xB1\xB6@%\xE3\x96\xB6\xBE]\x83\x0B\x814\x82\x82`@Qa\x0B\x08\x92\x91\x90a1[V[_3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x10\\W`@Qcr\x10\x9Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x10i\x83\x85\x01\x85a1\x9DV[\x90Pa\x10t\x81a\x1AhV[_a\x10}a\x1A\x9AV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P_a\x10\x94`\x0C` a0\x98V[a\x10\x9E\x90\x83a0\x85V[\x90P_a\x10\xAC\x84\x84\x84a\x16\x1DV[\x90P\x80` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x88`\x01`\x01`\xA0\x1B\x03\x16\x14a\x10\xE4W`@Qc@\x9B2\x0F`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`@\x01QB\x11\x80\x15a\x10\xFBWP\x80``\x01QB\x11\x15[a\x11\x18W`@QcE\xCB\n\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x11&\x83\x85`@\x01Qa\x1A\xA4V[a\x111\x82\x82\x86a\x1A\xEAV[``\x01Q\x93PPPP[\x93\x92PPPV[__a\x11M\x83a\x15\xEDV[`@\x80Q\x80\x82\x01\x90\x91R\x90Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x80\x83R`\x01`0\x1B\x90\x91\x04`0\x1Be\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16` \x83\x01R\x90\x91P\x83\x90\x03a\x11\x90W\x80` \x01Q\x91P[P\x91\x90PV[a\x11\x9Ea\x19\x91V[_[\x81\x81\x10\x15a\x121W_\x83\x83\x83\x81\x81\x10a\x11\xBBWa\x11\xBBa1GV[\x90P` \x02\x01` \x81\x01\x90a\x11\xD0\x91\x90a+\xFAV[`\x01`\x01`\xA0\x1B\x03\x81\x16_\x90\x81R` \x81\x90R`@\x90 T\x90\x91P`\xFF\x16a\x12\x0BW`@QcA\xD0\xC77`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x16_\x90\x81R` \x81\x90R`@\x90 \x80T`\xFF\x19\x16\x90U`\x01\x01a\x11\xA0V[P\x7F\xAE\xC1\xDF\xA3\"\x1B|Bnad\xE0\x8C\xA6\x81\x1AY\xE7\rO\xC9}~N\xFE\xCC\x7F/\x8A\xC4\xBAp\x82\x82`@Qa\x0B\x08\x92\x91\x90a1[V[3_\x90\x81R` \x81\x90R`@\x90 T`\xFF\x16a\x12\x92W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11a\x12\xE6W`@Qc\x0E\xC1\x12y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x91\x01\x81\x90R\x81Qa\x13!\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a0\x85V[B\x11a\x13@W`@Qc\x99\xD3\xFA\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x80Tk\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\x19\x16`\x01`0\x1BBe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x02\x91\x90\x91\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x96\x82\xAE?\xB7\x9C\x10\x94\x81\x16\xFE*\"L\xCA\x90%\xFBvqdw\xD7\x13\xDF\xECvm\x8B\xCC\xEE\x17\x91\x01a\t\xF0V[_\x82a\x13\xEB\x81\x84a\x13\xB8a\x14\xCDV[`@\x01Q`\x01`\x01`P\x1B\x03\x16\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1B9V[P`\x01\x95\x94PPPPPV[_\x80a\x14\x05`\x0C` a0\x98V[a\x14\x10\x90`\x02a0\x98V[a\x14\x1A\x90\x85a1\xCEV[\x90Pa\x13\xEB\x81\x84a\x14)a\x14\xCDV[` \x01Q`\x01`\x01`P\x1B\x03\x16\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1C|V[a\x14da\x19\x91V[`\x97\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x14\x95`eT`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[`@\x80Q``\x80\x82\x01\x83R_\x80\x83R` \x80\x84\x01\x82\x90R\x92\x84\x01R\x82Q\x90\x81\x01\x83Ra\x01\xF7\x81Rg\r\xE0\xB6\xB3\xA7d\0\0\x91\x81\x01\x82\x90R\x91\x82\x01R\x90V[`2Ta\x01\0\x90\x04`\xFF\x16a\x151W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a1\xE1V[a\x159a \x04V[a\x15W`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\x15QW\x81a\x19\xEBV[3a\x19\xEBV[P`\xFB\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[__a\x15tFa +V[\x90P_a\x15\x81\x82Ba1\xCEV[\x90P_a\x15\x90`\x0C` a0\x98V[a\x15\x9C`\x0C` a0\x98V[a\x15\xA6\x90\x84a2@V[a\x15\xB0\x91\x90a0\x98V[\x90Pa\x15\xE4a\x15\xC1`\x0C` a0\x98V[a\x15\xCB\x90\x87a0\x98V[a\x15\xD5\x83\x86a0\x85V[a\x15\xDF\x91\x90a0\x85V[a \x86V[\x95\x94PPPPPV[_a\x01-_a\x15\xFAa\x14\xCDV[Qa\x16\t\x90a\xFF\xFF\x16\x85a2SV[\x81R` \x01\x90\x81R` \x01_ \x90P\x91\x90PV[a\x16%a+lV[\x83`@\x01QQ_\x03a\x16BWa\x16;\x83\x83a \xF0V[\x90Pa\x16bV[\x83Q`\x01\x01a\x16UWa\x16;\x84\x83a!\x19V[a\x16_\x84\x84a!\xD9V[\x90P[\x80Q\x15a\x16\xFCW\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c4?\nh`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x16\xC5W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x16\xE9\x91\x90a2fV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01Ra\x11;V[a\x17C\x81`\x80\x01Q`@\x01Q_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[\x15a\x17\xAFW`\x01\x81R`@\x80Qc\x06\x87\xE1M`\xE3\x1B\x81R\x90Q`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x91c4?\nh\x91`\x04\x80\x83\x01\x92` \x92\x91\x90\x82\x90\x03\x01\x81\x86Z\xFA\x15\x80\x15a\x16\xC5W=__>=_\xFD[`\x80\x81\x01QQ`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R\x93\x92PPPV[_Q` a5`_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x0C}a\x19\x91V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x18%Wa\x18 \x83a\"pV[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x18\x7FWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x18|\x91\x81\x01\x90a2\x81V[`\x01[a\x18\xE2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x95V[_Q` a5`_9_Q\x90_R\x81\x14a\x19PW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x95V[Pa\x18 \x83\x83\x83a#\x0BV[a\x19p`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x0C\xD9W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x11[`eT`\x01`\x01`\xA0\x1B\x03\x163\x14a\x0C\xD9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x95V[`\x97\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x0C}\x81a#/V[_\x82\x82`@Q` \x01a\x1A\x18\x92\x91\x90a3\x04V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x92\x91PPV[a\x1AJ`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x0C\xD9W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80Q_\x19\x14\x80a\x1A}WP`@\x81\x01QQ\x81Q\x10[a\x0C}W`@Qc6(\xA8\x1B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0F;_a\x15iV[_a\x1A\xAE\x83a\x11BV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1A\xCAWa\x18 \x83\x83\x83a#\x80V[\x81Q\x15a\x18 W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1A\xF4\x84a\x11BV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1B(W\x81Q_\x19\x14a\x1B\x14WPPPPV[a\x1B#\x84\x83``\x01Q\x83a#\x80V[a\x1B3V[a\x1B3\x84\x84\x84a#\xB9V[PPPPV[`@\x80Qa\x01\0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x82\x90R`\xC0\x81\x01\x82\x90R`\xE0\x81\x01\x91\x90\x91R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R_a\x1B\xA9`\x0C` a0\x98V[a\x1B\xB4\x90`\x02a0\x98V[a\x1B\xBE\x90\x88a1\xCEV[\x90Pa\x1B\xCC\x81\x87\x87\x87a\x1C|V[_\x88\x81R`\x01` \x90\x81R`@\x80\x83 \x81Q\x80\x83\x01\x90\x92RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x84R`\x01`0\x1B\x90\x92\x04\x16\x92\x82\x01\x92\x90\x92R\x93\x96P\x91\x94P\x90\x15\x80a\x1C\x1DWP\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x10[\x90P_\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1CGWP\x83\x83` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x90P\x81\x80a\x1CRWP\x80[a\x1CoW`@Qcj`\x81\xD1`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPP\x94P\x94\x92PPPV[`@\x80Qa\x01\0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x82\x90R`\xC0\x81\x01\x82\x90R`\xE0\x81\x01\x91\x90\x91R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R`@Qc$\xD9\x12{`\xE2\x1B\x81R`\x04\x81\x01\x86\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c\x93dI\xEC\x90`$\x01a\x01\0`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1DCW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1Dg\x91\x90a3lV[\x91P\x81``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1D\x90WP\x85\x82``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[a\x1D\xADW`@Qci\xFE\x1F\xFB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x80\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x14\x80a\x1D\xD3WP\x85\x82`\x80\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1D\xF0W`@Qc\xA5R\xABI`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xA0\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1E\x14WP\x85\x82`\xA0\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1E1W`@QcL\x94\x19/`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@Qc\t\x0E\x1E\xED`\xE2\x1B\x81R`\x04\x81\x01\x86\x90R`$\x81\x01\x87\x90R_\x90\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c$8{\xB4\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1E\x9DW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1E\xC1\x91\x90a2\x81V[\x90P\x84\x81\x10\x15a\x1E\xE4W`@Qc\xC4\x1F\r\x0F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@Qc-\x0CX\xC9`\xE1\x1B\x81R`\x04\x81\x01\x87\x90R`\x01`\x01`\xA0\x1B\x03\x85\x81\x16`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90cZ\x18\xB1\x92\x90`D\x01`\x80`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1FOW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1Fs\x91\x90a4\x12V[\x91P\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1F\x9CWP\x86\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[a\x1F\xB9W`@Qco\xE7\xBC\xDB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1F\xDDWP\x86\x82`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1F\xFAW`@Qco\xE7\xBC\xDB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94P\x94\x92PPPV[`2Ta\x01\0\x90\x04`\xFF\x16a\x0C\xD9W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a1\xE1V[_`\x01\x82\x03a ?WPc_\xC60W\x91\x90PV[aBh\x82\x03a SWPce\x15j\xC0\x91\x90PV[d\x01\xA2\x14\x0C\xFF\x82\x03a jWPcfu]l\x91\x90PV[b\x08\x8B\xB0\x82\x03a \x7FWPcg\xD8\x11\x18\x91\x90PV[P_\x91\x90PV[_e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x11\x15a \xECW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FSafeCast: value doesn't fit in 4`D\x82\x01Re8 bits`\xD0\x1B`d\x82\x01R`\x84\x01a\n\x95V[P\x90V[a \xF8a+lV[`\x01\x81R`@\x81\x01\x83\x90Ra!\x0E`\x0C\x83a1\xCEV[``\x82\x01R\x92\x91PPV[a!!a+lV[`@\x83\x01Q\x80Qa!4\x90`\x01\x90a1\xCEV[\x81Q\x81\x10a!DWa!Da1GV[` \x02` \x01\x01Q` \x01Q\x81`@\x01\x81\x81RPP\x82``\x01QQ_\x03a!~W`\x01\x81Ra!t`\x0C\x83a1\xCEV[``\x82\x01Ra\x0E`V[_\x80\x82R``\x84\x01Q\x80Q\x90\x91\x90a!\x98Wa!\x98a1GV[` \x02` \x01\x01Q` \x01Q\x81``\x01\x81\x81RPP\x82``\x01Q_\x81Q\x81\x10a!\xC3Wa!\xC3a1GV[` \x02` \x01\x01Q\x81`\x80\x01\x81\x90RP\x92\x91PPV[a!\xE1a+lV[_\x81R`@\x83\x01Q\x83Q\x81Q\x81\x10a!\xFBWa!\xFBa1GV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q`\x80\x83\x01\x81\x90R\x01Q``\x82\x01R\x82Q_\x03a\"2Wa\"(`\x0C\x83a1\xCEV[`@\x82\x01Ra\x0E`V[`@\x83\x01Q\x83Qa\"E\x90`\x01\x90a1\xCEV[\x81Q\x81\x10a\"UWa\"Ua1GV[` \x02` \x01\x01Q` \x01Q\x81`@\x01\x81\x81RPP\x92\x91PPV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\"\xDDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x95V[_Q` a5`_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a#\x14\x83a$+V[_\x82Q\x11\x80a# WP\x80[\x15a\x18 Wa\x1B3\x83\x83a$jV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a#\x8B\x84\x84a\x1A\x04V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x81\x16\x90\x82\x16\x14a\x1B3W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\x80\x01QQ_\x03a#\xF2W\x81Qa#\xE4W`@Qc\x04vw\xF5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x1B3\x83\x82``\x01Qa$\x8FV[_a$\0\x82``\x01Qa&vV[\x90Pa$\x16\x84\x83` \x01Q\x83\x85`\x80\x01Qa'\x1DV[a$$\x84\x83``\x01Qa$\x8FV[PPPPPV[a$4\x81a\"pV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x0E]\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a5\x80`'\x919a'\xC3V[_a$\x98a\x0B\x15V[a$\xB5W`@Qc\rE\xC1\xAD`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0B\x19\x83\x01_a$\xC3a\x14\xCDV[`@\x01Q`\x01`\x01`P\x1B\x03\x16\x90P_[\x84Q\x81\x10\x15a%\xF9W_\x85\x82\x81Q\x81\x10a$\xF0Wa$\xF0a1GV[` \x02` \x01\x01Q\x90P\x83\x81` \x01Q\x11a%\x1EW`@Qc\\\x03\x14\x1B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0C\x87\x82` \x01Q\x03\x81a%4Wa%4a2,V[\x06\x15a%SW`@Qc\x97\x1C\xCE\x8F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80` \x01Q\x93P__a%\x8C\x89\x84`@\x01Q\x87\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1B9V[\x91P\x91P\x81`@\x01Qa\xFF\xFF\x16\x83``\x01Q\x10a%\xBCW`@Qc`\x16\xA6\xF3`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80Q\x83Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x16\x14a%\xEBW`@Qc\nQ\x9D\x8D`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPP\x80`\x01\x01\x90Pa$\xD4V[Pa\x01\x80\x85\x01\x82\x10a&\x1EW`@Qc\x96\xAC\xE7\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPa&*\x83\x83a\x1A\x04V[\x90Pa&6\x83\x82a(7V[\x82\x7F\xAE\x9Bd7\xAD&uS\xAF\xBF\x07U\x04\x05E\x8F\xC4?\x11\xF8\xC5\x007\xA3\xF6\xB4\xD7\x93pd\xCC\n\x82\x84`@Qa&h\x92\x91\x90a4sV[`@Q\x80\x91\x03\x90\xA2\x92\x91PPV[a&\xAA`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01``\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90V[`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01\x83`@Q` \x01a&\xD5\x91\x90a4\x94V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x81R` \x01\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90P\x91\x90PV[_a'*`\x0C` a0\x98V[a'5\x90`\x02a0\x98V[a'?\x90\x86a1\xCEV[\x90P_a'O\x82\x86a\x14)a\x14\xCDV[\x91PP_a'\x83\x85`@Q` \x01a'g\x91\x90a4\xD4V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x85a(`V[\x90P\x81_\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x81`\x01`\x01`\xA0\x1B\x03\x16\x14a'\xBAW`@Qc\x15}\xF6\xA5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa'\xDF\x91\x90a5#V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a(\x17W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a(\x1CV[``\x91P[P\x91P\x91Pa(-\x86\x83\x83\x87a(\x82V[\x96\x95PPPPPPV[_a(A\x83a\x15\xEDV[`0\x92\x90\x92\x1C`\x01`0\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x92\x90\x92\x17\x90UPV[___a(m\x85\x85a(\xFAV[\x91P\x91Pa(z\x81a)<V[P\x93\x92PPPV[``\x83\x15a(\xF0W\x82Q_\x03a(\xE9W`\x01`\x01`\xA0\x1B\x03\x85\x16;a(\xE9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x95V[P\x81a\x0B\xB1V[a\x0B\xB1\x83\x83a*\x85V[__\x82Q`A\x03a).W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa)\"\x87\x82\x85\x85a*\xAFV[\x94P\x94PPPPa)5V[P_\x90P`\x02[\x92P\x92\x90PV[_\x81`\x04\x81\x11\x15a)OWa)Oa59V[\x03a)WWPV[`\x01\x81`\x04\x81\x11\x15a)kWa)ka59V[\x03a)\xB8W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x18`$\x82\x01R\x7FECDSA: invalid signature\0\0\0\0\0\0\0\0`D\x82\x01R`d\x01a\n\x95V[`\x02\x81`\x04\x81\x11\x15a)\xCCWa)\xCCa59V[\x03a*\x19W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FECDSA: invalid signature length\0`D\x82\x01R`d\x01a\n\x95V[`\x03\x81`\x04\x81\x11\x15a*-Wa*-a59V[\x03a\x0C}W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\"`$\x82\x01R\x7FECDSA: invalid signature 's' val`D\x82\x01Raue`\xF0\x1B`d\x82\x01R`\x84\x01a\n\x95V[\x81Q\x15a*\x95W\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x91\x90a5MV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a*\xE4WP_\x90P`\x03a+cV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a+5W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a+]W_`\x01\x92P\x92PPa+cV[\x91P_\x90P[\x94P\x94\x92PPPV[`@Q\x80`\xA0\x01`@R\x80_\x15\x15\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01a+\xCA`@Q\x80`\x80\x01`@R\x80_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x90R\x90V[_` \x82\x84\x03\x12\x15a+\xDFW__\xFD[P5\x91\x90PV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0C}W__\xFD[_` \x82\x84\x03\x12\x15a,\nW__\xFD[\x815a\x11;\x81a+\xE6V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@Qa\x01\0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,\xBEWa,\xBEa,\x15V[`@R\x91\x90PV[_\x82`\x1F\x83\x01\x12a,\xD5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a,\xEEWa,\xEEa,\x15V[a,\xFD` \x82`\x05\x1B\x01a,\x96V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a-\x1EW__\xFD[` \x85\x01[\x83\x81\x10\x15a-}W`\x80\x81\x88\x03\x12\x15a-:W__\xFD[a-Ba,)V[\x815a-M\x81a+\xE6V[\x81R` \x82\x81\x015\x81\x83\x01R`@\x80\x84\x015\x90\x83\x01R``\x80\x84\x015\x90\x83\x01R\x90\x84R\x92\x90\x92\x01\x91`\x80\x01a-#V[P\x95\x94PPPPPV[_\x82`\x1F\x83\x01\x12a-\x96W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xAFWa-\xAFa,\x15V[a-\xC2`\x1F\x82\x01`\x1F\x19\x16` \x01a,\x96V[\x81\x81R\x84` \x83\x86\x01\x01\x11\x15a-\xD6W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[_`\xA0\x82\x84\x03\x12\x15a.\x02W__\xFD[a.\na,QV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90P`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.2W__\xFD[a.>\x84\x82\x85\x01a,\xC6V[`@\x83\x01RP``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.\\W__\xFD[a.h\x84\x82\x85\x01a,\xC6V[``\x83\x01RP`\x80\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.\x86W__\xFD[a.\x92\x84\x82\x85\x01a-\x87V[`\x80\x83\x01RP\x92\x91PPV[__`@\x83\x85\x03\x12\x15a.\xAFW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a.\xC4W__\xFD[a.\xD0\x85\x82\x86\x01a-\xF2V[\x95` \x94\x90\x94\x015\x94PPPPV[__`@\x83\x85\x03\x12\x15a.\xF0W__\xFD[\x825a.\xFB\x81a+\xE6V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a/\x15W__\xFD[a/!\x85\x82\x86\x01a-\x87V[\x91PP\x92P\x92\x90PV[__`@\x83\x85\x03\x12\x15a/<W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a/XW__\xFD[a/!\x85\x82\x86\x01a,\xC6V[__` \x83\x85\x03\x12\x15a/uW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a/\x8AW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a/\x9AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xAFW__\xFD[\x85` \x82`\x05\x1B\x84\x01\x01\x11\x15a/\xC3W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[___`@\x84\x86\x03\x12\x15a/\xE5W__\xFD[\x835a/\xF0\x81a+\xE6V[\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\nW__\xFD[\x84\x01`\x1F\x81\x01\x86\x13a0\x1AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a0/W__\xFD[\x86` \x82\x84\x01\x01\x11\x15a0@W__\xFD[\x93\x96` \x91\x90\x91\x01\x95P\x92\x93PPPV[__`@\x83\x85\x03\x12\x15a0bW__\xFD[PP\x805\x92` \x90\x91\x015\x91PV[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x0E`Wa\x0E`a0qV[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x0E`Wa\x0E`a0qV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[` \x80\x82R\x81\x01\x82\x90R_\x83`@\x83\x01\x82[\x85\x81\x10\x15a-}W\x825a1\x80\x81a+\xE6V[`\x01`\x01`\xA0\x1B\x03\x16\x82R` \x92\x83\x01\x92\x90\x91\x01\x90`\x01\x01a1mV[_` \x82\x84\x03\x12\x15a1\xADW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1\xC2W__\xFD[a\x0B\xB1\x84\x82\x85\x01a-\xF2V[\x81\x81\x03\x81\x81\x11\x15a\x0E`Wa\x0E`a0qV[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a2NWa2Na2,V[P\x04\x90V[_\x82a2aWa2aa2,V[P\x06\x90V[_` \x82\x84\x03\x12\x15a2vW__\xFD[\x81Qa\x11;\x81a+\xE6V[_` \x82\x84\x03\x12\x15a2\x91W__\xFD[PQ\x91\x90PV[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a2\xFAWa2\xE4\x86\x83Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16\x82R` \x80\x82\x01Q\x90\x83\x01R`@\x80\x82\x01Q\x90\x83\x01R``\x90\x81\x01Q\x91\x01RV[`\x80\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a2\xAAV[P\x93\x94\x93PPPPV[\x82\x81R`@` \x82\x01R_a\x0B\xB1`@\x83\x01\x84a2\x98V[\x80Q`\x01`\x01`P\x1B\x03\x81\x16\x81\x14a32W__\xFD[\x91\x90PV[\x80Qa\xFF\xFF\x81\x16\x81\x14a32W__\xFD[\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a32W__\xFD[\x80Q\x80\x15\x15\x81\x14a32W__\xFD[_a\x01\0\x82\x84\x03\x12\x80\x15a3~W__\xFD[Pa3\x87a,sV[\x82Qa3\x92\x81a+\xE6V[\x81Ra3\xA0` \x84\x01a3\x1CV[` \x82\x01Ra3\xB1`@\x84\x01a37V[`@\x82\x01Ra3\xC2``\x84\x01a3HV[``\x82\x01Ra3\xD3`\x80\x84\x01a3HV[`\x80\x82\x01Ra3\xE4`\xA0\x84\x01a3HV[`\xA0\x82\x01Ra3\xF5`\xC0\x84\x01a3]V[`\xC0\x82\x01Ra4\x06`\xE0\x84\x01a3]V[`\xE0\x82\x01R\x93\x92PPPV[_`\x80\x82\x84\x03\x12\x80\x15a4#W__\xFD[Pa4,a,)V[\x82Qa47\x81a+\xE6V[\x81Ra4E` \x84\x01a3HV[` \x82\x01Ra4V`@\x84\x01a3HV[`@\x82\x01Ra4g``\x84\x01a3]V[``\x82\x01R\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x19\x83\x16\x81R`@` \x82\x01R_a\x0B\xB1`@\x83\x01\x84a2\x98V[` \x81R_a\x0E]` \x83\x01\x84a2\x98V[_\x81Q\x80\x84R\x80` \x84\x01` \x86\x01^_` \x82\x86\x01\x01R` `\x1F\x19`\x1F\x83\x01\x16\x85\x01\x01\x91PP\x92\x91PPV[` \x81R`\x01`\x01`@\x1B\x03\x82Q\x16` \x82\x01R_` \x83\x01Q```@\x84\x01Ra5\x02`\x80\x84\x01\x82a4\xA6V[`@\x94\x90\x94\x01Q`\x01`\x01`\xA0\x1B\x03\x16``\x93\x90\x93\x01\x92\x90\x92RP\x90\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x81R_a\x0E]` \x83\x01\x84a4\xA6V\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 ljP8\xEF\x06\x98\xE3\xB9\xDB\x906\xAB\xE2\x17\xB9\xAF\xE89\x08\xF7>\n\x87\x1B\x82\n\xCA\x85\x11\xD9\x85dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405260043610610212575f3560e01c80638da5cb5b1161011e578063d3cbd83e116100a8578063f1c27dad1161006d578063f1c27dad14610799578063f2fde38b146107c7578063fb0e722b146107e6578063fd40a5fe14610819578063fd527be81461086e575f5ffd5b8063d3cbd83e146106d8578063d91f24f1146106f7578063e30c39781461072a578063e45f2fc314610747578063e4689d641461077a575f5ffd5b8063a486e0dd116100ee578063a486e0dd146105df578063ac0004da14610645578063ae41501a1461067b578063b44b2d521461069a578063cc809990146106b9575f5ffd5b80638da5cb5b146104d3578063937aaa9b146104f05780639fe786ab14610536578063a2651bb7146105c0575f5ffd5b806352d1902d1161019f578063715018a61161016f578063715018a61461044c57806372f84a1d1461046057806379ba5097146104975780638456cb59146104ab5780638abf6077146104bf575f5ffd5b806352d1902d146103a45780635bf4ea85146103c65780635c975abb146103f95780635ddc9e8d14610419575f5ffd5b80633075db56116101e55780633075db56146102c5578063312bcde3146102d95780633659cfe61461035e5780633f4ba83a1461037d5780634f1ef28614610391575f5ffd5b806304f3bcec1461021657806306418f051461026157806319ab453c1461028257806323c0b1ab146102a1575b5f5ffd5b348015610221575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b34801561026c575f5ffd5b5061028061027b366004612bcf565b6108b9565b005b34801561028d575f5ffd5b5061028061029c366004612bfa565b6109fc565b3480156102ac575f5ffd5b506102b5610b15565b6040519015158152602001610258565b3480156102d0575f5ffd5b506102b5610b6d565b3480156102e4575f5ffd5b506102f86102f3366004612e9e565b610b85565b604080518251151581526020808401516001600160a01b03908116828401528484015183850152606080860151818501526080958601518051909216958401959095529081015160a08301529182015160c082015291015160e082015261010001610258565b348015610369575f5ffd5b50610280610378366004612bfa565b610bb9565b348015610388575f5ffd5b50610280610c80565b61028061039f366004612edf565b610cdb565b3480156103af575f5ffd5b506103b8610d90565b604051908152602001610258565b3480156103d1575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610404575f5ffd5b506102b560fb54610100900460ff1660021490565b348015610424575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610457575f5ffd5b50610280610e41565b34801561046b575f5ffd5b5061047f61047a366004612f2b565b610e52565b60405165ffffffffffff199091168152602001610258565b3480156104a2575f5ffd5b50610280610e66565b3480156104b6575f5ffd5b50610280610edd565b3480156104ca575f5ffd5b50610244610f32565b3480156104de575f5ffd5b506065546001600160a01b0316610244565b3480156104fb575f5ffd5b506040805180820182525f80825260209182015281518083018352620151808082529082018181528351918252519181019190915201610258565b348015610541575f5ffd5b5061059a610550366004612bcf565b604080518082019091525f8082526020820152505f9081526001602090815260409182902082518084019093525465ffffffffffff8082168452600160301b909104169082015290565b60408051825165ffffffffffff9081168252602093840151169281019290925201610258565b3480156105cb575f5ffd5b506102806105da366004612f64565b610f40565b3480156105ea575f5ffd5b5061061f6105f9366004612bcf565b61012d6020525f908152604090205465ffffffffffff811690600160301b900460301b82565b6040805165ffffffffffff909316835265ffffffffffff19909116602083015201610258565b348015610650575f5ffd5b5061066461065f366004612fd3565b611012565b60405165ffffffffffff9091168152602001610258565b348015610686575f5ffd5b5061047f610695366004612bcf565b611142565b3480156106a5575f5ffd5b506102806106b4366004612f64565b611196565b3480156106c4575f5ffd5b506102806106d3366004612bcf565b611263565b3480156106e3575f5ffd5b506102b56106f2366004613051565b6113a9565b348015610702575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610735575f5ffd5b506097546001600160a01b0316610244565b348015610752575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610785575f5ffd5b506102b5610794366004613051565b6113f7565b3480156107a4575f5ffd5b506102b56107b3366004612bfa565b5f6020819052908152604090205460ff1681565b3480156107d2575f5ffd5b506102806107e1366004612bfa565b61145c565b3480156107f1575f5ffd5b506102447f000000000000000000000000000000000000000000000000000000000000000081565b348015610824575f5ffd5b506102b5610833366004612bcf565b5f9081526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b348015610879575f5ffd5b506108826114cd565b60408051825161ffff1681526020808401516001600160501b03908116918301919091529282015190921690820152606001610258565b335f9081526020819052604090205460ff166108e85760405163ac9d87cd60e01b815260040160405180910390fd5b5f8181526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416918301829052111561093d57604051631996476b60e01b815260040160405180910390fd5b6040805180820182525f8082526020918201528151808301909252620151808083529082015251602082015161097b919065ffffffffffff16613085565b421161099a5760405163a282931f60e01b815260040160405180910390fd5b5f82815260016020908152604091829020805465ffffffffffff19164265ffffffffffff16908117909155915191825283917f1a878b2bf8680c02f7d79c199a61adbe8744e8ccb0f17e36229b619331fa2e1391015b60405180910390a25050565b603254610100900460ff1615808015610a1c5750603254600160ff909116105b80610a365750303b158015610a36575060325460ff166001145b610a9e5760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b60648201526084015b60405180910390fd5b6032805460ff191660011790558015610ac1576032805461ff0019166101001790555b610aca8261150a565b8015610b11576032805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498906020015b60405180910390a15b5050565b5f5f610b205f611569565b65ffffffffffff169050804203610b38575f91505090565b5f610b45600c6020613098565b610b4f9083613085565b905080610b5b826115ed565b5465ffffffffffff1614159392505050565b5f6002610b7c60fb5460ff1690565b60ff1614905090565b610b8d612b6c565b5f610b9a600c6020613098565b610ba49084613085565b9050610bb184848361161d565b949350505050565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610c015760405162461bcd60e51b8152600401610a95906130af565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610c336117ca565b6001600160a01b031614610c595760405162461bcd60e51b8152600401610a95906130fb565b610c62816117e5565b604080515f80825260208201909252610c7d918391906117ed565b50565b610c8861195c565b610c9c60fb805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610cd9335f61198d565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610d235760405162461bcd60e51b8152600401610a95906130af565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610d556117ca565b6001600160a01b031614610d7b5760405162461bcd60e51b8152600401610a95906130fb565b610d84826117e5565b610b11828260016117ed565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610e2f5760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a95565b505f5160206135605f395f51905f5290565b610e49611991565b610cd95f6119eb565b5f610e5d8383611a04565b90505b92915050565b60975433906001600160a01b03168114610ed45760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a95565b610c7d816119eb565b610ee5611a36565b60fb805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610cd933600161198d565b5f610f3b6117ca565b905090565b610f48611991565b5f5b81811015610fe0575f838383818110610f6557610f65613147565b9050602002016020810190610f7a9190612bfa565b6001600160a01b0381165f9081526020819052604090205490915060ff1615610fb657604051634461492f60e01b815260040160405180910390fd5b6001600160a01b03165f908152602081905260409020805460ff1916600190811790915501610f4a565b507fdae2150d49d9cb1220fb4c279436b69ecffa40b1b64025e396b6be5d830b81348282604051610b0892919061315b565b5f336001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461105c576040516372109f7760e01b815260040160405180910390fd5b5f6110698385018561319d565b905061107481611a68565b5f61107d611a9a565b65ffffffffffff1690505f611094600c6020613098565b61109e9083613085565b90505f6110ac84848461161d565b905080602001516001600160a01b0316886001600160a01b0316146110e45760405163409b320f60e11b815260040160405180910390fd5b8060400151421180156110fb575080606001514211155b611118576040516345cb0af960e01b815260040160405180910390fd5b611126838560400151611aa4565b611131828286611aea565b6060015193505050505b9392505050565b5f5f61114d836115ed565b60408051808201909152905465ffffffffffff8116808352600160301b90910460301b65ffffffffffff1916602083015290915083900361119057806020015191505b50919050565b61119e611991565b5f5b81811015611231575f8383838181106111bb576111bb613147565b90506020020160208101906111d09190612bfa565b6001600160a01b0381165f9081526020819052604090205490915060ff1661120b576040516341d0c73760e01b815260040160405180910390fd5b6001600160a01b03165f908152602081905260409020805460ff191690556001016111a0565b507faec1dfa3221b7c426e6164e08ca6811a59e70d4fc97d7e4efecc7f2f8ac4ba708282604051610b0892919061315b565b335f9081526020819052604090205460ff166112925760405163ac9d87cd60e01b815260040160405180910390fd5b5f8181526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416918301829052116112e657604051630ec1127960e01b815260040160405180910390fd5b6040805180820182525f80825260209182015281518083019092526201518080835291018190528151611321919065ffffffffffff16613085565b4211611340576040516399d3faf960e01b815260040160405180910390fd5b5f8281526001602090815260409182902080546bffffffffffff0000000000001916600160301b4265ffffffffffff1690810291909117909155915191825283917f9682ae3fb79c10948116fe2a224cca9025fb76716477d713dfec766d8bccee1791016109f0565b5f826113eb81846113b86114cd565b604001516001600160501b03167f0000000000000000000000000000000000000000000000000000000000000000611b39565b50600195945050505050565b5f80611405600c6020613098565b611410906002613098565b61141a90856131ce565b90506113eb81846114296114cd565b602001516001600160501b03167f0000000000000000000000000000000000000000000000000000000000000000611c7c565b611464611991565b609780546001600160a01b0383166001600160a01b031990911681179091556114956065546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b60408051606080820183525f808352602080840182905292840152825190810183526101f78152670de0b6b3a76400009181018290529182015290565b603254610100900460ff166115315760405162461bcd60e51b8152600401610a95906131e1565b611539612004565b6115576001600160a01b0382161561155157816119eb565b336119eb565b5060fb805461ff001916610100179055565b5f5f6115744661202b565b90505f61158182426131ce565b90505f611590600c6020613098565b61159c600c6020613098565b6115a69084613240565b6115b09190613098565b90506115e46115c1600c6020613098565b6115cb9087613098565b6115d58386613085565b6115df9190613085565b612086565b95945050505050565b5f61012d5f6115fa6114cd565b516116099061ffff1685613253565b81526020019081526020015f209050919050565b611625612b6c565b8360400151515f036116425761163b83836120f0565b9050611662565b83516001016116555761163b8483612119565b61165f84846121d9565b90505b8051156116fc577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663343f0a686040518163ffffffff1660e01b8152600401602060405180830381865afa1580156116c5573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906116e99190613266565b6001600160a01b0316602082015261113b565b6117438160800151604001515f9081526001602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b156117af576001815260408051630687e14d60e31b815290516001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169163343f0a689160048083019260209291908290030181865afa1580156116c5573d5f5f3e3d5ffd5b6080810151516001600160a01b031660208201529392505050565b5f5160206135605f395f51905f52546001600160a01b031690565b610c7d611991565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff16156118255761182083612270565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa92505050801561187f575060408051601f3d908101601f1916820190925261187c91810190613281565b60015b6118e25760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a95565b5f5160206135605f395f51905f5281146119505760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a95565b5061182083838361230b565b61197060fb54610100900460ff1660021490565b610cd95760405163bae6e2a960e01b815260040160405180910390fd5b610b115b6065546001600160a01b03163314610cd95760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a95565b609780546001600160a01b0319169055610c7d8161232f565b5f8282604051602001611a18929190613304565b60405160208183030381529060405280519060200120905092915050565b611a4a60fb54610100900460ff1660021490565b15610cd95760405163bae6e2a960e01b815260040160405180910390fd5b80515f191480611a7d57506040810151518151105b610c7d57604051633628a81b60e01b815260040160405180910390fd5b5f610f3b5f611569565b5f611aae83611142565b905065ffffffffffff19811615611aca57611820838383612380565b8151156118205760405163eaf82a2560e01b815260040160405180910390fd5b5f611af484611142565b905065ffffffffffff19811615611b285781515f1914611b145750505050565b611b2384836060015183612380565b611b33565b611b338484846123b9565b50505050565b60408051610100810182525f80825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e0810191909152604080516080810182525f8082526020820181905291810182905260608101919091525f611ba9600c6020613098565b611bb4906002613098565b611bbe90886131ce565b9050611bcc81878787611c7c565b5f88815260016020908152604080832081518083019092525465ffffffffffff808216808452600160301b9092041692820192909252939650919450901580611c1d5750815165ffffffffffff1683105b90505f826020015165ffffffffffff165f14158015611c47575083836020015165ffffffffffff16105b90508180611c525750805b611c6f57604051636a6081d160e11b815260040160405180910390fd5b5050505094509492505050565b60408051610100810182525f80825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e0810191909152604080516080810182525f8082526020820181905291810182905260608101919091526040516324d9127b60e21b8152600481018690527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03169063936449ec9060240161010060405180830381865afa158015611d43573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611d67919061336c565b9150816060015165ffffffffffff165f14158015611d90575085826060015165ffffffffffff16105b611dad576040516369fe1ffb60e11b815260040160405180910390fd5b608082015165ffffffffffff9081161480611dd3575085826080015165ffffffffffff16115b611df05760405163a552ab4960e01b815260040160405180910390fd5b60a082015165ffffffffffff161580611e145750858260a0015165ffffffffffff16115b611e3157604051634c94192f60e01b815260040160405180910390fd5b60405163090e1eed60e21b815260048101869052602481018790525f907f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316906324387bb490604401602060405180830381865afa158015611e9d573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611ec19190613281565b905084811015611ee45760405163c41f0d0f60e01b815260040160405180910390fd5b604051632d0c58c960e11b8152600481018790526001600160a01b0385811660248301527f00000000000000000000000000000000000000000000000000000000000000001690635a18b19290604401608060405180830381865afa158015611f4f573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611f739190613412565b9150816020015165ffffffffffff165f14158015611f9c575086826020015165ffffffffffff16105b611fb957604051636fe7bcdb60e11b815260040160405180910390fd5b604082015165ffffffffffff161580611fdd575086826040015165ffffffffffff16115b611ffa57604051636fe7bcdb60e11b815260040160405180910390fd5b5094509492505050565b603254610100900460ff16610cd95760405162461bcd60e51b8152600401610a95906131e1565b5f6001820361203f5750635fc63057919050565b614268820361205357506365156ac0919050565b6401a2140cff820361206a57506366755d6c919050565b62088bb0820361207f57506367d81118919050565b505f919050565b5f65ffffffffffff8211156120ec5760405162461bcd60e51b815260206004820152602660248201527f53616665436173743a2076616c756520646f65736e27742066697420696e203460448201526538206269747360d01b6064820152608401610a95565b5090565b6120f8612b6c565b600181526040810183905261210e600c836131ce565b606082015292915050565b612121612b6c565b60408301518051612134906001906131ce565b8151811061214457612144613147565b6020026020010151602001518160400181815250508260600151515f0361217e5760018152612174600c836131ce565b6060820152610e60565b5f8082526060840151805190919061219857612198613147565b60200260200101516020015181606001818152505082606001515f815181106121c3576121c3613147565b6020026020010151816080018190525092915050565b6121e1612b6c565b5f815260408301518351815181106121fb576121fb613147565b602090810291909101810151608083018190520151606082015282515f0361223257612228600c836131ce565b6040820152610e60565b60408301518351612245906001906131ce565b8151811061225557612255613147565b60200260200101516020015181604001818152505092915050565b6001600160a01b0381163b6122dd5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a95565b5f5160206135605f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b6123148361242b565b5f825111806123205750805b1561182057611b33838361246a565b606580546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f61238b8484611a04565b905065ffffffffffff1982811690821614611b335760405163eaf82a2560e01b815260040160405180910390fd5b8060800151515f036123f25781516123e45760405163047677f560e21b815260040160405180910390fd5b611b3383826060015161248f565b5f6124008260600151612676565b905061241684836020015183856080015161271d565b61242484836060015161248f565b5050505050565b61243481612270565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060610e5d8383604051806060016040528060278152602001613580602791396127c3565b5f612498610b15565b6124b557604051630d45c1ad60e21b815260040160405180910390fd5b600b1983015f6124c36114cd565b604001516001600160501b031690505f5b84518110156125f9575f8582815181106124f0576124f0613147565b602002602001015190508381602001511161251e57604051635c03141b60e11b815260040160405180910390fd5b600c87826020015103816125345761253461322c565b06156125535760405163971cce8f60e01b815260040160405180910390fd5b806020015193505f5f61258c898460400151877f0000000000000000000000000000000000000000000000000000000000000000611b39565b91509150816040015161ffff168360600151106125bc57604051636016a6f360e01b815260040160405180910390fd5b805183516001600160a01b039081169116146125eb57604051630a519d8d60e31b815260040160405180910390fd5b5050508060010190506124d4565b506101808501821061261e576040516396ace79b60e01b815260040160405180910390fd5b505061262a8383611a04565b90506126368382612837565b827fae9b6437ad267553afbf07550405458fc43f11f8c50037a3f6b4d7937064cc0a8284604051612668929190613473565b60405180910390a292915050565b6126aa60405180606001604052805f6001600160401b03168152602001606081526020015f6001600160a01b031681525090565b60405180606001604052805f6001600160401b03168152602001836040516020016126d59190613494565b60405160208183030381529060405281526020017f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03168152509050919050565b5f61272a600c6020613098565b612735906002613098565b61273f90866131ce565b90505f61274f82866114296114cd565b9150505f6127838560405160200161276791906134d4565b6040516020818303038152906040528051906020012085612860565b9050815f01516001600160a01b0316816001600160a01b0316146127ba5760405163157df6a560e21b815260040160405180910390fd5b50505050505050565b60605f5f856001600160a01b0316856040516127df9190613523565b5f60405180830381855af49150503d805f8114612817576040519150601f19603f3d011682016040523d82523d5f602084013e61281c565b606091505b509150915061282d86838387612882565b9695505050505050565b5f612841836115ed565b60309290921c600160301b0265ffffffffffff90931692909217905550565b5f5f5f61286d85856128fa565b9150915061287a8161293c565b509392505050565b606083156128f05782515f036128e9576001600160a01b0385163b6128e95760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a95565b5081610bb1565b610bb18383612a85565b5f5f825160410361292e576020830151604084015160608501515f1a61292287828585612aaf565b94509450505050612935565b505f905060025b9250929050565b5f81600481111561294f5761294f613539565b036129575750565b600181600481111561296b5761296b613539565b036129b85760405162461bcd60e51b815260206004820152601860248201527f45434453413a20696e76616c6964207369676e617475726500000000000000006044820152606401610a95565b60028160048111156129cc576129cc613539565b03612a195760405162461bcd60e51b815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e677468006044820152606401610a95565b6003816004811115612a2d57612a2d613539565b03610c7d5760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c604482015261756560f01b6064820152608401610a95565b815115612a955781518083602001fd5b8060405162461bcd60e51b8152600401610a95919061354d565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115612ae457505f90506003612b63565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612b35573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612b5d575f60019250925050612b63565b91505f90505b94509492505050565b6040518060a001604052805f151581526020015f6001600160a01b031681526020015f81526020015f8152602001612bca60405180608001604052805f6001600160a01b031681526020015f81526020015f81526020015f81525090565b905290565b5f60208284031215612bdf575f5ffd5b5035919050565b6001600160a01b0381168114610c7d575f5ffd5b5f60208284031215612c0a575f5ffd5b813561113b81612be6565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b0381118282101715612c4b57612c4b612c15565b60405290565b60405160a081016001600160401b0381118282101715612c4b57612c4b612c15565b60405161010081016001600160401b0381118282101715612c4b57612c4b612c15565b604051601f8201601f191681016001600160401b0381118282101715612cbe57612cbe612c15565b604052919050565b5f82601f830112612cd5575f5ffd5b81356001600160401b03811115612cee57612cee612c15565b612cfd60208260051b01612c96565b8082825260208201915060208360071b860101925085831115612d1e575f5ffd5b602085015b83811015612d7d5760808188031215612d3a575f5ffd5b612d42612c29565b8135612d4d81612be6565b81526020828101358183015260408084013590830152606080840135908301529084529290920191608001612d23565b5095945050505050565b5f82601f830112612d96575f5ffd5b81356001600160401b03811115612daf57612daf612c15565b612dc2601f8201601f1916602001612c96565b818152846020838601011115612dd6575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f60a08284031215612e02575f5ffd5b612e0a612c51565b8235815260208084013590820152905060408201356001600160401b03811115612e32575f5ffd5b612e3e84828501612cc6565b60408301525060608201356001600160401b03811115612e5c575f5ffd5b612e6884828501612cc6565b60608301525060808201356001600160401b03811115612e86575f5ffd5b612e9284828501612d87565b60808301525092915050565b5f5f60408385031215612eaf575f5ffd5b82356001600160401b03811115612ec4575f5ffd5b612ed085828601612df2565b95602094909401359450505050565b5f5f60408385031215612ef0575f5ffd5b8235612efb81612be6565b915060208301356001600160401b03811115612f15575f5ffd5b612f2185828601612d87565b9150509250929050565b5f5f60408385031215612f3c575f5ffd5b8235915060208301356001600160401b03811115612f58575f5ffd5b612f2185828601612cc6565b5f5f60208385031215612f75575f5ffd5b82356001600160401b03811115612f8a575f5ffd5b8301601f81018513612f9a575f5ffd5b80356001600160401b03811115612faf575f5ffd5b8560208260051b8401011115612fc3575f5ffd5b6020919091019590945092505050565b5f5f5f60408486031215612fe5575f5ffd5b8335612ff081612be6565b925060208401356001600160401b0381111561300a575f5ffd5b8401601f8101861361301a575f5ffd5b80356001600160401b0381111561302f575f5ffd5b866020828401011115613040575f5ffd5b939660209190910195509293505050565b5f5f60408385031215613062575f5ffd5b50508035926020909101359150565b634e487b7160e01b5f52601160045260245ffd5b80820180821115610e6057610e60613071565b8082028115828204841417610e6057610e60613071565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b634e487b7160e01b5f52603260045260245ffd5b602080825281018290525f8360408301825b85811015612d7d57823561318081612be6565b6001600160a01b031682526020928301929091019060010161316d565b5f602082840312156131ad575f5ffd5b81356001600160401b038111156131c2575f5ffd5b610bb184828501612df2565b81810381811115610e6057610e60613071565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b634e487b7160e01b5f52601260045260245ffd5b5f8261324e5761324e61322c565b500490565b5f826132615761326161322c565b500690565b5f60208284031215613276575f5ffd5b815161113b81612be6565b5f60208284031215613291575f5ffd5b5051919050565b5f8151808452602084019350602083015f5b828110156132fa576132e486835180516001600160a01b031682526020808201519083015260408082015190830152606090810151910152565b60809590950194602091909101906001016132aa565b5093949350505050565b828152604060208201525f610bb16040830184613298565b80516001600160501b0381168114613332575f5ffd5b919050565b805161ffff81168114613332575f5ffd5b805165ffffffffffff81168114613332575f5ffd5b80518015158114613332575f5ffd5b5f61010082840312801561337e575f5ffd5b50613387612c73565b825161339281612be6565b81526133a06020840161331c565b60208201526133b160408401613337565b60408201526133c260608401613348565b60608201526133d360808401613348565b60808201526133e460a08401613348565b60a08201526133f560c0840161335d565b60c082015261340660e0840161335d565b60e08201529392505050565b5f6080828403128015613423575f5ffd5b5061342c612c29565b825161343781612be6565b815261344560208401613348565b602082015261345660408401613348565b60408201526134676060840161335d565b60608201529392505050565b65ffffffffffff1983168152604060208201525f610bb16040830184613298565b602081525f610e5d6020830184613298565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081526001600160401b0382511660208201525f60208301516060604084015261350260808401826134a6565b604094909401516001600160a01b0316606093909301929092525090919050565b5f82518060208501845e5f920191825250919050565b634e487b7160e01b5f52602160045260245ffd5b602081525f610e5d60208301846134a656fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212206c6a5038ef0698e3b9db9036abe217b9afe83908f73e0a871b820aca8511d98564736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R`\x046\x10a\x02\x12W_5`\xE0\x1C\x80c\x8D\xA5\xCB[\x11a\x01\x1EW\x80c\xD3\xCB\xD8>\x11a\0\xA8W\x80c\xF1\xC2}\xAD\x11a\0mW\x80c\xF1\xC2}\xAD\x14a\x07\x99W\x80c\xF2\xFD\xE3\x8B\x14a\x07\xC7W\x80c\xFB\x0Er+\x14a\x07\xE6W\x80c\xFD@\xA5\xFE\x14a\x08\x19W\x80c\xFDR{\xE8\x14a\x08nW__\xFD[\x80c\xD3\xCB\xD8>\x14a\x06\xD8W\x80c\xD9\x1F$\xF1\x14a\x06\xF7W\x80c\xE3\x0C9x\x14a\x07*W\x80c\xE4_/\xC3\x14a\x07GW\x80c\xE4h\x9Dd\x14a\x07zW__\xFD[\x80c\xA4\x86\xE0\xDD\x11a\0\xEEW\x80c\xA4\x86\xE0\xDD\x14a\x05\xDFW\x80c\xAC\0\x04\xDA\x14a\x06EW\x80c\xAEAP\x1A\x14a\x06{W\x80c\xB4K-R\x14a\x06\x9AW\x80c\xCC\x80\x99\x90\x14a\x06\xB9W__\xFD[\x80c\x8D\xA5\xCB[\x14a\x04\xD3W\x80c\x93z\xAA\x9B\x14a\x04\xF0W\x80c\x9F\xE7\x86\xAB\x14a\x056W\x80c\xA2e\x1B\xB7\x14a\x05\xC0W__\xFD[\x80cR\xD1\x90-\x11a\x01\x9FW\x80cqP\x18\xA6\x11a\x01oW\x80cqP\x18\xA6\x14a\x04LW\x80cr\xF8J\x1D\x14a\x04`W\x80cy\xBAP\x97\x14a\x04\x97W\x80c\x84V\xCBY\x14a\x04\xABW\x80c\x8A\xBF`w\x14a\x04\xBFW__\xFD[\x80cR\xD1\x90-\x14a\x03\xA4W\x80c[\xF4\xEA\x85\x14a\x03\xC6W\x80c\\\x97Z\xBB\x14a\x03\xF9W\x80c]\xDC\x9E\x8D\x14a\x04\x19W__\xFD[\x80c0u\xDBV\x11a\x01\xE5W\x80c0u\xDBV\x14a\x02\xC5W\x80c1+\xCD\xE3\x14a\x02\xD9W\x80c6Y\xCF\xE6\x14a\x03^W\x80c?K\xA8:\x14a\x03}W\x80cO\x1E\xF2\x86\x14a\x03\x91W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02\x16W\x80c\x06A\x8F\x05\x14a\x02aW\x80c\x19\xABE<\x14a\x02\x82W\x80c#\xC0\xB1\xAB\x14a\x02\xA1W[__\xFD[4\x80\x15a\x02!W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02lW__\xFD[Pa\x02\x80a\x02{6`\x04a+\xCFV[a\x08\xB9V[\0[4\x80\x15a\x02\x8DW__\xFD[Pa\x02\x80a\x02\x9C6`\x04a+\xFAV[a\t\xFCV[4\x80\x15a\x02\xACW__\xFD[Pa\x02\xB5a\x0B\x15V[`@Q\x90\x15\x15\x81R` \x01a\x02XV[4\x80\x15a\x02\xD0W__\xFD[Pa\x02\xB5a\x0BmV[4\x80\x15a\x02\xE4W__\xFD[Pa\x02\xF8a\x02\xF36`\x04a.\x9EV[a\x0B\x85V[`@\x80Q\x82Q\x15\x15\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x82\x84\x01R\x84\x84\x01Q\x83\x85\x01R``\x80\x86\x01Q\x81\x85\x01R`\x80\x95\x86\x01Q\x80Q\x90\x92\x16\x95\x84\x01\x95\x90\x95R\x90\x81\x01Q`\xA0\x83\x01R\x91\x82\x01Q`\xC0\x82\x01R\x91\x01Q`\xE0\x82\x01Ra\x01\0\x01a\x02XV[4\x80\x15a\x03iW__\xFD[Pa\x02\x80a\x03x6`\x04a+\xFAV[a\x0B\xB9V[4\x80\x15a\x03\x88W__\xFD[Pa\x02\x80a\x0C\x80V[a\x02\x80a\x03\x9F6`\x04a.\xDFV[a\x0C\xDBV[4\x80\x15a\x03\xAFW__\xFD[Pa\x03\xB8a\r\x90V[`@Q\x90\x81R` \x01a\x02XV[4\x80\x15a\x03\xD1W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\x04W__\xFD[Pa\x02\xB5`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04$W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04WW__\xFD[Pa\x02\x80a\x0EAV[4\x80\x15a\x04kW__\xFD[Pa\x04\x7Fa\x04z6`\x04a/+V[a\x0ERV[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x02XV[4\x80\x15a\x04\xA2W__\xFD[Pa\x02\x80a\x0EfV[4\x80\x15a\x04\xB6W__\xFD[Pa\x02\x80a\x0E\xDDV[4\x80\x15a\x04\xCAW__\xFD[Pa\x02Da\x0F2V[4\x80\x15a\x04\xDEW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x02DV[4\x80\x15a\x04\xFBW__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Rb\x01Q\x80\x80\x82R\x90\x82\x01\x81\x81R\x83Q\x91\x82RQ\x91\x81\x01\x91\x90\x91R\x01a\x02XV[4\x80\x15a\x05AW__\xFD[Pa\x05\x9Aa\x05P6`\x04a+\xCFV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01RP_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x84R`\x01`0\x1B\x90\x91\x04\x16\x90\x82\x01R\x90V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x93\x84\x01Q\x16\x92\x81\x01\x92\x90\x92R\x01a\x02XV[4\x80\x15a\x05\xCBW__\xFD[Pa\x02\x80a\x05\xDA6`\x04a/dV[a\x0F@V[4\x80\x15a\x05\xEAW__\xFD[Pa\x06\x1Fa\x05\xF96`\x04a+\xCFV[a\x01-` R_\x90\x81R`@\x90 Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x90`\x01`0\x1B\x90\x04`0\x1B\x82V[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x83Re\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16` \x83\x01R\x01a\x02XV[4\x80\x15a\x06PW__\xFD[Pa\x06da\x06_6`\x04a/\xD3V[a\x10\x12V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02XV[4\x80\x15a\x06\x86W__\xFD[Pa\x04\x7Fa\x06\x956`\x04a+\xCFV[a\x11BV[4\x80\x15a\x06\xA5W__\xFD[Pa\x02\x80a\x06\xB46`\x04a/dV[a\x11\x96V[4\x80\x15a\x06\xC4W__\xFD[Pa\x02\x80a\x06\xD36`\x04a+\xCFV[a\x12cV[4\x80\x15a\x06\xE3W__\xFD[Pa\x02\xB5a\x06\xF26`\x04a0QV[a\x13\xA9V[4\x80\x15a\x07\x02W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x075W__\xFD[P`\x97T`\x01`\x01`\xA0\x1B\x03\x16a\x02DV[4\x80\x15a\x07RW__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07\x85W__\xFD[Pa\x02\xB5a\x07\x946`\x04a0QV[a\x13\xF7V[4\x80\x15a\x07\xA4W__\xFD[Pa\x02\xB5a\x07\xB36`\x04a+\xFAV[_` \x81\x90R\x90\x81R`@\x90 T`\xFF\x16\x81V[4\x80\x15a\x07\xD2W__\xFD[Pa\x02\x80a\x07\xE16`\x04a+\xFAV[a\x14\\V[4\x80\x15a\x07\xF1W__\xFD[Pa\x02D\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x08$W__\xFD[Pa\x02\xB5a\x0836`\x04a+\xCFV[_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[4\x80\x15a\x08yW__\xFD[Pa\x08\x82a\x14\xCDV[`@\x80Q\x82Qa\xFF\xFF\x16\x81R` \x80\x84\x01Q`\x01`\x01`P\x1B\x03\x90\x81\x16\x91\x83\x01\x91\x90\x91R\x92\x82\x01Q\x90\x92\x16\x90\x82\x01R``\x01a\x02XV[3_\x90\x81R` \x81\x90R`@\x90 T`\xFF\x16a\x08\xE8W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11\x15a\t=W`@Qc\x19\x96Gk`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x90\x82\x01RQ` \x82\x01Qa\t{\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a0\x85V[B\x11a\t\x9AW`@Qc\xA2\x82\x93\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16Be\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x1A\x87\x8B+\xF8h\x0C\x02\xF7\xD7\x9C\x19\x9Aa\xAD\xBE\x87D\xE8\xCC\xB0\xF1~6\"\x9Ba\x931\xFA.\x13\x91\x01[`@Q\x80\x91\x03\x90\xA2PPV[`2Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\n\x1CWP`2T`\x01`\xFF\x90\x91\x16\x10[\x80a\n6WP0;\x15\x80\x15a\n6WP`2T`\xFF\x16`\x01\x14[a\n\x9EW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[`2\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\n\xC1W`2\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\n\xCA\x82a\x15\nV[\x80\x15a\x0B\x11W`2\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01[`@Q\x80\x91\x03\x90\xA1[PPV[__a\x0B _a\x15iV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P\x80B\x03a\x0B8W_\x91PP\x90V[_a\x0BE`\x0C` a0\x98V[a\x0BO\x90\x83a0\x85V[\x90P\x80a\x0B[\x82a\x15\xEDV[Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x93\x92PPPV[_`\x02a\x0B|`\xFBT`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[a\x0B\x8Da+lV[_a\x0B\x9A`\x0C` a0\x98V[a\x0B\xA4\x90\x84a0\x85V[\x90Pa\x0B\xB1\x84\x84\x83a\x16\x1DV[\x94\x93PPPPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x0C\x01W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xAFV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0C3a\x17\xCAV[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0CYW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xFBV[a\x0Cb\x81a\x17\xE5V[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x0C}\x91\x83\x91\x90a\x17\xEDV[PV[a\x0C\x88a\x19\\V[a\x0C\x9C`\xFB\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0C\xD93_a\x19\x8DV[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\r#W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xAFV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\rUa\x17\xCAV[`\x01`\x01`\xA0\x1B\x03\x16\x14a\r{W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a0\xFBV[a\r\x84\x82a\x17\xE5V[a\x0B\x11\x82\x82`\x01a\x17\xEDV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0E/W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x95V[P_Q` a5`_9_Q\x90_R\x90V[a\x0EIa\x19\x91V[a\x0C\xD9_a\x19\xEBV[_a\x0E]\x83\x83a\x1A\x04V[\x90P[\x92\x91PPV[`\x97T3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0E\xD4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x95V[a\x0C}\x81a\x19\xEBV[a\x0E\xE5a\x1A6V[`\xFB\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0C\xD93`\x01a\x19\x8DV[_a\x0F;a\x17\xCAV[\x90P\x90V[a\x0FHa\x19\x91V[_[\x81\x81\x10\x15a\x0F\xE0W_\x83\x83\x83\x81\x81\x10a\x0FeWa\x0Fea1GV[\x90P` \x02\x01` \x81\x01\x90a\x0Fz\x91\x90a+\xFAV[`\x01`\x01`\xA0\x1B\x03\x81\x16_\x90\x81R` \x81\x90R`@\x90 T\x90\x91P`\xFF\x16\x15a\x0F\xB6W`@QcDaI/`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x16_\x90\x81R` \x81\x90R`@\x90 \x80T`\xFF\x19\x16`\x01\x90\x81\x17\x90\x91U\x01a\x0FJV[P\x7F\xDA\xE2\x15\rI\xD9\xCB\x12 \xFBL'\x946\xB6\x9E\xCF\xFA@\xB1\xB6@%\xE3\x96\xB6\xBE]\x83\x0B\x814\x82\x82`@Qa\x0B\x08\x92\x91\x90a1[V[_3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x10\\W`@Qcr\x10\x9Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x10i\x83\x85\x01\x85a1\x9DV[\x90Pa\x10t\x81a\x1AhV[_a\x10}a\x1A\x9AV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P_a\x10\x94`\x0C` a0\x98V[a\x10\x9E\x90\x83a0\x85V[\x90P_a\x10\xAC\x84\x84\x84a\x16\x1DV[\x90P\x80` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x88`\x01`\x01`\xA0\x1B\x03\x16\x14a\x10\xE4W`@Qc@\x9B2\x0F`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`@\x01QB\x11\x80\x15a\x10\xFBWP\x80``\x01QB\x11\x15[a\x11\x18W`@QcE\xCB\n\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x11&\x83\x85`@\x01Qa\x1A\xA4V[a\x111\x82\x82\x86a\x1A\xEAV[``\x01Q\x93PPPP[\x93\x92PPPV[__a\x11M\x83a\x15\xEDV[`@\x80Q\x80\x82\x01\x90\x91R\x90Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x80\x83R`\x01`0\x1B\x90\x91\x04`0\x1Be\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16` \x83\x01R\x90\x91P\x83\x90\x03a\x11\x90W\x80` \x01Q\x91P[P\x91\x90PV[a\x11\x9Ea\x19\x91V[_[\x81\x81\x10\x15a\x121W_\x83\x83\x83\x81\x81\x10a\x11\xBBWa\x11\xBBa1GV[\x90P` \x02\x01` \x81\x01\x90a\x11\xD0\x91\x90a+\xFAV[`\x01`\x01`\xA0\x1B\x03\x81\x16_\x90\x81R` \x81\x90R`@\x90 T\x90\x91P`\xFF\x16a\x12\x0BW`@QcA\xD0\xC77`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x16_\x90\x81R` \x81\x90R`@\x90 \x80T`\xFF\x19\x16\x90U`\x01\x01a\x11\xA0V[P\x7F\xAE\xC1\xDF\xA3\"\x1B|Bnad\xE0\x8C\xA6\x81\x1AY\xE7\rO\xC9}~N\xFE\xCC\x7F/\x8A\xC4\xBAp\x82\x82`@Qa\x0B\x08\x92\x91\x90a1[V[3_\x90\x81R` \x81\x90R`@\x90 T`\xFF\x16a\x12\x92W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11a\x12\xE6W`@Qc\x0E\xC1\x12y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x91\x01\x81\x90R\x81Qa\x13!\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a0\x85V[B\x11a\x13@W`@Qc\x99\xD3\xFA\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x80Tk\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\x19\x16`\x01`0\x1BBe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x02\x91\x90\x91\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x96\x82\xAE?\xB7\x9C\x10\x94\x81\x16\xFE*\"L\xCA\x90%\xFBvqdw\xD7\x13\xDF\xECvm\x8B\xCC\xEE\x17\x91\x01a\t\xF0V[_\x82a\x13\xEB\x81\x84a\x13\xB8a\x14\xCDV[`@\x01Q`\x01`\x01`P\x1B\x03\x16\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1B9V[P`\x01\x95\x94PPPPPV[_\x80a\x14\x05`\x0C` a0\x98V[a\x14\x10\x90`\x02a0\x98V[a\x14\x1A\x90\x85a1\xCEV[\x90Pa\x13\xEB\x81\x84a\x14)a\x14\xCDV[` \x01Q`\x01`\x01`P\x1B\x03\x16\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1C|V[a\x14da\x19\x91V[`\x97\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x14\x95`eT`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[`@\x80Q``\x80\x82\x01\x83R_\x80\x83R` \x80\x84\x01\x82\x90R\x92\x84\x01R\x82Q\x90\x81\x01\x83Ra\x01\xF7\x81Rg\r\xE0\xB6\xB3\xA7d\0\0\x91\x81\x01\x82\x90R\x91\x82\x01R\x90V[`2Ta\x01\0\x90\x04`\xFF\x16a\x151W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a1\xE1V[a\x159a \x04V[a\x15W`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\x15QW\x81a\x19\xEBV[3a\x19\xEBV[P`\xFB\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[__a\x15tFa +V[\x90P_a\x15\x81\x82Ba1\xCEV[\x90P_a\x15\x90`\x0C` a0\x98V[a\x15\x9C`\x0C` a0\x98V[a\x15\xA6\x90\x84a2@V[a\x15\xB0\x91\x90a0\x98V[\x90Pa\x15\xE4a\x15\xC1`\x0C` a0\x98V[a\x15\xCB\x90\x87a0\x98V[a\x15\xD5\x83\x86a0\x85V[a\x15\xDF\x91\x90a0\x85V[a \x86V[\x95\x94PPPPPV[_a\x01-_a\x15\xFAa\x14\xCDV[Qa\x16\t\x90a\xFF\xFF\x16\x85a2SV[\x81R` \x01\x90\x81R` \x01_ \x90P\x91\x90PV[a\x16%a+lV[\x83`@\x01QQ_\x03a\x16BWa\x16;\x83\x83a \xF0V[\x90Pa\x16bV[\x83Q`\x01\x01a\x16UWa\x16;\x84\x83a!\x19V[a\x16_\x84\x84a!\xD9V[\x90P[\x80Q\x15a\x16\xFCW\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c4?\nh`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x16\xC5W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x16\xE9\x91\x90a2fV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01Ra\x11;V[a\x17C\x81`\x80\x01Q`@\x01Q_\x90\x81R`\x01` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[\x15a\x17\xAFW`\x01\x81R`@\x80Qc\x06\x87\xE1M`\xE3\x1B\x81R\x90Q`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x91c4?\nh\x91`\x04\x80\x83\x01\x92` \x92\x91\x90\x82\x90\x03\x01\x81\x86Z\xFA\x15\x80\x15a\x16\xC5W=__>=_\xFD[`\x80\x81\x01QQ`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R\x93\x92PPPV[_Q` a5`_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x0C}a\x19\x91V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x18%Wa\x18 \x83a\"pV[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x18\x7FWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x18|\x91\x81\x01\x90a2\x81V[`\x01[a\x18\xE2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x95V[_Q` a5`_9_Q\x90_R\x81\x14a\x19PW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x95V[Pa\x18 \x83\x83\x83a#\x0BV[a\x19p`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x0C\xD9W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x11[`eT`\x01`\x01`\xA0\x1B\x03\x163\x14a\x0C\xD9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x95V[`\x97\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x0C}\x81a#/V[_\x82\x82`@Q` \x01a\x1A\x18\x92\x91\x90a3\x04V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x92\x91PPV[a\x1AJ`\xFBTa\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x0C\xD9W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80Q_\x19\x14\x80a\x1A}WP`@\x81\x01QQ\x81Q\x10[a\x0C}W`@Qc6(\xA8\x1B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0F;_a\x15iV[_a\x1A\xAE\x83a\x11BV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1A\xCAWa\x18 \x83\x83\x83a#\x80V[\x81Q\x15a\x18 W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1A\xF4\x84a\x11BV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1B(W\x81Q_\x19\x14a\x1B\x14WPPPPV[a\x1B#\x84\x83``\x01Q\x83a#\x80V[a\x1B3V[a\x1B3\x84\x84\x84a#\xB9V[PPPPV[`@\x80Qa\x01\0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x82\x90R`\xC0\x81\x01\x82\x90R`\xE0\x81\x01\x91\x90\x91R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R_a\x1B\xA9`\x0C` a0\x98V[a\x1B\xB4\x90`\x02a0\x98V[a\x1B\xBE\x90\x88a1\xCEV[\x90Pa\x1B\xCC\x81\x87\x87\x87a\x1C|V[_\x88\x81R`\x01` \x90\x81R`@\x80\x83 \x81Q\x80\x83\x01\x90\x92RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x84R`\x01`0\x1B\x90\x92\x04\x16\x92\x82\x01\x92\x90\x92R\x93\x96P\x91\x94P\x90\x15\x80a\x1C\x1DWP\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x83\x10[\x90P_\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1CGWP\x83\x83` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x90P\x81\x80a\x1CRWP\x80[a\x1CoW`@Qcj`\x81\xD1`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPP\x94P\x94\x92PPPV[`@\x80Qa\x01\0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x82\x90R`\xA0\x81\x01\x82\x90R`\xC0\x81\x01\x82\x90R`\xE0\x81\x01\x91\x90\x91R`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R`@Qc$\xD9\x12{`\xE2\x1B\x81R`\x04\x81\x01\x86\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c\x93dI\xEC\x90`$\x01a\x01\0`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1DCW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1Dg\x91\x90a3lV[\x91P\x81``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1D\x90WP\x85\x82``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[a\x1D\xADW`@Qci\xFE\x1F\xFB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x80\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x14\x80a\x1D\xD3WP\x85\x82`\x80\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1D\xF0W`@Qc\xA5R\xABI`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xA0\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1E\x14WP\x85\x82`\xA0\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1E1W`@QcL\x94\x19/`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@Qc\t\x0E\x1E\xED`\xE2\x1B\x81R`\x04\x81\x01\x86\x90R`$\x81\x01\x87\x90R_\x90\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c$8{\xB4\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1E\x9DW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1E\xC1\x91\x90a2\x81V[\x90P\x84\x81\x10\x15a\x1E\xE4W`@Qc\xC4\x1F\r\x0F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@Qc-\x0CX\xC9`\xE1\x1B\x81R`\x04\x81\x01\x87\x90R`\x01`\x01`\xA0\x1B\x03\x85\x81\x16`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90cZ\x18\xB1\x92\x90`D\x01`\x80`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1FOW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1Fs\x91\x90a4\x12V[\x91P\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x15\x80\x15a\x1F\x9CWP\x86\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[a\x1F\xB9W`@Qco\xE7\xBC\xDB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1F\xDDWP\x86\x82`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[a\x1F\xFAW`@Qco\xE7\xBC\xDB`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94P\x94\x92PPPV[`2Ta\x01\0\x90\x04`\xFF\x16a\x0C\xD9W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x90a1\xE1V[_`\x01\x82\x03a ?WPc_\xC60W\x91\x90PV[aBh\x82\x03a SWPce\x15j\xC0\x91\x90PV[d\x01\xA2\x14\x0C\xFF\x82\x03a jWPcfu]l\x91\x90PV[b\x08\x8B\xB0\x82\x03a \x7FWPcg\xD8\x11\x18\x91\x90PV[P_\x91\x90PV[_e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x11\x15a \xECW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FSafeCast: value doesn't fit in 4`D\x82\x01Re8 bits`\xD0\x1B`d\x82\x01R`\x84\x01a\n\x95V[P\x90V[a \xF8a+lV[`\x01\x81R`@\x81\x01\x83\x90Ra!\x0E`\x0C\x83a1\xCEV[``\x82\x01R\x92\x91PPV[a!!a+lV[`@\x83\x01Q\x80Qa!4\x90`\x01\x90a1\xCEV[\x81Q\x81\x10a!DWa!Da1GV[` \x02` \x01\x01Q` \x01Q\x81`@\x01\x81\x81RPP\x82``\x01QQ_\x03a!~W`\x01\x81Ra!t`\x0C\x83a1\xCEV[``\x82\x01Ra\x0E`V[_\x80\x82R``\x84\x01Q\x80Q\x90\x91\x90a!\x98Wa!\x98a1GV[` \x02` \x01\x01Q` \x01Q\x81``\x01\x81\x81RPP\x82``\x01Q_\x81Q\x81\x10a!\xC3Wa!\xC3a1GV[` \x02` \x01\x01Q\x81`\x80\x01\x81\x90RP\x92\x91PPV[a!\xE1a+lV[_\x81R`@\x83\x01Q\x83Q\x81Q\x81\x10a!\xFBWa!\xFBa1GV[` \x90\x81\x02\x91\x90\x91\x01\x81\x01Q`\x80\x83\x01\x81\x90R\x01Q``\x82\x01R\x82Q_\x03a\"2Wa\"(`\x0C\x83a1\xCEV[`@\x82\x01Ra\x0E`V[`@\x83\x01Q\x83Qa\"E\x90`\x01\x90a1\xCEV[\x81Q\x81\x10a\"UWa\"Ua1GV[` \x02` \x01\x01Q` \x01Q\x81`@\x01\x81\x81RPP\x92\x91PPV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\"\xDDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x95V[_Q` a5`_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a#\x14\x83a$+V[_\x82Q\x11\x80a# WP\x80[\x15a\x18 Wa\x1B3\x83\x83a$jV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a#\x8B\x84\x84a\x1A\x04V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x81\x16\x90\x82\x16\x14a\x1B3W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`\x80\x01QQ_\x03a#\xF2W\x81Qa#\xE4W`@Qc\x04vw\xF5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x1B3\x83\x82``\x01Qa$\x8FV[_a$\0\x82``\x01Qa&vV[\x90Pa$\x16\x84\x83` \x01Q\x83\x85`\x80\x01Qa'\x1DV[a$$\x84\x83``\x01Qa$\x8FV[PPPPPV[a$4\x81a\"pV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x0E]\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a5\x80`'\x919a'\xC3V[_a$\x98a\x0B\x15V[a$\xB5W`@Qc\rE\xC1\xAD`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0B\x19\x83\x01_a$\xC3a\x14\xCDV[`@\x01Q`\x01`\x01`P\x1B\x03\x16\x90P_[\x84Q\x81\x10\x15a%\xF9W_\x85\x82\x81Q\x81\x10a$\xF0Wa$\xF0a1GV[` \x02` \x01\x01Q\x90P\x83\x81` \x01Q\x11a%\x1EW`@Qc\\\x03\x14\x1B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0C\x87\x82` \x01Q\x03\x81a%4Wa%4a2,V[\x06\x15a%SW`@Qc\x97\x1C\xCE\x8F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80` \x01Q\x93P__a%\x8C\x89\x84`@\x01Q\x87\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x1B9V[\x91P\x91P\x81`@\x01Qa\xFF\xFF\x16\x83``\x01Q\x10a%\xBCW`@Qc`\x16\xA6\xF3`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80Q\x83Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x16\x14a%\xEBW`@Qc\nQ\x9D\x8D`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPP\x80`\x01\x01\x90Pa$\xD4V[Pa\x01\x80\x85\x01\x82\x10a&\x1EW`@Qc\x96\xAC\xE7\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPa&*\x83\x83a\x1A\x04V[\x90Pa&6\x83\x82a(7V[\x82\x7F\xAE\x9Bd7\xAD&uS\xAF\xBF\x07U\x04\x05E\x8F\xC4?\x11\xF8\xC5\x007\xA3\xF6\xB4\xD7\x93pd\xCC\n\x82\x84`@Qa&h\x92\x91\x90a4sV[`@Q\x80\x91\x03\x90\xA2\x92\x91PPV[a&\xAA`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01``\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90V[`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01\x83`@Q` \x01a&\xD5\x91\x90a4\x94V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x81R` \x01\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90P\x91\x90PV[_a'*`\x0C` a0\x98V[a'5\x90`\x02a0\x98V[a'?\x90\x86a1\xCEV[\x90P_a'O\x82\x86a\x14)a\x14\xCDV[\x91PP_a'\x83\x85`@Q` \x01a'g\x91\x90a4\xD4V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x85a(`V[\x90P\x81_\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x81`\x01`\x01`\xA0\x1B\x03\x16\x14a'\xBAW`@Qc\x15}\xF6\xA5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa'\xDF\x91\x90a5#V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a(\x17W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a(\x1CV[``\x91P[P\x91P\x91Pa(-\x86\x83\x83\x87a(\x82V[\x96\x95PPPPPPV[_a(A\x83a\x15\xEDV[`0\x92\x90\x92\x1C`\x01`0\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x92\x90\x92\x17\x90UPV[___a(m\x85\x85a(\xFAV[\x91P\x91Pa(z\x81a)<V[P\x93\x92PPPV[``\x83\x15a(\xF0W\x82Q_\x03a(\xE9W`\x01`\x01`\xA0\x1B\x03\x85\x16;a(\xE9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x95V[P\x81a\x0B\xB1V[a\x0B\xB1\x83\x83a*\x85V[__\x82Q`A\x03a).W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa)\"\x87\x82\x85\x85a*\xAFV[\x94P\x94PPPPa)5V[P_\x90P`\x02[\x92P\x92\x90PV[_\x81`\x04\x81\x11\x15a)OWa)Oa59V[\x03a)WWPV[`\x01\x81`\x04\x81\x11\x15a)kWa)ka59V[\x03a)\xB8W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x18`$\x82\x01R\x7FECDSA: invalid signature\0\0\0\0\0\0\0\0`D\x82\x01R`d\x01a\n\x95V[`\x02\x81`\x04\x81\x11\x15a)\xCCWa)\xCCa59V[\x03a*\x19W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FECDSA: invalid signature length\0`D\x82\x01R`d\x01a\n\x95V[`\x03\x81`\x04\x81\x11\x15a*-Wa*-a59V[\x03a\x0C}W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\"`$\x82\x01R\x7FECDSA: invalid signature 's' val`D\x82\x01Raue`\xF0\x1B`d\x82\x01R`\x84\x01a\n\x95V[\x81Q\x15a*\x95W\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x95\x91\x90a5MV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a*\xE4WP_\x90P`\x03a+cV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a+5W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a+]W_`\x01\x92P\x92PPa+cV[\x91P_\x90P[\x94P\x94\x92PPPV[`@Q\x80`\xA0\x01`@R\x80_\x15\x15\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01a+\xCA`@Q\x80`\x80\x01`@R\x80_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01_\x81RP\x90V[\x90R\x90V[_` \x82\x84\x03\x12\x15a+\xDFW__\xFD[P5\x91\x90PV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0C}W__\xFD[_` \x82\x84\x03\x12\x15a,\nW__\xFD[\x815a\x11;\x81a+\xE6V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@R\x90V[`@Q`\xA0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@Qa\x01\0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,KWa,Ka,\x15V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a,\xBEWa,\xBEa,\x15V[`@R\x91\x90PV[_\x82`\x1F\x83\x01\x12a,\xD5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a,\xEEWa,\xEEa,\x15V[a,\xFD` \x82`\x05\x1B\x01a,\x96V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a-\x1EW__\xFD[` \x85\x01[\x83\x81\x10\x15a-}W`\x80\x81\x88\x03\x12\x15a-:W__\xFD[a-Ba,)V[\x815a-M\x81a+\xE6V[\x81R` \x82\x81\x015\x81\x83\x01R`@\x80\x84\x015\x90\x83\x01R``\x80\x84\x015\x90\x83\x01R\x90\x84R\x92\x90\x92\x01\x91`\x80\x01a-#V[P\x95\x94PPPPPV[_\x82`\x1F\x83\x01\x12a-\x96W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a-\xAFWa-\xAFa,\x15V[a-\xC2`\x1F\x82\x01`\x1F\x19\x16` \x01a,\x96V[\x81\x81R\x84` \x83\x86\x01\x01\x11\x15a-\xD6W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[_`\xA0\x82\x84\x03\x12\x15a.\x02W__\xFD[a.\na,QV[\x825\x81R` \x80\x84\x015\x90\x82\x01R\x90P`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.2W__\xFD[a.>\x84\x82\x85\x01a,\xC6V[`@\x83\x01RP``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.\\W__\xFD[a.h\x84\x82\x85\x01a,\xC6V[``\x83\x01RP`\x80\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a.\x86W__\xFD[a.\x92\x84\x82\x85\x01a-\x87V[`\x80\x83\x01RP\x92\x91PPV[__`@\x83\x85\x03\x12\x15a.\xAFW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a.\xC4W__\xFD[a.\xD0\x85\x82\x86\x01a-\xF2V[\x95` \x94\x90\x94\x015\x94PPPPV[__`@\x83\x85\x03\x12\x15a.\xF0W__\xFD[\x825a.\xFB\x81a+\xE6V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a/\x15W__\xFD[a/!\x85\x82\x86\x01a-\x87V[\x91PP\x92P\x92\x90PV[__`@\x83\x85\x03\x12\x15a/<W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a/XW__\xFD[a/!\x85\x82\x86\x01a,\xC6V[__` \x83\x85\x03\x12\x15a/uW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a/\x8AW__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a/\x9AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a/\xAFW__\xFD[\x85` \x82`\x05\x1B\x84\x01\x01\x11\x15a/\xC3W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[___`@\x84\x86\x03\x12\x15a/\xE5W__\xFD[\x835a/\xF0\x81a+\xE6V[\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\nW__\xFD[\x84\x01`\x1F\x81\x01\x86\x13a0\x1AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a0/W__\xFD[\x86` \x82\x84\x01\x01\x11\x15a0@W__\xFD[\x93\x96` \x91\x90\x91\x01\x95P\x92\x93PPPV[__`@\x83\x85\x03\x12\x15a0bW__\xFD[PP\x805\x92` \x90\x91\x015\x91PV[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x0E`Wa\x0E`a0qV[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x0E`Wa\x0E`a0qV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[` \x80\x82R\x81\x01\x82\x90R_\x83`@\x83\x01\x82[\x85\x81\x10\x15a-}W\x825a1\x80\x81a+\xE6V[`\x01`\x01`\xA0\x1B\x03\x16\x82R` \x92\x83\x01\x92\x90\x91\x01\x90`\x01\x01a1mV[_` \x82\x84\x03\x12\x15a1\xADW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a1\xC2W__\xFD[a\x0B\xB1\x84\x82\x85\x01a-\xF2V[\x81\x81\x03\x81\x81\x11\x15a\x0E`Wa\x0E`a0qV[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a2NWa2Na2,V[P\x04\x90V[_\x82a2aWa2aa2,V[P\x06\x90V[_` \x82\x84\x03\x12\x15a2vW__\xFD[\x81Qa\x11;\x81a+\xE6V[_` \x82\x84\x03\x12\x15a2\x91W__\xFD[PQ\x91\x90PV[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a2\xFAWa2\xE4\x86\x83Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16\x82R` \x80\x82\x01Q\x90\x83\x01R`@\x80\x82\x01Q\x90\x83\x01R``\x90\x81\x01Q\x91\x01RV[`\x80\x95\x90\x95\x01\x94` \x91\x90\x91\x01\x90`\x01\x01a2\xAAV[P\x93\x94\x93PPPPV[\x82\x81R`@` \x82\x01R_a\x0B\xB1`@\x83\x01\x84a2\x98V[\x80Q`\x01`\x01`P\x1B\x03\x81\x16\x81\x14a32W__\xFD[\x91\x90PV[\x80Qa\xFF\xFF\x81\x16\x81\x14a32W__\xFD[\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a32W__\xFD[\x80Q\x80\x15\x15\x81\x14a32W__\xFD[_a\x01\0\x82\x84\x03\x12\x80\x15a3~W__\xFD[Pa3\x87a,sV[\x82Qa3\x92\x81a+\xE6V[\x81Ra3\xA0` \x84\x01a3\x1CV[` \x82\x01Ra3\xB1`@\x84\x01a37V[`@\x82\x01Ra3\xC2``\x84\x01a3HV[``\x82\x01Ra3\xD3`\x80\x84\x01a3HV[`\x80\x82\x01Ra3\xE4`\xA0\x84\x01a3HV[`\xA0\x82\x01Ra3\xF5`\xC0\x84\x01a3]V[`\xC0\x82\x01Ra4\x06`\xE0\x84\x01a3]V[`\xE0\x82\x01R\x93\x92PPPV[_`\x80\x82\x84\x03\x12\x80\x15a4#W__\xFD[Pa4,a,)V[\x82Qa47\x81a+\xE6V[\x81Ra4E` \x84\x01a3HV[` \x82\x01Ra4V`@\x84\x01a3HV[`@\x82\x01Ra4g``\x84\x01a3]V[``\x82\x01R\x93\x92PPPV[e\xFF\xFF\xFF\xFF\xFF\xFF\x19\x83\x16\x81R`@` \x82\x01R_a\x0B\xB1`@\x83\x01\x84a2\x98V[` \x81R_a\x0E]` \x83\x01\x84a2\x98V[_\x81Q\x80\x84R\x80` \x84\x01` \x86\x01^_` \x82\x86\x01\x01R` `\x1F\x19`\x1F\x83\x01\x16\x85\x01\x01\x91PP\x92\x91PPV[` \x81R`\x01`\x01`@\x1B\x03\x82Q\x16` \x82\x01R_` \x83\x01Q```@\x84\x01Ra5\x02`\x80\x84\x01\x82a4\xA6V[`@\x94\x90\x94\x01Q`\x01`\x01`\xA0\x1B\x03\x16``\x93\x90\x93\x01\x92\x90\x92RP\x90\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x81R_a\x0E]` \x83\x01\x84a4\xA6V\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 ljP8\xEF\x06\x98\xE3\xB9\xDB\x906\xAB\xE2\x17\xB9\xAF\xE89\x08\xF7>\n\x87\x1B\x82\n\xCA\x85\x11\xD9\x85dsolcC\0\x08\x1E\x003",
    );
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Custom error with signature `ACCESS_DENIED()` and selector `0x95383ea1`.
```solidity
error ACCESS_DENIED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ACCESS_DENIED;
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
        impl ::core::convert::From<ACCESS_DENIED> for UnderlyingRustTuple<'_> {
            fn from(value: ACCESS_DENIED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ACCESS_DENIED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ACCESS_DENIED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ACCESS_DENIED()";
            const SELECTOR: [u8; 4] = [149u8, 56u8, 62u8, 161u8];
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
    /**Custom error with signature `BlacklistDelayNotMet()` and selector `0xa282931f`.
```solidity
error BlacklistDelayNotMet();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlacklistDelayNotMet;
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
        impl ::core::convert::From<BlacklistDelayNotMet> for UnderlyingRustTuple<'_> {
            fn from(value: BlacklistDelayNotMet) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlacklistDelayNotMet {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for BlacklistDelayNotMet {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "BlacklistDelayNotMet()";
            const SELECTOR: [u8; 4] = [162u8, 130u8, 147u8, 31u8];
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
    /**Custom error with signature `CommitmentSignerMismatch()` and selector `0x55f7da94`.
```solidity
error CommitmentSignerMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct CommitmentSignerMismatch;
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
        impl ::core::convert::From<CommitmentSignerMismatch>
        for UnderlyingRustTuple<'_> {
            fn from(value: CommitmentSignerMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for CommitmentSignerMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for CommitmentSignerMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "CommitmentSignerMismatch()";
            const SELECTOR: [u8; 4] = [85u8, 247u8, 218u8, 148u8];
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
    /**Custom error with signature `CommitterMismatch()` and selector `0x528cec68`.
```solidity
error CommitterMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct CommitterMismatch;
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
        impl ::core::convert::From<CommitterMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: CommitterMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for CommitterMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for CommitterMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "CommitterMismatch()";
            const SELECTOR: [u8; 4] = [82u8, 140u8, 236u8, 104u8];
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
    /**Custom error with signature `FUNC_NOT_IMPLEMENTED()` and selector `0x18571f1e`.
```solidity
error FUNC_NOT_IMPLEMENTED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct FUNC_NOT_IMPLEMENTED;
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
        impl ::core::convert::From<FUNC_NOT_IMPLEMENTED> for UnderlyingRustTuple<'_> {
            fn from(value: FUNC_NOT_IMPLEMENTED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for FUNC_NOT_IMPLEMENTED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for FUNC_NOT_IMPLEMENTED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "FUNC_NOT_IMPLEMENTED()";
            const SELECTOR: [u8; 4] = [24u8, 87u8, 31u8, 30u8];
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
    /**Custom error with signature `INVALID_PAUSE_STATUS()` and selector `0xbae6e2a9`.
```solidity
error INVALID_PAUSE_STATUS();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct INVALID_PAUSE_STATUS;
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
        impl ::core::convert::From<INVALID_PAUSE_STATUS> for UnderlyingRustTuple<'_> {
            fn from(value: INVALID_PAUSE_STATUS) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for INVALID_PAUSE_STATUS {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for INVALID_PAUSE_STATUS {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "INVALID_PAUSE_STATUS()";
            const SELECTOR: [u8; 4] = [186u8, 230u8, 226u8, 169u8];
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
    /**Custom error with signature `InvalidLookahead()` and selector `0xeaf82a25`.
```solidity
error InvalidLookahead();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidLookahead;
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
        impl ::core::convert::From<InvalidLookahead> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidLookahead) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidLookahead {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidLookahead {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidLookahead()";
            const SELECTOR: [u8; 4] = [234u8, 248u8, 42u8, 37u8];
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
    /**Custom error with signature `InvalidLookaheadEpoch()` and selector `0x96ace79b`.
```solidity
error InvalidLookaheadEpoch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidLookaheadEpoch;
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
        impl ::core::convert::From<InvalidLookaheadEpoch> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidLookaheadEpoch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidLookaheadEpoch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidLookaheadEpoch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidLookaheadEpoch()";
            const SELECTOR: [u8; 4] = [150u8, 172u8, 231u8, 155u8];
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
    /**Custom error with signature `InvalidLookaheadTimestamp()` and selector `0x45cb0af9`.
```solidity
error InvalidLookaheadTimestamp();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidLookaheadTimestamp;
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
        impl ::core::convert::From<InvalidLookaheadTimestamp>
        for UnderlyingRustTuple<'_> {
            fn from(value: InvalidLookaheadTimestamp) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for InvalidLookaheadTimestamp {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidLookaheadTimestamp {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidLookaheadTimestamp()";
            const SELECTOR: [u8; 4] = [69u8, 203u8, 10u8, 249u8];
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
    /**Custom error with signature `InvalidProposer()` and selector `0x4100ac03`.
```solidity
error InvalidProposer();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidProposer;
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
        impl ::core::convert::From<InvalidProposer> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidProposer) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidProposer {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidProposer {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidProposer()";
            const SELECTOR: [u8; 4] = [65u8, 0u8, 172u8, 3u8];
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
    /**Custom error with signature `InvalidSlotIndex()` and selector `0x3628a81b`.
```solidity
error InvalidSlotIndex();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidSlotIndex;
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
        impl ::core::convert::From<InvalidSlotIndex> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidSlotIndex) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidSlotIndex {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidSlotIndex {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidSlotIndex()";
            const SELECTOR: [u8; 4] = [54u8, 40u8, 168u8, 27u8];
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
    /**Custom error with signature `InvalidSlotTimestamp()` and selector `0x971cce8f`.
```solidity
error InvalidSlotTimestamp();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidSlotTimestamp;
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
        impl ::core::convert::From<InvalidSlotTimestamp> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidSlotTimestamp) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidSlotTimestamp {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidSlotTimestamp {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidSlotTimestamp()";
            const SELECTOR: [u8; 4] = [151u8, 28u8, 206u8, 143u8];
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
    /**Custom error with signature `InvalidValidatorLeafIndex()` and selector `0x6016a6f3`.
```solidity
error InvalidValidatorLeafIndex();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidValidatorLeafIndex;
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
        impl ::core::convert::From<InvalidValidatorLeafIndex>
        for UnderlyingRustTuple<'_> {
            fn from(value: InvalidValidatorLeafIndex) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for InvalidValidatorLeafIndex {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidValidatorLeafIndex {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidValidatorLeafIndex()";
            const SELECTOR: [u8; 4] = [96u8, 22u8, 166u8, 243u8];
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
    /**Custom error with signature `LookaheadNotRequired()` and selector `0x351706b4`.
```solidity
error LookaheadNotRequired();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadNotRequired;
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
        impl ::core::convert::From<LookaheadNotRequired> for UnderlyingRustTuple<'_> {
            fn from(value: LookaheadNotRequired) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for LookaheadNotRequired {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for LookaheadNotRequired {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "LookaheadNotRequired()";
            const SELECTOR: [u8; 4] = [53u8, 23u8, 6u8, 180u8];
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
    /**Custom error with signature `NotInbox()` and selector `0x72109f77`.
```solidity
error NotInbox();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct NotInbox;
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
        impl ::core::convert::From<NotInbox> for UnderlyingRustTuple<'_> {
            fn from(value: NotInbox) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for NotInbox {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for NotInbox {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "NotInbox()";
            const SELECTOR: [u8; 4] = [114u8, 16u8, 159u8, 119u8];
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
    /**Custom error with signature `NotOverseer()` and selector `0xac9d87cd`.
```solidity
error NotOverseer();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct NotOverseer;
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
        impl ::core::convert::From<NotOverseer> for UnderlyingRustTuple<'_> {
            fn from(value: NotOverseer) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for NotOverseer {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for NotOverseer {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "NotOverseer()";
            const SELECTOR: [u8; 4] = [172u8, 157u8, 135u8, 205u8];
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
    /**Custom error with signature `OperatorAlreadyBlacklisted()` and selector `0x1996476b`.
```solidity
error OperatorAlreadyBlacklisted();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorAlreadyBlacklisted;
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
        impl ::core::convert::From<OperatorAlreadyBlacklisted>
        for UnderlyingRustTuple<'_> {
            fn from(value: OperatorAlreadyBlacklisted) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for OperatorAlreadyBlacklisted {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorAlreadyBlacklisted {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorAlreadyBlacklisted()";
            const SELECTOR: [u8; 4] = [25u8, 150u8, 71u8, 107u8];
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
    /**Custom error with signature `OperatorHasBeenBlacklisted()` and selector `0xd4c103a2`.
```solidity
error OperatorHasBeenBlacklisted();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasBeenBlacklisted;
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
        impl ::core::convert::From<OperatorHasBeenBlacklisted>
        for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasBeenBlacklisted) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for OperatorHasBeenBlacklisted {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasBeenBlacklisted {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasBeenBlacklisted()";
            const SELECTOR: [u8; 4] = [212u8, 193u8, 3u8, 162u8];
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
    /**Custom error with signature `OperatorHasBeenSlashed()` and selector `0x4c94192f`.
```solidity
error OperatorHasBeenSlashed();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasBeenSlashed;
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
        impl ::core::convert::From<OperatorHasBeenSlashed> for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasBeenSlashed) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OperatorHasBeenSlashed {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasBeenSlashed {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasBeenSlashed()";
            const SELECTOR: [u8; 4] = [76u8, 148u8, 25u8, 47u8];
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
    /**Custom error with signature `OperatorHasInsufficientCollateral()` and selector `0xc41f0d0f`.
```solidity
error OperatorHasInsufficientCollateral();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasInsufficientCollateral;
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
        impl ::core::convert::From<OperatorHasInsufficientCollateral>
        for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasInsufficientCollateral) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for OperatorHasInsufficientCollateral {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasInsufficientCollateral {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasInsufficientCollateral()";
            const SELECTOR: [u8; 4] = [196u8, 31u8, 13u8, 15u8];
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
    /**Custom error with signature `OperatorHasNotOptedIn()` and selector `0xdfcf79b6`.
```solidity
error OperatorHasNotOptedIn();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasNotOptedIn;
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
        impl ::core::convert::From<OperatorHasNotOptedIn> for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasNotOptedIn) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OperatorHasNotOptedIn {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasNotOptedIn {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasNotOptedIn()";
            const SELECTOR: [u8; 4] = [223u8, 207u8, 121u8, 182u8];
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
    /**Custom error with signature `OperatorHasNotRegistered()` and selector `0xd3fc3ff6`.
```solidity
error OperatorHasNotRegistered();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasNotRegistered;
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
        impl ::core::convert::From<OperatorHasNotRegistered>
        for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasNotRegistered) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for OperatorHasNotRegistered {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasNotRegistered {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasNotRegistered()";
            const SELECTOR: [u8; 4] = [211u8, 252u8, 63u8, 246u8];
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
    /**Custom error with signature `OperatorHasUnregistered()` and selector `0xa552ab49`.
```solidity
error OperatorHasUnregistered();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorHasUnregistered;
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
        impl ::core::convert::From<OperatorHasUnregistered> for UnderlyingRustTuple<'_> {
            fn from(value: OperatorHasUnregistered) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OperatorHasUnregistered {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorHasUnregistered {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorHasUnregistered()";
            const SELECTOR: [u8; 4] = [165u8, 82u8, 171u8, 73u8];
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
    /**Custom error with signature `OperatorNotBlacklisted()` and selector `0x0ec11279`.
```solidity
error OperatorNotBlacklisted();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OperatorNotBlacklisted;
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
        impl ::core::convert::From<OperatorNotBlacklisted> for UnderlyingRustTuple<'_> {
            fn from(value: OperatorNotBlacklisted) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OperatorNotBlacklisted {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OperatorNotBlacklisted {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OperatorNotBlacklisted()";
            const SELECTOR: [u8; 4] = [14u8, 193u8, 18u8, 121u8];
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
    /**Custom error with signature `OverseerAlreadyExists()` and selector `0x4461492f`.
```solidity
error OverseerAlreadyExists();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OverseerAlreadyExists;
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
        impl ::core::convert::From<OverseerAlreadyExists> for UnderlyingRustTuple<'_> {
            fn from(value: OverseerAlreadyExists) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OverseerAlreadyExists {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OverseerAlreadyExists {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OverseerAlreadyExists()";
            const SELECTOR: [u8; 4] = [68u8, 97u8, 73u8, 47u8];
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
    /**Custom error with signature `OverseerDoesNotExist()` and selector `0x41d0c737`.
```solidity
error OverseerDoesNotExist();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct OverseerDoesNotExist;
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
        impl ::core::convert::From<OverseerDoesNotExist> for UnderlyingRustTuple<'_> {
            fn from(value: OverseerDoesNotExist) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for OverseerDoesNotExist {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for OverseerDoesNotExist {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "OverseerDoesNotExist()";
            const SELECTOR: [u8; 4] = [65u8, 208u8, 199u8, 55u8];
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
    /**Custom error with signature `ProposerIsNotFallbackPreconfer()` and selector `0x11d9dfd4`.
```solidity
error ProposerIsNotFallbackPreconfer();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposerIsNotFallbackPreconfer;
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
        impl ::core::convert::From<ProposerIsNotFallbackPreconfer>
        for UnderlyingRustTuple<'_> {
            fn from(value: ProposerIsNotFallbackPreconfer) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for ProposerIsNotFallbackPreconfer {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ProposerIsNotFallbackPreconfer {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ProposerIsNotFallbackPreconfer()";
            const SELECTOR: [u8; 4] = [17u8, 217u8, 223u8, 212u8];
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
    /**Custom error with signature `ProposerIsNotPreconfer()` and selector `0x8136641e`.
```solidity
error ProposerIsNotPreconfer();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposerIsNotPreconfer;
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
        impl ::core::convert::From<ProposerIsNotPreconfer> for UnderlyingRustTuple<'_> {
            fn from(value: ProposerIsNotPreconfer) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposerIsNotPreconfer {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ProposerIsNotPreconfer {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ProposerIsNotPreconfer()";
            const SELECTOR: [u8; 4] = [129u8, 54u8, 100u8, 30u8];
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
    /**Custom error with signature `REENTRANT_CALL()` and selector `0xdfc60d85`.
```solidity
error REENTRANT_CALL();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct REENTRANT_CALL;
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
        impl ::core::convert::From<REENTRANT_CALL> for UnderlyingRustTuple<'_> {
            fn from(value: REENTRANT_CALL) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for REENTRANT_CALL {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for REENTRANT_CALL {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "REENTRANT_CALL()";
            const SELECTOR: [u8; 4] = [223u8, 198u8, 13u8, 133u8];
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
    /**Custom error with signature `SlotTimestampIsNotIncrementing()` and selector `0xb8062836`.
```solidity
error SlotTimestampIsNotIncrementing();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SlotTimestampIsNotIncrementing;
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
        impl ::core::convert::From<SlotTimestampIsNotIncrementing>
        for UnderlyingRustTuple<'_> {
            fn from(value: SlotTimestampIsNotIncrementing) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for SlotTimestampIsNotIncrementing {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SlotTimestampIsNotIncrementing {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SlotTimestampIsNotIncrementing()";
            const SELECTOR: [u8; 4] = [184u8, 6u8, 40u8, 54u8];
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
    /**Custom error with signature `UnblacklistDelayNotMet()` and selector `0x99d3faf9`.
```solidity
error UnblacklistDelayNotMet();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct UnblacklistDelayNotMet;
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
        impl ::core::convert::From<UnblacklistDelayNotMet> for UnderlyingRustTuple<'_> {
            fn from(value: UnblacklistDelayNotMet) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for UnblacklistDelayNotMet {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for UnblacklistDelayNotMet {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "UnblacklistDelayNotMet()";
            const SELECTOR: [u8; 4] = [153u8, 211u8, 250u8, 249u8];
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
    /**Custom error with signature `ZERO_ADDRESS()` and selector `0x538ba4f9`.
```solidity
error ZERO_ADDRESS();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ZERO_ADDRESS;
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
        impl ::core::convert::From<ZERO_ADDRESS> for UnderlyingRustTuple<'_> {
            fn from(value: ZERO_ADDRESS) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ZERO_ADDRESS {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ZERO_ADDRESS {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ZERO_ADDRESS()";
            const SELECTOR: [u8; 4] = [83u8, 139u8, 164u8, 249u8];
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
    /**Custom error with signature `ZERO_VALUE()` and selector `0xec732959`.
```solidity
error ZERO_VALUE();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ZERO_VALUE;
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
        impl ::core::convert::From<ZERO_VALUE> for UnderlyingRustTuple<'_> {
            fn from(value: ZERO_VALUE) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ZERO_VALUE {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ZERO_VALUE {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ZERO_VALUE()";
            const SELECTOR: [u8; 4] = [236u8, 115u8, 41u8, 89u8];
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
    /**Event with signature `AdminChanged(address,address)` and selector `0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f`.
```solidity
event AdminChanged(address previousAdmin, address newAdmin);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct AdminChanged {
        #[allow(missing_docs)]
        pub previousAdmin: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub newAdmin: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for AdminChanged {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "AdminChanged(address,address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                126u8, 100u8, 77u8, 121u8, 66u8, 47u8, 23u8, 192u8, 30u8, 72u8, 148u8,
                181u8, 244u8, 245u8, 136u8, 211u8, 49u8, 235u8, 250u8, 40u8, 101u8, 61u8,
                66u8, 174u8, 131u8, 45u8, 197u8, 158u8, 56u8, 201u8, 121u8, 143u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    previousAdmin: data.0,
                    newAdmin: data.1,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.previousAdmin,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.newAdmin,
                    ),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for AdminChanged {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&AdminChanged> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &AdminChanged) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `BeaconUpgraded(address)` and selector `0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e`.
```solidity
event BeaconUpgraded(address indexed beacon);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct BeaconUpgraded {
        #[allow(missing_docs)]
        pub beacon: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for BeaconUpgraded {
            type DataTuple<'a> = ();
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Address,
            );
            const SIGNATURE: &'static str = "BeaconUpgraded(address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                28u8, 243u8, 176u8, 58u8, 108u8, 241u8, 159u8, 162u8, 186u8, 186u8, 77u8,
                241u8, 72u8, 233u8, 220u8, 171u8, 237u8, 234u8, 127u8, 138u8, 92u8, 7u8,
                132u8, 14u8, 32u8, 126u8, 92u8, 8u8, 155u8, 233u8, 93u8, 62u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { beacon: topics.1 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                ()
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.beacon.clone())
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.beacon,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for BeaconUpgraded {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&BeaconUpgraded> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &BeaconUpgraded) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Blacklisted(bytes32,uint48)` and selector `0x1a878b2bf8680c02f7d79c199a61adbe8744e8ccb0f17e36229b619331fa2e13`.
```solidity
event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Blacklisted {
        #[allow(missing_docs)]
        pub operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Blacklisted {
            type DataTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            const SIGNATURE: &'static str = "Blacklisted(bytes32,uint48)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                26u8, 135u8, 139u8, 43u8, 248u8, 104u8, 12u8, 2u8, 247u8, 215u8, 156u8,
                25u8, 154u8, 97u8, 173u8, 190u8, 135u8, 68u8, 232u8, 204u8, 176u8, 241u8,
                126u8, 54u8, 34u8, 155u8, 97u8, 147u8, 49u8, 250u8, 46u8, 19u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    operatorRegistrationRoot: topics.1,
                    timestamp: data.0,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.operatorRegistrationRoot.clone())
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic(
                    &self.operatorRegistrationRoot,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Blacklisted {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Blacklisted> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Blacklisted) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Initialized(uint8)` and selector `0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498`.
```solidity
event Initialized(uint8 version);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Initialized {
        #[allow(missing_docs)]
        pub version: u8,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Initialized {
            type DataTuple<'a> = (alloy::sol_types::sol_data::Uint<8>,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Initialized(uint8)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                127u8, 38u8, 184u8, 63u8, 249u8, 110u8, 31u8, 43u8, 106u8, 104u8, 47u8,
                19u8, 56u8, 82u8, 246u8, 121u8, 138u8, 9u8, 196u8, 101u8, 218u8, 149u8,
                146u8, 20u8, 96u8, 206u8, 251u8, 56u8, 71u8, 64u8, 36u8, 152u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { version: data.0 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.version),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Initialized {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Initialized> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Initialized) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `LookaheadPosted(uint256,bytes32,(address,uint256,bytes32,uint256)[])` and selector `0xae9b6437ad267553afbf07550405458fc43f11f8c50037a3f6b4d7937064cc0a`.
```solidity
event LookaheadPosted(uint256 indexed epochTimestamp, bytes32 lookaheadHash, ILookaheadStore.LookaheadSlot[] lookaheadSlots);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct LookaheadPosted {
        #[allow(missing_docs)]
        pub epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub lookaheadHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub lookaheadSlots: alloy::sol_types::private::Vec<
            <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for LookaheadPosted {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Array<ILookaheadStore::LookaheadSlot>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<256>,
            );
            const SIGNATURE: &'static str = "LookaheadPosted(uint256,bytes32,(address,uint256,bytes32,uint256)[])";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                174u8, 155u8, 100u8, 55u8, 173u8, 38u8, 117u8, 83u8, 175u8, 191u8, 7u8,
                85u8, 4u8, 5u8, 69u8, 143u8, 196u8, 63u8, 17u8, 248u8, 197u8, 0u8, 55u8,
                163u8, 246u8, 180u8, 215u8, 147u8, 112u8, 100u8, 204u8, 10u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    epochTimestamp: topics.1,
                    lookaheadHash: data.0,
                    lookaheadSlots: data.1,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.lookaheadHash),
                    <alloy::sol_types::sol_data::Array<
                        ILookaheadStore::LookaheadSlot,
                    > as alloy_sol_types::SolType>::tokenize(&self.lookaheadSlots),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.epochTimestamp.clone())
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic(&self.epochTimestamp);
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for LookaheadPosted {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&LookaheadPosted> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &LookaheadPosted) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `OverseersAdded(address[])` and selector `0xdae2150d49d9cb1220fb4c279436b69ecffa40b1b64025e396b6be5d830b8134`.
```solidity
event OverseersAdded(address[] overseers);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct OverseersAdded {
        #[allow(missing_docs)]
        pub overseers: alloy::sol_types::private::Vec<
            alloy::sol_types::private::Address,
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for OverseersAdded {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "OverseersAdded(address[])";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                218u8, 226u8, 21u8, 13u8, 73u8, 217u8, 203u8, 18u8, 32u8, 251u8, 76u8,
                39u8, 148u8, 54u8, 182u8, 158u8, 207u8, 250u8, 64u8, 177u8, 182u8, 64u8,
                37u8, 227u8, 150u8, 182u8, 190u8, 93u8, 131u8, 11u8, 129u8, 52u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { overseers: data.0 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::Address,
                    > as alloy_sol_types::SolType>::tokenize(&self.overseers),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for OverseersAdded {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&OverseersAdded> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &OverseersAdded) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `OverseersRemoved(address[])` and selector `0xaec1dfa3221b7c426e6164e08ca6811a59e70d4fc97d7e4efecc7f2f8ac4ba70`.
```solidity
event OverseersRemoved(address[] overseers);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct OverseersRemoved {
        #[allow(missing_docs)]
        pub overseers: alloy::sol_types::private::Vec<
            alloy::sol_types::private::Address,
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for OverseersRemoved {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "OverseersRemoved(address[])";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                174u8, 193u8, 223u8, 163u8, 34u8, 27u8, 124u8, 66u8, 110u8, 97u8, 100u8,
                224u8, 140u8, 166u8, 129u8, 26u8, 89u8, 231u8, 13u8, 79u8, 201u8, 125u8,
                126u8, 78u8, 254u8, 204u8, 127u8, 47u8, 138u8, 196u8, 186u8, 112u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { overseers: data.0 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::Address,
                    > as alloy_sol_types::SolType>::tokenize(&self.overseers),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for OverseersRemoved {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&OverseersRemoved> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &OverseersRemoved) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `OwnershipTransferStarted(address,address)` and selector `0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700`.
```solidity
event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct OwnershipTransferStarted {
        #[allow(missing_docs)]
        pub previousOwner: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub newOwner: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for OwnershipTransferStarted {
            type DataTuple<'a> = ();
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            const SIGNATURE: &'static str = "OwnershipTransferStarted(address,address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                56u8, 209u8, 107u8, 140u8, 172u8, 34u8, 217u8, 159u8, 199u8, 193u8, 36u8,
                185u8, 205u8, 13u8, 226u8, 211u8, 250u8, 31u8, 174u8, 244u8, 32u8, 191u8,
                231u8, 145u8, 216u8, 195u8, 98u8, 215u8, 101u8, 226u8, 39u8, 0u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    previousOwner: topics.1,
                    newOwner: topics.2,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                ()
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (
                    Self::SIGNATURE_HASH.into(),
                    self.previousOwner.clone(),
                    self.newOwner.clone(),
                )
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.previousOwner,
                );
                out[2usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.newOwner,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for OwnershipTransferStarted {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&OwnershipTransferStarted> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(
                this: &OwnershipTransferStarted,
            ) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `OwnershipTransferred(address,address)` and selector `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0`.
```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct OwnershipTransferred {
        #[allow(missing_docs)]
        pub previousOwner: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub newOwner: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for OwnershipTransferred {
            type DataTuple<'a> = ();
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            const SIGNATURE: &'static str = "OwnershipTransferred(address,address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                139u8, 224u8, 7u8, 156u8, 83u8, 22u8, 89u8, 20u8, 19u8, 68u8, 205u8,
                31u8, 208u8, 164u8, 242u8, 132u8, 25u8, 73u8, 127u8, 151u8, 34u8, 163u8,
                218u8, 175u8, 227u8, 180u8, 24u8, 111u8, 107u8, 100u8, 87u8, 224u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    previousOwner: topics.1,
                    newOwner: topics.2,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                ()
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (
                    Self::SIGNATURE_HASH.into(),
                    self.previousOwner.clone(),
                    self.newOwner.clone(),
                )
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.previousOwner,
                );
                out[2usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.newOwner,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for OwnershipTransferred {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&OwnershipTransferred> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &OwnershipTransferred) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Paused(address)` and selector `0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258`.
```solidity
event Paused(address account);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Paused {
        #[allow(missing_docs)]
        pub account: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Paused {
            type DataTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Paused(address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                98u8, 231u8, 140u8, 234u8, 1u8, 190u8, 227u8, 32u8, 205u8, 78u8, 66u8,
                2u8, 112u8, 181u8, 234u8, 116u8, 0u8, 13u8, 17u8, 176u8, 201u8, 247u8,
                71u8, 84u8, 235u8, 219u8, 252u8, 84u8, 75u8, 5u8, 162u8, 88u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { account: data.0 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.account,
                    ),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Paused {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Paused> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Paused) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Unblacklisted(bytes32,uint48)` and selector `0x9682ae3fb79c10948116fe2a224cca9025fb76716477d713dfec766d8bccee17`.
```solidity
event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Unblacklisted {
        #[allow(missing_docs)]
        pub operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Unblacklisted {
            type DataTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            const SIGNATURE: &'static str = "Unblacklisted(bytes32,uint48)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                150u8, 130u8, 174u8, 63u8, 183u8, 156u8, 16u8, 148u8, 129u8, 22u8, 254u8,
                42u8, 34u8, 76u8, 202u8, 144u8, 37u8, 251u8, 118u8, 113u8, 100u8, 119u8,
                215u8, 19u8, 223u8, 236u8, 118u8, 109u8, 139u8, 204u8, 238u8, 23u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    operatorRegistrationRoot: topics.1,
                    timestamp: data.0,
                }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.operatorRegistrationRoot.clone())
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic(
                    &self.operatorRegistrationRoot,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Unblacklisted {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Unblacklisted> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Unblacklisted) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Unpaused(address)` and selector `0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa`.
```solidity
event Unpaused(address account);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Unpaused {
        #[allow(missing_docs)]
        pub account: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Unpaused {
            type DataTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Unpaused(address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                93u8, 185u8, 238u8, 10u8, 73u8, 91u8, 242u8, 230u8, 255u8, 156u8, 145u8,
                167u8, 131u8, 76u8, 27u8, 164u8, 253u8, 210u8, 68u8, 165u8, 232u8, 170u8,
                78u8, 83u8, 123u8, 211u8, 138u8, 234u8, 228u8, 176u8, 115u8, 170u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { account: data.0 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.account,
                    ),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(),)
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Unpaused {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Unpaused> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Unpaused) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Upgraded(address)` and selector `0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b`.
```solidity
event Upgraded(address indexed implementation);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Upgraded {
        #[allow(missing_docs)]
        pub implementation: alloy::sol_types::private::Address,
    }
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for Upgraded {
            type DataTuple<'a> = ();
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Address,
            );
            const SIGNATURE: &'static str = "Upgraded(address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self { implementation: topics.1 }
            }
            #[inline]
            fn check_signature(
                topics: &<Self::TopicList as alloy_sol_types::SolType>::RustType,
            ) -> alloy_sol_types::Result<()> {
                if topics.0 != Self::SIGNATURE_HASH {
                    return Err(
                        alloy_sol_types::Error::invalid_event_signature_hash(
                            Self::SIGNATURE,
                            topics.0,
                            Self::SIGNATURE_HASH,
                        ),
                    );
                }
                Ok(())
            }
            #[inline]
            fn tokenize_body(&self) -> Self::DataToken<'_> {
                ()
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.implementation.clone())
            }
            #[inline]
            fn encode_topics_raw(
                &self,
                out: &mut [alloy_sol_types::abi::token::WordToken],
            ) -> alloy_sol_types::Result<()> {
                if out.len() < <Self::TopicList as alloy_sol_types::TopicList>::COUNT {
                    return Err(alloy_sol_types::Error::Overrun);
                }
                out[0usize] = alloy_sol_types::abi::token::WordToken(
                    Self::SIGNATURE_HASH,
                );
                out[1usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.implementation,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for Upgraded {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Upgraded> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Upgraded) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    /**Constructor`.
```solidity
constructor(address _urc, address _lookaheadSlasher, address _preconfSlasher, address _inbox, address _preconfWhitelist, address[] _overseers);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct constructorCall {
        #[allow(missing_docs)]
        pub _urc: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _lookaheadSlasher: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _preconfSlasher: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _inbox: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _preconfWhitelist: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _overseers: alloy::sol_types::private::Vec<
            alloy::sol_types::private::Address,
        >,
    }
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Vec<alloy::sol_types::private::Address>,
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
            impl ::core::convert::From<constructorCall> for UnderlyingRustTuple<'_> {
                fn from(value: constructorCall) -> Self {
                    (
                        value._urc,
                        value._lookaheadSlasher,
                        value._preconfSlasher,
                        value._inbox,
                        value._preconfWhitelist,
                        value._overseers,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for constructorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _urc: tuple.0,
                        _lookaheadSlasher: tuple.1,
                        _preconfSlasher: tuple.2,
                        _inbox: tuple.3,
                        _preconfWhitelist: tuple.4,
                        _overseers: tuple.5,
                    }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolConstructor for constructorCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._urc,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._lookaheadSlasher,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._preconfSlasher,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._inbox,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._preconfWhitelist,
                    ),
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::Address,
                    > as alloy_sol_types::SolType>::tokenize(&self._overseers),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `acceptOwnership()` and selector `0x79ba5097`.
```solidity
function acceptOwnership() external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct acceptOwnershipCall;
    ///Container type for the return parameters of the [`acceptOwnership()`](acceptOwnershipCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct acceptOwnershipReturn {}
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
            impl ::core::convert::From<acceptOwnershipCall> for UnderlyingRustTuple<'_> {
                fn from(value: acceptOwnershipCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for acceptOwnershipCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
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
            impl ::core::convert::From<acceptOwnershipReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: acceptOwnershipReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for acceptOwnershipReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl acceptOwnershipReturn {
            fn _tokenize(
                &self,
            ) -> <acceptOwnershipCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for acceptOwnershipCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = acceptOwnershipReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "acceptOwnership()";
            const SELECTOR: [u8; 4] = [121u8, 186u8, 80u8, 151u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                acceptOwnershipReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `addOverseers(address[])` and selector `0xa2651bb7`.
```solidity
function addOverseers(address[] memory _overseers) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct addOverseersCall {
        #[allow(missing_docs)]
        pub _overseers: alloy::sol_types::private::Vec<
            alloy::sol_types::private::Address,
        >,
    }
    ///Container type for the return parameters of the [`addOverseers(address[])`](addOverseersCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct addOverseersReturn {}
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
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Vec<alloy::sol_types::private::Address>,
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
            impl ::core::convert::From<addOverseersCall> for UnderlyingRustTuple<'_> {
                fn from(value: addOverseersCall) -> Self {
                    (value._overseers,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for addOverseersCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _overseers: tuple.0 }
                }
            }
        }
        {
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
            impl ::core::convert::From<addOverseersReturn> for UnderlyingRustTuple<'_> {
                fn from(value: addOverseersReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for addOverseersReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl addOverseersReturn {
            fn _tokenize(
                &self,
            ) -> <addOverseersCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for addOverseersCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = addOverseersReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "addOverseers(address[])";
            const SELECTOR: [u8; 4] = [162u8, 101u8, 27u8, 183u8];
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
                        alloy::sol_types::sol_data::Address,
                    > as alloy_sol_types::SolType>::tokenize(&self._overseers),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                addOverseersReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `blacklistOperator(bytes32)` and selector `0x06418f05`.
```solidity
function blacklistOperator(bytes32 _operatorRegistrationRoot) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blacklistOperatorCall {
        #[allow(missing_docs)]
        pub _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    ///Container type for the return parameters of the [`blacklistOperator(bytes32)`](blacklistOperatorCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blacklistOperatorReturn {}
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
            impl ::core::convert::From<blacklistOperatorCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: blacklistOperatorCall) -> Self {
                    (value._operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for blacklistOperatorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
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
            impl ::core::convert::From<blacklistOperatorReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: blacklistOperatorReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for blacklistOperatorReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl blacklistOperatorReturn {
            fn _tokenize(
                &self,
            ) -> <blacklistOperatorCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for blacklistOperatorCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = blacklistOperatorReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "blacklistOperator(bytes32)";
            const SELECTOR: [u8; 4] = [6u8, 65u8, 143u8, 5u8];
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
                    > as alloy_sol_types::SolType>::tokenize(
                        &self._operatorRegistrationRoot,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                blacklistOperatorReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `calculateLookaheadHash(uint256,(address,uint256,bytes32,uint256)[])` and selector `0x72f84a1d`.
```solidity
function calculateLookaheadHash(uint256 _epochTimestamp, ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots) external pure returns (bytes26);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct calculateLookaheadHashCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _lookaheadSlots: alloy::sol_types::private::Vec<
            <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`calculateLookaheadHash(uint256,(address,uint256,bytes32,uint256)[])`](calculateLookaheadHashCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct calculateLookaheadHashReturn {
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
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Array<ILookaheadStore::LookaheadSlot>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
                alloy::sol_types::private::Vec<
                    <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<calculateLookaheadHashCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: calculateLookaheadHashCall) -> Self {
                    (value._epochTimestamp, value._lookaheadSlots)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for calculateLookaheadHashCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _lookaheadSlots: tuple.1,
                    }
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
            impl ::core::convert::From<calculateLookaheadHashReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: calculateLookaheadHashReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for calculateLookaheadHashReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for calculateLookaheadHashCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Array<ILookaheadStore::LookaheadSlot>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<26>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "calculateLookaheadHash(uint256,(address,uint256,bytes32,uint256)[])";
            const SELECTOR: [u8; 4] = [114u8, 248u8, 74u8, 29u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._epochTimestamp),
                    <alloy::sol_types::sol_data::Array<
                        ILookaheadStore::LookaheadSlot,
                    > as alloy_sol_types::SolType>::tokenize(&self._lookaheadSlots),
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
                        let r: calculateLookaheadHashReturn = r.into();
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
                        let r: calculateLookaheadHashReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `checkProposer(address,bytes)` and selector `0xac0004da`.
```solidity
function checkProposer(address _proposer, bytes memory _lookaheadData) external returns (uint48);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct checkProposerCall {
        #[allow(missing_docs)]
        pub _proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _lookaheadData: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`checkProposer(address,bytes)`](checkProposerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct checkProposerReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::primitives::aliases::U48,
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
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Bytes,
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
            impl ::core::convert::From<checkProposerCall> for UnderlyingRustTuple<'_> {
                fn from(value: checkProposerCall) -> Self {
                    (value._proposer, value._lookaheadData)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for checkProposerCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _proposer: tuple.0,
                        _lookaheadData: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
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
            impl ::core::convert::From<checkProposerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: checkProposerReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for checkProposerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for checkProposerCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U48;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "checkProposer(address,bytes)";
            const SELECTOR: [u8; 4] = [172u8, 0u8, 4u8, 218u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._proposer,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._lookaheadData,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: checkProposerReturn = r.into();
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
                        let r: checkProposerReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getBlacklist(bytes32)` and selector `0x9fe786ab`.
```solidity
function getBlacklist(bytes32 operatorRegistrationRoot) external view returns (IBlacklist.BlacklistTimestamps memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistCall {
        #[allow(missing_docs)]
        pub operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBlacklist(bytes32)`](getBlacklistCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistReturn {
        #[allow(missing_docs)]
        pub _0: <IBlacklist::BlacklistTimestamps as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlacklistCall> for UnderlyingRustTuple<'_> {
                fn from(value: getBlacklistCall) -> Self {
                    (value.operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlacklistCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IBlacklist::BlacklistTimestamps,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IBlacklist::BlacklistTimestamps as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlacklistReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getBlacklistReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlacklistReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBlacklistCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IBlacklist::BlacklistTimestamps as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IBlacklist::BlacklistTimestamps,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBlacklist(bytes32)";
            const SELECTOR: [u8; 4] = [159u8, 231u8, 134u8, 171u8];
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
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.operatorRegistrationRoot,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <IBlacklist::BlacklistTimestamps as alloy_sol_types::SolType>::tokenize(
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
                        let r: getBlacklistReturn = r.into();
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
                        let r: getBlacklistReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getBlacklistConfig()` and selector `0x937aaa9b`.
```solidity
function getBlacklistConfig() external pure returns (IBlacklist.BlacklistConfig memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistConfigCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBlacklistConfig()`](getBlacklistConfigCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistConfigReturn {
        #[allow(missing_docs)]
        pub _0: <IBlacklist::BlacklistConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlacklistConfigCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getBlacklistConfigCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getBlacklistConfigCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (IBlacklist::BlacklistConfig,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IBlacklist::BlacklistConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlacklistConfigReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getBlacklistConfigReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getBlacklistConfigReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBlacklistConfigCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <IBlacklist::BlacklistConfig as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (IBlacklist::BlacklistConfig,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBlacklistConfig()";
            const SELECTOR: [u8; 4] = [147u8, 122u8, 170u8, 155u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <IBlacklist::BlacklistConfig as alloy_sol_types::SolType>::tokenize(
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
                        let r: getBlacklistConfigReturn = r.into();
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
                        let r: getBlacklistConfigReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getLookaheadHash(uint256)` and selector `0xae41501a`.
```solidity
function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26 hash_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getLookaheadHashCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getLookaheadHash(uint256)`](getLookaheadHashCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getLookaheadHashReturn {
        #[allow(missing_docs)]
        pub hash_: alloy::sol_types::private::FixedBytes<26>,
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<getLookaheadHashCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getLookaheadHashCall) -> Self {
                    (value._epochTimestamp,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getLookaheadHashCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _epochTimestamp: tuple.0 }
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
            impl ::core::convert::From<getLookaheadHashReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getLookaheadHashReturn) -> Self {
                    (value.hash_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getLookaheadHashReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { hash_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getLookaheadHashCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<26>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getLookaheadHash(uint256)";
            const SELECTOR: [u8; 4] = [174u8, 65u8, 80u8, 26u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._epochTimestamp),
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
                        let r: getLookaheadHashReturn = r.into();
                        r.hash_
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
                        let r: getLookaheadHashReturn = r.into();
                        r.hash_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getLookaheadStoreConfig()` and selector `0xfd527be8`.
```solidity
function getLookaheadStoreConfig() external pure returns (ILookaheadStore.LookaheadStoreConfig memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getLookaheadStoreConfigCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getLookaheadStoreConfig()`](getLookaheadStoreConfigCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getLookaheadStoreConfigReturn {
        #[allow(missing_docs)]
        pub _0: <ILookaheadStore::LookaheadStoreConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getLookaheadStoreConfigCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getLookaheadStoreConfigCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getLookaheadStoreConfigCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ILookaheadStore::LookaheadStoreConfig,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ILookaheadStore::LookaheadStoreConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getLookaheadStoreConfigReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getLookaheadStoreConfigReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getLookaheadStoreConfigReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getLookaheadStoreConfigCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ILookaheadStore::LookaheadStoreConfig as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ILookaheadStore::LookaheadStoreConfig,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getLookaheadStoreConfig()";
            const SELECTOR: [u8; 4] = [253u8, 82u8, 123u8, 232u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <ILookaheadStore::LookaheadStoreConfig as alloy_sol_types::SolType>::tokenize(
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
                        let r: getLookaheadStoreConfigReturn = r.into();
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
                        let r: getLookaheadStoreConfigReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `getProposerContext((uint256,bytes32,(address,uint256,bytes32,uint256)[],(address,uint256,bytes32,uint256)[],bytes),uint256)` and selector `0x312bcde3`.
```solidity
function getProposerContext(ILookaheadStore.LookaheadData memory _data, uint256 _epochTimestamp) external view returns (ILookaheadStore.ProposerContext memory context_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getProposerContextCall {
        #[allow(missing_docs)]
        pub _data: <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`getProposerContext((uint256,bytes32,(address,uint256,bytes32,uint256)[],(address,uint256,bytes32,uint256)[],bytes),uint256)`](getProposerContextCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getProposerContextReturn {
        #[allow(missing_docs)]
        pub context_: <ILookaheadStore::ProposerContext as alloy::sol_types::SolType>::RustType,
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
                ILookaheadStore::LookaheadData,
                alloy::sol_types::sol_data::Uint<256>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<getProposerContextCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getProposerContextCall) -> Self {
                    (value._data, value._epochTimestamp)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getProposerContextCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _data: tuple.0,
                        _epochTimestamp: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ILookaheadStore::ProposerContext,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ILookaheadStore::ProposerContext as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getProposerContextReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getProposerContextReturn) -> Self {
                    (value.context_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getProposerContextReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { context_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getProposerContextCall {
            type Parameters<'a> = (
                ILookaheadStore::LookaheadData,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ILookaheadStore::ProposerContext as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ILookaheadStore::ProposerContext,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getProposerContext((uint256,bytes32,(address,uint256,bytes32,uint256)[],(address,uint256,bytes32,uint256)[],bytes),uint256)";
            const SELECTOR: [u8; 4] = [49u8, 43u8, 205u8, 227u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <ILookaheadStore::LookaheadData as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._epochTimestamp),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <ILookaheadStore::ProposerContext as alloy_sol_types::SolType>::tokenize(
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
                        let r: getProposerContextReturn = r.into();
                        r.context_
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
                        let r: getProposerContextReturn = r.into();
                        r.context_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `impl()` and selector `0x8abf6077`.
```solidity
function r#impl() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct implCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`impl()`](implCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct implReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<implCall> for UnderlyingRustTuple<'_> {
                fn from(value: implCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for implCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<implReturn> for UnderlyingRustTuple<'_> {
                fn from(value: implReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for implReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for implCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "impl()";
            const SELECTOR: [u8; 4] = [138u8, 191u8, 96u8, 119u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: implReturn = r.into();
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
                        let r: implReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `inNonReentrant()` and selector `0x3075db56`.
```solidity
function inNonReentrant() external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct inNonReentrantCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`inNonReentrant()`](inNonReentrantCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct inNonReentrantReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
            impl ::core::convert::From<inNonReentrantCall> for UnderlyingRustTuple<'_> {
                fn from(value: inNonReentrantCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for inNonReentrantCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<inNonReentrantReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: inNonReentrantReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for inNonReentrantReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for inNonReentrantCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "inNonReentrant()";
            const SELECTOR: [u8; 4] = [48u8, 117u8, 219u8, 86u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: inNonReentrantReturn = r.into();
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
                        let r: inNonReentrantReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `inbox()` and selector `0xfb0e722b`.
```solidity
function inbox() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct inboxCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`inbox()`](inboxCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct inboxReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<inboxCall> for UnderlyingRustTuple<'_> {
                fn from(value: inboxCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for inboxCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<inboxReturn> for UnderlyingRustTuple<'_> {
                fn from(value: inboxReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for inboxReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for inboxCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "inbox()";
            const SELECTOR: [u8; 4] = [251u8, 14u8, 114u8, 43u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: inboxReturn = r.into();
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
                        let r: inboxReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `init(address)` and selector `0x19ab453c`.
```solidity
function init(address _owner) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct initCall {
        #[allow(missing_docs)]
        pub _owner: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`init(address)`](initCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct initReturn {}
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<initCall> for UnderlyingRustTuple<'_> {
                fn from(value: initCall) -> Self {
                    (value._owner,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for initCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _owner: tuple.0 }
                }
            }
        }
        {
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
            impl ::core::convert::From<initReturn> for UnderlyingRustTuple<'_> {
                fn from(value: initReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for initReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl initReturn {
            fn _tokenize(
                &self,
            ) -> <initCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for initCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Address,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = initReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "init(address)";
            const SELECTOR: [u8; 4] = [25u8, 171u8, 69u8, 60u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._owner,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                initReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isLookaheadOperatorValid(uint256,bytes32)` and selector `0xd3cbd83e`.
```solidity
function isLookaheadOperatorValid(uint256 _epochTimestamp, bytes32 _registrationRoot) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadOperatorValidCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isLookaheadOperatorValid(uint256,bytes32)`](isLookaheadOperatorValidCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadOperatorValidReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<isLookaheadOperatorValidCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadOperatorValidCall) -> Self {
                    (value._epochTimestamp, value._registrationRoot)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadOperatorValidCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _registrationRoot: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<isLookaheadOperatorValidReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadOperatorValidReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadOperatorValidReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isLookaheadOperatorValidCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isLookaheadOperatorValid(uint256,bytes32)";
            const SELECTOR: [u8; 4] = [211u8, 203u8, 216u8, 62u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._epochTimestamp),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._registrationRoot),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: isLookaheadOperatorValidReturn = r.into();
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
                        let r: isLookaheadOperatorValidReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isLookaheadPosterValid(uint256,bytes32)` and selector `0xe4689d64`.
```solidity
function isLookaheadPosterValid(uint256 _epochTimestamp, bytes32 _registrationRoot) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadPosterValidCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isLookaheadPosterValid(uint256,bytes32)`](isLookaheadPosterValidCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadPosterValidReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<isLookaheadPosterValidCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadPosterValidCall) -> Self {
                    (value._epochTimestamp, value._registrationRoot)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadPosterValidCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _registrationRoot: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<isLookaheadPosterValidReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadPosterValidReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadPosterValidReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isLookaheadPosterValidCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isLookaheadPosterValid(uint256,bytes32)";
            const SELECTOR: [u8; 4] = [228u8, 104u8, 157u8, 100u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._epochTimestamp),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._registrationRoot),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: isLookaheadPosterValidReturn = r.into();
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
                        let r: isLookaheadPosterValidReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isLookaheadRequired()` and selector `0x23c0b1ab`.
```solidity
function isLookaheadRequired() external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadRequiredCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isLookaheadRequired()`](isLookaheadRequiredCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isLookaheadRequiredReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
            impl ::core::convert::From<isLookaheadRequiredCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadRequiredCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadRequiredCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<isLookaheadRequiredReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: isLookaheadRequiredReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isLookaheadRequiredReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isLookaheadRequiredCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isLookaheadRequired()";
            const SELECTOR: [u8; 4] = [35u8, 192u8, 177u8, 171u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: isLookaheadRequiredReturn = r.into();
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
                        let r: isLookaheadRequiredReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isOperatorBlacklisted(bytes32)` and selector `0xfd40a5fe`.
```solidity
function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isOperatorBlacklistedCall {
        #[allow(missing_docs)]
        pub operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isOperatorBlacklisted(bytes32)`](isOperatorBlacklistedCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isOperatorBlacklistedReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
            impl ::core::convert::From<isOperatorBlacklistedCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: isOperatorBlacklistedCall) -> Self {
                    (value.operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isOperatorBlacklistedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<isOperatorBlacklistedReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: isOperatorBlacklistedReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isOperatorBlacklistedReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isOperatorBlacklistedCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isOperatorBlacklisted(bytes32)";
            const SELECTOR: [u8; 4] = [253u8, 64u8, 165u8, 254u8];
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
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.operatorRegistrationRoot,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: isOperatorBlacklistedReturn = r.into();
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
                        let r: isOperatorBlacklistedReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `lookahead(uint256)` and selector `0xa486e0dd`.
```solidity
function lookahead(uint256 epochTimestamp_mod_lookaheadBufferSize) external view returns (uint48 epochTimestamp, bytes26 lookaheadHash);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lookaheadCall {
        #[allow(missing_docs)]
        pub epochTimestamp_mod_lookaheadBufferSize: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`lookahead(uint256)`](lookaheadCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lookaheadReturn {
        #[allow(missing_docs)]
        pub epochTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub lookaheadHash: alloy::sol_types::private::FixedBytes<26>,
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<lookaheadCall> for UnderlyingRustTuple<'_> {
                fn from(value: lookaheadCall) -> Self {
                    (value.epochTimestamp_mod_lookaheadBufferSize,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for lookaheadCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        epochTimestamp_mod_lookaheadBufferSize: tuple.0,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<26>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::FixedBytes<26>,
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
            impl ::core::convert::From<lookaheadReturn> for UnderlyingRustTuple<'_> {
                fn from(value: lookaheadReturn) -> Self {
                    (value.epochTimestamp, value.lookaheadHash)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for lookaheadReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        epochTimestamp: tuple.0,
                        lookaheadHash: tuple.1,
                    }
                }
            }
        }
        impl lookaheadReturn {
            fn _tokenize(
                &self,
            ) -> <lookaheadCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.epochTimestamp),
                    <alloy::sol_types::sol_data::FixedBytes<
                        26,
                    > as alloy_sol_types::SolType>::tokenize(&self.lookaheadHash),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for lookaheadCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = lookaheadReturn;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<26>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "lookahead(uint256)";
            const SELECTOR: [u8; 4] = [164u8, 134u8, 224u8, 221u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.epochTimestamp_mod_lookaheadBufferSize,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                lookaheadReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `lookaheadSlasher()` and selector `0x5bf4ea85`.
```solidity
function lookaheadSlasher() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lookaheadSlasherCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`lookaheadSlasher()`](lookaheadSlasherCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lookaheadSlasherReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<lookaheadSlasherCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: lookaheadSlasherCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for lookaheadSlasherCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<lookaheadSlasherReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: lookaheadSlasherReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for lookaheadSlasherReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for lookaheadSlasherCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "lookaheadSlasher()";
            const SELECTOR: [u8; 4] = [91u8, 244u8, 234u8, 133u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: lookaheadSlasherReturn = r.into();
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
                        let r: lookaheadSlasherReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `overseers(address)` and selector `0xf1c27dad`.
```solidity
function overseers(address overseer) external view returns (bool isOverseer);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct overseersCall {
        #[allow(missing_docs)]
        pub overseer: alloy::sol_types::private::Address,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`overseers(address)`](overseersCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct overseersReturn {
        #[allow(missing_docs)]
        pub isOverseer: bool,
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<overseersCall> for UnderlyingRustTuple<'_> {
                fn from(value: overseersCall) -> Self {
                    (value.overseer,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for overseersCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { overseer: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<overseersReturn> for UnderlyingRustTuple<'_> {
                fn from(value: overseersReturn) -> Self {
                    (value.isOverseer,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for overseersReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { isOverseer: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for overseersCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Address,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "overseers(address)";
            const SELECTOR: [u8; 4] = [241u8, 194u8, 125u8, 173u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.overseer,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: overseersReturn = r.into();
                        r.isOverseer
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
                        let r: overseersReturn = r.into();
                        r.isOverseer
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `owner()` and selector `0x8da5cb5b`.
```solidity
function owner() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ownerCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`owner()`](ownerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ownerReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<ownerCall> for UnderlyingRustTuple<'_> {
                fn from(value: ownerCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for ownerCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<ownerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: ownerReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for ownerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for ownerCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "owner()";
            const SELECTOR: [u8; 4] = [141u8, 165u8, 203u8, 91u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: ownerReturn = r.into();
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
                        let r: ownerReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `pause()` and selector `0x8456cb59`.
```solidity
function pause() external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pauseCall;
    ///Container type for the return parameters of the [`pause()`](pauseCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pauseReturn {}
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
            impl ::core::convert::From<pauseCall> for UnderlyingRustTuple<'_> {
                fn from(value: pauseCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pauseCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
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
            impl ::core::convert::From<pauseReturn> for UnderlyingRustTuple<'_> {
                fn from(value: pauseReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pauseReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl pauseReturn {
            fn _tokenize(
                &self,
            ) -> <pauseCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for pauseCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = pauseReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "pause()";
            const SELECTOR: [u8; 4] = [132u8, 86u8, 203u8, 89u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                pauseReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `paused()` and selector `0x5c975abb`.
```solidity
function paused() external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pausedCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`paused()`](pausedCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pausedReturn {
        #[allow(missing_docs)]
        pub _0: bool,
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
            impl ::core::convert::From<pausedCall> for UnderlyingRustTuple<'_> {
                fn from(value: pausedCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pausedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (bool,);
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
            impl ::core::convert::From<pausedReturn> for UnderlyingRustTuple<'_> {
                fn from(value: pausedReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pausedReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for pausedCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "paused()";
            const SELECTOR: [u8; 4] = [92u8, 151u8, 90u8, 187u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
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
                        let r: pausedReturn = r.into();
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
                        let r: pausedReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `pendingOwner()` and selector `0xe30c3978`.
```solidity
function pendingOwner() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pendingOwnerCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`pendingOwner()`](pendingOwnerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pendingOwnerReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<pendingOwnerCall> for UnderlyingRustTuple<'_> {
                fn from(value: pendingOwnerCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pendingOwnerCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<pendingOwnerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: pendingOwnerReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pendingOwnerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for pendingOwnerCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "pendingOwner()";
            const SELECTOR: [u8; 4] = [227u8, 12u8, 57u8, 120u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: pendingOwnerReturn = r.into();
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
                        let r: pendingOwnerReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `preconfSlasher()` and selector `0xe45f2fc3`.
```solidity
function preconfSlasher() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfSlasherCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`preconfSlasher()`](preconfSlasherCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfSlasherReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<preconfSlasherCall> for UnderlyingRustTuple<'_> {
                fn from(value: preconfSlasherCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for preconfSlasherCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<preconfSlasherReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: preconfSlasherReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for preconfSlasherReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for preconfSlasherCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "preconfSlasher()";
            const SELECTOR: [u8; 4] = [228u8, 95u8, 47u8, 195u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: preconfSlasherReturn = r.into();
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
                        let r: preconfSlasherReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `preconfWhitelist()` and selector `0xd91f24f1`.
```solidity
function preconfWhitelist() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfWhitelistCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`preconfWhitelist()`](preconfWhitelistCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfWhitelistReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<preconfWhitelistCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: preconfWhitelistCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for preconfWhitelistCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<preconfWhitelistReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: preconfWhitelistReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for preconfWhitelistReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for preconfWhitelistCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "preconfWhitelist()";
            const SELECTOR: [u8; 4] = [217u8, 31u8, 36u8, 241u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: preconfWhitelistReturn = r.into();
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
                        let r: preconfWhitelistReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `proxiableUUID()` and selector `0x52d1902d`.
```solidity
function proxiableUUID() external view returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct proxiableUUIDCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`proxiableUUID()`](proxiableUUIDCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct proxiableUUIDReturn {
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
            impl ::core::convert::From<proxiableUUIDCall> for UnderlyingRustTuple<'_> {
                fn from(value: proxiableUUIDCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for proxiableUUIDCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
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
            impl ::core::convert::From<proxiableUUIDReturn> for UnderlyingRustTuple<'_> {
                fn from(value: proxiableUUIDReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for proxiableUUIDReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for proxiableUUIDCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "proxiableUUID()";
            const SELECTOR: [u8; 4] = [82u8, 209u8, 144u8, 45u8];
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
                        let r: proxiableUUIDReturn = r.into();
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
                        let r: proxiableUUIDReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `removeOverseers(address[])` and selector `0xb44b2d52`.
```solidity
function removeOverseers(address[] memory _overseers) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct removeOverseersCall {
        #[allow(missing_docs)]
        pub _overseers: alloy::sol_types::private::Vec<
            alloy::sol_types::private::Address,
        >,
    }
    ///Container type for the return parameters of the [`removeOverseers(address[])`](removeOverseersCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct removeOverseersReturn {}
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
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Vec<alloy::sol_types::private::Address>,
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
            impl ::core::convert::From<removeOverseersCall> for UnderlyingRustTuple<'_> {
                fn from(value: removeOverseersCall) -> Self {
                    (value._overseers,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for removeOverseersCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _overseers: tuple.0 }
                }
            }
        }
        {
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
            impl ::core::convert::From<removeOverseersReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: removeOverseersReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for removeOverseersReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl removeOverseersReturn {
            fn _tokenize(
                &self,
            ) -> <removeOverseersCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for removeOverseersCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Array<alloy::sol_types::sol_data::Address>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = removeOverseersReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "removeOverseers(address[])";
            const SELECTOR: [u8; 4] = [180u8, 75u8, 45u8, 82u8];
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
                        alloy::sol_types::sol_data::Address,
                    > as alloy_sol_types::SolType>::tokenize(&self._overseers),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                removeOverseersReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `renounceOwnership()` and selector `0x715018a6`.
```solidity
function renounceOwnership() external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct renounceOwnershipCall;
    ///Container type for the return parameters of the [`renounceOwnership()`](renounceOwnershipCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct renounceOwnershipReturn {}
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
            impl ::core::convert::From<renounceOwnershipCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: renounceOwnershipCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for renounceOwnershipCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
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
            impl ::core::convert::From<renounceOwnershipReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: renounceOwnershipReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for renounceOwnershipReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl renounceOwnershipReturn {
            fn _tokenize(
                &self,
            ) -> <renounceOwnershipCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for renounceOwnershipCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = renounceOwnershipReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "renounceOwnership()";
            const SELECTOR: [u8; 4] = [113u8, 80u8, 24u8, 166u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                renounceOwnershipReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `resolver()` and selector `0x04f3bcec`.
```solidity
function resolver() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct resolverCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`resolver()`](resolverCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct resolverReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<resolverCall> for UnderlyingRustTuple<'_> {
                fn from(value: resolverCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for resolverCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<resolverReturn> for UnderlyingRustTuple<'_> {
                fn from(value: resolverReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for resolverReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for resolverCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "resolver()";
            const SELECTOR: [u8; 4] = [4u8, 243u8, 188u8, 236u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: resolverReturn = r.into();
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
                        let r: resolverReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `transferOwnership(address)` and selector `0xf2fde38b`.
```solidity
function transferOwnership(address newOwner) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct transferOwnershipCall {
        #[allow(missing_docs)]
        pub newOwner: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`transferOwnership(address)`](transferOwnershipCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct transferOwnershipReturn {}
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<transferOwnershipCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: transferOwnershipCall) -> Self {
                    (value.newOwner,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for transferOwnershipCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { newOwner: tuple.0 }
                }
            }
        }
        {
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
            impl ::core::convert::From<transferOwnershipReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: transferOwnershipReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for transferOwnershipReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl transferOwnershipReturn {
            fn _tokenize(
                &self,
            ) -> <transferOwnershipCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for transferOwnershipCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Address,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = transferOwnershipReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "transferOwnership(address)";
            const SELECTOR: [u8; 4] = [242u8, 253u8, 227u8, 139u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.newOwner,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                transferOwnershipReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `unblacklistOperator(bytes32)` and selector `0xcc809990`.
```solidity
function unblacklistOperator(bytes32 _operatorRegistrationRoot) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct unblacklistOperatorCall {
        #[allow(missing_docs)]
        pub _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    ///Container type for the return parameters of the [`unblacklistOperator(bytes32)`](unblacklistOperatorCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct unblacklistOperatorReturn {}
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
            impl ::core::convert::From<unblacklistOperatorCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: unblacklistOperatorCall) -> Self {
                    (value._operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for unblacklistOperatorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
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
            impl ::core::convert::From<unblacklistOperatorReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: unblacklistOperatorReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for unblacklistOperatorReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl unblacklistOperatorReturn {
            fn _tokenize(
                &self,
            ) -> <unblacklistOperatorCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for unblacklistOperatorCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = unblacklistOperatorReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "unblacklistOperator(bytes32)";
            const SELECTOR: [u8; 4] = [204u8, 128u8, 153u8, 144u8];
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
                    > as alloy_sol_types::SolType>::tokenize(
                        &self._operatorRegistrationRoot,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                unblacklistOperatorReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `unpause()` and selector `0x3f4ba83a`.
```solidity
function unpause() external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct unpauseCall;
    ///Container type for the return parameters of the [`unpause()`](unpauseCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct unpauseReturn {}
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
            impl ::core::convert::From<unpauseCall> for UnderlyingRustTuple<'_> {
                fn from(value: unpauseCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for unpauseCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
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
            impl ::core::convert::From<unpauseReturn> for UnderlyingRustTuple<'_> {
                fn from(value: unpauseReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for unpauseReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl unpauseReturn {
            fn _tokenize(
                &self,
            ) -> <unpauseCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for unpauseCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = unpauseReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "unpause()";
            const SELECTOR: [u8; 4] = [63u8, 75u8, 168u8, 58u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                unpauseReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `upgradeTo(address)` and selector `0x3659cfe6`.
```solidity
function upgradeTo(address newImplementation) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct upgradeToCall {
        #[allow(missing_docs)]
        pub newImplementation: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`upgradeTo(address)`](upgradeToCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct upgradeToReturn {}
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
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<upgradeToCall> for UnderlyingRustTuple<'_> {
                fn from(value: upgradeToCall) -> Self {
                    (value.newImplementation,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for upgradeToCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { newImplementation: tuple.0 }
                }
            }
        }
        {
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
            impl ::core::convert::From<upgradeToReturn> for UnderlyingRustTuple<'_> {
                fn from(value: upgradeToReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for upgradeToReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl upgradeToReturn {
            fn _tokenize(
                &self,
            ) -> <upgradeToCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for upgradeToCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Address,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = upgradeToReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "upgradeTo(address)";
            const SELECTOR: [u8; 4] = [54u8, 89u8, 207u8, 230u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.newImplementation,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                upgradeToReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `upgradeToAndCall(address,bytes)` and selector `0x4f1ef286`.
```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct upgradeToAndCallCall {
        #[allow(missing_docs)]
        pub newImplementation: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub data: alloy::sol_types::private::Bytes,
    }
    ///Container type for the return parameters of the [`upgradeToAndCall(address,bytes)`](upgradeToAndCallCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct upgradeToAndCallReturn {}
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
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Bytes,
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
            impl ::core::convert::From<upgradeToAndCallCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: upgradeToAndCallCall) -> Self {
                    (value.newImplementation, value.data)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for upgradeToAndCallCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        newImplementation: tuple.0,
                        data: tuple.1,
                    }
                }
            }
        }
        {
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
            impl ::core::convert::From<upgradeToAndCallReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: upgradeToAndCallReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for upgradeToAndCallReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl upgradeToAndCallReturn {
            fn _tokenize(
                &self,
            ) -> <upgradeToAndCallCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for upgradeToAndCallCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = upgradeToAndCallReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "upgradeToAndCall(address,bytes)";
            const SELECTOR: [u8; 4] = [79u8, 30u8, 242u8, 134u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.newImplementation,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.data,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                upgradeToAndCallReturn::_tokenize(ret)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(Into::into)
            }
            #[inline]
            fn abi_decode_returns_validate(
                data: &[u8],
            ) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence_validate(data)
                    .map(Into::into)
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `urc()` and selector `0x5ddc9e8d`.
```solidity
function urc() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct urcCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`urc()`](urcCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct urcReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Address,
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
            impl ::core::convert::From<urcCall> for UnderlyingRustTuple<'_> {
                fn from(value: urcCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for urcCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Address,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (alloy::sol_types::private::Address,);
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
            impl ::core::convert::From<urcReturn> for UnderlyingRustTuple<'_> {
                fn from(value: urcReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for urcReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for urcCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "urc()";
            const SELECTOR: [u8; 4] = [93u8, 220u8, 158u8, 141u8];
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
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
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
                        let r: urcReturn = r.into();
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
                        let r: urcReturn = r.into();
                        r._0
                    })
            }
        }
    };
    ///Container for all the [`LookaheadStore`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum LookaheadStoreCalls {
        #[allow(missing_docs)]
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        addOverseers(addOverseersCall),
        #[allow(missing_docs)]
        blacklistOperator(blacklistOperatorCall),
        #[allow(missing_docs)]
        calculateLookaheadHash(calculateLookaheadHashCall),
        #[allow(missing_docs)]
        checkProposer(checkProposerCall),
        #[allow(missing_docs)]
        getBlacklist(getBlacklistCall),
        #[allow(missing_docs)]
        getBlacklistConfig(getBlacklistConfigCall),
        #[allow(missing_docs)]
        getLookaheadHash(getLookaheadHashCall),
        #[allow(missing_docs)]
        getLookaheadStoreConfig(getLookaheadStoreConfigCall),
        #[allow(missing_docs)]
        getProposerContext(getProposerContextCall),
        #[allow(missing_docs)]
        r#impl(implCall),
        #[allow(missing_docs)]
        inNonReentrant(inNonReentrantCall),
        #[allow(missing_docs)]
        inbox(inboxCall),
        #[allow(missing_docs)]
        init(initCall),
        #[allow(missing_docs)]
        isLookaheadOperatorValid(isLookaheadOperatorValidCall),
        #[allow(missing_docs)]
        isLookaheadPosterValid(isLookaheadPosterValidCall),
        #[allow(missing_docs)]
        isLookaheadRequired(isLookaheadRequiredCall),
        #[allow(missing_docs)]
        isOperatorBlacklisted(isOperatorBlacklistedCall),
        #[allow(missing_docs)]
        lookahead(lookaheadCall),
        #[allow(missing_docs)]
        lookaheadSlasher(lookaheadSlasherCall),
        #[allow(missing_docs)]
        overseers(overseersCall),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pause(pauseCall),
        #[allow(missing_docs)]
        paused(pausedCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        preconfSlasher(preconfSlasherCall),
        #[allow(missing_docs)]
        preconfWhitelist(preconfWhitelistCall),
        #[allow(missing_docs)]
        proxiableUUID(proxiableUUIDCall),
        #[allow(missing_docs)]
        removeOverseers(removeOverseersCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        resolver(resolverCall),
        #[allow(missing_docs)]
        transferOwnership(transferOwnershipCall),
        #[allow(missing_docs)]
        unblacklistOperator(unblacklistOperatorCall),
        #[allow(missing_docs)]
        unpause(unpauseCall),
        #[allow(missing_docs)]
        upgradeTo(upgradeToCall),
        #[allow(missing_docs)]
        upgradeToAndCall(upgradeToAndCallCall),
        #[allow(missing_docs)]
        urc(urcCall),
    }
    #[automatically_derived]
    impl LookaheadStoreCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [4u8, 243u8, 188u8, 236u8],
            [6u8, 65u8, 143u8, 5u8],
            [25u8, 171u8, 69u8, 60u8],
            [35u8, 192u8, 177u8, 171u8],
            [48u8, 117u8, 219u8, 86u8],
            [49u8, 43u8, 205u8, 227u8],
            [54u8, 89u8, 207u8, 230u8],
            [63u8, 75u8, 168u8, 58u8],
            [79u8, 30u8, 242u8, 134u8],
            [82u8, 209u8, 144u8, 45u8],
            [91u8, 244u8, 234u8, 133u8],
            [92u8, 151u8, 90u8, 187u8],
            [93u8, 220u8, 158u8, 141u8],
            [113u8, 80u8, 24u8, 166u8],
            [114u8, 248u8, 74u8, 29u8],
            [121u8, 186u8, 80u8, 151u8],
            [132u8, 86u8, 203u8, 89u8],
            [138u8, 191u8, 96u8, 119u8],
            [141u8, 165u8, 203u8, 91u8],
            [147u8, 122u8, 170u8, 155u8],
            [159u8, 231u8, 134u8, 171u8],
            [162u8, 101u8, 27u8, 183u8],
            [164u8, 134u8, 224u8, 221u8],
            [172u8, 0u8, 4u8, 218u8],
            [174u8, 65u8, 80u8, 26u8],
            [180u8, 75u8, 45u8, 82u8],
            [204u8, 128u8, 153u8, 144u8],
            [211u8, 203u8, 216u8, 62u8],
            [217u8, 31u8, 36u8, 241u8],
            [227u8, 12u8, 57u8, 120u8],
            [228u8, 95u8, 47u8, 195u8],
            [228u8, 104u8, 157u8, 100u8],
            [241u8, 194u8, 125u8, 173u8],
            [242u8, 253u8, 227u8, 139u8],
            [251u8, 14u8, 114u8, 43u8],
            [253u8, 64u8, 165u8, 254u8],
            [253u8, 82u8, 123u8, 232u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for LookaheadStoreCalls {
        const NAME: &'static str = "LookaheadStoreCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 37usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::addOverseers(_) => {
                    <addOverseersCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::blacklistOperator(_) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::calculateLookaheadHash(_) => {
                    <calculateLookaheadHashCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::checkProposer(_) => {
                    <checkProposerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBlacklist(_) => {
                    <getBlacklistCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBlacklistConfig(_) => {
                    <getBlacklistConfigCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getLookaheadHash(_) => {
                    <getLookaheadHashCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getLookaheadStoreConfig(_) => {
                    <getLookaheadStoreConfigCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getProposerContext(_) => {
                    <getProposerContextCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::r#impl(_) => <implCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::inNonReentrant(_) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::inbox(_) => <inboxCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::init(_) => <initCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::isLookaheadOperatorValid(_) => {
                    <isLookaheadOperatorValidCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isLookaheadPosterValid(_) => {
                    <isLookaheadPosterValidCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isLookaheadRequired(_) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isOperatorBlacklisted(_) => {
                    <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::lookahead(_) => {
                    <lookaheadCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::lookaheadSlasher(_) => {
                    <lookaheadSlasherCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::overseers(_) => {
                    <overseersCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pause(_) => <pauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::paused(_) => <pausedCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::preconfSlasher(_) => {
                    <preconfSlasherCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::preconfWhitelist(_) => {
                    <preconfWhitelistCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proxiableUUID(_) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::removeOverseers(_) => {
                    <removeOverseersCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::resolver(_) => <resolverCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::transferOwnership(_) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::unblacklistOperator(_) => {
                    <unblacklistOperatorCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::unpause(_) => <unpauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::upgradeTo(_) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::upgradeToAndCall(_) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::urc(_) => <urcCall as alloy_sol_types::SolCall>::SELECTOR,
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
            ) -> alloy_sol_types::Result<LookaheadStoreCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::resolver)
                    }
                    resolver
                },
                {
                    fn blacklistOperator(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::blacklistOperator)
                    }
                    blacklistOperator
                },
                {
                    fn init(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::init)
                    }
                    init
                },
                {
                    fn isLookaheadRequired(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadRequired)
                    }
                    isLookaheadRequired
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn getProposerContext(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getProposerContextCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::getProposerContext)
                    }
                    getProposerContext
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn lookaheadSlasher(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <lookaheadSlasherCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::lookaheadSlasher)
                    }
                    lookaheadSlasher
                },
                {
                    fn paused(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::paused)
                    }
                    paused
                },
                {
                    fn urc(data: &[u8]) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <urcCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::urc)
                    }
                    urc
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn calculateLookaheadHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <calculateLookaheadHashCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::calculateLookaheadHash)
                    }
                    calculateLookaheadHash
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn pause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::owner)
                    }
                    owner
                },
                {
                    fn getBlacklistConfig(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getBlacklistConfigCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::getBlacklistConfig)
                    }
                    getBlacklistConfig
                },
                {
                    fn getBlacklist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getBlacklistCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::getBlacklist)
                    }
                    getBlacklist
                },
                {
                    fn addOverseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <addOverseersCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::addOverseers)
                    }
                    addOverseers
                },
                {
                    fn lookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <lookaheadCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::lookahead)
                    }
                    lookahead
                },
                {
                    fn checkProposer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <checkProposerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::checkProposer)
                    }
                    checkProposer
                },
                {
                    fn getLookaheadHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getLookaheadHashCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::getLookaheadHash)
                    }
                    getLookaheadHash
                },
                {
                    fn removeOverseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <removeOverseersCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::removeOverseers)
                    }
                    removeOverseers
                },
                {
                    fn unblacklistOperator(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <unblacklistOperatorCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::unblacklistOperator)
                    }
                    unblacklistOperator
                },
                {
                    fn isLookaheadOperatorValid(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadOperatorValidCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadOperatorValid)
                    }
                    isLookaheadOperatorValid
                },
                {
                    fn preconfWhitelist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfWhitelistCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfWhitelist)
                    }
                    preconfWhitelist
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn preconfSlasher(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfSlasherCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfSlasher)
                    }
                    preconfSlasher
                },
                {
                    fn isLookaheadPosterValid(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadPosterValidCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadPosterValid)
                    }
                    isLookaheadPosterValid
                },
                {
                    fn overseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <overseersCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::overseers)
                    }
                    overseers
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn inbox(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <inboxCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::inbox)
                    }
                    inbox
                },
                {
                    fn isOperatorBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::isOperatorBlacklisted)
                    }
                    isOperatorBlacklisted
                },
                {
                    fn getLookaheadStoreConfig(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getLookaheadStoreConfigCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::getLookaheadStoreConfig)
                    }
                    getLookaheadStoreConfig
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
            ) -> alloy_sol_types::Result<LookaheadStoreCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::resolver)
                    }
                    resolver
                },
                {
                    fn blacklistOperator(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::blacklistOperator)
                    }
                    blacklistOperator
                },
                {
                    fn init(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::init)
                    }
                    init
                },
                {
                    fn isLookaheadRequired(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadRequired)
                    }
                    isLookaheadRequired
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn getProposerContext(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getProposerContextCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::getProposerContext)
                    }
                    getProposerContext
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn lookaheadSlasher(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <lookaheadSlasherCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::lookaheadSlasher)
                    }
                    lookaheadSlasher
                },
                {
                    fn paused(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::paused)
                    }
                    paused
                },
                {
                    fn urc(data: &[u8]) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <urcCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::urc)
                    }
                    urc
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn calculateLookaheadHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <calculateLookaheadHashCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::calculateLookaheadHash)
                    }
                    calculateLookaheadHash
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn pause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::owner)
                    }
                    owner
                },
                {
                    fn getBlacklistConfig(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getBlacklistConfigCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::getBlacklistConfig)
                    }
                    getBlacklistConfig
                },
                {
                    fn getBlacklist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getBlacklistCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::getBlacklist)
                    }
                    getBlacklist
                },
                {
                    fn addOverseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <addOverseersCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::addOverseers)
                    }
                    addOverseers
                },
                {
                    fn lookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <lookaheadCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::lookahead)
                    }
                    lookahead
                },
                {
                    fn checkProposer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <checkProposerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::checkProposer)
                    }
                    checkProposer
                },
                {
                    fn getLookaheadHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getLookaheadHashCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::getLookaheadHash)
                    }
                    getLookaheadHash
                },
                {
                    fn removeOverseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <removeOverseersCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::removeOverseers)
                    }
                    removeOverseers
                },
                {
                    fn unblacklistOperator(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <unblacklistOperatorCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::unblacklistOperator)
                    }
                    unblacklistOperator
                },
                {
                    fn isLookaheadOperatorValid(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadOperatorValidCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadOperatorValid)
                    }
                    isLookaheadOperatorValid
                },
                {
                    fn preconfWhitelist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfWhitelistCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfWhitelist)
                    }
                    preconfWhitelist
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn preconfSlasher(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfSlasherCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfSlasher)
                    }
                    preconfSlasher
                },
                {
                    fn isLookaheadPosterValid(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isLookaheadPosterValidCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::isLookaheadPosterValid)
                    }
                    isLookaheadPosterValid
                },
                {
                    fn overseers(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <overseersCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::overseers)
                    }
                    overseers
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn inbox(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <inboxCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::inbox)
                    }
                    inbox
                },
                {
                    fn isOperatorBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::isOperatorBlacklisted)
                    }
                    isOperatorBlacklisted
                },
                {
                    fn getLookaheadStoreConfig(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <getLookaheadStoreConfigCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::getLookaheadStoreConfig)
                    }
                    getLookaheadStoreConfig
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
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::addOverseers(inner) => {
                    <addOverseersCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::blacklistOperator(inner) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::calculateLookaheadHash(inner) => {
                    <calculateLookaheadHashCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::checkProposer(inner) => {
                    <checkProposerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getBlacklist(inner) => {
                    <getBlacklistCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getBlacklistConfig(inner) => {
                    <getBlacklistConfigCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getLookaheadHash(inner) => {
                    <getLookaheadHashCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getLookaheadStoreConfig(inner) => {
                    <getLookaheadStoreConfigCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getProposerContext(inner) => {
                    <getProposerContextCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::r#impl(inner) => {
                    <implCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::inNonReentrant(inner) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::inbox(inner) => {
                    <inboxCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::init(inner) => {
                    <initCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::isLookaheadOperatorValid(inner) => {
                    <isLookaheadOperatorValidCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::isLookaheadPosterValid(inner) => {
                    <isLookaheadPosterValidCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::isLookaheadRequired(inner) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::isOperatorBlacklisted(inner) => {
                    <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::lookahead(inner) => {
                    <lookaheadCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::lookaheadSlasher(inner) => {
                    <lookaheadSlasherCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::overseers(inner) => {
                    <overseersCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::pause(inner) => {
                    <pauseCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::paused(inner) => {
                    <pausedCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::preconfSlasher(inner) => {
                    <preconfSlasherCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::preconfWhitelist(inner) => {
                    <preconfWhitelistCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::proxiableUUID(inner) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::removeOverseers(inner) => {
                    <removeOverseersCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::renounceOwnership(inner) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::resolver(inner) => {
                    <resolverCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::unblacklistOperator(inner) => {
                    <unblacklistOperatorCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::unpause(inner) => {
                    <unpauseCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::upgradeTo(inner) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::upgradeToAndCall(inner) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::urc(inner) => {
                    <urcCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::addOverseers(inner) => {
                    <addOverseersCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::blacklistOperator(inner) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::calculateLookaheadHash(inner) => {
                    <calculateLookaheadHashCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::checkProposer(inner) => {
                    <checkProposerCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBlacklist(inner) => {
                    <getBlacklistCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBlacklistConfig(inner) => {
                    <getBlacklistConfigCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getLookaheadHash(inner) => {
                    <getLookaheadHashCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getLookaheadStoreConfig(inner) => {
                    <getLookaheadStoreConfigCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getProposerContext(inner) => {
                    <getProposerContextCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::r#impl(inner) => {
                    <implCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::inNonReentrant(inner) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::inbox(inner) => {
                    <inboxCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::init(inner) => {
                    <initCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::isLookaheadOperatorValid(inner) => {
                    <isLookaheadOperatorValidCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::isLookaheadPosterValid(inner) => {
                    <isLookaheadPosterValidCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::isLookaheadRequired(inner) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::isOperatorBlacklisted(inner) => {
                    <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::lookahead(inner) => {
                    <lookaheadCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::lookaheadSlasher(inner) => {
                    <lookaheadSlasherCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::overseers(inner) => {
                    <overseersCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::pause(inner) => {
                    <pauseCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::paused(inner) => {
                    <pausedCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::preconfSlasher(inner) => {
                    <preconfSlasherCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::preconfWhitelist(inner) => {
                    <preconfWhitelistCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::proxiableUUID(inner) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::removeOverseers(inner) => {
                    <removeOverseersCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::renounceOwnership(inner) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::resolver(inner) => {
                    <resolverCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::unblacklistOperator(inner) => {
                    <unblacklistOperatorCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::unpause(inner) => {
                    <unpauseCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::upgradeTo(inner) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::upgradeToAndCall(inner) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::urc(inner) => {
                    <urcCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
            }
        }
    }
    ///Container for all the [`LookaheadStore`](self) custom errors.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum LookaheadStoreErrors {
        #[allow(missing_docs)]
        ACCESS_DENIED(ACCESS_DENIED),
        #[allow(missing_docs)]
        BlacklistDelayNotMet(BlacklistDelayNotMet),
        #[allow(missing_docs)]
        CommitmentSignerMismatch(CommitmentSignerMismatch),
        #[allow(missing_docs)]
        CommitterMismatch(CommitterMismatch),
        #[allow(missing_docs)]
        FUNC_NOT_IMPLEMENTED(FUNC_NOT_IMPLEMENTED),
        #[allow(missing_docs)]
        INVALID_PAUSE_STATUS(INVALID_PAUSE_STATUS),
        #[allow(missing_docs)]
        InvalidLookahead(InvalidLookahead),
        #[allow(missing_docs)]
        InvalidLookaheadEpoch(InvalidLookaheadEpoch),
        #[allow(missing_docs)]
        InvalidLookaheadTimestamp(InvalidLookaheadTimestamp),
        #[allow(missing_docs)]
        InvalidProposer(InvalidProposer),
        #[allow(missing_docs)]
        InvalidSlotIndex(InvalidSlotIndex),
        #[allow(missing_docs)]
        InvalidSlotTimestamp(InvalidSlotTimestamp),
        #[allow(missing_docs)]
        InvalidValidatorLeafIndex(InvalidValidatorLeafIndex),
        #[allow(missing_docs)]
        LookaheadNotRequired(LookaheadNotRequired),
        #[allow(missing_docs)]
        NotInbox(NotInbox),
        #[allow(missing_docs)]
        NotOverseer(NotOverseer),
        #[allow(missing_docs)]
        OperatorAlreadyBlacklisted(OperatorAlreadyBlacklisted),
        #[allow(missing_docs)]
        OperatorHasBeenBlacklisted(OperatorHasBeenBlacklisted),
        #[allow(missing_docs)]
        OperatorHasBeenSlashed(OperatorHasBeenSlashed),
        #[allow(missing_docs)]
        OperatorHasInsufficientCollateral(OperatorHasInsufficientCollateral),
        #[allow(missing_docs)]
        OperatorHasNotOptedIn(OperatorHasNotOptedIn),
        #[allow(missing_docs)]
        OperatorHasNotRegistered(OperatorHasNotRegistered),
        #[allow(missing_docs)]
        OperatorHasUnregistered(OperatorHasUnregistered),
        #[allow(missing_docs)]
        OperatorNotBlacklisted(OperatorNotBlacklisted),
        #[allow(missing_docs)]
        OverseerAlreadyExists(OverseerAlreadyExists),
        #[allow(missing_docs)]
        OverseerDoesNotExist(OverseerDoesNotExist),
        #[allow(missing_docs)]
        ProposerIsNotFallbackPreconfer(ProposerIsNotFallbackPreconfer),
        #[allow(missing_docs)]
        ProposerIsNotPreconfer(ProposerIsNotPreconfer),
        #[allow(missing_docs)]
        REENTRANT_CALL(REENTRANT_CALL),
        #[allow(missing_docs)]
        SlotTimestampIsNotIncrementing(SlotTimestampIsNotIncrementing),
        #[allow(missing_docs)]
        UnblacklistDelayNotMet(UnblacklistDelayNotMet),
        #[allow(missing_docs)]
        ZERO_ADDRESS(ZERO_ADDRESS),
        #[allow(missing_docs)]
        ZERO_VALUE(ZERO_VALUE),
    }
    #[automatically_derived]
    impl LookaheadStoreErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [14u8, 193u8, 18u8, 121u8],
            [17u8, 217u8, 223u8, 212u8],
            [24u8, 87u8, 31u8, 30u8],
            [25u8, 150u8, 71u8, 107u8],
            [53u8, 23u8, 6u8, 180u8],
            [54u8, 40u8, 168u8, 27u8],
            [65u8, 0u8, 172u8, 3u8],
            [65u8, 208u8, 199u8, 55u8],
            [68u8, 97u8, 73u8, 47u8],
            [69u8, 203u8, 10u8, 249u8],
            [76u8, 148u8, 25u8, 47u8],
            [82u8, 140u8, 236u8, 104u8],
            [83u8, 139u8, 164u8, 249u8],
            [85u8, 247u8, 218u8, 148u8],
            [96u8, 22u8, 166u8, 243u8],
            [114u8, 16u8, 159u8, 119u8],
            [129u8, 54u8, 100u8, 30u8],
            [149u8, 56u8, 62u8, 161u8],
            [150u8, 172u8, 231u8, 155u8],
            [151u8, 28u8, 206u8, 143u8],
            [153u8, 211u8, 250u8, 249u8],
            [162u8, 130u8, 147u8, 31u8],
            [165u8, 82u8, 171u8, 73u8],
            [172u8, 157u8, 135u8, 205u8],
            [184u8, 6u8, 40u8, 54u8],
            [186u8, 230u8, 226u8, 169u8],
            [196u8, 31u8, 13u8, 15u8],
            [211u8, 252u8, 63u8, 246u8],
            [212u8, 193u8, 3u8, 162u8],
            [223u8, 198u8, 13u8, 133u8],
            [223u8, 207u8, 121u8, 182u8],
            [234u8, 248u8, 42u8, 37u8],
            [236u8, 115u8, 41u8, 89u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for LookaheadStoreErrors {
        const NAME: &'static str = "LookaheadStoreErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 33usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ACCESS_DENIED(_) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::BlacklistDelayNotMet(_) => {
                    <BlacklistDelayNotMet as alloy_sol_types::SolError>::SELECTOR
                }
                Self::CommitmentSignerMismatch(_) => {
                    <CommitmentSignerMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::CommitterMismatch(_) => {
                    <CommitterMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::FUNC_NOT_IMPLEMENTED(_) => {
                    <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::INVALID_PAUSE_STATUS(_) => {
                    <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidLookahead(_) => {
                    <InvalidLookahead as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidLookaheadEpoch(_) => {
                    <InvalidLookaheadEpoch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidLookaheadTimestamp(_) => {
                    <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidProposer(_) => {
                    <InvalidProposer as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidSlotIndex(_) => {
                    <InvalidSlotIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidSlotTimestamp(_) => {
                    <InvalidSlotTimestamp as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidValidatorLeafIndex(_) => {
                    <InvalidValidatorLeafIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::LookaheadNotRequired(_) => {
                    <LookaheadNotRequired as alloy_sol_types::SolError>::SELECTOR
                }
                Self::NotInbox(_) => <NotInbox as alloy_sol_types::SolError>::SELECTOR,
                Self::NotOverseer(_) => {
                    <NotOverseer as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorAlreadyBlacklisted(_) => {
                    <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasBeenBlacklisted(_) => {
                    <OperatorHasBeenBlacklisted as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasBeenSlashed(_) => {
                    <OperatorHasBeenSlashed as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasInsufficientCollateral(_) => {
                    <OperatorHasInsufficientCollateral as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasNotOptedIn(_) => {
                    <OperatorHasNotOptedIn as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasNotRegistered(_) => {
                    <OperatorHasNotRegistered as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorHasUnregistered(_) => {
                    <OperatorHasUnregistered as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorNotBlacklisted(_) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OverseerAlreadyExists(_) => {
                    <OverseerAlreadyExists as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OverseerDoesNotExist(_) => {
                    <OverseerDoesNotExist as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ProposerIsNotFallbackPreconfer(_) => {
                    <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ProposerIsNotPreconfer(_) => {
                    <ProposerIsNotPreconfer as alloy_sol_types::SolError>::SELECTOR
                }
                Self::REENTRANT_CALL(_) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SlotTimestampIsNotIncrementing(_) => {
                    <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::SELECTOR
                }
                Self::UnblacklistDelayNotMet(_) => {
                    <UnblacklistDelayNotMet as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ZERO_ADDRESS(_) => {
                    <ZERO_ADDRESS as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ZERO_VALUE(_) => {
                    <ZERO_VALUE as alloy_sol_types::SolError>::SELECTOR
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
            ) -> alloy_sol_types::Result<LookaheadStoreErrors>] = &[
                {
                    fn OperatorNotBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorNotBlacklisted)
                    }
                    OperatorNotBlacklisted
                },
                {
                    fn ProposerIsNotFallbackPreconfer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::ProposerIsNotFallbackPreconfer)
                    }
                    ProposerIsNotFallbackPreconfer
                },
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn OperatorAlreadyBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorAlreadyBlacklisted)
                    }
                    OperatorAlreadyBlacklisted
                },
                {
                    fn LookaheadNotRequired(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <LookaheadNotRequired as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::LookaheadNotRequired)
                    }
                    LookaheadNotRequired
                },
                {
                    fn InvalidSlotIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidSlotIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidSlotIndex)
                    }
                    InvalidSlotIndex
                },
                {
                    fn InvalidProposer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidProposer as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidProposer)
                    }
                    InvalidProposer
                },
                {
                    fn OverseerDoesNotExist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OverseerDoesNotExist as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OverseerDoesNotExist)
                    }
                    OverseerDoesNotExist
                },
                {
                    fn OverseerAlreadyExists(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OverseerAlreadyExists as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OverseerAlreadyExists)
                    }
                    OverseerAlreadyExists
                },
                {
                    fn InvalidLookaheadTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookaheadTimestamp)
                    }
                    InvalidLookaheadTimestamp
                },
                {
                    fn OperatorHasBeenSlashed(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasBeenSlashed as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasBeenSlashed)
                    }
                    OperatorHasBeenSlashed
                },
                {
                    fn CommitterMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <CommitterMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::CommitterMismatch)
                    }
                    CommitterMismatch
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(LookaheadStoreErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn CommitmentSignerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <CommitmentSignerMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::CommitmentSignerMismatch)
                    }
                    CommitmentSignerMismatch
                },
                {
                    fn InvalidValidatorLeafIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidValidatorLeafIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidValidatorLeafIndex)
                    }
                    InvalidValidatorLeafIndex
                },
                {
                    fn NotInbox(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <NotInbox as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(LookaheadStoreErrors::NotInbox)
                    }
                    NotInbox
                },
                {
                    fn ProposerIsNotPreconfer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ProposerIsNotPreconfer as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::ProposerIsNotPreconfer)
                    }
                    ProposerIsNotPreconfer
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn InvalidLookaheadEpoch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookaheadEpoch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookaheadEpoch)
                    }
                    InvalidLookaheadEpoch
                },
                {
                    fn InvalidSlotTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidSlotTimestamp as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidSlotTimestamp)
                    }
                    InvalidSlotTimestamp
                },
                {
                    fn UnblacklistDelayNotMet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <UnblacklistDelayNotMet as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::UnblacklistDelayNotMet)
                    }
                    UnblacklistDelayNotMet
                },
                {
                    fn BlacklistDelayNotMet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <BlacklistDelayNotMet as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::BlacklistDelayNotMet)
                    }
                    BlacklistDelayNotMet
                },
                {
                    fn OperatorHasUnregistered(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasUnregistered as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasUnregistered)
                    }
                    OperatorHasUnregistered
                },
                {
                    fn NotOverseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <NotOverseer as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(LookaheadStoreErrors::NotOverseer)
                    }
                    NotOverseer
                },
                {
                    fn SlotTimestampIsNotIncrementing(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::SlotTimestampIsNotIncrementing)
                    }
                    SlotTimestampIsNotIncrementing
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn OperatorHasInsufficientCollateral(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasInsufficientCollateral as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasInsufficientCollateral)
                    }
                    OperatorHasInsufficientCollateral
                },
                {
                    fn OperatorHasNotRegistered(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasNotRegistered as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasNotRegistered)
                    }
                    OperatorHasNotRegistered
                },
                {
                    fn OperatorHasBeenBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasBeenBlacklisted as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasBeenBlacklisted)
                    }
                    OperatorHasBeenBlacklisted
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn OperatorHasNotOptedIn(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasNotOptedIn as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasNotOptedIn)
                    }
                    OperatorHasNotOptedIn
                },
                {
                    fn InvalidLookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookahead as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookahead)
                    }
                    InvalidLookahead
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(LookaheadStoreErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
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
            ) -> alloy_sol_types::Result<LookaheadStoreErrors>] = &[
                {
                    fn OperatorNotBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorNotBlacklisted)
                    }
                    OperatorNotBlacklisted
                },
                {
                    fn ProposerIsNotFallbackPreconfer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::ProposerIsNotFallbackPreconfer)
                    }
                    ProposerIsNotFallbackPreconfer
                },
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn OperatorAlreadyBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorAlreadyBlacklisted)
                    }
                    OperatorAlreadyBlacklisted
                },
                {
                    fn LookaheadNotRequired(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <LookaheadNotRequired as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::LookaheadNotRequired)
                    }
                    LookaheadNotRequired
                },
                {
                    fn InvalidSlotIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidSlotIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidSlotIndex)
                    }
                    InvalidSlotIndex
                },
                {
                    fn InvalidProposer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidProposer as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidProposer)
                    }
                    InvalidProposer
                },
                {
                    fn OverseerDoesNotExist(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OverseerDoesNotExist as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OverseerDoesNotExist)
                    }
                    OverseerDoesNotExist
                },
                {
                    fn OverseerAlreadyExists(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OverseerAlreadyExists as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OverseerAlreadyExists)
                    }
                    OverseerAlreadyExists
                },
                {
                    fn InvalidLookaheadTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookaheadTimestamp)
                    }
                    InvalidLookaheadTimestamp
                },
                {
                    fn OperatorHasBeenSlashed(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasBeenSlashed as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasBeenSlashed)
                    }
                    OperatorHasBeenSlashed
                },
                {
                    fn CommitterMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <CommitterMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::CommitterMismatch)
                    }
                    CommitterMismatch
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn CommitmentSignerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <CommitmentSignerMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::CommitmentSignerMismatch)
                    }
                    CommitmentSignerMismatch
                },
                {
                    fn InvalidValidatorLeafIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidValidatorLeafIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidValidatorLeafIndex)
                    }
                    InvalidValidatorLeafIndex
                },
                {
                    fn NotInbox(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <NotInbox as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::NotInbox)
                    }
                    NotInbox
                },
                {
                    fn ProposerIsNotPreconfer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ProposerIsNotPreconfer as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::ProposerIsNotPreconfer)
                    }
                    ProposerIsNotPreconfer
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn InvalidLookaheadEpoch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookaheadEpoch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookaheadEpoch)
                    }
                    InvalidLookaheadEpoch
                },
                {
                    fn InvalidSlotTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidSlotTimestamp as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidSlotTimestamp)
                    }
                    InvalidSlotTimestamp
                },
                {
                    fn UnblacklistDelayNotMet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <UnblacklistDelayNotMet as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::UnblacklistDelayNotMet)
                    }
                    UnblacklistDelayNotMet
                },
                {
                    fn BlacklistDelayNotMet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <BlacklistDelayNotMet as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::BlacklistDelayNotMet)
                    }
                    BlacklistDelayNotMet
                },
                {
                    fn OperatorHasUnregistered(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasUnregistered as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasUnregistered)
                    }
                    OperatorHasUnregistered
                },
                {
                    fn NotOverseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <NotOverseer as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::NotOverseer)
                    }
                    NotOverseer
                },
                {
                    fn SlotTimestampIsNotIncrementing(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::SlotTimestampIsNotIncrementing)
                    }
                    SlotTimestampIsNotIncrementing
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn OperatorHasInsufficientCollateral(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasInsufficientCollateral as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasInsufficientCollateral)
                    }
                    OperatorHasInsufficientCollateral
                },
                {
                    fn OperatorHasNotRegistered(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasNotRegistered as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasNotRegistered)
                    }
                    OperatorHasNotRegistered
                },
                {
                    fn OperatorHasBeenBlacklisted(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasBeenBlacklisted as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasBeenBlacklisted)
                    }
                    OperatorHasBeenBlacklisted
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn OperatorHasNotOptedIn(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <OperatorHasNotOptedIn as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::OperatorHasNotOptedIn)
                    }
                    OperatorHasNotOptedIn
                },
                {
                    fn InvalidLookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <InvalidLookahead as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::InvalidLookahead)
                    }
                    InvalidLookahead
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
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
                Self::ACCESS_DENIED(inner) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::BlacklistDelayNotMet(inner) => {
                    <BlacklistDelayNotMet as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::CommitmentSignerMismatch(inner) => {
                    <CommitmentSignerMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::CommitterMismatch(inner) => {
                    <CommitterMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::FUNC_NOT_IMPLEMENTED(inner) => {
                    <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::INVALID_PAUSE_STATUS(inner) => {
                    <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidLookahead(inner) => {
                    <InvalidLookahead as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidLookaheadEpoch(inner) => {
                    <InvalidLookaheadEpoch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidLookaheadTimestamp(inner) => {
                    <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidProposer(inner) => {
                    <InvalidProposer as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidSlotIndex(inner) => {
                    <InvalidSlotIndex as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidSlotTimestamp(inner) => {
                    <InvalidSlotTimestamp as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidValidatorLeafIndex(inner) => {
                    <InvalidValidatorLeafIndex as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::LookaheadNotRequired(inner) => {
                    <LookaheadNotRequired as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::NotInbox(inner) => {
                    <NotInbox as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::NotOverseer(inner) => {
                    <NotOverseer as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::OperatorAlreadyBlacklisted(inner) => {
                    <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasBeenBlacklisted(inner) => {
                    <OperatorHasBeenBlacklisted as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasBeenSlashed(inner) => {
                    <OperatorHasBeenSlashed as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasInsufficientCollateral(inner) => {
                    <OperatorHasInsufficientCollateral as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasNotOptedIn(inner) => {
                    <OperatorHasNotOptedIn as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasNotRegistered(inner) => {
                    <OperatorHasNotRegistered as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorHasUnregistered(inner) => {
                    <OperatorHasUnregistered as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OperatorNotBlacklisted(inner) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OverseerAlreadyExists(inner) => {
                    <OverseerAlreadyExists as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::OverseerDoesNotExist(inner) => {
                    <OverseerDoesNotExist as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ProposerIsNotFallbackPreconfer(inner) => {
                    <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ProposerIsNotPreconfer(inner) => {
                    <ProposerIsNotPreconfer as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SlotTimestampIsNotIncrementing(inner) => {
                    <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::UnblacklistDelayNotMet(inner) => {
                    <UnblacklistDelayNotMet as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ZERO_ADDRESS(inner) => {
                    <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::ZERO_VALUE(inner) => {
                    <ZERO_VALUE as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::ACCESS_DENIED(inner) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::BlacklistDelayNotMet(inner) => {
                    <BlacklistDelayNotMet as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::CommitmentSignerMismatch(inner) => {
                    <CommitmentSignerMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::CommitterMismatch(inner) => {
                    <CommitterMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::FUNC_NOT_IMPLEMENTED(inner) => {
                    <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::INVALID_PAUSE_STATUS(inner) => {
                    <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidLookahead(inner) => {
                    <InvalidLookahead as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidLookaheadEpoch(inner) => {
                    <InvalidLookaheadEpoch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidLookaheadTimestamp(inner) => {
                    <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidProposer(inner) => {
                    <InvalidProposer as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidSlotIndex(inner) => {
                    <InvalidSlotIndex as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidSlotTimestamp(inner) => {
                    <InvalidSlotTimestamp as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidValidatorLeafIndex(inner) => {
                    <InvalidValidatorLeafIndex as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::LookaheadNotRequired(inner) => {
                    <LookaheadNotRequired as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::NotInbox(inner) => {
                    <NotInbox as alloy_sol_types::SolError>::abi_encode_raw(inner, out)
                }
                Self::NotOverseer(inner) => {
                    <NotOverseer as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorAlreadyBlacklisted(inner) => {
                    <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasBeenBlacklisted(inner) => {
                    <OperatorHasBeenBlacklisted as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasBeenSlashed(inner) => {
                    <OperatorHasBeenSlashed as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasInsufficientCollateral(inner) => {
                    <OperatorHasInsufficientCollateral as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasNotOptedIn(inner) => {
                    <OperatorHasNotOptedIn as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasNotRegistered(inner) => {
                    <OperatorHasNotRegistered as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorHasUnregistered(inner) => {
                    <OperatorHasUnregistered as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OperatorNotBlacklisted(inner) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OverseerAlreadyExists(inner) => {
                    <OverseerAlreadyExists as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::OverseerDoesNotExist(inner) => {
                    <OverseerDoesNotExist as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ProposerIsNotFallbackPreconfer(inner) => {
                    <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ProposerIsNotPreconfer(inner) => {
                    <ProposerIsNotPreconfer as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SlotTimestampIsNotIncrementing(inner) => {
                    <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::UnblacklistDelayNotMet(inner) => {
                    <UnblacklistDelayNotMet as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ZERO_ADDRESS(inner) => {
                    <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ZERO_VALUE(inner) => {
                    <ZERO_VALUE as alloy_sol_types::SolError>::abi_encode_raw(inner, out)
                }
            }
        }
    }
    ///Container for all the [`LookaheadStore`](self) events.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum LookaheadStoreEvents {
        #[allow(missing_docs)]
        AdminChanged(AdminChanged),
        #[allow(missing_docs)]
        BeaconUpgraded(BeaconUpgraded),
        #[allow(missing_docs)]
        Blacklisted(Blacklisted),
        #[allow(missing_docs)]
        Initialized(Initialized),
        #[allow(missing_docs)]
        LookaheadPosted(LookaheadPosted),
        #[allow(missing_docs)]
        OverseersAdded(OverseersAdded),
        #[allow(missing_docs)]
        OverseersRemoved(OverseersRemoved),
        #[allow(missing_docs)]
        OwnershipTransferStarted(OwnershipTransferStarted),
        #[allow(missing_docs)]
        OwnershipTransferred(OwnershipTransferred),
        #[allow(missing_docs)]
        Paused(Paused),
        #[allow(missing_docs)]
        Unblacklisted(Unblacklisted),
        #[allow(missing_docs)]
        Unpaused(Unpaused),
        #[allow(missing_docs)]
        Upgraded(Upgraded),
    }
    #[automatically_derived]
    impl LookaheadStoreEvents {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 32usize]] = &[
            [
                26u8, 135u8, 139u8, 43u8, 248u8, 104u8, 12u8, 2u8, 247u8, 215u8, 156u8,
                25u8, 154u8, 97u8, 173u8, 190u8, 135u8, 68u8, 232u8, 204u8, 176u8, 241u8,
                126u8, 54u8, 34u8, 155u8, 97u8, 147u8, 49u8, 250u8, 46u8, 19u8,
            ],
            [
                28u8, 243u8, 176u8, 58u8, 108u8, 241u8, 159u8, 162u8, 186u8, 186u8, 77u8,
                241u8, 72u8, 233u8, 220u8, 171u8, 237u8, 234u8, 127u8, 138u8, 92u8, 7u8,
                132u8, 14u8, 32u8, 126u8, 92u8, 8u8, 155u8, 233u8, 93u8, 62u8,
            ],
            [
                56u8, 209u8, 107u8, 140u8, 172u8, 34u8, 217u8, 159u8, 199u8, 193u8, 36u8,
                185u8, 205u8, 13u8, 226u8, 211u8, 250u8, 31u8, 174u8, 244u8, 32u8, 191u8,
                231u8, 145u8, 216u8, 195u8, 98u8, 215u8, 101u8, 226u8, 39u8, 0u8,
            ],
            [
                93u8, 185u8, 238u8, 10u8, 73u8, 91u8, 242u8, 230u8, 255u8, 156u8, 145u8,
                167u8, 131u8, 76u8, 27u8, 164u8, 253u8, 210u8, 68u8, 165u8, 232u8, 170u8,
                78u8, 83u8, 123u8, 211u8, 138u8, 234u8, 228u8, 176u8, 115u8, 170u8,
            ],
            [
                98u8, 231u8, 140u8, 234u8, 1u8, 190u8, 227u8, 32u8, 205u8, 78u8, 66u8,
                2u8, 112u8, 181u8, 234u8, 116u8, 0u8, 13u8, 17u8, 176u8, 201u8, 247u8,
                71u8, 84u8, 235u8, 219u8, 252u8, 84u8, 75u8, 5u8, 162u8, 88u8,
            ],
            [
                126u8, 100u8, 77u8, 121u8, 66u8, 47u8, 23u8, 192u8, 30u8, 72u8, 148u8,
                181u8, 244u8, 245u8, 136u8, 211u8, 49u8, 235u8, 250u8, 40u8, 101u8, 61u8,
                66u8, 174u8, 131u8, 45u8, 197u8, 158u8, 56u8, 201u8, 121u8, 143u8,
            ],
            [
                127u8, 38u8, 184u8, 63u8, 249u8, 110u8, 31u8, 43u8, 106u8, 104u8, 47u8,
                19u8, 56u8, 82u8, 246u8, 121u8, 138u8, 9u8, 196u8, 101u8, 218u8, 149u8,
                146u8, 20u8, 96u8, 206u8, 251u8, 56u8, 71u8, 64u8, 36u8, 152u8,
            ],
            [
                139u8, 224u8, 7u8, 156u8, 83u8, 22u8, 89u8, 20u8, 19u8, 68u8, 205u8,
                31u8, 208u8, 164u8, 242u8, 132u8, 25u8, 73u8, 127u8, 151u8, 34u8, 163u8,
                218u8, 175u8, 227u8, 180u8, 24u8, 111u8, 107u8, 100u8, 87u8, 224u8,
            ],
            [
                150u8, 130u8, 174u8, 63u8, 183u8, 156u8, 16u8, 148u8, 129u8, 22u8, 254u8,
                42u8, 34u8, 76u8, 202u8, 144u8, 37u8, 251u8, 118u8, 113u8, 100u8, 119u8,
                215u8, 19u8, 223u8, 236u8, 118u8, 109u8, 139u8, 204u8, 238u8, 23u8,
            ],
            [
                174u8, 155u8, 100u8, 55u8, 173u8, 38u8, 117u8, 83u8, 175u8, 191u8, 7u8,
                85u8, 4u8, 5u8, 69u8, 143u8, 196u8, 63u8, 17u8, 248u8, 197u8, 0u8, 55u8,
                163u8, 246u8, 180u8, 215u8, 147u8, 112u8, 100u8, 204u8, 10u8,
            ],
            [
                174u8, 193u8, 223u8, 163u8, 34u8, 27u8, 124u8, 66u8, 110u8, 97u8, 100u8,
                224u8, 140u8, 166u8, 129u8, 26u8, 89u8, 231u8, 13u8, 79u8, 201u8, 125u8,
                126u8, 78u8, 254u8, 204u8, 127u8, 47u8, 138u8, 196u8, 186u8, 112u8,
            ],
            [
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ],
            [
                218u8, 226u8, 21u8, 13u8, 73u8, 217u8, 203u8, 18u8, 32u8, 251u8, 76u8,
                39u8, 148u8, 54u8, 182u8, 158u8, 207u8, 250u8, 64u8, 177u8, 182u8, 64u8,
                37u8, 227u8, 150u8, 182u8, 190u8, 93u8, 131u8, 11u8, 129u8, 52u8,
            ],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolEventInterface for LookaheadStoreEvents {
        const NAME: &'static str = "LookaheadStoreEvents";
        const COUNT: usize = 13usize;
        fn decode_raw_log(
            topics: &[alloy_sol_types::Word],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            match topics.first().copied() {
                Some(<AdminChanged as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <AdminChanged as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::AdminChanged)
                }
                Some(<BeaconUpgraded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <BeaconUpgraded as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::BeaconUpgraded)
                }
                Some(<Blacklisted as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Blacklisted as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::Blacklisted)
                }
                Some(<Initialized as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Initialized as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::Initialized)
                }
                Some(<LookaheadPosted as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <LookaheadPosted as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::LookaheadPosted)
                }
                Some(<OverseersAdded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <OverseersAdded as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::OverseersAdded)
                }
                Some(<OverseersRemoved as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <OverseersRemoved as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::OverseersRemoved)
                }
                Some(
                    <OwnershipTransferStarted as alloy_sol_types::SolEvent>::SIGNATURE_HASH,
                ) => {
                    <OwnershipTransferStarted as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::OwnershipTransferStarted)
                }
                Some(
                    <OwnershipTransferred as alloy_sol_types::SolEvent>::SIGNATURE_HASH,
                ) => {
                    <OwnershipTransferred as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::OwnershipTransferred)
                }
                Some(<Paused as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Paused as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Paused)
                }
                Some(<Unblacklisted as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Unblacklisted as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::Unblacklisted)
                }
                Some(<Unpaused as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Unpaused as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Unpaused)
                }
                Some(<Upgraded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Upgraded as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Upgraded)
                }
                _ => {
                    alloy_sol_types::private::Err(alloy_sol_types::Error::InvalidLog {
                        name: <Self as alloy_sol_types::SolEventInterface>::NAME,
                        log: alloy_sol_types::private::Box::new(
                            alloy_sol_types::private::LogData::new_unchecked(
                                topics.to_vec(),
                                data.to_vec().into(),
                            ),
                        ),
                    })
                }
            }
        }
    }
    #[automatically_derived]
    impl alloy_sol_types::private::IntoLogData for LookaheadStoreEvents {
        fn to_log_data(&self) -> alloy_sol_types::private::LogData {
            match self {
                Self::AdminChanged(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::BeaconUpgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Blacklisted(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Initialized(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::LookaheadPosted(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OverseersAdded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OverseersRemoved(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OwnershipTransferStarted(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OwnershipTransferred(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Paused(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Unblacklisted(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Unpaused(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Upgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
            }
        }
        fn into_log_data(self) -> alloy_sol_types::private::LogData {
            match self {
                Self::AdminChanged(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::BeaconUpgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Blacklisted(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Initialized(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::LookaheadPosted(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OverseersAdded(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OverseersRemoved(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OwnershipTransferStarted(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OwnershipTransferred(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Paused(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Unblacklisted(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Unpaused(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Upgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
            }
        }
    }
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`LookaheadStore`](self) contract instance.

See the [wrapper's documentation](`LookaheadStoreInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> LookaheadStoreInstance<P, N> {
        LookaheadStoreInstance::<P, N>::new(address, provider)
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
        _urc: alloy::sol_types::private::Address,
        _lookaheadSlasher: alloy::sol_types::private::Address,
        _preconfSlasher: alloy::sol_types::private::Address,
        _inbox: alloy::sol_types::private::Address,
        _preconfWhitelist: alloy::sol_types::private::Address,
        _overseers: alloy::sol_types::private::Vec<alloy::sol_types::private::Address>,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<LookaheadStoreInstance<P, N>>,
    > {
        LookaheadStoreInstance::<
            P,
            N,
        >::deploy(
            provider,
            _urc,
            _lookaheadSlasher,
            _preconfSlasher,
            _inbox,
            _preconfWhitelist,
            _overseers,
        )
    }
    /**Creates a `RawCallBuilder` for deploying this contract using the given `provider`
and constructor arguments, if any.

This is a simple wrapper around creating a `RawCallBuilder` with the data set to
the bytecode concatenated with the constructor's ABI-encoded arguments.*/
    #[inline]
    pub fn deploy_builder<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        provider: P,
        _urc: alloy::sol_types::private::Address,
        _lookaheadSlasher: alloy::sol_types::private::Address,
        _preconfSlasher: alloy::sol_types::private::Address,
        _inbox: alloy::sol_types::private::Address,
        _preconfWhitelist: alloy::sol_types::private::Address,
        _overseers: alloy::sol_types::private::Vec<alloy::sol_types::private::Address>,
    ) -> alloy_contract::RawCallBuilder<P, N> {
        LookaheadStoreInstance::<
            P,
            N,
        >::deploy_builder(
            provider,
            _urc,
            _lookaheadSlasher,
            _preconfSlasher,
            _inbox,
            _preconfWhitelist,
            _overseers,
        )
    }
    /**A [`LookaheadStore`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`LookaheadStore`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct LookaheadStoreInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for LookaheadStoreInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("LookaheadStoreInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LookaheadStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`LookaheadStore`](self) contract instance.

See the [wrapper's documentation](`LookaheadStoreInstance`) for more details.*/
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
            _urc: alloy::sol_types::private::Address,
            _lookaheadSlasher: alloy::sol_types::private::Address,
            _preconfSlasher: alloy::sol_types::private::Address,
            _inbox: alloy::sol_types::private::Address,
            _preconfWhitelist: alloy::sol_types::private::Address,
            _overseers: alloy::sol_types::private::Vec<
                alloy::sol_types::private::Address,
            >,
        ) -> alloy_contract::Result<LookaheadStoreInstance<P, N>> {
            let call_builder = Self::deploy_builder(
                provider,
                _urc,
                _lookaheadSlasher,
                _preconfSlasher,
                _inbox,
                _preconfWhitelist,
                _overseers,
            );
            let contract_address = call_builder.deploy().await?;
            Ok(Self::new(contract_address, call_builder.provider))
        }
        /**Creates a `RawCallBuilder` for deploying this contract using the given `provider`
and constructor arguments, if any.

This is a simple wrapper around creating a `RawCallBuilder` with the data set to
the bytecode concatenated with the constructor's ABI-encoded arguments.*/
        #[inline]
        pub fn deploy_builder(
            provider: P,
            _urc: alloy::sol_types::private::Address,
            _lookaheadSlasher: alloy::sol_types::private::Address,
            _preconfSlasher: alloy::sol_types::private::Address,
            _inbox: alloy::sol_types::private::Address,
            _preconfWhitelist: alloy::sol_types::private::Address,
            _overseers: alloy::sol_types::private::Vec<
                alloy::sol_types::private::Address,
            >,
        ) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                provider,
                [
                    &BYTECODE[..],
                    &alloy_sol_types::SolConstructor::abi_encode(
                        &constructorCall {
                            _urc,
                            _lookaheadSlasher,
                            _preconfSlasher,
                            _inbox,
                            _preconfWhitelist,
                            _overseers,
                        },
                    )[..],
                ]
                    .concat()
                    .into(),
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
    impl<P: ::core::clone::Clone, N> LookaheadStoreInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> LookaheadStoreInstance<P, N> {
            LookaheadStoreInstance {
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
    > LookaheadStoreInstance<P, N> {
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
        ///Creates a new call builder for the [`acceptOwnership`] function.
        pub fn acceptOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, acceptOwnershipCall, N> {
            self.call_builder(&acceptOwnershipCall)
        }
        ///Creates a new call builder for the [`addOverseers`] function.
        pub fn addOverseers(
            &self,
            _overseers: alloy::sol_types::private::Vec<
                alloy::sol_types::private::Address,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, addOverseersCall, N> {
            self.call_builder(&addOverseersCall { _overseers })
        }
        ///Creates a new call builder for the [`blacklistOperator`] function.
        pub fn blacklistOperator(
            &self,
            _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, blacklistOperatorCall, N> {
            self.call_builder(
                &blacklistOperatorCall {
                    _operatorRegistrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`calculateLookaheadHash`] function.
        pub fn calculateLookaheadHash(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _lookaheadSlots: alloy::sol_types::private::Vec<
                <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, calculateLookaheadHashCall, N> {
            self.call_builder(
                &calculateLookaheadHashCall {
                    _epochTimestamp,
                    _lookaheadSlots,
                },
            )
        }
        ///Creates a new call builder for the [`checkProposer`] function.
        pub fn checkProposer(
            &self,
            _proposer: alloy::sol_types::private::Address,
            _lookaheadData: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, checkProposerCall, N> {
            self.call_builder(
                &checkProposerCall {
                    _proposer,
                    _lookaheadData,
                },
            )
        }
        ///Creates a new call builder for the [`getBlacklist`] function.
        pub fn getBlacklist(
            &self,
            operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, getBlacklistCall, N> {
            self.call_builder(
                &getBlacklistCall {
                    operatorRegistrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`getBlacklistConfig`] function.
        pub fn getBlacklistConfig(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, getBlacklistConfigCall, N> {
            self.call_builder(&getBlacklistConfigCall)
        }
        ///Creates a new call builder for the [`getLookaheadHash`] function.
        pub fn getLookaheadHash(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, getLookaheadHashCall, N> {
            self.call_builder(
                &getLookaheadHashCall {
                    _epochTimestamp,
                },
            )
        }
        ///Creates a new call builder for the [`getLookaheadStoreConfig`] function.
        pub fn getLookaheadStoreConfig(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, getLookaheadStoreConfigCall, N> {
            self.call_builder(&getLookaheadStoreConfigCall)
        }
        ///Creates a new call builder for the [`getProposerContext`] function.
        pub fn getProposerContext(
            &self,
            _data: <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, getProposerContextCall, N> {
            self.call_builder(
                &getProposerContextCall {
                    _data,
                    _epochTimestamp,
                },
            )
        }
        ///Creates a new call builder for the [`r#impl`] function.
        pub fn r#impl(&self) -> alloy_contract::SolCallBuilder<&P, implCall, N> {
            self.call_builder(&implCall)
        }
        ///Creates a new call builder for the [`inNonReentrant`] function.
        pub fn inNonReentrant(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, inNonReentrantCall, N> {
            self.call_builder(&inNonReentrantCall)
        }
        ///Creates a new call builder for the [`inbox`] function.
        pub fn inbox(&self) -> alloy_contract::SolCallBuilder<&P, inboxCall, N> {
            self.call_builder(&inboxCall)
        }
        ///Creates a new call builder for the [`init`] function.
        pub fn init(
            &self,
            _owner: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, initCall, N> {
            self.call_builder(&initCall { _owner })
        }
        ///Creates a new call builder for the [`isLookaheadOperatorValid`] function.
        pub fn isLookaheadOperatorValid(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isLookaheadOperatorValidCall, N> {
            self.call_builder(
                &isLookaheadOperatorValidCall {
                    _epochTimestamp,
                    _registrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`isLookaheadPosterValid`] function.
        pub fn isLookaheadPosterValid(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isLookaheadPosterValidCall, N> {
            self.call_builder(
                &isLookaheadPosterValidCall {
                    _epochTimestamp,
                    _registrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`isLookaheadRequired`] function.
        pub fn isLookaheadRequired(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, isLookaheadRequiredCall, N> {
            self.call_builder(&isLookaheadRequiredCall)
        }
        ///Creates a new call builder for the [`isOperatorBlacklisted`] function.
        pub fn isOperatorBlacklisted(
            &self,
            operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isOperatorBlacklistedCall, N> {
            self.call_builder(
                &isOperatorBlacklistedCall {
                    operatorRegistrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`lookahead`] function.
        pub fn lookahead(
            &self,
            epochTimestamp_mod_lookaheadBufferSize: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, lookaheadCall, N> {
            self.call_builder(
                &lookaheadCall {
                    epochTimestamp_mod_lookaheadBufferSize,
                },
            )
        }
        ///Creates a new call builder for the [`lookaheadSlasher`] function.
        pub fn lookaheadSlasher(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, lookaheadSlasherCall, N> {
            self.call_builder(&lookaheadSlasherCall)
        }
        ///Creates a new call builder for the [`overseers`] function.
        pub fn overseers(
            &self,
            overseer: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, overseersCall, N> {
            self.call_builder(&overseersCall { overseer })
        }
        ///Creates a new call builder for the [`owner`] function.
        pub fn owner(&self) -> alloy_contract::SolCallBuilder<&P, ownerCall, N> {
            self.call_builder(&ownerCall)
        }
        ///Creates a new call builder for the [`pause`] function.
        pub fn pause(&self) -> alloy_contract::SolCallBuilder<&P, pauseCall, N> {
            self.call_builder(&pauseCall)
        }
        ///Creates a new call builder for the [`paused`] function.
        pub fn paused(&self) -> alloy_contract::SolCallBuilder<&P, pausedCall, N> {
            self.call_builder(&pausedCall)
        }
        ///Creates a new call builder for the [`pendingOwner`] function.
        pub fn pendingOwner(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, pendingOwnerCall, N> {
            self.call_builder(&pendingOwnerCall)
        }
        ///Creates a new call builder for the [`preconfSlasher`] function.
        pub fn preconfSlasher(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, preconfSlasherCall, N> {
            self.call_builder(&preconfSlasherCall)
        }
        ///Creates a new call builder for the [`preconfWhitelist`] function.
        pub fn preconfWhitelist(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, preconfWhitelistCall, N> {
            self.call_builder(&preconfWhitelistCall)
        }
        ///Creates a new call builder for the [`proxiableUUID`] function.
        pub fn proxiableUUID(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, proxiableUUIDCall, N> {
            self.call_builder(&proxiableUUIDCall)
        }
        ///Creates a new call builder for the [`removeOverseers`] function.
        pub fn removeOverseers(
            &self,
            _overseers: alloy::sol_types::private::Vec<
                alloy::sol_types::private::Address,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, removeOverseersCall, N> {
            self.call_builder(&removeOverseersCall { _overseers })
        }
        ///Creates a new call builder for the [`renounceOwnership`] function.
        pub fn renounceOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, renounceOwnershipCall, N> {
            self.call_builder(&renounceOwnershipCall)
        }
        ///Creates a new call builder for the [`resolver`] function.
        pub fn resolver(&self) -> alloy_contract::SolCallBuilder<&P, resolverCall, N> {
            self.call_builder(&resolverCall)
        }
        ///Creates a new call builder for the [`transferOwnership`] function.
        pub fn transferOwnership(
            &self,
            newOwner: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, transferOwnershipCall, N> {
            self.call_builder(&transferOwnershipCall { newOwner })
        }
        ///Creates a new call builder for the [`unblacklistOperator`] function.
        pub fn unblacklistOperator(
            &self,
            _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, unblacklistOperatorCall, N> {
            self.call_builder(
                &unblacklistOperatorCall {
                    _operatorRegistrationRoot,
                },
            )
        }
        ///Creates a new call builder for the [`unpause`] function.
        pub fn unpause(&self) -> alloy_contract::SolCallBuilder<&P, unpauseCall, N> {
            self.call_builder(&unpauseCall)
        }
        ///Creates a new call builder for the [`upgradeTo`] function.
        pub fn upgradeTo(
            &self,
            newImplementation: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, upgradeToCall, N> {
            self.call_builder(&upgradeToCall { newImplementation })
        }
        ///Creates a new call builder for the [`upgradeToAndCall`] function.
        pub fn upgradeToAndCall(
            &self,
            newImplementation: alloy::sol_types::private::Address,
            data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, upgradeToAndCallCall, N> {
            self.call_builder(
                &upgradeToAndCallCall {
                    newImplementation,
                    data,
                },
            )
        }
        ///Creates a new call builder for the [`urc`] function.
        pub fn urc(&self) -> alloy_contract::SolCallBuilder<&P, urcCall, N> {
            self.call_builder(&urcCall)
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LookaheadStoreInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
        ///Creates a new event filter for the [`AdminChanged`] event.
        pub fn AdminChanged_filter(&self) -> alloy_contract::Event<&P, AdminChanged, N> {
            self.event_filter::<AdminChanged>()
        }
        ///Creates a new event filter for the [`BeaconUpgraded`] event.
        pub fn BeaconUpgraded_filter(
            &self,
        ) -> alloy_contract::Event<&P, BeaconUpgraded, N> {
            self.event_filter::<BeaconUpgraded>()
        }
        ///Creates a new event filter for the [`Blacklisted`] event.
        pub fn Blacklisted_filter(&self) -> alloy_contract::Event<&P, Blacklisted, N> {
            self.event_filter::<Blacklisted>()
        }
        ///Creates a new event filter for the [`Initialized`] event.
        pub fn Initialized_filter(&self) -> alloy_contract::Event<&P, Initialized, N> {
            self.event_filter::<Initialized>()
        }
        ///Creates a new event filter for the [`LookaheadPosted`] event.
        pub fn LookaheadPosted_filter(
            &self,
        ) -> alloy_contract::Event<&P, LookaheadPosted, N> {
            self.event_filter::<LookaheadPosted>()
        }
        ///Creates a new event filter for the [`OverseersAdded`] event.
        pub fn OverseersAdded_filter(
            &self,
        ) -> alloy_contract::Event<&P, OverseersAdded, N> {
            self.event_filter::<OverseersAdded>()
        }
        ///Creates a new event filter for the [`OverseersRemoved`] event.
        pub fn OverseersRemoved_filter(
            &self,
        ) -> alloy_contract::Event<&P, OverseersRemoved, N> {
            self.event_filter::<OverseersRemoved>()
        }
        ///Creates a new event filter for the [`OwnershipTransferStarted`] event.
        pub fn OwnershipTransferStarted_filter(
            &self,
        ) -> alloy_contract::Event<&P, OwnershipTransferStarted, N> {
            self.event_filter::<OwnershipTransferStarted>()
        }
        ///Creates a new event filter for the [`OwnershipTransferred`] event.
        pub fn OwnershipTransferred_filter(
            &self,
        ) -> alloy_contract::Event<&P, OwnershipTransferred, N> {
            self.event_filter::<OwnershipTransferred>()
        }
        ///Creates a new event filter for the [`Paused`] event.
        pub fn Paused_filter(&self) -> alloy_contract::Event<&P, Paused, N> {
            self.event_filter::<Paused>()
        }
        ///Creates a new event filter for the [`Unblacklisted`] event.
        pub fn Unblacklisted_filter(
            &self,
        ) -> alloy_contract::Event<&P, Unblacklisted, N> {
            self.event_filter::<Unblacklisted>()
        }
        ///Creates a new event filter for the [`Unpaused`] event.
        pub fn Unpaused_filter(&self) -> alloy_contract::Event<&P, Unpaused, N> {
            self.event_filter::<Unpaused>()
        }
        ///Creates a new event filter for the [`Upgraded`] event.
        pub fn Upgraded_filter(&self) -> alloy_contract::Event<&P, Upgraded, N> {
            self.event_filter::<Upgraded>()
        }
    }
}
