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
///Module containing a contract's types and functions.
/**

```solidity
library OntakeAnchor {
    struct BaseFeeConfig { uint8 adjustmentQuotient; uint8 sharingPctg; uint32 gasIssuancePerSecond; uint64 minGasExcess; uint32 maxGasIssuancePerBlock; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod OntakeAnchor {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BaseFeeConfig { uint8 adjustmentQuotient; uint8 sharingPctg; uint32 gasIssuancePerSecond; uint64 minGasExcess; uint32 maxGasIssuancePerBlock; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BaseFeeConfig {
        #[allow(missing_docs)]
        pub adjustmentQuotient: u8,
        #[allow(missing_docs)]
        pub sharingPctg: u8,
        #[allow(missing_docs)]
        pub gasIssuancePerSecond: u32,
        #[allow(missing_docs)]
        pub minGasExcess: u64,
        #[allow(missing_docs)]
        pub maxGasIssuancePerBlock: u32,
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
            alloy::sol_types::sol_data::Uint<8>,
            alloy::sol_types::sol_data::Uint<32>,
            alloy::sol_types::sol_data::Uint<64>,
            alloy::sol_types::sol_data::Uint<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (u8, u8, u32, u64, u32);
        #[cfg(test)]
        #[allow(dead_code, unreachable_patterns)]
        fn _type_assertion(
            _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
        ) {
            match _t {
                alloy_sol_types::private::AssertTypeEq::<
                    <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                >(_) => {}
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<BaseFeeConfig> for UnderlyingRustTuple<'_> {
            fn from(value: BaseFeeConfig) -> Self {
                (
                    value.adjustmentQuotient,
                    value.sharingPctg,
                    value.gasIssuancePerSecond,
                    value.minGasExcess,
                    value.maxGasIssuancePerBlock,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BaseFeeConfig {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    adjustmentQuotient: tuple.0,
                    sharingPctg: tuple.1,
                    gasIssuancePerSecond: tuple.2,
                    minGasExcess: tuple.3,
                    maxGasIssuancePerBlock: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BaseFeeConfig {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BaseFeeConfig {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.adjustmentQuotient),
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::tokenize(&self.sharingPctg),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.gasIssuancePerSecond),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.minGasExcess),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.maxGasIssuancePerBlock,
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
        impl alloy_sol_types::SolType for BaseFeeConfig {
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
        impl alloy_sol_types::SolStruct for BaseFeeConfig {
            const NAME: &'static str = "BaseFeeConfig";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BaseFeeConfig(uint8 adjustmentQuotient,uint8 sharingPctg,uint32 gasIssuancePerSecond,uint64 minGasExcess,uint32 maxGasIssuancePerBlock)",
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
                        8,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.adjustmentQuotient,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.sharingPctg)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.gasIssuancePerSecond,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.minGasExcess)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.maxGasIssuancePerBlock,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BaseFeeConfig {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.adjustmentQuotient,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        8,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.sharingPctg,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.gasIssuancePerSecond,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.minGasExcess,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.maxGasIssuancePerBlock,
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
                    &rust.adjustmentQuotient,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    8,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.sharingPctg,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.gasIssuancePerSecond,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    64,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.minGasExcess,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.maxGasIssuancePerBlock,
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
    /**Creates a new wrapper around an on-chain [`OntakeAnchor`](self) contract instance.

See the [wrapper's documentation](`OntakeAnchorInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> OntakeAnchorInstance<P, N> {
        OntakeAnchorInstance::<P, N>::new(address, provider)
    }
    /**A [`OntakeAnchor`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`OntakeAnchor`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct OntakeAnchorInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for OntakeAnchorInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("OntakeAnchorInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > OntakeAnchorInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`OntakeAnchor`](self) contract instance.

See the [wrapper's documentation](`OntakeAnchorInstance`) for more details.*/
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
    impl<P: ::core::clone::Clone, N> OntakeAnchorInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> OntakeAnchorInstance<P, N> {
            OntakeAnchorInstance {
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
    > OntakeAnchorInstance<P, N> {
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
    > OntakeAnchorInstance<P, N> {
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
library ShastaAnchor {
    struct State { bytes32 bondInstructionsHash; uint48 anchorBlockNumber; address designatedProver; bool isLowBondProposal; uint48 endOfSubmissionWindowTimestamp; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod ShastaAnchor {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct State { bytes32 bondInstructionsHash; uint48 anchorBlockNumber; address designatedProver; bool isLowBondProposal; uint48 endOfSubmissionWindowTimestamp; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct State {
        #[allow(missing_docs)]
        pub bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub designatedProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub isLowBondProposal: bool,
        #[allow(missing_docs)]
        pub endOfSubmissionWindowTimestamp: alloy::sol_types::private::primitives::aliases::U48,
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Bool,
            alloy::sol_types::sol_data::Uint<48>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::Address,
            bool,
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
        impl ::core::convert::From<State> for UnderlyingRustTuple<'_> {
            fn from(value: State) -> Self {
                (
                    value.bondInstructionsHash,
                    value.anchorBlockNumber,
                    value.designatedProver,
                    value.isLowBondProposal,
                    value.endOfSubmissionWindowTimestamp,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for State {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    bondInstructionsHash: tuple.0,
                    anchorBlockNumber: tuple.1,
                    designatedProver: tuple.2,
                    isLowBondProposal: tuple.3,
                    endOfSubmissionWindowTimestamp: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for State {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for State {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructionsHash),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver,
                    ),
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isLowBondProposal,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.endOfSubmissionWindowTimestamp,
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
        impl alloy_sol_types::SolType for State {
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
        impl alloy_sol_types::SolStruct for State {
            const NAME: &'static str = "State";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "State(bytes32 bondInstructionsHash,uint48 anchorBlockNumber,address designatedProver,bool isLowBondProposal,uint48 endOfSubmissionWindowTimestamp)",
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
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstructionsHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.anchorBlockNumber,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.designatedProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.isLowBondProposal,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.endOfSubmissionWindowTimestamp,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for State {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructionsHash,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.designatedProver,
                    )
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.isLowBondProposal,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.endOfSubmissionWindowTimestamp,
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
                    &rust.bondInstructionsHash,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.anchorBlockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.designatedProver,
                    out,
                );
                <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.isLowBondProposal,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.endOfSubmissionWindowTimestamp,
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
    /**Creates a new wrapper around an on-chain [`ShastaAnchor`](self) contract instance.

See the [wrapper's documentation](`ShastaAnchorInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> ShastaAnchorInstance<P, N> {
        ShastaAnchorInstance::<P, N>::new(address, provider)
    }
    /**A [`ShastaAnchor`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`ShastaAnchor`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct ShastaAnchorInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for ShastaAnchorInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("ShastaAnchorInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ShastaAnchorInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ShastaAnchor`](self) contract instance.

See the [wrapper's documentation](`ShastaAnchorInstance`) for more details.*/
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
    impl<P: ::core::clone::Clone, N> ShastaAnchorInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> ShastaAnchorInstance<P, N> {
            ShastaAnchorInstance {
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
    > ShastaAnchorInstance<P, N> {
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
    > ShastaAnchorInstance<P, N> {
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
library LibBonds {
    type BondType is uint8;
    struct BondInstruction {
        uint48 proposalId;
        BondType bondType;
        address payer;
        address payee;
    }
}

library OntakeAnchor {
    struct BaseFeeConfig {
        uint8 adjustmentQuotient;
        uint8 sharingPctg;
        uint32 gasIssuancePerSecond;
        uint64 minGasExcess;
        uint32 maxGasIssuancePerBlock;
    }
}

library ShastaAnchor {
    struct State {
        bytes32 bondInstructionsHash;
        uint48 anchorBlockNumber;
        address designatedProver;
        bool isLowBondProposal;
        uint48 endOfSubmissionWindowTimestamp;
    }
}

interface TaikoAnchor {
    error ACCESS_DENIED();
    error BlockHashAlreadySet();
    error BondInstructionsHashMismatch();
    error ETH_TRANSFER_FAILED();
    error FUNC_NOT_IMPLEMENTED();
    error INVALID_PAUSE_STATUS();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidForkHeight();
    error L2_BASEFEE_MISMATCH();
    error L2_DEPRECATED_METHOD();
    error L2_FORK_ERROR();
    error L2_INVALID_L1_CHAIN_ID();
    error L2_INVALID_L2_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error REENTRANT_CALL();
    error SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED();
    error ZERO_ADDRESS();
    error ZERO_VALUE();
    error ZeroBlockCount();

    event AdminChanged(address previousAdmin, address newAdmin);
    event Anchored(bytes32 parentHash, uint64 parentGasExcess);
    event BeaconUpgraded(address indexed beacon);
    event EIP1559Update(uint64 oldGasTarget, uint64 newGasTarget, uint64 oldGasExcess, uint64 newGasExcess, uint256 basefee);
    event Initialized(uint8 version);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);
    event Withdrawn(address token, address to, uint256 amount);

    constructor(uint48 _livenessBondGwei, uint48 _provabilityBondGwei, address _signalService, uint64 _pacayaForkHeight, uint64 _shastaForkHeight, address _bondManager);

    function ANCHOR_GAS_LIMIT() external view returns (uint64);
    function BASEFEE_MIN_VALUE() external view returns (uint256);
    function GOLDEN_TOUCH_ADDRESS() external view returns (address);
    function acceptOwnership() external;
    function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) external pure returns (uint64 newGasExcess_);
    function anchor(bytes32 _l1BlockHash, bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) external;
    function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig) external;
    function anchorV3(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig, bytes32[] memory _signalSlots) external;
    function blockIdToEndOfSubmissionWindowTimeStamp(uint256 blockId) external view returns (uint256 endOfSubmissionWindowTimestamp);
    function bondManager() external view returns (address);
    function calculateBaseFee(OntakeAnchor.BaseFeeConfig memory _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) external pure returns (uint256 basefee_, uint64 parentGasExcess_);
    function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) external pure returns (uint256 basefee_, uint64 parentGasExcess_);
    function getBasefeeV2(uint32 _parentGasUsed, uint64 _blockTimestamp, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig) external view returns (uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_);
    function getBlockHash(uint256 _blockId) external view returns (bytes32 blockHash_);
    function getDesignatedProver(uint48 _proposalId, address _proposer, bytes memory _proverAuth) external view returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_);
    function getState() external view returns (ShastaAnchor.State memory);
    function impl() external view returns (address);
    function inNonReentrant() external view returns (bool);
    function init(address _owner, uint64 _l1ChainId, uint64 _initialGasExcess) external;
    function l1ChainId() external view returns (uint64);
    function lastAnchorGasUsed() external view returns (uint32);
    function lastCheckpoint() external view returns (uint64);
    function livenessBondGwei() external view returns (uint48);
    function owner() external view returns (address);
    function pacayaForkHeight() external view returns (uint64);
    function parentGasExcess() external view returns (uint64);
    function parentGasTarget() external view returns (uint64);
    function parentTimestamp() external view returns (uint64);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function provabilityBondGwei() external view returns (uint48);
    function proxiableUUID() external view returns (bytes32);
    function publicInputHash() external view returns (bytes32);
    function renounceOwnership() external;
    function resolver() external view returns (address);
    function shastaForkHeight() external view returns (uint64);
    function signalService() external view returns (address);
    function skipFeeCheck() external pure returns (bool skipCheck_);
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function updateState(uint48 _proposalId, address _proposer, bytes memory _proverAuth, bytes32 _bondInstructionsHash, LibBonds.BondInstruction[] memory _bondInstructions, uint16 _blockIndex, uint48 _anchorBlockNumber, bytes32 _anchorBlockHash, bytes32 _anchorStateRoot, uint48 _endOfSubmissionWindowTimestamp) external returns (ShastaAnchor.State memory previousState_, ShastaAnchor.State memory newState_);
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function withdraw(address _token, address _to) external;
}
```

...which was generated by the following JSON ABI:
```json
[
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_livenessBondGwei",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_provabilityBondGwei",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_signalService",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_pacayaForkHeight",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_shastaForkHeight",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_bondManager",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ANCHOR_GAS_LIMIT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "BASEFEE_MIN_VALUE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "GOLDEN_TOUCH_ADDRESS",
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
    "name": "acceptOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "adjustExcess",
    "inputs": [
      {
        "name": "_currGasExcess",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_currGasTarget",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_newGasTarget",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "outputs": [
      {
        "name": "newGasExcess_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "anchor",
    "inputs": [
      {
        "name": "_l1BlockHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_l1StateRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_l1BlockId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "anchorV2",
    "inputs": [
      {
        "name": "_anchorBlockId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_anchorStateRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "_baseFeeConfig",
        "type": "tuple",
        "internalType": "struct OntakeAnchor.BaseFeeConfig",
        "components": [
          {
            "name": "adjustmentQuotient",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "sharingPctg",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "gasIssuancePerSecond",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "minGasExcess",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxGasIssuancePerBlock",
            "type": "uint32",
            "internalType": "uint32"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "anchorV3",
    "inputs": [
      {
        "name": "_anchorBlockId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_anchorStateRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "_baseFeeConfig",
        "type": "tuple",
        "internalType": "struct OntakeAnchor.BaseFeeConfig",
        "components": [
          {
            "name": "adjustmentQuotient",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "sharingPctg",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "gasIssuancePerSecond",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "minGasExcess",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxGasIssuancePerBlock",
            "type": "uint32",
            "internalType": "uint32"
          }
        ]
      },
      {
        "name": "_signalSlots",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "blockIdToEndOfSubmissionWindowTimeStamp",
    "inputs": [
      {
        "name": "blockId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "endOfSubmissionWindowTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "bondManager",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IBondManager"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateBaseFee",
    "inputs": [
      {
        "name": "_baseFeeConfig",
        "type": "tuple",
        "internalType": "struct OntakeAnchor.BaseFeeConfig",
        "components": [
          {
            "name": "adjustmentQuotient",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "sharingPctg",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "gasIssuancePerSecond",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "minGasExcess",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxGasIssuancePerBlock",
            "type": "uint32",
            "internalType": "uint32"
          }
        ]
      },
      {
        "name": "_blocktime",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_parentGasExcess",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [
      {
        "name": "basefee_",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "parentGasExcess_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getBasefee",
    "inputs": [
      {
        "name": "_anchorBlockId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [
      {
        "name": "basefee_",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "parentGasExcess_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getBasefeeV2",
    "inputs": [
      {
        "name": "_parentGasUsed",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "_blockTimestamp",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_baseFeeConfig",
        "type": "tuple",
        "internalType": "struct OntakeAnchor.BaseFeeConfig",
        "components": [
          {
            "name": "adjustmentQuotient",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "sharingPctg",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "gasIssuancePerSecond",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "minGasExcess",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxGasIssuancePerBlock",
            "type": "uint32",
            "internalType": "uint32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "basefee_",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "newGasTarget_",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "newGasExcess_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBlockHash",
    "inputs": [
      {
        "name": "_blockId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "blockHash_",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getDesignatedProver",
    "inputs": [
      {
        "name": "_proposalId",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_proposer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_proverAuth",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "isLowBondProposal_",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "designatedProver_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "provingFeeToTransfer_",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getState",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ShastaAnchor.State",
        "components": [
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "designatedProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "isLowBondProposal",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "endOfSubmissionWindowTimestamp",
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
    "name": "init",
    "inputs": [
      {
        "name": "_owner",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_l1ChainId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_initialGasExcess",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "l1ChainId",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lastAnchorGasUsed",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lastCheckpoint",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "livenessBondGwei",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
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
    "name": "pacayaForkHeight",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "parentGasExcess",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "parentGasTarget",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "parentTimestamp",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
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
    "name": "provabilityBondGwei",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
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
    "name": "publicInputHash",
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
    "name": "shastaForkHeight",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "signalService",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract ISignalService"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "skipFeeCheck",
    "inputs": [],
    "outputs": [
      {
        "name": "skipCheck_",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
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
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateState",
    "inputs": [
      {
        "name": "_proposalId",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_proposer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_proverAuth",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "_bondInstructionsHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_bondInstructions",
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
        "name": "_blockIndex",
        "type": "uint16",
        "internalType": "uint16"
      },
      {
        "name": "_anchorBlockNumber",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_anchorBlockHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_anchorStateRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_endOfSubmissionWindowTimestamp",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [
      {
        "name": "previousState_",
        "type": "tuple",
        "internalType": "struct ShastaAnchor.State",
        "components": [
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "designatedProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "isLowBondProposal",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "endOfSubmissionWindowTimestamp",
            "type": "uint48",
            "internalType": "uint48"
          }
        ]
      },
      {
        "name": "newState_",
        "type": "tuple",
        "internalType": "struct ShastaAnchor.State",
        "components": [
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "designatedProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "isLowBondProposal",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "endOfSubmissionWindowTimestamp",
            "type": "uint48",
            "internalType": "uint48"
          }
        ]
      }
    ],
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
    "name": "withdraw",
    "inputs": [
      {
        "name": "_token",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_to",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "Anchored",
    "inputs": [
      {
        "name": "parentHash",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "parentGasExcess",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
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
    "name": "EIP1559Update",
    "inputs": [
      {
        "name": "oldGasTarget",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "newGasTarget",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "oldGasExcess",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "newGasExcess",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "basefee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
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
    "type": "event",
    "name": "Withdrawn",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
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
    "name": "BlockHashAlreadySet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BondInstructionsHashMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ETH_TRANSFER_FAILED",
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
    "name": "InvalidAnchorBlockNumber",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidBlockIndex",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidForkHeight",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_BASEFEE_MISMATCH",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_DEPRECATED_METHOD",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_FORK_ERROR",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_INVALID_L1_CHAIN_ID",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_INVALID_L2_CHAIN_ID",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_INVALID_SENDER",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_PUBLIC_INPUT_HASH_MISMATCH",
    "inputs": []
  },
  {
    "type": "error",
    "name": "L2_TOO_LATE",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NonZeroAnchorBlockHash",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NonZeroAnchorStateRoot",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NonZeroBlockIndex",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ProposalIdMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ProposerMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "REENTRANT_CALL",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED",
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
  },
  {
    "type": "error",
    "name": "ZeroBlockCount",
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
pub mod TaikoAnchor {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x61018060405230608052348015610014575f5ffd5b50604051613ffd380380613ffd833981016040819052610033916101d7565b8585858585858383836100446100d5565b6001600160a01b0390921660c0526001600160401b0390811660e05290811661010052821615806100865750826001600160401b0316826001600160401b0316115b6100a357604051630174792f60e11b815260040160405180910390fd5b65ffffffffffff95861661012052939094166101405250506001600160a01b0316610160525061024795505050505050565b5f54610100900460ff16156101405760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b5f5460ff9081161461018f575f805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b805165ffffffffffff811681146101a6575f5ffd5b919050565b80516001600160a01b03811681146101a6575f5ffd5b80516001600160401b03811681146101a6575f5ffd5b5f5f5f5f5f5f60c087890312156101ec575f5ffd5b6101f587610191565b955061020360208801610191565b9450610211604088016101ab565b935061021f606088016101c1565b925061022d608088016101c1565b915061023b60a088016101ab565b90509295509295509295565b60805160a05160c05160e05161010051610120516101405161016051613cdd6103205f395f81816104370152818161149e015281816115340152818161190c015281816119d9015281816123e8015261248001525f81816105cc015261238601525f818161069f015261234201525f818161091f01528181610c0201528181610c2b015261138b01525f81816107c30152610bb001525f8181610571015281816116010152611e4001525f61027c01525f81816109d501528181610a1e01528181610cc801528181610d080152610d830152613cdd5ff3fe60806040526004361061026a575f3560e01c80638abf60771161014a578063cbd9999e116100be578063ee82ac5e11610078578063ee82ac5e146108a3578063f2a49b00146108c2578063f2fde38b146108ef578063f37f28681461090e578063f940e38514610941578063fd85eb2d14610960575f5ffd5b8063cbd9999e146107fb578063d32e81a514610812578063da69d3db14610838578063dac5df7814610857578063e30c39781461086c578063e902461a14610889575f5ffd5b8063a7e022d11161010f578063a7e022d11461070c578063b2105fec14610748578063b310e9e914610774578063b8c7b30c14610793578063ba9f41e8146107b2578063c46e3a66146107e5575f5ffd5b80638abf60771461065d5780638da5cb5b146106715780639de746791461068e5780639ee512f2146106c1578063a7137c0f146106e6575f5ffd5b80634ef77eb5116101e157806362d09453116101a657806362d0945314610560578063715018a61461059357806379ba5097146105a757806379efb434146105bb5780638456cb5914610605578063893f546014610619575f5ffd5b80634ef77eb5146104ad5780634f1ef286146104e557806352d1902d146104f8578063539b8ade1461051a5780635c975abb14610540575f5ffd5b80632f980473116102325780632f980473146103f45780633075db5614610412578063363cc427146104265780633659cfe6146104595780633f4ba83a1461047a57806348080a451461048e575f5ffd5b806304f3bcec1461026e57806312622e5b146102b9578063136dc4a8146102f05780631865c57d1461030f5780631c418a44146103b0575b5f5ffd5b348015610279575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b3480156102c4575f5ffd5b5060fe546102d8906001600160401b031681565b6040516001600160401b0390911681526020016102b0565b3480156102fb575f5ffd5b506102d861030a366004613201565b61097a565b34801561031a575f5ffd5b506103a36040805160a0810182525f80825260208201819052918101829052606081018290526080810191909152506040805160a08101825261012d54815261012e5465ffffffffffff8082166020840152600160301b82046001600160a01b031693830193909352600160d01b900460ff161515606082015261012f54909116608082015290565b6040516102b0919061328b565b3480156103bb575f5ffd5b506103cf6103ca366004613301565b610994565b6040805193151584526001600160a01b039092166020840152908201526060016102b0565b3480156103ff575f5ffd5b505f5b60405190151581526020016102b0565b34801561041d575f5ffd5b506104026109b3565b348015610431575f5ffd5b5061029c7f000000000000000000000000000000000000000000000000000000000000000081565b348015610464575f5ffd5b5061047861047336600461335d565b6109cb565b005b348015610485575f5ffd5b50610478610a9b565b348015610499575f5ffd5b506104786104a8366004613399565b610af6565b3480156104b8575f5ffd5b5060fe546104d090600160401b900463ffffffff1681565b60405163ffffffff90911681526020016102b0565b6104786104f336600461350a565b610cbe565b348015610503575f5ffd5b5061050c610d77565b6040519081526020016102b0565b348015610525575f5ffd5b5060fd546102d890600160801b90046001600160401b031681565b34801561054b575f5ffd5b5061040260c954610100900460ff1660021490565b34801561056b575f5ffd5b5061029c7f000000000000000000000000000000000000000000000000000000000000000081565b34801561059e575f5ffd5b50610478610e28565b3480156105b2575f5ffd5b50610478610e39565b3480156105c6575f5ffd5b506105ee7f000000000000000000000000000000000000000000000000000000000000000081565b60405165ffffffffffff90911681526020016102b0565b348015610610575f5ffd5b50610478610eb0565b348015610624575f5ffd5b50610638610633366004613554565b610f05565b604080519384526001600160401b0392831660208501529116908201526060016102b0565b348015610668575f5ffd5b5061029c611045565b34801561067c575f5ffd5b506033546001600160a01b031661029c565b348015610699575f5ffd5b506105ee7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106cc575f5ffd5b5061029c71777735367b36bc9b61c50022d9d0700db4ec81565b3480156106f1575f5ffd5b5060fd546102d890600160c01b90046001600160401b031681565b348015610717575f5ffd5b5061072b61072636600461358c565b611053565b604080519283526001600160401b039091166020830152016102b0565b348015610753575f5ffd5b5061050c6107623660046135bd565b6101306020525f908152604090205481565b34801561077f575f5ffd5b5061047861078e3660046135d4565b61106e565b34801561079e575f5ffd5b5060fd546102d8906001600160401b031681565b3480156107bd575f5ffd5b506102d87f000000000000000000000000000000000000000000000000000000000000000081565b3480156107f0575f5ffd5b506102d8620f424081565b348015610806575f5ffd5b5061050c63017d784081565b34801561081d575f5ffd5b5060fd546102d890600160401b90046001600160401b031681565b348015610843575f5ffd5b506104786108523660046135ef565b6112a0565b348015610862575f5ffd5b5061050c60fc5481565b348015610877575f5ffd5b506065546001600160a01b031661029c565b348015610894575f5ffd5b5061072b610726366004613632565b3480156108ae575f5ffd5b5061050c6108bd3660046135bd565b6112b9565b3480156108cd575f5ffd5b506108e16108dc3660046136cb565b6112f1565b6040516102b09291906137a9565b3480156108fa575f5ffd5b5061047861090936600461335d565b61171b565b348015610919575f5ffd5b506102d87f000000000000000000000000000000000000000000000000000000000000000081565b34801561094c575f5ffd5b5061047861095b3660046137c5565b61178c565b34801561096b575f5ffd5b506104786108523660046137ed565b5f6040516372c0090b60e11b815260040160405180910390fd5b5f5f5f6109a3878787876118b8565b9250925092509450945094915050565b5f60026109c260c95460ff1690565b60ff1614905090565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610a1c5760405162461bcd60e51b8152600401610a139061382e565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610a4e611a5d565b6001600160a01b031614610a745760405162461bcd60e51b8152600401610a139061387a565b610a7d81611a78565b604080515f80825260208201909252610a9891839190611a80565b50565b610aa3611bea565b610ab760c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610af4335f611c1b565b565b84610b0081611c23565b866001600160401b0316610b1381611c44565b610b2360608601604087016138c6565b63ffffffff16610b3281611c44565b610b3f60208701876138df565b60ff16610b4b81611c44565b3371777735367b36bc9b61c50022d9d0700db4ec14610b7d57604051636494e9f760e01b815260040160405180910390fd5b610b85611c64565b610b8f6002611c93565b8415610bae57604051639951d2e960e01b815260040160405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b0316431015610bf857604051631799c89b60e01b815260040160405180910390fd5b6001600160401b037f0000000000000000000000000000000000000000000000000000000000000000161580610c5657507f00000000000000000000000000000000000000000000000000000000000000006001600160401b031643105b610c7357604051631799c89b60e01b815260040160405180910390fd5b5f610c7f600143613913565b9050610c8a81611ca9565b610c948989611ce1565b610c9e8b8b611dc8565b610ca781611ee6565b50610cb26001611c93565b50505050505050505050565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610d065760405162461bcd60e51b8152600401610a139061382e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610d38611a5d565b6001600160a01b031614610d5e5760405162461bcd60e51b8152600401610a139061387a565b610d6782611a78565b610d7382826001611a80565b5050565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610e165760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a13565b505f516020613c615f395f51905f5290565b610e30611f7d565b610af45f611fd7565b60655433906001600160a01b03168114610ea75760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a13565b610a9881611fd7565b610eb8611ff0565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610af4336001611c1b565b5f808080610f1660208601866138df565b60ff16610f2960608701604088016138c6565b63ffffffff16610f399190613926565b60fd54909150610f5d906001600160401b03600160c01b8204811691849116612022565b90935091505f610f7360608701604088016138c6565b63ffffffff1660fd60109054906101000a90046001600160401b031688610f9a919061394f565b610fa49190613926565b9050610fb660a08701608088016138c6565b63ffffffff1615801590610fe75750610fd560a08701608088016138c6565b63ffffffff16816001600160401b0316115b1561100557610ffc60a08701608088016138c6565b63ffffffff1690505b6110218484838b61101c60808c0160608d0161396e565b61213a565b909550925063017d784085101561103a5763017d784094505b505093509350939050565b5f61104e611a5d565b905090565b5f5f6040516372c0090b60e11b815260040160405180910390fd5b5f54610100900460ff161580801561108c57505f54600160ff909116105b806110a55750303b1580156110a557505f5460ff166001145b6111085760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b6064820152608401610a13565b5f805460ff191660011790558015611129575f805461ff0019166101001790555b611132846121ba565b826001600160401b03165f0361115b576040516308279a2560e31b815260040160405180910390fd5b46836001600160401b031603611184576040516308279a2560e31b815260040160405180910390fd5b600146116111a557604051638f972ecb60e01b815260040160405180910390fd5b6001600160401b034611156111cd57604051638f972ecb60e01b815260040160405180910390fd5b431561121757436001036111fe575f6111e7600143613913565b5f81815260fb602052604090209040905550611217565b604051635a0f9e4160e11b815260040160405180910390fd5b60fe80546001600160401b0380861667ffffffffffffffff199283161790925560fd80549285169290911691909117905561125143612218565b5060fc55801561129a575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b50505050565b6040516372c0090b60e11b815260040160405180910390fd5b5f4382106112c857505f919050565b436112d583610100613987565b106112df57504090565b505f90815260fb602052604090205490565b6040805160a0810182525f808252602082018190529181018290526060810182905260808101919091526040805160a0810182525f808252602082018190529181018290526060810182905260808101919091523371777735367b36bc9b61c50022d9d0700db4ec1461137757604051636494e9f760e01b815260040160405180910390fd5b61137f611c64565b6113896002611c93565b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b03164310156113d357604051631799c89b60e01b815260040160405180910390fd5b50506040805160a08101825261012d54815261012e5465ffffffffffff8082166020840152600160301b82046001600160a01b031693830193909352600160d01b900460ff161515606082015261012f5490911660808201528061144061143b600143613913565b6122a8565b8661ffff165f0361159d575f6114588f8f8f8f6118b8565b6001600160a01b03909116604085015290151560608401529050801561158e57604051631c89cb6f60e11b81526001600160a01b038f81166004830152602482018390527f0000000000000000000000000000000000000000000000000000000000000000169063391396de906044016020604051808303815f875af11580156114e4573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611508919061399a565b506040828101519051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b158015611577575f5ffd5b505af1158015611589573d5f5f3e3d5ffd5b505050505b6115998a8a8d6122e7565b8252505b816020015165ffffffffffff168665ffffffffffff16111561166f576040805160608101825265ffffffffffff8881168252602082018881528284018881529351631934171960e31b815292519091166004830152516024820152905160448201527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03169063c9a0b8c8906064015f604051808303815f87803b15801561164a575f5ffd5b505af115801561165c573d5f5f3e3d5ffd5b50505065ffffffffffff87166020830152505b65ffffffffffff80841660808301819052825161012d5560208084015161012e805460408088015160608901511515600160d01b0260ff60d01b196001600160a01b03909216600160301b026001600160d01b0319909416959098169490941791909117929092169490941790935561012f805465ffffffffffff191683179055435f908152610130909152919091205561170a6001611c93565b9c509c9a5050505050505050505050565b611723611f7d565b606580546001600160a01b0383166001600160a01b031990911681179091556117546033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b806117968161251b565b61179e611ff0565b6117a6611f7d565b6117ae611c64565b6117b86002611c93565b5f6001600160a01b0384166117e15750476117dc6001600160a01b03841682612542565b61185d565b6040516370a0823160e01b81523060048201526001600160a01b038516906370a0823190602401602060405180830381865afa158015611823573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611847919061399a565b905061185d6001600160a01b038516848361254d565b604080516001600160a01b038087168252851660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a1506118b36001611c93565b505050565b5f5f5f5f6118c88888888861259f565b90935065ffffffffffff1690506118e3633b9aca00826139b1565b60405163508b724360e11b81526001600160a01b038981166004830152602482018390529192507f00000000000000000000000000000000000000000000000000000000000000009091169063a116e48690604401602060405180830381865afa158015611953573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061197791906139c8565b159350831561199b5761012e54600160301b90046001600160a01b03169250611a52565b866001600160a01b0316836001600160a01b031614611a525760405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015611a1e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611a4291906139c8565b611a4e57869250611a52565b8091505b509450945094915050565b5f516020613c615f395f51905f52546001600160a01b031690565b610a98611f7d565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff1615611ab3576118b3836126df565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa925050508015611b0d575060408051601f3d908101601f19168201909252611b0a9181019061399a565b60015b611b705760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a13565b5f516020613c615f395f51905f528114611bde5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a13565b506118b383838361277a565b611bfe60c954610100900460ff1660021490565b610af45760405163bae6e2a960e01b815260040160405180910390fd5b610d73611f7d565b5f819003610a985760405163ec73295960e01b815260040160405180910390fd5b805f03610a985760405163ec73295960e01b815260040160405180910390fd5b6002611c7260c95460ff1690565b60ff1603610af45760405163dfc60d8560e01b815260040160405180910390fd5b60c9805460ff191660ff92909216919091179055565b5f5f611cb483612218565b915091508160fc5414611cda5760405163d719258d60e01b815260040160405180910390fd5b60fc555050565b5f5f5f611cef854286610f05565b92509250925082481480611d0057505f5b611d1d576040516336d54d4f60e11b815260040160405180910390fd5b60fd5460408051600160c01b83046001600160401b039081168252858116602083015292831681830152918316606083015260808201859052517f781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c89181900360a00190a160fd805477ffffffffffffffffffffffffffffffff000000000000000016600160c01b6001600160401b039485160267ffffffffffffffff19161791909216179055505050565b60fd546001600160401b03600160401b909104811690831611611de9575050565b60fe546040516313e4299d60e21b81526001600160401b0391821660048201527f73e6d340850343cc6f001515dc593377337c95a6ffe034fe1e844d4dab5da16960248201529083166044820152606481018290527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031690634f90a674906084016020604051808303815f875af1158015611e8e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611eb2919061399a565b505060fd80546001600160401b03909216600160401b026fffffffffffffffff000000000000000019909216919091179055565b5f81815260fb60205260409081902082409081905560fd80546001600160401b03428116600160801b0267ffffffffffffffff60801b1983168117909355935192937f41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe493611f71938693908316921691909117909182526001600160401b0316602082015260400190565b60405180910390a15050565b6033546001600160a01b03163314610af45760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a13565b606580546001600160a01b0319169055610a988161279e565b61200460c954610100900460ff1660021490565b15610af45760405163bae6e2a960e01b815260040160405180910390fd5b5f80670de0b6b3a76400006001600160401b03861682036120495784849250925050612132565b6001600160401b03851615806120705750846001600160401b0316866001600160401b0316145b8061208e5750612081815f196139fb565b856001600160401b031610155b1561209f5785849250925050612132565b5f866001600160401b0316866001600160401b0316836120bf91906139b1565b6120c991906139fb565b90508015806120de57506001600160ff1b0381115b156120f0578585935093505050612132565b5f6120fa826127ef565b90505f828702828902015f81126001811461211957858204925061211d565b5f92505b50508761212982612a0c565b95509550505050505b935093915050565b5f808061215663ffffffff86166001600160401b038916613987565b9050856001600160401b0316811161216f576001612182565b6121826001600160401b03871682613913565b90506121a16001600160401b0361219b83878316612a24565b90612a3b565b91506121ad8883612a4f565b9250509550959350505050565b5f54610100900460ff166121e05760405162461bcd60e51b8152600401610a1390613a0e565b6121e8612a91565b6122066001600160a01b038216156122005781611fd7565b33611fd7565b5060c9805461ff001916610100179055565b5f5f6122226131c6565b46611fe08201525f5b60ff8110801561223e5750806001018510155b1561226f575f198186030180408360ff8306610100811061226157612261613a59565b60200201525060010161222b565b506120008120925083408161228560ff87613a6d565b610100811061229657612296613a59565b60200201526120009020919391925050565b5f81815260fb6020526040902054156122d45760405163614dc56760e01b815260040160405180910390fd5b5f81815260fb6020526040902090409055565b61012d54825f5b818110156124f2575f86868381811061230957612309613a59565b90506080020180360381019061231f9190613a80565b90505f60028260200151600281111561233a5761233a613ae4565b0361236657507f00000000000000000000000000000000000000000000000000000000000000006123a6565b60018260200151600281111561237e5761237e613ae4565b036123a657507f00000000000000000000000000000000000000000000000000000000000000005b65ffffffffffff8116156124d9576040828101519051631c89cb6f60e11b81526001600160a01b03918216600482015265ffffffffffff831660248201525f917f0000000000000000000000000000000000000000000000000000000000000000169063391396de906044016020604051808303815f875af115801561242e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612452919061399a565b6060840151604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390529192507f0000000000000000000000000000000000000000000000000000000000000000169063be32d1f4906044015f604051808303815f87803b1580156124c1575f5ffd5b505af11580156124d3573d5f5f3e3d5ffd5b50505050505b6124e38583612ab7565b945050508060010190506122ee565b50828214612513576040516388c4700b60e01b815260040160405180910390fd5b509392505050565b6001600160a01b038116610a985760405163538ba4f960e01b815260040160405180910390fd5b610d7382825a612b15565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b1790526118b3908490612b58565b5f8060a18310156125b457508390505f6126d6565b5f6125c184860186613af8565b90508665ffffffffffff16815f015165ffffffffffff161415806125fb5750856001600160a01b031681602001516001600160a01b031614155b1561260c57855f92509250506126d6565b8051602080830151604080850151815165ffffffffffff958616948101949094526001600160a01b03909216908301529190911660608201525f906080016040516020818303038152906040528051906020012090505f5f612672838560600151612c2b565b90925090505f81600481111561268a5761268a613ae4565b14801561269f57506001600160a01b03821615155b156126cd57819550886001600160a01b0316866001600160a01b0316146126c857836040015194505b6126d1565b8895505b505050505b94509492505050565b6001600160a01b0381163b61274c5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a13565b5f516020613c615f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b61278383612c6d565b5f8251118061278f5750805b156118b35761129a8383612cac565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b6fffffffffffffffffffffffffffffffff811160071b81811c6001600160401b031060061b1781811c63ffffffff1060051b1781811c61ffff1060041b1781811c60ff1060031b175f821361284b57631615e6385f526004601cfd5b7ff8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff6f8421084210842108cc6318c6db6d54be83831c1c601f161a1890811b609f90811c6c465772b2bbbb5f824b15207a3081018102606090811d6d0388eaa27412d5aca026815d636e018202811d6d0df99ac502031bf953eff472fdcc018202811d6d13cdffb29d51d99322bdff5f2211018202811d6d0a0f742023def783a307a986912e018202811d6d01920d8043ca89b5239253284e42018202811d6c0b7a86d7375468fac667a0a527016c29508e458543d8aa4df2abee7883018302821d6d0139601a2efabe717e604cbb4894018302821d6d02247f7a7b6594320649aa03aba1018302821d6c8c3f38e95a6b1ff2ab1c3b343619018302821d6d02384773bdf1ac5676facced60901901830290911d6cb9a025d814b29c212b8b1a07cd1901909102780a09507084cc699bb0e71ea869ffffffffffffffffffffffff190105711340daa0d5f769dba1915cef59f0815a5506029190037d0267a36c0c95b3975ab3ee5b203a7614a3f75373f047d803ae7b6687f2b302017d57115e47018c7177eebf7cd370a3356a1b7863008a5ae8028c72b88642840160ae1d90565b5f612a1e826001600160401b03612a3b565b92915050565b5f818311612a325781612a34565b825b9392505050565b5f818311612a495782612a34565b50919050565b5f826001600160401b03165f03612a6857506001612a1e565b612a346001846001600160401b0316612a818686612cd1565b612a8b91906139fb565b90612a24565b5f54610100900460ff16610af45760405162461bcd60e51b8152600401610a1390613a0e565b80515f9065ffffffffffff161580612ae357505f82602001516002811115612ae157612ae1613ae4565b145b612a32578282604051602001612afa929190613b95565b60405160208183030381529060405280519060200120612a34565b815f03612b2157505050565b612b3b83838360405180602001604052805f815250612d5f565b6118b357604051634c67134d60e11b815260040160405180910390fd5b5f612bac826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b0316612d9c9092919063ffffffff16565b905080515f1480612bcc575080806020019051810190612bcc91906139c8565b6118b35760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608401610a13565b5f5f8251604103612c5f576020830151604084015160608501515f1a612c5387828585612daa565b94509450505050612c66565b505f905060025b9250929050565b612c76816126df565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060612a348383604051806060016040528060278152602001613c8160279139612e64565b5f826001600160401b03165f03612cea57612cea613c01565b5f836001600160401b0316836001600160401b0316670de0b6b3a7640000612d1291906139b1565b612d1c91906139fb565b9050680755bf798b4a1bf1e4811115612d3b5750680755bf798b4a1bf1e45b670de0b6b3a7640000612d4d82612ed8565b612d5791906139fb565b949350505050565b5f6001600160a01b038516612d8757604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b6060612d5784845f85613052565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115612ddf57505f905060036126d6565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612e30573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612e58575f600192509250506126d6565b965f9650945050505050565b60605f5f856001600160a01b031685604051612e809190613c15565b5f60405180830381855af49150503d805f8114612eb8576040519150601f19603f3d011682016040523d82523d5f602084013e612ebd565b606091505b5091509150612ece86838387613129565b9695505050505050565b5f68023f2fa8f6da5b9d28198213612eef57919050565b680755bf798b4a1bf1e58212612f0c5763a37bfec95f526004601cfd5b6503782dace9d9604e83901b0591505f60606bb17217f7d1cf79abc9e3b39884821b056001605f1b01901d6bb17217f7d1cf79abc9e3b39881029093036c240c330e9fb2d9cbaf0fd5aafb1981018102606090811d6d0277594991cfc85f6e2461837cd9018202811d6d1a521255e34f6a5061b25ef1c9c319018202811d6db1bbb201f443cf962f1a1d3db4a5018202811d6e02c72388d9f74f51a9331fed693f1419018202811d6e05180bb14799ab47a8a8cb2a527d57016d02d16720577bd19bf614176fe9ea6c10fe68e7fd37d0007b713f765084018402831d9081019084016d01d3967ed30fc4f89c02bab5708119010290911d6e0587f503bb6ea29d25fcb740196450019091026d360d7aeea093263ecc6e0ecb291760621b010574029d9dc38563c32e5c2f6dc192ee70ef65f9978af30260c3939093039290921c92915050565b6060824710156130b35760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b6064820152608401610a13565b5f5f866001600160a01b031685876040516130ce9190613c15565b5f6040518083038185875af1925050503d805f8114613108576040519150601f19603f3d011682016040523d82523d5f602084013e61310d565b606091505b509150915061311e87838387613129565b979650505050505050565b606083156131975782515f03613190576001600160a01b0385163b6131905760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a13565b5081612d57565b612d5783838151156131ac5781518083602001fd5b8060405162461bcd60e51b8152600401610a139190613c2b565b604051806120000160405280610100906020820280368337509192915050565b80356001600160401b03811681146131fc575f5ffd5b919050565b5f5f5f60608486031215613213575f5ffd5b61321c846131e6565b925061322a602085016131e6565b9150613238604085016131e6565b90509250925092565b8051825265ffffffffffff602082015116602083015260018060a01b03604082015116604083015260608101511515606083015265ffffffffffff60808201511660808301525050565b60a08101612a1e8284613241565b803565ffffffffffff811681146131fc575f5ffd5b80356001600160a01b03811681146131fc575f5ffd5b5f5f83601f8401126132d4575f5ffd5b5081356001600160401b038111156132ea575f5ffd5b602083019150836020828501011115612c66575f5ffd5b5f5f5f5f60608587031215613314575f5ffd5b61331d85613299565b935061332b602086016132ae565b925060408501356001600160401b03811115613345575f5ffd5b613351878288016132c4565b95989497509550505050565b5f6020828403121561336d575f5ffd5b612a34826132ae565b803563ffffffff811681146131fc575f5ffd5b5f60a08284031215612a49575f5ffd5b5f5f5f5f5f5f61012087890312156133af575f5ffd5b6133b8876131e6565b9550602087013594506133cd60408801613376565b93506133dc8860608901613389565b92506101008701356001600160401b038111156133f7575f5ffd5b8701601f81018913613407575f5ffd5b80356001600160401b0381111561341c575f5ffd5b8960208260051b8401011115613430575f5ffd5b60208201935080925050509295509295509295565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b038111828210171561347b5761347b613445565b60405290565b5f82601f830112613490575f5ffd5b81356001600160401b038111156134a9576134a9613445565b604051601f8201601f19908116603f011681016001600160401b03811182821017156134d7576134d7613445565b6040528181528382016020018510156134ee575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f6040838503121561351b575f5ffd5b613524836132ae565b915060208301356001600160401b0381111561353e575f5ffd5b61354a85828601613481565b9150509250929050565b5f5f5f60e08486031215613566575f5ffd5b61356f84613376565b925061357d602085016131e6565b91506132388560408601613389565b5f5f6040838503121561359d575f5ffd5b6135a6836131e6565b91506135b460208401613376565b90509250929050565b5f602082840312156135cd575f5ffd5b5035919050565b5f5f5f606084860312156135e6575f5ffd5b61321c846132ae565b5f5f5f5f60808587031215613602575f5ffd5b8435935060208501359250613619604086016131e6565b915061362760608601613376565b905092959194509250565b5f5f5f5f6101008587031215613646575f5ffd5b6136508686613389565b935061365e60a086016131e6565b925061366c60c086016131e6565b915061362760e08601613376565b5f5f83601f84011261368a575f5ffd5b5081356001600160401b038111156136a0575f5ffd5b6020830191508360208260071b8501011115612c66575f5ffd5b803561ffff811681146131fc575f5ffd5b5f5f5f5f5f5f5f5f5f5f5f5f6101408d8f0312156136e7575f5ffd5b6136f08d613299565b9b506136fe60208e016132ae565b9a506001600160401b0360408e01351115613717575f5ffd5b6137278e60408f01358f016132c4565b909a50985060608d013597506001600160401b0360808e0135111561374a575f5ffd5b61375a8e60808f01358f0161367a565b909750955061376b60a08e016136ba565b945061377960c08e01613299565b935060e08d013592506101008d013591506137976101208e01613299565b90509295989b509295989b509295989b565b61014081016137b88285613241565b612a3460a0830184613241565b5f5f604083850312156137d6575f5ffd5b6137df836132ae565b91506135b4602084016132ae565b5f5f5f5f6101008587031215613801575f5ffd5b61380a856131e6565b93506020850135925061381f60408601613376565b91506136278660608701613389565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b5f602082840312156138d6575f5ffd5b612a3482613376565b5f602082840312156138ef575f5ffd5b813560ff81168114612a34575f5ffd5b634e487b7160e01b5f52601160045260245ffd5b81810381811115612a1e57612a1e6138ff565b6001600160401b038181168382160290811690818114613948576139486138ff565b5092915050565b6001600160401b038281168282160390811115612a1e57612a1e6138ff565b5f6020828403121561397e575f5ffd5b612a34826131e6565b80820180821115612a1e57612a1e6138ff565b5f602082840312156139aa575f5ffd5b5051919050565b8082028115828204841417612a1e57612a1e6138ff565b5f602082840312156139d8575f5ffd5b81518015158114612a34575f5ffd5b634e487b7160e01b5f52601260045260245ffd5b5f82613a0957613a096139e7565b500490565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b634e487b7160e01b5f52603260045260245ffd5b5f82613a7b57613a7b6139e7565b500690565b5f6080828403128015613a91575f5ffd5b50613a9a613459565b613aa383613299565b8152602083013560038110613ab6575f5ffd5b6020820152613ac7604084016132ae565b6040820152613ad8606084016132ae565b60608201529392505050565b634e487b7160e01b5f52602160045260245ffd5b5f60208284031215613b08575f5ffd5b81356001600160401b03811115613b1d575f5ffd5b820160808185031215613b2e575f5ffd5b613b36613459565b613b3f82613299565b8152613b4d602083016132ae565b6020820152613b5e60408301613299565b604082015260608201356001600160401b03811115613b7b575f5ffd5b613b8786828501613481565b606083015250949350505050565b5f60a08201905083825265ffffffffffff8351166020830152602083015160038110613bcf57634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b634e487b7160e01b5f52600160045260245ffd5b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212203c060b1097ef69f4151a7b22bfc3aedd7dddba0a962464433c4f41905e7682da64736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01\x80`@R0`\x80R4\x80\x15a\0\x14W__\xFD[P`@Qa?\xFD8\x03\x80a?\xFD\x839\x81\x01`@\x81\x90Ra\x003\x91a\x01\xD7V[\x85\x85\x85\x85\x85\x85\x83\x83\x83a\0Da\0\xD5V[`\x01`\x01`\xA0\x1B\x03\x90\x92\x16`\xC0R`\x01`\x01`@\x1B\x03\x90\x81\x16`\xE0R\x90\x81\x16a\x01\0R\x82\x16\x15\x80a\0\x86WP\x82`\x01`\x01`@\x1B\x03\x16\x82`\x01`\x01`@\x1B\x03\x16\x11[a\0\xA3W`@Qc\x01ty/`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[e\xFF\xFF\xFF\xFF\xFF\xFF\x95\x86\x16a\x01 R\x93\x90\x94\x16a\x01@RPP`\x01`\x01`\xA0\x1B\x03\x16a\x01`RPa\x02G\x95PPPPPPV[_Ta\x01\0\x90\x04`\xFF\x16\x15a\x01@W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FInitializable: contract is initi`D\x82\x01Rfalizing`\xC8\x1B`d\x82\x01R`\x84\x01`@Q\x80\x91\x03\x90\xFD[_T`\xFF\x90\x81\x16\x14a\x01\x8FW_\x80T`\xFF\x19\x16`\xFF\x90\x81\x17\x90\x91U`@Q\x90\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[V[\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x01\xA6W__\xFD[\x91\x90PV[\x80Q`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x01\xA6W__\xFD[\x80Q`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x01\xA6W__\xFD[______`\xC0\x87\x89\x03\x12\x15a\x01\xECW__\xFD[a\x01\xF5\x87a\x01\x91V[\x95Pa\x02\x03` \x88\x01a\x01\x91V[\x94Pa\x02\x11`@\x88\x01a\x01\xABV[\x93Pa\x02\x1F``\x88\x01a\x01\xC1V[\x92Pa\x02-`\x80\x88\x01a\x01\xC1V[\x91Pa\x02;`\xA0\x88\x01a\x01\xABV[\x90P\x92\x95P\x92\x95P\x92\x95V[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x01 Qa\x01@Qa\x01`Qa<\xDDa\x03 _9_\x81\x81a\x047\x01R\x81\x81a\x14\x9E\x01R\x81\x81a\x154\x01R\x81\x81a\x19\x0C\x01R\x81\x81a\x19\xD9\x01R\x81\x81a#\xE8\x01Ra$\x80\x01R_\x81\x81a\x05\xCC\x01Ra#\x86\x01R_\x81\x81a\x06\x9F\x01Ra#B\x01R_\x81\x81a\t\x1F\x01R\x81\x81a\x0C\x02\x01R\x81\x81a\x0C+\x01Ra\x13\x8B\x01R_\x81\x81a\x07\xC3\x01Ra\x0B\xB0\x01R_\x81\x81a\x05q\x01R\x81\x81a\x16\x01\x01Ra\x1E@\x01R_a\x02|\x01R_\x81\x81a\t\xD5\x01R\x81\x81a\n\x1E\x01R\x81\x81a\x0C\xC8\x01R\x81\x81a\r\x08\x01Ra\r\x83\x01Ra<\xDD_\xF3\xFE`\x80`@R`\x046\x10a\x02jW_5`\xE0\x1C\x80c\x8A\xBF`w\x11a\x01JW\x80c\xCB\xD9\x99\x9E\x11a\0\xBEW\x80c\xEE\x82\xAC^\x11a\0xW\x80c\xEE\x82\xAC^\x14a\x08\xA3W\x80c\xF2\xA4\x9B\0\x14a\x08\xC2W\x80c\xF2\xFD\xE3\x8B\x14a\x08\xEFW\x80c\xF3\x7F(h\x14a\t\x0EW\x80c\xF9@\xE3\x85\x14a\tAW\x80c\xFD\x85\xEB-\x14a\t`W__\xFD[\x80c\xCB\xD9\x99\x9E\x14a\x07\xFBW\x80c\xD3.\x81\xA5\x14a\x08\x12W\x80c\xDAi\xD3\xDB\x14a\x088W\x80c\xDA\xC5\xDFx\x14a\x08WW\x80c\xE3\x0C9x\x14a\x08lW\x80c\xE9\x02F\x1A\x14a\x08\x89W__\xFD[\x80c\xA7\xE0\"\xD1\x11a\x01\x0FW\x80c\xA7\xE0\"\xD1\x14a\x07\x0CW\x80c\xB2\x10_\xEC\x14a\x07HW\x80c\xB3\x10\xE9\xE9\x14a\x07tW\x80c\xB8\xC7\xB3\x0C\x14a\x07\x93W\x80c\xBA\x9FA\xE8\x14a\x07\xB2W\x80c\xC4n:f\x14a\x07\xE5W__\xFD[\x80c\x8A\xBF`w\x14a\x06]W\x80c\x8D\xA5\xCB[\x14a\x06qW\x80c\x9D\xE7Fy\x14a\x06\x8EW\x80c\x9E\xE5\x12\xF2\x14a\x06\xC1W\x80c\xA7\x13|\x0F\x14a\x06\xE6W__\xFD[\x80cN\xF7~\xB5\x11a\x01\xE1W\x80cb\xD0\x94S\x11a\x01\xA6W\x80cb\xD0\x94S\x14a\x05`W\x80cqP\x18\xA6\x14a\x05\x93W\x80cy\xBAP\x97\x14a\x05\xA7W\x80cy\xEF\xB44\x14a\x05\xBBW\x80c\x84V\xCBY\x14a\x06\x05W\x80c\x89?T`\x14a\x06\x19W__\xFD[\x80cN\xF7~\xB5\x14a\x04\xADW\x80cO\x1E\xF2\x86\x14a\x04\xE5W\x80cR\xD1\x90-\x14a\x04\xF8W\x80cS\x9B\x8A\xDE\x14a\x05\x1AW\x80c\\\x97Z\xBB\x14a\x05@W__\xFD[\x80c/\x98\x04s\x11a\x022W\x80c/\x98\x04s\x14a\x03\xF4W\x80c0u\xDBV\x14a\x04\x12W\x80c6<\xC4'\x14a\x04&W\x80c6Y\xCF\xE6\x14a\x04YW\x80c?K\xA8:\x14a\x04zW\x80cH\x08\nE\x14a\x04\x8EW__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02nW\x80c\x12b.[\x14a\x02\xB9W\x80c\x13m\xC4\xA8\x14a\x02\xF0W\x80c\x18e\xC5}\x14a\x03\x0FW\x80c\x1CA\x8AD\x14a\x03\xB0W[__\xFD[4\x80\x15a\x02yW__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02\xC4W__\xFD[P`\xFETa\x02\xD8\x90`\x01`\x01`@\x1B\x03\x16\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x02\xB0V[4\x80\x15a\x02\xFBW__\xFD[Pa\x02\xD8a\x03\n6`\x04a2\x01V[a\tzV[4\x80\x15a\x03\x1AW__\xFD[Pa\x03\xA3`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91RP`@\x80Q`\xA0\x81\x01\x82Ra\x01-T\x81Ra\x01.Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16` \x84\x01R`\x01`0\x1B\x82\x04`\x01`\x01`\xA0\x1B\x03\x16\x93\x83\x01\x93\x90\x93R`\x01`\xD0\x1B\x90\x04`\xFF\x16\x15\x15``\x82\x01Ra\x01/T\x90\x91\x16`\x80\x82\x01R\x90V[`@Qa\x02\xB0\x91\x90a2\x8BV[4\x80\x15a\x03\xBBW__\xFD[Pa\x03\xCFa\x03\xCA6`\x04a3\x01V[a\t\x94V[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x02\xB0V[4\x80\x15a\x03\xFFW__\xFD[P_[`@Q\x90\x15\x15\x81R` \x01a\x02\xB0V[4\x80\x15a\x04\x1DW__\xFD[Pa\x04\x02a\t\xB3V[4\x80\x15a\x041W__\xFD[Pa\x02\x9C\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04dW__\xFD[Pa\x04xa\x04s6`\x04a3]V[a\t\xCBV[\0[4\x80\x15a\x04\x85W__\xFD[Pa\x04xa\n\x9BV[4\x80\x15a\x04\x99W__\xFD[Pa\x04xa\x04\xA86`\x04a3\x99V[a\n\xF6V[4\x80\x15a\x04\xB8W__\xFD[P`\xFETa\x04\xD0\x90`\x01`@\x1B\x90\x04c\xFF\xFF\xFF\xFF\x16\x81V[`@Qc\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02\xB0V[a\x04xa\x04\xF36`\x04a5\nV[a\x0C\xBEV[4\x80\x15a\x05\x03W__\xFD[Pa\x05\x0Ca\rwV[`@Q\x90\x81R` \x01a\x02\xB0V[4\x80\x15a\x05%W__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\x80\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x05KW__\xFD[Pa\x04\x02`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x05kW__\xFD[Pa\x02\x9C\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x05\x9EW__\xFD[Pa\x04xa\x0E(V[4\x80\x15a\x05\xB2W__\xFD[Pa\x04xa\x0E9V[4\x80\x15a\x05\xC6W__\xFD[Pa\x05\xEE\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02\xB0V[4\x80\x15a\x06\x10W__\xFD[Pa\x04xa\x0E\xB0V[4\x80\x15a\x06$W__\xFD[Pa\x068a\x0636`\x04a5TV[a\x0F\x05V[`@\x80Q\x93\x84R`\x01`\x01`@\x1B\x03\x92\x83\x16` \x85\x01R\x91\x16\x90\x82\x01R``\x01a\x02\xB0V[4\x80\x15a\x06hW__\xFD[Pa\x02\x9Ca\x10EV[4\x80\x15a\x06|W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x02\x9CV[4\x80\x15a\x06\x99W__\xFD[Pa\x05\xEE\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xCCW__\xFD[Pa\x02\x9Cqww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[4\x80\x15a\x06\xF1W__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\xC0\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x07\x17W__\xFD[Pa\x07+a\x07&6`\x04a5\x8CV[a\x10SV[`@\x80Q\x92\x83R`\x01`\x01`@\x1B\x03\x90\x91\x16` \x83\x01R\x01a\x02\xB0V[4\x80\x15a\x07SW__\xFD[Pa\x05\x0Ca\x07b6`\x04a5\xBDV[a\x010` R_\x90\x81R`@\x90 T\x81V[4\x80\x15a\x07\x7FW__\xFD[Pa\x04xa\x07\x8E6`\x04a5\xD4V[a\x10nV[4\x80\x15a\x07\x9EW__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x07\xBDW__\xFD[Pa\x02\xD8\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07\xF0W__\xFD[Pa\x02\xD8b\x0FB@\x81V[4\x80\x15a\x08\x06W__\xFD[Pa\x05\x0Cc\x01}x@\x81V[4\x80\x15a\x08\x1DW__\xFD[P`\xFDTa\x02\xD8\x90`\x01`@\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x08CW__\xFD[Pa\x04xa\x08R6`\x04a5\xEFV[a\x12\xA0V[4\x80\x15a\x08bW__\xFD[Pa\x05\x0C`\xFCT\x81V[4\x80\x15a\x08wW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x02\x9CV[4\x80\x15a\x08\x94W__\xFD[Pa\x07+a\x07&6`\x04a62V[4\x80\x15a\x08\xAEW__\xFD[Pa\x05\x0Ca\x08\xBD6`\x04a5\xBDV[a\x12\xB9V[4\x80\x15a\x08\xCDW__\xFD[Pa\x08\xE1a\x08\xDC6`\x04a6\xCBV[a\x12\xF1V[`@Qa\x02\xB0\x92\x91\x90a7\xA9V[4\x80\x15a\x08\xFAW__\xFD[Pa\x04xa\t\t6`\x04a3]V[a\x17\x1BV[4\x80\x15a\t\x19W__\xFD[Pa\x02\xD8\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\tLW__\xFD[Pa\x04xa\t[6`\x04a7\xC5V[a\x17\x8CV[4\x80\x15a\tkW__\xFD[Pa\x04xa\x08R6`\x04a7\xEDV[_`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[___a\t\xA3\x87\x87\x87\x87a\x18\xB8V[\x92P\x92P\x92P\x94P\x94P\x94\x91PPV[_`\x02a\t\xC2`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\x1CW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8.V[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\nNa\x1A]V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\ntW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8zV[a\n}\x81a\x1AxV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\n\x98\x91\x83\x91\x90a\x1A\x80V[PV[a\n\xA3a\x1B\xEAV[a\n\xB7`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xF43_a\x1C\x1BV[V[\x84a\x0B\0\x81a\x1C#V[\x86`\x01`\x01`@\x1B\x03\x16a\x0B\x13\x81a\x1CDV[a\x0B#``\x86\x01`@\x87\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16a\x0B2\x81a\x1CDV[a\x0B?` \x87\x01\x87a8\xDFV[`\xFF\x16a\x0BK\x81a\x1CDV[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x0B}W`@Qcd\x94\xE9\xF7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x85a\x1CdV[a\x0B\x8F`\x02a\x1C\x93V[\x84\x15a\x0B\xAEW`@Qc\x99Q\xD2\xE9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10\x15a\x0B\xF8W`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x15\x80a\x0CVWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10[a\x0CsW`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0C\x7F`\x01Ca9\x13V[\x90Pa\x0C\x8A\x81a\x1C\xA9V[a\x0C\x94\x89\x89a\x1C\xE1V[a\x0C\x9E\x8B\x8Ba\x1D\xC8V[a\x0C\xA7\x81a\x1E\xE6V[Pa\x0C\xB2`\x01a\x1C\x93V[PPPPPPPPPPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\r\x06W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8.V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\r8a\x1A]V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\r^W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8zV[a\rg\x82a\x1AxV[a\rs\x82\x82`\x01a\x1A\x80V[PPV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0E\x16W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x13V[P_Q` a<a_9_Q\x90_R\x90V[a\x0E0a\x1F}V[a\n\xF4_a\x1F\xD7V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0E\xA7W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x13V[a\n\x98\x81a\x1F\xD7V[a\x0E\xB8a\x1F\xF0V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xF43`\x01a\x1C\x1BV[_\x80\x80\x80a\x0F\x16` \x86\x01\x86a8\xDFV[`\xFF\x16a\x0F)``\x87\x01`@\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16a\x0F9\x91\x90a9&V[`\xFDT\x90\x91Pa\x0F]\x90`\x01`\x01`@\x1B\x03`\x01`\xC0\x1B\x82\x04\x81\x16\x91\x84\x91\x16a \"V[\x90\x93P\x91P_a\x0Fs``\x87\x01`@\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16`\xFD`\x10\x90T\x90a\x01\0\n\x90\x04`\x01`\x01`@\x1B\x03\x16\x88a\x0F\x9A\x91\x90a9OV[a\x0F\xA4\x91\x90a9&V[\x90Pa\x0F\xB6`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0F\xE7WPa\x0F\xD5`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x81`\x01`\x01`@\x1B\x03\x16\x11[\x15a\x10\x05Wa\x0F\xFC`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x90P[a\x10!\x84\x84\x83\x8Ba\x10\x1C`\x80\x8C\x01``\x8D\x01a9nV[a!:V[\x90\x95P\x92Pc\x01}x@\x85\x10\x15a\x10:Wc\x01}x@\x94P[PP\x93P\x93P\x93\x90PV[_a\x10Na\x1A]V[\x90P\x90V[__`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x10\x8CWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x10\xA5WP0;\x15\x80\x15a\x10\xA5WP_T`\xFF\x16`\x01\x14[a\x11\x08W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01a\n\x13V[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x11)W_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\x112\x84a!\xBAV[\x82`\x01`\x01`@\x1B\x03\x16_\x03a\x11[W`@Qc\x08'\x9A%`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[F\x83`\x01`\x01`@\x1B\x03\x16\x03a\x11\x84W`@Qc\x08'\x9A%`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01F\x11a\x11\xA5W`@Qc\x8F\x97.\xCB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03F\x11\x15a\x11\xCDW`@Qc\x8F\x97.\xCB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[C\x15a\x12\x17WC`\x01\x03a\x11\xFEW_a\x11\xE7`\x01Ca9\x13V[_\x81\x81R`\xFB` R`@\x90 \x90@\x90UPa\x12\x17V[`@QcZ\x0F\x9EA`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFE\x80T`\x01`\x01`@\x1B\x03\x80\x86\x16g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x92\x83\x16\x17\x90\x92U`\xFD\x80T\x92\x85\x16\x92\x90\x91\x16\x91\x90\x91\x17\x90Ua\x12QCa\"\x18V[P`\xFCU\x80\x15a\x12\x9AW_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPPPV[`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_C\x82\x10a\x12\xC8WP_\x91\x90PV[Ca\x12\xD5\x83a\x01\0a9\x87V[\x10a\x12\xDFWP@\x90V[P_\x90\x81R`\xFB` R`@\x90 T\x90V[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x13wW`@Qcd\x94\xE9\xF7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x13\x7Fa\x1CdV[a\x13\x89`\x02a\x1C\x93V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10\x15a\x13\xD3W`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP`@\x80Q`\xA0\x81\x01\x82Ra\x01-T\x81Ra\x01.Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16` \x84\x01R`\x01`0\x1B\x82\x04`\x01`\x01`\xA0\x1B\x03\x16\x93\x83\x01\x93\x90\x93R`\x01`\xD0\x1B\x90\x04`\xFF\x16\x15\x15``\x82\x01Ra\x01/T\x90\x91\x16`\x80\x82\x01R\x80a\x14@a\x14;`\x01Ca9\x13V[a\"\xA8V[\x86a\xFF\xFF\x16_\x03a\x15\x9DW_a\x14X\x8F\x8F\x8F\x8Fa\x18\xB8V[`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`@\x85\x01R\x90\x15\x15``\x84\x01R\x90P\x80\x15a\x15\x8EW`@Qc\x1C\x89\xCBo`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8F\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c9\x13\x96\xDE\x90`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x14\xE4W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x15\x08\x91\x90a9\x9AV[P`@\x82\x81\x01Q\x90Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x15wW__\xFD[PZ\xF1\x15\x80\x15a\x15\x89W=__>=_\xFD[PPPP[a\x15\x99\x8A\x8A\x8Da\"\xE7V[\x82RP[\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x86e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\x16oW`@\x80Q``\x81\x01\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x88\x81\x16\x82R` \x82\x01\x88\x81R\x82\x84\x01\x88\x81R\x93Qc\x194\x17\x19`\xE3\x1B\x81R\x92Q\x90\x91\x16`\x04\x83\x01RQ`$\x82\x01R\x90Q`D\x82\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c\xC9\xA0\xB8\xC8\x90`d\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x16JW__\xFD[PZ\xF1\x15\x80\x15a\x16\\W=__>=_\xFD[PPPe\xFF\xFF\xFF\xFF\xFF\xFF\x87\x16` \x83\x01RP[e\xFF\xFF\xFF\xFF\xFF\xFF\x80\x84\x16`\x80\x83\x01\x81\x90R\x82Qa\x01-U` \x80\x84\x01Qa\x01.\x80T`@\x80\x88\x01Q``\x89\x01Q\x15\x15`\x01`\xD0\x1B\x02`\xFF`\xD0\x1B\x19`\x01`\x01`\xA0\x1B\x03\x90\x92\x16`\x01`0\x1B\x02`\x01`\x01`\xD0\x1B\x03\x19\x90\x94\x16\x95\x90\x98\x16\x94\x90\x94\x17\x91\x90\x91\x17\x92\x90\x92\x16\x94\x90\x94\x17\x90\x93Ua\x01/\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16\x83\x17\x90UC_\x90\x81Ra\x010\x90\x91R\x91\x90\x91 Ua\x17\n`\x01a\x1C\x93V[\x9CP\x9C\x9APPPPPPPPPPPV[a\x17#a\x1F}V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x17T`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[\x80a\x17\x96\x81a%\x1BV[a\x17\x9Ea\x1F\xF0V[a\x17\xA6a\x1F}V[a\x17\xAEa\x1CdV[a\x17\xB8`\x02a\x1C\x93V[_`\x01`\x01`\xA0\x1B\x03\x84\x16a\x17\xE1WPGa\x17\xDC`\x01`\x01`\xA0\x1B\x03\x84\x16\x82a%BV[a\x18]V[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x85\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x18#W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x18G\x91\x90a9\x9AV[\x90Pa\x18]`\x01`\x01`\xA0\x1B\x03\x85\x16\x84\x83a%MV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x87\x16\x82R\x85\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\x18\xB3`\x01a\x1C\x93V[PPPV[____a\x18\xC8\x88\x88\x88\x88a%\x9FV[\x90\x93Pe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90Pa\x18\xE3c;\x9A\xCA\0\x82a9\xB1V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x89\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x91\x92P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x19SW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x19w\x91\x90a9\xC8V[\x15\x93P\x83\x15a\x19\x9BWa\x01.T`\x01`0\x1B\x90\x04`\x01`\x01`\xA0\x1B\x03\x16\x92Pa\x1ARV[\x86`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x14a\x1ARW`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1A\x1EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1AB\x91\x90a9\xC8V[a\x1ANW\x86\x92Pa\x1ARV[\x80\x91P[P\x94P\x94P\x94\x91PPV[_Q` a<a_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\n\x98a\x1F}V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x1A\xB3Wa\x18\xB3\x83a&\xDFV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x1B\rWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x1B\n\x91\x81\x01\x90a9\x9AV[`\x01[a\x1BpW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x13V[_Q` a<a_9_Q\x90_R\x81\x14a\x1B\xDEW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x13V[Pa\x18\xB3\x83\x83\x83a'zV[a\x1B\xFE`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\n\xF4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\rsa\x1F}V[_\x81\x90\x03a\n\x98W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80_\x03a\n\x98W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x02a\x1Cr`\xC9T`\xFF\x16\x90V[`\xFF\x16\x03a\n\xF4W`@Qc\xDF\xC6\r\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xC9\x80T`\xFF\x19\x16`\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[__a\x1C\xB4\x83a\"\x18V[\x91P\x91P\x81`\xFCT\x14a\x1C\xDAW`@Qc\xD7\x19%\x8D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFCUPPV[___a\x1C\xEF\x85B\x86a\x0F\x05V[\x92P\x92P\x92P\x82H\x14\x80a\x1D\0WP_[a\x1D\x1DW`@Qc6\xD5MO`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFDT`@\x80Q`\x01`\xC0\x1B\x83\x04`\x01`\x01`@\x1B\x03\x90\x81\x16\x82R\x85\x81\x16` \x83\x01R\x92\x83\x16\x81\x83\x01R\x91\x83\x16``\x83\x01R`\x80\x82\x01\x85\x90RQ\x7Fx\x1A\xE5\xC2!X\x06\x15\r\\q\xA4\xEDS6\xE5\xDC:\xD3*\xEF\x04\xFC\x0Fbjn\xE0\xC2\xF8\xD1\xC8\x91\x81\x90\x03`\xA0\x01\x90\xA1`\xFD\x80Tw\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\0\0\x16`\x01`\xC0\x1B`\x01`\x01`@\x1B\x03\x94\x85\x16\x02g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16\x17\x91\x90\x92\x16\x17\x90UPPPV[`\xFDT`\x01`\x01`@\x1B\x03`\x01`@\x1B\x90\x91\x04\x81\x16\x90\x83\x16\x11a\x1D\xE9WPPV[`\xFET`@Qc\x13\xE4)\x9D`\xE2\x1B\x81R`\x01`\x01`@\x1B\x03\x91\x82\x16`\x04\x82\x01R\x7Fs\xE6\xD3@\x85\x03C\xCCo\0\x15\x15\xDCY3w3|\x95\xA6\xFF\xE04\xFE\x1E\x84MM\xAB]\xA1i`$\x82\x01R\x90\x83\x16`D\x82\x01R`d\x81\x01\x82\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90cO\x90\xA6t\x90`\x84\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x1E\x8EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1E\xB2\x91\x90a9\x9AV[PP`\xFD\x80T`\x01`\x01`@\x1B\x03\x90\x92\x16`\x01`@\x1B\x02o\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\0\0\x19\x90\x92\x16\x91\x90\x91\x17\x90UV[_\x81\x81R`\xFB` R`@\x90\x81\x90 \x82@\x90\x81\x90U`\xFD\x80T`\x01`\x01`@\x1B\x03B\x81\x16`\x01`\x80\x1B\x02g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x1B\x19\x83\x16\x81\x17\x90\x93U\x93Q\x92\x93\x7FA\xC3\xF4\x10\xF5\xC8\xAC6\xBBF\xB1\xDC\xCE\xF0\xDE\x0F\x96@\x87\xC9\xE6\x88y_\xA0.\xCF\xA2\xC2\x0B?\xE4\x93a\x1Fq\x93\x86\x93\x90\x83\x16\x92\x16\x91\x90\x91\x17\x90\x91\x82R`\x01`\x01`@\x1B\x03\x16` \x82\x01R`@\x01\x90V[`@Q\x80\x91\x03\x90\xA1PPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\n\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x13V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\n\x98\x81a'\x9EV[a \x04`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\n\xF4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x80g\r\xE0\xB6\xB3\xA7d\0\0`\x01`\x01`@\x1B\x03\x86\x16\x82\x03a IW\x84\x84\x92P\x92PPa!2V[`\x01`\x01`@\x1B\x03\x85\x16\x15\x80a pWP\x84`\x01`\x01`@\x1B\x03\x16\x86`\x01`\x01`@\x1B\x03\x16\x14[\x80a \x8EWPa \x81\x81_\x19a9\xFBV[\x85`\x01`\x01`@\x1B\x03\x16\x10\x15[\x15a \x9FW\x85\x84\x92P\x92PPa!2V[_\x86`\x01`\x01`@\x1B\x03\x16\x86`\x01`\x01`@\x1B\x03\x16\x83a \xBF\x91\x90a9\xB1V[a \xC9\x91\x90a9\xFBV[\x90P\x80\x15\x80a \xDEWP`\x01`\x01`\xFF\x1B\x03\x81\x11[\x15a \xF0W\x85\x85\x93P\x93PPPa!2V[_a \xFA\x82a'\xEFV[\x90P_\x82\x87\x02\x82\x89\x02\x01_\x81\x12`\x01\x81\x14a!\x19W\x85\x82\x04\x92Pa!\x1DV[_\x92P[PP\x87a!)\x82a*\x0CV[\x95P\x95PPPPP[\x93P\x93\x91PPV[_\x80\x80a!Vc\xFF\xFF\xFF\xFF\x86\x16`\x01`\x01`@\x1B\x03\x89\x16a9\x87V[\x90P\x85`\x01`\x01`@\x1B\x03\x16\x81\x11a!oW`\x01a!\x82V[a!\x82`\x01`\x01`@\x1B\x03\x87\x16\x82a9\x13V[\x90Pa!\xA1`\x01`\x01`@\x1B\x03a!\x9B\x83\x87\x83\x16a*$V[\x90a*;V[\x91Pa!\xAD\x88\x83a*OV[\x92PP\x95P\x95\x93PPPPV[_Ta\x01\0\x90\x04`\xFF\x16a!\xE0W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a:\x0EV[a!\xE8a*\x91V[a\"\x06`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\"\0W\x81a\x1F\xD7V[3a\x1F\xD7V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[__a\"\"a1\xC6V[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\">WP\x80`\x01\x01\x85\x10\x15[\x15a\"oW_\x19\x81\x86\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\"aWa\"aa:YV[` \x02\x01RP`\x01\x01a\"+V[Pa \0\x81 \x92P\x83@\x81a\"\x85`\xFF\x87a:mV[a\x01\0\x81\x10a\"\x96Wa\"\x96a:YV[` \x02\x01Ra \0\x90 \x91\x93\x91\x92PPV[_\x81\x81R`\xFB` R`@\x90 T\x15a\"\xD4W`@QcaM\xC5g`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\xFB` R`@\x90 \x90@\x90UV[a\x01-T\x82_[\x81\x81\x10\x15a$\xF2W_\x86\x86\x83\x81\x81\x10a#\tWa#\ta:YV[\x90P`\x80\x02\x01\x806\x03\x81\x01\x90a#\x1F\x91\x90a:\x80V[\x90P_`\x02\x82` \x01Q`\x02\x81\x11\x15a#:Wa#:a:\xE4V[\x03a#fWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a#\xA6V[`\x01\x82` \x01Q`\x02\x81\x11\x15a#~Wa#~a:\xE4V[\x03a#\xA6WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x15a$\xD9W`@\x82\x81\x01Q\x90Qc\x1C\x89\xCBo`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01Re\xFF\xFF\xFF\xFF\xFF\xFF\x83\x16`$\x82\x01R_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c9\x13\x96\xDE\x90`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a$.W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a$R\x91\x90a9\x9AV[``\x84\x01Q`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x91\x92P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a$\xC1W__\xFD[PZ\xF1\x15\x80\x15a$\xD3W=__>=_\xFD[PPPPP[a$\xE3\x85\x83a*\xB7V[\x94PPP\x80`\x01\x01\x90Pa\"\xEEV[P\x82\x82\x14a%\x13W`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x93\x92PPPV[`\x01`\x01`\xA0\x1B\x03\x81\x16a\n\x98W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\rs\x82\x82Za+\x15V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\x18\xB3\x90\x84\x90a+XV[_\x80`\xA1\x83\x10\x15a%\xB4WP\x83\x90P_a&\xD6V[_a%\xC1\x84\x86\x01\x86a:\xF8V[\x90P\x86e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x80a%\xFBWP\x85`\x01`\x01`\xA0\x1B\x03\x16\x81` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14\x15[\x15a&\x0CW\x85_\x92P\x92PPa&\xD6V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x95\x86\x16\x94\x81\x01\x94\x90\x94R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16\x90\x83\x01R\x91\x90\x91\x16``\x82\x01R_\x90`\x80\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P__a&r\x83\x85``\x01Qa,+V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a&\x8AWa&\x8Aa:\xE4V[\x14\x80\x15a&\x9FWP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15\x15[\x15a&\xCDW\x81\x95P\x88`\x01`\x01`\xA0\x1B\x03\x16\x86`\x01`\x01`\xA0\x1B\x03\x16\x14a&\xC8W\x83`@\x01Q\x94P[a&\xD1V[\x88\x95P[PPPP[\x94P\x94\x92PPPV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a'LW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x13V[_Q` a<a_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a'\x83\x83a,mV[_\x82Q\x11\x80a'\x8FWP\x80[\x15a\x18\xB3Wa\x12\x9A\x83\x83a,\xACV[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[o\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x81\x11`\x07\x1B\x81\x81\x1C`\x01`\x01`@\x1B\x03\x10`\x06\x1B\x17\x81\x81\x1Cc\xFF\xFF\xFF\xFF\x10`\x05\x1B\x17\x81\x81\x1Ca\xFF\xFF\x10`\x04\x1B\x17\x81\x81\x1C`\xFF\x10`\x03\x1B\x17_\x82\x13a(KWc\x16\x15\xE68_R`\x04`\x1C\xFD[\x7F\xF8\xF9\xF9\xFA\xF9\xFD\xFA\xFB\xF9\xFD\xFC\xFD\xFA\xFB\xFC\xFE\xF9\xFA\xFD\xFA\xFC\xFC\xFB\xFE\xFA\xFA\xFC\xFB\xFF\xFF\xFF\xFFo\x84!\x08B\x10\x84!\x08\xCCc\x18\xC6\xDBmT\xBE\x83\x83\x1C\x1C`\x1F\x16\x1A\x18\x90\x81\x1B`\x9F\x90\x81\x1ClFWr\xB2\xBB\xBB_\x82K\x15 z0\x81\x01\x81\x02``\x90\x81\x1Dm\x03\x88\xEA\xA2t\x12\xD5\xAC\xA0&\x81]cn\x01\x82\x02\x81\x1Dm\r\xF9\x9A\xC5\x02\x03\x1B\xF9S\xEF\xF4r\xFD\xCC\x01\x82\x02\x81\x1Dm\x13\xCD\xFF\xB2\x9DQ\xD9\x93\"\xBD\xFF_\"\x11\x01\x82\x02\x81\x1Dm\n\x0Ft #\xDE\xF7\x83\xA3\x07\xA9\x86\x91.\x01\x82\x02\x81\x1Dm\x01\x92\r\x80C\xCA\x89\xB5#\x92S(NB\x01\x82\x02\x81\x1Dl\x0Bz\x86\xD77Th\xFA\xC6g\xA0\xA5'\x01l)P\x8EE\x85C\xD8\xAAM\xF2\xAB\xEEx\x83\x01\x83\x02\x82\x1Dm\x019`\x1A.\xFA\xBEq~`L\xBBH\x94\x01\x83\x02\x82\x1Dm\x02$\x7Fz{e\x942\x06I\xAA\x03\xAB\xA1\x01\x83\x02\x82\x1Dl\x8C?8\xE9Zk\x1F\xF2\xAB\x1C;46\x19\x01\x83\x02\x82\x1Dm\x028Gs\xBD\xF1\xACVv\xFA\xCC\xED`\x90\x19\x01\x83\x02\x90\x91\x1Dl\xB9\xA0%\xD8\x14\xB2\x9C!+\x8B\x1A\x07\xCD\x19\x01\x90\x91\x02x\n\tPp\x84\xCCi\x9B\xB0\xE7\x1E\xA8i\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x01\x05q\x13@\xDA\xA0\xD5\xF7i\xDB\xA1\x91\\\xEFY\xF0\x81ZU\x06\x02\x91\x90\x03}\x02g\xA3l\x0C\x95\xB3\x97Z\xB3\xEE[ :v\x14\xA3\xF7Ss\xF0G\xD8\x03\xAE{f\x87\xF2\xB3\x02\x01}W\x11^G\x01\x8Cqw\xEE\xBF|\xD3p\xA35j\x1Bxc\0\x8AZ\xE8\x02\x8Cr\xB8\x86B\x84\x01`\xAE\x1D\x90V[_a*\x1E\x82`\x01`\x01`@\x1B\x03a*;V[\x92\x91PPV[_\x81\x83\x11a*2W\x81a*4V[\x82[\x93\x92PPPV[_\x81\x83\x11a*IW\x82a*4V[P\x91\x90PV[_\x82`\x01`\x01`@\x1B\x03\x16_\x03a*hWP`\x01a*\x1EV[a*4`\x01\x84`\x01`\x01`@\x1B\x03\x16a*\x81\x86\x86a,\xD1V[a*\x8B\x91\x90a9\xFBV[\x90a*$V[_Ta\x01\0\x90\x04`\xFF\x16a\n\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a:\x0EV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a*\xE3WP_\x82` \x01Q`\x02\x81\x11\x15a*\xE1Wa*\xE1a:\xE4V[\x14[a*2W\x82\x82`@Q` \x01a*\xFA\x92\x91\x90a;\x95V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a*4V[\x81_\x03a+!WPPPV[a+;\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa-_V[a\x18\xB3W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a+\xAC\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a-\x9C\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a+\xCCWP\x80\x80` \x01\x90Q\x81\x01\x90a+\xCC\x91\x90a9\xC8V[a\x18\xB3W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\n\x13V[__\x82Q`A\x03a,_W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa,S\x87\x82\x85\x85a-\xAAV[\x94P\x94PPPPa,fV[P_\x90P`\x02[\x92P\x92\x90PV[a,v\x81a&\xDFV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a*4\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a<\x81`'\x919a.dV[_\x82`\x01`\x01`@\x1B\x03\x16_\x03a,\xEAWa,\xEAa<\x01V[_\x83`\x01`\x01`@\x1B\x03\x16\x83`\x01`\x01`@\x1B\x03\x16g\r\xE0\xB6\xB3\xA7d\0\0a-\x12\x91\x90a9\xB1V[a-\x1C\x91\x90a9\xFBV[\x90Ph\x07U\xBFy\x8BJ\x1B\xF1\xE4\x81\x11\x15a-;WPh\x07U\xBFy\x8BJ\x1B\xF1\xE4[g\r\xE0\xB6\xB3\xA7d\0\0a-M\x82a.\xD8V[a-W\x91\x90a9\xFBV[\x94\x93PPPPV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a-\x87W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a-W\x84\x84_\x85a0RV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a-\xDFWP_\x90P`\x03a&\xD6V[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a.0W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a.XW_`\x01\x92P\x92PPa&\xD6V[\x96_\x96P\x94PPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa.\x80\x91\x90a<\x15V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a.\xB8W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a.\xBDV[``\x91P[P\x91P\x91Pa.\xCE\x86\x83\x83\x87a1)V[\x96\x95PPPPPPV[_h\x02?/\xA8\xF6\xDA[\x9D(\x19\x82\x13a.\xEFW\x91\x90PV[h\x07U\xBFy\x8BJ\x1B\xF1\xE5\x82\x12a/\x0CWc\xA3{\xFE\xC9_R`\x04`\x1C\xFD[e\x03x-\xAC\xE9\xD9`N\x83\x90\x1B\x05\x91P_``k\xB1r\x17\xF7\xD1\xCFy\xAB\xC9\xE3\xB3\x98\x84\x82\x1B\x05`\x01`_\x1B\x01\x90\x1Dk\xB1r\x17\xF7\xD1\xCFy\xAB\xC9\xE3\xB3\x98\x81\x02\x90\x93\x03l$\x0C3\x0E\x9F\xB2\xD9\xCB\xAF\x0F\xD5\xAA\xFB\x19\x81\x01\x81\x02``\x90\x81\x1Dm\x02wYI\x91\xCF\xC8_n$a\x83|\xD9\x01\x82\x02\x81\x1Dm\x1AR\x12U\xE3OjPa\xB2^\xF1\xC9\xC3\x19\x01\x82\x02\x81\x1Dm\xB1\xBB\xB2\x01\xF4C\xCF\x96/\x1A\x1D=\xB4\xA5\x01\x82\x02\x81\x1Dn\x02\xC7#\x88\xD9\xF7OQ\xA93\x1F\xEDi?\x14\x19\x01\x82\x02\x81\x1Dn\x05\x18\x0B\xB1G\x99\xABG\xA8\xA8\xCB*R}W\x01m\x02\xD1g W{\xD1\x9B\xF6\x14\x17o\xE9\xEAl\x10\xFEh\xE7\xFD7\xD0\0{q?vP\x84\x01\x84\x02\x83\x1D\x90\x81\x01\x90\x84\x01m\x01\xD3\x96~\xD3\x0F\xC4\xF8\x9C\x02\xBA\xB5p\x81\x19\x01\x02\x90\x91\x1Dn\x05\x87\xF5\x03\xBBn\xA2\x9D%\xFC\xB7@\x19dP\x01\x90\x91\x02m6\rz\xEE\xA0\x93&>\xCCn\x0E\xCB)\x17`b\x1B\x01\x05t\x02\x9D\x9D\xC3\x85c\xC3.\\/m\xC1\x92\xEEp\xEFe\xF9\x97\x8A\xF3\x02`\xC3\x93\x90\x93\x03\x92\x90\x92\x1C\x92\x91PPV[``\x82G\x10\x15a0\xB3W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FAddress: insufficient balance fo`D\x82\x01Re\x1C\x88\x18\xD8[\x1B`\xD2\x1B`d\x82\x01R`\x84\x01a\n\x13V[__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa0\xCE\x91\x90a<\x15V[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a1\x08W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a1\rV[``\x91P[P\x91P\x91Pa1\x1E\x87\x83\x83\x87a1)V[\x97\x96PPPPPPPV[``\x83\x15a1\x97W\x82Q_\x03a1\x90W`\x01`\x01`\xA0\x1B\x03\x85\x16;a1\x90W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x13V[P\x81a-WV[a-W\x83\x83\x81Q\x15a1\xACW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x91\x90a<+V[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[\x805`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a1\xFCW__\xFD[\x91\x90PV[___``\x84\x86\x03\x12\x15a2\x13W__\xFD[a2\x1C\x84a1\xE6V[\x92Pa2*` \x85\x01a1\xE6V[\x91Pa28`@\x85\x01a1\xE6V[\x90P\x92P\x92P\x92V[\x80Q\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01R`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x83\x01R``\x81\x01Q\x15\x15``\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x82\x01Q\x16`\x80\x83\x01RPPV[`\xA0\x81\x01a*\x1E\x82\x84a2AV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a1\xFCW__\xFD[__\x83`\x1F\x84\x01\x12a2\xD4W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a2\xEAW__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a,fW__\xFD[____``\x85\x87\x03\x12\x15a3\x14W__\xFD[a3\x1D\x85a2\x99V[\x93Pa3+` \x86\x01a2\xAEV[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3EW__\xFD[a3Q\x87\x82\x88\x01a2\xC4V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a3mW__\xFD[a*4\x82a2\xAEV[\x805c\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[_`\xA0\x82\x84\x03\x12\x15a*IW__\xFD[______a\x01 \x87\x89\x03\x12\x15a3\xAFW__\xFD[a3\xB8\x87a1\xE6V[\x95P` \x87\x015\x94Pa3\xCD`@\x88\x01a3vV[\x93Pa3\xDC\x88``\x89\x01a3\x89V[\x92Pa\x01\0\x87\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xF7W__\xFD[\x87\x01`\x1F\x81\x01\x89\x13a4\x07W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a4\x1CW__\xFD[\x89` \x82`\x05\x1B\x84\x01\x01\x11\x15a40W__\xFD[` \x82\x01\x93P\x80\x92PPP\x92\x95P\x92\x95P\x92\x95V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4{Wa4{a4EV[`@R\x90V[_\x82`\x1F\x83\x01\x12a4\x90W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xA9Wa4\xA9a4EV[`@Q`\x1F\x82\x01`\x1F\x19\x90\x81\x16`?\x01\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\xD7Wa4\xD7a4EV[`@R\x81\x81R\x83\x82\x01` \x01\x85\x10\x15a4\xEEW__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a5\x1BW__\xFD[a5$\x83a2\xAEV[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5>W__\xFD[a5J\x85\x82\x86\x01a4\x81V[\x91PP\x92P\x92\x90PV[___`\xE0\x84\x86\x03\x12\x15a5fW__\xFD[a5o\x84a3vV[\x92Pa5}` \x85\x01a1\xE6V[\x91Pa28\x85`@\x86\x01a3\x89V[__`@\x83\x85\x03\x12\x15a5\x9DW__\xFD[a5\xA6\x83a1\xE6V[\x91Pa5\xB4` \x84\x01a3vV[\x90P\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a5\xCDW__\xFD[P5\x91\x90PV[___``\x84\x86\x03\x12\x15a5\xE6W__\xFD[a2\x1C\x84a2\xAEV[____`\x80\x85\x87\x03\x12\x15a6\x02W__\xFD[\x845\x93P` \x85\x015\x92Pa6\x19`@\x86\x01a1\xE6V[\x91Pa6'``\x86\x01a3vV[\x90P\x92\x95\x91\x94P\x92PV[____a\x01\0\x85\x87\x03\x12\x15a6FW__\xFD[a6P\x86\x86a3\x89V[\x93Pa6^`\xA0\x86\x01a1\xE6V[\x92Pa6l`\xC0\x86\x01a1\xE6V[\x91Pa6'`\xE0\x86\x01a3vV[__\x83`\x1F\x84\x01\x12a6\x8AW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a6\xA0W__\xFD[` \x83\x01\x91P\x83` \x82`\x07\x1B\x85\x01\x01\x11\x15a,fW__\xFD[\x805a\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[____________a\x01@\x8D\x8F\x03\x12\x15a6\xE7W__\xFD[a6\xF0\x8Da2\x99V[\x9BPa6\xFE` \x8E\x01a2\xAEV[\x9AP`\x01`\x01`@\x1B\x03`@\x8E\x015\x11\x15a7\x17W__\xFD[a7'\x8E`@\x8F\x015\x8F\x01a2\xC4V[\x90\x9AP\x98P``\x8D\x015\x97P`\x01`\x01`@\x1B\x03`\x80\x8E\x015\x11\x15a7JW__\xFD[a7Z\x8E`\x80\x8F\x015\x8F\x01a6zV[\x90\x97P\x95Pa7k`\xA0\x8E\x01a6\xBAV[\x94Pa7y`\xC0\x8E\x01a2\x99V[\x93P`\xE0\x8D\x015\x92Pa\x01\0\x8D\x015\x91Pa7\x97a\x01 \x8E\x01a2\x99V[\x90P\x92\x95\x98\x9BP\x92\x95\x98\x9BP\x92\x95\x98\x9BV[a\x01@\x81\x01a7\xB8\x82\x85a2AV[a*4`\xA0\x83\x01\x84a2AV[__`@\x83\x85\x03\x12\x15a7\xD6W__\xFD[a7\xDF\x83a2\xAEV[\x91Pa5\xB4` \x84\x01a2\xAEV[____a\x01\0\x85\x87\x03\x12\x15a8\x01W__\xFD[a8\n\x85a1\xE6V[\x93P` \x85\x015\x92Pa8\x1F`@\x86\x01a3vV[\x91Pa6'\x86``\x87\x01a3\x89V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a8\xD6W__\xFD[a*4\x82a3vV[_` \x82\x84\x03\x12\x15a8\xEFW__\xFD[\x815`\xFF\x81\x16\x81\x14a*4W__\xFD[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x81\x81\x03\x81\x81\x11\x15a*\x1EWa*\x1Ea8\xFFV[`\x01`\x01`@\x1B\x03\x81\x81\x16\x83\x82\x16\x02\x90\x81\x16\x90\x81\x81\x14a9HWa9Ha8\xFFV[P\x92\x91PPV[`\x01`\x01`@\x1B\x03\x82\x81\x16\x82\x82\x16\x03\x90\x81\x11\x15a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9~W__\xFD[a*4\x82a1\xE6V[\x80\x82\x01\x80\x82\x11\x15a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9\xAAW__\xFD[PQ\x91\x90PV[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9\xD8W__\xFD[\x81Q\x80\x15\x15\x81\x14a*4W__\xFD[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a:\tWa:\ta9\xE7V[P\x04\x90V[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[_\x82a:{Wa:{a9\xE7V[P\x06\x90V[_`\x80\x82\x84\x03\x12\x80\x15a:\x91W__\xFD[Pa:\x9Aa4YV[a:\xA3\x83a2\x99V[\x81R` \x83\x015`\x03\x81\x10a:\xB6W__\xFD[` \x82\x01Ra:\xC7`@\x84\x01a2\xAEV[`@\x82\x01Ra:\xD8``\x84\x01a2\xAEV[``\x82\x01R\x93\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a;\x08W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a;\x1DW__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a;.W__\xFD[a;6a4YV[a;?\x82a2\x99V[\x81Ra;M` \x83\x01a2\xAEV[` \x82\x01Ra;^`@\x83\x01a2\x99V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;{W__\xFD[a;\x87\x86\x82\x85\x01a4\x81V[``\x83\x01RP\x94\x93PPPPV[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a;\xCFWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[cNH{q`\xE0\x1B_R`\x01`\x04R`$_\xFD[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 <\x06\x0B\x10\x97\xEFi\xF4\x15\x1A{\"\xBF\xC3\xAE\xDD}\xDD\xBA\n\x96$dC<OA\x90^v\x82\xDAdsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x60806040526004361061026a575f3560e01c80638abf60771161014a578063cbd9999e116100be578063ee82ac5e11610078578063ee82ac5e146108a3578063f2a49b00146108c2578063f2fde38b146108ef578063f37f28681461090e578063f940e38514610941578063fd85eb2d14610960575f5ffd5b8063cbd9999e146107fb578063d32e81a514610812578063da69d3db14610838578063dac5df7814610857578063e30c39781461086c578063e902461a14610889575f5ffd5b8063a7e022d11161010f578063a7e022d11461070c578063b2105fec14610748578063b310e9e914610774578063b8c7b30c14610793578063ba9f41e8146107b2578063c46e3a66146107e5575f5ffd5b80638abf60771461065d5780638da5cb5b146106715780639de746791461068e5780639ee512f2146106c1578063a7137c0f146106e6575f5ffd5b80634ef77eb5116101e157806362d09453116101a657806362d0945314610560578063715018a61461059357806379ba5097146105a757806379efb434146105bb5780638456cb5914610605578063893f546014610619575f5ffd5b80634ef77eb5146104ad5780634f1ef286146104e557806352d1902d146104f8578063539b8ade1461051a5780635c975abb14610540575f5ffd5b80632f980473116102325780632f980473146103f45780633075db5614610412578063363cc427146104265780633659cfe6146104595780633f4ba83a1461047a57806348080a451461048e575f5ffd5b806304f3bcec1461026e57806312622e5b146102b9578063136dc4a8146102f05780631865c57d1461030f5780631c418a44146103b0575b5f5ffd5b348015610279575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b3480156102c4575f5ffd5b5060fe546102d8906001600160401b031681565b6040516001600160401b0390911681526020016102b0565b3480156102fb575f5ffd5b506102d861030a366004613201565b61097a565b34801561031a575f5ffd5b506103a36040805160a0810182525f80825260208201819052918101829052606081018290526080810191909152506040805160a08101825261012d54815261012e5465ffffffffffff8082166020840152600160301b82046001600160a01b031693830193909352600160d01b900460ff161515606082015261012f54909116608082015290565b6040516102b0919061328b565b3480156103bb575f5ffd5b506103cf6103ca366004613301565b610994565b6040805193151584526001600160a01b039092166020840152908201526060016102b0565b3480156103ff575f5ffd5b505f5b60405190151581526020016102b0565b34801561041d575f5ffd5b506104026109b3565b348015610431575f5ffd5b5061029c7f000000000000000000000000000000000000000000000000000000000000000081565b348015610464575f5ffd5b5061047861047336600461335d565b6109cb565b005b348015610485575f5ffd5b50610478610a9b565b348015610499575f5ffd5b506104786104a8366004613399565b610af6565b3480156104b8575f5ffd5b5060fe546104d090600160401b900463ffffffff1681565b60405163ffffffff90911681526020016102b0565b6104786104f336600461350a565b610cbe565b348015610503575f5ffd5b5061050c610d77565b6040519081526020016102b0565b348015610525575f5ffd5b5060fd546102d890600160801b90046001600160401b031681565b34801561054b575f5ffd5b5061040260c954610100900460ff1660021490565b34801561056b575f5ffd5b5061029c7f000000000000000000000000000000000000000000000000000000000000000081565b34801561059e575f5ffd5b50610478610e28565b3480156105b2575f5ffd5b50610478610e39565b3480156105c6575f5ffd5b506105ee7f000000000000000000000000000000000000000000000000000000000000000081565b60405165ffffffffffff90911681526020016102b0565b348015610610575f5ffd5b50610478610eb0565b348015610624575f5ffd5b50610638610633366004613554565b610f05565b604080519384526001600160401b0392831660208501529116908201526060016102b0565b348015610668575f5ffd5b5061029c611045565b34801561067c575f5ffd5b506033546001600160a01b031661029c565b348015610699575f5ffd5b506105ee7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106cc575f5ffd5b5061029c71777735367b36bc9b61c50022d9d0700db4ec81565b3480156106f1575f5ffd5b5060fd546102d890600160c01b90046001600160401b031681565b348015610717575f5ffd5b5061072b61072636600461358c565b611053565b604080519283526001600160401b039091166020830152016102b0565b348015610753575f5ffd5b5061050c6107623660046135bd565b6101306020525f908152604090205481565b34801561077f575f5ffd5b5061047861078e3660046135d4565b61106e565b34801561079e575f5ffd5b5060fd546102d8906001600160401b031681565b3480156107bd575f5ffd5b506102d87f000000000000000000000000000000000000000000000000000000000000000081565b3480156107f0575f5ffd5b506102d8620f424081565b348015610806575f5ffd5b5061050c63017d784081565b34801561081d575f5ffd5b5060fd546102d890600160401b90046001600160401b031681565b348015610843575f5ffd5b506104786108523660046135ef565b6112a0565b348015610862575f5ffd5b5061050c60fc5481565b348015610877575f5ffd5b506065546001600160a01b031661029c565b348015610894575f5ffd5b5061072b610726366004613632565b3480156108ae575f5ffd5b5061050c6108bd3660046135bd565b6112b9565b3480156108cd575f5ffd5b506108e16108dc3660046136cb565b6112f1565b6040516102b09291906137a9565b3480156108fa575f5ffd5b5061047861090936600461335d565b61171b565b348015610919575f5ffd5b506102d87f000000000000000000000000000000000000000000000000000000000000000081565b34801561094c575f5ffd5b5061047861095b3660046137c5565b61178c565b34801561096b575f5ffd5b506104786108523660046137ed565b5f6040516372c0090b60e11b815260040160405180910390fd5b5f5f5f6109a3878787876118b8565b9250925092509450945094915050565b5f60026109c260c95460ff1690565b60ff1614905090565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610a1c5760405162461bcd60e51b8152600401610a139061382e565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610a4e611a5d565b6001600160a01b031614610a745760405162461bcd60e51b8152600401610a139061387a565b610a7d81611a78565b604080515f80825260208201909252610a9891839190611a80565b50565b610aa3611bea565b610ab760c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610af4335f611c1b565b565b84610b0081611c23565b866001600160401b0316610b1381611c44565b610b2360608601604087016138c6565b63ffffffff16610b3281611c44565b610b3f60208701876138df565b60ff16610b4b81611c44565b3371777735367b36bc9b61c50022d9d0700db4ec14610b7d57604051636494e9f760e01b815260040160405180910390fd5b610b85611c64565b610b8f6002611c93565b8415610bae57604051639951d2e960e01b815260040160405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b0316431015610bf857604051631799c89b60e01b815260040160405180910390fd5b6001600160401b037f0000000000000000000000000000000000000000000000000000000000000000161580610c5657507f00000000000000000000000000000000000000000000000000000000000000006001600160401b031643105b610c7357604051631799c89b60e01b815260040160405180910390fd5b5f610c7f600143613913565b9050610c8a81611ca9565b610c948989611ce1565b610c9e8b8b611dc8565b610ca781611ee6565b50610cb26001611c93565b50505050505050505050565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610d065760405162461bcd60e51b8152600401610a139061382e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610d38611a5d565b6001600160a01b031614610d5e5760405162461bcd60e51b8152600401610a139061387a565b610d6782611a78565b610d7382826001611a80565b5050565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610e165760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a13565b505f516020613c615f395f51905f5290565b610e30611f7d565b610af45f611fd7565b60655433906001600160a01b03168114610ea75760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a13565b610a9881611fd7565b610eb8611ff0565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610af4336001611c1b565b5f808080610f1660208601866138df565b60ff16610f2960608701604088016138c6565b63ffffffff16610f399190613926565b60fd54909150610f5d906001600160401b03600160c01b8204811691849116612022565b90935091505f610f7360608701604088016138c6565b63ffffffff1660fd60109054906101000a90046001600160401b031688610f9a919061394f565b610fa49190613926565b9050610fb660a08701608088016138c6565b63ffffffff1615801590610fe75750610fd560a08701608088016138c6565b63ffffffff16816001600160401b0316115b1561100557610ffc60a08701608088016138c6565b63ffffffff1690505b6110218484838b61101c60808c0160608d0161396e565b61213a565b909550925063017d784085101561103a5763017d784094505b505093509350939050565b5f61104e611a5d565b905090565b5f5f6040516372c0090b60e11b815260040160405180910390fd5b5f54610100900460ff161580801561108c57505f54600160ff909116105b806110a55750303b1580156110a557505f5460ff166001145b6111085760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b6064820152608401610a13565b5f805460ff191660011790558015611129575f805461ff0019166101001790555b611132846121ba565b826001600160401b03165f0361115b576040516308279a2560e31b815260040160405180910390fd5b46836001600160401b031603611184576040516308279a2560e31b815260040160405180910390fd5b600146116111a557604051638f972ecb60e01b815260040160405180910390fd5b6001600160401b034611156111cd57604051638f972ecb60e01b815260040160405180910390fd5b431561121757436001036111fe575f6111e7600143613913565b5f81815260fb602052604090209040905550611217565b604051635a0f9e4160e11b815260040160405180910390fd5b60fe80546001600160401b0380861667ffffffffffffffff199283161790925560fd80549285169290911691909117905561125143612218565b5060fc55801561129a575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b50505050565b6040516372c0090b60e11b815260040160405180910390fd5b5f4382106112c857505f919050565b436112d583610100613987565b106112df57504090565b505f90815260fb602052604090205490565b6040805160a0810182525f808252602082018190529181018290526060810182905260808101919091526040805160a0810182525f808252602082018190529181018290526060810182905260808101919091523371777735367b36bc9b61c50022d9d0700db4ec1461137757604051636494e9f760e01b815260040160405180910390fd5b61137f611c64565b6113896002611c93565b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b03164310156113d357604051631799c89b60e01b815260040160405180910390fd5b50506040805160a08101825261012d54815261012e5465ffffffffffff8082166020840152600160301b82046001600160a01b031693830193909352600160d01b900460ff161515606082015261012f5490911660808201528061144061143b600143613913565b6122a8565b8661ffff165f0361159d575f6114588f8f8f8f6118b8565b6001600160a01b03909116604085015290151560608401529050801561158e57604051631c89cb6f60e11b81526001600160a01b038f81166004830152602482018390527f0000000000000000000000000000000000000000000000000000000000000000169063391396de906044016020604051808303815f875af11580156114e4573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611508919061399a565b506040828101519051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b158015611577575f5ffd5b505af1158015611589573d5f5f3e3d5ffd5b505050505b6115998a8a8d6122e7565b8252505b816020015165ffffffffffff168665ffffffffffff16111561166f576040805160608101825265ffffffffffff8881168252602082018881528284018881529351631934171960e31b815292519091166004830152516024820152905160448201527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03169063c9a0b8c8906064015f604051808303815f87803b15801561164a575f5ffd5b505af115801561165c573d5f5f3e3d5ffd5b50505065ffffffffffff87166020830152505b65ffffffffffff80841660808301819052825161012d5560208084015161012e805460408088015160608901511515600160d01b0260ff60d01b196001600160a01b03909216600160301b026001600160d01b0319909416959098169490941791909117929092169490941790935561012f805465ffffffffffff191683179055435f908152610130909152919091205561170a6001611c93565b9c509c9a5050505050505050505050565b611723611f7d565b606580546001600160a01b0383166001600160a01b031990911681179091556117546033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b806117968161251b565b61179e611ff0565b6117a6611f7d565b6117ae611c64565b6117b86002611c93565b5f6001600160a01b0384166117e15750476117dc6001600160a01b03841682612542565b61185d565b6040516370a0823160e01b81523060048201526001600160a01b038516906370a0823190602401602060405180830381865afa158015611823573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611847919061399a565b905061185d6001600160a01b038516848361254d565b604080516001600160a01b038087168252851660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a1506118b36001611c93565b505050565b5f5f5f5f6118c88888888861259f565b90935065ffffffffffff1690506118e3633b9aca00826139b1565b60405163508b724360e11b81526001600160a01b038981166004830152602482018390529192507f00000000000000000000000000000000000000000000000000000000000000009091169063a116e48690604401602060405180830381865afa158015611953573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061197791906139c8565b159350831561199b5761012e54600160301b90046001600160a01b03169250611a52565b866001600160a01b0316836001600160a01b031614611a525760405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015611a1e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611a4291906139c8565b611a4e57869250611a52565b8091505b509450945094915050565b5f516020613c615f395f51905f52546001600160a01b031690565b610a98611f7d565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff1615611ab3576118b3836126df565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa925050508015611b0d575060408051601f3d908101601f19168201909252611b0a9181019061399a565b60015b611b705760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a13565b5f516020613c615f395f51905f528114611bde5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a13565b506118b383838361277a565b611bfe60c954610100900460ff1660021490565b610af45760405163bae6e2a960e01b815260040160405180910390fd5b610d73611f7d565b5f819003610a985760405163ec73295960e01b815260040160405180910390fd5b805f03610a985760405163ec73295960e01b815260040160405180910390fd5b6002611c7260c95460ff1690565b60ff1603610af45760405163dfc60d8560e01b815260040160405180910390fd5b60c9805460ff191660ff92909216919091179055565b5f5f611cb483612218565b915091508160fc5414611cda5760405163d719258d60e01b815260040160405180910390fd5b60fc555050565b5f5f5f611cef854286610f05565b92509250925082481480611d0057505f5b611d1d576040516336d54d4f60e11b815260040160405180910390fd5b60fd5460408051600160c01b83046001600160401b039081168252858116602083015292831681830152918316606083015260808201859052517f781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c89181900360a00190a160fd805477ffffffffffffffffffffffffffffffff000000000000000016600160c01b6001600160401b039485160267ffffffffffffffff19161791909216179055505050565b60fd546001600160401b03600160401b909104811690831611611de9575050565b60fe546040516313e4299d60e21b81526001600160401b0391821660048201527f73e6d340850343cc6f001515dc593377337c95a6ffe034fe1e844d4dab5da16960248201529083166044820152606481018290527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031690634f90a674906084016020604051808303815f875af1158015611e8e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611eb2919061399a565b505060fd80546001600160401b03909216600160401b026fffffffffffffffff000000000000000019909216919091179055565b5f81815260fb60205260409081902082409081905560fd80546001600160401b03428116600160801b0267ffffffffffffffff60801b1983168117909355935192937f41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe493611f71938693908316921691909117909182526001600160401b0316602082015260400190565b60405180910390a15050565b6033546001600160a01b03163314610af45760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a13565b606580546001600160a01b0319169055610a988161279e565b61200460c954610100900460ff1660021490565b15610af45760405163bae6e2a960e01b815260040160405180910390fd5b5f80670de0b6b3a76400006001600160401b03861682036120495784849250925050612132565b6001600160401b03851615806120705750846001600160401b0316866001600160401b0316145b8061208e5750612081815f196139fb565b856001600160401b031610155b1561209f5785849250925050612132565b5f866001600160401b0316866001600160401b0316836120bf91906139b1565b6120c991906139fb565b90508015806120de57506001600160ff1b0381115b156120f0578585935093505050612132565b5f6120fa826127ef565b90505f828702828902015f81126001811461211957858204925061211d565b5f92505b50508761212982612a0c565b95509550505050505b935093915050565b5f808061215663ffffffff86166001600160401b038916613987565b9050856001600160401b0316811161216f576001612182565b6121826001600160401b03871682613913565b90506121a16001600160401b0361219b83878316612a24565b90612a3b565b91506121ad8883612a4f565b9250509550959350505050565b5f54610100900460ff166121e05760405162461bcd60e51b8152600401610a1390613a0e565b6121e8612a91565b6122066001600160a01b038216156122005781611fd7565b33611fd7565b5060c9805461ff001916610100179055565b5f5f6122226131c6565b46611fe08201525f5b60ff8110801561223e5750806001018510155b1561226f575f198186030180408360ff8306610100811061226157612261613a59565b60200201525060010161222b565b506120008120925083408161228560ff87613a6d565b610100811061229657612296613a59565b60200201526120009020919391925050565b5f81815260fb6020526040902054156122d45760405163614dc56760e01b815260040160405180910390fd5b5f81815260fb6020526040902090409055565b61012d54825f5b818110156124f2575f86868381811061230957612309613a59565b90506080020180360381019061231f9190613a80565b90505f60028260200151600281111561233a5761233a613ae4565b0361236657507f00000000000000000000000000000000000000000000000000000000000000006123a6565b60018260200151600281111561237e5761237e613ae4565b036123a657507f00000000000000000000000000000000000000000000000000000000000000005b65ffffffffffff8116156124d9576040828101519051631c89cb6f60e11b81526001600160a01b03918216600482015265ffffffffffff831660248201525f917f0000000000000000000000000000000000000000000000000000000000000000169063391396de906044016020604051808303815f875af115801561242e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612452919061399a565b6060840151604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390529192507f0000000000000000000000000000000000000000000000000000000000000000169063be32d1f4906044015f604051808303815f87803b1580156124c1575f5ffd5b505af11580156124d3573d5f5f3e3d5ffd5b50505050505b6124e38583612ab7565b945050508060010190506122ee565b50828214612513576040516388c4700b60e01b815260040160405180910390fd5b509392505050565b6001600160a01b038116610a985760405163538ba4f960e01b815260040160405180910390fd5b610d7382825a612b15565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b1790526118b3908490612b58565b5f8060a18310156125b457508390505f6126d6565b5f6125c184860186613af8565b90508665ffffffffffff16815f015165ffffffffffff161415806125fb5750856001600160a01b031681602001516001600160a01b031614155b1561260c57855f92509250506126d6565b8051602080830151604080850151815165ffffffffffff958616948101949094526001600160a01b03909216908301529190911660608201525f906080016040516020818303038152906040528051906020012090505f5f612672838560600151612c2b565b90925090505f81600481111561268a5761268a613ae4565b14801561269f57506001600160a01b03821615155b156126cd57819550886001600160a01b0316866001600160a01b0316146126c857836040015194505b6126d1565b8895505b505050505b94509492505050565b6001600160a01b0381163b61274c5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a13565b5f516020613c615f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b61278383612c6d565b5f8251118061278f5750805b156118b35761129a8383612cac565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b6fffffffffffffffffffffffffffffffff811160071b81811c6001600160401b031060061b1781811c63ffffffff1060051b1781811c61ffff1060041b1781811c60ff1060031b175f821361284b57631615e6385f526004601cfd5b7ff8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff6f8421084210842108cc6318c6db6d54be83831c1c601f161a1890811b609f90811c6c465772b2bbbb5f824b15207a3081018102606090811d6d0388eaa27412d5aca026815d636e018202811d6d0df99ac502031bf953eff472fdcc018202811d6d13cdffb29d51d99322bdff5f2211018202811d6d0a0f742023def783a307a986912e018202811d6d01920d8043ca89b5239253284e42018202811d6c0b7a86d7375468fac667a0a527016c29508e458543d8aa4df2abee7883018302821d6d0139601a2efabe717e604cbb4894018302821d6d02247f7a7b6594320649aa03aba1018302821d6c8c3f38e95a6b1ff2ab1c3b343619018302821d6d02384773bdf1ac5676facced60901901830290911d6cb9a025d814b29c212b8b1a07cd1901909102780a09507084cc699bb0e71ea869ffffffffffffffffffffffff190105711340daa0d5f769dba1915cef59f0815a5506029190037d0267a36c0c95b3975ab3ee5b203a7614a3f75373f047d803ae7b6687f2b302017d57115e47018c7177eebf7cd370a3356a1b7863008a5ae8028c72b88642840160ae1d90565b5f612a1e826001600160401b03612a3b565b92915050565b5f818311612a325781612a34565b825b9392505050565b5f818311612a495782612a34565b50919050565b5f826001600160401b03165f03612a6857506001612a1e565b612a346001846001600160401b0316612a818686612cd1565b612a8b91906139fb565b90612a24565b5f54610100900460ff16610af45760405162461bcd60e51b8152600401610a1390613a0e565b80515f9065ffffffffffff161580612ae357505f82602001516002811115612ae157612ae1613ae4565b145b612a32578282604051602001612afa929190613b95565b60405160208183030381529060405280519060200120612a34565b815f03612b2157505050565b612b3b83838360405180602001604052805f815250612d5f565b6118b357604051634c67134d60e11b815260040160405180910390fd5b5f612bac826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b0316612d9c9092919063ffffffff16565b905080515f1480612bcc575080806020019051810190612bcc91906139c8565b6118b35760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608401610a13565b5f5f8251604103612c5f576020830151604084015160608501515f1a612c5387828585612daa565b94509450505050612c66565b505f905060025b9250929050565b612c76816126df565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060612a348383604051806060016040528060278152602001613c8160279139612e64565b5f826001600160401b03165f03612cea57612cea613c01565b5f836001600160401b0316836001600160401b0316670de0b6b3a7640000612d1291906139b1565b612d1c91906139fb565b9050680755bf798b4a1bf1e4811115612d3b5750680755bf798b4a1bf1e45b670de0b6b3a7640000612d4d82612ed8565b612d5791906139fb565b949350505050565b5f6001600160a01b038516612d8757604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b6060612d5784845f85613052565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115612ddf57505f905060036126d6565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612e30573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612e58575f600192509250506126d6565b965f9650945050505050565b60605f5f856001600160a01b031685604051612e809190613c15565b5f60405180830381855af49150503d805f8114612eb8576040519150601f19603f3d011682016040523d82523d5f602084013e612ebd565b606091505b5091509150612ece86838387613129565b9695505050505050565b5f68023f2fa8f6da5b9d28198213612eef57919050565b680755bf798b4a1bf1e58212612f0c5763a37bfec95f526004601cfd5b6503782dace9d9604e83901b0591505f60606bb17217f7d1cf79abc9e3b39884821b056001605f1b01901d6bb17217f7d1cf79abc9e3b39881029093036c240c330e9fb2d9cbaf0fd5aafb1981018102606090811d6d0277594991cfc85f6e2461837cd9018202811d6d1a521255e34f6a5061b25ef1c9c319018202811d6db1bbb201f443cf962f1a1d3db4a5018202811d6e02c72388d9f74f51a9331fed693f1419018202811d6e05180bb14799ab47a8a8cb2a527d57016d02d16720577bd19bf614176fe9ea6c10fe68e7fd37d0007b713f765084018402831d9081019084016d01d3967ed30fc4f89c02bab5708119010290911d6e0587f503bb6ea29d25fcb740196450019091026d360d7aeea093263ecc6e0ecb291760621b010574029d9dc38563c32e5c2f6dc192ee70ef65f9978af30260c3939093039290921c92915050565b6060824710156130b35760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b6064820152608401610a13565b5f5f866001600160a01b031685876040516130ce9190613c15565b5f6040518083038185875af1925050503d805f8114613108576040519150601f19603f3d011682016040523d82523d5f602084013e61310d565b606091505b509150915061311e87838387613129565b979650505050505050565b606083156131975782515f03613190576001600160a01b0385163b6131905760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a13565b5081612d57565b612d5783838151156131ac5781518083602001fd5b8060405162461bcd60e51b8152600401610a139190613c2b565b604051806120000160405280610100906020820280368337509192915050565b80356001600160401b03811681146131fc575f5ffd5b919050565b5f5f5f60608486031215613213575f5ffd5b61321c846131e6565b925061322a602085016131e6565b9150613238604085016131e6565b90509250925092565b8051825265ffffffffffff602082015116602083015260018060a01b03604082015116604083015260608101511515606083015265ffffffffffff60808201511660808301525050565b60a08101612a1e8284613241565b803565ffffffffffff811681146131fc575f5ffd5b80356001600160a01b03811681146131fc575f5ffd5b5f5f83601f8401126132d4575f5ffd5b5081356001600160401b038111156132ea575f5ffd5b602083019150836020828501011115612c66575f5ffd5b5f5f5f5f60608587031215613314575f5ffd5b61331d85613299565b935061332b602086016132ae565b925060408501356001600160401b03811115613345575f5ffd5b613351878288016132c4565b95989497509550505050565b5f6020828403121561336d575f5ffd5b612a34826132ae565b803563ffffffff811681146131fc575f5ffd5b5f60a08284031215612a49575f5ffd5b5f5f5f5f5f5f61012087890312156133af575f5ffd5b6133b8876131e6565b9550602087013594506133cd60408801613376565b93506133dc8860608901613389565b92506101008701356001600160401b038111156133f7575f5ffd5b8701601f81018913613407575f5ffd5b80356001600160401b0381111561341c575f5ffd5b8960208260051b8401011115613430575f5ffd5b60208201935080925050509295509295509295565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b038111828210171561347b5761347b613445565b60405290565b5f82601f830112613490575f5ffd5b81356001600160401b038111156134a9576134a9613445565b604051601f8201601f19908116603f011681016001600160401b03811182821017156134d7576134d7613445565b6040528181528382016020018510156134ee575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f6040838503121561351b575f5ffd5b613524836132ae565b915060208301356001600160401b0381111561353e575f5ffd5b61354a85828601613481565b9150509250929050565b5f5f5f60e08486031215613566575f5ffd5b61356f84613376565b925061357d602085016131e6565b91506132388560408601613389565b5f5f6040838503121561359d575f5ffd5b6135a6836131e6565b91506135b460208401613376565b90509250929050565b5f602082840312156135cd575f5ffd5b5035919050565b5f5f5f606084860312156135e6575f5ffd5b61321c846132ae565b5f5f5f5f60808587031215613602575f5ffd5b8435935060208501359250613619604086016131e6565b915061362760608601613376565b905092959194509250565b5f5f5f5f6101008587031215613646575f5ffd5b6136508686613389565b935061365e60a086016131e6565b925061366c60c086016131e6565b915061362760e08601613376565b5f5f83601f84011261368a575f5ffd5b5081356001600160401b038111156136a0575f5ffd5b6020830191508360208260071b8501011115612c66575f5ffd5b803561ffff811681146131fc575f5ffd5b5f5f5f5f5f5f5f5f5f5f5f5f6101408d8f0312156136e7575f5ffd5b6136f08d613299565b9b506136fe60208e016132ae565b9a506001600160401b0360408e01351115613717575f5ffd5b6137278e60408f01358f016132c4565b909a50985060608d013597506001600160401b0360808e0135111561374a575f5ffd5b61375a8e60808f01358f0161367a565b909750955061376b60a08e016136ba565b945061377960c08e01613299565b935060e08d013592506101008d013591506137976101208e01613299565b90509295989b509295989b509295989b565b61014081016137b88285613241565b612a3460a0830184613241565b5f5f604083850312156137d6575f5ffd5b6137df836132ae565b91506135b4602084016132ae565b5f5f5f5f6101008587031215613801575f5ffd5b61380a856131e6565b93506020850135925061381f60408601613376565b91506136278660608701613389565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b5f602082840312156138d6575f5ffd5b612a3482613376565b5f602082840312156138ef575f5ffd5b813560ff81168114612a34575f5ffd5b634e487b7160e01b5f52601160045260245ffd5b81810381811115612a1e57612a1e6138ff565b6001600160401b038181168382160290811690818114613948576139486138ff565b5092915050565b6001600160401b038281168282160390811115612a1e57612a1e6138ff565b5f6020828403121561397e575f5ffd5b612a34826131e6565b80820180821115612a1e57612a1e6138ff565b5f602082840312156139aa575f5ffd5b5051919050565b8082028115828204841417612a1e57612a1e6138ff565b5f602082840312156139d8575f5ffd5b81518015158114612a34575f5ffd5b634e487b7160e01b5f52601260045260245ffd5b5f82613a0957613a096139e7565b500490565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b634e487b7160e01b5f52603260045260245ffd5b5f82613a7b57613a7b6139e7565b500690565b5f6080828403128015613a91575f5ffd5b50613a9a613459565b613aa383613299565b8152602083013560038110613ab6575f5ffd5b6020820152613ac7604084016132ae565b6040820152613ad8606084016132ae565b60608201529392505050565b634e487b7160e01b5f52602160045260245ffd5b5f60208284031215613b08575f5ffd5b81356001600160401b03811115613b1d575f5ffd5b820160808185031215613b2e575f5ffd5b613b36613459565b613b3f82613299565b8152613b4d602083016132ae565b6020820152613b5e60408301613299565b604082015260608201356001600160401b03811115613b7b575f5ffd5b613b8786828501613481565b606083015250949350505050565b5f60a08201905083825265ffffffffffff8351166020830152602083015160038110613bcf57634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b634e487b7160e01b5f52600160045260245ffd5b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212203c060b1097ef69f4151a7b22bfc3aedd7dddba0a962464433c4f41905e7682da64736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R`\x046\x10a\x02jW_5`\xE0\x1C\x80c\x8A\xBF`w\x11a\x01JW\x80c\xCB\xD9\x99\x9E\x11a\0\xBEW\x80c\xEE\x82\xAC^\x11a\0xW\x80c\xEE\x82\xAC^\x14a\x08\xA3W\x80c\xF2\xA4\x9B\0\x14a\x08\xC2W\x80c\xF2\xFD\xE3\x8B\x14a\x08\xEFW\x80c\xF3\x7F(h\x14a\t\x0EW\x80c\xF9@\xE3\x85\x14a\tAW\x80c\xFD\x85\xEB-\x14a\t`W__\xFD[\x80c\xCB\xD9\x99\x9E\x14a\x07\xFBW\x80c\xD3.\x81\xA5\x14a\x08\x12W\x80c\xDAi\xD3\xDB\x14a\x088W\x80c\xDA\xC5\xDFx\x14a\x08WW\x80c\xE3\x0C9x\x14a\x08lW\x80c\xE9\x02F\x1A\x14a\x08\x89W__\xFD[\x80c\xA7\xE0\"\xD1\x11a\x01\x0FW\x80c\xA7\xE0\"\xD1\x14a\x07\x0CW\x80c\xB2\x10_\xEC\x14a\x07HW\x80c\xB3\x10\xE9\xE9\x14a\x07tW\x80c\xB8\xC7\xB3\x0C\x14a\x07\x93W\x80c\xBA\x9FA\xE8\x14a\x07\xB2W\x80c\xC4n:f\x14a\x07\xE5W__\xFD[\x80c\x8A\xBF`w\x14a\x06]W\x80c\x8D\xA5\xCB[\x14a\x06qW\x80c\x9D\xE7Fy\x14a\x06\x8EW\x80c\x9E\xE5\x12\xF2\x14a\x06\xC1W\x80c\xA7\x13|\x0F\x14a\x06\xE6W__\xFD[\x80cN\xF7~\xB5\x11a\x01\xE1W\x80cb\xD0\x94S\x11a\x01\xA6W\x80cb\xD0\x94S\x14a\x05`W\x80cqP\x18\xA6\x14a\x05\x93W\x80cy\xBAP\x97\x14a\x05\xA7W\x80cy\xEF\xB44\x14a\x05\xBBW\x80c\x84V\xCBY\x14a\x06\x05W\x80c\x89?T`\x14a\x06\x19W__\xFD[\x80cN\xF7~\xB5\x14a\x04\xADW\x80cO\x1E\xF2\x86\x14a\x04\xE5W\x80cR\xD1\x90-\x14a\x04\xF8W\x80cS\x9B\x8A\xDE\x14a\x05\x1AW\x80c\\\x97Z\xBB\x14a\x05@W__\xFD[\x80c/\x98\x04s\x11a\x022W\x80c/\x98\x04s\x14a\x03\xF4W\x80c0u\xDBV\x14a\x04\x12W\x80c6<\xC4'\x14a\x04&W\x80c6Y\xCF\xE6\x14a\x04YW\x80c?K\xA8:\x14a\x04zW\x80cH\x08\nE\x14a\x04\x8EW__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02nW\x80c\x12b.[\x14a\x02\xB9W\x80c\x13m\xC4\xA8\x14a\x02\xF0W\x80c\x18e\xC5}\x14a\x03\x0FW\x80c\x1CA\x8AD\x14a\x03\xB0W[__\xFD[4\x80\x15a\x02yW__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02\xC4W__\xFD[P`\xFETa\x02\xD8\x90`\x01`\x01`@\x1B\x03\x16\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x02\xB0V[4\x80\x15a\x02\xFBW__\xFD[Pa\x02\xD8a\x03\n6`\x04a2\x01V[a\tzV[4\x80\x15a\x03\x1AW__\xFD[Pa\x03\xA3`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91RP`@\x80Q`\xA0\x81\x01\x82Ra\x01-T\x81Ra\x01.Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16` \x84\x01R`\x01`0\x1B\x82\x04`\x01`\x01`\xA0\x1B\x03\x16\x93\x83\x01\x93\x90\x93R`\x01`\xD0\x1B\x90\x04`\xFF\x16\x15\x15``\x82\x01Ra\x01/T\x90\x91\x16`\x80\x82\x01R\x90V[`@Qa\x02\xB0\x91\x90a2\x8BV[4\x80\x15a\x03\xBBW__\xFD[Pa\x03\xCFa\x03\xCA6`\x04a3\x01V[a\t\x94V[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x02\xB0V[4\x80\x15a\x03\xFFW__\xFD[P_[`@Q\x90\x15\x15\x81R` \x01a\x02\xB0V[4\x80\x15a\x04\x1DW__\xFD[Pa\x04\x02a\t\xB3V[4\x80\x15a\x041W__\xFD[Pa\x02\x9C\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04dW__\xFD[Pa\x04xa\x04s6`\x04a3]V[a\t\xCBV[\0[4\x80\x15a\x04\x85W__\xFD[Pa\x04xa\n\x9BV[4\x80\x15a\x04\x99W__\xFD[Pa\x04xa\x04\xA86`\x04a3\x99V[a\n\xF6V[4\x80\x15a\x04\xB8W__\xFD[P`\xFETa\x04\xD0\x90`\x01`@\x1B\x90\x04c\xFF\xFF\xFF\xFF\x16\x81V[`@Qc\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02\xB0V[a\x04xa\x04\xF36`\x04a5\nV[a\x0C\xBEV[4\x80\x15a\x05\x03W__\xFD[Pa\x05\x0Ca\rwV[`@Q\x90\x81R` \x01a\x02\xB0V[4\x80\x15a\x05%W__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\x80\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x05KW__\xFD[Pa\x04\x02`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x05kW__\xFD[Pa\x02\x9C\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x05\x9EW__\xFD[Pa\x04xa\x0E(V[4\x80\x15a\x05\xB2W__\xFD[Pa\x04xa\x0E9V[4\x80\x15a\x05\xC6W__\xFD[Pa\x05\xEE\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02\xB0V[4\x80\x15a\x06\x10W__\xFD[Pa\x04xa\x0E\xB0V[4\x80\x15a\x06$W__\xFD[Pa\x068a\x0636`\x04a5TV[a\x0F\x05V[`@\x80Q\x93\x84R`\x01`\x01`@\x1B\x03\x92\x83\x16` \x85\x01R\x91\x16\x90\x82\x01R``\x01a\x02\xB0V[4\x80\x15a\x06hW__\xFD[Pa\x02\x9Ca\x10EV[4\x80\x15a\x06|W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x02\x9CV[4\x80\x15a\x06\x99W__\xFD[Pa\x05\xEE\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xCCW__\xFD[Pa\x02\x9Cqww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[4\x80\x15a\x06\xF1W__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\xC0\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x07\x17W__\xFD[Pa\x07+a\x07&6`\x04a5\x8CV[a\x10SV[`@\x80Q\x92\x83R`\x01`\x01`@\x1B\x03\x90\x91\x16` \x83\x01R\x01a\x02\xB0V[4\x80\x15a\x07SW__\xFD[Pa\x05\x0Ca\x07b6`\x04a5\xBDV[a\x010` R_\x90\x81R`@\x90 T\x81V[4\x80\x15a\x07\x7FW__\xFD[Pa\x04xa\x07\x8E6`\x04a5\xD4V[a\x10nV[4\x80\x15a\x07\x9EW__\xFD[P`\xFDTa\x02\xD8\x90`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x07\xBDW__\xFD[Pa\x02\xD8\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07\xF0W__\xFD[Pa\x02\xD8b\x0FB@\x81V[4\x80\x15a\x08\x06W__\xFD[Pa\x05\x0Cc\x01}x@\x81V[4\x80\x15a\x08\x1DW__\xFD[P`\xFDTa\x02\xD8\x90`\x01`@\x1B\x90\x04`\x01`\x01`@\x1B\x03\x16\x81V[4\x80\x15a\x08CW__\xFD[Pa\x04xa\x08R6`\x04a5\xEFV[a\x12\xA0V[4\x80\x15a\x08bW__\xFD[Pa\x05\x0C`\xFCT\x81V[4\x80\x15a\x08wW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x02\x9CV[4\x80\x15a\x08\x94W__\xFD[Pa\x07+a\x07&6`\x04a62V[4\x80\x15a\x08\xAEW__\xFD[Pa\x05\x0Ca\x08\xBD6`\x04a5\xBDV[a\x12\xB9V[4\x80\x15a\x08\xCDW__\xFD[Pa\x08\xE1a\x08\xDC6`\x04a6\xCBV[a\x12\xF1V[`@Qa\x02\xB0\x92\x91\x90a7\xA9V[4\x80\x15a\x08\xFAW__\xFD[Pa\x04xa\t\t6`\x04a3]V[a\x17\x1BV[4\x80\x15a\t\x19W__\xFD[Pa\x02\xD8\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\tLW__\xFD[Pa\x04xa\t[6`\x04a7\xC5V[a\x17\x8CV[4\x80\x15a\tkW__\xFD[Pa\x04xa\x08R6`\x04a7\xEDV[_`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[___a\t\xA3\x87\x87\x87\x87a\x18\xB8V[\x92P\x92P\x92P\x94P\x94P\x94\x91PPV[_`\x02a\t\xC2`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\x1CW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8.V[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\nNa\x1A]V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\ntW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8zV[a\n}\x81a\x1AxV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\n\x98\x91\x83\x91\x90a\x1A\x80V[PV[a\n\xA3a\x1B\xEAV[a\n\xB7`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xF43_a\x1C\x1BV[V[\x84a\x0B\0\x81a\x1C#V[\x86`\x01`\x01`@\x1B\x03\x16a\x0B\x13\x81a\x1CDV[a\x0B#``\x86\x01`@\x87\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16a\x0B2\x81a\x1CDV[a\x0B?` \x87\x01\x87a8\xDFV[`\xFF\x16a\x0BK\x81a\x1CDV[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x0B}W`@Qcd\x94\xE9\xF7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x85a\x1CdV[a\x0B\x8F`\x02a\x1C\x93V[\x84\x15a\x0B\xAEW`@Qc\x99Q\xD2\xE9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10\x15a\x0B\xF8W`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x15\x80a\x0CVWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10[a\x0CsW`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0C\x7F`\x01Ca9\x13V[\x90Pa\x0C\x8A\x81a\x1C\xA9V[a\x0C\x94\x89\x89a\x1C\xE1V[a\x0C\x9E\x8B\x8Ba\x1D\xC8V[a\x0C\xA7\x81a\x1E\xE6V[Pa\x0C\xB2`\x01a\x1C\x93V[PPPPPPPPPPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\r\x06W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8.V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\r8a\x1A]V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\r^W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a8zV[a\rg\x82a\x1AxV[a\rs\x82\x82`\x01a\x1A\x80V[PPV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0E\x16W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x13V[P_Q` a<a_9_Q\x90_R\x90V[a\x0E0a\x1F}V[a\n\xF4_a\x1F\xD7V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0E\xA7W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x13V[a\n\x98\x81a\x1F\xD7V[a\x0E\xB8a\x1F\xF0V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xF43`\x01a\x1C\x1BV[_\x80\x80\x80a\x0F\x16` \x86\x01\x86a8\xDFV[`\xFF\x16a\x0F)``\x87\x01`@\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16a\x0F9\x91\x90a9&V[`\xFDT\x90\x91Pa\x0F]\x90`\x01`\x01`@\x1B\x03`\x01`\xC0\x1B\x82\x04\x81\x16\x91\x84\x91\x16a \"V[\x90\x93P\x91P_a\x0Fs``\x87\x01`@\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16`\xFD`\x10\x90T\x90a\x01\0\n\x90\x04`\x01`\x01`@\x1B\x03\x16\x88a\x0F\x9A\x91\x90a9OV[a\x0F\xA4\x91\x90a9&V[\x90Pa\x0F\xB6`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0F\xE7WPa\x0F\xD5`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x81`\x01`\x01`@\x1B\x03\x16\x11[\x15a\x10\x05Wa\x0F\xFC`\xA0\x87\x01`\x80\x88\x01a8\xC6V[c\xFF\xFF\xFF\xFF\x16\x90P[a\x10!\x84\x84\x83\x8Ba\x10\x1C`\x80\x8C\x01``\x8D\x01a9nV[a!:V[\x90\x95P\x92Pc\x01}x@\x85\x10\x15a\x10:Wc\x01}x@\x94P[PP\x93P\x93P\x93\x90PV[_a\x10Na\x1A]V[\x90P\x90V[__`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x10\x8CWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x10\xA5WP0;\x15\x80\x15a\x10\xA5WP_T`\xFF\x16`\x01\x14[a\x11\x08W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01a\n\x13V[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x11)W_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\x112\x84a!\xBAV[\x82`\x01`\x01`@\x1B\x03\x16_\x03a\x11[W`@Qc\x08'\x9A%`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[F\x83`\x01`\x01`@\x1B\x03\x16\x03a\x11\x84W`@Qc\x08'\x9A%`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01F\x11a\x11\xA5W`@Qc\x8F\x97.\xCB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03F\x11\x15a\x11\xCDW`@Qc\x8F\x97.\xCB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[C\x15a\x12\x17WC`\x01\x03a\x11\xFEW_a\x11\xE7`\x01Ca9\x13V[_\x81\x81R`\xFB` R`@\x90 \x90@\x90UPa\x12\x17V[`@QcZ\x0F\x9EA`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFE\x80T`\x01`\x01`@\x1B\x03\x80\x86\x16g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x92\x83\x16\x17\x90\x92U`\xFD\x80T\x92\x85\x16\x92\x90\x91\x16\x91\x90\x91\x17\x90Ua\x12QCa\"\x18V[P`\xFCU\x80\x15a\x12\x9AW_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPPPV[`@Qcr\xC0\t\x0B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_C\x82\x10a\x12\xC8WP_\x91\x90PV[Ca\x12\xD5\x83a\x01\0a9\x87V[\x10a\x12\xDFWP@\x90V[P_\x90\x81R`\xFB` R`@\x90 T\x90V[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x13wW`@Qcd\x94\xE9\xF7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x13\x7Fa\x1CdV[a\x13\x89`\x02a\x1C\x93V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16C\x10\x15a\x13\xD3W`@Qc\x17\x99\xC8\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP`@\x80Q`\xA0\x81\x01\x82Ra\x01-T\x81Ra\x01.Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16` \x84\x01R`\x01`0\x1B\x82\x04`\x01`\x01`\xA0\x1B\x03\x16\x93\x83\x01\x93\x90\x93R`\x01`\xD0\x1B\x90\x04`\xFF\x16\x15\x15``\x82\x01Ra\x01/T\x90\x91\x16`\x80\x82\x01R\x80a\x14@a\x14;`\x01Ca9\x13V[a\"\xA8V[\x86a\xFF\xFF\x16_\x03a\x15\x9DW_a\x14X\x8F\x8F\x8F\x8Fa\x18\xB8V[`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`@\x85\x01R\x90\x15\x15``\x84\x01R\x90P\x80\x15a\x15\x8EW`@Qc\x1C\x89\xCBo`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8F\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c9\x13\x96\xDE\x90`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x14\xE4W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x15\x08\x91\x90a9\x9AV[P`@\x82\x81\x01Q\x90Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x15wW__\xFD[PZ\xF1\x15\x80\x15a\x15\x89W=__>=_\xFD[PPPP[a\x15\x99\x8A\x8A\x8Da\"\xE7V[\x82RP[\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x86e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\x16oW`@\x80Q``\x81\x01\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x88\x81\x16\x82R` \x82\x01\x88\x81R\x82\x84\x01\x88\x81R\x93Qc\x194\x17\x19`\xE3\x1B\x81R\x92Q\x90\x91\x16`\x04\x83\x01RQ`$\x82\x01R\x90Q`D\x82\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90c\xC9\xA0\xB8\xC8\x90`d\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x16JW__\xFD[PZ\xF1\x15\x80\x15a\x16\\W=__>=_\xFD[PPPe\xFF\xFF\xFF\xFF\xFF\xFF\x87\x16` \x83\x01RP[e\xFF\xFF\xFF\xFF\xFF\xFF\x80\x84\x16`\x80\x83\x01\x81\x90R\x82Qa\x01-U` \x80\x84\x01Qa\x01.\x80T`@\x80\x88\x01Q``\x89\x01Q\x15\x15`\x01`\xD0\x1B\x02`\xFF`\xD0\x1B\x19`\x01`\x01`\xA0\x1B\x03\x90\x92\x16`\x01`0\x1B\x02`\x01`\x01`\xD0\x1B\x03\x19\x90\x94\x16\x95\x90\x98\x16\x94\x90\x94\x17\x91\x90\x91\x17\x92\x90\x92\x16\x94\x90\x94\x17\x90\x93Ua\x01/\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16\x83\x17\x90UC_\x90\x81Ra\x010\x90\x91R\x91\x90\x91 Ua\x17\n`\x01a\x1C\x93V[\x9CP\x9C\x9APPPPPPPPPPPV[a\x17#a\x1F}V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x17T`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[\x80a\x17\x96\x81a%\x1BV[a\x17\x9Ea\x1F\xF0V[a\x17\xA6a\x1F}V[a\x17\xAEa\x1CdV[a\x17\xB8`\x02a\x1C\x93V[_`\x01`\x01`\xA0\x1B\x03\x84\x16a\x17\xE1WPGa\x17\xDC`\x01`\x01`\xA0\x1B\x03\x84\x16\x82a%BV[a\x18]V[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x85\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x18#W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x18G\x91\x90a9\x9AV[\x90Pa\x18]`\x01`\x01`\xA0\x1B\x03\x85\x16\x84\x83a%MV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x87\x16\x82R\x85\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\x18\xB3`\x01a\x1C\x93V[PPPV[____a\x18\xC8\x88\x88\x88\x88a%\x9FV[\x90\x93Pe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90Pa\x18\xE3c;\x9A\xCA\0\x82a9\xB1V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x89\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x91\x92P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x19SW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x19w\x91\x90a9\xC8V[\x15\x93P\x83\x15a\x19\x9BWa\x01.T`\x01`0\x1B\x90\x04`\x01`\x01`\xA0\x1B\x03\x16\x92Pa\x1ARV[\x86`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x14a\x1ARW`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x1A\x1EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1AB\x91\x90a9\xC8V[a\x1ANW\x86\x92Pa\x1ARV[\x80\x91P[P\x94P\x94P\x94\x91PPV[_Q` a<a_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\n\x98a\x1F}V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x1A\xB3Wa\x18\xB3\x83a&\xDFV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x1B\rWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x1B\n\x91\x81\x01\x90a9\x9AV[`\x01[a\x1BpW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x13V[_Q` a<a_9_Q\x90_R\x81\x14a\x1B\xDEW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x13V[Pa\x18\xB3\x83\x83\x83a'zV[a\x1B\xFE`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\n\xF4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\rsa\x1F}V[_\x81\x90\x03a\n\x98W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80_\x03a\n\x98W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x02a\x1Cr`\xC9T`\xFF\x16\x90V[`\xFF\x16\x03a\n\xF4W`@Qc\xDF\xC6\r\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xC9\x80T`\xFF\x19\x16`\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[__a\x1C\xB4\x83a\"\x18V[\x91P\x91P\x81`\xFCT\x14a\x1C\xDAW`@Qc\xD7\x19%\x8D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFCUPPV[___a\x1C\xEF\x85B\x86a\x0F\x05V[\x92P\x92P\x92P\x82H\x14\x80a\x1D\0WP_[a\x1D\x1DW`@Qc6\xD5MO`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xFDT`@\x80Q`\x01`\xC0\x1B\x83\x04`\x01`\x01`@\x1B\x03\x90\x81\x16\x82R\x85\x81\x16` \x83\x01R\x92\x83\x16\x81\x83\x01R\x91\x83\x16``\x83\x01R`\x80\x82\x01\x85\x90RQ\x7Fx\x1A\xE5\xC2!X\x06\x15\r\\q\xA4\xEDS6\xE5\xDC:\xD3*\xEF\x04\xFC\x0Fbjn\xE0\xC2\xF8\xD1\xC8\x91\x81\x90\x03`\xA0\x01\x90\xA1`\xFD\x80Tw\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\0\0\x16`\x01`\xC0\x1B`\x01`\x01`@\x1B\x03\x94\x85\x16\x02g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16\x17\x91\x90\x92\x16\x17\x90UPPPV[`\xFDT`\x01`\x01`@\x1B\x03`\x01`@\x1B\x90\x91\x04\x81\x16\x90\x83\x16\x11a\x1D\xE9WPPV[`\xFET`@Qc\x13\xE4)\x9D`\xE2\x1B\x81R`\x01`\x01`@\x1B\x03\x91\x82\x16`\x04\x82\x01R\x7Fs\xE6\xD3@\x85\x03C\xCCo\0\x15\x15\xDCY3w3|\x95\xA6\xFF\xE04\xFE\x1E\x84MM\xAB]\xA1i`$\x82\x01R\x90\x83\x16`D\x82\x01R`d\x81\x01\x82\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x90cO\x90\xA6t\x90`\x84\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x1E\x8EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1E\xB2\x91\x90a9\x9AV[PP`\xFD\x80T`\x01`\x01`@\x1B\x03\x90\x92\x16`\x01`@\x1B\x02o\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\0\0\x19\x90\x92\x16\x91\x90\x91\x17\x90UV[_\x81\x81R`\xFB` R`@\x90\x81\x90 \x82@\x90\x81\x90U`\xFD\x80T`\x01`\x01`@\x1B\x03B\x81\x16`\x01`\x80\x1B\x02g\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x1B\x19\x83\x16\x81\x17\x90\x93U\x93Q\x92\x93\x7FA\xC3\xF4\x10\xF5\xC8\xAC6\xBBF\xB1\xDC\xCE\xF0\xDE\x0F\x96@\x87\xC9\xE6\x88y_\xA0.\xCF\xA2\xC2\x0B?\xE4\x93a\x1Fq\x93\x86\x93\x90\x83\x16\x92\x16\x91\x90\x91\x17\x90\x91\x82R`\x01`\x01`@\x1B\x03\x16` \x82\x01R`@\x01\x90V[`@Q\x80\x91\x03\x90\xA1PPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\n\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x13V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\n\x98\x81a'\x9EV[a \x04`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\n\xF4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x80g\r\xE0\xB6\xB3\xA7d\0\0`\x01`\x01`@\x1B\x03\x86\x16\x82\x03a IW\x84\x84\x92P\x92PPa!2V[`\x01`\x01`@\x1B\x03\x85\x16\x15\x80a pWP\x84`\x01`\x01`@\x1B\x03\x16\x86`\x01`\x01`@\x1B\x03\x16\x14[\x80a \x8EWPa \x81\x81_\x19a9\xFBV[\x85`\x01`\x01`@\x1B\x03\x16\x10\x15[\x15a \x9FW\x85\x84\x92P\x92PPa!2V[_\x86`\x01`\x01`@\x1B\x03\x16\x86`\x01`\x01`@\x1B\x03\x16\x83a \xBF\x91\x90a9\xB1V[a \xC9\x91\x90a9\xFBV[\x90P\x80\x15\x80a \xDEWP`\x01`\x01`\xFF\x1B\x03\x81\x11[\x15a \xF0W\x85\x85\x93P\x93PPPa!2V[_a \xFA\x82a'\xEFV[\x90P_\x82\x87\x02\x82\x89\x02\x01_\x81\x12`\x01\x81\x14a!\x19W\x85\x82\x04\x92Pa!\x1DV[_\x92P[PP\x87a!)\x82a*\x0CV[\x95P\x95PPPPP[\x93P\x93\x91PPV[_\x80\x80a!Vc\xFF\xFF\xFF\xFF\x86\x16`\x01`\x01`@\x1B\x03\x89\x16a9\x87V[\x90P\x85`\x01`\x01`@\x1B\x03\x16\x81\x11a!oW`\x01a!\x82V[a!\x82`\x01`\x01`@\x1B\x03\x87\x16\x82a9\x13V[\x90Pa!\xA1`\x01`\x01`@\x1B\x03a!\x9B\x83\x87\x83\x16a*$V[\x90a*;V[\x91Pa!\xAD\x88\x83a*OV[\x92PP\x95P\x95\x93PPPPV[_Ta\x01\0\x90\x04`\xFF\x16a!\xE0W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a:\x0EV[a!\xE8a*\x91V[a\"\x06`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\"\0W\x81a\x1F\xD7V[3a\x1F\xD7V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[__a\"\"a1\xC6V[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\">WP\x80`\x01\x01\x85\x10\x15[\x15a\"oW_\x19\x81\x86\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\"aWa\"aa:YV[` \x02\x01RP`\x01\x01a\"+V[Pa \0\x81 \x92P\x83@\x81a\"\x85`\xFF\x87a:mV[a\x01\0\x81\x10a\"\x96Wa\"\x96a:YV[` \x02\x01Ra \0\x90 \x91\x93\x91\x92PPV[_\x81\x81R`\xFB` R`@\x90 T\x15a\"\xD4W`@QcaM\xC5g`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81R`\xFB` R`@\x90 \x90@\x90UV[a\x01-T\x82_[\x81\x81\x10\x15a$\xF2W_\x86\x86\x83\x81\x81\x10a#\tWa#\ta:YV[\x90P`\x80\x02\x01\x806\x03\x81\x01\x90a#\x1F\x91\x90a:\x80V[\x90P_`\x02\x82` \x01Q`\x02\x81\x11\x15a#:Wa#:a:\xE4V[\x03a#fWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a#\xA6V[`\x01\x82` \x01Q`\x02\x81\x11\x15a#~Wa#~a:\xE4V[\x03a#\xA6WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x15a$\xD9W`@\x82\x81\x01Q\x90Qc\x1C\x89\xCBo`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01Re\xFF\xFF\xFF\xFF\xFF\xFF\x83\x16`$\x82\x01R_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c9\x13\x96\xDE\x90`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a$.W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a$R\x91\x90a9\x9AV[``\x84\x01Q`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x91\x92P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a$\xC1W__\xFD[PZ\xF1\x15\x80\x15a$\xD3W=__>=_\xFD[PPPPP[a$\xE3\x85\x83a*\xB7V[\x94PPP\x80`\x01\x01\x90Pa\"\xEEV[P\x82\x82\x14a%\x13W`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x93\x92PPPV[`\x01`\x01`\xA0\x1B\x03\x81\x16a\n\x98W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\rs\x82\x82Za+\x15V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\x18\xB3\x90\x84\x90a+XV[_\x80`\xA1\x83\x10\x15a%\xB4WP\x83\x90P_a&\xD6V[_a%\xC1\x84\x86\x01\x86a:\xF8V[\x90P\x86e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x80a%\xFBWP\x85`\x01`\x01`\xA0\x1B\x03\x16\x81` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14\x15[\x15a&\x0CW\x85_\x92P\x92PPa&\xD6V[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x95\x86\x16\x94\x81\x01\x94\x90\x94R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16\x90\x83\x01R\x91\x90\x91\x16``\x82\x01R_\x90`\x80\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P__a&r\x83\x85``\x01Qa,+V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a&\x8AWa&\x8Aa:\xE4V[\x14\x80\x15a&\x9FWP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15\x15[\x15a&\xCDW\x81\x95P\x88`\x01`\x01`\xA0\x1B\x03\x16\x86`\x01`\x01`\xA0\x1B\x03\x16\x14a&\xC8W\x83`@\x01Q\x94P[a&\xD1V[\x88\x95P[PPPP[\x94P\x94\x92PPPV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a'LW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x13V[_Q` a<a_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a'\x83\x83a,mV[_\x82Q\x11\x80a'\x8FWP\x80[\x15a\x18\xB3Wa\x12\x9A\x83\x83a,\xACV[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[o\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x81\x11`\x07\x1B\x81\x81\x1C`\x01`\x01`@\x1B\x03\x10`\x06\x1B\x17\x81\x81\x1Cc\xFF\xFF\xFF\xFF\x10`\x05\x1B\x17\x81\x81\x1Ca\xFF\xFF\x10`\x04\x1B\x17\x81\x81\x1C`\xFF\x10`\x03\x1B\x17_\x82\x13a(KWc\x16\x15\xE68_R`\x04`\x1C\xFD[\x7F\xF8\xF9\xF9\xFA\xF9\xFD\xFA\xFB\xF9\xFD\xFC\xFD\xFA\xFB\xFC\xFE\xF9\xFA\xFD\xFA\xFC\xFC\xFB\xFE\xFA\xFA\xFC\xFB\xFF\xFF\xFF\xFFo\x84!\x08B\x10\x84!\x08\xCCc\x18\xC6\xDBmT\xBE\x83\x83\x1C\x1C`\x1F\x16\x1A\x18\x90\x81\x1B`\x9F\x90\x81\x1ClFWr\xB2\xBB\xBB_\x82K\x15 z0\x81\x01\x81\x02``\x90\x81\x1Dm\x03\x88\xEA\xA2t\x12\xD5\xAC\xA0&\x81]cn\x01\x82\x02\x81\x1Dm\r\xF9\x9A\xC5\x02\x03\x1B\xF9S\xEF\xF4r\xFD\xCC\x01\x82\x02\x81\x1Dm\x13\xCD\xFF\xB2\x9DQ\xD9\x93\"\xBD\xFF_\"\x11\x01\x82\x02\x81\x1Dm\n\x0Ft #\xDE\xF7\x83\xA3\x07\xA9\x86\x91.\x01\x82\x02\x81\x1Dm\x01\x92\r\x80C\xCA\x89\xB5#\x92S(NB\x01\x82\x02\x81\x1Dl\x0Bz\x86\xD77Th\xFA\xC6g\xA0\xA5'\x01l)P\x8EE\x85C\xD8\xAAM\xF2\xAB\xEEx\x83\x01\x83\x02\x82\x1Dm\x019`\x1A.\xFA\xBEq~`L\xBBH\x94\x01\x83\x02\x82\x1Dm\x02$\x7Fz{e\x942\x06I\xAA\x03\xAB\xA1\x01\x83\x02\x82\x1Dl\x8C?8\xE9Zk\x1F\xF2\xAB\x1C;46\x19\x01\x83\x02\x82\x1Dm\x028Gs\xBD\xF1\xACVv\xFA\xCC\xED`\x90\x19\x01\x83\x02\x90\x91\x1Dl\xB9\xA0%\xD8\x14\xB2\x9C!+\x8B\x1A\x07\xCD\x19\x01\x90\x91\x02x\n\tPp\x84\xCCi\x9B\xB0\xE7\x1E\xA8i\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x01\x05q\x13@\xDA\xA0\xD5\xF7i\xDB\xA1\x91\\\xEFY\xF0\x81ZU\x06\x02\x91\x90\x03}\x02g\xA3l\x0C\x95\xB3\x97Z\xB3\xEE[ :v\x14\xA3\xF7Ss\xF0G\xD8\x03\xAE{f\x87\xF2\xB3\x02\x01}W\x11^G\x01\x8Cqw\xEE\xBF|\xD3p\xA35j\x1Bxc\0\x8AZ\xE8\x02\x8Cr\xB8\x86B\x84\x01`\xAE\x1D\x90V[_a*\x1E\x82`\x01`\x01`@\x1B\x03a*;V[\x92\x91PPV[_\x81\x83\x11a*2W\x81a*4V[\x82[\x93\x92PPPV[_\x81\x83\x11a*IW\x82a*4V[P\x91\x90PV[_\x82`\x01`\x01`@\x1B\x03\x16_\x03a*hWP`\x01a*\x1EV[a*4`\x01\x84`\x01`\x01`@\x1B\x03\x16a*\x81\x86\x86a,\xD1V[a*\x8B\x91\x90a9\xFBV[\x90a*$V[_Ta\x01\0\x90\x04`\xFF\x16a\n\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x90a:\x0EV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a*\xE3WP_\x82` \x01Q`\x02\x81\x11\x15a*\xE1Wa*\xE1a:\xE4V[\x14[a*2W\x82\x82`@Q` \x01a*\xFA\x92\x91\x90a;\x95V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a*4V[\x81_\x03a+!WPPPV[a+;\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa-_V[a\x18\xB3W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a+\xAC\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a-\x9C\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a+\xCCWP\x80\x80` \x01\x90Q\x81\x01\x90a+\xCC\x91\x90a9\xC8V[a\x18\xB3W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\n\x13V[__\x82Q`A\x03a,_W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa,S\x87\x82\x85\x85a-\xAAV[\x94P\x94PPPPa,fV[P_\x90P`\x02[\x92P\x92\x90PV[a,v\x81a&\xDFV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a*4\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a<\x81`'\x919a.dV[_\x82`\x01`\x01`@\x1B\x03\x16_\x03a,\xEAWa,\xEAa<\x01V[_\x83`\x01`\x01`@\x1B\x03\x16\x83`\x01`\x01`@\x1B\x03\x16g\r\xE0\xB6\xB3\xA7d\0\0a-\x12\x91\x90a9\xB1V[a-\x1C\x91\x90a9\xFBV[\x90Ph\x07U\xBFy\x8BJ\x1B\xF1\xE4\x81\x11\x15a-;WPh\x07U\xBFy\x8BJ\x1B\xF1\xE4[g\r\xE0\xB6\xB3\xA7d\0\0a-M\x82a.\xD8V[a-W\x91\x90a9\xFBV[\x94\x93PPPPV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a-\x87W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a-W\x84\x84_\x85a0RV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a-\xDFWP_\x90P`\x03a&\xD6V[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a.0W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a.XW_`\x01\x92P\x92PPa&\xD6V[\x96_\x96P\x94PPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa.\x80\x91\x90a<\x15V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a.\xB8W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a.\xBDV[``\x91P[P\x91P\x91Pa.\xCE\x86\x83\x83\x87a1)V[\x96\x95PPPPPPV[_h\x02?/\xA8\xF6\xDA[\x9D(\x19\x82\x13a.\xEFW\x91\x90PV[h\x07U\xBFy\x8BJ\x1B\xF1\xE5\x82\x12a/\x0CWc\xA3{\xFE\xC9_R`\x04`\x1C\xFD[e\x03x-\xAC\xE9\xD9`N\x83\x90\x1B\x05\x91P_``k\xB1r\x17\xF7\xD1\xCFy\xAB\xC9\xE3\xB3\x98\x84\x82\x1B\x05`\x01`_\x1B\x01\x90\x1Dk\xB1r\x17\xF7\xD1\xCFy\xAB\xC9\xE3\xB3\x98\x81\x02\x90\x93\x03l$\x0C3\x0E\x9F\xB2\xD9\xCB\xAF\x0F\xD5\xAA\xFB\x19\x81\x01\x81\x02``\x90\x81\x1Dm\x02wYI\x91\xCF\xC8_n$a\x83|\xD9\x01\x82\x02\x81\x1Dm\x1AR\x12U\xE3OjPa\xB2^\xF1\xC9\xC3\x19\x01\x82\x02\x81\x1Dm\xB1\xBB\xB2\x01\xF4C\xCF\x96/\x1A\x1D=\xB4\xA5\x01\x82\x02\x81\x1Dn\x02\xC7#\x88\xD9\xF7OQ\xA93\x1F\xEDi?\x14\x19\x01\x82\x02\x81\x1Dn\x05\x18\x0B\xB1G\x99\xABG\xA8\xA8\xCB*R}W\x01m\x02\xD1g W{\xD1\x9B\xF6\x14\x17o\xE9\xEAl\x10\xFEh\xE7\xFD7\xD0\0{q?vP\x84\x01\x84\x02\x83\x1D\x90\x81\x01\x90\x84\x01m\x01\xD3\x96~\xD3\x0F\xC4\xF8\x9C\x02\xBA\xB5p\x81\x19\x01\x02\x90\x91\x1Dn\x05\x87\xF5\x03\xBBn\xA2\x9D%\xFC\xB7@\x19dP\x01\x90\x91\x02m6\rz\xEE\xA0\x93&>\xCCn\x0E\xCB)\x17`b\x1B\x01\x05t\x02\x9D\x9D\xC3\x85c\xC3.\\/m\xC1\x92\xEEp\xEFe\xF9\x97\x8A\xF3\x02`\xC3\x93\x90\x93\x03\x92\x90\x92\x1C\x92\x91PPV[``\x82G\x10\x15a0\xB3W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FAddress: insufficient balance fo`D\x82\x01Re\x1C\x88\x18\xD8[\x1B`\xD2\x1B`d\x82\x01R`\x84\x01a\n\x13V[__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa0\xCE\x91\x90a<\x15V[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a1\x08W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a1\rV[``\x91P[P\x91P\x91Pa1\x1E\x87\x83\x83\x87a1)V[\x97\x96PPPPPPPV[``\x83\x15a1\x97W\x82Q_\x03a1\x90W`\x01`\x01`\xA0\x1B\x03\x85\x16;a1\x90W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x13V[P\x81a-WV[a-W\x83\x83\x81Q\x15a1\xACW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x13\x91\x90a<+V[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[\x805`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a1\xFCW__\xFD[\x91\x90PV[___``\x84\x86\x03\x12\x15a2\x13W__\xFD[a2\x1C\x84a1\xE6V[\x92Pa2*` \x85\x01a1\xE6V[\x91Pa28`@\x85\x01a1\xE6V[\x90P\x92P\x92P\x92V[\x80Q\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x82\x01Q\x16` \x83\x01R`\x01\x80`\xA0\x1B\x03`@\x82\x01Q\x16`@\x83\x01R``\x81\x01Q\x15\x15``\x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x82\x01Q\x16`\x80\x83\x01RPPV[`\xA0\x81\x01a*\x1E\x82\x84a2AV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a1\xFCW__\xFD[__\x83`\x1F\x84\x01\x12a2\xD4W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a2\xEAW__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a,fW__\xFD[____``\x85\x87\x03\x12\x15a3\x14W__\xFD[a3\x1D\x85a2\x99V[\x93Pa3+` \x86\x01a2\xAEV[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3EW__\xFD[a3Q\x87\x82\x88\x01a2\xC4V[\x95\x98\x94\x97P\x95PPPPV[_` \x82\x84\x03\x12\x15a3mW__\xFD[a*4\x82a2\xAEV[\x805c\xFF\xFF\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[_`\xA0\x82\x84\x03\x12\x15a*IW__\xFD[______a\x01 \x87\x89\x03\x12\x15a3\xAFW__\xFD[a3\xB8\x87a1\xE6V[\x95P` \x87\x015\x94Pa3\xCD`@\x88\x01a3vV[\x93Pa3\xDC\x88``\x89\x01a3\x89V[\x92Pa\x01\0\x87\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xF7W__\xFD[\x87\x01`\x1F\x81\x01\x89\x13a4\x07W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a4\x1CW__\xFD[\x89` \x82`\x05\x1B\x84\x01\x01\x11\x15a40W__\xFD[` \x82\x01\x93P\x80\x92PPP\x92\x95P\x92\x95P\x92\x95V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4{Wa4{a4EV[`@R\x90V[_\x82`\x1F\x83\x01\x12a4\x90W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xA9Wa4\xA9a4EV[`@Q`\x1F\x82\x01`\x1F\x19\x90\x81\x16`?\x01\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a4\xD7Wa4\xD7a4EV[`@R\x81\x81R\x83\x82\x01` \x01\x85\x10\x15a4\xEEW__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a5\x1BW__\xFD[a5$\x83a2\xAEV[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a5>W__\xFD[a5J\x85\x82\x86\x01a4\x81V[\x91PP\x92P\x92\x90PV[___`\xE0\x84\x86\x03\x12\x15a5fW__\xFD[a5o\x84a3vV[\x92Pa5}` \x85\x01a1\xE6V[\x91Pa28\x85`@\x86\x01a3\x89V[__`@\x83\x85\x03\x12\x15a5\x9DW__\xFD[a5\xA6\x83a1\xE6V[\x91Pa5\xB4` \x84\x01a3vV[\x90P\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a5\xCDW__\xFD[P5\x91\x90PV[___``\x84\x86\x03\x12\x15a5\xE6W__\xFD[a2\x1C\x84a2\xAEV[____`\x80\x85\x87\x03\x12\x15a6\x02W__\xFD[\x845\x93P` \x85\x015\x92Pa6\x19`@\x86\x01a1\xE6V[\x91Pa6'``\x86\x01a3vV[\x90P\x92\x95\x91\x94P\x92PV[____a\x01\0\x85\x87\x03\x12\x15a6FW__\xFD[a6P\x86\x86a3\x89V[\x93Pa6^`\xA0\x86\x01a1\xE6V[\x92Pa6l`\xC0\x86\x01a1\xE6V[\x91Pa6'`\xE0\x86\x01a3vV[__\x83`\x1F\x84\x01\x12a6\x8AW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a6\xA0W__\xFD[` \x83\x01\x91P\x83` \x82`\x07\x1B\x85\x01\x01\x11\x15a,fW__\xFD[\x805a\xFF\xFF\x81\x16\x81\x14a1\xFCW__\xFD[____________a\x01@\x8D\x8F\x03\x12\x15a6\xE7W__\xFD[a6\xF0\x8Da2\x99V[\x9BPa6\xFE` \x8E\x01a2\xAEV[\x9AP`\x01`\x01`@\x1B\x03`@\x8E\x015\x11\x15a7\x17W__\xFD[a7'\x8E`@\x8F\x015\x8F\x01a2\xC4V[\x90\x9AP\x98P``\x8D\x015\x97P`\x01`\x01`@\x1B\x03`\x80\x8E\x015\x11\x15a7JW__\xFD[a7Z\x8E`\x80\x8F\x015\x8F\x01a6zV[\x90\x97P\x95Pa7k`\xA0\x8E\x01a6\xBAV[\x94Pa7y`\xC0\x8E\x01a2\x99V[\x93P`\xE0\x8D\x015\x92Pa\x01\0\x8D\x015\x91Pa7\x97a\x01 \x8E\x01a2\x99V[\x90P\x92\x95\x98\x9BP\x92\x95\x98\x9BP\x92\x95\x98\x9BV[a\x01@\x81\x01a7\xB8\x82\x85a2AV[a*4`\xA0\x83\x01\x84a2AV[__`@\x83\x85\x03\x12\x15a7\xD6W__\xFD[a7\xDF\x83a2\xAEV[\x91Pa5\xB4` \x84\x01a2\xAEV[____a\x01\0\x85\x87\x03\x12\x15a8\x01W__\xFD[a8\n\x85a1\xE6V[\x93P` \x85\x015\x92Pa8\x1F`@\x86\x01a3vV[\x91Pa6'\x86``\x87\x01a3\x89V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a8\xD6W__\xFD[a*4\x82a3vV[_` \x82\x84\x03\x12\x15a8\xEFW__\xFD[\x815`\xFF\x81\x16\x81\x14a*4W__\xFD[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x81\x81\x03\x81\x81\x11\x15a*\x1EWa*\x1Ea8\xFFV[`\x01`\x01`@\x1B\x03\x81\x81\x16\x83\x82\x16\x02\x90\x81\x16\x90\x81\x81\x14a9HWa9Ha8\xFFV[P\x92\x91PPV[`\x01`\x01`@\x1B\x03\x82\x81\x16\x82\x82\x16\x03\x90\x81\x11\x15a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9~W__\xFD[a*4\x82a1\xE6V[\x80\x82\x01\x80\x82\x11\x15a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9\xAAW__\xFD[PQ\x91\x90PV[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a*\x1EWa*\x1Ea8\xFFV[_` \x82\x84\x03\x12\x15a9\xD8W__\xFD[\x81Q\x80\x15\x15\x81\x14a*4W__\xFD[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a:\tWa:\ta9\xE7V[P\x04\x90V[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[_\x82a:{Wa:{a9\xE7V[P\x06\x90V[_`\x80\x82\x84\x03\x12\x80\x15a:\x91W__\xFD[Pa:\x9Aa4YV[a:\xA3\x83a2\x99V[\x81R` \x83\x015`\x03\x81\x10a:\xB6W__\xFD[` \x82\x01Ra:\xC7`@\x84\x01a2\xAEV[`@\x82\x01Ra:\xD8``\x84\x01a2\xAEV[``\x82\x01R\x93\x92PPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a;\x08W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a;\x1DW__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a;.W__\xFD[a;6a4YV[a;?\x82a2\x99V[\x81Ra;M` \x83\x01a2\xAEV[` \x82\x01Ra;^`@\x83\x01a2\x99V[`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a;{W__\xFD[a;\x87\x86\x82\x85\x01a4\x81V[``\x83\x01RP\x94\x93PPPPV[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a;\xCFWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[cNH{q`\xE0\x1B_R`\x01`\x04R`$_\xFD[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 <\x06\x0B\x10\x97\xEFi\xF4\x15\x1A{\"\xBF\xC3\xAE\xDD}\xDD\xBA\n\x96$dC<OA\x90^v\x82\xDAdsolcC\0\x08\x1E\x003",
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
    /**Custom error with signature `BlockHashAlreadySet()` and selector `0x614dc567`.
```solidity
error BlockHashAlreadySet();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlockHashAlreadySet;
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
        impl ::core::convert::From<BlockHashAlreadySet> for UnderlyingRustTuple<'_> {
            fn from(value: BlockHashAlreadySet) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlockHashAlreadySet {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for BlockHashAlreadySet {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "BlockHashAlreadySet()";
            const SELECTOR: [u8; 4] = [97u8, 77u8, 197u8, 103u8];
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
    /**Custom error with signature `BondInstructionsHashMismatch()` and selector `0x88c4700b`.
```solidity
error BondInstructionsHashMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BondInstructionsHashMismatch;
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
        impl ::core::convert::From<BondInstructionsHashMismatch>
        for UnderlyingRustTuple<'_> {
            fn from(value: BondInstructionsHashMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for BondInstructionsHashMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for BondInstructionsHashMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "BondInstructionsHashMismatch()";
            const SELECTOR: [u8; 4] = [136u8, 196u8, 112u8, 11u8];
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
    /**Custom error with signature `ETH_TRANSFER_FAILED()` and selector `0x98ce269a`.
```solidity
error ETH_TRANSFER_FAILED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ETH_TRANSFER_FAILED;
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
        impl ::core::convert::From<ETH_TRANSFER_FAILED> for UnderlyingRustTuple<'_> {
            fn from(value: ETH_TRANSFER_FAILED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ETH_TRANSFER_FAILED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ETH_TRANSFER_FAILED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ETH_TRANSFER_FAILED()";
            const SELECTOR: [u8; 4] = [152u8, 206u8, 38u8, 154u8];
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
    /**Custom error with signature `InvalidAnchorBlockNumber()` and selector `0xf1cb0235`.
```solidity
error InvalidAnchorBlockNumber();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidAnchorBlockNumber;
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
        impl ::core::convert::From<InvalidAnchorBlockNumber>
        for UnderlyingRustTuple<'_> {
            fn from(value: InvalidAnchorBlockNumber) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for InvalidAnchorBlockNumber {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidAnchorBlockNumber {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidAnchorBlockNumber()";
            const SELECTOR: [u8; 4] = [241u8, 203u8, 2u8, 53u8];
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
    /**Custom error with signature `InvalidBlockIndex()` and selector `0x59b452ef`.
```solidity
error InvalidBlockIndex();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidBlockIndex;
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
        impl ::core::convert::From<InvalidBlockIndex> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidBlockIndex) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidBlockIndex {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidBlockIndex {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidBlockIndex()";
            const SELECTOR: [u8; 4] = [89u8, 180u8, 82u8, 239u8];
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
    /**Custom error with signature `InvalidForkHeight()` and selector `0x02e8f25e`.
```solidity
error InvalidForkHeight();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidForkHeight;
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
        impl ::core::convert::From<InvalidForkHeight> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidForkHeight) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidForkHeight {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidForkHeight {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidForkHeight()";
            const SELECTOR: [u8; 4] = [2u8, 232u8, 242u8, 94u8];
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
    /**Custom error with signature `L2_BASEFEE_MISMATCH()` and selector `0x6daa9a9e`.
```solidity
error L2_BASEFEE_MISMATCH();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_BASEFEE_MISMATCH;
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
        impl ::core::convert::From<L2_BASEFEE_MISMATCH> for UnderlyingRustTuple<'_> {
            fn from(value: L2_BASEFEE_MISMATCH) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_BASEFEE_MISMATCH {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_BASEFEE_MISMATCH {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_BASEFEE_MISMATCH()";
            const SELECTOR: [u8; 4] = [109u8, 170u8, 154u8, 158u8];
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
    /**Custom error with signature `L2_DEPRECATED_METHOD()` and selector `0xe5801216`.
```solidity
error L2_DEPRECATED_METHOD();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_DEPRECATED_METHOD;
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
        impl ::core::convert::From<L2_DEPRECATED_METHOD> for UnderlyingRustTuple<'_> {
            fn from(value: L2_DEPRECATED_METHOD) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_DEPRECATED_METHOD {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_DEPRECATED_METHOD {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_DEPRECATED_METHOD()";
            const SELECTOR: [u8; 4] = [229u8, 128u8, 18u8, 22u8];
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
    /**Custom error with signature `L2_FORK_ERROR()` and selector `0x1799c89b`.
```solidity
error L2_FORK_ERROR();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_FORK_ERROR;
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
        impl ::core::convert::From<L2_FORK_ERROR> for UnderlyingRustTuple<'_> {
            fn from(value: L2_FORK_ERROR) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_FORK_ERROR {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_FORK_ERROR {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_FORK_ERROR()";
            const SELECTOR: [u8; 4] = [23u8, 153u8, 200u8, 155u8];
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
    /**Custom error with signature `L2_INVALID_L1_CHAIN_ID()` and selector `0x413cd128`.
```solidity
error L2_INVALID_L1_CHAIN_ID();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_INVALID_L1_CHAIN_ID;
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
        impl ::core::convert::From<L2_INVALID_L1_CHAIN_ID> for UnderlyingRustTuple<'_> {
            fn from(value: L2_INVALID_L1_CHAIN_ID) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_INVALID_L1_CHAIN_ID {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_INVALID_L1_CHAIN_ID {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_INVALID_L1_CHAIN_ID()";
            const SELECTOR: [u8; 4] = [65u8, 60u8, 209u8, 40u8];
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
    /**Custom error with signature `L2_INVALID_L2_CHAIN_ID()` and selector `0x8f972ecb`.
```solidity
error L2_INVALID_L2_CHAIN_ID();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_INVALID_L2_CHAIN_ID;
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
        impl ::core::convert::From<L2_INVALID_L2_CHAIN_ID> for UnderlyingRustTuple<'_> {
            fn from(value: L2_INVALID_L2_CHAIN_ID) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_INVALID_L2_CHAIN_ID {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_INVALID_L2_CHAIN_ID {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_INVALID_L2_CHAIN_ID()";
            const SELECTOR: [u8; 4] = [143u8, 151u8, 46u8, 203u8];
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
    /**Custom error with signature `L2_INVALID_SENDER()` and selector `0x6494e9f7`.
```solidity
error L2_INVALID_SENDER();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_INVALID_SENDER;
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
        impl ::core::convert::From<L2_INVALID_SENDER> for UnderlyingRustTuple<'_> {
            fn from(value: L2_INVALID_SENDER) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_INVALID_SENDER {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_INVALID_SENDER {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_INVALID_SENDER()";
            const SELECTOR: [u8; 4] = [100u8, 148u8, 233u8, 247u8];
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
    /**Custom error with signature `L2_PUBLIC_INPUT_HASH_MISMATCH()` and selector `0xd719258d`.
```solidity
error L2_PUBLIC_INPUT_HASH_MISMATCH();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_PUBLIC_INPUT_HASH_MISMATCH;
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
        impl ::core::convert::From<L2_PUBLIC_INPUT_HASH_MISMATCH>
        for UnderlyingRustTuple<'_> {
            fn from(value: L2_PUBLIC_INPUT_HASH_MISMATCH) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for L2_PUBLIC_INPUT_HASH_MISMATCH {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_PUBLIC_INPUT_HASH_MISMATCH {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_PUBLIC_INPUT_HASH_MISMATCH()";
            const SELECTOR: [u8; 4] = [215u8, 25u8, 37u8, 141u8];
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
    /**Custom error with signature `L2_TOO_LATE()` and selector `0xb41f3c82`.
```solidity
error L2_TOO_LATE();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct L2_TOO_LATE;
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
        impl ::core::convert::From<L2_TOO_LATE> for UnderlyingRustTuple<'_> {
            fn from(value: L2_TOO_LATE) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for L2_TOO_LATE {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for L2_TOO_LATE {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "L2_TOO_LATE()";
            const SELECTOR: [u8; 4] = [180u8, 31u8, 60u8, 130u8];
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
    /**Custom error with signature `NonZeroAnchorBlockHash()` and selector `0xad10361f`.
```solidity
error NonZeroAnchorBlockHash();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct NonZeroAnchorBlockHash;
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
        impl ::core::convert::From<NonZeroAnchorBlockHash> for UnderlyingRustTuple<'_> {
            fn from(value: NonZeroAnchorBlockHash) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for NonZeroAnchorBlockHash {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for NonZeroAnchorBlockHash {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "NonZeroAnchorBlockHash()";
            const SELECTOR: [u8; 4] = [173u8, 16u8, 54u8, 31u8];
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
    /**Custom error with signature `NonZeroAnchorStateRoot()` and selector `0x21a00d67`.
```solidity
error NonZeroAnchorStateRoot();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct NonZeroAnchorStateRoot;
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
        impl ::core::convert::From<NonZeroAnchorStateRoot> for UnderlyingRustTuple<'_> {
            fn from(value: NonZeroAnchorStateRoot) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for NonZeroAnchorStateRoot {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for NonZeroAnchorStateRoot {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "NonZeroAnchorStateRoot()";
            const SELECTOR: [u8; 4] = [33u8, 160u8, 13u8, 103u8];
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
    /**Custom error with signature `NonZeroBlockIndex()` and selector `0x4a39329c`.
```solidity
error NonZeroBlockIndex();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct NonZeroBlockIndex;
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
        impl ::core::convert::From<NonZeroBlockIndex> for UnderlyingRustTuple<'_> {
            fn from(value: NonZeroBlockIndex) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for NonZeroBlockIndex {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for NonZeroBlockIndex {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "NonZeroBlockIndex()";
            const SELECTOR: [u8; 4] = [74u8, 57u8, 50u8, 156u8];
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
    /**Custom error with signature `ProposalIdMismatch()` and selector `0x229329c7`.
```solidity
error ProposalIdMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposalIdMismatch;
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
        impl ::core::convert::From<ProposalIdMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: ProposalIdMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposalIdMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ProposalIdMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ProposalIdMismatch()";
            const SELECTOR: [u8; 4] = [34u8, 147u8, 41u8, 199u8];
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
    /**Custom error with signature `ProposerMismatch()` and selector `0xe0a5aa81`.
```solidity
error ProposerMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposerMismatch;
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
        impl ::core::convert::From<ProposerMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: ProposerMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposerMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ProposerMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ProposerMismatch()";
            const SELECTOR: [u8; 4] = [224u8, 165u8, 170u8, 129u8];
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
    /**Custom error with signature `SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED()` and selector `0x9951d2e9`.
```solidity
error SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED;
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
        impl ::core::convert::From<SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED>
        for UnderlyingRustTuple<'_> {
            fn from(value: SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED()";
            const SELECTOR: [u8; 4] = [153u8, 81u8, 210u8, 233u8];
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
    /**Custom error with signature `ZeroBlockCount()` and selector `0xca22ef76`.
```solidity
error ZeroBlockCount();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ZeroBlockCount;
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
        impl ::core::convert::From<ZeroBlockCount> for UnderlyingRustTuple<'_> {
            fn from(value: ZeroBlockCount) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ZeroBlockCount {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ZeroBlockCount {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ZeroBlockCount()";
            const SELECTOR: [u8; 4] = [202u8, 34u8, 239u8, 118u8];
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
    /**Event with signature `Anchored(bytes32,uint64)` and selector `0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4`.
```solidity
event Anchored(bytes32 parentHash, uint64 parentGasExcess);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Anchored {
        #[allow(missing_docs)]
        pub parentHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub parentGasExcess: u64,
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
        impl alloy_sol_types::SolEvent for Anchored {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Anchored(bytes32,uint64)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                65u8, 195u8, 244u8, 16u8, 245u8, 200u8, 172u8, 54u8, 187u8, 70u8, 177u8,
                220u8, 206u8, 240u8, 222u8, 15u8, 150u8, 64u8, 135u8, 201u8, 230u8,
                136u8, 121u8, 95u8, 160u8, 46u8, 207u8, 162u8, 194u8, 11u8, 63u8, 228u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    parentHash: data.0,
                    parentGasExcess: data.1,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.parentHash),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentGasExcess),
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
        impl alloy_sol_types::private::IntoLogData for Anchored {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Anchored> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Anchored) -> alloy_sol_types::private::LogData {
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
    /**Event with signature `EIP1559Update(uint64,uint64,uint64,uint64,uint256)` and selector `0x781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c8`.
```solidity
event EIP1559Update(uint64 oldGasTarget, uint64 newGasTarget, uint64 oldGasExcess, uint64 newGasExcess, uint256 basefee);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct EIP1559Update {
        #[allow(missing_docs)]
        pub oldGasTarget: u64,
        #[allow(missing_docs)]
        pub newGasTarget: u64,
        #[allow(missing_docs)]
        pub oldGasExcess: u64,
        #[allow(missing_docs)]
        pub newGasExcess: u64,
        #[allow(missing_docs)]
        pub basefee: alloy::sol_types::private::primitives::aliases::U256,
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
        impl alloy_sol_types::SolEvent for EIP1559Update {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "EIP1559Update(uint64,uint64,uint64,uint64,uint256)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                120u8, 26u8, 229u8, 194u8, 33u8, 88u8, 6u8, 21u8, 13u8, 92u8, 113u8,
                164u8, 237u8, 83u8, 54u8, 229u8, 220u8, 58u8, 211u8, 42u8, 239u8, 4u8,
                252u8, 15u8, 98u8, 106u8, 110u8, 224u8, 194u8, 248u8, 209u8, 200u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    oldGasTarget: data.0,
                    newGasTarget: data.1,
                    oldGasExcess: data.2,
                    newGasExcess: data.3,
                    basefee: data.4,
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
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.oldGasTarget),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.newGasTarget),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.oldGasExcess),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.newGasExcess),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.basefee),
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
        impl alloy_sol_types::private::IntoLogData for EIP1559Update {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&EIP1559Update> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &EIP1559Update) -> alloy_sol_types::private::LogData {
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
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Event with signature `Withdrawn(address,address,uint256)` and selector `0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb`.
```solidity
event Withdrawn(address token, address to, uint256 amount);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct Withdrawn {
        #[allow(missing_docs)]
        pub token: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub to: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub amount: alloy::sol_types::private::primitives::aliases::U256,
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
        impl alloy_sol_types::SolEvent for Withdrawn {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Withdrawn(address,address,uint256)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                209u8, 193u8, 159u8, 188u8, 212u8, 85u8, 26u8, 94u8, 223u8, 182u8, 109u8,
                67u8, 210u8, 227u8, 55u8, 192u8, 72u8, 55u8, 175u8, 218u8, 52u8, 130u8,
                180u8, 43u8, 223u8, 86u8, 154u8, 143u8, 204u8, 218u8, 229u8, 251u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    token: data.0,
                    to: data.1,
                    amount: data.2,
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
                        &self.token,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.to,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.amount),
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
        impl alloy_sol_types::private::IntoLogData for Withdrawn {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&Withdrawn> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &Withdrawn) -> alloy_sol_types::private::LogData {
                alloy_sol_types::SolEvent::encode_log_data(this)
            }
        }
    };
    /**Constructor`.
```solidity
constructor(uint48 _livenessBondGwei, uint48 _provabilityBondGwei, address _signalService, uint64 _pacayaForkHeight, uint64 _shastaForkHeight, address _bondManager);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct constructorCall {
        #[allow(missing_docs)]
        pub _livenessBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _provabilityBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _signalService: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _pacayaForkHeight: u64,
        #[allow(missing_docs)]
        pub _shastaForkHeight: u64,
        #[allow(missing_docs)]
        pub _bondManager: alloy::sol_types::private::Address,
    }
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::Address,
                u64,
                u64,
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
            impl ::core::convert::From<constructorCall> for UnderlyingRustTuple<'_> {
                fn from(value: constructorCall) -> Self {
                    (
                        value._livenessBondGwei,
                        value._provabilityBondGwei,
                        value._signalService,
                        value._pacayaForkHeight,
                        value._shastaForkHeight,
                        value._bondManager,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for constructorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _livenessBondGwei: tuple.0,
                        _provabilityBondGwei: tuple.1,
                        _signalService: tuple.2,
                        _pacayaForkHeight: tuple.3,
                        _shastaForkHeight: tuple.4,
                        _bondManager: tuple.5,
                    }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolConstructor for constructorCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._livenessBondGwei),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._provabilityBondGwei),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._signalService,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._pacayaForkHeight),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._shastaForkHeight),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._bondManager,
                    ),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `ANCHOR_GAS_LIMIT()` and selector `0xc46e3a66`.
```solidity
function ANCHOR_GAS_LIMIT() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ANCHOR_GAS_LIMITCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`ANCHOR_GAS_LIMIT()`](ANCHOR_GAS_LIMITCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ANCHOR_GAS_LIMITReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<ANCHOR_GAS_LIMITCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: ANCHOR_GAS_LIMITCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for ANCHOR_GAS_LIMITCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<ANCHOR_GAS_LIMITReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: ANCHOR_GAS_LIMITReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for ANCHOR_GAS_LIMITReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for ANCHOR_GAS_LIMITCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ANCHOR_GAS_LIMIT()";
            const SELECTOR: [u8; 4] = [196u8, 110u8, 58u8, 102u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: ANCHOR_GAS_LIMITReturn = r.into();
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
                        let r: ANCHOR_GAS_LIMITReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `BASEFEE_MIN_VALUE()` and selector `0xcbd9999e`.
```solidity
function BASEFEE_MIN_VALUE() external view returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BASEFEE_MIN_VALUECall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`BASEFEE_MIN_VALUE()`](BASEFEE_MIN_VALUECall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BASEFEE_MIN_VALUEReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<BASEFEE_MIN_VALUECall>
            for UnderlyingRustTuple<'_> {
                fn from(value: BASEFEE_MIN_VALUECall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for BASEFEE_MIN_VALUECall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
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
            impl ::core::convert::From<BASEFEE_MIN_VALUEReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: BASEFEE_MIN_VALUEReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for BASEFEE_MIN_VALUEReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for BASEFEE_MIN_VALUECall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "BASEFEE_MIN_VALUE()";
            const SELECTOR: [u8; 4] = [203u8, 217u8, 153u8, 158u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: BASEFEE_MIN_VALUEReturn = r.into();
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
                        let r: BASEFEE_MIN_VALUEReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `GOLDEN_TOUCH_ADDRESS()` and selector `0x9ee512f2`.
```solidity
function GOLDEN_TOUCH_ADDRESS() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct GOLDEN_TOUCH_ADDRESSCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`GOLDEN_TOUCH_ADDRESS()`](GOLDEN_TOUCH_ADDRESSCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct GOLDEN_TOUCH_ADDRESSReturn {
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
            impl ::core::convert::From<GOLDEN_TOUCH_ADDRESSCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: GOLDEN_TOUCH_ADDRESSCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for GOLDEN_TOUCH_ADDRESSCall {
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
            impl ::core::convert::From<GOLDEN_TOUCH_ADDRESSReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: GOLDEN_TOUCH_ADDRESSReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for GOLDEN_TOUCH_ADDRESSReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for GOLDEN_TOUCH_ADDRESSCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "GOLDEN_TOUCH_ADDRESS()";
            const SELECTOR: [u8; 4] = [158u8, 229u8, 18u8, 242u8];
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
                        let r: GOLDEN_TOUCH_ADDRESSReturn = r.into();
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
                        let r: GOLDEN_TOUCH_ADDRESSReturn = r.into();
                        r._0
                    })
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
    /**Function with signature `adjustExcess(uint64,uint64,uint64)` and selector `0x136dc4a8`.
```solidity
function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) external pure returns (uint64 newGasExcess_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct adjustExcessCall {
        #[allow(missing_docs)]
        pub _currGasExcess: u64,
        #[allow(missing_docs)]
        pub _currGasTarget: u64,
        #[allow(missing_docs)]
        pub _newGasTarget: u64,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`adjustExcess(uint64,uint64,uint64)`](adjustExcessCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct adjustExcessReturn {
        #[allow(missing_docs)]
        pub newGasExcess_: u64,
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
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64, u64, u64);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<adjustExcessCall> for UnderlyingRustTuple<'_> {
                fn from(value: adjustExcessCall) -> Self {
                    (value._currGasExcess, value._currGasTarget, value._newGasTarget)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for adjustExcessCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _currGasExcess: tuple.0,
                        _currGasTarget: tuple.1,
                        _newGasTarget: tuple.2,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<adjustExcessReturn> for UnderlyingRustTuple<'_> {
                fn from(value: adjustExcessReturn) -> Self {
                    (value.newGasExcess_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for adjustExcessReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { newGasExcess_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for adjustExcessCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "adjustExcess(uint64,uint64,uint64)";
            const SELECTOR: [u8; 4] = [19u8, 109u8, 196u8, 168u8];
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
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._currGasExcess),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._currGasTarget),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._newGasTarget),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: adjustExcessReturn = r.into();
                        r.newGasExcess_
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
                        let r: adjustExcessReturn = r.into();
                        r.newGasExcess_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `anchor(bytes32,bytes32,uint64,uint32)` and selector `0xda69d3db`.
```solidity
function anchor(bytes32 _l1BlockHash, bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorCall {
        #[allow(missing_docs)]
        pub _l1BlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _l1StateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _l1BlockId: u64,
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
    }
    ///Container type for the return parameters of the [`anchor(bytes32,bytes32,uint64,uint32)`](anchorCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorReturn {}
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
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::FixedBytes<32>,
                alloy::sol_types::private::FixedBytes<32>,
                u64,
                u32,
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
            impl ::core::convert::From<anchorCall> for UnderlyingRustTuple<'_> {
                fn from(value: anchorCall) -> Self {
                    (
                        value._l1BlockHash,
                        value._l1StateRoot,
                        value._l1BlockId,
                        value._parentGasUsed,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _l1BlockHash: tuple.0,
                        _l1StateRoot: tuple.1,
                        _l1BlockId: tuple.2,
                        _parentGasUsed: tuple.3,
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
            impl ::core::convert::From<anchorReturn> for UnderlyingRustTuple<'_> {
                fn from(value: anchorReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl anchorReturn {
            fn _tokenize(
                &self,
            ) -> <anchorCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for anchorCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = anchorReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "anchor(bytes32,bytes32,uint64,uint32)";
            const SELECTOR: [u8; 4] = [218u8, 105u8, 211u8, 219u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._l1BlockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._l1StateRoot),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._l1BlockId),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                anchorReturn::_tokenize(ret)
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
    /**Function with signature `anchorV2(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32))` and selector `0xfd85eb2d`.
```solidity
function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV2Call {
        #[allow(missing_docs)]
        pub _anchorBlockId: u64,
        #[allow(missing_docs)]
        pub _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
        #[allow(missing_docs)]
        pub _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
    }
    ///Container type for the return parameters of the [`anchorV2(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32))`](anchorV2Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV2Return {}
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
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<32>,
                OntakeAnchor::BaseFeeConfig,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u64,
                alloy::sol_types::private::FixedBytes<32>,
                u32,
                <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<anchorV2Call> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV2Call) -> Self {
                    (
                        value._anchorBlockId,
                        value._anchorStateRoot,
                        value._parentGasUsed,
                        value._baseFeeConfig,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV2Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _anchorBlockId: tuple.0,
                        _anchorStateRoot: tuple.1,
                        _parentGasUsed: tuple.2,
                        _baseFeeConfig: tuple.3,
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
            impl ::core::convert::From<anchorV2Return> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV2Return) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV2Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl anchorV2Return {
            fn _tokenize(
                &self,
            ) -> <anchorV2Call as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for anchorV2Call {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<32>,
                OntakeAnchor::BaseFeeConfig,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = anchorV2Return;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "anchorV2(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32))";
            const SELECTOR: [u8; 4] = [253u8, 133u8, 235u8, 45u8];
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
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorBlockId),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorStateRoot),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                    <OntakeAnchor::BaseFeeConfig as alloy_sol_types::SolType>::tokenize(
                        &self._baseFeeConfig,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                anchorV2Return::_tokenize(ret)
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
    /**Function with signature `anchorV3(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32),bytes32[])` and selector `0x48080a45`.
```solidity
function anchorV3(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig, bytes32[] memory _signalSlots) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV3Call {
        #[allow(missing_docs)]
        pub _anchorBlockId: u64,
        #[allow(missing_docs)]
        pub _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
        #[allow(missing_docs)]
        pub _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub _signalSlots: alloy::sol_types::private::Vec<
            alloy::sol_types::private::FixedBytes<32>,
        >,
    }
    ///Container type for the return parameters of the [`anchorV3(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32),bytes32[])`](anchorV3Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV3Return {}
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
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<32>,
                OntakeAnchor::BaseFeeConfig,
                alloy::sol_types::sol_data::Array<
                    alloy::sol_types::sol_data::FixedBytes<32>,
                >,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u64,
                alloy::sol_types::private::FixedBytes<32>,
                u32,
                <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
                alloy::sol_types::private::Vec<alloy::sol_types::private::FixedBytes<32>>,
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
            impl ::core::convert::From<anchorV3Call> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV3Call) -> Self {
                    (
                        value._anchorBlockId,
                        value._anchorStateRoot,
                        value._parentGasUsed,
                        value._baseFeeConfig,
                        value._signalSlots,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV3Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _anchorBlockId: tuple.0,
                        _anchorStateRoot: tuple.1,
                        _parentGasUsed: tuple.2,
                        _baseFeeConfig: tuple.3,
                        _signalSlots: tuple.4,
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
            impl ::core::convert::From<anchorV3Return> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV3Return) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV3Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl anchorV3Return {
            fn _tokenize(
                &self,
            ) -> <anchorV3Call as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for anchorV3Call {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<32>,
                OntakeAnchor::BaseFeeConfig,
                alloy::sol_types::sol_data::Array<
                    alloy::sol_types::sol_data::FixedBytes<32>,
                >,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = anchorV3Return;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "anchorV3(uint64,bytes32,uint32,(uint8,uint8,uint32,uint64,uint32),bytes32[])";
            const SELECTOR: [u8; 4] = [72u8, 8u8, 10u8, 69u8];
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
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorBlockId),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorStateRoot),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                    <OntakeAnchor::BaseFeeConfig as alloy_sol_types::SolType>::tokenize(
                        &self._baseFeeConfig,
                    ),
                    <alloy::sol_types::sol_data::Array<
                        alloy::sol_types::sol_data::FixedBytes<32>,
                    > as alloy_sol_types::SolType>::tokenize(&self._signalSlots),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                anchorV3Return::_tokenize(ret)
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
    /**Function with signature `blockIdToEndOfSubmissionWindowTimeStamp(uint256)` and selector `0xb2105fec`.
```solidity
function blockIdToEndOfSubmissionWindowTimeStamp(uint256 blockId) external view returns (uint256 endOfSubmissionWindowTimestamp);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blockIdToEndOfSubmissionWindowTimeStampCall {
        #[allow(missing_docs)]
        pub blockId: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`blockIdToEndOfSubmissionWindowTimeStamp(uint256)`](blockIdToEndOfSubmissionWindowTimeStampCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blockIdToEndOfSubmissionWindowTimeStampReturn {
        #[allow(missing_docs)]
        pub endOfSubmissionWindowTimestamp: alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<blockIdToEndOfSubmissionWindowTimeStampCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: blockIdToEndOfSubmissionWindowTimeStampCall) -> Self {
                    (value.blockId,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for blockIdToEndOfSubmissionWindowTimeStampCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { blockId: tuple.0 }
                }
            }
        }
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
            impl ::core::convert::From<blockIdToEndOfSubmissionWindowTimeStampReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: blockIdToEndOfSubmissionWindowTimeStampReturn) -> Self {
                    (value.endOfSubmissionWindowTimestamp,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for blockIdToEndOfSubmissionWindowTimeStampReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        endOfSubmissionWindowTimestamp: tuple.0,
                    }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for blockIdToEndOfSubmissionWindowTimeStampCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "blockIdToEndOfSubmissionWindowTimeStamp(uint256)";
            const SELECTOR: [u8; 4] = [178u8, 16u8, 95u8, 236u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self.blockId),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: blockIdToEndOfSubmissionWindowTimeStampReturn = r.into();
                        r.endOfSubmissionWindowTimestamp
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
                        let r: blockIdToEndOfSubmissionWindowTimeStampReturn = r.into();
                        r.endOfSubmissionWindowTimestamp
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `bondManager()` and selector `0x363cc427`.
```solidity
function bondManager() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct bondManagerCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`bondManager()`](bondManagerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct bondManagerReturn {
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
            impl ::core::convert::From<bondManagerCall> for UnderlyingRustTuple<'_> {
                fn from(value: bondManagerCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for bondManagerCall {
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
            impl ::core::convert::From<bondManagerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: bondManagerReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for bondManagerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for bondManagerCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "bondManager()";
            const SELECTOR: [u8; 4] = [54u8, 60u8, 196u8, 39u8];
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
                        let r: bondManagerReturn = r.into();
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
                        let r: bondManagerReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `calculateBaseFee((uint8,uint8,uint32,uint64,uint32),uint64,uint64,uint32)` and selector `0xe902461a`.
```solidity
function calculateBaseFee(OntakeAnchor.BaseFeeConfig memory _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) external pure returns (uint256 basefee_, uint64 parentGasExcess_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct calculateBaseFeeCall {
        #[allow(missing_docs)]
        pub _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub _blocktime: u64,
        #[allow(missing_docs)]
        pub _parentGasExcess: u64,
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`calculateBaseFee((uint8,uint8,uint32,uint64,uint32),uint64,uint64,uint32)`](calculateBaseFeeCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct calculateBaseFeeReturn {
        #[allow(missing_docs)]
        pub basefee_: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub parentGasExcess_: u64,
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
                OntakeAnchor::BaseFeeConfig,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
                u64,
                u64,
                u32,
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
            impl ::core::convert::From<calculateBaseFeeCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: calculateBaseFeeCall) -> Self {
                    (
                        value._baseFeeConfig,
                        value._blocktime,
                        value._parentGasExcess,
                        value._parentGasUsed,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for calculateBaseFeeCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _baseFeeConfig: tuple.0,
                        _blocktime: tuple.1,
                        _parentGasExcess: tuple.2,
                        _parentGasUsed: tuple.3,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
                u64,
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
            impl ::core::convert::From<calculateBaseFeeReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: calculateBaseFeeReturn) -> Self {
                    (value.basefee_, value.parentGasExcess_)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for calculateBaseFeeReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        basefee_: tuple.0,
                        parentGasExcess_: tuple.1,
                    }
                }
            }
        }
        impl calculateBaseFeeReturn {
            fn _tokenize(
                &self,
            ) -> <calculateBaseFeeCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.basefee_),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentGasExcess_),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for calculateBaseFeeCall {
            type Parameters<'a> = (
                OntakeAnchor::BaseFeeConfig,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = calculateBaseFeeReturn;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "calculateBaseFee((uint8,uint8,uint32,uint64,uint32),uint64,uint64,uint32)";
            const SELECTOR: [u8; 4] = [233u8, 2u8, 70u8, 26u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <OntakeAnchor::BaseFeeConfig as alloy_sol_types::SolType>::tokenize(
                        &self._baseFeeConfig,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._blocktime),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasExcess),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                calculateBaseFeeReturn::_tokenize(ret)
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
    /**Function with signature `getBasefee(uint64,uint32)` and selector `0xa7e022d1`.
```solidity
function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) external pure returns (uint256 basefee_, uint64 parentGasExcess_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBasefeeCall {
        #[allow(missing_docs)]
        pub _anchorBlockId: u64,
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBasefee(uint64,uint32)`](getBasefeeCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBasefeeReturn {
        #[allow(missing_docs)]
        pub basefee_: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub parentGasExcess_: u64,
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
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64, u32);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<getBasefeeCall> for UnderlyingRustTuple<'_> {
                fn from(value: getBasefeeCall) -> Self {
                    (value._anchorBlockId, value._parentGasUsed)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBasefeeCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _anchorBlockId: tuple.0,
                        _parentGasUsed: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
                u64,
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
            impl ::core::convert::From<getBasefeeReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getBasefeeReturn) -> Self {
                    (value.basefee_, value.parentGasExcess_)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBasefeeReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        basefee_: tuple.0,
                        parentGasExcess_: tuple.1,
                    }
                }
            }
        }
        impl getBasefeeReturn {
            fn _tokenize(
                &self,
            ) -> <getBasefeeCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.basefee_),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentGasExcess_),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBasefeeCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = getBasefeeReturn;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBasefee(uint64,uint32)";
            const SELECTOR: [u8; 4] = [167u8, 224u8, 34u8, 209u8];
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
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorBlockId),
                    <alloy::sol_types::sol_data::Uint<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                getBasefeeReturn::_tokenize(ret)
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
    /**Function with signature `getBasefeeV2(uint32,uint64,(uint8,uint8,uint32,uint64,uint32))` and selector `0x893f5460`.
```solidity
function getBasefeeV2(uint32 _parentGasUsed, uint64 _blockTimestamp, OntakeAnchor.BaseFeeConfig memory _baseFeeConfig) external view returns (uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBasefeeV2Call {
        #[allow(missing_docs)]
        pub _parentGasUsed: u32,
        #[allow(missing_docs)]
        pub _blockTimestamp: u64,
        #[allow(missing_docs)]
        pub _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBasefeeV2(uint32,uint64,(uint8,uint8,uint32,uint64,uint32))`](getBasefeeV2Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBasefeeV2Return {
        #[allow(missing_docs)]
        pub basefee_: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub newGasTarget_: u64,
        #[allow(missing_docs)]
        pub newGasExcess_: u64,
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
                alloy::sol_types::sol_data::Uint<32>,
                alloy::sol_types::sol_data::Uint<64>,
                OntakeAnchor::BaseFeeConfig,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u32,
                u64,
                <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBasefeeV2Call> for UnderlyingRustTuple<'_> {
                fn from(value: getBasefeeV2Call) -> Self {
                    (value._parentGasUsed, value._blockTimestamp, value._baseFeeConfig)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBasefeeV2Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _parentGasUsed: tuple.0,
                        _blockTimestamp: tuple.1,
                        _baseFeeConfig: tuple.2,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
                u64,
                u64,
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
            impl ::core::convert::From<getBasefeeV2Return> for UnderlyingRustTuple<'_> {
                fn from(value: getBasefeeV2Return) -> Self {
                    (value.basefee_, value.newGasTarget_, value.newGasExcess_)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBasefeeV2Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        basefee_: tuple.0,
                        newGasTarget_: tuple.1,
                        newGasExcess_: tuple.2,
                    }
                }
            }
        }
        impl getBasefeeV2Return {
            fn _tokenize(
                &self,
            ) -> <getBasefeeV2Call as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.basefee_),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.newGasTarget_),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.newGasExcess_),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBasefeeV2Call {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<32>,
                alloy::sol_types::sol_data::Uint<64>,
                OntakeAnchor::BaseFeeConfig,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = getBasefeeV2Return;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBasefeeV2(uint32,uint64,(uint8,uint8,uint32,uint64,uint32))";
            const SELECTOR: [u8; 4] = [137u8, 63u8, 84u8, 96u8];
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
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._parentGasUsed),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._blockTimestamp),
                    <OntakeAnchor::BaseFeeConfig as alloy_sol_types::SolType>::tokenize(
                        &self._baseFeeConfig,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                getBasefeeV2Return::_tokenize(ret)
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
    /**Function with signature `getBlockHash(uint256)` and selector `0xee82ac5e`.
```solidity
function getBlockHash(uint256 _blockId) external view returns (bytes32 blockHash_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlockHashCall {
        #[allow(missing_docs)]
        pub _blockId: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBlockHash(uint256)`](getBlockHashCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlockHashReturn {
        #[allow(missing_docs)]
        pub blockHash_: alloy::sol_types::private::FixedBytes<32>,
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
            impl ::core::convert::From<getBlockHashCall> for UnderlyingRustTuple<'_> {
                fn from(value: getBlockHashCall) -> Self {
                    (value._blockId,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlockHashCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _blockId: tuple.0 }
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
            impl ::core::convert::From<getBlockHashReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getBlockHashReturn) -> Self {
                    (value.blockHash_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlockHashReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { blockHash_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBlockHashCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBlockHash(uint256)";
            const SELECTOR: [u8; 4] = [238u8, 130u8, 172u8, 94u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._blockId),
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
                        let r: getBlockHashReturn = r.into();
                        r.blockHash_
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
                        let r: getBlockHashReturn = r.into();
                        r.blockHash_
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getDesignatedProver(uint48,address,bytes)` and selector `0x1c418a44`.
```solidity
function getDesignatedProver(uint48 _proposalId, address _proposer, bytes memory _proverAuth) external view returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getDesignatedProverCall {
        #[allow(missing_docs)]
        pub _proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _proverAuth: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getDesignatedProver(uint48,address,bytes)`](getDesignatedProverCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getDesignatedProverReturn {
        #[allow(missing_docs)]
        pub isLowBondProposal_: bool,
        #[allow(missing_docs)]
        pub designatedProver_: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub provingFeeToTransfer_: alloy::sol_types::private::primitives::aliases::U256,
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
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U48,
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
            impl ::core::convert::From<getDesignatedProverCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getDesignatedProverCall) -> Self {
                    (value._proposalId, value._proposer, value._proverAuth)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getDesignatedProverCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _proposalId: tuple.0,
                        _proposer: tuple.1,
                        _proverAuth: tuple.2,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Bool,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                bool,
                alloy::sol_types::private::Address,
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
            impl ::core::convert::From<getDesignatedProverReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getDesignatedProverReturn) -> Self {
                    (
                        value.isLowBondProposal_,
                        value.designatedProver_,
                        value.provingFeeToTransfer_,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getDesignatedProverReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        isLowBondProposal_: tuple.0,
                        designatedProver_: tuple.1,
                        provingFeeToTransfer_: tuple.2,
                    }
                }
            }
        }
        impl getDesignatedProverReturn {
            fn _tokenize(
                &self,
            ) -> <getDesignatedProverCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isLowBondProposal_,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver_,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.provingFeeToTransfer_),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getDesignatedProverCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = getDesignatedProverReturn;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Bool,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getDesignatedProver(uint48,address,bytes)";
            const SELECTOR: [u8; 4] = [28u8, 65u8, 138u8, 68u8];
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
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._proposalId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._proposer,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._proverAuth,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                getDesignatedProverReturn::_tokenize(ret)
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
    /**Function with signature `getState()` and selector `0x1865c57d`.
```solidity
function getState() external view returns (ShastaAnchor.State memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getStateCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getState()`](getStateCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getStateReturn {
        #[allow(missing_docs)]
        pub _0: <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getStateCall> for UnderlyingRustTuple<'_> {
                fn from(value: getStateCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getStateCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ShastaAnchor::State,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getStateReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getStateReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getStateReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getStateCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ShastaAnchor::State as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ShastaAnchor::State,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getState()";
            const SELECTOR: [u8; 4] = [24u8, 101u8, 197u8, 125u8];
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
                (<ShastaAnchor::State as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: getStateReturn = r.into();
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
                        let r: getStateReturn = r.into();
                        r._0
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
    /**Function with signature `init(address,uint64,uint64)` and selector `0xb310e9e9`.
```solidity
function init(address _owner, uint64 _l1ChainId, uint64 _initialGasExcess) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct initCall {
        #[allow(missing_docs)]
        pub _owner: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _l1ChainId: u64,
        #[allow(missing_docs)]
        pub _initialGasExcess: u64,
    }
    ///Container type for the return parameters of the [`init(address,uint64,uint64)`](initCall) function.
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
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                u64,
                u64,
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
            impl ::core::convert::From<initCall> for UnderlyingRustTuple<'_> {
                fn from(value: initCall) -> Self {
                    (value._owner, value._l1ChainId, value._initialGasExcess)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for initCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _owner: tuple.0,
                        _l1ChainId: tuple.1,
                        _initialGasExcess: tuple.2,
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
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Uint<64>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = initReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "init(address,uint64,uint64)";
            const SELECTOR: [u8; 4] = [179u8, 16u8, 233u8, 233u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._l1ChainId),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._initialGasExcess),
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
    /**Function with signature `l1ChainId()` and selector `0x12622e5b`.
```solidity
function l1ChainId() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct l1ChainIdCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`l1ChainId()`](l1ChainIdCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct l1ChainIdReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<l1ChainIdCall> for UnderlyingRustTuple<'_> {
                fn from(value: l1ChainIdCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for l1ChainIdCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<l1ChainIdReturn> for UnderlyingRustTuple<'_> {
                fn from(value: l1ChainIdReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for l1ChainIdReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for l1ChainIdCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "l1ChainId()";
            const SELECTOR: [u8; 4] = [18u8, 98u8, 46u8, 91u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: l1ChainIdReturn = r.into();
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
                        let r: l1ChainIdReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `lastAnchorGasUsed()` and selector `0x4ef77eb5`.
```solidity
function lastAnchorGasUsed() external view returns (uint32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lastAnchorGasUsedCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`lastAnchorGasUsed()`](lastAnchorGasUsedCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lastAnchorGasUsedReturn {
        #[allow(missing_docs)]
        pub _0: u32,
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
            impl ::core::convert::From<lastAnchorGasUsedCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: lastAnchorGasUsedCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for lastAnchorGasUsedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<32>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u32,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<lastAnchorGasUsedReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: lastAnchorGasUsedReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for lastAnchorGasUsedReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for lastAnchorGasUsedCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u32;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "lastAnchorGasUsed()";
            const SELECTOR: [u8; 4] = [78u8, 247u8, 126u8, 181u8];
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
                    <alloy::sol_types::sol_data::Uint<
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
                        let r: lastAnchorGasUsedReturn = r.into();
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
                        let r: lastAnchorGasUsedReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `lastCheckpoint()` and selector `0xd32e81a5`.
```solidity
function lastCheckpoint() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lastCheckpointCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`lastCheckpoint()`](lastCheckpointCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct lastCheckpointReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<lastCheckpointCall> for UnderlyingRustTuple<'_> {
                fn from(value: lastCheckpointCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for lastCheckpointCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<lastCheckpointReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: lastCheckpointReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for lastCheckpointReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for lastCheckpointCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "lastCheckpoint()";
            const SELECTOR: [u8; 4] = [211u8, 46u8, 129u8, 165u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: lastCheckpointReturn = r.into();
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
                        let r: lastCheckpointReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `livenessBondGwei()` and selector `0x9de74679`.
```solidity
function livenessBondGwei() external view returns (uint48);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct livenessBondGweiCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`livenessBondGwei()`](livenessBondGweiCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct livenessBondGweiReturn {
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
            impl ::core::convert::From<livenessBondGweiCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: livenessBondGweiCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for livenessBondGweiCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
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
            impl ::core::convert::From<livenessBondGweiReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: livenessBondGweiReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for livenessBondGweiReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for livenessBondGweiCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U48;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "livenessBondGwei()";
            const SELECTOR: [u8; 4] = [157u8, 231u8, 70u8, 121u8];
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
                        let r: livenessBondGweiReturn = r.into();
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
                        let r: livenessBondGweiReturn = r.into();
                        r._0
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
    /**Function with signature `pacayaForkHeight()` and selector `0xba9f41e8`.
```solidity
function pacayaForkHeight() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pacayaForkHeightCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`pacayaForkHeight()`](pacayaForkHeightCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pacayaForkHeightReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<pacayaForkHeightCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: pacayaForkHeightCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for pacayaForkHeightCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<pacayaForkHeightReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: pacayaForkHeightReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for pacayaForkHeightReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for pacayaForkHeightCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "pacayaForkHeight()";
            const SELECTOR: [u8; 4] = [186u8, 159u8, 65u8, 232u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: pacayaForkHeightReturn = r.into();
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
                        let r: pacayaForkHeightReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `parentGasExcess()` and selector `0xb8c7b30c`.
```solidity
function parentGasExcess() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentGasExcessCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`parentGasExcess()`](parentGasExcessCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentGasExcessReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<parentGasExcessCall> for UnderlyingRustTuple<'_> {
                fn from(value: parentGasExcessCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for parentGasExcessCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<parentGasExcessReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: parentGasExcessReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for parentGasExcessReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for parentGasExcessCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "parentGasExcess()";
            const SELECTOR: [u8; 4] = [184u8, 199u8, 179u8, 12u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: parentGasExcessReturn = r.into();
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
                        let r: parentGasExcessReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `parentGasTarget()` and selector `0xa7137c0f`.
```solidity
function parentGasTarget() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentGasTargetCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`parentGasTarget()`](parentGasTargetCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentGasTargetReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<parentGasTargetCall> for UnderlyingRustTuple<'_> {
                fn from(value: parentGasTargetCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for parentGasTargetCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<parentGasTargetReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: parentGasTargetReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for parentGasTargetReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for parentGasTargetCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "parentGasTarget()";
            const SELECTOR: [u8; 4] = [167u8, 19u8, 124u8, 15u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: parentGasTargetReturn = r.into();
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
                        let r: parentGasTargetReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `parentTimestamp()` and selector `0x539b8ade`.
```solidity
function parentTimestamp() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentTimestampCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`parentTimestamp()`](parentTimestampCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct parentTimestampReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<parentTimestampCall> for UnderlyingRustTuple<'_> {
                fn from(value: parentTimestampCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for parentTimestampCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<parentTimestampReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: parentTimestampReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for parentTimestampReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for parentTimestampCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "parentTimestamp()";
            const SELECTOR: [u8; 4] = [83u8, 155u8, 138u8, 222u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: parentTimestampReturn = r.into();
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
                        let r: parentTimestampReturn = r.into();
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
    /**Function with signature `provabilityBondGwei()` and selector `0x79efb434`.
```solidity
function provabilityBondGwei() external view returns (uint48);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct provabilityBondGweiCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`provabilityBondGwei()`](provabilityBondGweiCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct provabilityBondGweiReturn {
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
            impl ::core::convert::From<provabilityBondGweiCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: provabilityBondGweiCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for provabilityBondGweiCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
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
            impl ::core::convert::From<provabilityBondGweiReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: provabilityBondGweiReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for provabilityBondGweiReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for provabilityBondGweiCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U48;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "provabilityBondGwei()";
            const SELECTOR: [u8; 4] = [121u8, 239u8, 180u8, 52u8];
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
                        let r: provabilityBondGweiReturn = r.into();
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
                        let r: provabilityBondGweiReturn = r.into();
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
    /**Function with signature `publicInputHash()` and selector `0xdac5df78`.
```solidity
function publicInputHash() external view returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct publicInputHashCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`publicInputHash()`](publicInputHashCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct publicInputHashReturn {
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
            impl ::core::convert::From<publicInputHashCall> for UnderlyingRustTuple<'_> {
                fn from(value: publicInputHashCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for publicInputHashCall {
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
            impl ::core::convert::From<publicInputHashReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: publicInputHashReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for publicInputHashReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for publicInputHashCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "publicInputHash()";
            const SELECTOR: [u8; 4] = [218u8, 197u8, 223u8, 120u8];
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
                        let r: publicInputHashReturn = r.into();
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
                        let r: publicInputHashReturn = r.into();
                        r._0
                    })
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
    /**Function with signature `shastaForkHeight()` and selector `0xf37f2868`.
```solidity
function shastaForkHeight() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct shastaForkHeightCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`shastaForkHeight()`](shastaForkHeightCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct shastaForkHeightReturn {
        #[allow(missing_docs)]
        pub _0: u64,
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
            impl ::core::convert::From<shastaForkHeightCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: shastaForkHeightCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for shastaForkHeightCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (u64,);
            #[cfg(test)]
            #[allow(dead_code, unreachable_patterns)]
            fn _type_assertion(
                _t: alloy_sol_types::private::AssertTypeEq<UnderlyingRustTuple>,
            ) {
                match _t {
                    alloy_sol_types::private::AssertTypeEq::<
                        <UnderlyingSolTuple as alloy_sol_types::SolType>::RustType,
                    >(_) => {}
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<shastaForkHeightReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: shastaForkHeightReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for shastaForkHeightReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for shastaForkHeightCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "shastaForkHeight()";
            const SELECTOR: [u8; 4] = [243u8, 127u8, 40u8, 104u8];
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
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(ret),
                )
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: shastaForkHeightReturn = r.into();
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
                        let r: shastaForkHeightReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `signalService()` and selector `0x62d09453`.
```solidity
function signalService() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct signalServiceCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`signalService()`](signalServiceCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct signalServiceReturn {
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
            impl ::core::convert::From<signalServiceCall> for UnderlyingRustTuple<'_> {
                fn from(value: signalServiceCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for signalServiceCall {
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
            impl ::core::convert::From<signalServiceReturn> for UnderlyingRustTuple<'_> {
                fn from(value: signalServiceReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for signalServiceReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for signalServiceCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "signalService()";
            const SELECTOR: [u8; 4] = [98u8, 208u8, 148u8, 83u8];
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
                        let r: signalServiceReturn = r.into();
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
                        let r: signalServiceReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `skipFeeCheck()` and selector `0x2f980473`.
```solidity
function skipFeeCheck() external pure returns (bool skipCheck_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct skipFeeCheckCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`skipFeeCheck()`](skipFeeCheckCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct skipFeeCheckReturn {
        #[allow(missing_docs)]
        pub skipCheck_: bool,
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
            impl ::core::convert::From<skipFeeCheckCall> for UnderlyingRustTuple<'_> {
                fn from(value: skipFeeCheckCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for skipFeeCheckCall {
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
            impl ::core::convert::From<skipFeeCheckReturn> for UnderlyingRustTuple<'_> {
                fn from(value: skipFeeCheckReturn) -> Self {
                    (value.skipCheck_,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for skipFeeCheckReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { skipCheck_: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for skipFeeCheckCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "skipFeeCheck()";
            const SELECTOR: [u8; 4] = [47u8, 152u8, 4u8, 115u8];
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
                        let r: skipFeeCheckReturn = r.into();
                        r.skipCheck_
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
                        let r: skipFeeCheckReturn = r.into();
                        r.skipCheck_
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
    #[derive()]
    /**Function with signature `updateState(uint48,address,bytes,bytes32,(uint48,uint8,address,address)[],uint16,uint48,bytes32,bytes32,uint48)` and selector `0xf2a49b00`.
```solidity
function updateState(uint48 _proposalId, address _proposer, bytes memory _proverAuth, bytes32 _bondInstructionsHash, LibBonds.BondInstruction[] memory _bondInstructions, uint16 _blockIndex, uint48 _anchorBlockNumber, bytes32 _anchorBlockHash, bytes32 _anchorStateRoot, uint48 _endOfSubmissionWindowTimestamp) external returns (ShastaAnchor.State memory previousState_, ShastaAnchor.State memory newState_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct updateStateCall {
        #[allow(missing_docs)]
        pub _proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _proverAuth: alloy::sol_types::private::Bytes,
        #[allow(missing_docs)]
        pub _bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _bondInstructions: alloy::sol_types::private::Vec<
            <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
        >,
        #[allow(missing_docs)]
        pub _blockIndex: u16,
        #[allow(missing_docs)]
        pub _anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _anchorBlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _endOfSubmissionWindowTimestamp: alloy::sol_types::private::primitives::aliases::U48,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`updateState(uint48,address,bytes,bytes32,(uint48,uint8,address,address)[],uint16,uint48,bytes32,bytes32,uint48)`](updateStateCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct updateStateReturn {
        #[allow(missing_docs)]
        pub previousState_: <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub newState_: <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
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
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
                alloy::sol_types::sol_data::Uint<16>,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<48>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Bytes,
                alloy::sol_types::private::FixedBytes<32>,
                alloy::sol_types::private::Vec<
                    <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
                >,
                u16,
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::FixedBytes<32>,
                alloy::sol_types::private::FixedBytes<32>,
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
            impl ::core::convert::From<updateStateCall> for UnderlyingRustTuple<'_> {
                fn from(value: updateStateCall) -> Self {
                    (
                        value._proposalId,
                        value._proposer,
                        value._proverAuth,
                        value._bondInstructionsHash,
                        value._bondInstructions,
                        value._blockIndex,
                        value._anchorBlockNumber,
                        value._anchorBlockHash,
                        value._anchorStateRoot,
                        value._endOfSubmissionWindowTimestamp,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for updateStateCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _proposalId: tuple.0,
                        _proposer: tuple.1,
                        _proverAuth: tuple.2,
                        _bondInstructionsHash: tuple.3,
                        _bondInstructions: tuple.4,
                        _blockIndex: tuple.5,
                        _anchorBlockNumber: tuple.6,
                        _anchorBlockHash: tuple.7,
                        _anchorStateRoot: tuple.8,
                        _endOfSubmissionWindowTimestamp: tuple.9,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ShastaAnchor::State, ShastaAnchor::State);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
                <ShastaAnchor::State as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<updateStateReturn> for UnderlyingRustTuple<'_> {
                fn from(value: updateStateReturn) -> Self {
                    (value.previousState_, value.newState_)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for updateStateReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        previousState_: tuple.0,
                        newState_: tuple.1,
                    }
                }
            }
        }
        impl updateStateReturn {
            fn _tokenize(
                &self,
            ) -> <updateStateCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <ShastaAnchor::State as alloy_sol_types::SolType>::tokenize(
                        &self.previousState_,
                    ),
                    <ShastaAnchor::State as alloy_sol_types::SolType>::tokenize(
                        &self.newState_,
                    ),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for updateStateCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
                alloy::sol_types::sol_data::Uint<16>,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<48>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = updateStateReturn;
            type ReturnTuple<'a> = (ShastaAnchor::State, ShastaAnchor::State);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "updateState(uint48,address,bytes,bytes32,(uint48,uint8,address,address)[],uint16,uint48,bytes32,bytes32,uint48)";
            const SELECTOR: [u8; 4] = [242u8, 164u8, 155u8, 0u8];
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
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._proposalId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._proposer,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._proverAuth,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self._bondInstructionsHash,
                    ),
                    <alloy::sol_types::sol_data::Array<
                        LibBonds::BondInstruction,
                    > as alloy_sol_types::SolType>::tokenize(&self._bondInstructions),
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self._blockIndex),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorBlockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._anchorStateRoot),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self._endOfSubmissionWindowTimestamp,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                updateStateReturn::_tokenize(ret)
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
    /**Function with signature `withdraw(address,address)` and selector `0xf940e385`.
```solidity
function withdraw(address _token, address _to) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct withdrawCall {
        #[allow(missing_docs)]
        pub _token: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _to: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`withdraw(address,address)`](withdrawCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct withdrawReturn {}
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
            impl ::core::convert::From<withdrawCall> for UnderlyingRustTuple<'_> {
                fn from(value: withdrawCall) -> Self {
                    (value._token, value._to)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for withdrawCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _token: tuple.0,
                        _to: tuple.1,
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
            impl ::core::convert::From<withdrawReturn> for UnderlyingRustTuple<'_> {
                fn from(value: withdrawReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for withdrawReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl withdrawReturn {
            fn _tokenize(
                &self,
            ) -> <withdrawCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for withdrawCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = withdrawReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "withdraw(address,address)";
            const SELECTOR: [u8; 4] = [249u8, 64u8, 227u8, 133u8];
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
                        &self._token,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._to,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                withdrawReturn::_tokenize(ret)
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
    ///Container for all the [`TaikoAnchor`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum TaikoAnchorCalls {
        #[allow(missing_docs)]
        ANCHOR_GAS_LIMIT(ANCHOR_GAS_LIMITCall),
        #[allow(missing_docs)]
        BASEFEE_MIN_VALUE(BASEFEE_MIN_VALUECall),
        #[allow(missing_docs)]
        GOLDEN_TOUCH_ADDRESS(GOLDEN_TOUCH_ADDRESSCall),
        #[allow(missing_docs)]
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        adjustExcess(adjustExcessCall),
        #[allow(missing_docs)]
        anchor(anchorCall),
        #[allow(missing_docs)]
        anchorV2(anchorV2Call),
        #[allow(missing_docs)]
        anchorV3(anchorV3Call),
        #[allow(missing_docs)]
        blockIdToEndOfSubmissionWindowTimeStamp(
            blockIdToEndOfSubmissionWindowTimeStampCall,
        ),
        #[allow(missing_docs)]
        bondManager(bondManagerCall),
        #[allow(missing_docs)]
        calculateBaseFee(calculateBaseFeeCall),
        #[allow(missing_docs)]
        getBasefee(getBasefeeCall),
        #[allow(missing_docs)]
        getBasefeeV2(getBasefeeV2Call),
        #[allow(missing_docs)]
        getBlockHash(getBlockHashCall),
        #[allow(missing_docs)]
        getDesignatedProver(getDesignatedProverCall),
        #[allow(missing_docs)]
        getState(getStateCall),
        #[allow(missing_docs)]
        r#impl(implCall),
        #[allow(missing_docs)]
        inNonReentrant(inNonReentrantCall),
        #[allow(missing_docs)]
        init(initCall),
        #[allow(missing_docs)]
        l1ChainId(l1ChainIdCall),
        #[allow(missing_docs)]
        lastAnchorGasUsed(lastAnchorGasUsedCall),
        #[allow(missing_docs)]
        lastCheckpoint(lastCheckpointCall),
        #[allow(missing_docs)]
        livenessBondGwei(livenessBondGweiCall),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pacayaForkHeight(pacayaForkHeightCall),
        #[allow(missing_docs)]
        parentGasExcess(parentGasExcessCall),
        #[allow(missing_docs)]
        parentGasTarget(parentGasTargetCall),
        #[allow(missing_docs)]
        parentTimestamp(parentTimestampCall),
        #[allow(missing_docs)]
        pause(pauseCall),
        #[allow(missing_docs)]
        paused(pausedCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        provabilityBondGwei(provabilityBondGweiCall),
        #[allow(missing_docs)]
        proxiableUUID(proxiableUUIDCall),
        #[allow(missing_docs)]
        publicInputHash(publicInputHashCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        resolver(resolverCall),
        #[allow(missing_docs)]
        shastaForkHeight(shastaForkHeightCall),
        #[allow(missing_docs)]
        signalService(signalServiceCall),
        #[allow(missing_docs)]
        skipFeeCheck(skipFeeCheckCall),
        #[allow(missing_docs)]
        transferOwnership(transferOwnershipCall),
        #[allow(missing_docs)]
        unpause(unpauseCall),
        #[allow(missing_docs)]
        updateState(updateStateCall),
        #[allow(missing_docs)]
        upgradeTo(upgradeToCall),
        #[allow(missing_docs)]
        upgradeToAndCall(upgradeToAndCallCall),
        #[allow(missing_docs)]
        withdraw(withdrawCall),
    }
    #[automatically_derived]
    impl TaikoAnchorCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [4u8, 243u8, 188u8, 236u8],
            [18u8, 98u8, 46u8, 91u8],
            [19u8, 109u8, 196u8, 168u8],
            [24u8, 101u8, 197u8, 125u8],
            [28u8, 65u8, 138u8, 68u8],
            [47u8, 152u8, 4u8, 115u8],
            [48u8, 117u8, 219u8, 86u8],
            [54u8, 60u8, 196u8, 39u8],
            [54u8, 89u8, 207u8, 230u8],
            [63u8, 75u8, 168u8, 58u8],
            [72u8, 8u8, 10u8, 69u8],
            [78u8, 247u8, 126u8, 181u8],
            [79u8, 30u8, 242u8, 134u8],
            [82u8, 209u8, 144u8, 45u8],
            [83u8, 155u8, 138u8, 222u8],
            [92u8, 151u8, 90u8, 187u8],
            [98u8, 208u8, 148u8, 83u8],
            [113u8, 80u8, 24u8, 166u8],
            [121u8, 186u8, 80u8, 151u8],
            [121u8, 239u8, 180u8, 52u8],
            [132u8, 86u8, 203u8, 89u8],
            [137u8, 63u8, 84u8, 96u8],
            [138u8, 191u8, 96u8, 119u8],
            [141u8, 165u8, 203u8, 91u8],
            [157u8, 231u8, 70u8, 121u8],
            [158u8, 229u8, 18u8, 242u8],
            [167u8, 19u8, 124u8, 15u8],
            [167u8, 224u8, 34u8, 209u8],
            [178u8, 16u8, 95u8, 236u8],
            [179u8, 16u8, 233u8, 233u8],
            [184u8, 199u8, 179u8, 12u8],
            [186u8, 159u8, 65u8, 232u8],
            [196u8, 110u8, 58u8, 102u8],
            [203u8, 217u8, 153u8, 158u8],
            [211u8, 46u8, 129u8, 165u8],
            [218u8, 105u8, 211u8, 219u8],
            [218u8, 197u8, 223u8, 120u8],
            [227u8, 12u8, 57u8, 120u8],
            [233u8, 2u8, 70u8, 26u8],
            [238u8, 130u8, 172u8, 94u8],
            [242u8, 164u8, 155u8, 0u8],
            [242u8, 253u8, 227u8, 139u8],
            [243u8, 127u8, 40u8, 104u8],
            [249u8, 64u8, 227u8, 133u8],
            [253u8, 133u8, 235u8, 45u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for TaikoAnchorCalls {
        const NAME: &'static str = "TaikoAnchorCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 45usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ANCHOR_GAS_LIMIT(_) => {
                    <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::BASEFEE_MIN_VALUE(_) => {
                    <BASEFEE_MIN_VALUECall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::GOLDEN_TOUCH_ADDRESS(_) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::adjustExcess(_) => {
                    <adjustExcessCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::anchor(_) => <anchorCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::anchorV2(_) => <anchorV2Call as alloy_sol_types::SolCall>::SELECTOR,
                Self::anchorV3(_) => <anchorV3Call as alloy_sol_types::SolCall>::SELECTOR,
                Self::blockIdToEndOfSubmissionWindowTimeStamp(_) => {
                    <blockIdToEndOfSubmissionWindowTimeStampCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::bondManager(_) => {
                    <bondManagerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::calculateBaseFee(_) => {
                    <calculateBaseFeeCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBasefee(_) => {
                    <getBasefeeCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBasefeeV2(_) => {
                    <getBasefeeV2Call as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBlockHash(_) => {
                    <getBlockHashCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getDesignatedProver(_) => {
                    <getDesignatedProverCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getState(_) => <getStateCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::r#impl(_) => <implCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::inNonReentrant(_) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::init(_) => <initCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::l1ChainId(_) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::lastAnchorGasUsed(_) => {
                    <lastAnchorGasUsedCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::lastCheckpoint(_) => {
                    <lastCheckpointCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::livenessBondGwei(_) => {
                    <livenessBondGweiCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pacayaForkHeight(_) => {
                    <pacayaForkHeightCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::parentGasExcess(_) => {
                    <parentGasExcessCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::parentGasTarget(_) => {
                    <parentGasTargetCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::parentTimestamp(_) => {
                    <parentTimestampCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::pause(_) => <pauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::paused(_) => <pausedCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::provabilityBondGwei(_) => {
                    <provabilityBondGweiCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proxiableUUID(_) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::publicInputHash(_) => {
                    <publicInputHashCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::resolver(_) => <resolverCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::shastaForkHeight(_) => {
                    <shastaForkHeightCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::signalService(_) => {
                    <signalServiceCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::skipFeeCheck(_) => {
                    <skipFeeCheckCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::transferOwnership(_) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::unpause(_) => <unpauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::updateState(_) => {
                    <updateStateCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::upgradeTo(_) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::upgradeToAndCall(_) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::withdraw(_) => <withdrawCall as alloy_sol_types::SolCall>::SELECTOR,
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
            ) -> alloy_sol_types::Result<TaikoAnchorCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::resolver)
                    }
                    resolver
                },
                {
                    fn l1ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <l1ChainIdCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::l1ChainId)
                    }
                    l1ChainId
                },
                {
                    fn adjustExcess(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <adjustExcessCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::adjustExcess)
                    }
                    adjustExcess
                },
                {
                    fn getState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getStateCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::getState)
                    }
                    getState
                },
                {
                    fn getDesignatedProver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::getDesignatedProver)
                    }
                    getDesignatedProver
                },
                {
                    fn skipFeeCheck(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <skipFeeCheckCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::skipFeeCheck)
                    }
                    skipFeeCheck
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn bondManager(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <bondManagerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::bondManager)
                    }
                    bondManager
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::unpause)
                    }
                    unpause
                },
                {
                    fn anchorV3(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorV3Call as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::anchorV3)
                    }
                    anchorV3
                },
                {
                    fn lastAnchorGasUsed(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <lastAnchorGasUsedCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::lastAnchorGasUsed)
                    }
                    lastAnchorGasUsed
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn parentTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentTimestampCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentTimestamp)
                    }
                    parentTimestamp
                },
                {
                    fn paused(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::paused)
                    }
                    paused
                },
                {
                    fn signalService(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <signalServiceCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::signalService)
                    }
                    signalService
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn provabilityBondGwei(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <provabilityBondGweiCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::provabilityBondGwei)
                    }
                    provabilityBondGwei
                },
                {
                    fn pause(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::pause)
                    }
                    pause
                },
                {
                    fn getBasefeeV2(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBasefeeV2Call as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBasefeeV2)
                    }
                    getBasefeeV2
                },
                {
                    fn r#impl(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::owner)
                    }
                    owner
                },
                {
                    fn livenessBondGwei(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <livenessBondGweiCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::livenessBondGwei)
                    }
                    livenessBondGwei
                },
                {
                    fn GOLDEN_TOUCH_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::GOLDEN_TOUCH_ADDRESS)
                    }
                    GOLDEN_TOUCH_ADDRESS
                },
                {
                    fn parentGasTarget(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentGasTargetCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentGasTarget)
                    }
                    parentGasTarget
                },
                {
                    fn getBasefee(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBasefeeCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBasefee)
                    }
                    getBasefee
                },
                {
                    fn blockIdToEndOfSubmissionWindowTimeStamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <blockIdToEndOfSubmissionWindowTimeStampCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(
                                TaikoAnchorCalls::blockIdToEndOfSubmissionWindowTimeStamp,
                            )
                    }
                    blockIdToEndOfSubmissionWindowTimeStamp
                },
                {
                    fn init(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::init)
                    }
                    init
                },
                {
                    fn parentGasExcess(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentGasExcessCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentGasExcess)
                    }
                    parentGasExcess
                },
                {
                    fn pacayaForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pacayaForkHeightCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::pacayaForkHeight)
                    }
                    pacayaForkHeight
                },
                {
                    fn ANCHOR_GAS_LIMIT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::ANCHOR_GAS_LIMIT)
                    }
                    ANCHOR_GAS_LIMIT
                },
                {
                    fn BASEFEE_MIN_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <BASEFEE_MIN_VALUECall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::BASEFEE_MIN_VALUE)
                    }
                    BASEFEE_MIN_VALUE
                },
                {
                    fn lastCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <lastCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::lastCheckpoint)
                    }
                    lastCheckpoint
                },
                {
                    fn anchor(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::anchor)
                    }
                    anchor
                },
                {
                    fn publicInputHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <publicInputHashCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::publicInputHash)
                    }
                    publicInputHash
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn calculateBaseFee(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <calculateBaseFeeCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::calculateBaseFee)
                    }
                    calculateBaseFee
                },
                {
                    fn getBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBlockHashCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBlockHash)
                    }
                    getBlockHash
                },
                {
                    fn updateState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <updateStateCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::updateState)
                    }
                    updateState
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn shastaForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <shastaForkHeightCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorCalls::shastaForkHeight)
                    }
                    shastaForkHeight
                },
                {
                    fn withdraw(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <withdrawCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::withdraw)
                    }
                    withdraw
                },
                {
                    fn anchorV2(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorV2Call as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(TaikoAnchorCalls::anchorV2)
                    }
                    anchorV2
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
            ) -> alloy_sol_types::Result<TaikoAnchorCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::resolver)
                    }
                    resolver
                },
                {
                    fn l1ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <l1ChainIdCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::l1ChainId)
                    }
                    l1ChainId
                },
                {
                    fn adjustExcess(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <adjustExcessCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::adjustExcess)
                    }
                    adjustExcess
                },
                {
                    fn getState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getStateCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::getState)
                    }
                    getState
                },
                {
                    fn getDesignatedProver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::getDesignatedProver)
                    }
                    getDesignatedProver
                },
                {
                    fn skipFeeCheck(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <skipFeeCheckCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::skipFeeCheck)
                    }
                    skipFeeCheck
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn bondManager(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <bondManagerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::bondManager)
                    }
                    bondManager
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::unpause)
                    }
                    unpause
                },
                {
                    fn anchorV3(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorV3Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::anchorV3)
                    }
                    anchorV3
                },
                {
                    fn lastAnchorGasUsed(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <lastAnchorGasUsedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::lastAnchorGasUsed)
                    }
                    lastAnchorGasUsed
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn parentTimestamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentTimestampCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentTimestamp)
                    }
                    parentTimestamp
                },
                {
                    fn paused(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::paused)
                    }
                    paused
                },
                {
                    fn signalService(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <signalServiceCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::signalService)
                    }
                    signalService
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn provabilityBondGwei(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <provabilityBondGweiCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::provabilityBondGwei)
                    }
                    provabilityBondGwei
                },
                {
                    fn pause(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::pause)
                    }
                    pause
                },
                {
                    fn getBasefeeV2(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBasefeeV2Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBasefeeV2)
                    }
                    getBasefeeV2
                },
                {
                    fn r#impl(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::owner)
                    }
                    owner
                },
                {
                    fn livenessBondGwei(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <livenessBondGweiCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::livenessBondGwei)
                    }
                    livenessBondGwei
                },
                {
                    fn GOLDEN_TOUCH_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::GOLDEN_TOUCH_ADDRESS)
                    }
                    GOLDEN_TOUCH_ADDRESS
                },
                {
                    fn parentGasTarget(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentGasTargetCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentGasTarget)
                    }
                    parentGasTarget
                },
                {
                    fn getBasefee(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBasefeeCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBasefee)
                    }
                    getBasefee
                },
                {
                    fn blockIdToEndOfSubmissionWindowTimeStamp(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <blockIdToEndOfSubmissionWindowTimeStampCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(
                                TaikoAnchorCalls::blockIdToEndOfSubmissionWindowTimeStamp,
                            )
                    }
                    blockIdToEndOfSubmissionWindowTimeStamp
                },
                {
                    fn init(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::init)
                    }
                    init
                },
                {
                    fn parentGasExcess(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <parentGasExcessCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::parentGasExcess)
                    }
                    parentGasExcess
                },
                {
                    fn pacayaForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pacayaForkHeightCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::pacayaForkHeight)
                    }
                    pacayaForkHeight
                },
                {
                    fn ANCHOR_GAS_LIMIT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::ANCHOR_GAS_LIMIT)
                    }
                    ANCHOR_GAS_LIMIT
                },
                {
                    fn BASEFEE_MIN_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <BASEFEE_MIN_VALUECall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::BASEFEE_MIN_VALUE)
                    }
                    BASEFEE_MIN_VALUE
                },
                {
                    fn lastCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <lastCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::lastCheckpoint)
                    }
                    lastCheckpoint
                },
                {
                    fn anchor(data: &[u8]) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::anchor)
                    }
                    anchor
                },
                {
                    fn publicInputHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <publicInputHashCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::publicInputHash)
                    }
                    publicInputHash
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn calculateBaseFee(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <calculateBaseFeeCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::calculateBaseFee)
                    }
                    calculateBaseFee
                },
                {
                    fn getBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <getBlockHashCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::getBlockHash)
                    }
                    getBlockHash
                },
                {
                    fn updateState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <updateStateCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::updateState)
                    }
                    updateState
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn shastaForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <shastaForkHeightCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::shastaForkHeight)
                    }
                    shastaForkHeight
                },
                {
                    fn withdraw(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <withdrawCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::withdraw)
                    }
                    withdraw
                },
                {
                    fn anchorV2(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorCalls> {
                        <anchorV2Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorCalls::anchorV2)
                    }
                    anchorV2
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
                Self::ANCHOR_GAS_LIMIT(inner) => {
                    <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::BASEFEE_MIN_VALUE(inner) => {
                    <BASEFEE_MIN_VALUECall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::GOLDEN_TOUCH_ADDRESS(inner) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::adjustExcess(inner) => {
                    <adjustExcessCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::anchor(inner) => {
                    <anchorCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::anchorV2(inner) => {
                    <anchorV2Call as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::anchorV3(inner) => {
                    <anchorV3Call as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::blockIdToEndOfSubmissionWindowTimeStamp(inner) => {
                    <blockIdToEndOfSubmissionWindowTimeStampCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::bondManager(inner) => {
                    <bondManagerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::calculateBaseFee(inner) => {
                    <calculateBaseFeeCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getBasefee(inner) => {
                    <getBasefeeCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::getBasefeeV2(inner) => {
                    <getBasefeeV2Call as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getBlockHash(inner) => {
                    <getBlockHashCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getDesignatedProver(inner) => {
                    <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getState(inner) => {
                    <getStateCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::r#impl(inner) => {
                    <implCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::inNonReentrant(inner) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::init(inner) => {
                    <initCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::l1ChainId(inner) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::lastAnchorGasUsed(inner) => {
                    <lastAnchorGasUsedCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::lastCheckpoint(inner) => {
                    <lastCheckpointCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::livenessBondGwei(inner) => {
                    <livenessBondGweiCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::pacayaForkHeight(inner) => {
                    <pacayaForkHeightCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::parentGasExcess(inner) => {
                    <parentGasExcessCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::parentGasTarget(inner) => {
                    <parentGasTargetCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::parentTimestamp(inner) => {
                    <parentTimestampCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
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
                Self::provabilityBondGwei(inner) => {
                    <provabilityBondGweiCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::proxiableUUID(inner) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::publicInputHash(inner) => {
                    <publicInputHashCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::shastaForkHeight(inner) => {
                    <shastaForkHeightCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::signalService(inner) => {
                    <signalServiceCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::skipFeeCheck(inner) => {
                    <skipFeeCheckCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::unpause(inner) => {
                    <unpauseCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::updateState(inner) => {
                    <updateStateCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::upgradeTo(inner) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::upgradeToAndCall(inner) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::withdraw(inner) => {
                    <withdrawCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::ANCHOR_GAS_LIMIT(inner) => {
                    <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::BASEFEE_MIN_VALUE(inner) => {
                    <BASEFEE_MIN_VALUECall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::GOLDEN_TOUCH_ADDRESS(inner) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::adjustExcess(inner) => {
                    <adjustExcessCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::anchor(inner) => {
                    <anchorCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::anchorV2(inner) => {
                    <anchorV2Call as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::anchorV3(inner) => {
                    <anchorV3Call as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::blockIdToEndOfSubmissionWindowTimeStamp(inner) => {
                    <blockIdToEndOfSubmissionWindowTimeStampCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::bondManager(inner) => {
                    <bondManagerCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::calculateBaseFee(inner) => {
                    <calculateBaseFeeCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBasefee(inner) => {
                    <getBasefeeCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBasefeeV2(inner) => {
                    <getBasefeeV2Call as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBlockHash(inner) => {
                    <getBlockHashCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getDesignatedProver(inner) => {
                    <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getState(inner) => {
                    <getStateCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::init(inner) => {
                    <initCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::l1ChainId(inner) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::lastAnchorGasUsed(inner) => {
                    <lastAnchorGasUsedCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::lastCheckpoint(inner) => {
                    <lastCheckpointCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::livenessBondGwei(inner) => {
                    <livenessBondGweiCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::pacayaForkHeight(inner) => {
                    <pacayaForkHeightCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::parentGasExcess(inner) => {
                    <parentGasExcessCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::parentGasTarget(inner) => {
                    <parentGasTargetCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::parentTimestamp(inner) => {
                    <parentTimestampCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
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
                Self::provabilityBondGwei(inner) => {
                    <provabilityBondGweiCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::publicInputHash(inner) => {
                    <publicInputHashCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::shastaForkHeight(inner) => {
                    <shastaForkHeightCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::signalService(inner) => {
                    <signalServiceCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::skipFeeCheck(inner) => {
                    <skipFeeCheckCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::unpause(inner) => {
                    <unpauseCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::updateState(inner) => {
                    <updateStateCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
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
                Self::withdraw(inner) => {
                    <withdrawCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`TaikoAnchor`](self) custom errors.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum TaikoAnchorErrors {
        #[allow(missing_docs)]
        ACCESS_DENIED(ACCESS_DENIED),
        #[allow(missing_docs)]
        BlockHashAlreadySet(BlockHashAlreadySet),
        #[allow(missing_docs)]
        BondInstructionsHashMismatch(BondInstructionsHashMismatch),
        #[allow(missing_docs)]
        ETH_TRANSFER_FAILED(ETH_TRANSFER_FAILED),
        #[allow(missing_docs)]
        FUNC_NOT_IMPLEMENTED(FUNC_NOT_IMPLEMENTED),
        #[allow(missing_docs)]
        INVALID_PAUSE_STATUS(INVALID_PAUSE_STATUS),
        #[allow(missing_docs)]
        InvalidAnchorBlockNumber(InvalidAnchorBlockNumber),
        #[allow(missing_docs)]
        InvalidBlockIndex(InvalidBlockIndex),
        #[allow(missing_docs)]
        InvalidForkHeight(InvalidForkHeight),
        #[allow(missing_docs)]
        L2_BASEFEE_MISMATCH(L2_BASEFEE_MISMATCH),
        #[allow(missing_docs)]
        L2_DEPRECATED_METHOD(L2_DEPRECATED_METHOD),
        #[allow(missing_docs)]
        L2_FORK_ERROR(L2_FORK_ERROR),
        #[allow(missing_docs)]
        L2_INVALID_L1_CHAIN_ID(L2_INVALID_L1_CHAIN_ID),
        #[allow(missing_docs)]
        L2_INVALID_L2_CHAIN_ID(L2_INVALID_L2_CHAIN_ID),
        #[allow(missing_docs)]
        L2_INVALID_SENDER(L2_INVALID_SENDER),
        #[allow(missing_docs)]
        L2_PUBLIC_INPUT_HASH_MISMATCH(L2_PUBLIC_INPUT_HASH_MISMATCH),
        #[allow(missing_docs)]
        L2_TOO_LATE(L2_TOO_LATE),
        #[allow(missing_docs)]
        NonZeroAnchorBlockHash(NonZeroAnchorBlockHash),
        #[allow(missing_docs)]
        NonZeroAnchorStateRoot(NonZeroAnchorStateRoot),
        #[allow(missing_docs)]
        NonZeroBlockIndex(NonZeroBlockIndex),
        #[allow(missing_docs)]
        ProposalIdMismatch(ProposalIdMismatch),
        #[allow(missing_docs)]
        ProposerMismatch(ProposerMismatch),
        #[allow(missing_docs)]
        REENTRANT_CALL(REENTRANT_CALL),
        #[allow(missing_docs)]
        SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED),
        #[allow(missing_docs)]
        ZERO_ADDRESS(ZERO_ADDRESS),
        #[allow(missing_docs)]
        ZERO_VALUE(ZERO_VALUE),
        #[allow(missing_docs)]
        ZeroBlockCount(ZeroBlockCount),
    }
    #[automatically_derived]
    impl TaikoAnchorErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [2u8, 232u8, 242u8, 94u8],
            [23u8, 153u8, 200u8, 155u8],
            [24u8, 87u8, 31u8, 30u8],
            [33u8, 160u8, 13u8, 103u8],
            [34u8, 147u8, 41u8, 199u8],
            [65u8, 60u8, 209u8, 40u8],
            [74u8, 57u8, 50u8, 156u8],
            [83u8, 139u8, 164u8, 249u8],
            [89u8, 180u8, 82u8, 239u8],
            [97u8, 77u8, 197u8, 103u8],
            [100u8, 148u8, 233u8, 247u8],
            [109u8, 170u8, 154u8, 158u8],
            [136u8, 196u8, 112u8, 11u8],
            [143u8, 151u8, 46u8, 203u8],
            [149u8, 56u8, 62u8, 161u8],
            [152u8, 206u8, 38u8, 154u8],
            [153u8, 81u8, 210u8, 233u8],
            [173u8, 16u8, 54u8, 31u8],
            [180u8, 31u8, 60u8, 130u8],
            [186u8, 230u8, 226u8, 169u8],
            [202u8, 34u8, 239u8, 118u8],
            [215u8, 25u8, 37u8, 141u8],
            [223u8, 198u8, 13u8, 133u8],
            [224u8, 165u8, 170u8, 129u8],
            [229u8, 128u8, 18u8, 22u8],
            [236u8, 115u8, 41u8, 89u8],
            [241u8, 203u8, 2u8, 53u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for TaikoAnchorErrors {
        const NAME: &'static str = "TaikoAnchorErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 27usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ACCESS_DENIED(_) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::BlockHashAlreadySet(_) => {
                    <BlockHashAlreadySet as alloy_sol_types::SolError>::SELECTOR
                }
                Self::BondInstructionsHashMismatch(_) => {
                    <BondInstructionsHashMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ETH_TRANSFER_FAILED(_) => {
                    <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::FUNC_NOT_IMPLEMENTED(_) => {
                    <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::INVALID_PAUSE_STATUS(_) => {
                    <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidAnchorBlockNumber(_) => {
                    <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidBlockIndex(_) => {
                    <InvalidBlockIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidForkHeight(_) => {
                    <InvalidForkHeight as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_BASEFEE_MISMATCH(_) => {
                    <L2_BASEFEE_MISMATCH as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_DEPRECATED_METHOD(_) => {
                    <L2_DEPRECATED_METHOD as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_FORK_ERROR(_) => {
                    <L2_FORK_ERROR as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_INVALID_L1_CHAIN_ID(_) => {
                    <L2_INVALID_L1_CHAIN_ID as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_INVALID_L2_CHAIN_ID(_) => {
                    <L2_INVALID_L2_CHAIN_ID as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_INVALID_SENDER(_) => {
                    <L2_INVALID_SENDER as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_PUBLIC_INPUT_HASH_MISMATCH(_) => {
                    <L2_PUBLIC_INPUT_HASH_MISMATCH as alloy_sol_types::SolError>::SELECTOR
                }
                Self::L2_TOO_LATE(_) => {
                    <L2_TOO_LATE as alloy_sol_types::SolError>::SELECTOR
                }
                Self::NonZeroAnchorBlockHash(_) => {
                    <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::SELECTOR
                }
                Self::NonZeroAnchorStateRoot(_) => {
                    <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::SELECTOR
                }
                Self::NonZeroBlockIndex(_) => {
                    <NonZeroBlockIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ProposalIdMismatch(_) => {
                    <ProposalIdMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ProposerMismatch(_) => {
                    <ProposerMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::REENTRANT_CALL(_) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(_) => {
                    <SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ZERO_ADDRESS(_) => {
                    <ZERO_ADDRESS as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ZERO_VALUE(_) => {
                    <ZERO_VALUE as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ZeroBlockCount(_) => {
                    <ZeroBlockCount as alloy_sol_types::SolError>::SELECTOR
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
            ) -> alloy_sol_types::Result<TaikoAnchorErrors>] = &[
                {
                    fn InvalidForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidForkHeight as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidForkHeight)
                    }
                    InvalidForkHeight
                },
                {
                    fn L2_FORK_ERROR(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_FORK_ERROR as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_FORK_ERROR)
                    }
                    L2_FORK_ERROR
                },
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn NonZeroAnchorStateRoot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroAnchorStateRoot)
                    }
                    NonZeroAnchorStateRoot
                },
                {
                    fn ProposalIdMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ProposalIdMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::ProposalIdMismatch)
                    }
                    ProposalIdMismatch
                },
                {
                    fn L2_INVALID_L1_CHAIN_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_L1_CHAIN_ID as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_L1_CHAIN_ID)
                    }
                    L2_INVALID_L1_CHAIN_ID
                },
                {
                    fn NonZeroBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroBlockIndex)
                    }
                    NonZeroBlockIndex
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(TaikoAnchorErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn InvalidBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidBlockIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidBlockIndex)
                    }
                    InvalidBlockIndex
                },
                {
                    fn BlockHashAlreadySet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <BlockHashAlreadySet as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::BlockHashAlreadySet)
                    }
                    BlockHashAlreadySet
                },
                {
                    fn L2_INVALID_SENDER(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_SENDER as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_SENDER)
                    }
                    L2_INVALID_SENDER
                },
                {
                    fn L2_BASEFEE_MISMATCH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_BASEFEE_MISMATCH as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_BASEFEE_MISMATCH)
                    }
                    L2_BASEFEE_MISMATCH
                },
                {
                    fn BondInstructionsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::BondInstructionsHashMismatch)
                    }
                    BondInstructionsHashMismatch
                },
                {
                    fn L2_INVALID_L2_CHAIN_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_L2_CHAIN_ID as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_L2_CHAIN_ID)
                    }
                    L2_INVALID_L2_CHAIN_ID
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn ETH_TRANSFER_FAILED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::ETH_TRANSFER_FAILED)
                    }
                    ETH_TRANSFER_FAILED
                },
                {
                    fn SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED)
                    }
                    SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED
                },
                {
                    fn NonZeroAnchorBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroAnchorBlockHash)
                    }
                    NonZeroAnchorBlockHash
                },
                {
                    fn L2_TOO_LATE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_TOO_LATE as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(TaikoAnchorErrors::L2_TOO_LATE)
                    }
                    L2_TOO_LATE
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn ZeroBlockCount(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZeroBlockCount as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::ZeroBlockCount)
                    }
                    ZeroBlockCount
                },
                {
                    fn L2_PUBLIC_INPUT_HASH_MISMATCH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_PUBLIC_INPUT_HASH_MISMATCH as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_PUBLIC_INPUT_HASH_MISMATCH)
                    }
                    L2_PUBLIC_INPUT_HASH_MISMATCH
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn ProposerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ProposerMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::ProposerMismatch)
                    }
                    ProposerMismatch
                },
                {
                    fn L2_DEPRECATED_METHOD(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_DEPRECATED_METHOD as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_DEPRECATED_METHOD)
                    }
                    L2_DEPRECATED_METHOD
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(TaikoAnchorErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
                },
                {
                    fn InvalidAnchorBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidAnchorBlockNumber)
                    }
                    InvalidAnchorBlockNumber
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
            ) -> alloy_sol_types::Result<TaikoAnchorErrors>] = &[
                {
                    fn InvalidForkHeight(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidForkHeight as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidForkHeight)
                    }
                    InvalidForkHeight
                },
                {
                    fn L2_FORK_ERROR(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_FORK_ERROR as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_FORK_ERROR)
                    }
                    L2_FORK_ERROR
                },
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn NonZeroAnchorStateRoot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroAnchorStateRoot)
                    }
                    NonZeroAnchorStateRoot
                },
                {
                    fn ProposalIdMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ProposalIdMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ProposalIdMismatch)
                    }
                    ProposalIdMismatch
                },
                {
                    fn L2_INVALID_L1_CHAIN_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_L1_CHAIN_ID as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_L1_CHAIN_ID)
                    }
                    L2_INVALID_L1_CHAIN_ID
                },
                {
                    fn NonZeroBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroBlockIndex)
                    }
                    NonZeroBlockIndex
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn InvalidBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidBlockIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidBlockIndex)
                    }
                    InvalidBlockIndex
                },
                {
                    fn BlockHashAlreadySet(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <BlockHashAlreadySet as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::BlockHashAlreadySet)
                    }
                    BlockHashAlreadySet
                },
                {
                    fn L2_INVALID_SENDER(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_SENDER as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_SENDER)
                    }
                    L2_INVALID_SENDER
                },
                {
                    fn L2_BASEFEE_MISMATCH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_BASEFEE_MISMATCH as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_BASEFEE_MISMATCH)
                    }
                    L2_BASEFEE_MISMATCH
                },
                {
                    fn BondInstructionsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::BondInstructionsHashMismatch)
                    }
                    BondInstructionsHashMismatch
                },
                {
                    fn L2_INVALID_L2_CHAIN_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_INVALID_L2_CHAIN_ID as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_INVALID_L2_CHAIN_ID)
                    }
                    L2_INVALID_L2_CHAIN_ID
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn ETH_TRANSFER_FAILED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ETH_TRANSFER_FAILED)
                    }
                    ETH_TRANSFER_FAILED
                },
                {
                    fn SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED)
                    }
                    SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED
                },
                {
                    fn NonZeroAnchorBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::NonZeroAnchorBlockHash)
                    }
                    NonZeroAnchorBlockHash
                },
                {
                    fn L2_TOO_LATE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_TOO_LATE as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_TOO_LATE)
                    }
                    L2_TOO_LATE
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn ZeroBlockCount(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZeroBlockCount as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ZeroBlockCount)
                    }
                    ZeroBlockCount
                },
                {
                    fn L2_PUBLIC_INPUT_HASH_MISMATCH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_PUBLIC_INPUT_HASH_MISMATCH as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_PUBLIC_INPUT_HASH_MISMATCH)
                    }
                    L2_PUBLIC_INPUT_HASH_MISMATCH
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn ProposerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ProposerMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ProposerMismatch)
                    }
                    ProposerMismatch
                },
                {
                    fn L2_DEPRECATED_METHOD(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <L2_DEPRECATED_METHOD as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::L2_DEPRECATED_METHOD)
                    }
                    L2_DEPRECATED_METHOD
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
                },
                {
                    fn InvalidAnchorBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<TaikoAnchorErrors> {
                        <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(TaikoAnchorErrors::InvalidAnchorBlockNumber)
                    }
                    InvalidAnchorBlockNumber
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
                Self::BlockHashAlreadySet(inner) => {
                    <BlockHashAlreadySet as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::BondInstructionsHashMismatch(inner) => {
                    <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ETH_TRANSFER_FAILED(inner) => {
                    <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::InvalidAnchorBlockNumber(inner) => {
                    <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidBlockIndex(inner) => {
                    <InvalidBlockIndex as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidForkHeight(inner) => {
                    <InvalidForkHeight as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_BASEFEE_MISMATCH(inner) => {
                    <L2_BASEFEE_MISMATCH as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_DEPRECATED_METHOD(inner) => {
                    <L2_DEPRECATED_METHOD as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_FORK_ERROR(inner) => {
                    <L2_FORK_ERROR as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::L2_INVALID_L1_CHAIN_ID(inner) => {
                    <L2_INVALID_L1_CHAIN_ID as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_INVALID_L2_CHAIN_ID(inner) => {
                    <L2_INVALID_L2_CHAIN_ID as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_INVALID_SENDER(inner) => {
                    <L2_INVALID_SENDER as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_PUBLIC_INPUT_HASH_MISMATCH(inner) => {
                    <L2_PUBLIC_INPUT_HASH_MISMATCH as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::L2_TOO_LATE(inner) => {
                    <L2_TOO_LATE as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::NonZeroAnchorBlockHash(inner) => {
                    <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::NonZeroAnchorStateRoot(inner) => {
                    <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::NonZeroBlockIndex(inner) => {
                    <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ProposalIdMismatch(inner) => {
                    <ProposalIdMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ProposerMismatch(inner) => {
                    <ProposerMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(inner) => {
                    <SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::ZERO_ADDRESS(inner) => {
                    <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::ZERO_VALUE(inner) => {
                    <ZERO_VALUE as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::ZeroBlockCount(inner) => {
                    <ZeroBlockCount as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
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
                Self::BlockHashAlreadySet(inner) => {
                    <BlockHashAlreadySet as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::BondInstructionsHashMismatch(inner) => {
                    <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ETH_TRANSFER_FAILED(inner) => {
                    <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::InvalidAnchorBlockNumber(inner) => {
                    <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidBlockIndex(inner) => {
                    <InvalidBlockIndex as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidForkHeight(inner) => {
                    <InvalidForkHeight as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_BASEFEE_MISMATCH(inner) => {
                    <L2_BASEFEE_MISMATCH as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_DEPRECATED_METHOD(inner) => {
                    <L2_DEPRECATED_METHOD as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_FORK_ERROR(inner) => {
                    <L2_FORK_ERROR as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_INVALID_L1_CHAIN_ID(inner) => {
                    <L2_INVALID_L1_CHAIN_ID as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_INVALID_L2_CHAIN_ID(inner) => {
                    <L2_INVALID_L2_CHAIN_ID as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_INVALID_SENDER(inner) => {
                    <L2_INVALID_SENDER as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_PUBLIC_INPUT_HASH_MISMATCH(inner) => {
                    <L2_PUBLIC_INPUT_HASH_MISMATCH as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::L2_TOO_LATE(inner) => {
                    <L2_TOO_LATE as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::NonZeroAnchorBlockHash(inner) => {
                    <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::NonZeroAnchorStateRoot(inner) => {
                    <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::NonZeroBlockIndex(inner) => {
                    <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ProposalIdMismatch(inner) => {
                    <ProposalIdMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::ProposerMismatch(inner) => {
                    <ProposerMismatch as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED(inner) => {
                    <SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::ZeroBlockCount(inner) => {
                    <ZeroBlockCount as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`TaikoAnchor`](self) events.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum TaikoAnchorEvents {
        #[allow(missing_docs)]
        AdminChanged(AdminChanged),
        #[allow(missing_docs)]
        Anchored(Anchored),
        #[allow(missing_docs)]
        BeaconUpgraded(BeaconUpgraded),
        #[allow(missing_docs)]
        EIP1559Update(EIP1559Update),
        #[allow(missing_docs)]
        Initialized(Initialized),
        #[allow(missing_docs)]
        OwnershipTransferStarted(OwnershipTransferStarted),
        #[allow(missing_docs)]
        OwnershipTransferred(OwnershipTransferred),
        #[allow(missing_docs)]
        Paused(Paused),
        #[allow(missing_docs)]
        Unpaused(Unpaused),
        #[allow(missing_docs)]
        Upgraded(Upgraded),
        #[allow(missing_docs)]
        Withdrawn(Withdrawn),
    }
    #[automatically_derived]
    impl TaikoAnchorEvents {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 32usize]] = &[
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
                65u8, 195u8, 244u8, 16u8, 245u8, 200u8, 172u8, 54u8, 187u8, 70u8, 177u8,
                220u8, 206u8, 240u8, 222u8, 15u8, 150u8, 64u8, 135u8, 201u8, 230u8,
                136u8, 121u8, 95u8, 160u8, 46u8, 207u8, 162u8, 194u8, 11u8, 63u8, 228u8,
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
                120u8, 26u8, 229u8, 194u8, 33u8, 88u8, 6u8, 21u8, 13u8, 92u8, 113u8,
                164u8, 237u8, 83u8, 54u8, 229u8, 220u8, 58u8, 211u8, 42u8, 239u8, 4u8,
                252u8, 15u8, 98u8, 106u8, 110u8, 224u8, 194u8, 248u8, 209u8, 200u8,
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
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ],
            [
                209u8, 193u8, 159u8, 188u8, 212u8, 85u8, 26u8, 94u8, 223u8, 182u8, 109u8,
                67u8, 210u8, 227u8, 55u8, 192u8, 72u8, 55u8, 175u8, 218u8, 52u8, 130u8,
                180u8, 43u8, 223u8, 86u8, 154u8, 143u8, 204u8, 218u8, 229u8, 251u8,
            ],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolEventInterface for TaikoAnchorEvents {
        const NAME: &'static str = "TaikoAnchorEvents";
        const COUNT: usize = 11usize;
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
                Some(<Anchored as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Anchored as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Anchored)
                }
                Some(<BeaconUpgraded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <BeaconUpgraded as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::BeaconUpgraded)
                }
                Some(<EIP1559Update as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <EIP1559Update as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::EIP1559Update)
                }
                Some(<Initialized as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Initialized as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::Initialized)
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
                Some(<Unpaused as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Unpaused as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Unpaused)
                }
                Some(<Upgraded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Upgraded as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Upgraded)
                }
                Some(<Withdrawn as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Withdrawn as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::Withdrawn)
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
    impl alloy_sol_types::private::IntoLogData for TaikoAnchorEvents {
        fn to_log_data(&self) -> alloy_sol_types::private::LogData {
            match self {
                Self::AdminChanged(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Anchored(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::BeaconUpgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::EIP1559Update(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Initialized(inner) => {
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
                Self::Unpaused(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Upgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Withdrawn(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
            }
        }
        fn into_log_data(self) -> alloy_sol_types::private::LogData {
            match self {
                Self::AdminChanged(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Anchored(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::BeaconUpgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::EIP1559Update(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Initialized(inner) => {
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
                Self::Unpaused(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Upgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Withdrawn(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
            }
        }
    }
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`TaikoAnchor`](self) contract instance.

See the [wrapper's documentation](`TaikoAnchorInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        provider: P,
    ) -> TaikoAnchorInstance<P, N> {
        TaikoAnchorInstance::<P, N>::new(address, provider)
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
        _livenessBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        _provabilityBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        _signalService: alloy::sol_types::private::Address,
        _pacayaForkHeight: u64,
        _shastaForkHeight: u64,
        _bondManager: alloy::sol_types::private::Address,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<TaikoAnchorInstance<P, N>>,
    > {
        TaikoAnchorInstance::<
            P,
            N,
        >::deploy(
            provider,
            _livenessBondGwei,
            _provabilityBondGwei,
            _signalService,
            _pacayaForkHeight,
            _shastaForkHeight,
            _bondManager,
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
        _livenessBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        _provabilityBondGwei: alloy::sol_types::private::primitives::aliases::U48,
        _signalService: alloy::sol_types::private::Address,
        _pacayaForkHeight: u64,
        _shastaForkHeight: u64,
        _bondManager: alloy::sol_types::private::Address,
    ) -> alloy_contract::RawCallBuilder<P, N> {
        TaikoAnchorInstance::<
            P,
            N,
        >::deploy_builder(
            provider,
            _livenessBondGwei,
            _provabilityBondGwei,
            _signalService,
            _pacayaForkHeight,
            _shastaForkHeight,
            _bondManager,
        )
    }
    /**A [`TaikoAnchor`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`TaikoAnchor`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct TaikoAnchorInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for TaikoAnchorInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("TaikoAnchorInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > TaikoAnchorInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`TaikoAnchor`](self) contract instance.

See the [wrapper's documentation](`TaikoAnchorInstance`) for more details.*/
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
            _livenessBondGwei: alloy::sol_types::private::primitives::aliases::U48,
            _provabilityBondGwei: alloy::sol_types::private::primitives::aliases::U48,
            _signalService: alloy::sol_types::private::Address,
            _pacayaForkHeight: u64,
            _shastaForkHeight: u64,
            _bondManager: alloy::sol_types::private::Address,
        ) -> alloy_contract::Result<TaikoAnchorInstance<P, N>> {
            let call_builder = Self::deploy_builder(
                provider,
                _livenessBondGwei,
                _provabilityBondGwei,
                _signalService,
                _pacayaForkHeight,
                _shastaForkHeight,
                _bondManager,
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
            _livenessBondGwei: alloy::sol_types::private::primitives::aliases::U48,
            _provabilityBondGwei: alloy::sol_types::private::primitives::aliases::U48,
            _signalService: alloy::sol_types::private::Address,
            _pacayaForkHeight: u64,
            _shastaForkHeight: u64,
            _bondManager: alloy::sol_types::private::Address,
        ) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                provider,
                [
                    &BYTECODE[..],
                    &alloy_sol_types::SolConstructor::abi_encode(
                        &constructorCall {
                            _livenessBondGwei,
                            _provabilityBondGwei,
                            _signalService,
                            _pacayaForkHeight,
                            _shastaForkHeight,
                            _bondManager,
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
    impl<P: ::core::clone::Clone, N> TaikoAnchorInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> TaikoAnchorInstance<P, N> {
            TaikoAnchorInstance {
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
    > TaikoAnchorInstance<P, N> {
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
        ///Creates a new call builder for the [`ANCHOR_GAS_LIMIT`] function.
        pub fn ANCHOR_GAS_LIMIT(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, ANCHOR_GAS_LIMITCall, N> {
            self.call_builder(&ANCHOR_GAS_LIMITCall)
        }
        ///Creates a new call builder for the [`BASEFEE_MIN_VALUE`] function.
        pub fn BASEFEE_MIN_VALUE(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, BASEFEE_MIN_VALUECall, N> {
            self.call_builder(&BASEFEE_MIN_VALUECall)
        }
        ///Creates a new call builder for the [`GOLDEN_TOUCH_ADDRESS`] function.
        pub fn GOLDEN_TOUCH_ADDRESS(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, GOLDEN_TOUCH_ADDRESSCall, N> {
            self.call_builder(&GOLDEN_TOUCH_ADDRESSCall)
        }
        ///Creates a new call builder for the [`acceptOwnership`] function.
        pub fn acceptOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, acceptOwnershipCall, N> {
            self.call_builder(&acceptOwnershipCall)
        }
        ///Creates a new call builder for the [`adjustExcess`] function.
        pub fn adjustExcess(
            &self,
            _currGasExcess: u64,
            _currGasTarget: u64,
            _newGasTarget: u64,
        ) -> alloy_contract::SolCallBuilder<&P, adjustExcessCall, N> {
            self.call_builder(
                &adjustExcessCall {
                    _currGasExcess,
                    _currGasTarget,
                    _newGasTarget,
                },
            )
        }
        ///Creates a new call builder for the [`anchor`] function.
        pub fn anchor(
            &self,
            _l1BlockHash: alloy::sol_types::private::FixedBytes<32>,
            _l1StateRoot: alloy::sol_types::private::FixedBytes<32>,
            _l1BlockId: u64,
            _parentGasUsed: u32,
        ) -> alloy_contract::SolCallBuilder<&P, anchorCall, N> {
            self.call_builder(
                &anchorCall {
                    _l1BlockHash,
                    _l1StateRoot,
                    _l1BlockId,
                    _parentGasUsed,
                },
            )
        }
        ///Creates a new call builder for the [`anchorV2`] function.
        pub fn anchorV2(
            &self,
            _anchorBlockId: u64,
            _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
            _parentGasUsed: u32,
            _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, anchorV2Call, N> {
            self.call_builder(
                &anchorV2Call {
                    _anchorBlockId,
                    _anchorStateRoot,
                    _parentGasUsed,
                    _baseFeeConfig,
                },
            )
        }
        ///Creates a new call builder for the [`anchorV3`] function.
        pub fn anchorV3(
            &self,
            _anchorBlockId: u64,
            _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
            _parentGasUsed: u32,
            _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
            _signalSlots: alloy::sol_types::private::Vec<
                alloy::sol_types::private::FixedBytes<32>,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, anchorV3Call, N> {
            self.call_builder(
                &anchorV3Call {
                    _anchorBlockId,
                    _anchorStateRoot,
                    _parentGasUsed,
                    _baseFeeConfig,
                    _signalSlots,
                },
            )
        }
        ///Creates a new call builder for the [`blockIdToEndOfSubmissionWindowTimeStamp`] function.
        pub fn blockIdToEndOfSubmissionWindowTimeStamp(
            &self,
            blockId: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<
            &P,
            blockIdToEndOfSubmissionWindowTimeStampCall,
            N,
        > {
            self.call_builder(
                &blockIdToEndOfSubmissionWindowTimeStampCall {
                    blockId,
                },
            )
        }
        ///Creates a new call builder for the [`bondManager`] function.
        pub fn bondManager(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, bondManagerCall, N> {
            self.call_builder(&bondManagerCall)
        }
        ///Creates a new call builder for the [`calculateBaseFee`] function.
        pub fn calculateBaseFee(
            &self,
            _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
            _blocktime: u64,
            _parentGasExcess: u64,
            _parentGasUsed: u32,
        ) -> alloy_contract::SolCallBuilder<&P, calculateBaseFeeCall, N> {
            self.call_builder(
                &calculateBaseFeeCall {
                    _baseFeeConfig,
                    _blocktime,
                    _parentGasExcess,
                    _parentGasUsed,
                },
            )
        }
        ///Creates a new call builder for the [`getBasefee`] function.
        pub fn getBasefee(
            &self,
            _anchorBlockId: u64,
            _parentGasUsed: u32,
        ) -> alloy_contract::SolCallBuilder<&P, getBasefeeCall, N> {
            self.call_builder(
                &getBasefeeCall {
                    _anchorBlockId,
                    _parentGasUsed,
                },
            )
        }
        ///Creates a new call builder for the [`getBasefeeV2`] function.
        pub fn getBasefeeV2(
            &self,
            _parentGasUsed: u32,
            _blockTimestamp: u64,
            _baseFeeConfig: <OntakeAnchor::BaseFeeConfig as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, getBasefeeV2Call, N> {
            self.call_builder(
                &getBasefeeV2Call {
                    _parentGasUsed,
                    _blockTimestamp,
                    _baseFeeConfig,
                },
            )
        }
        ///Creates a new call builder for the [`getBlockHash`] function.
        pub fn getBlockHash(
            &self,
            _blockId: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, getBlockHashCall, N> {
            self.call_builder(&getBlockHashCall { _blockId })
        }
        ///Creates a new call builder for the [`getDesignatedProver`] function.
        pub fn getDesignatedProver(
            &self,
            _proposalId: alloy::sol_types::private::primitives::aliases::U48,
            _proposer: alloy::sol_types::private::Address,
            _proverAuth: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, getDesignatedProverCall, N> {
            self.call_builder(
                &getDesignatedProverCall {
                    _proposalId,
                    _proposer,
                    _proverAuth,
                },
            )
        }
        ///Creates a new call builder for the [`getState`] function.
        pub fn getState(&self) -> alloy_contract::SolCallBuilder<&P, getStateCall, N> {
            self.call_builder(&getStateCall)
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
        ///Creates a new call builder for the [`init`] function.
        pub fn init(
            &self,
            _owner: alloy::sol_types::private::Address,
            _l1ChainId: u64,
            _initialGasExcess: u64,
        ) -> alloy_contract::SolCallBuilder<&P, initCall, N> {
            self.call_builder(
                &initCall {
                    _owner,
                    _l1ChainId,
                    _initialGasExcess,
                },
            )
        }
        ///Creates a new call builder for the [`l1ChainId`] function.
        pub fn l1ChainId(&self) -> alloy_contract::SolCallBuilder<&P, l1ChainIdCall, N> {
            self.call_builder(&l1ChainIdCall)
        }
        ///Creates a new call builder for the [`lastAnchorGasUsed`] function.
        pub fn lastAnchorGasUsed(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, lastAnchorGasUsedCall, N> {
            self.call_builder(&lastAnchorGasUsedCall)
        }
        ///Creates a new call builder for the [`lastCheckpoint`] function.
        pub fn lastCheckpoint(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, lastCheckpointCall, N> {
            self.call_builder(&lastCheckpointCall)
        }
        ///Creates a new call builder for the [`livenessBondGwei`] function.
        pub fn livenessBondGwei(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, livenessBondGweiCall, N> {
            self.call_builder(&livenessBondGweiCall)
        }
        ///Creates a new call builder for the [`owner`] function.
        pub fn owner(&self) -> alloy_contract::SolCallBuilder<&P, ownerCall, N> {
            self.call_builder(&ownerCall)
        }
        ///Creates a new call builder for the [`pacayaForkHeight`] function.
        pub fn pacayaForkHeight(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, pacayaForkHeightCall, N> {
            self.call_builder(&pacayaForkHeightCall)
        }
        ///Creates a new call builder for the [`parentGasExcess`] function.
        pub fn parentGasExcess(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, parentGasExcessCall, N> {
            self.call_builder(&parentGasExcessCall)
        }
        ///Creates a new call builder for the [`parentGasTarget`] function.
        pub fn parentGasTarget(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, parentGasTargetCall, N> {
            self.call_builder(&parentGasTargetCall)
        }
        ///Creates a new call builder for the [`parentTimestamp`] function.
        pub fn parentTimestamp(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, parentTimestampCall, N> {
            self.call_builder(&parentTimestampCall)
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
        ///Creates a new call builder for the [`provabilityBondGwei`] function.
        pub fn provabilityBondGwei(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, provabilityBondGweiCall, N> {
            self.call_builder(&provabilityBondGweiCall)
        }
        ///Creates a new call builder for the [`proxiableUUID`] function.
        pub fn proxiableUUID(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, proxiableUUIDCall, N> {
            self.call_builder(&proxiableUUIDCall)
        }
        ///Creates a new call builder for the [`publicInputHash`] function.
        pub fn publicInputHash(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, publicInputHashCall, N> {
            self.call_builder(&publicInputHashCall)
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
        ///Creates a new call builder for the [`shastaForkHeight`] function.
        pub fn shastaForkHeight(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, shastaForkHeightCall, N> {
            self.call_builder(&shastaForkHeightCall)
        }
        ///Creates a new call builder for the [`signalService`] function.
        pub fn signalService(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, signalServiceCall, N> {
            self.call_builder(&signalServiceCall)
        }
        ///Creates a new call builder for the [`skipFeeCheck`] function.
        pub fn skipFeeCheck(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, skipFeeCheckCall, N> {
            self.call_builder(&skipFeeCheckCall)
        }
        ///Creates a new call builder for the [`transferOwnership`] function.
        pub fn transferOwnership(
            &self,
            newOwner: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, transferOwnershipCall, N> {
            self.call_builder(&transferOwnershipCall { newOwner })
        }
        ///Creates a new call builder for the [`unpause`] function.
        pub fn unpause(&self) -> alloy_contract::SolCallBuilder<&P, unpauseCall, N> {
            self.call_builder(&unpauseCall)
        }
        ///Creates a new call builder for the [`updateState`] function.
        pub fn updateState(
            &self,
            _proposalId: alloy::sol_types::private::primitives::aliases::U48,
            _proposer: alloy::sol_types::private::Address,
            _proverAuth: alloy::sol_types::private::Bytes,
            _bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
            _bondInstructions: alloy::sol_types::private::Vec<
                <LibBonds::BondInstruction as alloy::sol_types::SolType>::RustType,
            >,
            _blockIndex: u16,
            _anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
            _anchorBlockHash: alloy::sol_types::private::FixedBytes<32>,
            _anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
            _endOfSubmissionWindowTimestamp: alloy::sol_types::private::primitives::aliases::U48,
        ) -> alloy_contract::SolCallBuilder<&P, updateStateCall, N> {
            self.call_builder(
                &updateStateCall {
                    _proposalId,
                    _proposer,
                    _proverAuth,
                    _bondInstructionsHash,
                    _bondInstructions,
                    _blockIndex,
                    _anchorBlockNumber,
                    _anchorBlockHash,
                    _anchorStateRoot,
                    _endOfSubmissionWindowTimestamp,
                },
            )
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
        ///Creates a new call builder for the [`withdraw`] function.
        pub fn withdraw(
            &self,
            _token: alloy::sol_types::private::Address,
            _to: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, withdrawCall, N> {
            self.call_builder(&withdrawCall { _token, _to })
        }
    }
    /// Event filters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > TaikoAnchorInstance<P, N> {
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
        ///Creates a new event filter for the [`Anchored`] event.
        pub fn Anchored_filter(&self) -> alloy_contract::Event<&P, Anchored, N> {
            self.event_filter::<Anchored>()
        }
        ///Creates a new event filter for the [`BeaconUpgraded`] event.
        pub fn BeaconUpgraded_filter(
            &self,
        ) -> alloy_contract::Event<&P, BeaconUpgraded, N> {
            self.event_filter::<BeaconUpgraded>()
        }
        ///Creates a new event filter for the [`EIP1559Update`] event.
        pub fn EIP1559Update_filter(
            &self,
        ) -> alloy_contract::Event<&P, EIP1559Update, N> {
            self.event_filter::<EIP1559Update>()
        }
        ///Creates a new event filter for the [`Initialized`] event.
        pub fn Initialized_filter(&self) -> alloy_contract::Event<&P, Initialized, N> {
            self.event_filter::<Initialized>()
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
        ///Creates a new event filter for the [`Unpaused`] event.
        pub fn Unpaused_filter(&self) -> alloy_contract::Event<&P, Unpaused, N> {
            self.event_filter::<Unpaused>()
        }
        ///Creates a new event filter for the [`Upgraded`] event.
        pub fn Upgraded_filter(&self) -> alloy_contract::Event<&P, Upgraded, N> {
            self.event_filter::<Upgraded>()
        }
        ///Creates a new event filter for the [`Withdrawn`] event.
        pub fn Withdrawn_filter(&self) -> alloy_contract::Event<&P, Withdrawn, N> {
            self.event_filter::<Withdrawn>()
        }
    }
}
