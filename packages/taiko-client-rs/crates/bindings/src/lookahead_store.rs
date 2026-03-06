///Module containing a contract's types and functions.
/**

```solidity
library ILookaheadStore {
    struct BlacklistConfig { uint256 blacklistDelay; uint256 unblacklistDelay; }
    struct BlacklistTimestamps { uint48 blacklistedAt; uint48 unBlacklistedAt; }
    struct LookaheadData { uint256 slotIndex; bytes currLookahead; bytes nextLookahead; bytes commitmentSignature; }
    struct LookaheadSlot { address committer; uint48 timestamp; uint16 validatorLeafIndex; bytes32 registrationRoot; }
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct LookaheadData { uint256 slotIndex; bytes currLookahead; bytes nextLookahead; bytes commitmentSignature; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadData {
        #[allow(missing_docs)]
        pub slotIndex: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub currLookahead: alloy::sol_types::private::Bytes,
        #[allow(missing_docs)]
        pub nextLookahead: alloy::sol_types::private::Bytes,
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
        #[allow(dead_code)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::Bytes,
            alloy::sol_types::sol_data::Bytes,
            alloy::sol_types::sol_data::Bytes,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U256,
            alloy::sol_types::private::Bytes,
            alloy::sol_types::private::Bytes,
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
                    currLookahead: tuple.1,
                    nextLookahead: tuple.2,
                    commitmentSignature: tuple.3,
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
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.currLookahead,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.nextLookahead,
                    ),
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
                    "LookaheadData(uint256 slotIndex,bytes currLookahead,bytes nextLookahead,bytes commitmentSignature)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.slotIndex)
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.currLookahead,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.nextLookahead,
                        )
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
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.currLookahead,
                    )
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
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
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.currLookahead,
                    out,
                );
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
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
struct LookaheadSlot { address committer; uint48 timestamp; uint16 validatorLeafIndex; bytes32 registrationRoot; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LookaheadSlot {
        #[allow(missing_docs)]
        pub committer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub timestamp: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub validatorLeafIndex: u16,
        #[allow(missing_docs)]
        pub registrationRoot: alloy::sol_types::private::FixedBytes<32>,
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
        #[allow(dead_code)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<16>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::Address,
            alloy::sol_types::private::primitives::aliases::U48,
            u16,
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
        impl ::core::convert::From<LookaheadSlot> for UnderlyingRustTuple<'_> {
            fn from(value: LookaheadSlot) -> Self {
                (
                    value.committer,
                    value.timestamp,
                    value.validatorLeafIndex,
                    value.registrationRoot,
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
                    validatorLeafIndex: tuple.2,
                    registrationRoot: tuple.3,
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
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.timestamp),
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self.validatorLeafIndex),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.registrationRoot),
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
                    "LookaheadSlot(address committer,uint48 timestamp,uint16 validatorLeafIndex,bytes32 registrationRoot)",
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
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.timestamp)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.validatorLeafIndex,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.registrationRoot,
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
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.timestamp,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.validatorLeafIndex,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.registrationRoot,
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
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.timestamp,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    16,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.validatorLeafIndex,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.registrationRoot,
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
        #[allow(dead_code)]
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
        __provider: P,
    ) -> ILookaheadStoreInstance<P, N> {
        ILookaheadStoreInstance::<P, N>::new(address, __provider)
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
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ILookaheadStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ILookaheadStore`](self) contract instance.

See the [wrapper's documentation](`ILookaheadStoreInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            __provider: P,
        ) -> Self {
            Self {
                address,
                provider: __provider,
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
///Module containing a contract's types and functions.
/**

```solidity
library ISlasher {
    struct Commitment { uint64 commitmentType; bytes payload; address slasher; }
}
```*/
#[allow(
    non_camel_case_types,
    non_snake_case,
    clippy::pub_underscore_fields,
    clippy::style,
    clippy::empty_structs_with_brackets
)]
pub mod ISlasher {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct Commitment { uint64 commitmentType; bytes payload; address slasher; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Commitment {
        #[allow(missing_docs)]
        pub commitmentType: u64,
        #[allow(missing_docs)]
        pub payload: alloy::sol_types::private::Bytes,
        #[allow(missing_docs)]
        pub slasher: alloy::sol_types::private::Address,
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
        #[allow(dead_code)]
        type UnderlyingSolTuple<'a> = (
            alloy::sol_types::sol_data::Uint<64>,
            alloy::sol_types::sol_data::Bytes,
            alloy::sol_types::sol_data::Address,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            u64,
            alloy::sol_types::private::Bytes,
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
        impl ::core::convert::From<Commitment> for UnderlyingRustTuple<'_> {
            fn from(value: Commitment) -> Self {
                (value.commitmentType, value.payload, value.slasher)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Commitment {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    commitmentType: tuple.0,
                    payload: tuple.1,
                    slasher: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for Commitment {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for Commitment {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self.commitmentType),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.payload,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.slasher,
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
        impl alloy_sol_types::SolType for Commitment {
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
        impl alloy_sol_types::SolStruct for Commitment {
            const NAME: &'static str = "Commitment";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "Commitment(uint64 commitmentType,bytes payload,address slasher)",
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
                        64,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.commitmentType,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.payload,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.slasher,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for Commitment {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.commitmentType,
                    )
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.payload,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.slasher,
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
                    64,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.commitmentType,
                    out,
                );
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.payload,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.slasher,
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
    /**Creates a new wrapper around an on-chain [`ISlasher`](self) contract instance.

See the [wrapper's documentation](`ISlasherInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        __provider: P,
    ) -> ISlasherInstance<P, N> {
        ISlasherInstance::<P, N>::new(address, __provider)
    }
    /**A [`ISlasher`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`ISlasher`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct ISlasherInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for ISlasherInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("ISlasherInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ISlasherInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ISlasher`](self) contract instance.

See the [wrapper's documentation](`ISlasherInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            __provider: P,
        ) -> Self {
            Self {
                address,
                provider: __provider,
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
    impl<P: ::core::clone::Clone, N> ISlasherInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> ISlasherInstance<P, N> {
            ISlasherInstance {
                address: self.address,
                provider: ::core::clone::Clone::clone(&self.provider),
                _network: ::core::marker::PhantomData,
            }
        }
    }
    /// Function calls.
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ISlasherInstance<P, N> {
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
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ISlasherInstance<P, N> {
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
library ILookaheadStore {
    struct BlacklistConfig {
        uint256 blacklistDelay;
        uint256 unblacklistDelay;
    }
    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }
    struct LookaheadData {
        uint256 slotIndex;
        bytes currLookahead;
        bytes nextLookahead;
        bytes commitmentSignature;
    }
    struct LookaheadSlot {
        address committer;
        uint48 timestamp;
        uint16 validatorLeafIndex;
        bytes32 registrationRoot;
    }
    struct ProposerContext {
        bool isFallback;
        address proposer;
        uint256 submissionWindowStart;
        uint256 submissionWindowEnd;
        LookaheadSlot lookaheadSlot;
    }
}

library ISlasher {
    struct Commitment {
        uint64 commitmentType;
        bytes payload;
        address slasher;
    }
}

interface LookaheadStore {
    error ACCESS_DENIED();
    error BlacklistDelayNotMet();
    error CommitmentSignerMismatch();
    error FUNC_NOT_IMPLEMENTED();
    error INVALID_PAUSE_STATUS();
    error InvalidLookahead();
    error InvalidLookaheadEpoch();
    error InvalidLookaheadTimestamp();
    error InvalidProposer();
    error InvalidSlotIndex();
    error InvalidSlotTimestamp();
    error NotInbox();
    error NotOverseer();
    error OperatorAlreadyBlacklisted();
    error OperatorNotBlacklisted();
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
    event LookaheadPosted(uint256 indexed epochTimestamp, bytes26 lookaheadHash);
    event OverseerSet(address indexed oldOverseer, address indexed newOverseer);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    constructor(address _inbox, address _preconfSlasherL1, address _preconfWhitelist, address _urc);

    function LOOKAHEAD_BUFFER_SIZE() external view returns (uint256);
    function acceptOwnership() external;
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external;
    function buildLookaheadCommitment(uint256 _epochTimestamp, bytes memory _encodedLookahead) external view returns (ISlasher.Commitment memory);
    function calculateLookaheadHash(uint256 _epochTimestamp, bytes memory _encodedLookahead) external pure returns (bytes26);
    function checkProposer(address _proposer, bytes memory _lookaheadData) external returns (uint48);
    function encodeLookahead(ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots) external pure returns (bytes memory);
    function getBlacklist(bytes32 _operatorRegistrationRoot) external view returns (ILookaheadStore.BlacklistTimestamps memory);
    function getBlacklistConfig() external pure returns (ILookaheadStore.BlacklistConfig memory);
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26 hash_);
    function getProposerContext(uint256 _epochTimestamp, ILookaheadStore.LookaheadData memory _data) external view returns (ILookaheadStore.ProposerContext memory context_);
    function impl() external view returns (address);
    function inNonReentrant() external view returns (bool);
    function inbox() external view returns (address);
    function init(address _owner, address _overseer) external;
    function isLookaheadRequired() external view returns (bool);
    function isOperatorActive(bytes32 _registrationRoot, uint256 _referenceTimestamp) external view returns (bool);
    function isOperatorBlacklisted(bytes32 _operatorRegistrationRoot) external view returns (bool);
    function lookahead(uint256 epochTimestamp_mod_lookaheadBufferSize) external view returns (uint48 epochTimestamp, bytes26 lookaheadHash);
    function overseer() external view returns (address);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function preconfSlasherL1() external view returns (address);
    function preconfWhitelist() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function resolver() external view returns (address);
    function setOverseer(address _newOverseer) external;
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
        "name": "_inbox",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_preconfSlasherL1",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_preconfWhitelist",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_urc",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "LOOKAHEAD_BUFFER_SIZE",
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
    "name": "acceptOwnership",
    "inputs": [],
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
    "name": "buildLookaheadCommitment",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_encodedLookahead",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ISlasher.Commitment",
        "components": [
          {
            "name": "commitmentType",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "payload",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "slasher",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "stateMutability": "view"
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
        "name": "_encodedLookahead",
        "type": "bytes",
        "internalType": "bytes"
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
    "name": "encodeLookahead",
    "inputs": [
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
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "validatorLeafIndex",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "registrationRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getBlacklist",
    "inputs": [
      {
        "name": "_operatorRegistrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ILookaheadStore.BlacklistTimestamps",
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
        "internalType": "struct ILookaheadStore.BlacklistConfig",
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
    "name": "getProposerContext",
    "inputs": [
      {
        "name": "_epochTimestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
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
            "name": "currLookahead",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "nextLookahead",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "commitmentSignature",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
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
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "validatorLeafIndex",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "registrationRoot",
                "type": "bytes32",
                "internalType": "bytes32"
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
      },
      {
        "name": "_overseer",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "isOperatorActive",
    "inputs": [
      {
        "name": "_registrationRoot",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_referenceTimestamp",
        "type": "uint256",
        "internalType": "uint256"
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
    "name": "isOperatorBlacklisted",
    "inputs": [
      {
        "name": "_operatorRegistrationRoot",
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
    "name": "overseer",
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
    "name": "preconfSlasherL1",
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
    "name": "setOverseer",
    "inputs": [
      {
        "name": "_newOverseer",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
        "internalType": "address"
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
        "type": "bytes26",
        "indexed": false,
        "internalType": "bytes26"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OverseerSet",
    "inputs": [
      {
        "name": "oldOverseer",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOverseer",
        "type": "address",
        "indexed": true,
        "internalType": "address"
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
    "name": "OperatorNotBlacklisted",
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
    ///0x61014060405230608052348015610014575f5ffd5b5060405161332d38038061332d83398101604081905261003391610136565b61003b61005f565b6001600160a01b0393841660c05291831660e0528216610100521661012052610187565b5f54610100900460ff16156100ca5760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b5f5460ff90811614610119575f805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b80516001600160a01b0381168114610131575f5ffd5b919050565b5f5f5f5f60808587031215610149575f5ffd5b6101528561011b565b93506101606020860161011b565b925061016e6040860161011b565b915061017c6060860161011b565b905092959194509250565b60805160a05160c05160e051610100516101205161311261021b5f395f818161044b01528181610c4a0152610d6501525f818161070d015281816116e201526117a701525f818161028801528181610d3b015261146201525f81816107e601526110d101525f61021901525f8181610a4e01528181610a9701528181610b7901528181610bb90152610f1f01526131125ff3fe608060405260043610610207575f3560e01c80638da5cb5b11610113578063cc8099901161009d578063e30c39781161006d578063e30c39781461077a578063f09a401614610797578063f2fde38b146107b6578063fb0e722b146107d5578063fd40a5fe14610808575f5ffd5b8063cc809990146106dd578063d91f24f1146106fc578063dfbb74071461072f578063e2828f471461075b575f5ffd5b8063a486e0dd116100e3578063a486e0dd146105c0578063a6e0427414610625578063ac0004da1461065c578063ae41501a14610692578063c86dc3fd146106b1575f5ffd5b80638da5cb5b146104bd578063937aaa9b146104da5780639fe786ab14610520578063a2bf9dba146105ab575f5ffd5b80634f1ef286116101945780635ddc9e8d116101645780635ddc9e8d1461043a578063715018a61461046d57806379ba5097146104815780638456cb59146104955780638abf6077146104a9575f5ffd5b80634f1ef286146103c6578063513ae999146103d957806352d1902d146103f85780635c975abb1461041a575f5ffd5b806323c0b1ab116101da57806323c0b1ab1461033b5780633075db561461035f5780633659cfe6146103735780633f4ba83a146103925780634ba25656146103a6575f5ffd5b806304f3bcec1461020b57806306418f05146102565780630d9cead7146102775780631d3f2b5e146102aa575b5f5ffd5b348015610216575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b348015610261575f5ffd5b506102756102703660046128dd565b61085e565b005b348015610282575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b3480156102b5575f5ffd5b506102c96102c43660046128f4565b6109a0565b604080518251151581526020808401516001600160a01b03908116828401528484015183850152606080860151818501526080958601518051909216958401959095529081015165ffffffffffff1660a08301529182015161ffff1660c082015291015160e08201526101000161024d565b348015610346575f5ffd5b5061034f6109d4565b604051901515815260200161024d565b34801561036a575f5ffd5b5061034f610a2c565b34801561037e575f5ffd5b5061027561038d366004612951565b610a44565b34801561039d575f5ffd5b50610275610b14565b3480156103b1575f5ffd5b5061012d54610239906001600160a01b031681565b6102756103d43660046129fb565b610b6f565b3480156103e4575f5ffd5b5061034f6103f3366004612aa0565b610c28565b348015610403575f5ffd5b5061040c610f13565b60405190815260200161024d565b348015610425575f5ffd5b5061034f60c954610100900460ff1660021490565b348015610445575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b348015610478575f5ffd5b50610275610fc4565b34801561048c575f5ffd5b50610275610fd5565b3480156104a0575f5ffd5b5061027561104c565b3480156104b4575f5ffd5b506102396110a1565b3480156104c8575f5ffd5b506033546001600160a01b0316610239565b3480156104e5575f5ffd5b506040805180820182525f8082526020918201528151808301835262015180808252908201818152835191825251918101919091520161024d565b34801561052b575f5ffd5b5061058561053a3660046128dd565b604080518082019091525f8082526020820152505f90815261012e602090815260409182902082518084019093525465ffffffffffff8082168452600160301b909104169082015290565b60408051825165ffffffffffff908116825260209384015116928101929092520161024d565b3480156105b6575f5ffd5b5061040c6101f781565b3480156105cb575f5ffd5b506105ff6105da3660046128dd565b60fb6020525f908152604090205465ffffffffffff811690600160301b900460301b82565b6040805165ffffffffffff909316835265ffffffffffff1990911660208301520161024d565b348015610630575f5ffd5b5061064461063f366004612afd565b6110af565b60405165ffffffffffff19909116815260200161024d565b348015610667575f5ffd5b5061067b610676366004612b44565b6110c5565b60405165ffffffffffff909116815260200161024d565b34801561069d575f5ffd5b506106446106ac3660046128dd565b6111e9565b3480156106bc575f5ffd5b506106d06106cb366004612b7b565b61123d565b60405161024d9190612c18565b3480156106e8575f5ffd5b506102756106f73660046128dd565b611299565b348015610707575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b34801561073a575f5ffd5b5061074e610749366004612afd565b6113de565b60405161024d9190612c2a565b348015610766575f5ffd5b50610275610775366004612951565b611496565b348015610785575f5ffd5b506065546001600160a01b0316610239565b3480156107a2575f5ffd5b506102756107b1366004612c79565b6114f0565b3480156107c1575f5ffd5b506102756107d0366004612951565b61161a565b3480156107e0575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b348015610813575f5ffd5b5061034f6108223660046128dd565b5f90815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b61012d546001600160a01b0316331461088a5760405163ac9d87cd60e01b815260040160405180910390fd5b5f81815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b9092041691830182905211156108e057604051631996476b60e01b815260040160405180910390fd5b6040805180820182525f8082526020918201528151808301909252620151808083529082015251602082015161091e919065ffffffffffff16612cb9565b421161093d5760405163a282931f60e01b815260040160405180910390fd5b5f82815261012e6020908152604091829020805465ffffffffffff19164265ffffffffffff16908117909155915191825283917f1a878b2bf8680c02f7d79c199a61adbe8744e8ccb0f17e36229b619331fa2e1391015b60405180910390a25050565b6109a8612881565b5f6109b5600c6020612ccc565b6109bf9085612cb9565b90506109cc83858361168b565b949350505050565b5f5f6109df5f61185c565b65ffffffffffff1690508042036109f7575f91505090565b5f610a04600c6020612ccc565b610a0e9083612cb9565b905080610a1a826118e0565b5465ffffffffffff1614159392505050565b5f6002610a3b60c95460ff1690565b60ff1614905090565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610a955760405162461bcd60e51b8152600401610a8c90612ce3565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610ac7611904565b6001600160a01b031614610aed5760405162461bcd60e51b8152600401610a8c90612d2f565b610af68161191f565b604080515f80825260208201909252610b1191839190611927565b50565b610b1c611a91565b610b3060c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610b6d335f611ac2565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610bb75760405162461bcd60e51b8152600401610a8c90612ce3565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610be9611904565b6001600160a01b031614610c0f5760405162461bcd60e51b8152600401610a8c90612d2f565b610c188261191f565b610c2482826001611927565b5050565b6040516324d9127b60e21b8152600481018390525f9081906001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169063936449ec9060240161010060405180830381865afa158015610c90573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610cb49190612de0565b9050806060015165ffffffffffff165f1480610cdb575082816060015165ffffffffffff16115b15610ce9575f915050610f0d565b608081015165ffffffffffff1615801590610d0f575082816080015165ffffffffffff16105b15610d1d575f915050610f0d565b604051632d0c58c960e11b8152600481018590526001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000811660248301525f917f000000000000000000000000000000000000000000000000000000000000000090911690635a18b19290604401608060405180830381865afa158015610dac573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610dd09190612e86565b9050806020015165ffffffffffff165f1480610df7575083816020015165ffffffffffff16115b15610e06575f92505050610f0d565b604081015165ffffffffffff1615801590610e2c575083816040015165ffffffffffff16105b15610e3b575f92505050610f0d565b5f85815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b909204169183019190915215801590610e895750805165ffffffffffff1685115b15610ecf57805f015165ffffffffffff16816020015165ffffffffffff161080610ebf575084816020015165ffffffffffff1610155b15610ecf575f9350505050610f0d565b60a083015165ffffffffffff1615801590610ef55750848360a0015165ffffffffffff16105b15610f05575f9350505050610f0d565b600193505050505b92915050565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610fb25760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a8c565b505f5160206130965f395f51905f5290565b610fcc611ac6565b610b6d5f611b20565b60655433906001600160a01b031681146110435760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a8c565b610b1181611b20565b611054611b39565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610b6d336001611ac2565b5f6110aa611904565b905090565b5f6110bb848484611b6b565b90505b9392505050565b5f336001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461110f576040516372109f7760e01b815260040160405180910390fd5b602083015f61111c611b89565b65ffffffffffff1690505f611133600c6020612ccc565b61113d9083612cb9565b90505f61114b84848461168b565b905080602001516001600160a01b0316886001600160a01b0316146111835760405163409b320f60e11b815260040160405180910390fd5b8060400151421015801561119b575080606001514211155b6111b8576040516345cb0af960e01b815260040160405180910390fd5b6111ce836111c96020870187612eeb565b611b93565b6111da83838387611be4565b60600151979650505050505050565b5f5f6111f4836118e0565b60408051808201909152905465ffffffffffff8116808352600160301b90910460301b65ffffffffffff1916602083015290915083900361123757806020015191505b50919050565b60606110be8383808060200260200160405190810160405280939291908181526020015f905b8282101561128f5761128060808302860136819003810190612f2d565b81526020019060010190611263565b5050505050611c43565b61012d546001600160a01b031633146112c55760405163ac9d87cd60e01b815260040160405180910390fd5b5f81815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b909204169183018290521161131a57604051630ec1127960e01b815260040160405180910390fd5b6040805180820182525f80825260209182015281518083019092526201518080835291018190528151611355919065ffffffffffff16612cb9565b4211611374576040516399d3faf960e01b815260040160405180910390fd5b5f82815261012e602090815260409182902080546bffffffffffff0000000000001916600160301b4265ffffffffffff1690810291909117909155915191825283917f9682ae3fb79c10948116fe2a224cca9025fb76716477d713dfec766d8bccee179101610994565b61141260405180606001604052805f6001600160401b03168152602001606081526020015f6001600160a01b031681525090565b60405180606001604052805f6001600160401b031681526020016114378686866110af565b6040805165ffffffffffff1990921660208301520160405160208183030381529060405281526020017f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031681525090509392505050565b61149e611ac6565b61012d80546001600160a01b038381166001600160a01b0319831681179093556040519116919082907ff5640ad8a74a6066c7f3bc15976d1d80bde51dbbc9d9cd875d9c6582b5a70e3d905f90a35050565b5f54610100900460ff161580801561150e57505f54600160ff909116105b806115275750303b15801561152757505f5460ff166001145b61158a5760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b6064820152608401610a8c565b5f805460ff1916600117905580156115ab575f805461ff0019166101001790555b6115b483611d6d565b61012d80546001600160a01b0319166001600160a01b0384161790558015611615575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b505050565b611622611ac6565b606580546001600160a01b0383166001600160a01b031990911681179091556116536033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b611693612881565b6116a06020850185612eeb565b90505f036116b9576116b28383611dcb565b90506116d9565b60018435016116cc576116b28483611df4565b6116d68484611ebe565b90505b805115611773577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663343f0a686040518163ffffffff1660e01b8152600401602060405180830381865afa15801561173c573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906117609190612f8d565b6001600160a01b031660208201526110be565b61178581608001516060015142610c28565b611841576001815260408051630687e14d60e31b815290516001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169163343f0a689160048083019260209291908290030181865afa1580156117f0573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906118149190612f8d565b6001600160a01b03166020820152600184350161183c57611836600c83612fa8565b60608201525b6110be565b6080810151516001600160a01b031660208201529392505050565b5f5f61186746611f87565b90505f6118748242612fa8565b90505f611883600c6020612ccc565b61188f600c6020612ccc565b6118999084612fcf565b6118a39190612ccc565b90506118d76118b4600c6020612ccc565b6118be9087612ccc565b6118c88386612cb9565b6118d29190612cb9565b611fe2565b95945050505050565b5f60fb816118f06101f785612fe2565b81526020019081526020015f209050919050565b5f5160206130965f395f51905f52546001600160a01b031690565b610b11611ac6565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff161561195a576116158361204c565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa9250505080156119b4575060408051601f3d908101601f191682019092526119b191810190612ff5565b60015b611a175760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a8c565b5f5160206130965f395f51905f528114611a855760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a8c565b506116158383836120e7565b611aa560c954610100900460ff1660021490565b610b6d5760405163bae6e2a960e01b815260040160405180910390fd5b610c245b6033546001600160a01b03163314610b6d5760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a8c565b606580546001600160a01b0319169055610b118161210b565b611b4d60c954610100900460ff1660021490565b15610b6d5760405163bae6e2a960e01b815260040160405180910390fd5b5f604051848152828460208301376020830181209150509392505050565b5f6110aa5f61185c565b5f611b9d846111e9565b905065ffffffffffff19811615611bbf57611bba8484848461215c565b611bde565b8115611bde5760405163eaf82a2560e01b815260040160405180910390fd5b50505050565b5f611bee846111e9565b905065ffffffffffff19811615611c2a5781355f1914611c0e5750611bde565b611c2584611c1f6040850185612eeb565b8461215c565b611c3c565b844214611c3c57611c3c848484612196565b5050505050565b6060603c8251611c539190612ccc565b6001600160401b03811115611c6a57611c6a61296c565b6040519080825280601f01601f191660200182016040528015611c94576020820181803683370190505b509050602081015f5b8351811015611d6657611cd282858381518110611cbc57611cbc61300c565b60200260200101515f015160601b815260140190565b9150611d0182858381518110611cea57611cea61300c565b60200260200101516020015160d01b815260060190565b9150611d3082858381518110611d1957611d1961300c565b60200260200101516040015160f01b815260020190565b9150611d5c82858381518110611d4857611d4861300c565b602002602001015160600151815260200190565b9150600101611c9d565b5050919050565b5f54610100900460ff16611d935760405162461bcd60e51b8152600401610a8c90613020565b611d9b6122a7565b611db96001600160a01b03821615611db35781611b20565b33611b20565b5060c9805461ff001916610100179055565b611dd3612881565b6001815260408101839052611de9600c83612fa8565b606082015292915050565b611dfc612881565b5f611e33611e0d6020860186612eeb565b6001611e24611e1f60208a018a612eeb565b6122cd565b611e2e9190612fa8565b6122d9565b9050600c816020015165ffffffffffff16611e4e9190612fa8565b604080840191909152611e6390850185612eeb565b90505f03611e845760018252611e7a600c84612fa8565b6060830152611eb7565b5f611e9b611e956040870187612eeb565b5f6122d9565b5f8452602081015165ffffffffffff1660608501526080840152505b5092915050565b611ec6612881565b5f611ede611ed76020860186612eeb565b86356122d9565b5f80845260808401829052602082015165ffffffffffff16606085015290915084359003611f125760408201839052611eb7565b611f22611e1f6020860186612eeb565b843510611f4257604051633628a81b60e01b815260040160405180910390fd5b5f611f5f611f536020870187612eeb565b611e2e60018935612fa8565b9050600c816020015165ffffffffffff16611f7a9190612fa8565b6040840152505092915050565b5f60018203611f9b5750635fc63057919050565b6142688203611faf57506365156ac0919050565b6401a2140cff8203611fc657506366755d6c919050565b62088bb08203611fdb57506367d81118919050565b505f919050565b5f65ffffffffffff8211156120485760405162461bcd60e51b815260206004820152602660248201527f53616665436173743a2076616c756520646f65736e27742066697420696e203460448201526538206269747360d01b6064820152608401610a8c565b5090565b6001600160a01b0381163b6120b95760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a8c565b5f5160206130965f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b6120f083612347565b5f825111806120fc5750805b1561161557611bde8383612386565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f6121688585856110af565b905065ffffffffffff1982811690821614611c3c5760405163eaf82a2560e01b815260040160405180910390fd5b6121a36060820182612eeb565b90505f036121cf5781516121ca5760405163047677f560e21b815260040160405180910390fd5b612291565b5f6121e1846107496040850185612eeb565b90505f612256826040516020016121f89190612c2a565b60408051601f19818403018152919052805160209091012061221d6060860186612eeb565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506123ab92505050565b905083602001516001600160a01b0316816001600160a01b03161461228e5760405163157df6a560e21b815260040160405180910390fd5b50505b611bde836122a26040840184612eeb565b6123cd565b5f54610100900460ff16610b6d5760405162461bcd60e51b8152600401610a8c90613020565b5f6110be603c83612fcf565b604080516080810182525f80825260208201819052918101829052606081019190915283612308603c84612ccc565b6123129082612cb9565b8035606090811c8452601482013560d01c6020850152601a82013560f01c6040850152601c9091013590830152509392505050565b6123508161204c565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b60606110be83836040518060600160405280602781526020016130b6602791396124fa565b5f5f5f6123b8858561256e565b915091506123c5816125b0565b509392505050565b5f600b198401816123de85856122cd565b90505f5b81811015612477575f6123f68787846122d9565b905083816020015165ffffffffffff161161242457604051635c03141b60e11b815260040160405180910390fd5b600c88826020015165ffffffffffff16038161244257612442612fbb565b06156124615760405163971cce8f60e01b815260040160405180910390fd5b6020015165ffffffffffff1692506001016123e2565b506101808601821061249c576040516396ace79b60e01b815260040160405180910390fd5b50506124a98484846110af565b90506124b584826126f9565b60405165ffffffffffff198216815284907ff4b55b856c583b952f0c0d42067c8e63c9fae395322905d45e55af1d0f0959949060200160405180910390a29392505050565b60605f5f856001600160a01b031685604051612516919061306b565b5f60405180830381855af49150503d805f811461254e576040519150601f19603f3d011682016040523d82523d5f602084013e612553565b606091505b509150915061256486838387612722565b9695505050505050565b5f5f82516041036125a2576020830151604084015160608501515f1a6125968782858561279a565b945094505050506125a9565b505f905060025b9250929050565b5f8160048111156125c3576125c3613081565b036125cb5750565b60018160048111156125df576125df613081565b0361262c5760405162461bcd60e51b815260206004820152601860248201527f45434453413a20696e76616c6964207369676e617475726500000000000000006044820152606401610a8c565b600281600481111561264057612640613081565b0361268d5760405162461bcd60e51b815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e677468006044820152606401610a8c565b60038160048111156126a1576126a1613081565b03610b115760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c604482015261756560f01b6064820152608401610a8c565b5f612703836118e0565b60309290921c600160301b0265ffffffffffff90931692909217905550565b606083156127905782515f03612789576001600160a01b0385163b6127895760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a8c565b50816109cc565b6109cc8383612857565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08311156127cf57505f9050600361284e565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612820573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612848575f6001925092505061284e565b91505f90505b94509492505050565b8151156128675781518083602001fd5b8060405162461bcd60e51b8152600401610a8c9190612c18565b6040518060a001604052805f151581526020015f6001600160a01b031681526020015f81526020015f81526020016128d8604080516080810182525f80825260208201819052918101829052606081019190915290565b905290565b5f602082840312156128ed575f5ffd5b5035919050565b5f5f60408385031215612905575f5ffd5b8235915060208301356001600160401b03811115612921575f5ffd5b830160808186031215612932575f5ffd5b809150509250929050565b6001600160a01b0381168114610b11575f5ffd5b5f60208284031215612961575f5ffd5b81356110be8161293d565b634e487b7160e01b5f52604160045260245ffd5b60405161010081016001600160401b03811182821017156129a3576129a361296c565b60405290565b604051608081016001600160401b03811182821017156129a3576129a361296c565b604051601f8201601f191681016001600160401b03811182821017156129f3576129f361296c565b604052919050565b5f5f60408385031215612a0c575f5ffd5b8235612a178161293d565b915060208301356001600160401b03811115612a31575f5ffd5b8301601f81018513612a41575f5ffd5b80356001600160401b03811115612a5a57612a5a61296c565b612a6d601f8201601f19166020016129cb565b818152866020838501011115612a81575f5ffd5b816020840160208301375f602083830101528093505050509250929050565b5f5f60408385031215612ab1575f5ffd5b50508035926020909101359150565b5f5f83601f840112612ad0575f5ffd5b5081356001600160401b03811115612ae6575f5ffd5b6020830191508360208285010111156125a9575f5ffd5b5f5f5f60408486031215612b0f575f5ffd5b8335925060208401356001600160401b03811115612b2b575f5ffd5b612b3786828701612ac0565b9497909650939450505050565b5f5f5f60408486031215612b56575f5ffd5b8335612b618161293d565b925060208401356001600160401b03811115612b2b575f5ffd5b5f5f60208385031215612b8c575f5ffd5b82356001600160401b03811115612ba1575f5ffd5b8301601f81018513612bb1575f5ffd5b80356001600160401b03811115612bc6575f5ffd5b8560208260071b8401011115612bda575f5ffd5b6020919091019590945092505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081525f6110be6020830184612bea565b602081526001600160401b0382511660208201525f602083015160606040840152612c586080840182612bea565b604094909401516001600160a01b0316606093909301929092525090919050565b5f5f60408385031215612c8a575f5ffd5b8235612c958161293d565b915060208301356129328161293d565b634e487b7160e01b5f52601160045260245ffd5b80820180821115610f0d57610f0d612ca5565b8082028115828204841417610f0d57610f0d612ca5565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b805169ffffffffffffffffffff81168114612d94575f5ffd5b919050565b61ffff81168114610b11575f5ffd5b8051612d9481612d99565b65ffffffffffff81168114610b11575f5ffd5b8051612d9481612db3565b80518015158114612d94575f5ffd5b5f610100828403128015612df2575f5ffd5b50612dfb612980565b8251612e068161293d565b8152612e1460208401612d7b565b6020820152612e2560408401612da8565b6040820152612e3660608401612dc6565b6060820152612e4760808401612dc6565b6080820152612e5860a08401612dc6565b60a0820152612e6960c08401612dd1565b60c0820152612e7a60e08401612dd1565b60e08201529392505050565b5f6080828403128015612e97575f5ffd5b50612ea06129a9565b8251612eab8161293d565b81526020830151612ebb81612db3565b60208201526040830151612ece81612db3565b6040820152612edf60608401612dd1565b60608201529392505050565b5f5f8335601e19843603018112612f00575f5ffd5b8301803591506001600160401b03821115612f19575f5ffd5b6020019150368190038213156125a9575f5ffd5b5f6080828403128015612f3e575f5ffd5b50612f476129a9565b8235612f528161293d565b81526020830135612f6281612db3565b60208201526040830135612f7581612d99565b60408201526060928301359281019290925250919050565b5f60208284031215612f9d575f5ffd5b81516110be8161293d565b81810381811115610f0d57610f0d612ca5565b634e487b7160e01b5f52601260045260245ffd5b5f82612fdd57612fdd612fbb565b500490565b5f82612ff057612ff0612fbb565b500690565b5f60208284031215613005575f5ffd5b5051919050565b634e487b7160e01b5f52603260045260245ffd5b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b5f82518060208501845e5f920191825250919050565b634e487b7160e01b5f52602160045260245ffdfe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220bc3208e89db479394361bf8fc047bb9b000f5551a5c6af87519ceeffcbd5e91364736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01@`@R0`\x80R4\x80\x15a\0\x14W__\xFD[P`@Qa3-8\x03\x80a3-\x839\x81\x01`@\x81\x90Ra\x003\x91a\x016V[a\0;a\0_V[`\x01`\x01`\xA0\x1B\x03\x93\x84\x16`\xC0R\x91\x83\x16`\xE0R\x82\x16a\x01\0R\x16a\x01 Ra\x01\x87V[_Ta\x01\0\x90\x04`\xFF\x16\x15a\0\xCAW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FInitializable: contract is initi`D\x82\x01Rfalizing`\xC8\x1B`d\x82\x01R`\x84\x01`@Q\x80\x91\x03\x90\xFD[_T`\xFF\x90\x81\x16\x14a\x01\x19W_\x80T`\xFF\x19\x16`\xFF\x90\x81\x17\x90\x91U`@Q\x90\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[V[\x80Q`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x011W__\xFD[\x91\x90PV[____`\x80\x85\x87\x03\x12\x15a\x01IW__\xFD[a\x01R\x85a\x01\x1BV[\x93Pa\x01`` \x86\x01a\x01\x1BV[\x92Pa\x01n`@\x86\x01a\x01\x1BV[\x91Pa\x01|``\x86\x01a\x01\x1BV[\x90P\x92\x95\x91\x94P\x92PV[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x01 Qa1\x12a\x02\x1B_9_\x81\x81a\x04K\x01R\x81\x81a\x0CJ\x01Ra\re\x01R_\x81\x81a\x07\r\x01R\x81\x81a\x16\xE2\x01Ra\x17\xA7\x01R_\x81\x81a\x02\x88\x01R\x81\x81a\r;\x01Ra\x14b\x01R_\x81\x81a\x07\xE6\x01Ra\x10\xD1\x01R_a\x02\x19\x01R_\x81\x81a\nN\x01R\x81\x81a\n\x97\x01R\x81\x81a\x0By\x01R\x81\x81a\x0B\xB9\x01Ra\x0F\x1F\x01Ra1\x12_\xF3\xFE`\x80`@R`\x046\x10a\x02\x07W_5`\xE0\x1C\x80c\x8D\xA5\xCB[\x11a\x01\x13W\x80c\xCC\x80\x99\x90\x11a\0\x9DW\x80c\xE3\x0C9x\x11a\0mW\x80c\xE3\x0C9x\x14a\x07zW\x80c\xF0\x9A@\x16\x14a\x07\x97W\x80c\xF2\xFD\xE3\x8B\x14a\x07\xB6W\x80c\xFB\x0Er+\x14a\x07\xD5W\x80c\xFD@\xA5\xFE\x14a\x08\x08W__\xFD[\x80c\xCC\x80\x99\x90\x14a\x06\xDDW\x80c\xD9\x1F$\xF1\x14a\x06\xFCW\x80c\xDF\xBBt\x07\x14a\x07/W\x80c\xE2\x82\x8FG\x14a\x07[W__\xFD[\x80c\xA4\x86\xE0\xDD\x11a\0\xE3W\x80c\xA4\x86\xE0\xDD\x14a\x05\xC0W\x80c\xA6\xE0Bt\x14a\x06%W\x80c\xAC\0\x04\xDA\x14a\x06\\W\x80c\xAEAP\x1A\x14a\x06\x92W\x80c\xC8m\xC3\xFD\x14a\x06\xB1W__\xFD[\x80c\x8D\xA5\xCB[\x14a\x04\xBDW\x80c\x93z\xAA\x9B\x14a\x04\xDAW\x80c\x9F\xE7\x86\xAB\x14a\x05 W\x80c\xA2\xBF\x9D\xBA\x14a\x05\xABW__\xFD[\x80cO\x1E\xF2\x86\x11a\x01\x94W\x80c]\xDC\x9E\x8D\x11a\x01dW\x80c]\xDC\x9E\x8D\x14a\x04:W\x80cqP\x18\xA6\x14a\x04mW\x80cy\xBAP\x97\x14a\x04\x81W\x80c\x84V\xCBY\x14a\x04\x95W\x80c\x8A\xBF`w\x14a\x04\xA9W__\xFD[\x80cO\x1E\xF2\x86\x14a\x03\xC6W\x80cQ:\xE9\x99\x14a\x03\xD9W\x80cR\xD1\x90-\x14a\x03\xF8W\x80c\\\x97Z\xBB\x14a\x04\x1AW__\xFD[\x80c#\xC0\xB1\xAB\x11a\x01\xDAW\x80c#\xC0\xB1\xAB\x14a\x03;W\x80c0u\xDBV\x14a\x03_W\x80c6Y\xCF\xE6\x14a\x03sW\x80c?K\xA8:\x14a\x03\x92W\x80cK\xA2VV\x14a\x03\xA6W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02\x0BW\x80c\x06A\x8F\x05\x14a\x02VW\x80c\r\x9C\xEA\xD7\x14a\x02wW\x80c\x1D?+^\x14a\x02\xAAW[__\xFD[4\x80\x15a\x02\x16W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02aW__\xFD[Pa\x02ua\x02p6`\x04a(\xDDV[a\x08^V[\0[4\x80\x15a\x02\x82W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x02\xB5W__\xFD[Pa\x02\xC9a\x02\xC46`\x04a(\xF4V[a\t\xA0V[`@\x80Q\x82Q\x15\x15\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x82\x84\x01R\x84\x84\x01Q\x83\x85\x01R``\x80\x86\x01Q\x81\x85\x01R`\x80\x95\x86\x01Q\x80Q\x90\x92\x16\x95\x84\x01\x95\x90\x95R\x90\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xA0\x83\x01R\x91\x82\x01Qa\xFF\xFF\x16`\xC0\x82\x01R\x91\x01Q`\xE0\x82\x01Ra\x01\0\x01a\x02MV[4\x80\x15a\x03FW__\xFD[Pa\x03Oa\t\xD4V[`@Q\x90\x15\x15\x81R` \x01a\x02MV[4\x80\x15a\x03jW__\xFD[Pa\x03Oa\n,V[4\x80\x15a\x03~W__\xFD[Pa\x02ua\x03\x8D6`\x04a)QV[a\nDV[4\x80\x15a\x03\x9DW__\xFD[Pa\x02ua\x0B\x14V[4\x80\x15a\x03\xB1W__\xFD[Pa\x01-Ta\x029\x90`\x01`\x01`\xA0\x1B\x03\x16\x81V[a\x02ua\x03\xD46`\x04a)\xFBV[a\x0BoV[4\x80\x15a\x03\xE4W__\xFD[Pa\x03Oa\x03\xF36`\x04a*\xA0V[a\x0C(V[4\x80\x15a\x04\x03W__\xFD[Pa\x04\x0Ca\x0F\x13V[`@Q\x90\x81R` \x01a\x02MV[4\x80\x15a\x04%W__\xFD[Pa\x03O`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04EW__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04xW__\xFD[Pa\x02ua\x0F\xC4V[4\x80\x15a\x04\x8CW__\xFD[Pa\x02ua\x0F\xD5V[4\x80\x15a\x04\xA0W__\xFD[Pa\x02ua\x10LV[4\x80\x15a\x04\xB4W__\xFD[Pa\x029a\x10\xA1V[4\x80\x15a\x04\xC8W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x029V[4\x80\x15a\x04\xE5W__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Rb\x01Q\x80\x80\x82R\x90\x82\x01\x81\x81R\x83Q\x91\x82RQ\x91\x81\x01\x91\x90\x91R\x01a\x02MV[4\x80\x15a\x05+W__\xFD[Pa\x05\x85a\x05:6`\x04a(\xDDV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01RP_\x90\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x84R`\x01`0\x1B\x90\x91\x04\x16\x90\x82\x01R\x90V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x93\x84\x01Q\x16\x92\x81\x01\x92\x90\x92R\x01a\x02MV[4\x80\x15a\x05\xB6W__\xFD[Pa\x04\x0Ca\x01\xF7\x81V[4\x80\x15a\x05\xCBW__\xFD[Pa\x05\xFFa\x05\xDA6`\x04a(\xDDV[`\xFB` R_\x90\x81R`@\x90 Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x90`\x01`0\x1B\x90\x04`0\x1B\x82V[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x83Re\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16` \x83\x01R\x01a\x02MV[4\x80\x15a\x060W__\xFD[Pa\x06Da\x06?6`\x04a*\xFDV[a\x10\xAFV[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x02MV[4\x80\x15a\x06gW__\xFD[Pa\x06{a\x06v6`\x04a+DV[a\x10\xC5V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02MV[4\x80\x15a\x06\x9DW__\xFD[Pa\x06Da\x06\xAC6`\x04a(\xDDV[a\x11\xE9V[4\x80\x15a\x06\xBCW__\xFD[Pa\x06\xD0a\x06\xCB6`\x04a+{V[a\x12=V[`@Qa\x02M\x91\x90a,\x18V[4\x80\x15a\x06\xE8W__\xFD[Pa\x02ua\x06\xF76`\x04a(\xDDV[a\x12\x99V[4\x80\x15a\x07\x07W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07:W__\xFD[Pa\x07Na\x07I6`\x04a*\xFDV[a\x13\xDEV[`@Qa\x02M\x91\x90a,*V[4\x80\x15a\x07fW__\xFD[Pa\x02ua\x07u6`\x04a)QV[a\x14\x96V[4\x80\x15a\x07\x85W__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x029V[4\x80\x15a\x07\xA2W__\xFD[Pa\x02ua\x07\xB16`\x04a,yV[a\x14\xF0V[4\x80\x15a\x07\xC1W__\xFD[Pa\x02ua\x07\xD06`\x04a)QV[a\x16\x1AV[4\x80\x15a\x07\xE0W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x08\x13W__\xFD[Pa\x03Oa\x08\"6`\x04a(\xDDV[_\x90\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[a\x01-T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x08\x8AW`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11\x15a\x08\xE0W`@Qc\x19\x96Gk`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x90\x82\x01RQ` \x82\x01Qa\t\x1E\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a,\xB9V[B\x11a\t=W`@Qc\xA2\x82\x93\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16Be\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x1A\x87\x8B+\xF8h\x0C\x02\xF7\xD7\x9C\x19\x9Aa\xAD\xBE\x87D\xE8\xCC\xB0\xF1~6\"\x9Ba\x931\xFA.\x13\x91\x01[`@Q\x80\x91\x03\x90\xA2PPV[a\t\xA8a(\x81V[_a\t\xB5`\x0C` a,\xCCV[a\t\xBF\x90\x85a,\xB9V[\x90Pa\t\xCC\x83\x85\x83a\x16\x8BV[\x94\x93PPPPV[__a\t\xDF_a\x18\\V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P\x80B\x03a\t\xF7W_\x91PP\x90V[_a\n\x04`\x0C` a,\xCCV[a\n\x0E\x90\x83a,\xB9V[\x90P\x80a\n\x1A\x82a\x18\xE0V[Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x93\x92PPPV[_`\x02a\n;`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\x95W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a,\xE3V[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\n\xC7a\x19\x04V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\n\xEDW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a-/V[a\n\xF6\x81a\x19\x1FV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x0B\x11\x91\x83\x91\x90a\x19'V[PV[a\x0B\x1Ca\x1A\x91V[a\x0B0`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0Bm3_a\x1A\xC2V[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x0B\xB7W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a,\xE3V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0B\xE9a\x19\x04V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0C\x0FW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a-/V[a\x0C\x18\x82a\x19\x1FV[a\x0C$\x82\x82`\x01a\x19'V[PPV[`@Qc$\xD9\x12{`\xE2\x1B\x81R`\x04\x81\x01\x83\x90R_\x90\x81\x90`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\x93dI\xEC\x90`$\x01a\x01\0`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0C\x90W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0C\xB4\x91\x90a-\xE0V[\x90P\x80``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x80a\x0C\xDBWP\x82\x81``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[\x15a\x0C\xE9W_\x91PPa\x0F\rV[`\x80\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\r\x0FWP\x82\x81`\x80\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\r\x1DW_\x91PPa\x0F\rV[`@Qc-\x0CX\xC9`\xE1\x1B\x81R`\x04\x81\x01\x85\x90R`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81\x16`$\x83\x01R_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90cZ\x18\xB1\x92\x90`D\x01`\x80`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\r\xACW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\r\xD0\x91\x90a.\x86V[\x90P\x80` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x80a\r\xF7WP\x83\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[\x15a\x0E\x06W_\x92PPPa\x0F\rV[`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0E,WP\x83\x81`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\x0E;W_\x92PPPa\x0F\rV[_\x85\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x91\x90\x91R\x15\x80\x15\x90a\x0E\x89WP\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x85\x11[\x15a\x0E\xCFW\x80_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x80a\x0E\xBFWP\x84\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x15[\x15a\x0E\xCFW_\x93PPPPa\x0F\rV[`\xA0\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0E\xF5WP\x84\x83`\xA0\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\x0F\x05W_\x93PPPPa\x0F\rV[`\x01\x93PPPP[\x92\x91PPV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0F\xB2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x8CV[P_Q` a0\x96_9_Q\x90_R\x90V[a\x0F\xCCa\x1A\xC6V[a\x0Bm_a\x1B V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x10CW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x8CV[a\x0B\x11\x81a\x1B V[a\x10Ta\x1B9V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0Bm3`\x01a\x1A\xC2V[_a\x10\xAAa\x19\x04V[\x90P\x90V[_a\x10\xBB\x84\x84\x84a\x1BkV[\x90P[\x93\x92PPPV[_3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x11\x0FW`@Qcr\x10\x9Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x83\x01_a\x11\x1Ca\x1B\x89V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P_a\x113`\x0C` a,\xCCV[a\x11=\x90\x83a,\xB9V[\x90P_a\x11K\x84\x84\x84a\x16\x8BV[\x90P\x80` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x88`\x01`\x01`\xA0\x1B\x03\x16\x14a\x11\x83W`@Qc@\x9B2\x0F`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`@\x01QB\x10\x15\x80\x15a\x11\x9BWP\x80``\x01QB\x11\x15[a\x11\xB8W`@QcE\xCB\n\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x11\xCE\x83a\x11\xC9` \x87\x01\x87a.\xEBV[a\x1B\x93V[a\x11\xDA\x83\x83\x83\x87a\x1B\xE4V[``\x01Q\x97\x96PPPPPPPV[__a\x11\xF4\x83a\x18\xE0V[`@\x80Q\x80\x82\x01\x90\x91R\x90Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x80\x83R`\x01`0\x1B\x90\x91\x04`0\x1Be\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16` \x83\x01R\x90\x91P\x83\x90\x03a\x127W\x80` \x01Q\x91P[P\x91\x90PV[``a\x10\xBE\x83\x83\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x12\x8FWa\x12\x80`\x80\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a/-V[\x81R` \x01\x90`\x01\x01\x90a\x12cV[PPPPPa\x1CCV[a\x01-T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x12\xC5W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11a\x13\x1AW`@Qc\x0E\xC1\x12y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x91\x01\x81\x90R\x81Qa\x13U\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a,\xB9V[B\x11a\x13tW`@Qc\x99\xD3\xFA\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x80Tk\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\x19\x16`\x01`0\x1BBe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x02\x91\x90\x91\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x96\x82\xAE?\xB7\x9C\x10\x94\x81\x16\xFE*\"L\xCA\x90%\xFBvqdw\xD7\x13\xDF\xECvm\x8B\xCC\xEE\x17\x91\x01a\t\x94V[a\x14\x12`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01``\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90V[`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01a\x147\x86\x86\x86a\x10\xAFV[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x92\x16` \x83\x01R\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x81R` \x01\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90P\x93\x92PPPV[a\x14\x9Ea\x1A\xC6V[a\x01-\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\xF5d\n\xD8\xA7J`f\xC7\xF3\xBC\x15\x97m\x1D\x80\xBD\xE5\x1D\xBB\xC9\xD9\xCD\x87]\x9Ce\x82\xB5\xA7\x0E=\x90_\x90\xA3PPV[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x15\x0EWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x15'WP0;\x15\x80\x15a\x15'WP_T`\xFF\x16`\x01\x14[a\x15\x8AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x15\xABW_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\x15\xB4\x83a\x1DmV[a\x01-\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x84\x16\x17\x90U\x80\x15a\x16\x15W_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPPV[a\x16\"a\x1A\xC6V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x16S`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\x16\x93a(\x81V[a\x16\xA0` \x85\x01\x85a.\xEBV[\x90P_\x03a\x16\xB9Wa\x16\xB2\x83\x83a\x1D\xCBV[\x90Pa\x16\xD9V[`\x01\x845\x01a\x16\xCCWa\x16\xB2\x84\x83a\x1D\xF4V[a\x16\xD6\x84\x84a\x1E\xBEV[\x90P[\x80Q\x15a\x17sW\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c4?\nh`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x17<W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x17`\x91\x90a/\x8DV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01Ra\x10\xBEV[a\x17\x85\x81`\x80\x01Q``\x01QBa\x0C(V[a\x18AW`\x01\x81R`@\x80Qc\x06\x87\xE1M`\xE3\x1B\x81R\x90Q`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x91c4?\nh\x91`\x04\x80\x83\x01\x92` \x92\x91\x90\x82\x90\x03\x01\x81\x86Z\xFA\x15\x80\x15a\x17\xF0W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x18\x14\x91\x90a/\x8DV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R`\x01\x845\x01a\x18<Wa\x186`\x0C\x83a/\xA8V[``\x82\x01R[a\x10\xBEV[`\x80\x81\x01QQ`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R\x93\x92PPPV[__a\x18gFa\x1F\x87V[\x90P_a\x18t\x82Ba/\xA8V[\x90P_a\x18\x83`\x0C` a,\xCCV[a\x18\x8F`\x0C` a,\xCCV[a\x18\x99\x90\x84a/\xCFV[a\x18\xA3\x91\x90a,\xCCV[\x90Pa\x18\xD7a\x18\xB4`\x0C` a,\xCCV[a\x18\xBE\x90\x87a,\xCCV[a\x18\xC8\x83\x86a,\xB9V[a\x18\xD2\x91\x90a,\xB9V[a\x1F\xE2V[\x95\x94PPPPPV[_`\xFB\x81a\x18\xF0a\x01\xF7\x85a/\xE2V[\x81R` \x01\x90\x81R` \x01_ \x90P\x91\x90PV[_Q` a0\x96_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x0B\x11a\x1A\xC6V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x19ZWa\x16\x15\x83a LV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x19\xB4WP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x19\xB1\x91\x81\x01\x90a/\xF5V[`\x01[a\x1A\x17W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_Q` a0\x96_9_Q\x90_R\x81\x14a\x1A\x85W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x8CV[Pa\x16\x15\x83\x83\x83a \xE7V[a\x1A\xA5`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x0BmW`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0C$[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x0BmW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x8CV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x0B\x11\x81a!\x0BV[a\x1BM`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x0BmW`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`@Q\x84\x81R\x82\x84` \x83\x017` \x83\x01\x81 \x91PP\x93\x92PPPV[_a\x10\xAA_a\x18\\V[_a\x1B\x9D\x84a\x11\xE9V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1B\xBFWa\x1B\xBA\x84\x84\x84\x84a!\\V[a\x1B\xDEV[\x81\x15a\x1B\xDEW`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPPV[_a\x1B\xEE\x84a\x11\xE9V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1C*W\x815_\x19\x14a\x1C\x0EWPa\x1B\xDEV[a\x1C%\x84a\x1C\x1F`@\x85\x01\x85a.\xEBV[\x84a!\\V[a\x1C<V[\x84B\x14a\x1C<Wa\x1C<\x84\x84\x84a!\x96V[PPPPPV[```<\x82Qa\x1CS\x91\x90a,\xCCV[`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1CjWa\x1Cja)lV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x1C\x94W` \x82\x01\x81\x806\x837\x01\x90P[P\x90P` \x81\x01_[\x83Q\x81\x10\x15a\x1DfWa\x1C\xD2\x82\x85\x83\x81Q\x81\x10a\x1C\xBCWa\x1C\xBCa0\x0CV[` \x02` \x01\x01Q_\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x1D\x01\x82\x85\x83\x81Q\x81\x10a\x1C\xEAWa\x1C\xEAa0\x0CV[` \x02` \x01\x01Q` \x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x1D0\x82\x85\x83\x81Q\x81\x10a\x1D\x19Wa\x1D\x19a0\x0CV[` \x02` \x01\x01Q`@\x01Q`\xF0\x1B\x81R`\x02\x01\x90V[\x91Pa\x1D\\\x82\x85\x83\x81Q\x81\x10a\x1DHWa\x1DHa0\x0CV[` \x02` \x01\x01Q``\x01Q\x81R` \x01\x90V[\x91P`\x01\x01a\x1C\x9DV[PP\x91\x90PV[_Ta\x01\0\x90\x04`\xFF\x16a\x1D\x93W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a0 V[a\x1D\x9Ba\"\xA7V[a\x1D\xB9`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\x1D\xB3W\x81a\x1B V[3a\x1B V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[a\x1D\xD3a(\x81V[`\x01\x81R`@\x81\x01\x83\x90Ra\x1D\xE9`\x0C\x83a/\xA8V[``\x82\x01R\x92\x91PPV[a\x1D\xFCa(\x81V[_a\x1E3a\x1E\r` \x86\x01\x86a.\xEBV[`\x01a\x1E$a\x1E\x1F` \x8A\x01\x8Aa.\xEBV[a\"\xCDV[a\x1E.\x91\x90a/\xA8V[a\"\xD9V[\x90P`\x0C\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x1EN\x91\x90a/\xA8V[`@\x80\x84\x01\x91\x90\x91Ra\x1Ec\x90\x85\x01\x85a.\xEBV[\x90P_\x03a\x1E\x84W`\x01\x82Ra\x1Ez`\x0C\x84a/\xA8V[``\x83\x01Ra\x1E\xB7V[_a\x1E\x9Ba\x1E\x95`@\x87\x01\x87a.\xEBV[_a\"\xD9V[_\x84R` \x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x85\x01R`\x80\x84\x01RP[P\x92\x91PPV[a\x1E\xC6a(\x81V[_a\x1E\xDEa\x1E\xD7` \x86\x01\x86a.\xEBV[\x865a\"\xD9V[_\x80\x84R`\x80\x84\x01\x82\x90R` \x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x85\x01R\x90\x91P\x845\x90\x03a\x1F\x12W`@\x82\x01\x83\x90Ra\x1E\xB7V[a\x1F\"a\x1E\x1F` \x86\x01\x86a.\xEBV[\x845\x10a\x1FBW`@Qc6(\xA8\x1B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1F_a\x1FS` \x87\x01\x87a.\xEBV[a\x1E.`\x01\x895a/\xA8V[\x90P`\x0C\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x1Fz\x91\x90a/\xA8V[`@\x84\x01RPP\x92\x91PPV[_`\x01\x82\x03a\x1F\x9BWPc_\xC60W\x91\x90PV[aBh\x82\x03a\x1F\xAFWPce\x15j\xC0\x91\x90PV[d\x01\xA2\x14\x0C\xFF\x82\x03a\x1F\xC6WPcfu]l\x91\x90PV[b\x08\x8B\xB0\x82\x03a\x1F\xDBWPcg\xD8\x11\x18\x91\x90PV[P_\x91\x90PV[_e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x11\x15a HW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FSafeCast: value doesn't fit in 4`D\x82\x01Re8 bits`\xD0\x1B`d\x82\x01R`\x84\x01a\n\x8CV[P\x90V[`\x01`\x01`\xA0\x1B\x03\x81\x16;a \xB9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_Q` a0\x96_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a \xF0\x83a#GV[_\x82Q\x11\x80a \xFCWP\x80[\x15a\x16\x15Wa\x1B\xDE\x83\x83a#\x86V[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a!h\x85\x85\x85a\x10\xAFV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x81\x16\x90\x82\x16\x14a\x1C<W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a!\xA3``\x82\x01\x82a.\xEBV[\x90P_\x03a!\xCFW\x81Qa!\xCAW`@Qc\x04vw\xF5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\"\x91V[_a!\xE1\x84a\x07I`@\x85\x01\x85a.\xEBV[\x90P_a\"V\x82`@Q` \x01a!\xF8\x91\x90a,*V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x80Q` \x90\x91\x01 a\"\x1D``\x86\x01\x86a.\xEBV[\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa#\xAB\x92PPPV[\x90P\x83` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x81`\x01`\x01`\xA0\x1B\x03\x16\x14a\"\x8EW`@Qc\x15}\xF6\xA5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP[a\x1B\xDE\x83a\"\xA2`@\x84\x01\x84a.\xEBV[a#\xCDV[_Ta\x01\0\x90\x04`\xFF\x16a\x0BmW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a0 V[_a\x10\xBE`<\x83a/\xCFV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x83a#\x08`<\x84a,\xCCV[a#\x12\x90\x82a,\xB9V[\x805``\x90\x81\x1C\x84R`\x14\x82\x015`\xD0\x1C` \x85\x01R`\x1A\x82\x015`\xF0\x1C`@\x85\x01R`\x1C\x90\x91\x015\x90\x83\x01RP\x93\x92PPPV[a#P\x81a LV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x10\xBE\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a0\xB6`'\x919a$\xFAV[___a#\xB8\x85\x85a%nV[\x91P\x91Pa#\xC5\x81a%\xB0V[P\x93\x92PPPV[_`\x0B\x19\x84\x01\x81a#\xDE\x85\x85a\"\xCDV[\x90P_[\x81\x81\x10\x15a$wW_a#\xF6\x87\x87\x84a\"\xD9V[\x90P\x83\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11a$$W`@Qc\\\x03\x14\x1B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0C\x88\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x03\x81a$BWa$Ba/\xBBV[\x06\x15a$aW`@Qc\x97\x1C\xCE\x8F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x92P`\x01\x01a#\xE2V[Pa\x01\x80\x86\x01\x82\x10a$\x9CW`@Qc\x96\xAC\xE7\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPa$\xA9\x84\x84\x84a\x10\xAFV[\x90Pa$\xB5\x84\x82a&\xF9V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x16\x81R\x84\x90\x7F\xF4\xB5[\x85lX;\x95/\x0C\rB\x06|\x8Ec\xC9\xFA\xE3\x952)\x05\xD4^U\xAF\x1D\x0F\tY\x94\x90` \x01`@Q\x80\x91\x03\x90\xA2\x93\x92PPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa%\x16\x91\x90a0kV[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a%NW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a%SV[``\x91P[P\x91P\x91Pa%d\x86\x83\x83\x87a'\"V[\x96\x95PPPPPPV[__\x82Q`A\x03a%\xA2W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa%\x96\x87\x82\x85\x85a'\x9AV[\x94P\x94PPPPa%\xA9V[P_\x90P`\x02[\x92P\x92\x90PV[_\x81`\x04\x81\x11\x15a%\xC3Wa%\xC3a0\x81V[\x03a%\xCBWPV[`\x01\x81`\x04\x81\x11\x15a%\xDFWa%\xDFa0\x81V[\x03a&,W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x18`$\x82\x01R\x7FECDSA: invalid signature\0\0\0\0\0\0\0\0`D\x82\x01R`d\x01a\n\x8CV[`\x02\x81`\x04\x81\x11\x15a&@Wa&@a0\x81V[\x03a&\x8DW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FECDSA: invalid signature length\0`D\x82\x01R`d\x01a\n\x8CV[`\x03\x81`\x04\x81\x11\x15a&\xA1Wa&\xA1a0\x81V[\x03a\x0B\x11W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\"`$\x82\x01R\x7FECDSA: invalid signature 's' val`D\x82\x01Raue`\xF0\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_a'\x03\x83a\x18\xE0V[`0\x92\x90\x92\x1C`\x01`0\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x92\x90\x92\x17\x90UPV[``\x83\x15a'\x90W\x82Q_\x03a'\x89W`\x01`\x01`\xA0\x1B\x03\x85\x16;a'\x89W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x8CV[P\x81a\t\xCCV[a\t\xCC\x83\x83a(WV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a'\xCFWP_\x90P`\x03a(NV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a( W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a(HW_`\x01\x92P\x92PPa(NV[\x91P_\x90P[\x94P\x94\x92PPPV[\x81Q\x15a(gW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x91\x90a,\x18V[`@Q\x80`\xA0\x01`@R\x80_\x15\x15\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01a(\xD8`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x90V[\x90R\x90V[_` \x82\x84\x03\x12\x15a(\xEDW__\xFD[P5\x91\x90PV[__`@\x83\x85\x03\x12\x15a)\x05W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a)!W__\xFD[\x83\x01`\x80\x81\x86\x03\x12\x15a)2W__\xFD[\x80\x91PP\x92P\x92\x90PV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0B\x11W__\xFD[_` \x82\x84\x03\x12\x15a)aW__\xFD[\x815a\x10\xBE\x81a)=V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Qa\x01\0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xA3Wa)\xA3a)lV[`@R\x90V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xA3Wa)\xA3a)lV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xF3Wa)\xF3a)lV[`@R\x91\x90PV[__`@\x83\x85\x03\x12\x15a*\x0CW__\xFD[\x825a*\x17\x81a)=V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a*1W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a*AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a*ZWa*Za)lV[a*m`\x1F\x82\x01`\x1F\x19\x16` \x01a)\xCBV[\x81\x81R\x86` \x83\x85\x01\x01\x11\x15a*\x81W__\xFD[\x81` \x84\x01` \x83\x017_` \x83\x83\x01\x01R\x80\x93PPPP\x92P\x92\x90PV[__`@\x83\x85\x03\x12\x15a*\xB1W__\xFD[PP\x805\x92` \x90\x91\x015\x91PV[__\x83`\x1F\x84\x01\x12a*\xD0W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a*\xE6W__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a%\xA9W__\xFD[___`@\x84\x86\x03\x12\x15a+\x0FW__\xFD[\x835\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a++W__\xFD[a+7\x86\x82\x87\x01a*\xC0V[\x94\x97\x90\x96P\x93\x94PPPPV[___`@\x84\x86\x03\x12\x15a+VW__\xFD[\x835a+a\x81a)=V[\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a++W__\xFD[__` \x83\x85\x03\x12\x15a+\x8CW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xA1W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a+\xB1W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xC6W__\xFD[\x85` \x82`\x07\x1B\x84\x01\x01\x11\x15a+\xDAW__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_\x81Q\x80\x84R\x80` \x84\x01` \x86\x01^_` \x82\x86\x01\x01R` `\x1F\x19`\x1F\x83\x01\x16\x85\x01\x01\x91PP\x92\x91PPV[` \x81R_a\x10\xBE` \x83\x01\x84a+\xEAV[` \x81R`\x01`\x01`@\x1B\x03\x82Q\x16` \x82\x01R_` \x83\x01Q```@\x84\x01Ra,X`\x80\x84\x01\x82a+\xEAV[`@\x94\x90\x94\x01Q`\x01`\x01`\xA0\x1B\x03\x16``\x93\x90\x93\x01\x92\x90\x92RP\x90\x91\x90PV[__`@\x83\x85\x03\x12\x15a,\x8AW__\xFD[\x825a,\x95\x81a)=V[\x91P` \x83\x015a)2\x81a)=V[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x0F\rWa\x0F\ra,\xA5V[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x0F\rWa\x0F\ra,\xA5V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[\x80Qi\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a-\x94W__\xFD[\x91\x90PV[a\xFF\xFF\x81\x16\x81\x14a\x0B\x11W__\xFD[\x80Qa-\x94\x81a-\x99V[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0B\x11W__\xFD[\x80Qa-\x94\x81a-\xB3V[\x80Q\x80\x15\x15\x81\x14a-\x94W__\xFD[_a\x01\0\x82\x84\x03\x12\x80\x15a-\xF2W__\xFD[Pa-\xFBa)\x80V[\x82Qa.\x06\x81a)=V[\x81Ra.\x14` \x84\x01a-{V[` \x82\x01Ra.%`@\x84\x01a-\xA8V[`@\x82\x01Ra.6``\x84\x01a-\xC6V[``\x82\x01Ra.G`\x80\x84\x01a-\xC6V[`\x80\x82\x01Ra.X`\xA0\x84\x01a-\xC6V[`\xA0\x82\x01Ra.i`\xC0\x84\x01a-\xD1V[`\xC0\x82\x01Ra.z`\xE0\x84\x01a-\xD1V[`\xE0\x82\x01R\x93\x92PPPV[_`\x80\x82\x84\x03\x12\x80\x15a.\x97W__\xFD[Pa.\xA0a)\xA9V[\x82Qa.\xAB\x81a)=V[\x81R` \x83\x01Qa.\xBB\x81a-\xB3V[` \x82\x01R`@\x83\x01Qa.\xCE\x81a-\xB3V[`@\x82\x01Ra.\xDF``\x84\x01a-\xD1V[``\x82\x01R\x93\x92PPPV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a/\0W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a/\x19W__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a%\xA9W__\xFD[_`\x80\x82\x84\x03\x12\x80\x15a/>W__\xFD[Pa/Ga)\xA9V[\x825a/R\x81a)=V[\x81R` \x83\x015a/b\x81a-\xB3V[` \x82\x01R`@\x83\x015a/u\x81a-\x99V[`@\x82\x01R``\x92\x83\x015\x92\x81\x01\x92\x90\x92RP\x91\x90PV[_` \x82\x84\x03\x12\x15a/\x9DW__\xFD[\x81Qa\x10\xBE\x81a)=V[\x81\x81\x03\x81\x81\x11\x15a\x0F\rWa\x0F\ra,\xA5V[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a/\xDDWa/\xDDa/\xBBV[P\x04\x90V[_\x82a/\xF0Wa/\xF0a/\xBBV[P\x06\x90V[_` \x82\x84\x03\x12\x15a0\x05W__\xFD[PQ\x91\x90PV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \xBC2\x08\xE8\x9D\xB4y9Ca\xBF\x8F\xC0G\xBB\x9B\0\x0FUQ\xA5\xC6\xAF\x87Q\x9C\xEE\xFF\xCB\xD5\xE9\x13dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405260043610610207575f3560e01c80638da5cb5b11610113578063cc8099901161009d578063e30c39781161006d578063e30c39781461077a578063f09a401614610797578063f2fde38b146107b6578063fb0e722b146107d5578063fd40a5fe14610808575f5ffd5b8063cc809990146106dd578063d91f24f1146106fc578063dfbb74071461072f578063e2828f471461075b575f5ffd5b8063a486e0dd116100e3578063a486e0dd146105c0578063a6e0427414610625578063ac0004da1461065c578063ae41501a14610692578063c86dc3fd146106b1575f5ffd5b80638da5cb5b146104bd578063937aaa9b146104da5780639fe786ab14610520578063a2bf9dba146105ab575f5ffd5b80634f1ef286116101945780635ddc9e8d116101645780635ddc9e8d1461043a578063715018a61461046d57806379ba5097146104815780638456cb59146104955780638abf6077146104a9575f5ffd5b80634f1ef286146103c6578063513ae999146103d957806352d1902d146103f85780635c975abb1461041a575f5ffd5b806323c0b1ab116101da57806323c0b1ab1461033b5780633075db561461035f5780633659cfe6146103735780633f4ba83a146103925780634ba25656146103a6575f5ffd5b806304f3bcec1461020b57806306418f05146102565780630d9cead7146102775780631d3f2b5e146102aa575b5f5ffd5b348015610216575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b348015610261575f5ffd5b506102756102703660046128dd565b61085e565b005b348015610282575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b3480156102b5575f5ffd5b506102c96102c43660046128f4565b6109a0565b604080518251151581526020808401516001600160a01b03908116828401528484015183850152606080860151818501526080958601518051909216958401959095529081015165ffffffffffff1660a08301529182015161ffff1660c082015291015160e08201526101000161024d565b348015610346575f5ffd5b5061034f6109d4565b604051901515815260200161024d565b34801561036a575f5ffd5b5061034f610a2c565b34801561037e575f5ffd5b5061027561038d366004612951565b610a44565b34801561039d575f5ffd5b50610275610b14565b3480156103b1575f5ffd5b5061012d54610239906001600160a01b031681565b6102756103d43660046129fb565b610b6f565b3480156103e4575f5ffd5b5061034f6103f3366004612aa0565b610c28565b348015610403575f5ffd5b5061040c610f13565b60405190815260200161024d565b348015610425575f5ffd5b5061034f60c954610100900460ff1660021490565b348015610445575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b348015610478575f5ffd5b50610275610fc4565b34801561048c575f5ffd5b50610275610fd5565b3480156104a0575f5ffd5b5061027561104c565b3480156104b4575f5ffd5b506102396110a1565b3480156104c8575f5ffd5b506033546001600160a01b0316610239565b3480156104e5575f5ffd5b506040805180820182525f8082526020918201528151808301835262015180808252908201818152835191825251918101919091520161024d565b34801561052b575f5ffd5b5061058561053a3660046128dd565b604080518082019091525f8082526020820152505f90815261012e602090815260409182902082518084019093525465ffffffffffff8082168452600160301b909104169082015290565b60408051825165ffffffffffff908116825260209384015116928101929092520161024d565b3480156105b6575f5ffd5b5061040c6101f781565b3480156105cb575f5ffd5b506105ff6105da3660046128dd565b60fb6020525f908152604090205465ffffffffffff811690600160301b900460301b82565b6040805165ffffffffffff909316835265ffffffffffff1990911660208301520161024d565b348015610630575f5ffd5b5061064461063f366004612afd565b6110af565b60405165ffffffffffff19909116815260200161024d565b348015610667575f5ffd5b5061067b610676366004612b44565b6110c5565b60405165ffffffffffff909116815260200161024d565b34801561069d575f5ffd5b506106446106ac3660046128dd565b6111e9565b3480156106bc575f5ffd5b506106d06106cb366004612b7b565b61123d565b60405161024d9190612c18565b3480156106e8575f5ffd5b506102756106f73660046128dd565b611299565b348015610707575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b34801561073a575f5ffd5b5061074e610749366004612afd565b6113de565b60405161024d9190612c2a565b348015610766575f5ffd5b50610275610775366004612951565b611496565b348015610785575f5ffd5b506065546001600160a01b0316610239565b3480156107a2575f5ffd5b506102756107b1366004612c79565b6114f0565b3480156107c1575f5ffd5b506102756107d0366004612951565b61161a565b3480156107e0575f5ffd5b506102397f000000000000000000000000000000000000000000000000000000000000000081565b348015610813575f5ffd5b5061034f6108223660046128dd565b5f90815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b90920416929091018290521190565b61012d546001600160a01b0316331461088a5760405163ac9d87cd60e01b815260040160405180910390fd5b5f81815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b9092041691830182905211156108e057604051631996476b60e01b815260040160405180910390fd5b6040805180820182525f8082526020918201528151808301909252620151808083529082015251602082015161091e919065ffffffffffff16612cb9565b421161093d5760405163a282931f60e01b815260040160405180910390fd5b5f82815261012e6020908152604091829020805465ffffffffffff19164265ffffffffffff16908117909155915191825283917f1a878b2bf8680c02f7d79c199a61adbe8744e8ccb0f17e36229b619331fa2e1391015b60405180910390a25050565b6109a8612881565b5f6109b5600c6020612ccc565b6109bf9085612cb9565b90506109cc83858361168b565b949350505050565b5f5f6109df5f61185c565b65ffffffffffff1690508042036109f7575f91505090565b5f610a04600c6020612ccc565b610a0e9083612cb9565b905080610a1a826118e0565b5465ffffffffffff1614159392505050565b5f6002610a3b60c95460ff1690565b60ff1614905090565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610a955760405162461bcd60e51b8152600401610a8c90612ce3565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610ac7611904565b6001600160a01b031614610aed5760405162461bcd60e51b8152600401610a8c90612d2f565b610af68161191f565b604080515f80825260208201909252610b1191839190611927565b50565b610b1c611a91565b610b3060c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610b6d335f611ac2565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610bb75760405162461bcd60e51b8152600401610a8c90612ce3565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610be9611904565b6001600160a01b031614610c0f5760405162461bcd60e51b8152600401610a8c90612d2f565b610c188261191f565b610c2482826001611927565b5050565b6040516324d9127b60e21b8152600481018390525f9081906001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169063936449ec9060240161010060405180830381865afa158015610c90573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610cb49190612de0565b9050806060015165ffffffffffff165f1480610cdb575082816060015165ffffffffffff16115b15610ce9575f915050610f0d565b608081015165ffffffffffff1615801590610d0f575082816080015165ffffffffffff16105b15610d1d575f915050610f0d565b604051632d0c58c960e11b8152600481018590526001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000811660248301525f917f000000000000000000000000000000000000000000000000000000000000000090911690635a18b19290604401608060405180830381865afa158015610dac573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610dd09190612e86565b9050806020015165ffffffffffff165f1480610df7575083816020015165ffffffffffff16115b15610e06575f92505050610f0d565b604081015165ffffffffffff1615801590610e2c575083816040015165ffffffffffff16105b15610e3b575f92505050610f0d565b5f85815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b909204169183019190915215801590610e895750805165ffffffffffff1685115b15610ecf57805f015165ffffffffffff16816020015165ffffffffffff161080610ebf575084816020015165ffffffffffff1610155b15610ecf575f9350505050610f0d565b60a083015165ffffffffffff1615801590610ef55750848360a0015165ffffffffffff16105b15610f05575f9350505050610f0d565b600193505050505b92915050565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610fb25760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c00000000000000006064820152608401610a8c565b505f5160206130965f395f51905f5290565b610fcc611ac6565b610b6d5f611b20565b60655433906001600160a01b031681146110435760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b6064820152608401610a8c565b610b1181611b20565b611054611b39565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610b6d336001611ac2565b5f6110aa611904565b905090565b5f6110bb848484611b6b565b90505b9392505050565b5f336001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461110f576040516372109f7760e01b815260040160405180910390fd5b602083015f61111c611b89565b65ffffffffffff1690505f611133600c6020612ccc565b61113d9083612cb9565b90505f61114b84848461168b565b905080602001516001600160a01b0316886001600160a01b0316146111835760405163409b320f60e11b815260040160405180910390fd5b8060400151421015801561119b575080606001514211155b6111b8576040516345cb0af960e01b815260040160405180910390fd5b6111ce836111c96020870187612eeb565b611b93565b6111da83838387611be4565b60600151979650505050505050565b5f5f6111f4836118e0565b60408051808201909152905465ffffffffffff8116808352600160301b90910460301b65ffffffffffff1916602083015290915083900361123757806020015191505b50919050565b60606110be8383808060200260200160405190810160405280939291908181526020015f905b8282101561128f5761128060808302860136819003810190612f2d565b81526020019060010190611263565b5050505050611c43565b61012d546001600160a01b031633146112c55760405163ac9d87cd60e01b815260040160405180910390fd5b5f81815261012e602090815260409182902082518084019093525465ffffffffffff808216808552600160301b909204169183018290521161131a57604051630ec1127960e01b815260040160405180910390fd5b6040805180820182525f80825260209182015281518083019092526201518080835291018190528151611355919065ffffffffffff16612cb9565b4211611374576040516399d3faf960e01b815260040160405180910390fd5b5f82815261012e602090815260409182902080546bffffffffffff0000000000001916600160301b4265ffffffffffff1690810291909117909155915191825283917f9682ae3fb79c10948116fe2a224cca9025fb76716477d713dfec766d8bccee179101610994565b61141260405180606001604052805f6001600160401b03168152602001606081526020015f6001600160a01b031681525090565b60405180606001604052805f6001600160401b031681526020016114378686866110af565b6040805165ffffffffffff1990921660208301520160405160208183030381529060405281526020017f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031681525090509392505050565b61149e611ac6565b61012d80546001600160a01b038381166001600160a01b0319831681179093556040519116919082907ff5640ad8a74a6066c7f3bc15976d1d80bde51dbbc9d9cd875d9c6582b5a70e3d905f90a35050565b5f54610100900460ff161580801561150e57505f54600160ff909116105b806115275750303b15801561152757505f5460ff166001145b61158a5760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b6064820152608401610a8c565b5f805460ff1916600117905580156115ab575f805461ff0019166101001790555b6115b483611d6d565b61012d80546001600160a01b0319166001600160a01b0384161790558015611615575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b505050565b611622611ac6565b606580546001600160a01b0383166001600160a01b031990911681179091556116536033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b611693612881565b6116a06020850185612eeb565b90505f036116b9576116b28383611dcb565b90506116d9565b60018435016116cc576116b28483611df4565b6116d68484611ebe565b90505b805115611773577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663343f0a686040518163ffffffff1660e01b8152600401602060405180830381865afa15801561173c573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906117609190612f8d565b6001600160a01b031660208201526110be565b61178581608001516060015142610c28565b611841576001815260408051630687e14d60e31b815290516001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169163343f0a689160048083019260209291908290030181865afa1580156117f0573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906118149190612f8d565b6001600160a01b03166020820152600184350161183c57611836600c83612fa8565b60608201525b6110be565b6080810151516001600160a01b031660208201529392505050565b5f5f61186746611f87565b90505f6118748242612fa8565b90505f611883600c6020612ccc565b61188f600c6020612ccc565b6118999084612fcf565b6118a39190612ccc565b90506118d76118b4600c6020612ccc565b6118be9087612ccc565b6118c88386612cb9565b6118d29190612cb9565b611fe2565b95945050505050565b5f60fb816118f06101f785612fe2565b81526020019081526020015f209050919050565b5f5160206130965f395f51905f52546001600160a01b031690565b610b11611ac6565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff161561195a576116158361204c565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa9250505080156119b4575060408051601f3d908101601f191682019092526119b191810190612ff5565b60015b611a175760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b6064820152608401610a8c565b5f5160206130965f395f51905f528114611a855760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b6064820152608401610a8c565b506116158383836120e7565b611aa560c954610100900460ff1660021490565b610b6d5760405163bae6e2a960e01b815260040160405180910390fd5b610c245b6033546001600160a01b03163314610b6d5760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610a8c565b606580546001600160a01b0319169055610b118161210b565b611b4d60c954610100900460ff1660021490565b15610b6d5760405163bae6e2a960e01b815260040160405180910390fd5b5f604051848152828460208301376020830181209150509392505050565b5f6110aa5f61185c565b5f611b9d846111e9565b905065ffffffffffff19811615611bbf57611bba8484848461215c565b611bde565b8115611bde5760405163eaf82a2560e01b815260040160405180910390fd5b50505050565b5f611bee846111e9565b905065ffffffffffff19811615611c2a5781355f1914611c0e5750611bde565b611c2584611c1f6040850185612eeb565b8461215c565b611c3c565b844214611c3c57611c3c848484612196565b5050505050565b6060603c8251611c539190612ccc565b6001600160401b03811115611c6a57611c6a61296c565b6040519080825280601f01601f191660200182016040528015611c94576020820181803683370190505b509050602081015f5b8351811015611d6657611cd282858381518110611cbc57611cbc61300c565b60200260200101515f015160601b815260140190565b9150611d0182858381518110611cea57611cea61300c565b60200260200101516020015160d01b815260060190565b9150611d3082858381518110611d1957611d1961300c565b60200260200101516040015160f01b815260020190565b9150611d5c82858381518110611d4857611d4861300c565b602002602001015160600151815260200190565b9150600101611c9d565b5050919050565b5f54610100900460ff16611d935760405162461bcd60e51b8152600401610a8c90613020565b611d9b6122a7565b611db96001600160a01b03821615611db35781611b20565b33611b20565b5060c9805461ff001916610100179055565b611dd3612881565b6001815260408101839052611de9600c83612fa8565b606082015292915050565b611dfc612881565b5f611e33611e0d6020860186612eeb565b6001611e24611e1f60208a018a612eeb565b6122cd565b611e2e9190612fa8565b6122d9565b9050600c816020015165ffffffffffff16611e4e9190612fa8565b604080840191909152611e6390850185612eeb565b90505f03611e845760018252611e7a600c84612fa8565b6060830152611eb7565b5f611e9b611e956040870187612eeb565b5f6122d9565b5f8452602081015165ffffffffffff1660608501526080840152505b5092915050565b611ec6612881565b5f611ede611ed76020860186612eeb565b86356122d9565b5f80845260808401829052602082015165ffffffffffff16606085015290915084359003611f125760408201839052611eb7565b611f22611e1f6020860186612eeb565b843510611f4257604051633628a81b60e01b815260040160405180910390fd5b5f611f5f611f536020870187612eeb565b611e2e60018935612fa8565b9050600c816020015165ffffffffffff16611f7a9190612fa8565b6040840152505092915050565b5f60018203611f9b5750635fc63057919050565b6142688203611faf57506365156ac0919050565b6401a2140cff8203611fc657506366755d6c919050565b62088bb08203611fdb57506367d81118919050565b505f919050565b5f65ffffffffffff8211156120485760405162461bcd60e51b815260206004820152602660248201527f53616665436173743a2076616c756520646f65736e27742066697420696e203460448201526538206269747360d01b6064820152608401610a8c565b5090565b6001600160a01b0381163b6120b95760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b6064820152608401610a8c565b5f5160206130965f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b6120f083612347565b5f825111806120fc5750805b1561161557611bde8383612386565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f6121688585856110af565b905065ffffffffffff1982811690821614611c3c5760405163eaf82a2560e01b815260040160405180910390fd5b6121a36060820182612eeb565b90505f036121cf5781516121ca5760405163047677f560e21b815260040160405180910390fd5b612291565b5f6121e1846107496040850185612eeb565b90505f612256826040516020016121f89190612c2a565b60408051601f19818403018152919052805160209091012061221d6060860186612eeb565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152506123ab92505050565b905083602001516001600160a01b0316816001600160a01b03161461228e5760405163157df6a560e21b815260040160405180910390fd5b50505b611bde836122a26040840184612eeb565b6123cd565b5f54610100900460ff16610b6d5760405162461bcd60e51b8152600401610a8c90613020565b5f6110be603c83612fcf565b604080516080810182525f80825260208201819052918101829052606081019190915283612308603c84612ccc565b6123129082612cb9565b8035606090811c8452601482013560d01c6020850152601a82013560f01c6040850152601c9091013590830152509392505050565b6123508161204c565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b60606110be83836040518060600160405280602781526020016130b6602791396124fa565b5f5f5f6123b8858561256e565b915091506123c5816125b0565b509392505050565b5f600b198401816123de85856122cd565b90505f5b81811015612477575f6123f68787846122d9565b905083816020015165ffffffffffff161161242457604051635c03141b60e11b815260040160405180910390fd5b600c88826020015165ffffffffffff16038161244257612442612fbb565b06156124615760405163971cce8f60e01b815260040160405180910390fd5b6020015165ffffffffffff1692506001016123e2565b506101808601821061249c576040516396ace79b60e01b815260040160405180910390fd5b50506124a98484846110af565b90506124b584826126f9565b60405165ffffffffffff198216815284907ff4b55b856c583b952f0c0d42067c8e63c9fae395322905d45e55af1d0f0959949060200160405180910390a29392505050565b60605f5f856001600160a01b031685604051612516919061306b565b5f60405180830381855af49150503d805f811461254e576040519150601f19603f3d011682016040523d82523d5f602084013e612553565b606091505b509150915061256486838387612722565b9695505050505050565b5f5f82516041036125a2576020830151604084015160608501515f1a6125968782858561279a565b945094505050506125a9565b505f905060025b9250929050565b5f8160048111156125c3576125c3613081565b036125cb5750565b60018160048111156125df576125df613081565b0361262c5760405162461bcd60e51b815260206004820152601860248201527f45434453413a20696e76616c6964207369676e617475726500000000000000006044820152606401610a8c565b600281600481111561264057612640613081565b0361268d5760405162461bcd60e51b815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e677468006044820152606401610a8c565b60038160048111156126a1576126a1613081565b03610b115760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c604482015261756560f01b6064820152608401610a8c565b5f612703836118e0565b60309290921c600160301b0265ffffffffffff90931692909217905550565b606083156127905782515f03612789576001600160a01b0385163b6127895760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610a8c565b50816109cc565b6109cc8383612857565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08311156127cf57505f9050600361284e565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015612820573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116612848575f6001925092505061284e565b91505f90505b94509492505050565b8151156128675781518083602001fd5b8060405162461bcd60e51b8152600401610a8c9190612c18565b6040518060a001604052805f151581526020015f6001600160a01b031681526020015f81526020015f81526020016128d8604080516080810182525f80825260208201819052918101829052606081019190915290565b905290565b5f602082840312156128ed575f5ffd5b5035919050565b5f5f60408385031215612905575f5ffd5b8235915060208301356001600160401b03811115612921575f5ffd5b830160808186031215612932575f5ffd5b809150509250929050565b6001600160a01b0381168114610b11575f5ffd5b5f60208284031215612961575f5ffd5b81356110be8161293d565b634e487b7160e01b5f52604160045260245ffd5b60405161010081016001600160401b03811182821017156129a3576129a361296c565b60405290565b604051608081016001600160401b03811182821017156129a3576129a361296c565b604051601f8201601f191681016001600160401b03811182821017156129f3576129f361296c565b604052919050565b5f5f60408385031215612a0c575f5ffd5b8235612a178161293d565b915060208301356001600160401b03811115612a31575f5ffd5b8301601f81018513612a41575f5ffd5b80356001600160401b03811115612a5a57612a5a61296c565b612a6d601f8201601f19166020016129cb565b818152866020838501011115612a81575f5ffd5b816020840160208301375f602083830101528093505050509250929050565b5f5f60408385031215612ab1575f5ffd5b50508035926020909101359150565b5f5f83601f840112612ad0575f5ffd5b5081356001600160401b03811115612ae6575f5ffd5b6020830191508360208285010111156125a9575f5ffd5b5f5f5f60408486031215612b0f575f5ffd5b8335925060208401356001600160401b03811115612b2b575f5ffd5b612b3786828701612ac0565b9497909650939450505050565b5f5f5f60408486031215612b56575f5ffd5b8335612b618161293d565b925060208401356001600160401b03811115612b2b575f5ffd5b5f5f60208385031215612b8c575f5ffd5b82356001600160401b03811115612ba1575f5ffd5b8301601f81018513612bb1575f5ffd5b80356001600160401b03811115612bc6575f5ffd5b8560208260071b8401011115612bda575f5ffd5b6020919091019590945092505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081525f6110be6020830184612bea565b602081526001600160401b0382511660208201525f602083015160606040840152612c586080840182612bea565b604094909401516001600160a01b0316606093909301929092525090919050565b5f5f60408385031215612c8a575f5ffd5b8235612c958161293d565b915060208301356129328161293d565b634e487b7160e01b5f52601160045260245ffd5b80820180821115610f0d57610f0d612ca5565b8082028115828204841417610f0d57610f0d612ca5565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b805169ffffffffffffffffffff81168114612d94575f5ffd5b919050565b61ffff81168114610b11575f5ffd5b8051612d9481612d99565b65ffffffffffff81168114610b11575f5ffd5b8051612d9481612db3565b80518015158114612d94575f5ffd5b5f610100828403128015612df2575f5ffd5b50612dfb612980565b8251612e068161293d565b8152612e1460208401612d7b565b6020820152612e2560408401612da8565b6040820152612e3660608401612dc6565b6060820152612e4760808401612dc6565b6080820152612e5860a08401612dc6565b60a0820152612e6960c08401612dd1565b60c0820152612e7a60e08401612dd1565b60e08201529392505050565b5f6080828403128015612e97575f5ffd5b50612ea06129a9565b8251612eab8161293d565b81526020830151612ebb81612db3565b60208201526040830151612ece81612db3565b6040820152612edf60608401612dd1565b60608201529392505050565b5f5f8335601e19843603018112612f00575f5ffd5b8301803591506001600160401b03821115612f19575f5ffd5b6020019150368190038213156125a9575f5ffd5b5f6080828403128015612f3e575f5ffd5b50612f476129a9565b8235612f528161293d565b81526020830135612f6281612db3565b60208201526040830135612f7581612d99565b60408201526060928301359281019290925250919050565b5f60208284031215612f9d575f5ffd5b81516110be8161293d565b81810381811115610f0d57610f0d612ca5565b634e487b7160e01b5f52601260045260245ffd5b5f82612fdd57612fdd612fbb565b500490565b5f82612ff057612ff0612fbb565b500690565b5f60208284031215613005575f5ffd5b5051919050565b634e487b7160e01b5f52603260045260245ffd5b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b5f82518060208501845e5f920191825250919050565b634e487b7160e01b5f52602160045260245ffdfe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220bc3208e89db479394361bf8fc047bb9b000f5551a5c6af87519ceeffcbd5e91364736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R`\x046\x10a\x02\x07W_5`\xE0\x1C\x80c\x8D\xA5\xCB[\x11a\x01\x13W\x80c\xCC\x80\x99\x90\x11a\0\x9DW\x80c\xE3\x0C9x\x11a\0mW\x80c\xE3\x0C9x\x14a\x07zW\x80c\xF0\x9A@\x16\x14a\x07\x97W\x80c\xF2\xFD\xE3\x8B\x14a\x07\xB6W\x80c\xFB\x0Er+\x14a\x07\xD5W\x80c\xFD@\xA5\xFE\x14a\x08\x08W__\xFD[\x80c\xCC\x80\x99\x90\x14a\x06\xDDW\x80c\xD9\x1F$\xF1\x14a\x06\xFCW\x80c\xDF\xBBt\x07\x14a\x07/W\x80c\xE2\x82\x8FG\x14a\x07[W__\xFD[\x80c\xA4\x86\xE0\xDD\x11a\0\xE3W\x80c\xA4\x86\xE0\xDD\x14a\x05\xC0W\x80c\xA6\xE0Bt\x14a\x06%W\x80c\xAC\0\x04\xDA\x14a\x06\\W\x80c\xAEAP\x1A\x14a\x06\x92W\x80c\xC8m\xC3\xFD\x14a\x06\xB1W__\xFD[\x80c\x8D\xA5\xCB[\x14a\x04\xBDW\x80c\x93z\xAA\x9B\x14a\x04\xDAW\x80c\x9F\xE7\x86\xAB\x14a\x05 W\x80c\xA2\xBF\x9D\xBA\x14a\x05\xABW__\xFD[\x80cO\x1E\xF2\x86\x11a\x01\x94W\x80c]\xDC\x9E\x8D\x11a\x01dW\x80c]\xDC\x9E\x8D\x14a\x04:W\x80cqP\x18\xA6\x14a\x04mW\x80cy\xBAP\x97\x14a\x04\x81W\x80c\x84V\xCBY\x14a\x04\x95W\x80c\x8A\xBF`w\x14a\x04\xA9W__\xFD[\x80cO\x1E\xF2\x86\x14a\x03\xC6W\x80cQ:\xE9\x99\x14a\x03\xD9W\x80cR\xD1\x90-\x14a\x03\xF8W\x80c\\\x97Z\xBB\x14a\x04\x1AW__\xFD[\x80c#\xC0\xB1\xAB\x11a\x01\xDAW\x80c#\xC0\xB1\xAB\x14a\x03;W\x80c0u\xDBV\x14a\x03_W\x80c6Y\xCF\xE6\x14a\x03sW\x80c?K\xA8:\x14a\x03\x92W\x80cK\xA2VV\x14a\x03\xA6W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x02\x0BW\x80c\x06A\x8F\x05\x14a\x02VW\x80c\r\x9C\xEA\xD7\x14a\x02wW\x80c\x1D?+^\x14a\x02\xAAW[__\xFD[4\x80\x15a\x02\x16W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02aW__\xFD[Pa\x02ua\x02p6`\x04a(\xDDV[a\x08^V[\0[4\x80\x15a\x02\x82W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x02\xB5W__\xFD[Pa\x02\xC9a\x02\xC46`\x04a(\xF4V[a\t\xA0V[`@\x80Q\x82Q\x15\x15\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x82\x84\x01R\x84\x84\x01Q\x83\x85\x01R``\x80\x86\x01Q\x81\x85\x01R`\x80\x95\x86\x01Q\x80Q\x90\x92\x16\x95\x84\x01\x95\x90\x95R\x90\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xA0\x83\x01R\x91\x82\x01Qa\xFF\xFF\x16`\xC0\x82\x01R\x91\x01Q`\xE0\x82\x01Ra\x01\0\x01a\x02MV[4\x80\x15a\x03FW__\xFD[Pa\x03Oa\t\xD4V[`@Q\x90\x15\x15\x81R` \x01a\x02MV[4\x80\x15a\x03jW__\xFD[Pa\x03Oa\n,V[4\x80\x15a\x03~W__\xFD[Pa\x02ua\x03\x8D6`\x04a)QV[a\nDV[4\x80\x15a\x03\x9DW__\xFD[Pa\x02ua\x0B\x14V[4\x80\x15a\x03\xB1W__\xFD[Pa\x01-Ta\x029\x90`\x01`\x01`\xA0\x1B\x03\x16\x81V[a\x02ua\x03\xD46`\x04a)\xFBV[a\x0BoV[4\x80\x15a\x03\xE4W__\xFD[Pa\x03Oa\x03\xF36`\x04a*\xA0V[a\x0C(V[4\x80\x15a\x04\x03W__\xFD[Pa\x04\x0Ca\x0F\x13V[`@Q\x90\x81R` \x01a\x02MV[4\x80\x15a\x04%W__\xFD[Pa\x03O`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04EW__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04xW__\xFD[Pa\x02ua\x0F\xC4V[4\x80\x15a\x04\x8CW__\xFD[Pa\x02ua\x0F\xD5V[4\x80\x15a\x04\xA0W__\xFD[Pa\x02ua\x10LV[4\x80\x15a\x04\xB4W__\xFD[Pa\x029a\x10\xA1V[4\x80\x15a\x04\xC8W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x029V[4\x80\x15a\x04\xE5W__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Rb\x01Q\x80\x80\x82R\x90\x82\x01\x81\x81R\x83Q\x91\x82RQ\x91\x81\x01\x91\x90\x91R\x01a\x02MV[4\x80\x15a\x05+W__\xFD[Pa\x05\x85a\x05:6`\x04a(\xDDV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01RP_\x90\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x84R`\x01`0\x1B\x90\x91\x04\x16\x90\x82\x01R\x90V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x93\x84\x01Q\x16\x92\x81\x01\x92\x90\x92R\x01a\x02MV[4\x80\x15a\x05\xB6W__\xFD[Pa\x04\x0Ca\x01\xF7\x81V[4\x80\x15a\x05\xCBW__\xFD[Pa\x05\xFFa\x05\xDA6`\x04a(\xDDV[`\xFB` R_\x90\x81R`@\x90 Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x90`\x01`0\x1B\x90\x04`0\x1B\x82V[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x83Re\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16` \x83\x01R\x01a\x02MV[4\x80\x15a\x060W__\xFD[Pa\x06Da\x06?6`\x04a*\xFDV[a\x10\xAFV[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x91\x16\x81R` \x01a\x02MV[4\x80\x15a\x06gW__\xFD[Pa\x06{a\x06v6`\x04a+DV[a\x10\xC5V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x91\x16\x81R` \x01a\x02MV[4\x80\x15a\x06\x9DW__\xFD[Pa\x06Da\x06\xAC6`\x04a(\xDDV[a\x11\xE9V[4\x80\x15a\x06\xBCW__\xFD[Pa\x06\xD0a\x06\xCB6`\x04a+{V[a\x12=V[`@Qa\x02M\x91\x90a,\x18V[4\x80\x15a\x06\xE8W__\xFD[Pa\x02ua\x06\xF76`\x04a(\xDDV[a\x12\x99V[4\x80\x15a\x07\x07W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x07:W__\xFD[Pa\x07Na\x07I6`\x04a*\xFDV[a\x13\xDEV[`@Qa\x02M\x91\x90a,*V[4\x80\x15a\x07fW__\xFD[Pa\x02ua\x07u6`\x04a)QV[a\x14\x96V[4\x80\x15a\x07\x85W__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x029V[4\x80\x15a\x07\xA2W__\xFD[Pa\x02ua\x07\xB16`\x04a,yV[a\x14\xF0V[4\x80\x15a\x07\xC1W__\xFD[Pa\x02ua\x07\xD06`\x04a)QV[a\x16\x1AV[4\x80\x15a\x07\xE0W__\xFD[Pa\x029\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x08\x13W__\xFD[Pa\x03Oa\x08\"6`\x04a(\xDDV[_\x90\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x92\x90\x91\x01\x82\x90R\x11\x90V[a\x01-T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x08\x8AW`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11\x15a\x08\xE0W`@Qc\x19\x96Gk`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x90\x82\x01RQ` \x82\x01Qa\t\x1E\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a,\xB9V[B\x11a\t=W`@Qc\xA2\x82\x93\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16Be\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x1A\x87\x8B+\xF8h\x0C\x02\xF7\xD7\x9C\x19\x9Aa\xAD\xBE\x87D\xE8\xCC\xB0\xF1~6\"\x9Ba\x931\xFA.\x13\x91\x01[`@Q\x80\x91\x03\x90\xA2PPV[a\t\xA8a(\x81V[_a\t\xB5`\x0C` a,\xCCV[a\t\xBF\x90\x85a,\xB9V[\x90Pa\t\xCC\x83\x85\x83a\x16\x8BV[\x94\x93PPPPV[__a\t\xDF_a\x18\\V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P\x80B\x03a\t\xF7W_\x91PP\x90V[_a\n\x04`\x0C` a,\xCCV[a\n\x0E\x90\x83a,\xB9V[\x90P\x80a\n\x1A\x82a\x18\xE0V[Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x15\x93\x92PPPV[_`\x02a\n;`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\x95W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a,\xE3V[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\n\xC7a\x19\x04V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\n\xEDW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a-/V[a\n\xF6\x81a\x19\x1FV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x0B\x11\x91\x83\x91\x90a\x19'V[PV[a\x0B\x1Ca\x1A\x91V[a\x0B0`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0Bm3_a\x1A\xC2V[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x0B\xB7W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a,\xE3V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0B\xE9a\x19\x04V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0C\x0FW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a-/V[a\x0C\x18\x82a\x19\x1FV[a\x0C$\x82\x82`\x01a\x19'V[PPV[`@Qc$\xD9\x12{`\xE2\x1B\x81R`\x04\x81\x01\x83\x90R_\x90\x81\x90`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\x93dI\xEC\x90`$\x01a\x01\0`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0C\x90W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0C\xB4\x91\x90a-\xE0V[\x90P\x80``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x80a\x0C\xDBWP\x82\x81``\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[\x15a\x0C\xE9W_\x91PPa\x0F\rV[`\x80\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\r\x0FWP\x82\x81`\x80\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\r\x1DW_\x91PPa\x0F\rV[`@Qc-\x0CX\xC9`\xE1\x1B\x81R`\x04\x81\x01\x85\x90R`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81\x16`$\x83\x01R_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90cZ\x18\xB1\x92\x90`D\x01`\x80`@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\r\xACW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\r\xD0\x91\x90a.\x86V[\x90P\x80` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16_\x14\x80a\r\xF7WP\x83\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11[\x15a\x0E\x06W_\x92PPPa\x0F\rV[`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0E,WP\x83\x81`@\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\x0E;W_\x92PPPa\x0F\rV[_\x85\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x91\x90\x91R\x15\x80\x15\x90a\x0E\x89WP\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x85\x11[\x15a\x0E\xCFW\x80_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x80a\x0E\xBFWP\x84\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x15[\x15a\x0E\xCFW_\x93PPPPa\x0F\rV[`\xA0\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80\x15\x90a\x0E\xF5WP\x84\x83`\xA0\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10[\x15a\x0F\x05W_\x93PPPPa\x0F\rV[`\x01\x93PPPP[\x92\x91PPV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0F\xB2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\n\x8CV[P_Q` a0\x96_9_Q\x90_R\x90V[a\x0F\xCCa\x1A\xC6V[a\x0Bm_a\x1B V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x10CW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\n\x8CV[a\x0B\x11\x81a\x1B V[a\x10Ta\x1B9V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x0Bm3`\x01a\x1A\xC2V[_a\x10\xAAa\x19\x04V[\x90P\x90V[_a\x10\xBB\x84\x84\x84a\x1BkV[\x90P[\x93\x92PPPV[_3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x11\x0FW`@Qcr\x10\x9Fw`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x83\x01_a\x11\x1Ca\x1B\x89V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90P_a\x113`\x0C` a,\xCCV[a\x11=\x90\x83a,\xB9V[\x90P_a\x11K\x84\x84\x84a\x16\x8BV[\x90P\x80` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x88`\x01`\x01`\xA0\x1B\x03\x16\x14a\x11\x83W`@Qc@\x9B2\x0F`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80`@\x01QB\x10\x15\x80\x15a\x11\x9BWP\x80``\x01QB\x11\x15[a\x11\xB8W`@QcE\xCB\n\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x11\xCE\x83a\x11\xC9` \x87\x01\x87a.\xEBV[a\x1B\x93V[a\x11\xDA\x83\x83\x83\x87a\x1B\xE4V[``\x01Q\x97\x96PPPPPPPV[__a\x11\xF4\x83a\x18\xE0V[`@\x80Q\x80\x82\x01\x90\x91R\x90Te\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x80\x83R`\x01`0\x1B\x90\x91\x04`0\x1Be\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16` \x83\x01R\x90\x91P\x83\x90\x03a\x127W\x80` \x01Q\x91P[P\x91\x90PV[``a\x10\xBE\x83\x83\x80\x80` \x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01_\x90[\x82\x82\x10\x15a\x12\x8FWa\x12\x80`\x80\x83\x02\x86\x016\x81\x90\x03\x81\x01\x90a/-V[\x81R` \x01\x90`\x01\x01\x90a\x12cV[PPPPPa\x1CCV[a\x01-T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x12\xC5W`@Qc\xAC\x9D\x87\xCD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x82Q\x80\x84\x01\x90\x93RTe\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x85R`\x01`0\x1B\x90\x92\x04\x16\x91\x83\x01\x82\x90R\x11a\x13\x1AW`@Qc\x0E\xC1\x12y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x90\x92Rb\x01Q\x80\x80\x83R\x91\x01\x81\x90R\x81Qa\x13U\x91\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16a,\xB9V[B\x11a\x13tW`@Qc\x99\xD3\xFA\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82\x81Ra\x01.` \x90\x81R`@\x91\x82\x90 \x80Tk\xFF\xFF\xFF\xFF\xFF\xFF\0\0\0\0\0\0\x19\x16`\x01`0\x1BBe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x81\x02\x91\x90\x91\x17\x90\x91U\x91Q\x91\x82R\x83\x91\x7F\x96\x82\xAE?\xB7\x9C\x10\x94\x81\x16\xFE*\"L\xCA\x90%\xFBvqdw\xD7\x13\xDF\xECvm\x8B\xCC\xEE\x17\x91\x01a\t\x94V[a\x14\x12`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01``\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90V[`@Q\x80``\x01`@R\x80_`\x01`\x01`@\x1B\x03\x16\x81R` \x01a\x147\x86\x86\x86a\x10\xAFV[`@\x80Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x92\x16` \x83\x01R\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x81R` \x01\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16\x81RP\x90P\x93\x92PPPV[a\x14\x9Ea\x1A\xC6V[a\x01-\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\xF5d\n\xD8\xA7J`f\xC7\xF3\xBC\x15\x97m\x1D\x80\xBD\xE5\x1D\xBB\xC9\xD9\xCD\x87]\x9Ce\x82\xB5\xA7\x0E=\x90_\x90\xA3PPV[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x15\x0EWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x15'WP0;\x15\x80\x15a\x15'WP_T`\xFF\x16`\x01\x14[a\x15\x8AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x15\xABW_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[a\x15\xB4\x83a\x1DmV[a\x01-\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x84\x16\x17\x90U\x80\x15a\x16\x15W_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPPV[a\x16\"a\x1A\xC6V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x16S`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\x16\x93a(\x81V[a\x16\xA0` \x85\x01\x85a.\xEBV[\x90P_\x03a\x16\xB9Wa\x16\xB2\x83\x83a\x1D\xCBV[\x90Pa\x16\xD9V[`\x01\x845\x01a\x16\xCCWa\x16\xB2\x84\x83a\x1D\xF4V[a\x16\xD6\x84\x84a\x1E\xBEV[\x90P[\x80Q\x15a\x17sW\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c4?\nh`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x17<W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x17`\x91\x90a/\x8DV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01Ra\x10\xBEV[a\x17\x85\x81`\x80\x01Q``\x01QBa\x0C(V[a\x18AW`\x01\x81R`@\x80Qc\x06\x87\xE1M`\xE3\x1B\x81R\x90Q`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x91c4?\nh\x91`\x04\x80\x83\x01\x92` \x92\x91\x90\x82\x90\x03\x01\x81\x86Z\xFA\x15\x80\x15a\x17\xF0W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x18\x14\x91\x90a/\x8DV[`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R`\x01\x845\x01a\x18<Wa\x186`\x0C\x83a/\xA8V[``\x82\x01R[a\x10\xBEV[`\x80\x81\x01QQ`\x01`\x01`\xA0\x1B\x03\x16` \x82\x01R\x93\x92PPPV[__a\x18gFa\x1F\x87V[\x90P_a\x18t\x82Ba/\xA8V[\x90P_a\x18\x83`\x0C` a,\xCCV[a\x18\x8F`\x0C` a,\xCCV[a\x18\x99\x90\x84a/\xCFV[a\x18\xA3\x91\x90a,\xCCV[\x90Pa\x18\xD7a\x18\xB4`\x0C` a,\xCCV[a\x18\xBE\x90\x87a,\xCCV[a\x18\xC8\x83\x86a,\xB9V[a\x18\xD2\x91\x90a,\xB9V[a\x1F\xE2V[\x95\x94PPPPPV[_`\xFB\x81a\x18\xF0a\x01\xF7\x85a/\xE2V[\x81R` \x01\x90\x81R` \x01_ \x90P\x91\x90PV[_Q` a0\x96_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x0B\x11a\x1A\xC6V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x19ZWa\x16\x15\x83a LV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x19\xB4WP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x19\xB1\x91\x81\x01\x90a/\xF5V[`\x01[a\x1A\x17W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_Q` a0\x96_9_Q\x90_R\x81\x14a\x1A\x85W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\n\x8CV[Pa\x16\x15\x83\x83\x83a \xE7V[a\x1A\xA5`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x0BmW`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0C$[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x0BmW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\n\x8CV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x0B\x11\x81a!\x0BV[a\x1BM`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x0BmW`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`@Q\x84\x81R\x82\x84` \x83\x017` \x83\x01\x81 \x91PP\x93\x92PPPV[_a\x10\xAA_a\x18\\V[_a\x1B\x9D\x84a\x11\xE9V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1B\xBFWa\x1B\xBA\x84\x84\x84\x84a!\\V[a\x1B\xDEV[\x81\x15a\x1B\xDEW`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPPPV[_a\x1B\xEE\x84a\x11\xE9V[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x81\x16\x15a\x1C*W\x815_\x19\x14a\x1C\x0EWPa\x1B\xDEV[a\x1C%\x84a\x1C\x1F`@\x85\x01\x85a.\xEBV[\x84a!\\V[a\x1C<V[\x84B\x14a\x1C<Wa\x1C<\x84\x84\x84a!\x96V[PPPPPV[```<\x82Qa\x1CS\x91\x90a,\xCCV[`\x01`\x01`@\x1B\x03\x81\x11\x15a\x1CjWa\x1Cja)lV[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x1C\x94W` \x82\x01\x81\x806\x837\x01\x90P[P\x90P` \x81\x01_[\x83Q\x81\x10\x15a\x1DfWa\x1C\xD2\x82\x85\x83\x81Q\x81\x10a\x1C\xBCWa\x1C\xBCa0\x0CV[` \x02` \x01\x01Q_\x01Q``\x1B\x81R`\x14\x01\x90V[\x91Pa\x1D\x01\x82\x85\x83\x81Q\x81\x10a\x1C\xEAWa\x1C\xEAa0\x0CV[` \x02` \x01\x01Q` \x01Q`\xD0\x1B\x81R`\x06\x01\x90V[\x91Pa\x1D0\x82\x85\x83\x81Q\x81\x10a\x1D\x19Wa\x1D\x19a0\x0CV[` \x02` \x01\x01Q`@\x01Q`\xF0\x1B\x81R`\x02\x01\x90V[\x91Pa\x1D\\\x82\x85\x83\x81Q\x81\x10a\x1DHWa\x1DHa0\x0CV[` \x02` \x01\x01Q``\x01Q\x81R` \x01\x90V[\x91P`\x01\x01a\x1C\x9DV[PP\x91\x90PV[_Ta\x01\0\x90\x04`\xFF\x16a\x1D\x93W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a0 V[a\x1D\x9Ba\"\xA7V[a\x1D\xB9`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\x1D\xB3W\x81a\x1B V[3a\x1B V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[a\x1D\xD3a(\x81V[`\x01\x81R`@\x81\x01\x83\x90Ra\x1D\xE9`\x0C\x83a/\xA8V[``\x82\x01R\x92\x91PPV[a\x1D\xFCa(\x81V[_a\x1E3a\x1E\r` \x86\x01\x86a.\xEBV[`\x01a\x1E$a\x1E\x1F` \x8A\x01\x8Aa.\xEBV[a\"\xCDV[a\x1E.\x91\x90a/\xA8V[a\"\xD9V[\x90P`\x0C\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x1EN\x91\x90a/\xA8V[`@\x80\x84\x01\x91\x90\x91Ra\x1Ec\x90\x85\x01\x85a.\xEBV[\x90P_\x03a\x1E\x84W`\x01\x82Ra\x1Ez`\x0C\x84a/\xA8V[``\x83\x01Ra\x1E\xB7V[_a\x1E\x9Ba\x1E\x95`@\x87\x01\x87a.\xEBV[_a\"\xD9V[_\x84R` \x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x85\x01R`\x80\x84\x01RP[P\x92\x91PPV[a\x1E\xC6a(\x81V[_a\x1E\xDEa\x1E\xD7` \x86\x01\x86a.\xEBV[\x865a\"\xD9V[_\x80\x84R`\x80\x84\x01\x82\x90R` \x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x85\x01R\x90\x91P\x845\x90\x03a\x1F\x12W`@\x82\x01\x83\x90Ra\x1E\xB7V[a\x1F\"a\x1E\x1F` \x86\x01\x86a.\xEBV[\x845\x10a\x1FBW`@Qc6(\xA8\x1B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1F_a\x1FS` \x87\x01\x87a.\xEBV[a\x1E.`\x01\x895a/\xA8V[\x90P`\x0C\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x1Fz\x91\x90a/\xA8V[`@\x84\x01RPP\x92\x91PPV[_`\x01\x82\x03a\x1F\x9BWPc_\xC60W\x91\x90PV[aBh\x82\x03a\x1F\xAFWPce\x15j\xC0\x91\x90PV[d\x01\xA2\x14\x0C\xFF\x82\x03a\x1F\xC6WPcfu]l\x91\x90PV[b\x08\x8B\xB0\x82\x03a\x1F\xDBWPcg\xD8\x11\x18\x91\x90PV[P_\x91\x90PV[_e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x11\x15a HW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FSafeCast: value doesn't fit in 4`D\x82\x01Re8 bits`\xD0\x1B`d\x82\x01R`\x84\x01a\n\x8CV[P\x90V[`\x01`\x01`\xA0\x1B\x03\x81\x16;a \xB9W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_Q` a0\x96_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a \xF0\x83a#GV[_\x82Q\x11\x80a \xFCWP\x80[\x15a\x16\x15Wa\x1B\xDE\x83\x83a#\x86V[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a!h\x85\x85\x85a\x10\xAFV[\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x81\x16\x90\x82\x16\x14a\x1C<W`@Qc\xEA\xF8*%`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a!\xA3``\x82\x01\x82a.\xEBV[\x90P_\x03a!\xCFW\x81Qa!\xCAW`@Qc\x04vw\xF5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\"\x91V[_a!\xE1\x84a\x07I`@\x85\x01\x85a.\xEBV[\x90P_a\"V\x82`@Q` \x01a!\xF8\x91\x90a,*V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x80Q` \x90\x91\x01 a\"\x1D``\x86\x01\x86a.\xEBV[\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa#\xAB\x92PPPV[\x90P\x83` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x81`\x01`\x01`\xA0\x1B\x03\x16\x14a\"\x8EW`@Qc\x15}\xF6\xA5`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PP[a\x1B\xDE\x83a\"\xA2`@\x84\x01\x84a.\xEBV[a#\xCDV[_Ta\x01\0\x90\x04`\xFF\x16a\x0BmW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x90a0 V[_a\x10\xBE`<\x83a/\xCFV[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x83a#\x08`<\x84a,\xCCV[a#\x12\x90\x82a,\xB9V[\x805``\x90\x81\x1C\x84R`\x14\x82\x015`\xD0\x1C` \x85\x01R`\x1A\x82\x015`\xF0\x1C`@\x85\x01R`\x1C\x90\x91\x015\x90\x83\x01RP\x93\x92PPPV[a#P\x81a LV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x10\xBE\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a0\xB6`'\x919a$\xFAV[___a#\xB8\x85\x85a%nV[\x91P\x91Pa#\xC5\x81a%\xB0V[P\x93\x92PPPV[_`\x0B\x19\x84\x01\x81a#\xDE\x85\x85a\"\xCDV[\x90P_[\x81\x81\x10\x15a$wW_a#\xF6\x87\x87\x84a\"\xD9V[\x90P\x83\x81` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11a$$W`@Qc\\\x03\x14\x1B`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x0C\x88\x82` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x03\x81a$BWa$Ba/\xBBV[\x06\x15a$aW`@Qc\x97\x1C\xCE\x8F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x92P`\x01\x01a#\xE2V[Pa\x01\x80\x86\x01\x82\x10a$\x9CW`@Qc\x96\xAC\xE7\x9B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PPa$\xA9\x84\x84\x84a\x10\xAFV[\x90Pa$\xB5\x84\x82a&\xF9V[`@Qe\xFF\xFF\xFF\xFF\xFF\xFF\x19\x82\x16\x81R\x84\x90\x7F\xF4\xB5[\x85lX;\x95/\x0C\rB\x06|\x8Ec\xC9\xFA\xE3\x952)\x05\xD4^U\xAF\x1D\x0F\tY\x94\x90` \x01`@Q\x80\x91\x03\x90\xA2\x93\x92PPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa%\x16\x91\x90a0kV[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a%NW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a%SV[``\x91P[P\x91P\x91Pa%d\x86\x83\x83\x87a'\"V[\x96\x95PPPPPPV[__\x82Q`A\x03a%\xA2W` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa%\x96\x87\x82\x85\x85a'\x9AV[\x94P\x94PPPPa%\xA9V[P_\x90P`\x02[\x92P\x92\x90PV[_\x81`\x04\x81\x11\x15a%\xC3Wa%\xC3a0\x81V[\x03a%\xCBWPV[`\x01\x81`\x04\x81\x11\x15a%\xDFWa%\xDFa0\x81V[\x03a&,W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x18`$\x82\x01R\x7FECDSA: invalid signature\0\0\0\0\0\0\0\0`D\x82\x01R`d\x01a\n\x8CV[`\x02\x81`\x04\x81\x11\x15a&@Wa&@a0\x81V[\x03a&\x8DW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FECDSA: invalid signature length\0`D\x82\x01R`d\x01a\n\x8CV[`\x03\x81`\x04\x81\x11\x15a&\xA1Wa&\xA1a0\x81V[\x03a\x0B\x11W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\"`$\x82\x01R\x7FECDSA: invalid signature 's' val`D\x82\x01Raue`\xF0\x1B`d\x82\x01R`\x84\x01a\n\x8CV[_a'\x03\x83a\x18\xE0V[`0\x92\x90\x92\x1C`\x01`0\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x93\x16\x92\x90\x92\x17\x90UPV[``\x83\x15a'\x90W\x82Q_\x03a'\x89W`\x01`\x01`\xA0\x1B\x03\x85\x16;a'\x89W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\n\x8CV[P\x81a\t\xCCV[a\t\xCC\x83\x83a(WV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a'\xCFWP_\x90P`\x03a(NV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a( W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a(HW_`\x01\x92P\x92PPa(NV[\x91P_\x90P[\x94P\x94\x92PPPV[\x81Q\x15a(gW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\n\x8C\x91\x90a,\x18V[`@Q\x80`\xA0\x01`@R\x80_\x15\x15\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_\x81R` \x01_\x81R` \x01a(\xD8`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91R\x90V[\x90R\x90V[_` \x82\x84\x03\x12\x15a(\xEDW__\xFD[P5\x91\x90PV[__`@\x83\x85\x03\x12\x15a)\x05W__\xFD[\x825\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a)!W__\xFD[\x83\x01`\x80\x81\x86\x03\x12\x15a)2W__\xFD[\x80\x91PP\x92P\x92\x90PV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0B\x11W__\xFD[_` \x82\x84\x03\x12\x15a)aW__\xFD[\x815a\x10\xBE\x81a)=V[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Qa\x01\0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xA3Wa)\xA3a)lV[`@R\x90V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xA3Wa)\xA3a)lV[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a)\xF3Wa)\xF3a)lV[`@R\x91\x90PV[__`@\x83\x85\x03\x12\x15a*\x0CW__\xFD[\x825a*\x17\x81a)=V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a*1W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a*AW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a*ZWa*Za)lV[a*m`\x1F\x82\x01`\x1F\x19\x16` \x01a)\xCBV[\x81\x81R\x86` \x83\x85\x01\x01\x11\x15a*\x81W__\xFD[\x81` \x84\x01` \x83\x017_` \x83\x83\x01\x01R\x80\x93PPPP\x92P\x92\x90PV[__`@\x83\x85\x03\x12\x15a*\xB1W__\xFD[PP\x805\x92` \x90\x91\x015\x91PV[__\x83`\x1F\x84\x01\x12a*\xD0W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a*\xE6W__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a%\xA9W__\xFD[___`@\x84\x86\x03\x12\x15a+\x0FW__\xFD[\x835\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a++W__\xFD[a+7\x86\x82\x87\x01a*\xC0V[\x94\x97\x90\x96P\x93\x94PPPPV[___`@\x84\x86\x03\x12\x15a+VW__\xFD[\x835a+a\x81a)=V[\x92P` \x84\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a++W__\xFD[__` \x83\x85\x03\x12\x15a+\x8CW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xA1W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a+\xB1W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a+\xC6W__\xFD[\x85` \x82`\x07\x1B\x84\x01\x01\x11\x15a+\xDAW__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_\x81Q\x80\x84R\x80` \x84\x01` \x86\x01^_` \x82\x86\x01\x01R` `\x1F\x19`\x1F\x83\x01\x16\x85\x01\x01\x91PP\x92\x91PPV[` \x81R_a\x10\xBE` \x83\x01\x84a+\xEAV[` \x81R`\x01`\x01`@\x1B\x03\x82Q\x16` \x82\x01R_` \x83\x01Q```@\x84\x01Ra,X`\x80\x84\x01\x82a+\xEAV[`@\x94\x90\x94\x01Q`\x01`\x01`\xA0\x1B\x03\x16``\x93\x90\x93\x01\x92\x90\x92RP\x90\x91\x90PV[__`@\x83\x85\x03\x12\x15a,\x8AW__\xFD[\x825a,\x95\x81a)=V[\x91P` \x83\x015a)2\x81a)=V[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x0F\rWa\x0F\ra,\xA5V[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x0F\rWa\x0F\ra,\xA5V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[\x80Qi\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a-\x94W__\xFD[\x91\x90PV[a\xFF\xFF\x81\x16\x81\x14a\x0B\x11W__\xFD[\x80Qa-\x94\x81a-\x99V[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0B\x11W__\xFD[\x80Qa-\x94\x81a-\xB3V[\x80Q\x80\x15\x15\x81\x14a-\x94W__\xFD[_a\x01\0\x82\x84\x03\x12\x80\x15a-\xF2W__\xFD[Pa-\xFBa)\x80V[\x82Qa.\x06\x81a)=V[\x81Ra.\x14` \x84\x01a-{V[` \x82\x01Ra.%`@\x84\x01a-\xA8V[`@\x82\x01Ra.6``\x84\x01a-\xC6V[``\x82\x01Ra.G`\x80\x84\x01a-\xC6V[`\x80\x82\x01Ra.X`\xA0\x84\x01a-\xC6V[`\xA0\x82\x01Ra.i`\xC0\x84\x01a-\xD1V[`\xC0\x82\x01Ra.z`\xE0\x84\x01a-\xD1V[`\xE0\x82\x01R\x93\x92PPPV[_`\x80\x82\x84\x03\x12\x80\x15a.\x97W__\xFD[Pa.\xA0a)\xA9V[\x82Qa.\xAB\x81a)=V[\x81R` \x83\x01Qa.\xBB\x81a-\xB3V[` \x82\x01R`@\x83\x01Qa.\xCE\x81a-\xB3V[`@\x82\x01Ra.\xDF``\x84\x01a-\xD1V[``\x82\x01R\x93\x92PPPV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a/\0W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a/\x19W__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a%\xA9W__\xFD[_`\x80\x82\x84\x03\x12\x80\x15a/>W__\xFD[Pa/Ga)\xA9V[\x825a/R\x81a)=V[\x81R` \x83\x015a/b\x81a-\xB3V[` \x82\x01R`@\x83\x015a/u\x81a-\x99V[`@\x82\x01R``\x92\x83\x015\x92\x81\x01\x92\x90\x92RP\x91\x90PV[_` \x82\x84\x03\x12\x15a/\x9DW__\xFD[\x81Qa\x10\xBE\x81a)=V[\x81\x81\x03\x81\x81\x11\x15a\x0F\rWa\x0F\ra,\xA5V[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_\x82a/\xDDWa/\xDDa/\xBBV[P\x04\x90V[_\x82a/\xF0Wa/\xF0a/\xBBV[P\x06\x90V[_` \x82\x84\x03\x12\x15a0\x05W__\xFD[PQ\x91\x90PV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \xBC2\x08\xE8\x9D\xB4y9Ca\xBF\x8F\xC0G\xBB\x9B\0\x0FUQ\xA5\xC6\xAF\x87Q\x9C\xEE\xFF\xCB\xD5\xE9\x13dsolcC\0\x08\x1E\x003",
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
        #[allow(dead_code)]
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
    /**Event with signature `LookaheadPosted(uint256,bytes26)` and selector `0xf4b55b856c583b952f0c0d42067c8e63c9fae395322905d45e55af1d0f095994`.
```solidity
event LookaheadPosted(uint256 indexed epochTimestamp, bytes26 lookaheadHash);
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for LookaheadPosted {
            type DataTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<256>,
            );
            const SIGNATURE: &'static str = "LookaheadPosted(uint256,bytes26)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                244u8, 181u8, 91u8, 133u8, 108u8, 88u8, 59u8, 149u8, 47u8, 12u8, 13u8,
                66u8, 6u8, 124u8, 142u8, 99u8, 201u8, 250u8, 227u8, 149u8, 50u8, 41u8,
                5u8, 212u8, 94u8, 85u8, 175u8, 29u8, 15u8, 9u8, 89u8, 148u8,
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
                        26,
                    > as alloy_sol_types::SolType>::tokenize(&self.lookaheadHash),
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
    /**Event with signature `OverseerSet(address,address)` and selector `0xf5640ad8a74a6066c7f3bc15976d1d80bde51dbbc9d9cd875d9c6582b5a70e3d`.
```solidity
event OverseerSet(address indexed oldOverseer, address indexed newOverseer);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct OverseerSet {
        #[allow(missing_docs)]
        pub oldOverseer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub newOverseer: alloy::sol_types::private::Address,
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
        impl alloy_sol_types::SolEvent for OverseerSet {
            type DataTuple<'a> = ();
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            const SIGNATURE: &'static str = "OverseerSet(address,address)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                245u8, 100u8, 10u8, 216u8, 167u8, 74u8, 96u8, 102u8, 199u8, 243u8, 188u8,
                21u8, 151u8, 109u8, 29u8, 128u8, 189u8, 229u8, 29u8, 187u8, 201u8, 217u8,
                205u8, 135u8, 93u8, 156u8, 101u8, 130u8, 181u8, 167u8, 14u8, 61u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    oldOverseer: topics.1,
                    newOverseer: topics.2,
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
                    self.oldOverseer.clone(),
                    self.newOverseer.clone(),
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
                    &self.oldOverseer,
                );
                out[2usize] = <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic(
                    &self.newOverseer,
                );
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for OverseerSet {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&OverseerSet> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &OverseerSet) -> alloy_sol_types::private::LogData {
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
constructor(address _inbox, address _preconfSlasherL1, address _preconfWhitelist, address _urc);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct constructorCall {
        #[allow(missing_docs)]
        pub _inbox: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _preconfSlasherL1: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _preconfWhitelist: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _urc: alloy::sol_types::private::Address,
    }
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
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
            impl ::core::convert::From<constructorCall> for UnderlyingRustTuple<'_> {
                fn from(value: constructorCall) -> Self {
                    (
                        value._inbox,
                        value._preconfSlasherL1,
                        value._preconfWhitelist,
                        value._urc,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for constructorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _inbox: tuple.0,
                        _preconfSlasherL1: tuple.1,
                        _preconfWhitelist: tuple.2,
                        _urc: tuple.3,
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
                        &self._inbox,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._preconfSlasherL1,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._preconfWhitelist,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._urc,
                    ),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `LOOKAHEAD_BUFFER_SIZE()` and selector `0xa2bf9dba`.
```solidity
function LOOKAHEAD_BUFFER_SIZE() external view returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LOOKAHEAD_BUFFER_SIZECall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`LOOKAHEAD_BUFFER_SIZE()`](LOOKAHEAD_BUFFER_SIZECall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LOOKAHEAD_BUFFER_SIZEReturn {
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
            #[allow(dead_code)]
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
            impl ::core::convert::From<LOOKAHEAD_BUFFER_SIZECall>
            for UnderlyingRustTuple<'_> {
                fn from(value: LOOKAHEAD_BUFFER_SIZECall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for LOOKAHEAD_BUFFER_SIZECall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<LOOKAHEAD_BUFFER_SIZEReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: LOOKAHEAD_BUFFER_SIZEReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for LOOKAHEAD_BUFFER_SIZEReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for LOOKAHEAD_BUFFER_SIZECall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "LOOKAHEAD_BUFFER_SIZE()";
            const SELECTOR: [u8; 4] = [162u8, 191u8, 157u8, 186u8];
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
                        let r: LOOKAHEAD_BUFFER_SIZEReturn = r.into();
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
                        let r: LOOKAHEAD_BUFFER_SIZEReturn = r.into();
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `buildLookaheadCommitment(uint256,bytes)` and selector `0xdfbb7407`.
```solidity
function buildLookaheadCommitment(uint256 _epochTimestamp, bytes memory _encodedLookahead) external view returns (ISlasher.Commitment memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct buildLookaheadCommitmentCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _encodedLookahead: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`buildLookaheadCommitment(uint256,bytes)`](buildLookaheadCommitmentCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct buildLookaheadCommitmentReturn {
        #[allow(missing_docs)]
        pub _0: <ISlasher::Commitment as alloy::sol_types::SolType>::RustType,
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<buildLookaheadCommitmentCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: buildLookaheadCommitmentCall) -> Self {
                    (value._epochTimestamp, value._encodedLookahead)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for buildLookaheadCommitmentCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _encodedLookahead: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (ISlasher::Commitment,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ISlasher::Commitment as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<buildLookaheadCommitmentReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: buildLookaheadCommitmentReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for buildLookaheadCommitmentReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for buildLookaheadCommitmentCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ISlasher::Commitment as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ISlasher::Commitment,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "buildLookaheadCommitment(uint256,bytes)";
            const SELECTOR: [u8; 4] = [223u8, 187u8, 116u8, 7u8];
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
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._encodedLookahead,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (<ISlasher::Commitment as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: buildLookaheadCommitmentReturn = r.into();
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
                        let r: buildLookaheadCommitmentReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `calculateLookaheadHash(uint256,bytes)` and selector `0xa6e04274`.
```solidity
function calculateLookaheadHash(uint256 _epochTimestamp, bytes memory _encodedLookahead) external pure returns (bytes26);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct calculateLookaheadHashCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _encodedLookahead: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`calculateLookaheadHash(uint256,bytes)`](calculateLookaheadHashCall) function.
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<calculateLookaheadHashCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: calculateLookaheadHashCall) -> Self {
                    (value._epochTimestamp, value._encodedLookahead)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for calculateLookaheadHashCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _encodedLookahead: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<26>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<26>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "calculateLookaheadHash(uint256,bytes)";
            const SELECTOR: [u8; 4] = [166u8, 224u8, 66u8, 116u8];
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
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._encodedLookahead,
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `encodeLookahead((address,uint48,uint16,bytes32)[])` and selector `0xc86dc3fd`.
```solidity
function encodeLookahead(ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots) external pure returns (bytes memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeLookaheadCall {
        #[allow(missing_docs)]
        pub _lookaheadSlots: alloy::sol_types::private::Vec<
            <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
        >,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`encodeLookahead((address,uint48,uint16,bytes32)[])`](encodeLookaheadCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct encodeLookaheadReturn {
        #[allow(missing_docs)]
        pub _0: alloy::sol_types::private::Bytes,
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Array<ILookaheadStore::LookaheadSlot>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
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
            impl ::core::convert::From<encodeLookaheadCall> for UnderlyingRustTuple<'_> {
                fn from(value: encodeLookaheadCall) -> Self {
                    (value._lookaheadSlots,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for encodeLookaheadCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _lookaheadSlots: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<encodeLookaheadReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: encodeLookaheadReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for encodeLookaheadReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for encodeLookaheadCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Array<ILookaheadStore::LookaheadSlot>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Bytes;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bytes,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "encodeLookahead((address,uint48,uint16,bytes32)[])";
            const SELECTOR: [u8; 4] = [200u8, 109u8, 195u8, 253u8];
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
                        ILookaheadStore::LookaheadSlot,
                    > as alloy_sol_types::SolType>::tokenize(&self._lookaheadSlots),
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
                        let r: encodeLookaheadReturn = r.into();
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
                        let r: encodeLookaheadReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getBlacklist(bytes32)` and selector `0x9fe786ab`.
```solidity
function getBlacklist(bytes32 _operatorRegistrationRoot) external view returns (ILookaheadStore.BlacklistTimestamps memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistCall {
        #[allow(missing_docs)]
        pub _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBlacklist(bytes32)`](getBlacklistCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlacklistReturn {
        #[allow(missing_docs)]
        pub _0: <ILookaheadStore::BlacklistTimestamps as alloy::sol_types::SolType>::RustType,
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
            #[allow(dead_code)]
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
                    (value._operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlacklistCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (ILookaheadStore::BlacklistTimestamps,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ILookaheadStore::BlacklistTimestamps as alloy::sol_types::SolType>::RustType,
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
            type Return = <ILookaheadStore::BlacklistTimestamps as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ILookaheadStore::BlacklistTimestamps,);
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
                        &self._operatorRegistrationRoot,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <ILookaheadStore::BlacklistTimestamps as alloy_sol_types::SolType>::tokenize(
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
function getBlacklistConfig() external pure returns (ILookaheadStore.BlacklistConfig memory);
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
        pub _0: <ILookaheadStore::BlacklistConfig as alloy::sol_types::SolType>::RustType,
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (ILookaheadStore::BlacklistConfig,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ILookaheadStore::BlacklistConfig as alloy::sol_types::SolType>::RustType,
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
            type Return = <ILookaheadStore::BlacklistConfig as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ILookaheadStore::BlacklistConfig,);
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
                    <ILookaheadStore::BlacklistConfig as alloy_sol_types::SolType>::tokenize(
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `getProposerContext(uint256,(uint256,bytes,bytes,bytes))` and selector `0x1d3f2b5e`.
```solidity
function getProposerContext(uint256 _epochTimestamp, ILookaheadStore.LookaheadData memory _data) external view returns (ILookaheadStore.ProposerContext memory context_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getProposerContextCall {
        #[allow(missing_docs)]
        pub _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _data: <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    ///Container type for the return parameters of the [`getProposerContext(uint256,(uint256,bytes,bytes,bytes))`](getProposerContextCall) function.
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<256>,
                ILookaheadStore::LookaheadData,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U256,
                <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
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
                    (value._epochTimestamp, value._data)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getProposerContextCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _epochTimestamp: tuple.0,
                        _data: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
                alloy::sol_types::sol_data::Uint<256>,
                ILookaheadStore::LookaheadData,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ILookaheadStore::ProposerContext as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ILookaheadStore::ProposerContext,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getProposerContext(uint256,(uint256,bytes,bytes,bytes))";
            const SELECTOR: [u8; 4] = [29u8, 63u8, 43u8, 94u8];
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
                    <ILookaheadStore::LookaheadData as alloy_sol_types::SolType>::tokenize(
                        &self._data,
                    ),
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `init(address,address)` and selector `0xf09a4016`.
```solidity
function init(address _owner, address _overseer) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct initCall {
        #[allow(missing_docs)]
        pub _owner: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _overseer: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`init(address,address)`](initCall) function.
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
            #[allow(dead_code)]
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
            impl ::core::convert::From<initCall> for UnderlyingRustTuple<'_> {
                fn from(value: initCall) -> Self {
                    (value._owner, value._overseer)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for initCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _owner: tuple.0,
                        _overseer: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
                alloy::sol_types::sol_data::Address,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = initReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "init(address,address)";
            const SELECTOR: [u8; 4] = [240u8, 154u8, 64u8, 22u8];
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._overseer,
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `isOperatorActive(bytes32,uint256)` and selector `0x513ae999`.
```solidity
function isOperatorActive(bytes32 _registrationRoot, uint256 _referenceTimestamp) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isOperatorActiveCall {
        #[allow(missing_docs)]
        pub _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _referenceTimestamp: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isOperatorActive(bytes32,uint256)`](isOperatorActiveCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isOperatorActiveReturn {
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
            #[allow(dead_code)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<256>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
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
            impl ::core::convert::From<isOperatorActiveCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: isOperatorActiveCall) -> Self {
                    (value._registrationRoot, value._referenceTimestamp)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isOperatorActiveCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _registrationRoot: tuple.0,
                        _referenceTimestamp: tuple.1,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<isOperatorActiveReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: isOperatorActiveReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isOperatorActiveReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isOperatorActiveCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isOperatorActive(bytes32,uint256)";
            const SELECTOR: [u8; 4] = [81u8, 58u8, 233u8, 153u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._registrationRoot),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._referenceTimestamp),
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
                        let r: isOperatorActiveReturn = r.into();
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
                        let r: isOperatorActiveReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isOperatorBlacklisted(bytes32)` and selector `0xfd40a5fe`.
```solidity
function isOperatorBlacklisted(bytes32 _operatorRegistrationRoot) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isOperatorBlacklistedCall {
        #[allow(missing_docs)]
        pub _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
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
            #[allow(dead_code)]
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
                    (value._operatorRegistrationRoot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isOperatorBlacklistedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _operatorRegistrationRoot: tuple.0,
                    }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
                        &self._operatorRegistrationRoot,
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `overseer()` and selector `0x4ba25656`.
```solidity
function overseer() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct overseerCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`overseer()`](overseerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct overseerReturn {
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
            #[allow(dead_code)]
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
            impl ::core::convert::From<overseerCall> for UnderlyingRustTuple<'_> {
                fn from(value: overseerCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for overseerCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<overseerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: overseerReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for overseerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for overseerCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "overseer()";
            const SELECTOR: [u8; 4] = [75u8, 162u8, 86u8, 86u8];
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
                        let r: overseerReturn = r.into();
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
                        let r: overseerReturn = r.into();
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `preconfSlasherL1()` and selector `0x0d9cead7`.
```solidity
function preconfSlasherL1() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfSlasherL1Call;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`preconfSlasherL1()`](preconfSlasherL1Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct preconfSlasherL1Return {
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
            #[allow(dead_code)]
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
            impl ::core::convert::From<preconfSlasherL1Call>
            for UnderlyingRustTuple<'_> {
                fn from(value: preconfSlasherL1Call) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for preconfSlasherL1Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<preconfSlasherL1Return>
            for UnderlyingRustTuple<'_> {
                fn from(value: preconfSlasherL1Return) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for preconfSlasherL1Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for preconfSlasherL1Call {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "preconfSlasherL1()";
            const SELECTOR: [u8; 4] = [13u8, 156u8, 234u8, 215u8];
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
                        let r: preconfSlasherL1Return = r.into();
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
                        let r: preconfSlasherL1Return = r.into();
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    /**Function with signature `setOverseer(address)` and selector `0xe2828f47`.
```solidity
function setOverseer(address _newOverseer) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct setOverseerCall {
        #[allow(missing_docs)]
        pub _newOverseer: alloy::sol_types::private::Address,
    }
    ///Container type for the return parameters of the [`setOverseer(address)`](setOverseerCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct setOverseerReturn {}
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
            #[allow(dead_code)]
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
            impl ::core::convert::From<setOverseerCall> for UnderlyingRustTuple<'_> {
                fn from(value: setOverseerCall) -> Self {
                    (value._newOverseer,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for setOverseerCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _newOverseer: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<setOverseerReturn> for UnderlyingRustTuple<'_> {
                fn from(value: setOverseerReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for setOverseerReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl setOverseerReturn {
            fn _tokenize(
                &self,
            ) -> <setOverseerCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for setOverseerCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Address,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = setOverseerReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "setOverseer(address)";
            const SELECTOR: [u8; 4] = [226u8, 130u8, 143u8, 71u8];
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
                        &self._newOverseer,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                setOverseerReturn::_tokenize(ret)
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
            #[allow(dead_code)]
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
    #[derive(Clone)]
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum LookaheadStoreCalls {
        #[allow(missing_docs)]
        LOOKAHEAD_BUFFER_SIZE(LOOKAHEAD_BUFFER_SIZECall),
        #[allow(missing_docs)]
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        blacklistOperator(blacklistOperatorCall),
        #[allow(missing_docs)]
        buildLookaheadCommitment(buildLookaheadCommitmentCall),
        #[allow(missing_docs)]
        calculateLookaheadHash(calculateLookaheadHashCall),
        #[allow(missing_docs)]
        checkProposer(checkProposerCall),
        #[allow(missing_docs)]
        encodeLookahead(encodeLookaheadCall),
        #[allow(missing_docs)]
        getBlacklist(getBlacklistCall),
        #[allow(missing_docs)]
        getBlacklistConfig(getBlacklistConfigCall),
        #[allow(missing_docs)]
        getLookaheadHash(getLookaheadHashCall),
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
        isLookaheadRequired(isLookaheadRequiredCall),
        #[allow(missing_docs)]
        isOperatorActive(isOperatorActiveCall),
        #[allow(missing_docs)]
        isOperatorBlacklisted(isOperatorBlacklistedCall),
        #[allow(missing_docs)]
        lookahead(lookaheadCall),
        #[allow(missing_docs)]
        overseer(overseerCall),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pause(pauseCall),
        #[allow(missing_docs)]
        paused(pausedCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        preconfSlasherL1(preconfSlasherL1Call),
        #[allow(missing_docs)]
        preconfWhitelist(preconfWhitelistCall),
        #[allow(missing_docs)]
        proxiableUUID(proxiableUUIDCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        resolver(resolverCall),
        #[allow(missing_docs)]
        setOverseer(setOverseerCall),
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
            [13u8, 156u8, 234u8, 215u8],
            [29u8, 63u8, 43u8, 94u8],
            [35u8, 192u8, 177u8, 171u8],
            [48u8, 117u8, 219u8, 86u8],
            [54u8, 89u8, 207u8, 230u8],
            [63u8, 75u8, 168u8, 58u8],
            [75u8, 162u8, 86u8, 86u8],
            [79u8, 30u8, 242u8, 134u8],
            [81u8, 58u8, 233u8, 153u8],
            [82u8, 209u8, 144u8, 45u8],
            [92u8, 151u8, 90u8, 187u8],
            [93u8, 220u8, 158u8, 141u8],
            [113u8, 80u8, 24u8, 166u8],
            [121u8, 186u8, 80u8, 151u8],
            [132u8, 86u8, 203u8, 89u8],
            [138u8, 191u8, 96u8, 119u8],
            [141u8, 165u8, 203u8, 91u8],
            [147u8, 122u8, 170u8, 155u8],
            [159u8, 231u8, 134u8, 171u8],
            [162u8, 191u8, 157u8, 186u8],
            [164u8, 134u8, 224u8, 221u8],
            [166u8, 224u8, 66u8, 116u8],
            [172u8, 0u8, 4u8, 218u8],
            [174u8, 65u8, 80u8, 26u8],
            [200u8, 109u8, 195u8, 253u8],
            [204u8, 128u8, 153u8, 144u8],
            [217u8, 31u8, 36u8, 241u8],
            [223u8, 187u8, 116u8, 7u8],
            [226u8, 130u8, 143u8, 71u8],
            [227u8, 12u8, 57u8, 120u8],
            [240u8, 154u8, 64u8, 22u8],
            [242u8, 253u8, 227u8, 139u8],
            [251u8, 14u8, 114u8, 43u8],
            [253u8, 64u8, 165u8, 254u8],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(resolver),
            ::core::stringify!(blacklistOperator),
            ::core::stringify!(preconfSlasherL1),
            ::core::stringify!(getProposerContext),
            ::core::stringify!(isLookaheadRequired),
            ::core::stringify!(inNonReentrant),
            ::core::stringify!(upgradeTo),
            ::core::stringify!(unpause),
            ::core::stringify!(overseer),
            ::core::stringify!(upgradeToAndCall),
            ::core::stringify!(isOperatorActive),
            ::core::stringify!(proxiableUUID),
            ::core::stringify!(paused),
            ::core::stringify!(urc),
            ::core::stringify!(renounceOwnership),
            ::core::stringify!(acceptOwnership),
            ::core::stringify!(pause),
            ::core::stringify!(r#impl),
            ::core::stringify!(owner),
            ::core::stringify!(getBlacklistConfig),
            ::core::stringify!(getBlacklist),
            ::core::stringify!(LOOKAHEAD_BUFFER_SIZE),
            ::core::stringify!(lookahead),
            ::core::stringify!(calculateLookaheadHash),
            ::core::stringify!(checkProposer),
            ::core::stringify!(getLookaheadHash),
            ::core::stringify!(encodeLookahead),
            ::core::stringify!(unblacklistOperator),
            ::core::stringify!(preconfWhitelist),
            ::core::stringify!(buildLookaheadCommitment),
            ::core::stringify!(setOverseer),
            ::core::stringify!(pendingOwner),
            ::core::stringify!(init),
            ::core::stringify!(transferOwnership),
            ::core::stringify!(inbox),
            ::core::stringify!(isOperatorBlacklisted),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <resolverCall as alloy_sol_types::SolCall>::SIGNATURE,
            <blacklistOperatorCall as alloy_sol_types::SolCall>::SIGNATURE,
            <preconfSlasherL1Call as alloy_sol_types::SolCall>::SIGNATURE,
            <getProposerContextCall as alloy_sol_types::SolCall>::SIGNATURE,
            <isLookaheadRequiredCall as alloy_sol_types::SolCall>::SIGNATURE,
            <inNonReentrantCall as alloy_sol_types::SolCall>::SIGNATURE,
            <upgradeToCall as alloy_sol_types::SolCall>::SIGNATURE,
            <unpauseCall as alloy_sol_types::SolCall>::SIGNATURE,
            <overseerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <upgradeToAndCallCall as alloy_sol_types::SolCall>::SIGNATURE,
            <isOperatorActiveCall as alloy_sol_types::SolCall>::SIGNATURE,
            <proxiableUUIDCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pausedCall as alloy_sol_types::SolCall>::SIGNATURE,
            <urcCall as alloy_sol_types::SolCall>::SIGNATURE,
            <renounceOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <acceptOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pauseCall as alloy_sol_types::SolCall>::SIGNATURE,
            <implCall as alloy_sol_types::SolCall>::SIGNATURE,
            <ownerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <getBlacklistConfigCall as alloy_sol_types::SolCall>::SIGNATURE,
            <getBlacklistCall as alloy_sol_types::SolCall>::SIGNATURE,
            <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::SIGNATURE,
            <lookaheadCall as alloy_sol_types::SolCall>::SIGNATURE,
            <calculateLookaheadHashCall as alloy_sol_types::SolCall>::SIGNATURE,
            <checkProposerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <getLookaheadHashCall as alloy_sol_types::SolCall>::SIGNATURE,
            <encodeLookaheadCall as alloy_sol_types::SolCall>::SIGNATURE,
            <unblacklistOperatorCall as alloy_sol_types::SolCall>::SIGNATURE,
            <preconfWhitelistCall as alloy_sol_types::SolCall>::SIGNATURE,
            <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::SIGNATURE,
            <setOverseerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pendingOwnerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <initCall as alloy_sol_types::SolCall>::SIGNATURE,
            <transferOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <inboxCall as alloy_sol_types::SolCall>::SIGNATURE,
            <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::SIGNATURE,
        ];
        /// Returns the signature for the given selector, if known.
        #[inline]
        pub fn signature_by_selector(
            selector: [u8; 4usize],
        ) -> ::core::option::Option<&'static str> {
            match Self::SELECTORS.binary_search(&selector) {
                ::core::result::Result::Ok(idx) => {
                    ::core::option::Option::Some(Self::SIGNATURES[idx])
                }
                ::core::result::Result::Err(_) => ::core::option::Option::None,
            }
        }
        /// Returns the enum variant name for the given selector, if known.
        #[inline]
        pub fn name_by_selector(
            selector: [u8; 4usize],
        ) -> ::core::option::Option<&'static str> {
            let sig = Self::signature_by_selector(selector)?;
            sig.split_once('(').map(|(name, _)| name)
        }
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for LookaheadStoreCalls {
        const NAME: &'static str = "LookaheadStoreCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 36usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::LOOKAHEAD_BUFFER_SIZE(_) => {
                    <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::blacklistOperator(_) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::buildLookaheadCommitment(_) => {
                    <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::calculateLookaheadHash(_) => {
                    <calculateLookaheadHashCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::checkProposer(_) => {
                    <checkProposerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeLookahead(_) => {
                    <encodeLookaheadCall as alloy_sol_types::SolCall>::SELECTOR
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
                Self::getProposerContext(_) => {
                    <getProposerContextCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::r#impl(_) => <implCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::inNonReentrant(_) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::inbox(_) => <inboxCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::init(_) => <initCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::isLookaheadRequired(_) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isOperatorActive(_) => {
                    <isOperatorActiveCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isOperatorBlacklisted(_) => {
                    <isOperatorBlacklistedCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::lookahead(_) => {
                    <lookaheadCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::overseer(_) => <overseerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pause(_) => <pauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::paused(_) => <pausedCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::preconfSlasherL1(_) => {
                    <preconfSlasherL1Call as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::preconfWhitelist(_) => {
                    <preconfWhitelistCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proxiableUUID(_) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::resolver(_) => <resolverCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::setOverseer(_) => {
                    <setOverseerCall as alloy_sol_types::SolCall>::SELECTOR
                }
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
                    fn preconfSlasherL1(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfSlasherL1Call as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfSlasherL1)
                    }
                    preconfSlasherL1
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
                    fn overseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <overseerCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::overseer)
                    }
                    overseer
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
                    fn isOperatorActive(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isOperatorActiveCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::isOperatorActive)
                    }
                    isOperatorActive
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
                    fn LOOKAHEAD_BUFFER_SIZE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::LOOKAHEAD_BUFFER_SIZE)
                    }
                    LOOKAHEAD_BUFFER_SIZE
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
                    fn encodeLookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <encodeLookaheadCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::encodeLookahead)
                    }
                    encodeLookahead
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
                    fn buildLookaheadCommitment(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::buildLookaheadCommitment)
                    }
                    buildLookaheadCommitment
                },
                {
                    fn setOverseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <setOverseerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(LookaheadStoreCalls::setOverseer)
                    }
                    setOverseer
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
                    fn init(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(LookaheadStoreCalls::init)
                    }
                    init
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
                    fn preconfSlasherL1(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <preconfSlasherL1Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::preconfSlasherL1)
                    }
                    preconfSlasherL1
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
                    fn overseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <overseerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::overseer)
                    }
                    overseer
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
                    fn isOperatorActive(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <isOperatorActiveCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::isOperatorActive)
                    }
                    isOperatorActive
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
                    fn LOOKAHEAD_BUFFER_SIZE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::LOOKAHEAD_BUFFER_SIZE)
                    }
                    LOOKAHEAD_BUFFER_SIZE
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
                    fn encodeLookahead(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <encodeLookaheadCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::encodeLookahead)
                    }
                    encodeLookahead
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
                    fn buildLookaheadCommitment(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::buildLookaheadCommitment)
                    }
                    buildLookaheadCommitment
                },
                {
                    fn setOverseer(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<LookaheadStoreCalls> {
                        <setOverseerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(LookaheadStoreCalls::setOverseer)
                    }
                    setOverseer
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
                Self::LOOKAHEAD_BUFFER_SIZE(inner) => {
                    <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::blacklistOperator(inner) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::buildLookaheadCommitment(inner) => {
                    <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::encodeLookahead(inner) => {
                    <encodeLookaheadCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::isLookaheadRequired(inner) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::isOperatorActive(inner) => {
                    <isOperatorActiveCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::overseer(inner) => {
                    <overseerCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
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
                Self::preconfSlasherL1(inner) => {
                    <preconfSlasherL1Call as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::renounceOwnership(inner) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::resolver(inner) => {
                    <resolverCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::setOverseer(inner) => {
                    <setOverseerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
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
                Self::LOOKAHEAD_BUFFER_SIZE(inner) => {
                    <LOOKAHEAD_BUFFER_SIZECall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::blacklistOperator(inner) => {
                    <blacklistOperatorCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::buildLookaheadCommitment(inner) => {
                    <buildLookaheadCommitmentCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::encodeLookahead(inner) => {
                    <encodeLookaheadCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::isLookaheadRequired(inner) => {
                    <isLookaheadRequiredCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::isOperatorActive(inner) => {
                    <isOperatorActiveCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::overseer(inner) => {
                    <overseerCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::preconfSlasherL1(inner) => {
                    <preconfSlasherL1Call as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::setOverseer(inner) => {
                    <setOverseerCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
    #[derive(Clone)]
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
        NotInbox(NotInbox),
        #[allow(missing_docs)]
        NotOverseer(NotOverseer),
        #[allow(missing_docs)]
        OperatorAlreadyBlacklisted(OperatorAlreadyBlacklisted),
        #[allow(missing_docs)]
        OperatorNotBlacklisted(OperatorNotBlacklisted),
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
            [54u8, 40u8, 168u8, 27u8],
            [65u8, 0u8, 172u8, 3u8],
            [69u8, 203u8, 10u8, 249u8],
            [83u8, 139u8, 164u8, 249u8],
            [85u8, 247u8, 218u8, 148u8],
            [114u8, 16u8, 159u8, 119u8],
            [129u8, 54u8, 100u8, 30u8],
            [149u8, 56u8, 62u8, 161u8],
            [150u8, 172u8, 231u8, 155u8],
            [151u8, 28u8, 206u8, 143u8],
            [153u8, 211u8, 250u8, 249u8],
            [162u8, 130u8, 147u8, 31u8],
            [172u8, 157u8, 135u8, 205u8],
            [184u8, 6u8, 40u8, 54u8],
            [186u8, 230u8, 226u8, 169u8],
            [223u8, 198u8, 13u8, 133u8],
            [234u8, 248u8, 42u8, 37u8],
            [236u8, 115u8, 41u8, 89u8],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(OperatorNotBlacklisted),
            ::core::stringify!(ProposerIsNotFallbackPreconfer),
            ::core::stringify!(FUNC_NOT_IMPLEMENTED),
            ::core::stringify!(OperatorAlreadyBlacklisted),
            ::core::stringify!(InvalidSlotIndex),
            ::core::stringify!(InvalidProposer),
            ::core::stringify!(InvalidLookaheadTimestamp),
            ::core::stringify!(ZERO_ADDRESS),
            ::core::stringify!(CommitmentSignerMismatch),
            ::core::stringify!(NotInbox),
            ::core::stringify!(ProposerIsNotPreconfer),
            ::core::stringify!(ACCESS_DENIED),
            ::core::stringify!(InvalidLookaheadEpoch),
            ::core::stringify!(InvalidSlotTimestamp),
            ::core::stringify!(UnblacklistDelayNotMet),
            ::core::stringify!(BlacklistDelayNotMet),
            ::core::stringify!(NotOverseer),
            ::core::stringify!(SlotTimestampIsNotIncrementing),
            ::core::stringify!(INVALID_PAUSE_STATUS),
            ::core::stringify!(REENTRANT_CALL),
            ::core::stringify!(InvalidLookahead),
            ::core::stringify!(ZERO_VALUE),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <OperatorNotBlacklisted as alloy_sol_types::SolError>::SIGNATURE,
            <ProposerIsNotFallbackPreconfer as alloy_sol_types::SolError>::SIGNATURE,
            <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::SIGNATURE,
            <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidSlotIndex as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidProposer as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidLookaheadTimestamp as alloy_sol_types::SolError>::SIGNATURE,
            <ZERO_ADDRESS as alloy_sol_types::SolError>::SIGNATURE,
            <CommitmentSignerMismatch as alloy_sol_types::SolError>::SIGNATURE,
            <NotInbox as alloy_sol_types::SolError>::SIGNATURE,
            <ProposerIsNotPreconfer as alloy_sol_types::SolError>::SIGNATURE,
            <ACCESS_DENIED as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidLookaheadEpoch as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidSlotTimestamp as alloy_sol_types::SolError>::SIGNATURE,
            <UnblacklistDelayNotMet as alloy_sol_types::SolError>::SIGNATURE,
            <BlacklistDelayNotMet as alloy_sol_types::SolError>::SIGNATURE,
            <NotOverseer as alloy_sol_types::SolError>::SIGNATURE,
            <SlotTimestampIsNotIncrementing as alloy_sol_types::SolError>::SIGNATURE,
            <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::SIGNATURE,
            <REENTRANT_CALL as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidLookahead as alloy_sol_types::SolError>::SIGNATURE,
            <ZERO_VALUE as alloy_sol_types::SolError>::SIGNATURE,
        ];
        /// Returns the signature for the given selector, if known.
        #[inline]
        pub fn signature_by_selector(
            selector: [u8; 4usize],
        ) -> ::core::option::Option<&'static str> {
            match Self::SELECTORS.binary_search(&selector) {
                ::core::result::Result::Ok(idx) => {
                    ::core::option::Option::Some(Self::SIGNATURES[idx])
                }
                ::core::result::Result::Err(_) => ::core::option::Option::None,
            }
        }
        /// Returns the enum variant name for the given selector, if known.
        #[inline]
        pub fn name_by_selector(
            selector: [u8; 4usize],
        ) -> ::core::option::Option<&'static str> {
            let sig = Self::signature_by_selector(selector)?;
            sig.split_once('(').map(|(name, _)| name)
        }
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for LookaheadStoreErrors {
        const NAME: &'static str = "LookaheadStoreErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 22usize;
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
                Self::NotInbox(_) => <NotInbox as alloy_sol_types::SolError>::SELECTOR,
                Self::NotOverseer(_) => {
                    <NotOverseer as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorAlreadyBlacklisted(_) => {
                    <OperatorAlreadyBlacklisted as alloy_sol_types::SolError>::SELECTOR
                }
                Self::OperatorNotBlacklisted(_) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::SELECTOR
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
                Self::OperatorNotBlacklisted(inner) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::OperatorNotBlacklisted(inner) => {
                    <OperatorNotBlacklisted as alloy_sol_types::SolError>::abi_encode_raw(
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
    #[derive(Clone)]
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
        OverseerSet(OverseerSet),
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
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ],
            [
                244u8, 181u8, 91u8, 133u8, 108u8, 88u8, 59u8, 149u8, 47u8, 12u8, 13u8,
                66u8, 6u8, 124u8, 142u8, 99u8, 201u8, 250u8, 227u8, 149u8, 50u8, 41u8,
                5u8, 212u8, 94u8, 85u8, 175u8, 29u8, 15u8, 9u8, 89u8, 148u8,
            ],
            [
                245u8, 100u8, 10u8, 216u8, 167u8, 74u8, 96u8, 102u8, 199u8, 243u8, 188u8,
                21u8, 151u8, 109u8, 29u8, 128u8, 189u8, 229u8, 29u8, 187u8, 201u8, 217u8,
                205u8, 135u8, 93u8, 156u8, 101u8, 130u8, 181u8, 167u8, 14u8, 61u8,
            ],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(Blacklisted),
            ::core::stringify!(BeaconUpgraded),
            ::core::stringify!(OwnershipTransferStarted),
            ::core::stringify!(Unpaused),
            ::core::stringify!(Paused),
            ::core::stringify!(AdminChanged),
            ::core::stringify!(Initialized),
            ::core::stringify!(OwnershipTransferred),
            ::core::stringify!(Unblacklisted),
            ::core::stringify!(Upgraded),
            ::core::stringify!(LookaheadPosted),
            ::core::stringify!(OverseerSet),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <Blacklisted as alloy_sol_types::SolEvent>::SIGNATURE,
            <BeaconUpgraded as alloy_sol_types::SolEvent>::SIGNATURE,
            <OwnershipTransferStarted as alloy_sol_types::SolEvent>::SIGNATURE,
            <Unpaused as alloy_sol_types::SolEvent>::SIGNATURE,
            <Paused as alloy_sol_types::SolEvent>::SIGNATURE,
            <AdminChanged as alloy_sol_types::SolEvent>::SIGNATURE,
            <Initialized as alloy_sol_types::SolEvent>::SIGNATURE,
            <OwnershipTransferred as alloy_sol_types::SolEvent>::SIGNATURE,
            <Unblacklisted as alloy_sol_types::SolEvent>::SIGNATURE,
            <Upgraded as alloy_sol_types::SolEvent>::SIGNATURE,
            <LookaheadPosted as alloy_sol_types::SolEvent>::SIGNATURE,
            <OverseerSet as alloy_sol_types::SolEvent>::SIGNATURE,
        ];
        /// Returns the signature for the given selector, if known.
        #[inline]
        pub fn signature_by_selector(
            selector: [u8; 32usize],
        ) -> ::core::option::Option<&'static str> {
            match Self::SELECTORS.binary_search(&selector) {
                ::core::result::Result::Ok(idx) => {
                    ::core::option::Option::Some(Self::SIGNATURES[idx])
                }
                ::core::result::Result::Err(_) => ::core::option::Option::None,
            }
        }
        /// Returns the enum variant name for the given selector, if known.
        #[inline]
        pub fn name_by_selector(
            selector: [u8; 32usize],
        ) -> ::core::option::Option<&'static str> {
            let sig = Self::signature_by_selector(selector)?;
            sig.split_once('(').map(|(name, _)| name)
        }
    }
    #[automatically_derived]
    impl alloy_sol_types::SolEventInterface for LookaheadStoreEvents {
        const NAME: &'static str = "LookaheadStoreEvents";
        const COUNT: usize = 12usize;
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
                Some(<OverseerSet as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <OverseerSet as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::OverseerSet)
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
                Self::OverseerSet(inner) => {
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
                Self::OverseerSet(inner) => {
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
        __provider: P,
    ) -> LookaheadStoreInstance<P, N> {
        LookaheadStoreInstance::<P, N>::new(address, __provider)
    }
    /**Deploys this contract using the given `provider` and constructor arguments, if any.

Returns a new instance of the contract, if the deployment was successful.

For more fine-grained control over the deployment process, use [`deploy_builder`] instead.*/
    #[inline]
    pub fn deploy<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        __provider: P,
        _inbox: alloy::sol_types::private::Address,
        _preconfSlasherL1: alloy::sol_types::private::Address,
        _preconfWhitelist: alloy::sol_types::private::Address,
        _urc: alloy::sol_types::private::Address,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<LookaheadStoreInstance<P, N>>,
    > {
        LookaheadStoreInstance::<
            P,
            N,
        >::deploy(__provider, _inbox, _preconfSlasherL1, _preconfWhitelist, _urc)
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
        __provider: P,
        _inbox: alloy::sol_types::private::Address,
        _preconfSlasherL1: alloy::sol_types::private::Address,
        _preconfWhitelist: alloy::sol_types::private::Address,
        _urc: alloy::sol_types::private::Address,
    ) -> alloy_contract::RawCallBuilder<P, N> {
        LookaheadStoreInstance::<
            P,
            N,
        >::deploy_builder(__provider, _inbox, _preconfSlasherL1, _preconfWhitelist, _urc)
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
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > LookaheadStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`LookaheadStore`](self) contract instance.

See the [wrapper's documentation](`LookaheadStoreInstance`) for more details.*/
        #[inline]
        pub const fn new(
            address: alloy_sol_types::private::Address,
            __provider: P,
        ) -> Self {
            Self {
                address,
                provider: __provider,
                _network: ::core::marker::PhantomData,
            }
        }
        /**Deploys this contract using the given `provider` and constructor arguments, if any.

Returns a new instance of the contract, if the deployment was successful.

For more fine-grained control over the deployment process, use [`deploy_builder`] instead.*/
        #[inline]
        pub async fn deploy(
            __provider: P,
            _inbox: alloy::sol_types::private::Address,
            _preconfSlasherL1: alloy::sol_types::private::Address,
            _preconfWhitelist: alloy::sol_types::private::Address,
            _urc: alloy::sol_types::private::Address,
        ) -> alloy_contract::Result<LookaheadStoreInstance<P, N>> {
            let call_builder = Self::deploy_builder(
                __provider,
                _inbox,
                _preconfSlasherL1,
                _preconfWhitelist,
                _urc,
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
            __provider: P,
            _inbox: alloy::sol_types::private::Address,
            _preconfSlasherL1: alloy::sol_types::private::Address,
            _preconfWhitelist: alloy::sol_types::private::Address,
            _urc: alloy::sol_types::private::Address,
        ) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                __provider,
                [
                    &BYTECODE[..],
                    &alloy_sol_types::SolConstructor::abi_encode(
                        &constructorCall {
                            _inbox,
                            _preconfSlasherL1,
                            _preconfWhitelist,
                            _urc,
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
        ///Creates a new call builder for the [`LOOKAHEAD_BUFFER_SIZE`] function.
        pub fn LOOKAHEAD_BUFFER_SIZE(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, LOOKAHEAD_BUFFER_SIZECall, N> {
            self.call_builder(&LOOKAHEAD_BUFFER_SIZECall)
        }
        ///Creates a new call builder for the [`acceptOwnership`] function.
        pub fn acceptOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, acceptOwnershipCall, N> {
            self.call_builder(&acceptOwnershipCall)
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
        ///Creates a new call builder for the [`buildLookaheadCommitment`] function.
        pub fn buildLookaheadCommitment(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _encodedLookahead: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, buildLookaheadCommitmentCall, N> {
            self.call_builder(
                &buildLookaheadCommitmentCall {
                    _epochTimestamp,
                    _encodedLookahead,
                },
            )
        }
        ///Creates a new call builder for the [`calculateLookaheadHash`] function.
        pub fn calculateLookaheadHash(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _encodedLookahead: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, calculateLookaheadHashCall, N> {
            self.call_builder(
                &calculateLookaheadHashCall {
                    _epochTimestamp,
                    _encodedLookahead,
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
        ///Creates a new call builder for the [`encodeLookahead`] function.
        pub fn encodeLookahead(
            &self,
            _lookaheadSlots: alloy::sol_types::private::Vec<
                <ILookaheadStore::LookaheadSlot as alloy::sol_types::SolType>::RustType,
            >,
        ) -> alloy_contract::SolCallBuilder<&P, encodeLookaheadCall, N> {
            self.call_builder(
                &encodeLookaheadCall {
                    _lookaheadSlots,
                },
            )
        }
        ///Creates a new call builder for the [`getBlacklist`] function.
        pub fn getBlacklist(
            &self,
            _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, getBlacklistCall, N> {
            self.call_builder(
                &getBlacklistCall {
                    _operatorRegistrationRoot,
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
        ///Creates a new call builder for the [`getProposerContext`] function.
        pub fn getProposerContext(
            &self,
            _epochTimestamp: alloy::sol_types::private::primitives::aliases::U256,
            _data: <ILookaheadStore::LookaheadData as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, getProposerContextCall, N> {
            self.call_builder(
                &getProposerContextCall {
                    _epochTimestamp,
                    _data,
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
            _overseer: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, initCall, N> {
            self.call_builder(&initCall { _owner, _overseer })
        }
        ///Creates a new call builder for the [`isLookaheadRequired`] function.
        pub fn isLookaheadRequired(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, isLookaheadRequiredCall, N> {
            self.call_builder(&isLookaheadRequiredCall)
        }
        ///Creates a new call builder for the [`isOperatorActive`] function.
        pub fn isOperatorActive(
            &self,
            _registrationRoot: alloy::sol_types::private::FixedBytes<32>,
            _referenceTimestamp: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, isOperatorActiveCall, N> {
            self.call_builder(
                &isOperatorActiveCall {
                    _registrationRoot,
                    _referenceTimestamp,
                },
            )
        }
        ///Creates a new call builder for the [`isOperatorBlacklisted`] function.
        pub fn isOperatorBlacklisted(
            &self,
            _operatorRegistrationRoot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isOperatorBlacklistedCall, N> {
            self.call_builder(
                &isOperatorBlacklistedCall {
                    _operatorRegistrationRoot,
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
        ///Creates a new call builder for the [`overseer`] function.
        pub fn overseer(&self) -> alloy_contract::SolCallBuilder<&P, overseerCall, N> {
            self.call_builder(&overseerCall)
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
        ///Creates a new call builder for the [`preconfSlasherL1`] function.
        pub fn preconfSlasherL1(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, preconfSlasherL1Call, N> {
            self.call_builder(&preconfSlasherL1Call)
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
        ///Creates a new call builder for the [`setOverseer`] function.
        pub fn setOverseer(
            &self,
            _newOverseer: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, setOverseerCall, N> {
            self.call_builder(&setOverseerCall { _newOverseer })
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
        ///Creates a new event filter for the [`OverseerSet`] event.
        pub fn OverseerSet_filter(&self) -> alloy_contract::Event<&P, OverseerSet, N> {
            self.event_filter::<OverseerSet>()
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
