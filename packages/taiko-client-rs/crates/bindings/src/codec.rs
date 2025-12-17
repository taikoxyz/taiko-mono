///Module containing a contract's types and functions.
/**

```solidity
library IInbox {
    struct Commitment { uint48 firstProposalId; bytes32 firstProposalParentBlockHash; bytes32 lastProposalHash; address actualProver; uint48 endBlockNumber; bytes32 endStateRoot; Transition[] transitions; }
    struct DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
    struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 parentProposalHash; uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
    struct ProposeInput { uint48 deadline; LibBlobs.BlobReference blobReference; uint8 numForcedInclusions; }
    struct ProveInput { Commitment commitment; bool forceCheckpointSync; }
    struct Transition { address proposer; address designatedProver; uint48 timestamp; bytes32 blockHash; }
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
struct Commitment { uint48 firstProposalId; bytes32 firstProposalParentBlockHash; bytes32 lastProposalHash; address actualProver; uint48 endBlockNumber; bytes32 endStateRoot; Transition[] transitions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct Commitment {
        #[allow(missing_docs)]
        pub firstProposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub firstProposalParentBlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub lastProposalHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub actualProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub endBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub endStateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub transitions: alloy::sol_types::private::Vec<
            <Transition as alloy::sol_types::SolType>::RustType,
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
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Array<Transition>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::Vec<
                <Transition as alloy::sol_types::SolType>::RustType,
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
        impl ::core::convert::From<Commitment> for UnderlyingRustTuple<'_> {
            fn from(value: Commitment) -> Self {
                (
                    value.firstProposalId,
                    value.firstProposalParentBlockHash,
                    value.lastProposalHash,
                    value.actualProver,
                    value.endBlockNumber,
                    value.endStateRoot,
                    value.transitions,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for Commitment {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    firstProposalId: tuple.0,
                    firstProposalParentBlockHash: tuple.1,
                    lastProposalHash: tuple.2,
                    actualProver: tuple.3,
                    endBlockNumber: tuple.4,
                    endStateRoot: tuple.5,
                    transitions: tuple.6,
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
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.firstProposalId),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.firstProposalParentBlockHash,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.lastProposalHash),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.actualProver,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.endBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.endStateRoot),
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::tokenize(&self.transitions),
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
                    "Commitment(uint48 firstProposalId,bytes32 firstProposalParentBlockHash,bytes32 lastProposalHash,address actualProver,uint48 endBlockNumber,bytes32 endStateRoot,Transition[] transitions)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.firstProposalId,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.firstProposalParentBlockHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.lastProposalHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.actualProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.endBlockNumber,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.endStateRoot)
                        .0,
                    <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.transitions)
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
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.firstProposalId,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.firstProposalParentBlockHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.lastProposalHash,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.actualProver,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.endBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.endStateRoot,
                    )
                    + <alloy::sol_types::sol_data::Array<
                        Transition,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.transitions,
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
                    &rust.firstProposalParentBlockHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.lastProposalHash,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.actualProver,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.endBlockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.endStateRoot,
                    out,
                );
                <alloy::sol_types::sol_data::Array<
                    Transition,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.transitions,
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
struct Proposal { uint48 id; uint48 timestamp; uint48 endOfSubmissionWindowTimestamp; address proposer; bytes32 parentProposalHash; uint48 originBlockNumber; bytes32 originBlockHash; uint8 basefeeSharingPctg; DerivationSource[] sources; }
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Uint<8>,
            alloy::sol_types::sol_data::Array<DerivationSource>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::Address,
            alloy::sol_types::private::FixedBytes<32>,
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
        impl ::core::convert::From<Proposal> for UnderlyingRustTuple<'_> {
            fn from(value: Proposal) -> Self {
                (
                    value.id,
                    value.timestamp,
                    value.endOfSubmissionWindowTimestamp,
                    value.proposer,
                    value.parentProposalHash,
                    value.originBlockNumber,
                    value.originBlockHash,
                    value.basefeeSharingPctg,
                    value.sources,
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
                    originBlockNumber: tuple.5,
                    originBlockHash: tuple.6,
                    basefeeSharingPctg: tuple.7,
                    sources: tuple.8,
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
                    "Proposal(uint48 id,uint48 timestamp,uint48 endOfSubmissionWindowTimestamp,address proposer,bytes32 parentProposalHash,uint48 originBlockNumber,bytes32 originBlockHash,uint8 basefeeSharingPctg,DerivationSource[] sources)",
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
struct ProveInput { Commitment commitment; bool forceCheckpointSync; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProveInput {
        #[allow(missing_docs)]
        pub commitment: <Commitment as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub forceCheckpointSync: bool,
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
        type UnderlyingSolTuple<'a> = (Commitment, alloy::sol_types::sol_data::Bool);
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            <Commitment as alloy::sol_types::SolType>::RustType,
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
                (value.commitment, value.forceCheckpointSync)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProveInput {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    commitment: tuple.0,
                    forceCheckpointSync: tuple.1,
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
                    <Commitment as alloy_sol_types::SolType>::tokenize(&self.commitment),
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.forceCheckpointSync,
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
                    "ProveInput(Commitment commitment,bool forceCheckpointSync)",
                )
            }
            #[inline]
            fn eip712_components() -> alloy_sol_types::private::Vec<
                alloy_sol_types::private::Cow<'static, str>,
            > {
                let mut components = alloy_sol_types::private::Vec::with_capacity(1);
                components
                    .push(
                        <Commitment as alloy_sol_types::SolStruct>::eip712_root_type(),
                    );
                components
                    .extend(
                        <Commitment as alloy_sol_types::SolStruct>::eip712_components(),
                    );
                components
            }
            #[inline]
            fn eip712_encode_data(&self) -> alloy_sol_types::private::Vec<u8> {
                [
                    <Commitment as alloy_sol_types::SolType>::eip712_data_word(
                            &self.commitment,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.forceCheckpointSync,
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
                    + <Commitment as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.commitment,
                    )
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.forceCheckpointSync,
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
                <Commitment as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.commitment,
                    out,
                );
                <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.forceCheckpointSync,
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
struct Transition { address proposer; address designatedProver; uint48 timestamp; bytes32 blockHash; }
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
        pub blockHash: alloy::sol_types::private::FixedBytes<32>,
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
                    value.blockHash,
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
                    blockHash: tuple.3,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.blockHash),
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
                    "Transition(address proposer,address designatedProver,uint48 timestamp,bytes32 blockHash)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blockHash)
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
                        &rust.blockHash,
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
                    &rust.blockHash,
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
library IInbox {
    struct Commitment {
        uint48 firstProposalId;
        bytes32 firstProposalParentBlockHash;
        bytes32 lastProposalHash;
        address actualProver;
        uint48 endBlockNumber;
        bytes32 endStateRoot;
        Transition[] transitions;
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
        uint48 originBlockNumber;
        bytes32 originBlockHash;
        uint8 basefeeSharingPctg;
        DerivationSource[] sources;
    }
    struct ProposeInput {
        uint48 deadline;
        LibBlobs.BlobReference blobReference;
        uint8 numForcedInclusions;
    }
    struct ProveInput {
        Commitment commitment;
        bool forceCheckpointSync;
    }
    struct Transition {
        address proposer;
        address designatedProver;
        uint48 timestamp;
        bytes32 blockHash;
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
    function decodeProveInput(bytes memory _data) external pure returns (IInbox.ProveInput memory input_);
    function encodeProposeInput(IInbox.ProposeInput memory _input) external pure returns (bytes memory encoded_);
    function encodeProveInput(IInbox.ProveInput memory _input) external pure returns (bytes memory encoded_);
    function hashBondInstruction(LibBonds.BondInstruction memory _bondInstruction) external pure returns (bytes32);
    function hashCommitment(IInbox.Commitment memory _commitment) external pure returns (bytes32);
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32);
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
            "name": "commitment",
            "type": "tuple",
            "internalType": "struct IInbox.Commitment",
            "components": [
              {
                "name": "firstProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "firstProposalParentBlockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "lastProposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "endBlockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endStateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
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
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "forceCheckpointSync",
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
    "name": "encodeProveInput",
    "inputs": [
      {
        "name": "_input",
        "type": "tuple",
        "internalType": "struct IInbox.ProveInput",
        "components": [
          {
            "name": "commitment",
            "type": "tuple",
            "internalType": "struct IInbox.Commitment",
            "components": [
              {
                "name": "firstProposalId",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "firstProposalParentBlockHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "lastProposalHash",
                "type": "bytes32",
                "internalType": "bytes32"
              },
              {
                "name": "actualProver",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "endBlockNumber",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "endStateRoot",
                "type": "bytes32",
                "internalType": "bytes32"
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
                    "name": "blockHash",
                    "type": "bytes32",
                    "internalType": "bytes32"
                  }
                ]
              }
            ]
          },
          {
            "name": "forceCheckpointSync",
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
    "name": "hashCommitment",
    "inputs": [
      {
        "name": "_commitment",
        "type": "tuple",
        "internalType": "struct IInbox.Commitment",
        "components": [
          {
            "name": "firstProposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "firstProposalParentBlockHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "lastProposalHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "actualProver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "endBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "endStateRoot",
            "type": "bytes32",
            "internalType": "bytes32"
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
                "name": "blockHash",
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
    ///0x6080604052348015600e575f5ffd5b506113978061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061007a575f3560e01c8063b28e824e11610058578063b28e824e14610128578063c3d3e2f41461013b578063cbc148c31461014e578063edbacd4414610161575f5ffd5b80632f1969b01461007e5780635a213615146100a7578063afb63ad4146100c8575b5f5ffd5b61009161008c36600461087b565b610181565b60405161009e9190610894565b60405180910390f35b6100ba6100b53660046108c9565b6101a0565b60405190815260200161009e565b6100db6100d63660046108da565b6101b8565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a00161009e565b6100ba610136366004610946565b610205565b61009161014936600461097d565b610217565b6100ba61015c3660046109b3565b61022a565b61017461016f3660046108da565b61023c565b60405161009e9190610a5c565b606061019a61019536849003840184610c38565b610282565b92915050565b5f61019a6101b336849003840184610cde565b6102f9565b6101c06107e6565b6101fe83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061032892505050565b9392505050565b5f61019a61021283610f00565b610380565b606061019a610225836110fd565b610392565b5f61019a61023783611150565b6104b8565b61024461081d565b6101fe83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061060f92505050565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d8201906102f190829061077f565b905050919050565b5f8160405160200161030b919061115b565b604051602081830303815290604052805190602001209050919050565b6103306107e6565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b5f8160405160200161030b9190611289565b805160c08101515160609190604e02608301806001600160401b038111156103bc576103bc610af6565b6040519080825280601f01601f1916602001820160405280156103e6576020820181803683370190505b50825160d090811b602083810191909152840151602683015260408401516046830152606080850151901b606683015260808085015190911b607a83015260a0808501519183019190915260c0840151519194508401906104469061078b565b60c08301515160f01b81526002015f5b8360c00151518110156104945761048a828560c00151838151811061047d5761047d61134d565b60200260200101516107b1565b9150600101610456565b506104af8186602001516104a8575f61077f565b600161077f565b50505050919050565b60c081015180515f919060096004820201836104e48260408051828152600190920160051b8201905290565b6020808201529050855165ffffffffffff166040820152602086015160608201526040860151608082015260608601516001600160a01b031660a0820152608086015165ffffffffffff1660c082015260a086015160e082015260e0610100820152610120810183905260095f5b848110156105dd575f86828151811061056d5761056d61134d565b602090810291909101015180516001600160a01b03166001850160051b860152905060208101516001600160a01b03166002840160051b850152604081015165ffffffffffff166003840160051b85015260608101516004840160051b8501525060049190910190600101610552565b50815160051b60208301206106048380516040516001820160051b83011490151060061b52565b979650505050505050565b61061761081d565b602082810151825160d091821c90526026840151835190920191909152604683015182516040015260668301518251606091821c910152607a8301518251911c608091820152820151815160a09081019190915282015160a283019060f01c806001600160401b0381111561068e5761068e610af6565b6040519080825280602002602001820160405280156106de57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816106ac5790505b50835160c001525f5b8161ffff1681101561076d57604080516080810182525f8082526020820181815292820181815260608084019283528751811c84526014880151901c909352602886015160d01c909252602e850151909152604e8401855160c001518051849081106107555761075561134d565b602090810291909101019190915292506001016106e7565b50505160f81c15156020820152919050565b5f818353505060010190565b61ffff8111156107ae5760405163161e7a6b60e11b815260040160405180910390fd5b50565b8051606090811b83526020820151811b6014840152604082015160d01b6028840152810151602e8301908152604e83016101fe565b60408051606080820183525f8083528351918201845280825260208281018290529382015290918201905b81525f60209091015290565b60405180604001604052806108116040518060e001604052805f65ffffffffffff1681526020015f81526020015f81526020015f6001600160a01b031681526020015f65ffffffffffff1681526020015f8152602001606081525090565b5f60a082840312801561088c575f5ffd5b509092915050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f608082840312801561088c575f5ffd5b5f5f602083850312156108eb575f5ffd5b82356001600160401b03811115610900575f5ffd5b8301601f81018513610910575f5ffd5b80356001600160401b03811115610925575f5ffd5b856020828401011115610936575f5ffd5b6020919091019590945092505050565b5f60208284031215610956575f5ffd5b81356001600160401b0381111561096b575f5ffd5b820161012081850312156101fe575f5ffd5b5f6020828403121561098d575f5ffd5b81356001600160401b038111156109a2575f5ffd5b8201604081850312156101fe575f5ffd5b5f602082840312156109c3575f5ffd5b81356001600160401b038111156109d8575f5ffd5b820160e081850312156101fe575f5ffd5b5f8151808452602084019350602083015f5b82811015610a5257815180516001600160a01b0390811688526020808301519091168189015260408083015165ffffffffffff169089015260609182015191880191909152608090960195909101906001016109fb565b5093949350505050565b602081525f82516040602084015265ffffffffffff815116606084015260208101516080840152604081015160a084015260018060a01b0360608201511660c084015265ffffffffffff60808201511660e084015260a081015161010084015260c0810151905060e0610120840152610ad96101408401826109e9565b90506020840151610aee604085018215159052565b509392505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b0381118282101715610b2c57610b2c610af6565b60405290565b604051608081016001600160401b0381118282101715610b2c57610b2c610af6565b604080519081016001600160401b0381118282101715610b2c57610b2c610af6565b60405161012081016001600160401b0381118282101715610b2c57610b2c610af6565b60405160e081016001600160401b0381118282101715610b2c57610b2c610af6565b604051601f8201601f191681016001600160401b0381118282101715610be357610be3610af6565b604052919050565b803565ffffffffffff81168114610c00575f5ffd5b919050565b803561ffff81168114610c00575f5ffd5b803562ffffff81168114610c00575f5ffd5b803560ff81168114610c00575f5ffd5b5f81830360a081128015610c4a575f5ffd5b50610c53610b0a565b610c5c84610beb565b81526060601f1983011215610c6f575f5ffd5b610c77610b0a565b9150610c8560208501610c05565b8252610c9360408501610c05565b6020830152610ca460608501610c16565b6040830152816020820152610cbb60808501610c28565b6040820152949350505050565b80356001600160a01b0381168114610c00575f5ffd5b5f6080828403128015610cef575f5ffd5b50610cf8610b32565b610d0183610beb565b8152602083013560028110610d14575f5ffd5b6020820152610d2560408401610cc8565b6040820152610d3660608401610cc8565b60608201529392505050565b5f6001600160401b03821115610d5a57610d5a610af6565b5060051b60200190565b80358015158114610c00575f5ffd5b5f82601f830112610d82575f5ffd5b8135610d95610d9082610d42565b610bbb565b8082825260208201915060208360051b860101925085831115610db6575f5ffd5b602085015b83811015610ef65780356001600160401b03811115610dd8575f5ffd5b86016040818903601f19011215610ded575f5ffd5b610df5610b54565b610e0160208301610d64565b815260408201356001600160401b03811115610e1b575f5ffd5b6020818401019250506060828a031215610e33575f5ffd5b610e3b610b0a565b82356001600160401b03811115610e50575f5ffd5b8301601f81018b13610e60575f5ffd5b8035610e6e610d9082610d42565b8082825260208201915060208360051b85010192508d831115610e8f575f5ffd5b6020840193505b82841015610eb1578335825260209384019390910190610e96565b845250610ec391505060208401610c16565b6020820152610ed460408401610beb565b6040820152806020830152508085525050602083019250602081019050610dbb565b5095945050505050565b5f6101208236031215610f11575f5ffd5b610f19610b76565b610f2283610beb565b8152610f3060208401610beb565b6020820152610f4160408401610beb565b6040820152610f5260608401610cc8565b606082015260808381013590820152610f6d60a08401610beb565b60a082015260c08381013590820152610f8860e08401610c28565b60e08201526101008301356001600160401b03811115610fa6575f5ffd5b610fb236828601610d73565b6101008301525092915050565b5f82601f830112610fce575f5ffd5b8135610fdc610d9082610d42565b8082825260208201915060208360071b860101925085831115610ffd575f5ffd5b602085015b83811015610ef65760808188031215611019575f5ffd5b611021610b32565b61102a82610cc8565b815261103860208301610cc8565b602082015261104960408301610beb565b6040820152606082810135908201528352602090920191608001611002565b5f60e08284031215611078575f5ffd5b611080610b99565b905061108b82610beb565b815260208281013590820152604080830135908201526110ad60608301610cc8565b60608201526110be60808301610beb565b608082015260a0828101359082015260c08201356001600160401b038111156110e5575f5ffd5b6110f184828501610fbf565b60c08301525092915050565b5f6040823603121561110d575f5ffd5b611115610b54565b82356001600160401b0381111561112a575f5ffd5b61113636828601611068565b82525061114560208401610d64565b602082015292915050565b5f61019a3683611068565b815165ffffffffffff168152602082015160808201906002811061118d57634e487b7160e01b5f52602160045260245ffd5b60208301526040838101516001600160a01b039081169184019190915260609384015116929091019190915290565b5f82825180855260208501945060208160051b830101602085015f5b8381101561127d57848303601f19018852815180511515845260209081015160408286018190528151606091870191909152805160a08701819052919201905f9060c08701905b80831015611242578351825260208201915060208401935060018301925061121f565b5060208481015162ffffff16606089015260409094015165ffffffffffff1660809097019690965250509788019791909101906001016111d8565b50909695505050505050565b602081526112a260208201835165ffffffffffff169052565b5f60208301516112bc604084018265ffffffffffff169052565b50604083015165ffffffffffff811660608401525060608301516001600160a01b038116608084015250608083015160a083015260a083015161130960c084018265ffffffffffff169052565b5060c083015160e083015260e083015161132961010084018260ff169052565b50610100830151610120808401526113456101408401826111bc565b949350505050565b634e487b7160e01b5f52603260045260245ffdfea2646970667358221220df6a1d58bc12063bf3e39c9331c6bd846313154e983b47e1cbb4c3a14f89a1d264736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15`\x0EW__\xFD[Pa\x13\x97\x80a\0\x1C_9_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0zW_5`\xE0\x1C\x80c\xB2\x8E\x82N\x11a\0XW\x80c\xB2\x8E\x82N\x14a\x01(W\x80c\xC3\xD3\xE2\xF4\x14a\x01;W\x80c\xCB\xC1H\xC3\x14a\x01NW\x80c\xED\xBA\xCDD\x14a\x01aW__\xFD[\x80c/\x19i\xB0\x14a\0~W\x80cZ!6\x15\x14a\0\xA7W\x80c\xAF\xB6:\xD4\x14a\0\xC8W[__\xFD[a\0\x91a\0\x8C6`\x04a\x08{V[a\x01\x81V[`@Qa\0\x9E\x91\x90a\x08\x94V[`@Q\x80\x91\x03\x90\xF3[a\0\xBAa\0\xB56`\x04a\x08\xC9V[a\x01\xA0V[`@Q\x90\x81R` \x01a\0\x9EV[a\0\xDBa\0\xD66`\x04a\x08\xDAV[a\x01\xB8V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\0\x9EV[a\0\xBAa\x0166`\x04a\tFV[a\x02\x05V[a\0\x91a\x01I6`\x04a\t}V[a\x02\x17V[a\0\xBAa\x01\\6`\x04a\t\xB3V[a\x02*V[a\x01ta\x01o6`\x04a\x08\xDAV[a\x02<V[`@Qa\0\x9E\x91\x90a\n\\V[``a\x01\x9Aa\x01\x956\x84\x90\x03\x84\x01\x84a\x0C8V[a\x02\x82V[\x92\x91PPV[_a\x01\x9Aa\x01\xB36\x84\x90\x03\x84\x01\x84a\x0C\xDEV[a\x02\xF9V[a\x01\xC0a\x07\xE6V[a\x01\xFE\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x03(\x92PPPV[\x93\x92PPPV[_a\x01\x9Aa\x02\x12\x83a\x0F\0V[a\x03\x80V[``a\x01\x9Aa\x02%\x83a\x10\xFDV[a\x03\x92V[_a\x01\x9Aa\x027\x83a\x11PV[a\x04\xB8V[a\x02Da\x08\x1DV[a\x01\xFE\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x06\x0F\x92PPPV[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x02\xF1\x90\x82\x90a\x07\x7FV[\x90PP\x91\x90PV[_\x81`@Q` \x01a\x03\x0B\x91\x90a\x11[V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[a\x030a\x07\xE6V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[_\x81`@Q` \x01a\x03\x0B\x91\x90a\x12\x89V[\x80Q`\xC0\x81\x01QQ``\x91\x90`N\x02`\x83\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x03\xBCWa\x03\xBCa\n\xF6V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x03\xE6W` \x82\x01\x81\x806\x837\x01\x90P[P\x82Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x84\x01Q`&\x83\x01R`@\x84\x01Q`F\x83\x01R``\x80\x85\x01Q\x90\x1B`f\x83\x01R`\x80\x80\x85\x01Q\x90\x91\x1B`z\x83\x01R`\xA0\x80\x85\x01Q\x91\x83\x01\x91\x90\x91R`\xC0\x84\x01QQ\x91\x94P\x84\x01\x90a\x04F\x90a\x07\x8BV[`\xC0\x83\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x83`\xC0\x01QQ\x81\x10\x15a\x04\x94Wa\x04\x8A\x82\x85`\xC0\x01Q\x83\x81Q\x81\x10a\x04}Wa\x04}a\x13MV[` \x02` \x01\x01Qa\x07\xB1V[\x91P`\x01\x01a\x04VV[Pa\x04\xAF\x81\x86` \x01Qa\x04\xA8W_a\x07\x7FV[`\x01a\x07\x7FV[PPPP\x91\x90PV[`\xC0\x81\x01Q\x80Q_\x91\x90`\t`\x04\x82\x02\x01\x83a\x04\xE4\x82`@\x80Q\x82\x81R`\x01\x90\x92\x01`\x05\x1B\x82\x01\x90R\x90V[` \x80\x82\x01R\x90P\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\x80\x82\x01R``\x86\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\xA0\x82\x01R`\x80\x86\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xC0\x82\x01R`\xA0\x86\x01Q`\xE0\x82\x01R`\xE0a\x01\0\x82\x01Ra\x01 \x81\x01\x83\x90R`\t_[\x84\x81\x10\x15a\x05\xDDW_\x86\x82\x81Q\x81\x10a\x05mWa\x05ma\x13MV[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16`\x01\x85\x01`\x05\x1B\x86\x01R\x90P` \x81\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x02\x84\x01`\x05\x1B\x85\x01R`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x84\x01`\x05\x1B\x85\x01R``\x81\x01Q`\x04\x84\x01`\x05\x1B\x85\x01RP`\x04\x91\x90\x91\x01\x90`\x01\x01a\x05RV[P\x81Q`\x05\x1B` \x83\x01 a\x06\x04\x83\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x97\x96PPPPPPPV[a\x06\x17a\x08\x1DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q\x90\x92\x01\x91\x90\x91R`F\x83\x01Q\x82Q`@\x01R`f\x83\x01Q\x82Q``\x91\x82\x1C\x91\x01R`z\x83\x01Q\x82Q\x91\x1C`\x80\x91\x82\x01R\x82\x01Q\x81Q`\xA0\x90\x81\x01\x91\x90\x91R\x82\x01Q`\xA2\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x8EWa\x06\x8Ea\n\xF6V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x06\xDEW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x06\xACW\x90P[P\x83Q`\xC0\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x07mW`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x92\x83R\x87Q\x81\x1C\x84R`\x14\x88\x01Q\x90\x1C\x90\x93R`(\x86\x01Q`\xD0\x1C\x90\x92R`.\x85\x01Q\x90\x91R`N\x84\x01\x85Q`\xC0\x01Q\x80Q\x84\x90\x81\x10a\x07UWa\x07Ua\x13MV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x06\xE7V[PPQ`\xF8\x1C\x15\x15` \x82\x01R\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x07\xAEW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q``\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x14\x84\x01R`@\x82\x01Q`\xD0\x1B`(\x84\x01R\x81\x01Q`.\x83\x01\x90\x81R`N\x83\x01a\x01\xFEV[`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90[\x81R_` \x90\x91\x01R\x90V[`@Q\x80`@\x01`@R\x80a\x08\x11`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01``\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a\x08\x8CW__\xFD[P\x90\x92\x91PPV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_`\x80\x82\x84\x03\x12\x80\x15a\x08\x8CW__\xFD[__` \x83\x85\x03\x12\x15a\x08\xEBW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\0W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\t\x10W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\t%W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\t6W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_` \x82\x84\x03\x12\x15a\tVW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\tkW__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_` \x82\x84\x03\x12\x15a\t\x8DW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xA2W__\xFD[\x82\x01`@\x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_` \x82\x84\x03\x12\x15a\t\xC3W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xD8W__\xFD[\x82\x01`\xE0\x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a\nRW\x81Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x88R` \x80\x83\x01Q\x90\x91\x16\x81\x89\x01R`@\x80\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x89\x01R``\x91\x82\x01Q\x91\x88\x01\x91\x90\x91R`\x80\x90\x96\x01\x95\x90\x91\x01\x90`\x01\x01a\t\xFBV[P\x93\x94\x93PPPPV[` \x81R_\x82Q`@` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16``\x84\x01R` \x81\x01Q`\x80\x84\x01R`@\x81\x01Q`\xA0\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16`\xC0\x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x82\x01Q\x16`\xE0\x84\x01R`\xA0\x81\x01Qa\x01\0\x84\x01R`\xC0\x81\x01Q\x90P`\xE0a\x01 \x84\x01Ra\n\xD9a\x01@\x84\x01\x82a\t\xE9V[\x90P` \x84\x01Qa\n\xEE`@\x85\x01\x82\x15\x15\x90RV[P\x93\x92PPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@R\x90V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Qa\x01 \x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B\xE3Wa\x0B\xE3a\n\xF6V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x805`\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x0CJW__\xFD[Pa\x0CSa\x0B\nV[a\x0C\\\x84a\x0B\xEBV[\x81R```\x1F\x19\x83\x01\x12\x15a\x0CoW__\xFD[a\x0Cwa\x0B\nV[\x91Pa\x0C\x85` \x85\x01a\x0C\x05V[\x82Ra\x0C\x93`@\x85\x01a\x0C\x05V[` \x83\x01Ra\x0C\xA4``\x85\x01a\x0C\x16V[`@\x83\x01R\x81` \x82\x01Ra\x0C\xBB`\x80\x85\x01a\x0C(V[`@\x82\x01R\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0C\0W__\xFD[_`\x80\x82\x84\x03\x12\x80\x15a\x0C\xEFW__\xFD[Pa\x0C\xF8a\x0B2V[a\r\x01\x83a\x0B\xEBV[\x81R` \x83\x015`\x02\x81\x10a\r\x14W__\xFD[` \x82\x01Ra\r%`@\x84\x01a\x0C\xC8V[`@\x82\x01Ra\r6``\x84\x01a\x0C\xC8V[``\x82\x01R\x93\x92PPPV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\rZWa\rZa\n\xF6V[P`\x05\x1B` \x01\x90V[\x805\x80\x15\x15\x81\x14a\x0C\0W__\xFD[_\x82`\x1F\x83\x01\x12a\r\x82W__\xFD[\x815a\r\x95a\r\x90\x82a\rBV[a\x0B\xBBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a\r\xB6W__\xFD[` \x85\x01[\x83\x81\x10\x15a\x0E\xF6W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\r\xD8W__\xFD[\x86\x01`@\x81\x89\x03`\x1F\x19\x01\x12\x15a\r\xEDW__\xFD[a\r\xF5a\x0BTV[a\x0E\x01` \x83\x01a\rdV[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E\x1BW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8A\x03\x12\x15a\x0E3W__\xFD[a\x0E;a\x0B\nV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0EPW__\xFD[\x83\x01`\x1F\x81\x01\x8B\x13a\x0E`W__\xFD[\x805a\x0Ena\r\x90\x82a\rBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8D\x83\x11\x15a\x0E\x8FW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x0E\xB1W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a\x0E\x96V[\x84RPa\x0E\xC3\x91PP` \x84\x01a\x0C\x16V[` \x82\x01Ra\x0E\xD4`@\x84\x01a\x0B\xEBV[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa\r\xBBV[P\x95\x94PPPPPV[_a\x01 \x826\x03\x12\x15a\x0F\x11W__\xFD[a\x0F\x19a\x0BvV[a\x0F\"\x83a\x0B\xEBV[\x81Ra\x0F0` \x84\x01a\x0B\xEBV[` \x82\x01Ra\x0FA`@\x84\x01a\x0B\xEBV[`@\x82\x01Ra\x0FR``\x84\x01a\x0C\xC8V[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01Ra\x0Fm`\xA0\x84\x01a\x0B\xEBV[`\xA0\x82\x01R`\xC0\x83\x81\x015\x90\x82\x01Ra\x0F\x88`\xE0\x84\x01a\x0C(V[`\xE0\x82\x01Ra\x01\0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0F\xA6W__\xFD[a\x0F\xB26\x82\x86\x01a\rsV[a\x01\0\x83\x01RP\x92\x91PPV[_\x82`\x1F\x83\x01\x12a\x0F\xCEW__\xFD[\x815a\x0F\xDCa\r\x90\x82a\rBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a\x0F\xFDW__\xFD[` \x85\x01[\x83\x81\x10\x15a\x0E\xF6W`\x80\x81\x88\x03\x12\x15a\x10\x19W__\xFD[a\x10!a\x0B2V[a\x10*\x82a\x0C\xC8V[\x81Ra\x108` \x83\x01a\x0C\xC8V[` \x82\x01Ra\x10I`@\x83\x01a\x0B\xEBV[`@\x82\x01R``\x82\x81\x015\x90\x82\x01R\x83R` \x90\x92\x01\x91`\x80\x01a\x10\x02V[_`\xE0\x82\x84\x03\x12\x15a\x10xW__\xFD[a\x10\x80a\x0B\x99V[\x90Pa\x10\x8B\x82a\x0B\xEBV[\x81R` \x82\x81\x015\x90\x82\x01R`@\x80\x83\x015\x90\x82\x01Ra\x10\xAD``\x83\x01a\x0C\xC8V[``\x82\x01Ra\x10\xBE`\x80\x83\x01a\x0B\xEBV[`\x80\x82\x01R`\xA0\x82\x81\x015\x90\x82\x01R`\xC0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x10\xE5W__\xFD[a\x10\xF1\x84\x82\x85\x01a\x0F\xBFV[`\xC0\x83\x01RP\x92\x91PPV[_`@\x826\x03\x12\x15a\x11\rW__\xFD[a\x11\x15a\x0BTV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x11*W__\xFD[a\x1166\x82\x86\x01a\x10hV[\x82RPa\x11E` \x84\x01a\rdV[` \x82\x01R\x92\x91PPV[_a\x01\x9A6\x83a\x10hV[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x82\x01Q`\x80\x82\x01\x90`\x02\x81\x10a\x11\x8DWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x83\x01R`@\x83\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x84\x01\x91\x90\x91R``\x93\x84\x01Q\x16\x92\x90\x91\x01\x91\x90\x91R\x90V[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a\x12}W\x84\x83\x03`\x1F\x19\x01\x88R\x81Q\x80Q\x15\x15\x84R` \x90\x81\x01Q`@\x82\x86\x01\x81\x90R\x81Q``\x91\x87\x01\x91\x90\x91R\x80Q`\xA0\x87\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x87\x01\x90[\x80\x83\x10\x15a\x12BW\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x12\x1FV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x89\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x97\x01\x96\x90\x96RPP\x97\x88\x01\x97\x91\x90\x91\x01\x90`\x01\x01a\x11\xD8V[P\x90\x96\x95PPPPPPV[` \x81Ra\x12\xA2` \x82\x01\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[_` \x83\x01Qa\x12\xBC`@\x84\x01\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[P`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16``\x84\x01RP``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x81\x16`\x80\x84\x01RP`\x80\x83\x01Q`\xA0\x83\x01R`\xA0\x83\x01Qa\x13\t`\xC0\x84\x01\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[P`\xC0\x83\x01Q`\xE0\x83\x01R`\xE0\x83\x01Qa\x13)a\x01\0\x84\x01\x82`\xFF\x16\x90RV[Pa\x01\0\x83\x01Qa\x01 \x80\x84\x01Ra\x13Ea\x01@\x84\x01\x82a\x11\xBCV[\x94\x93PPPPV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xA2dipfsX\"\x12 \xDFj\x1DX\xBC\x12\x06;\xF3\xE3\x9C\x931\xC6\xBD\x84c\x13\x15N\x98;G\xE1\xCB\xB4\xC3\xA1O\x89\xA1\xD2dsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b506004361061007a575f3560e01c8063b28e824e11610058578063b28e824e14610128578063c3d3e2f41461013b578063cbc148c31461014e578063edbacd4414610161575f5ffd5b80632f1969b01461007e5780635a213615146100a7578063afb63ad4146100c8575b5f5ffd5b61009161008c36600461087b565b610181565b60405161009e9190610894565b60405180910390f35b6100ba6100b53660046108c9565b6101a0565b60405190815260200161009e565b6100db6100d63660046108da565b6101b8565b60408051825165ffffffffffff168152602080840151805161ffff90811683850152918101519091168284015282015162ffffff16606082015291015160ff16608082015260a00161009e565b6100ba610136366004610946565b610205565b61009161014936600461097d565b610217565b6100ba61015c3660046109b3565b61022a565b61017461016f3660046108da565b61023c565b60405161009e9190610a5c565b606061019a61019536849003840184610c38565b610282565b92915050565b5f61019a6101b336849003840184610cde565b6102f9565b6101c06107e6565b6101fe83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061032892505050565b9392505050565b5f61019a61021283610f00565b610380565b606061019a610225836110fd565b610392565b5f61019a61023783611150565b6104b8565b61024461081d565b6101fe83838080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061060f92505050565b60408051600e8082528183019092526060916020820181803683375050835160d01b60208084019190915284810180515160f090811b602686015281519092015190911b60288401525160409081015160e81b602a84015284015191925050602d8201906102f190829061077f565b905050919050565b5f8160405160200161030b919061115b565b604051602081830303815290604052805190602001209050919050565b6103306107e6565b60208281015160d01c82526026830151828201805160f092831c905260288501518151921c9190920152602a830151905160e89190911c604091820152602d9092015160f81c9181019190915290565b5f8160405160200161030b9190611289565b805160c08101515160609190604e02608301806001600160401b038111156103bc576103bc610af6565b6040519080825280601f01601f1916602001820160405280156103e6576020820181803683370190505b50825160d090811b602083810191909152840151602683015260408401516046830152606080850151901b606683015260808085015190911b607a83015260a0808501519183019190915260c0840151519194508401906104469061078b565b60c08301515160f01b81526002015f5b8360c00151518110156104945761048a828560c00151838151811061047d5761047d61134d565b60200260200101516107b1565b9150600101610456565b506104af8186602001516104a8575f61077f565b600161077f565b50505050919050565b60c081015180515f919060096004820201836104e48260408051828152600190920160051b8201905290565b6020808201529050855165ffffffffffff166040820152602086015160608201526040860151608082015260608601516001600160a01b031660a0820152608086015165ffffffffffff1660c082015260a086015160e082015260e0610100820152610120810183905260095f5b848110156105dd575f86828151811061056d5761056d61134d565b602090810291909101015180516001600160a01b03166001850160051b860152905060208101516001600160a01b03166002840160051b850152604081015165ffffffffffff166003840160051b85015260608101516004840160051b8501525060049190910190600101610552565b50815160051b60208301206106048380516040516001820160051b83011490151060061b52565b979650505050505050565b61061761081d565b602082810151825160d091821c90526026840151835190920191909152604683015182516040015260668301518251606091821c910152607a8301518251911c608091820152820151815160a09081019190915282015160a283019060f01c806001600160401b0381111561068e5761068e610af6565b6040519080825280602002602001820160405280156106de57816020015b604080516080810182525f8082526020808301829052928201819052606082015282525f199092019101816106ac5790505b50835160c001525f5b8161ffff1681101561076d57604080516080810182525f8082526020820181815292820181815260608084019283528751811c84526014880151901c909352602886015160d01c909252602e850151909152604e8401855160c001518051849081106107555761075561134d565b602090810291909101019190915292506001016106e7565b50505160f81c15156020820152919050565b5f818353505060010190565b61ffff8111156107ae5760405163161e7a6b60e11b815260040160405180910390fd5b50565b8051606090811b83526020820151811b6014840152604082015160d01b6028840152810151602e8301908152604e83016101fe565b60408051606080820183525f8083528351918201845280825260208281018290529382015290918201905b81525f60209091015290565b60405180604001604052806108116040518060e001604052805f65ffffffffffff1681526020015f81526020015f81526020015f6001600160a01b031681526020015f65ffffffffffff1681526020015f8152602001606081525090565b5f60a082840312801561088c575f5ffd5b509092915050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f608082840312801561088c575f5ffd5b5f5f602083850312156108eb575f5ffd5b82356001600160401b03811115610900575f5ffd5b8301601f81018513610910575f5ffd5b80356001600160401b03811115610925575f5ffd5b856020828401011115610936575f5ffd5b6020919091019590945092505050565b5f60208284031215610956575f5ffd5b81356001600160401b0381111561096b575f5ffd5b820161012081850312156101fe575f5ffd5b5f6020828403121561098d575f5ffd5b81356001600160401b038111156109a2575f5ffd5b8201604081850312156101fe575f5ffd5b5f602082840312156109c3575f5ffd5b81356001600160401b038111156109d8575f5ffd5b820160e081850312156101fe575f5ffd5b5f8151808452602084019350602083015f5b82811015610a5257815180516001600160a01b0390811688526020808301519091168189015260408083015165ffffffffffff169089015260609182015191880191909152608090960195909101906001016109fb565b5093949350505050565b602081525f82516040602084015265ffffffffffff815116606084015260208101516080840152604081015160a084015260018060a01b0360608201511660c084015265ffffffffffff60808201511660e084015260a081015161010084015260c0810151905060e0610120840152610ad96101408401826109e9565b90506020840151610aee604085018215159052565b509392505050565b634e487b7160e01b5f52604160045260245ffd5b604051606081016001600160401b0381118282101715610b2c57610b2c610af6565b60405290565b604051608081016001600160401b0381118282101715610b2c57610b2c610af6565b604080519081016001600160401b0381118282101715610b2c57610b2c610af6565b60405161012081016001600160401b0381118282101715610b2c57610b2c610af6565b60405160e081016001600160401b0381118282101715610b2c57610b2c610af6565b604051601f8201601f191681016001600160401b0381118282101715610be357610be3610af6565b604052919050565b803565ffffffffffff81168114610c00575f5ffd5b919050565b803561ffff81168114610c00575f5ffd5b803562ffffff81168114610c00575f5ffd5b803560ff81168114610c00575f5ffd5b5f81830360a081128015610c4a575f5ffd5b50610c53610b0a565b610c5c84610beb565b81526060601f1983011215610c6f575f5ffd5b610c77610b0a565b9150610c8560208501610c05565b8252610c9360408501610c05565b6020830152610ca460608501610c16565b6040830152816020820152610cbb60808501610c28565b6040820152949350505050565b80356001600160a01b0381168114610c00575f5ffd5b5f6080828403128015610cef575f5ffd5b50610cf8610b32565b610d0183610beb565b8152602083013560028110610d14575f5ffd5b6020820152610d2560408401610cc8565b6040820152610d3660608401610cc8565b60608201529392505050565b5f6001600160401b03821115610d5a57610d5a610af6565b5060051b60200190565b80358015158114610c00575f5ffd5b5f82601f830112610d82575f5ffd5b8135610d95610d9082610d42565b610bbb565b8082825260208201915060208360051b860101925085831115610db6575f5ffd5b602085015b83811015610ef65780356001600160401b03811115610dd8575f5ffd5b86016040818903601f19011215610ded575f5ffd5b610df5610b54565b610e0160208301610d64565b815260408201356001600160401b03811115610e1b575f5ffd5b6020818401019250506060828a031215610e33575f5ffd5b610e3b610b0a565b82356001600160401b03811115610e50575f5ffd5b8301601f81018b13610e60575f5ffd5b8035610e6e610d9082610d42565b8082825260208201915060208360051b85010192508d831115610e8f575f5ffd5b6020840193505b82841015610eb1578335825260209384019390910190610e96565b845250610ec391505060208401610c16565b6020820152610ed460408401610beb565b6040820152806020830152508085525050602083019250602081019050610dbb565b5095945050505050565b5f6101208236031215610f11575f5ffd5b610f19610b76565b610f2283610beb565b8152610f3060208401610beb565b6020820152610f4160408401610beb565b6040820152610f5260608401610cc8565b606082015260808381013590820152610f6d60a08401610beb565b60a082015260c08381013590820152610f8860e08401610c28565b60e08201526101008301356001600160401b03811115610fa6575f5ffd5b610fb236828601610d73565b6101008301525092915050565b5f82601f830112610fce575f5ffd5b8135610fdc610d9082610d42565b8082825260208201915060208360071b860101925085831115610ffd575f5ffd5b602085015b83811015610ef65760808188031215611019575f5ffd5b611021610b32565b61102a82610cc8565b815261103860208301610cc8565b602082015261104960408301610beb565b6040820152606082810135908201528352602090920191608001611002565b5f60e08284031215611078575f5ffd5b611080610b99565b905061108b82610beb565b815260208281013590820152604080830135908201526110ad60608301610cc8565b60608201526110be60808301610beb565b608082015260a0828101359082015260c08201356001600160401b038111156110e5575f5ffd5b6110f184828501610fbf565b60c08301525092915050565b5f6040823603121561110d575f5ffd5b611115610b54565b82356001600160401b0381111561112a575f5ffd5b61113636828601611068565b82525061114560208401610d64565b602082015292915050565b5f61019a3683611068565b815165ffffffffffff168152602082015160808201906002811061118d57634e487b7160e01b5f52602160045260245ffd5b60208301526040838101516001600160a01b039081169184019190915260609384015116929091019190915290565b5f82825180855260208501945060208160051b830101602085015f5b8381101561127d57848303601f19018852815180511515845260209081015160408286018190528151606091870191909152805160a08701819052919201905f9060c08701905b80831015611242578351825260208201915060208401935060018301925061121f565b5060208481015162ffffff16606089015260409094015165ffffffffffff1660809097019690965250509788019791909101906001016111d8565b50909695505050505050565b602081526112a260208201835165ffffffffffff169052565b5f60208301516112bc604084018265ffffffffffff169052565b50604083015165ffffffffffff811660608401525060608301516001600160a01b038116608084015250608083015160a083015260a083015161130960c084018265ffffffffffff169052565b5060c083015160e083015260e083015161132961010084018260ff169052565b50610100830151610120808401526113456101408401826111bc565b949350505050565b634e487b7160e01b5f52603260045260245ffdfea2646970667358221220df6a1d58bc12063bf3e39c9331c6bd846313154e983b47e1cbb4c3a14f89a1d264736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\0zW_5`\xE0\x1C\x80c\xB2\x8E\x82N\x11a\0XW\x80c\xB2\x8E\x82N\x14a\x01(W\x80c\xC3\xD3\xE2\xF4\x14a\x01;W\x80c\xCB\xC1H\xC3\x14a\x01NW\x80c\xED\xBA\xCDD\x14a\x01aW__\xFD[\x80c/\x19i\xB0\x14a\0~W\x80cZ!6\x15\x14a\0\xA7W\x80c\xAF\xB6:\xD4\x14a\0\xC8W[__\xFD[a\0\x91a\0\x8C6`\x04a\x08{V[a\x01\x81V[`@Qa\0\x9E\x91\x90a\x08\x94V[`@Q\x80\x91\x03\x90\xF3[a\0\xBAa\0\xB56`\x04a\x08\xC9V[a\x01\xA0V[`@Q\x90\x81R` \x01a\0\x9EV[a\0\xDBa\0\xD66`\x04a\x08\xDAV[a\x01\xB8V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x80Qa\xFF\xFF\x90\x81\x16\x83\x85\x01R\x91\x81\x01Q\x90\x91\x16\x82\x84\x01R\x82\x01Qb\xFF\xFF\xFF\x16``\x82\x01R\x91\x01Q`\xFF\x16`\x80\x82\x01R`\xA0\x01a\0\x9EV[a\0\xBAa\x0166`\x04a\tFV[a\x02\x05V[a\0\x91a\x01I6`\x04a\t}V[a\x02\x17V[a\0\xBAa\x01\\6`\x04a\t\xB3V[a\x02*V[a\x01ta\x01o6`\x04a\x08\xDAV[a\x02<V[`@Qa\0\x9E\x91\x90a\n\\V[``a\x01\x9Aa\x01\x956\x84\x90\x03\x84\x01\x84a\x0C8V[a\x02\x82V[\x92\x91PPV[_a\x01\x9Aa\x01\xB36\x84\x90\x03\x84\x01\x84a\x0C\xDEV[a\x02\xF9V[a\x01\xC0a\x07\xE6V[a\x01\xFE\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x03(\x92PPPV[\x93\x92PPPV[_a\x01\x9Aa\x02\x12\x83a\x0F\0V[a\x03\x80V[``a\x01\x9Aa\x02%\x83a\x10\xFDV[a\x03\x92V[_a\x01\x9Aa\x027\x83a\x11PV[a\x04\xB8V[a\x02Da\x08\x1DV[a\x01\xFE\x83\x83\x80\x80`\x1F\x01` \x80\x91\x04\x02` \x01`@Q\x90\x81\x01`@R\x80\x93\x92\x91\x90\x81\x81R` \x01\x83\x83\x80\x82\x847_\x92\x01\x91\x90\x91RPa\x06\x0F\x92PPPV[`@\x80Q`\x0E\x80\x82R\x81\x83\x01\x90\x92R``\x91` \x82\x01\x81\x806\x837PP\x83Q`\xD0\x1B` \x80\x84\x01\x91\x90\x91R\x84\x81\x01\x80QQ`\xF0\x90\x81\x1B`&\x86\x01R\x81Q\x90\x92\x01Q\x90\x91\x1B`(\x84\x01RQ`@\x90\x81\x01Q`\xE8\x1B`*\x84\x01R\x84\x01Q\x91\x92PP`-\x82\x01\x90a\x02\xF1\x90\x82\x90a\x07\x7FV[\x90PP\x91\x90PV[_\x81`@Q` \x01a\x03\x0B\x91\x90a\x11[V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P\x91\x90PV[a\x030a\x07\xE6V[` \x82\x81\x01Q`\xD0\x1C\x82R`&\x83\x01Q\x82\x82\x01\x80Q`\xF0\x92\x83\x1C\x90R`(\x85\x01Q\x81Q\x92\x1C\x91\x90\x92\x01R`*\x83\x01Q\x90Q`\xE8\x91\x90\x91\x1C`@\x91\x82\x01R`-\x90\x92\x01Q`\xF8\x1C\x91\x81\x01\x91\x90\x91R\x90V[_\x81`@Q` \x01a\x03\x0B\x91\x90a\x12\x89V[\x80Q`\xC0\x81\x01QQ``\x91\x90`N\x02`\x83\x01\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x03\xBCWa\x03\xBCa\n\xF6V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a\x03\xE6W` \x82\x01\x81\x806\x837\x01\x90P[P\x82Q`\xD0\x90\x81\x1B` \x83\x81\x01\x91\x90\x91R\x84\x01Q`&\x83\x01R`@\x84\x01Q`F\x83\x01R``\x80\x85\x01Q\x90\x1B`f\x83\x01R`\x80\x80\x85\x01Q\x90\x91\x1B`z\x83\x01R`\xA0\x80\x85\x01Q\x91\x83\x01\x91\x90\x91R`\xC0\x84\x01QQ\x91\x94P\x84\x01\x90a\x04F\x90a\x07\x8BV[`\xC0\x83\x01QQ`\xF0\x1B\x81R`\x02\x01_[\x83`\xC0\x01QQ\x81\x10\x15a\x04\x94Wa\x04\x8A\x82\x85`\xC0\x01Q\x83\x81Q\x81\x10a\x04}Wa\x04}a\x13MV[` \x02` \x01\x01Qa\x07\xB1V[\x91P`\x01\x01a\x04VV[Pa\x04\xAF\x81\x86` \x01Qa\x04\xA8W_a\x07\x7FV[`\x01a\x07\x7FV[PPPP\x91\x90PV[`\xC0\x81\x01Q\x80Q_\x91\x90`\t`\x04\x82\x02\x01\x83a\x04\xE4\x82`@\x80Q\x82\x81R`\x01\x90\x92\x01`\x05\x1B\x82\x01\x90R\x90V[` \x80\x82\x01R\x90P\x85Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`@\x82\x01R` \x86\x01Q``\x82\x01R`@\x86\x01Q`\x80\x82\x01R``\x86\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\xA0\x82\x01R`\x80\x86\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\xC0\x82\x01R`\xA0\x86\x01Q`\xE0\x82\x01R`\xE0a\x01\0\x82\x01Ra\x01 \x81\x01\x83\x90R`\t_[\x84\x81\x10\x15a\x05\xDDW_\x86\x82\x81Q\x81\x10a\x05mWa\x05ma\x13MV[` \x90\x81\x02\x91\x90\x91\x01\x01Q\x80Q`\x01`\x01`\xA0\x1B\x03\x16`\x01\x85\x01`\x05\x1B\x86\x01R\x90P` \x81\x01Q`\x01`\x01`\xA0\x1B\x03\x16`\x02\x84\x01`\x05\x1B\x85\x01R`@\x81\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x03\x84\x01`\x05\x1B\x85\x01R``\x81\x01Q`\x04\x84\x01`\x05\x1B\x85\x01RP`\x04\x91\x90\x91\x01\x90`\x01\x01a\x05RV[P\x81Q`\x05\x1B` \x83\x01 a\x06\x04\x83\x80Q`@Q`\x01\x82\x01`\x05\x1B\x83\x01\x14\x90\x15\x10`\x06\x1BRV[\x97\x96PPPPPPPV[a\x06\x17a\x08\x1DV[` \x82\x81\x01Q\x82Q`\xD0\x91\x82\x1C\x90R`&\x84\x01Q\x83Q\x90\x92\x01\x91\x90\x91R`F\x83\x01Q\x82Q`@\x01R`f\x83\x01Q\x82Q``\x91\x82\x1C\x91\x01R`z\x83\x01Q\x82Q\x91\x1C`\x80\x91\x82\x01R\x82\x01Q\x81Q`\xA0\x90\x81\x01\x91\x90\x91R\x82\x01Q`\xA2\x83\x01\x90`\xF0\x1C\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a\x06\x8EWa\x06\x8Ea\n\xF6V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a\x06\xDEW\x81` \x01[`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x80\x83\x01\x82\x90R\x92\x82\x01\x81\x90R``\x82\x01R\x82R_\x19\x90\x92\x01\x91\x01\x81a\x06\xACW\x90P[P\x83Q`\xC0\x01R_[\x81a\xFF\xFF\x16\x81\x10\x15a\x07mW`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x81R\x92\x82\x01\x81\x81R``\x80\x84\x01\x92\x83R\x87Q\x81\x1C\x84R`\x14\x88\x01Q\x90\x1C\x90\x93R`(\x86\x01Q`\xD0\x1C\x90\x92R`.\x85\x01Q\x90\x91R`N\x84\x01\x85Q`\xC0\x01Q\x80Q\x84\x90\x81\x10a\x07UWa\x07Ua\x13MV[` \x90\x81\x02\x91\x90\x91\x01\x01\x91\x90\x91R\x92P`\x01\x01a\x06\xE7V[PPQ`\xF8\x1C\x15\x15` \x82\x01R\x91\x90PV[_\x81\x83SPP`\x01\x01\x90V[a\xFF\xFF\x81\x11\x15a\x07\xAEW`@Qc\x16\x1Ezk`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[PV[\x80Q``\x90\x81\x1B\x83R` \x82\x01Q\x81\x1B`\x14\x84\x01R`@\x82\x01Q`\xD0\x1B`(\x84\x01R\x81\x01Q`.\x83\x01\x90\x81R`N\x83\x01a\x01\xFEV[`@\x80Q``\x80\x82\x01\x83R_\x80\x83R\x83Q\x91\x82\x01\x84R\x80\x82R` \x82\x81\x01\x82\x90R\x93\x82\x01R\x90\x91\x82\x01\x90[\x81R_` \x90\x91\x01R\x90V[`@Q\x80`@\x01`@R\x80a\x08\x11`@Q\x80`\xE0\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81R` \x01_`\x01`\x01`\xA0\x1B\x03\x16\x81R` \x01_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01``\x81RP\x90V[_`\xA0\x82\x84\x03\x12\x80\x15a\x08\x8CW__\xFD[P\x90\x92\x91PPV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV[_`\x80\x82\x84\x03\x12\x80\x15a\x08\x8CW__\xFD[__` \x83\x85\x03\x12\x15a\x08\xEBW__\xFD[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\0W__\xFD[\x83\x01`\x1F\x81\x01\x85\x13a\t\x10W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\t%W__\xFD[\x85` \x82\x84\x01\x01\x11\x15a\t6W__\xFD[` \x91\x90\x91\x01\x95\x90\x94P\x92PPPV[_` \x82\x84\x03\x12\x15a\tVW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\tkW__\xFD[\x82\x01a\x01 \x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_` \x82\x84\x03\x12\x15a\t\x8DW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xA2W__\xFD[\x82\x01`@\x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_` \x82\x84\x03\x12\x15a\t\xC3W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\t\xD8W__\xFD[\x82\x01`\xE0\x81\x85\x03\x12\x15a\x01\xFEW__\xFD[_\x81Q\x80\x84R` \x84\x01\x93P` \x83\x01_[\x82\x81\x10\x15a\nRW\x81Q\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x88R` \x80\x83\x01Q\x90\x91\x16\x81\x89\x01R`@\x80\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90\x89\x01R``\x91\x82\x01Q\x91\x88\x01\x91\x90\x91R`\x80\x90\x96\x01\x95\x90\x91\x01\x90`\x01\x01a\t\xFBV[P\x93\x94\x93PPPPV[` \x81R_\x82Q`@` \x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF\x81Q\x16``\x84\x01R` \x81\x01Q`\x80\x84\x01R`@\x81\x01Q`\xA0\x84\x01R`\x01\x80`\xA0\x1B\x03``\x82\x01Q\x16`\xC0\x84\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`\x80\x82\x01Q\x16`\xE0\x84\x01R`\xA0\x81\x01Qa\x01\0\x84\x01R`\xC0\x81\x01Q\x90P`\xE0a\x01 \x84\x01Ra\n\xD9a\x01@\x84\x01\x82a\t\xE9V[\x90P` \x84\x01Qa\n\xEE`@\x85\x01\x82\x15\x15\x90RV[P\x93\x92PPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q``\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@R\x90V[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@\x80Q\x90\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Qa\x01 \x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Q`\xE0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B,Wa\x0B,a\n\xF6V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x0B\xE3Wa\x0B\xE3a\n\xF6V[`@R\x91\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x91\x90PV[\x805a\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x805b\xFF\xFF\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[\x805`\xFF\x81\x16\x81\x14a\x0C\0W__\xFD[_\x81\x83\x03`\xA0\x81\x12\x80\x15a\x0CJW__\xFD[Pa\x0CSa\x0B\nV[a\x0C\\\x84a\x0B\xEBV[\x81R```\x1F\x19\x83\x01\x12\x15a\x0CoW__\xFD[a\x0Cwa\x0B\nV[\x91Pa\x0C\x85` \x85\x01a\x0C\x05V[\x82Ra\x0C\x93`@\x85\x01a\x0C\x05V[` \x83\x01Ra\x0C\xA4``\x85\x01a\x0C\x16V[`@\x83\x01R\x81` \x82\x01Ra\x0C\xBB`\x80\x85\x01a\x0C(V[`@\x82\x01R\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x0C\0W__\xFD[_`\x80\x82\x84\x03\x12\x80\x15a\x0C\xEFW__\xFD[Pa\x0C\xF8a\x0B2V[a\r\x01\x83a\x0B\xEBV[\x81R` \x83\x015`\x02\x81\x10a\r\x14W__\xFD[` \x82\x01Ra\r%`@\x84\x01a\x0C\xC8V[`@\x82\x01Ra\r6``\x84\x01a\x0C\xC8V[``\x82\x01R\x93\x92PPPV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a\rZWa\rZa\n\xF6V[P`\x05\x1B` \x01\x90V[\x805\x80\x15\x15\x81\x14a\x0C\0W__\xFD[_\x82`\x1F\x83\x01\x12a\r\x82W__\xFD[\x815a\r\x95a\r\x90\x82a\rBV[a\x0B\xBBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a\r\xB6W__\xFD[` \x85\x01[\x83\x81\x10\x15a\x0E\xF6W\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\r\xD8W__\xFD[\x86\x01`@\x81\x89\x03`\x1F\x19\x01\x12\x15a\r\xEDW__\xFD[a\r\xF5a\x0BTV[a\x0E\x01` \x83\x01a\rdV[\x81R`@\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0E\x1BW__\xFD[` \x81\x84\x01\x01\x92PP``\x82\x8A\x03\x12\x15a\x0E3W__\xFD[a\x0E;a\x0B\nV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0EPW__\xFD[\x83\x01`\x1F\x81\x01\x8B\x13a\x0E`W__\xFD[\x805a\x0Ena\r\x90\x82a\rBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x8D\x83\x11\x15a\x0E\x8FW__\xFD[` \x84\x01\x93P[\x82\x84\x10\x15a\x0E\xB1W\x835\x82R` \x93\x84\x01\x93\x90\x91\x01\x90a\x0E\x96V[\x84RPa\x0E\xC3\x91PP` \x84\x01a\x0C\x16V[` \x82\x01Ra\x0E\xD4`@\x84\x01a\x0B\xEBV[`@\x82\x01R\x80` \x83\x01RP\x80\x85RPP` \x83\x01\x92P` \x81\x01\x90Pa\r\xBBV[P\x95\x94PPPPPV[_a\x01 \x826\x03\x12\x15a\x0F\x11W__\xFD[a\x0F\x19a\x0BvV[a\x0F\"\x83a\x0B\xEBV[\x81Ra\x0F0` \x84\x01a\x0B\xEBV[` \x82\x01Ra\x0FA`@\x84\x01a\x0B\xEBV[`@\x82\x01Ra\x0FR``\x84\x01a\x0C\xC8V[``\x82\x01R`\x80\x83\x81\x015\x90\x82\x01Ra\x0Fm`\xA0\x84\x01a\x0B\xEBV[`\xA0\x82\x01R`\xC0\x83\x81\x015\x90\x82\x01Ra\x0F\x88`\xE0\x84\x01a\x0C(V[`\xE0\x82\x01Ra\x01\0\x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x0F\xA6W__\xFD[a\x0F\xB26\x82\x86\x01a\rsV[a\x01\0\x83\x01RP\x92\x91PPV[_\x82`\x1F\x83\x01\x12a\x0F\xCEW__\xFD[\x815a\x0F\xDCa\r\x90\x82a\rBV[\x80\x82\x82R` \x82\x01\x91P` \x83`\x07\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a\x0F\xFDW__\xFD[` \x85\x01[\x83\x81\x10\x15a\x0E\xF6W`\x80\x81\x88\x03\x12\x15a\x10\x19W__\xFD[a\x10!a\x0B2V[a\x10*\x82a\x0C\xC8V[\x81Ra\x108` \x83\x01a\x0C\xC8V[` \x82\x01Ra\x10I`@\x83\x01a\x0B\xEBV[`@\x82\x01R``\x82\x81\x015\x90\x82\x01R\x83R` \x90\x92\x01\x91`\x80\x01a\x10\x02V[_`\xE0\x82\x84\x03\x12\x15a\x10xW__\xFD[a\x10\x80a\x0B\x99V[\x90Pa\x10\x8B\x82a\x0B\xEBV[\x81R` \x82\x81\x015\x90\x82\x01R`@\x80\x83\x015\x90\x82\x01Ra\x10\xAD``\x83\x01a\x0C\xC8V[``\x82\x01Ra\x10\xBE`\x80\x83\x01a\x0B\xEBV[`\x80\x82\x01R`\xA0\x82\x81\x015\x90\x82\x01R`\xC0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x10\xE5W__\xFD[a\x10\xF1\x84\x82\x85\x01a\x0F\xBFV[`\xC0\x83\x01RP\x92\x91PPV[_`@\x826\x03\x12\x15a\x11\rW__\xFD[a\x11\x15a\x0BTV[\x825`\x01`\x01`@\x1B\x03\x81\x11\x15a\x11*W__\xFD[a\x1166\x82\x86\x01a\x10hV[\x82RPa\x11E` \x84\x01a\rdV[` \x82\x01R\x92\x91PPV[_a\x01\x9A6\x83a\x10hV[\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x82\x01Q`\x80\x82\x01\x90`\x02\x81\x10a\x11\x8DWcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[` \x83\x01R`@\x83\x81\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16\x91\x84\x01\x91\x90\x91R``\x93\x84\x01Q\x16\x92\x90\x91\x01\x91\x90\x91R\x90V[_\x82\x82Q\x80\x85R` \x85\x01\x94P` \x81`\x05\x1B\x83\x01\x01` \x85\x01_[\x83\x81\x10\x15a\x12}W\x84\x83\x03`\x1F\x19\x01\x88R\x81Q\x80Q\x15\x15\x84R` \x90\x81\x01Q`@\x82\x86\x01\x81\x90R\x81Q``\x91\x87\x01\x91\x90\x91R\x80Q`\xA0\x87\x01\x81\x90R\x91\x92\x01\x90_\x90`\xC0\x87\x01\x90[\x80\x83\x10\x15a\x12BW\x83Q\x82R` \x82\x01\x91P` \x84\x01\x93P`\x01\x83\x01\x92Pa\x12\x1FV[P` \x84\x81\x01Qb\xFF\xFF\xFF\x16``\x89\x01R`@\x90\x94\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16`\x80\x90\x97\x01\x96\x90\x96RPP\x97\x88\x01\x97\x91\x90\x91\x01\x90`\x01\x01a\x11\xD8V[P\x90\x96\x95PPPPPPV[` \x81Ra\x12\xA2` \x82\x01\x83Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[_` \x83\x01Qa\x12\xBC`@\x84\x01\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[P`@\x83\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16``\x84\x01RP``\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x81\x16`\x80\x84\x01RP`\x80\x83\x01Q`\xA0\x83\x01R`\xA0\x83\x01Qa\x13\t`\xC0\x84\x01\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x90RV[P`\xC0\x83\x01Q`\xE0\x83\x01R`\xE0\x83\x01Qa\x13)a\x01\0\x84\x01\x82`\xFF\x16\x90RV[Pa\x01\0\x83\x01Qa\x01 \x80\x84\x01Ra\x13Ea\x01@\x84\x01\x82a\x11\xBCV[\x94\x93PPPPV[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD\xFE\xA2dipfsX\"\x12 \xDFj\x1DX\xBC\x12\x06;\xF3\xE3\x9C\x931\xC6\xBD\x84c\x13\x15N\x98;G\xE1\xCB\xB4\xC3\xA1O\x89\xA1\xD2dsolcC\0\x08\x1E\x003",
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
    /**Function with signature `encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool))` and selector `0xc3d3e2f4`.
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
    ///Container type for the return parameters of the [`encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool))`](encodeProveInputCall) function.
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
            const SIGNATURE: &'static str = "encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool))";
            const SELECTOR: [u8; 4] = [195u8, 211u8, 226u8, 244u8];
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
    #[derive()]
    /**Function with signature `hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]))` and selector `0xcbc148c3`.
```solidity
function hashCommitment(IInbox.Commitment memory _commitment) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCommitmentCall {
        #[allow(missing_docs)]
        pub _commitment: <IInbox::Commitment as alloy::sol_types::SolType>::RustType,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]))`](hashCommitmentCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct hashCommitmentReturn {
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
            type UnderlyingSolTuple<'a> = (IInbox::Commitment,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <IInbox::Commitment as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<hashCommitmentCall> for UnderlyingRustTuple<'_> {
                fn from(value: hashCommitmentCall) -> Self {
                    (value._commitment,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for hashCommitmentCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _commitment: tuple.0 }
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
            impl ::core::convert::From<hashCommitmentReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: hashCommitmentReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for hashCommitmentReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for hashCommitmentCall {
            type Parameters<'a> = (IInbox::Commitment,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]))";
            const SELECTOR: [u8; 4] = [203u8, 193u8, 72u8, 195u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <IInbox::Commitment as alloy_sol_types::SolType>::tokenize(
                        &self._commitment,
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
                        let r: hashCommitmentReturn = r.into();
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
                        let r: hashCommitmentReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    /**Function with signature `hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))` and selector `0xb28e824e`.
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
    ///Container type for the return parameters of the [`hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))`](hashProposalCall) function.
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
            const SIGNATURE: &'static str = "hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]))";
            const SELECTOR: [u8; 4] = [178u8, 142u8, 130u8, 78u8];
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
    ///Container for all the [`Codec`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum CodecCalls {
        #[allow(missing_docs)]
        decodeProposeInput(decodeProposeInputCall),
        #[allow(missing_docs)]
        decodeProveInput(decodeProveInputCall),
        #[allow(missing_docs)]
        encodeProposeInput(encodeProposeInputCall),
        #[allow(missing_docs)]
        encodeProveInput(encodeProveInputCall),
        #[allow(missing_docs)]
        hashBondInstruction(hashBondInstructionCall),
        #[allow(missing_docs)]
        hashCommitment(hashCommitmentCall),
        #[allow(missing_docs)]
        hashProposal(hashProposalCall),
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
            [47u8, 25u8, 105u8, 176u8],
            [90u8, 33u8, 54u8, 21u8],
            [175u8, 182u8, 58u8, 212u8],
            [178u8, 142u8, 130u8, 78u8],
            [195u8, 211u8, 226u8, 244u8],
            [203u8, 193u8, 72u8, 195u8],
            [237u8, 186u8, 205u8, 68u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for CodecCalls {
        const NAME: &'static str = "CodecCalls";
        const MIN_DATA_LENGTH: usize = 32usize;
        const COUNT: usize = 7usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::decodeProposeInput(_) => {
                    <decodeProposeInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::decodeProveInput(_) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProposeInput(_) => {
                    <encodeProposeInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::encodeProveInput(_) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashBondInstruction(_) => {
                    <hashBondInstructionCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashCommitment(_) => {
                    <hashCommitmentCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::hashProposal(_) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::SELECTOR
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
                    fn hashProposal(data: &[u8]) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashProposal)
                    }
                    hashProposal
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
                    fn hashCommitment(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashCommitmentCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(CodecCalls::hashCommitment)
                    }
                    hashCommitment
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
                    fn hashProposal(data: &[u8]) -> alloy_sol_types::Result<CodecCalls> {
                        <hashProposalCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashProposal)
                    }
                    hashProposal
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
                    fn hashCommitment(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<CodecCalls> {
                        <hashCommitmentCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(CodecCalls::hashCommitment)
                    }
                    hashCommitment
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
                Self::decodeProveInput(inner) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProposeInput(inner) => {
                    <encodeProposeInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::encodeProveInput(inner) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashBondInstruction(inner) => {
                    <hashBondInstructionCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashCommitment(inner) => {
                    <hashCommitmentCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::hashProposal(inner) => {
                    <hashProposalCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::decodeProveInput(inner) => {
                    <decodeProveInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::encodeProveInput(inner) => {
                    <encodeProveInputCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::hashCommitment(inner) => {
                    <hashCommitmentCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
        ///Creates a new call builder for the [`decodeProveInput`] function.
        pub fn decodeProveInput(
            &self,
            _data: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, decodeProveInputCall, N> {
            self.call_builder(&decodeProveInputCall { _data })
        }
        ///Creates a new call builder for the [`encodeProposeInput`] function.
        pub fn encodeProposeInput(
            &self,
            _input: <IInbox::ProposeInput as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProposeInputCall, N> {
            self.call_builder(&encodeProposeInputCall { _input })
        }
        ///Creates a new call builder for the [`encodeProveInput`] function.
        pub fn encodeProveInput(
            &self,
            _input: <IInbox::ProveInput as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, encodeProveInputCall, N> {
            self.call_builder(&encodeProveInputCall { _input })
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
        ///Creates a new call builder for the [`hashCommitment`] function.
        pub fn hashCommitment(
            &self,
            _commitment: <IInbox::Commitment as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashCommitmentCall, N> {
            self.call_builder(&hashCommitmentCall { _commitment })
        }
        ///Creates a new call builder for the [`hashProposal`] function.
        pub fn hashProposal(
            &self,
            _proposal: <IInbox::Proposal as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, hashProposalCall, N> {
            self.call_builder(&hashProposalCall { _proposal })
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
