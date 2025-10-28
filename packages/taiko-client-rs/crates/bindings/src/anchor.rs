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
library LibBonds {
    type BondType is uint8;
    struct BondInstruction {
        uint48 proposalId;
        BondType bondType;
        address payer;
        address payee;
    }
}

interface Anchor {
    struct BlockParams {
        uint16 blockIndex;
        uint48 anchorBlockNumber;
        bytes32 anchorBlockHash;
        bytes32 anchorStateRoot;
    }
    struct BlockState {
        uint48 anchorBlockNumber;
        bytes32 ancestorsHash;
    }
    struct ProposalParams {
        uint48 proposalId;
        address proposer;
        bytes proverAuth;
        bytes32 bondInstructionsHash;
        LibBonds.BondInstruction[] bondInstructions;
    }
    struct ProposalState {
        bytes32 bondInstructionsHash;
        address designatedProver;
        bool isLowBondProposal;
    }
    struct ProverAuth {
        uint48 proposalId;
        address proposer;
        uint256 provingFee;
        bytes signature;
    }

    error AncestorsHashMismatch();
    error BondInstructionsHashMismatch();
    error ETH_TRANSFER_FAILED();
    error InvalidAddress();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error ZeroBlockCount();

    event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 anchorBlockNumber, bytes32 ancestorsHash);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawn(address token, address to, uint256 amount);

    constructor(address _checkpointStore, address _bondManager, uint256 _livenessBond, uint256 _provabilityBond, uint64 _l1ChainId, address _owner);

    function ANCHOR_GAS_LIMIT() external view returns (uint64);
    function GOLDEN_TOUCH_ADDRESS() external view returns (address);
    function _isMatchingProverAuthContext(ProverAuth memory _auth, uint48 _proposalId, address _proposer) external pure returns (bool);
    function acceptOwnership() external;
    function anchorV4(ProposalParams memory _proposalParams, BlockParams memory _blockParams) external;
    function bondManager() external view returns (address);
    function checkpointStore() external view returns (address);
    function getBlockState() external view returns (BlockState memory);
    function getDesignatedProver(uint48 _proposalId, address _proposer, bytes memory _proverAuth, address _currentDesignatedProver) external view returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_);
    function getProposalState() external view returns (ProposalState memory);
    function l1ChainId() external view returns (uint64);
    function livenessBond() external view returns (uint256);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function provabilityBond() external view returns (uint256);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function validateProverAuth(uint48 _proposalId, address _proposer, bytes memory _proverAuth) external pure returns (address signer_, uint256 provingFee_);
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
        "name": "_checkpointStore",
        "type": "address",
        "internalType": "contract ICheckpointStore"
      },
      {
        "name": "_bondManager",
        "type": "address",
        "internalType": "contract IBondManager"
      },
      {
        "name": "_livenessBond",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_provabilityBond",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_l1ChainId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_owner",
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
    "name": "_isMatchingProverAuthContext",
    "inputs": [
      {
        "name": "_auth",
        "type": "tuple",
        "internalType": "struct Anchor.ProverAuth",
        "components": [
          {
            "name": "proposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "proposer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "provingFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "signature",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      },
      {
        "name": "_proposalId",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_proposer",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
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
    "name": "anchorV4",
    "inputs": [
      {
        "name": "_proposalParams",
        "type": "tuple",
        "internalType": "struct Anchor.ProposalParams",
        "components": [
          {
            "name": "proposalId",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "proposer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "proverAuth",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
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
      },
      {
        "name": "_blockParams",
        "type": "tuple",
        "internalType": "struct Anchor.BlockParams",
        "components": [
          {
            "name": "blockIndex",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "anchorBlockHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "anchorStateRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "checkpointStore",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract ICheckpointStore"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBlockState",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct Anchor.BlockState",
        "components": [
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "ancestorsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
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
      },
      {
        "name": "_currentDesignatedProver",
        "type": "address",
        "internalType": "address"
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
    "name": "getProposalState",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct Anchor.ProposalState",
        "components": [
          {
            "name": "bondInstructionsHash",
            "type": "bytes32",
            "internalType": "bytes32"
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
          }
        ]
      }
    ],
    "stateMutability": "view"
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
    "name": "livenessBond",
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
    "name": "provabilityBond",
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
    "name": "renounceOwnership",
    "inputs": [],
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
    "name": "validateProverAuth",
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
        "name": "signer_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "provingFee_",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
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
    "name": "Anchored",
    "inputs": [
      {
        "name": "bondInstructionsHash",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "designatedProver",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "isLowBondProposal",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      },
      {
        "name": "anchorBlockNumber",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      },
      {
        "name": "ancestorsHash",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
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
    "name": "AncestorsHashMismatch",
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
    "name": "InvalidAddress",
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
    "name": "InvalidL1ChainId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidL2ChainId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSender",
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
pub mod Anchor {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x610120604052348015610010575f5ffd5b50604051611f35380380611f3583398101604081905261002f916101e2565b61003833610163565b60016002556001600160a01b0386166100645760405163e6c4247b60e01b815260040160405180910390fd5b6001600160a01b03851661008b5760405163e6c4247b60e01b815260040160405180910390fd5b6001600160a01b0381166100b25760405163e6c4247b60e01b815260040160405180910390fd5b6001600160401b038216158015906100d3575046826001600160401b031614155b6100f05760405163ca40667b60e01b815260040160405180910390fd5b60014611801561010757506001600160401b034611155b6101245760405163142d897560e31b815260040160405180910390fd5b6001600160a01b0380871660a052851660805260c084905260e08390526001600160401b0382166101005261015881610163565b50505050505061025d565b600180546001600160a01b031916905561017c8161017f565b50565b5f80546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6001600160a01b038116811461017c575f5ffd5b5f5f5f5f5f5f60c087890312156101f7575f5ffd5b8651610202816101ce565b6020880151909650610213816101ce565b6040880151606089015160808a015192975090955093506001600160401b038116811461023e575f5ffd5b60a088015190925061024f816101ce565b809150509295509295509295565b60805160a05160c05160e05161010051611c5c6102d95f395f61016f01525f818161035a01526113dc01525f818161038f015261139c01525f81816102220152610cbe01525f81816101ae015281816106ed015281816107be01528181610b0901528181610bd601528181610f310152610fe00152611c5c5ff3fe608060405234801561000f575f5ffd5b506004361061011c575f3560e01c8063a37ea515116100a9578063d44142211161006e578063d44142211461038a578063ddececb2146103b1578063e30c3978146103d4578063f2fde38b146103e5578063f940e385146103f8575f5ffd5b8063a37ea5151461025d578063aade375b1461028f578063b3d5e45f14610313578063c46e3a661461034b578063cf1a0f2214610355575f5ffd5b8063715018a6116100ef578063715018a6146101fd57806379ba5097146102055780638da5cb5b1461020d578063955a72441461021d5780639ee512f214610244575f5ffd5b80630f439bd91461012057806312622e5b1461016a578063363cc427146101a95780634e60c8bb146101e8575b5f5ffd5b6040805180820182525f8082526020918201528151808301835260095465ffffffffffff16808252600a549183019182528351908152905191810191909152015b60405180910390f35b6101917f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b039091168152602001610161565b6101d07f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160a01b039091168152602001610161565b6101fb6101f63660046115ea565b61040b565b005b6101fb6104f1565b6101fb610504565b5f546001600160a01b03166101d0565b6101d07f000000000000000000000000000000000000000000000000000000000000000081565b6101d071777735367b36bc9b61c50022d9d0700db4ec81565b61027061026b3660046116b0565b610583565b604080516001600160a01b039093168352602083019190915201610161565b6102e6604080516060810182525f8082526020820181905291810191909152506040805160608101825260075481526008546001600160a01b0381166020830152600160a01b900460ff1615159181019190915290565b60408051825181526020808401516001600160a01b03169082015291810151151590820152606001610161565b61032661032136600461170c565b6106ae565b6040805193151584526001600160a01b03909216602084015290820152606001610161565b610191620f424081565b61037c7f000000000000000000000000000000000000000000000000000000000000000081565b604051908152602001610161565b61037c7f000000000000000000000000000000000000000000000000000000000000000081565b6103c46103bf3660046118b1565b610851565b6040519015158152602001610161565b6001546001600160a01b03166101d0565b6101fb6103f336600461190a565b610891565b6101fb610406366004611923565b610901565b3371777735367b36bc9b61c50022d9d0700db4ec1461043d57604051636edaef2f60e11b815260040160405180910390fd5b610445610a33565b6104526020820182611954565b61ffff165f036104655761046582610a8a565b61046e81610c55565b600754600854600954600a54604080519485526001600160a01b0384166020860152600160a01b90930460ff1615159284019290925265ffffffffffff16606083015260808201527fabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e97349060a00160405180910390a16104ed6001600255565b5050565b6104f9610dca565b6105025f610e23565b565b60015433906001600160a01b031681146105775760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b60648201526084015b60405180910390fd5b61058081610e23565b50565b5f8060e183101561059857508390505f6106a5565b5f6105a58486018661197c565b90506105b2818888610851565b6105c257855f92509250506106a5565b6041816060015151146105db57855f92509250506106a5565b5f5f61063e610634848051602080830151604093840151845165ffffffffffff909416848401526001600160a01b0390911683850152606080840191909152835180840390910181526080909201909252805191012090565b8460600151610e3c565b90925090505f816004811115610656576106566119ad565b14158061066a57506001600160a01b038216155b1561067d57875f945094505050506106a5565b819450876001600160a01b0316856001600160a01b0316146106a157826040015193505b5050505b94509492505050565b5f5f5f5f5f6106bf8a8a8a8a610583565b60405163508b724360e11b81526001600160a01b038c81166004830152602482018390529294509092505f917f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610732573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061075691906119c1565b90508061076f576001875f955095509550505050610846565b896001600160a01b0316836001600160a01b031603610799575f8a5f955095509550505050610846565b60405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610803573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061082791906119c1565b61083c575f8a5f955095509550505050610846565b505f945090925090505b955095509592505050565b5f8265ffffffffffff16845f015165ffffffffffff161480156108895750816001600160a01b031684602001516001600160a01b0316145b949350505050565b610899610dca565b600180546001600160a01b0383166001600160a01b031990911681179091556108c95f546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b610909610dca565b610911610a33565b6001600160a01b0381166109385760405163e6c4247b60e01b815260040160405180910390fd5b5f6001600160a01b03831661096157504761095c6001600160a01b03831682610e7e565b6109dd565b6040516370a0823160e01b81523060048201526001600160a01b038416906370a0823190602401602060405180830381865afa1580156109a3573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906109c791906119e0565b90506109dd6001600160a01b0384168383610e89565b604080516001600160a01b038086168252841660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a1506104ed6001600255565b6002805403610a845760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c00604482015260640161056e565b60028055565b5f610ac9610a9b60208401846119f7565b610aab604085016020860161190a565b610ab86040860186611a10565b6008546001600160a01b03166106ae565b60088054931515600160a01b026001600160a81b03199094166001600160a01b039093169290921792909217905590508015610c30576001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de610b3e604085016020860161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044016020604051808303815f875af1158015610b88573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610bac91906119e0565b50600854604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b158015610c19575f5ffd5b505af1158015610c2b573d5f5f3e3d5ffd5b505050505b600754610c4e90610c446080850185611a52565b8560600135610edb565b6007555050565b5f5f610c5f6110c3565b600a54919350915015610c8e57600a548214610c8e576040516349645ffd60e01b815260040160405180910390fd5b600a81905560095465ffffffffffff16610cae60408501602086016119f7565b65ffffffffffff161115610dc5577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663c9a0b8c86040518060600160405280866020016020810190610d0991906119f7565b65ffffffffffff1681526020018660400135815260200186606001358152506040518263ffffffff1660e01b8152600401610d689190815165ffffffffffff168152602080830151908201526040918201519181019190915260600190565b5f604051808303815f87803b158015610d7f575f5ffd5b505af1158015610d91573d5f5f3e3d5ffd5b50610da69250505060408401602085016119f7565b6009805465ffffffffffff191665ffffffffffff929092169190911790555b505050565b5f546001600160a01b031633146105025760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161056e565b600180546001600160a01b031916905561058081611160565b5f5f8251604103610e70576020830151604084015160608501515f1a610e64878285856111af565b94509450505050610e77565b505f905060025b9250929050565b6104ed82825a611269565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b179052610dc59084906112ac565b83825f5b818110156110995736868683818110610efa57610efa611a97565b90506080020190505f610f1e826020016020810190610f199190611ab9565b61137f565b90508015611072575f6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de610f66606086016040870161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018590526044016020604051808303815f875af1158015610fb0573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610fd491906119e0565b90506001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663be32d1f4611015608086016060870161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044015f604051808303815f87803b15801561105a575f5ffd5b505af115801561106c573d5f5f3e3d5ffd5b50505050505b61108a8561108536859003850185611ad2565b611407565b94505050806001019050610edf565b508282146110ba576040516388c4700b60e01b815260040160405180910390fd5b50949350505050565b5f80806110d1600143611b31565b90506110db6115ca565b46611fe08201525f5b60ff811080156110f75750806001018310155b15611128575f198184030180408360ff8306610100811061111a5761111a611a97565b6020020152506001016110e4565b506120008120935081408161113e60ff85611b50565b610100811061114f5761114f611a97565b602002015261200090209293915050565b5f80546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08311156111e457505f905060036106a5565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015611235573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b03811661125d575f600192509250506106a5565b965f9650945050505050565b815f0361127557505050565b61128f83838360405180602001604052805f815250611470565b610dc557604051634c67134d60e11b815260040160405180910390fd5b5f611300826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166114ad9092919063ffffffff16565b905080515f148061132057508080602001905181019061132091906119c1565b610dc55760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b606482015260840161056e565b5f6002826002811115611394576113946119ad565b036113c057507f0000000000000000000000000000000000000000000000000000000000000000919050565b60018260028111156113d4576113d46119ad565b0361140057507f0000000000000000000000000000000000000000000000000000000000000000919050565b505f919050565b80515f9065ffffffffffff16158061143357505f82602001516002811115611431576114316119ad565b145b61146557828260405160200161144a929190611b6f565b60405160208183030381529060405280519060200120611467565b825b90505b92915050565b5f6001600160a01b03851661149857604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b606061088984845f85855f5f866001600160a01b031685876040516114d29190611bdb565b5f6040518083038185875af1925050503d805f811461150c576040519150601f19603f3d011682016040523d82523d5f602084013e611511565b606091505b50915091506115228783838761152d565b979650505050505050565b6060831561159b5782515f03611594576001600160a01b0385163b6115945760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000604482015260640161056e565b5081610889565b61088983838151156115b05781518083602001fd5b8060405162461bcd60e51b815260040161056e9190611bf1565b604051806120000160405280610100906020820280368337509192915050565b5f5f82840360a08112156115fc575f5ffd5b83356001600160401b03811115611611575f5ffd5b840160a08187031215611622575f5ffd5b92506080601f1982011215611635575f5ffd5b506020830190509250929050565b803565ffffffffffff81168114611658575f5ffd5b919050565b80356001600160a01b0381168114611658575f5ffd5b5f5f83601f840112611683575f5ffd5b5081356001600160401b03811115611699575f5ffd5b602083019150836020828501011115610e77575f5ffd5b5f5f5f5f606085870312156116c3575f5ffd5b6116cc85611643565b93506116da6020860161165d565b925060408501356001600160401b038111156116f4575f5ffd5b61170087828801611673565b95989497509550505050565b5f5f5f5f5f60808688031215611720575f5ffd5b61172986611643565b94506117376020870161165d565b935060408601356001600160401b03811115611751575f5ffd5b61175d88828901611673565b909450925061177090506060870161165d565b90509295509295909350565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156117b2576117b261177c565b60405290565b604051601f8201601f191681016001600160401b03811182821017156117e0576117e061177c565b604052919050565b5f608082840312156117f8575f5ffd5b611800611790565b905061180b82611643565b81526118196020830161165d565b60208201526040820135604082015260608201356001600160401b03811115611840575f5ffd5b8201601f81018413611850575f5ffd5b80356001600160401b038111156118695761186961177c565b61187c601f8201601f19166020016117b8565b818152856020838501011115611890575f5ffd5b816020840160208301375f6020838301015280606085015250505092915050565b5f5f5f606084860312156118c3575f5ffd5b83356001600160401b038111156118d8575f5ffd5b6118e4868287016117e8565b9350506118f360208501611643565b91506119016040850161165d565b90509250925092565b5f6020828403121561191a575f5ffd5b6114678261165d565b5f5f60408385031215611934575f5ffd5b61193d8361165d565b915061194b6020840161165d565b90509250929050565b5f60208284031215611964575f5ffd5b813561ffff81168114611975575f5ffd5b9392505050565b5f6020828403121561198c575f5ffd5b81356001600160401b038111156119a1575f5ffd5b610889848285016117e8565b634e487b7160e01b5f52602160045260245ffd5b5f602082840312156119d1575f5ffd5b81518015158114611975575f5ffd5b5f602082840312156119f0575f5ffd5b5051919050565b5f60208284031215611a07575f5ffd5b61146782611643565b5f5f8335601e19843603018112611a25575f5ffd5b8301803591506001600160401b03821115611a3e575f5ffd5b602001915036819003821315610e77575f5ffd5b5f5f8335601e19843603018112611a67575f5ffd5b8301803591506001600160401b03821115611a80575f5ffd5b6020019150600781901b3603821315610e77575f5ffd5b634e487b7160e01b5f52603260045260245ffd5b803560038110611658575f5ffd5b5f60208284031215611ac9575f5ffd5b61146782611aab565b5f6080828403128015611ae3575f5ffd5b50611aec611790565b611af583611643565b8152611b0360208401611aab565b6020820152611b146040840161165d565b6040820152611b256060840161165d565b60608201529392505050565b8181038181111561146a57634e487b7160e01b5f52601160045260245ffd5b5f82611b6a57634e487b7160e01b5f52601260045260245ffd5b500690565b5f60a08201905083825265ffffffffffff8351166020830152602083015160038110611ba957634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fea2646970667358221220191807277d3300b0c349d7c3cc9c877f31a614e501bff339450f4352fb98ec5964736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01 `@R4\x80\x15a\0\x10W__\xFD[P`@Qa\x1F58\x03\x80a\x1F5\x839\x81\x01`@\x81\x90Ra\0/\x91a\x01\xE2V[a\083a\x01cV[`\x01`\x02U`\x01`\x01`\xA0\x1B\x03\x86\x16a\0dW`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x85\x16a\0\x8BW`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x81\x16a\0\xB2W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03\x82\x16\x15\x80\x15\x90a\0\xD3WPF\x82`\x01`\x01`@\x1B\x03\x16\x14\x15[a\0\xF0W`@Qc\xCA@f{`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01F\x11\x80\x15a\x01\x07WP`\x01`\x01`@\x1B\x03F\x11\x15[a\x01$W`@Qc\x14-\x89u`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x80\x87\x16`\xA0R\x85\x16`\x80R`\xC0\x84\x90R`\xE0\x83\x90R`\x01`\x01`@\x1B\x03\x82\x16a\x01\0Ra\x01X\x81a\x01cV[PPPPPPa\x02]V[`\x01\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x01|\x81a\x01\x7FV[PV[_\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x84U`@Q\x91\x90\x92\x16\x92\x83\x91\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x91\x90\xA3PPV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x01|W__\xFD[______`\xC0\x87\x89\x03\x12\x15a\x01\xF7W__\xFD[\x86Qa\x02\x02\x81a\x01\xCEV[` \x88\x01Q\x90\x96Pa\x02\x13\x81a\x01\xCEV[`@\x88\x01Q``\x89\x01Q`\x80\x8A\x01Q\x92\x97P\x90\x95P\x93P`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x02>W__\xFD[`\xA0\x88\x01Q\x90\x92Pa\x02O\x81a\x01\xCEV[\x80\x91PP\x92\x95P\x92\x95P\x92\x95V[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x1C\\a\x02\xD9_9_a\x01o\x01R_\x81\x81a\x03Z\x01Ra\x13\xDC\x01R_\x81\x81a\x03\x8F\x01Ra\x13\x9C\x01R_\x81\x81a\x02\"\x01Ra\x0C\xBE\x01R_\x81\x81a\x01\xAE\x01R\x81\x81a\x06\xED\x01R\x81\x81a\x07\xBE\x01R\x81\x81a\x0B\t\x01R\x81\x81a\x0B\xD6\x01R\x81\x81a\x0F1\x01Ra\x0F\xE0\x01Ra\x1C\\_\xF3\xFE`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\x01\x1CW_5`\xE0\x1C\x80c\xA3~\xA5\x15\x11a\0\xA9W\x80c\xD4AB!\x11a\0nW\x80c\xD4AB!\x14a\x03\x8AW\x80c\xDD\xEC\xEC\xB2\x14a\x03\xB1W\x80c\xE3\x0C9x\x14a\x03\xD4W\x80c\xF2\xFD\xE3\x8B\x14a\x03\xE5W\x80c\xF9@\xE3\x85\x14a\x03\xF8W__\xFD[\x80c\xA3~\xA5\x15\x14a\x02]W\x80c\xAA\xDE7[\x14a\x02\x8FW\x80c\xB3\xD5\xE4_\x14a\x03\x13W\x80c\xC4n:f\x14a\x03KW\x80c\xCF\x1A\x0F\"\x14a\x03UW__\xFD[\x80cqP\x18\xA6\x11a\0\xEFW\x80cqP\x18\xA6\x14a\x01\xFDW\x80cy\xBAP\x97\x14a\x02\x05W\x80c\x8D\xA5\xCB[\x14a\x02\rW\x80c\x95ZrD\x14a\x02\x1DW\x80c\x9E\xE5\x12\xF2\x14a\x02DW__\xFD[\x80c\x0FC\x9B\xD9\x14a\x01 W\x80c\x12b.[\x14a\x01jW\x80c6<\xC4'\x14a\x01\xA9W\x80cN`\xC8\xBB\x14a\x01\xE8W[__\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83R`\tTe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80\x82R`\nT\x91\x83\x01\x91\x82R\x83Q\x90\x81R\x90Q\x91\x81\x01\x91\x90\x91R\x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x01aV[a\x01\xD0\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01a\x01aV[a\x01\xFBa\x01\xF66`\x04a\x15\xEAV[a\x04\x0BV[\0[a\x01\xFBa\x04\xF1V[a\x01\xFBa\x05\x04V[_T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xD0V[a\x01\xD0\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[a\x01\xD0qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[a\x02pa\x02k6`\x04a\x16\xB0V[a\x05\x83V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x83R` \x83\x01\x91\x90\x91R\x01a\x01aV[a\x02\xE6`@\x80Q``\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x91\x90\x91RP`@\x80Q``\x81\x01\x82R`\x07T\x81R`\x08T`\x01`\x01`\xA0\x1B\x03\x81\x16` \x83\x01R`\x01`\xA0\x1B\x90\x04`\xFF\x16\x15\x15\x91\x81\x01\x91\x90\x91R\x90V[`@\x80Q\x82Q\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x82\x01R\x91\x81\x01Q\x15\x15\x90\x82\x01R``\x01a\x01aV[a\x03&a\x03!6`\x04a\x17\x0CV[a\x06\xAEV[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x01aV[a\x01\x91b\x0FB@\x81V[a\x03|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q\x90\x81R` \x01a\x01aV[a\x03|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[a\x03\xC4a\x03\xBF6`\x04a\x18\xB1V[a\x08QV[`@Q\x90\x15\x15\x81R` \x01a\x01aV[`\x01T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xD0V[a\x01\xFBa\x03\xF36`\x04a\x19\nV[a\x08\x91V[a\x01\xFBa\x04\x066`\x04a\x19#V[a\t\x01V[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x04=W`@Qcn\xDA\xEF/`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x04Ea\n3V[a\x04R` \x82\x01\x82a\x19TV[a\xFF\xFF\x16_\x03a\x04eWa\x04e\x82a\n\x8AV[a\x04n\x81a\x0CUV[`\x07T`\x08T`\tT`\nT`@\x80Q\x94\x85R`\x01`\x01`\xA0\x1B\x03\x84\x16` \x86\x01R`\x01`\xA0\x1B\x90\x93\x04`\xFF\x16\x15\x15\x92\x84\x01\x92\x90\x92Re\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x83\x01R`\x80\x82\x01R\x7F\xAB\xE1\xAB+\xA2,g*\xDB\xC2\x9E5\xDE6\xDBx\xE8\xB2\xD2\xCE]`\x02c)\xD5-\xA5\xF3\x1E\x974\x90`\xA0\x01`@Q\x80\x91\x03\x90\xA1a\x04\xED`\x01`\x02UV[PPV[a\x04\xF9a\r\xCAV[a\x05\x02_a\x0E#V[V[`\x01T3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x05wW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[a\x05\x80\x81a\x0E#V[PV[_\x80`\xE1\x83\x10\x15a\x05\x98WP\x83\x90P_a\x06\xA5V[_a\x05\xA5\x84\x86\x01\x86a\x19|V[\x90Pa\x05\xB2\x81\x88\x88a\x08QV[a\x05\xC2W\x85_\x92P\x92PPa\x06\xA5V[`A\x81``\x01QQ\x14a\x05\xDBW\x85_\x92P\x92PPa\x06\xA5V[__a\x06>a\x064\x84\x80Q` \x80\x83\x01Q`@\x93\x84\x01Q\x84Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x94\x16\x84\x84\x01R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x83\x85\x01R``\x80\x84\x01\x91\x90\x91R\x83Q\x80\x84\x03\x90\x91\x01\x81R`\x80\x90\x92\x01\x90\x92R\x80Q\x91\x01 \x90V[\x84``\x01Qa\x0E<V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a\x06VWa\x06Va\x19\xADV[\x14\x15\x80a\x06jWP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15[\x15a\x06}W\x87_\x94P\x94PPPPa\x06\xA5V[\x81\x94P\x87`\x01`\x01`\xA0\x1B\x03\x16\x85`\x01`\x01`\xA0\x1B\x03\x16\x14a\x06\xA1W\x82`@\x01Q\x93P[PPP[\x94P\x94\x92PPPV[_____a\x06\xBF\x8A\x8A\x8A\x8Aa\x05\x83V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8C\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x92\x94P\x90\x92P_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x072W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x07V\x91\x90a\x19\xC1V[\x90P\x80a\x07oW`\x01\x87_\x95P\x95P\x95PPPPa\x08FV[\x89`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x03a\x07\x99W_\x8A_\x95P\x95P\x95PPPPa\x08FV[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x08\x03W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x08'\x91\x90a\x19\xC1V[a\x08<W_\x8A_\x95P\x95P\x95PPPPa\x08FV[P_\x94P\x90\x92P\x90P[\x95P\x95P\x95\x92PPPV[_\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x80\x15a\x08\x89WP\x81`\x01`\x01`\xA0\x1B\x03\x16\x84` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14[\x94\x93PPPPV[a\x08\x99a\r\xCAV[`\x01\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x08\xC9_T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\t\ta\r\xCAV[a\t\x11a\n3V[`\x01`\x01`\xA0\x1B\x03\x81\x16a\t8W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\taWPGa\t\\`\x01`\x01`\xA0\x1B\x03\x83\x16\x82a\x0E~V[a\t\xDDV[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x84\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\t\xA3W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\t\xC7\x91\x90a\x19\xE0V[\x90Pa\t\xDD`\x01`\x01`\xA0\x1B\x03\x84\x16\x83\x83a\x0E\x89V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x86\x16\x82R\x84\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\x04\xED`\x01`\x02UV[`\x02\x80T\x03a\n\x84W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FReentrancyGuard: reentrant call\0`D\x82\x01R`d\x01a\x05nV[`\x02\x80UV[_a\n\xC9a\n\x9B` \x84\x01\x84a\x19\xF7V[a\n\xAB`@\x85\x01` \x86\x01a\x19\nV[a\n\xB8`@\x86\x01\x86a\x1A\x10V[`\x08T`\x01`\x01`\xA0\x1B\x03\x16a\x06\xAEV[`\x08\x80T\x93\x15\x15`\x01`\xA0\x1B\x02`\x01`\x01`\xA8\x1B\x03\x19\x90\x94\x16`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x92\x90\x92\x17\x92\x90\x92\x17\x90U\x90P\x80\x15a\x0C0W`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x0B>`@\x85\x01` \x86\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x0B\x88W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0B\xAC\x91\x90a\x19\xE0V[P`\x08T`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x0C\x19W__\xFD[PZ\xF1\x15\x80\x15a\x0C+W=__>=_\xFD[PPPP[`\x07Ta\x0CN\x90a\x0CD`\x80\x85\x01\x85a\x1ARV[\x85``\x015a\x0E\xDBV[`\x07UPPV[__a\x0C_a\x10\xC3V[`\nT\x91\x93P\x91P\x15a\x0C\x8EW`\nT\x82\x14a\x0C\x8EW`@QcId_\xFD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\n\x81\x90U`\tTe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x0C\xAE`@\x85\x01` \x86\x01a\x19\xF7V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\r\xC5W\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c\xC9\xA0\xB8\xC8`@Q\x80``\x01`@R\x80\x86` \x01` \x81\x01\x90a\r\t\x91\x90a\x19\xF7V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01\x86`@\x015\x81R` \x01\x86``\x015\x81RP`@Q\x82c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01a\rh\x91\x90\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x83\x01Q\x90\x82\x01R`@\x91\x82\x01Q\x91\x81\x01\x91\x90\x91R``\x01\x90V[_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\r\x7FW__\xFD[PZ\xF1\x15\x80\x15a\r\x91W=__>=_\xFD[Pa\r\xA6\x92PPP`@\x84\x01` \x85\x01a\x19\xF7V[`\t\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90U[PPPV[_T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x05\x02W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x05nV[`\x01\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x05\x80\x81a\x11`V[__\x82Q`A\x03a\x0EpW` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa\x0Ed\x87\x82\x85\x85a\x11\xAFV[\x94P\x94PPPPa\x0EwV[P_\x90P`\x02[\x92P\x92\x90PV[a\x04\xED\x82\x82Za\x12iV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\r\xC5\x90\x84\x90a\x12\xACV[\x83\x82_[\x81\x81\x10\x15a\x10\x99W6\x86\x86\x83\x81\x81\x10a\x0E\xFAWa\x0E\xFAa\x1A\x97V[\x90P`\x80\x02\x01\x90P_a\x0F\x1E\x82` \x01` \x81\x01\x90a\x0F\x19\x91\x90a\x1A\xB9V[a\x13\x7FV[\x90P\x80\x15a\x10rW_`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x0Ff``\x86\x01`@\x87\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x85\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x0F\xB0W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0F\xD4\x91\x90a\x19\xE0V[\x90P`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c\xBE2\xD1\xF4a\x10\x15`\x80\x86\x01``\x87\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x10ZW__\xFD[PZ\xF1\x15\x80\x15a\x10lW=__>=_\xFD[PPPPP[a\x10\x8A\x85a\x10\x856\x85\x90\x03\x85\x01\x85a\x1A\xD2V[a\x14\x07V[\x94PPP\x80`\x01\x01\x90Pa\x0E\xDFV[P\x82\x82\x14a\x10\xBAW`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94\x93PPPPV[_\x80\x80a\x10\xD1`\x01Ca\x1B1V[\x90Pa\x10\xDBa\x15\xCAV[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\x10\xF7WP\x80`\x01\x01\x83\x10\x15[\x15a\x11(W_\x19\x81\x84\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\x11\x1AWa\x11\x1Aa\x1A\x97V[` \x02\x01RP`\x01\x01a\x10\xE4V[Pa \0\x81 \x93P\x81@\x81a\x11>`\xFF\x85a\x1BPV[a\x01\0\x81\x10a\x11OWa\x11Oa\x1A\x97V[` \x02\x01Ra \0\x90 \x92\x93\x91PPV[_\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x84U`@Q\x91\x90\x92\x16\x92\x83\x91\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x91\x90\xA3PPV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a\x11\xE4WP_\x90P`\x03a\x06\xA5V[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a\x125W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a\x12]W_`\x01\x92P\x92PPa\x06\xA5V[\x96_\x96P\x94PPPPPV[\x81_\x03a\x12uWPPPV[a\x12\x8F\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa\x14pV[a\r\xC5W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x13\0\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a\x14\xAD\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a\x13 WP\x80\x80` \x01\x90Q\x81\x01\x90a\x13 \x91\x90a\x19\xC1V[a\r\xC5W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\x05nV[_`\x02\x82`\x02\x81\x11\x15a\x13\x94Wa\x13\x94a\x19\xADV[\x03a\x13\xC0WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[`\x01\x82`\x02\x81\x11\x15a\x13\xD4Wa\x13\xD4a\x19\xADV[\x03a\x14\0WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[P_\x91\x90PV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x143WP_\x82` \x01Q`\x02\x81\x11\x15a\x141Wa\x141a\x19\xADV[\x14[a\x14eW\x82\x82`@Q` \x01a\x14J\x92\x91\x90a\x1BoV[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a\x14gV[\x82[\x90P[\x92\x91PPV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a\x14\x98W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a\x08\x89\x84\x84_\x85\x85__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa\x14\xD2\x91\x90a\x1B\xDBV[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a\x15\x0CW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x15\x11V[``\x91P[P\x91P\x91Pa\x15\"\x87\x83\x83\x87a\x15-V[\x97\x96PPPPPPPV[``\x83\x15a\x15\x9BW\x82Q_\x03a\x15\x94W`\x01`\x01`\xA0\x1B\x03\x85\x16;a\x15\x94W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x05nV[P\x81a\x08\x89V[a\x08\x89\x83\x83\x81Q\x15a\x15\xB0W\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05n\x91\x90a\x1B\xF1V[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[__\x82\x84\x03`\xA0\x81\x12\x15a\x15\xFCW__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x11W__\xFD[\x84\x01`\xA0\x81\x87\x03\x12\x15a\x16\"W__\xFD[\x92P`\x80`\x1F\x19\x82\x01\x12\x15a\x165W__\xFD[P` \x83\x01\x90P\x92P\x92\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x16XW__\xFD[\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x16XW__\xFD[__\x83`\x1F\x84\x01\x12a\x16\x83W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x99W__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a\x0EwW__\xFD[____``\x85\x87\x03\x12\x15a\x16\xC3W__\xFD[a\x16\xCC\x85a\x16CV[\x93Pa\x16\xDA` \x86\x01a\x16]V[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\xF4W__\xFD[a\x17\0\x87\x82\x88\x01a\x16sV[\x95\x98\x94\x97P\x95PPPPV[_____`\x80\x86\x88\x03\x12\x15a\x17 W__\xFD[a\x17)\x86a\x16CV[\x94Pa\x177` \x87\x01a\x16]V[\x93P`@\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17QW__\xFD[a\x17]\x88\x82\x89\x01a\x16sV[\x90\x94P\x92Pa\x17p\x90P``\x87\x01a\x16]V[\x90P\x92\x95P\x92\x95\x90\x93PV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x17\xB2Wa\x17\xB2a\x17|V[`@R\x90V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x17\xE0Wa\x17\xE0a\x17|V[`@R\x91\x90PV[_`\x80\x82\x84\x03\x12\x15a\x17\xF8W__\xFD[a\x18\0a\x17\x90V[\x90Pa\x18\x0B\x82a\x16CV[\x81Ra\x18\x19` \x83\x01a\x16]V[` \x82\x01R`@\x82\x015`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18@W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x18PW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18iWa\x18ia\x17|V[a\x18|`\x1F\x82\x01`\x1F\x19\x16` \x01a\x17\xB8V[\x81\x81R\x85` \x83\x85\x01\x01\x11\x15a\x18\x90W__\xFD[\x81` \x84\x01` \x83\x017_` \x83\x83\x01\x01R\x80``\x85\x01RPPP\x92\x91PPV[___``\x84\x86\x03\x12\x15a\x18\xC3W__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18\xD8W__\xFD[a\x18\xE4\x86\x82\x87\x01a\x17\xE8V[\x93PPa\x18\xF3` \x85\x01a\x16CV[\x91Pa\x19\x01`@\x85\x01a\x16]V[\x90P\x92P\x92P\x92V[_` \x82\x84\x03\x12\x15a\x19\x1AW__\xFD[a\x14g\x82a\x16]V[__`@\x83\x85\x03\x12\x15a\x194W__\xFD[a\x19=\x83a\x16]V[\x91Pa\x19K` \x84\x01a\x16]V[\x90P\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a\x19dW__\xFD[\x815a\xFF\xFF\x81\x16\x81\x14a\x19uW__\xFD[\x93\x92PPPV[_` \x82\x84\x03\x12\x15a\x19\x8CW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\xA1W__\xFD[a\x08\x89\x84\x82\x85\x01a\x17\xE8V[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a\x19\xD1W__\xFD[\x81Q\x80\x15\x15\x81\x14a\x19uW__\xFD[_` \x82\x84\x03\x12\x15a\x19\xF0W__\xFD[PQ\x91\x90PV[_` \x82\x84\x03\x12\x15a\x1A\x07W__\xFD[a\x14g\x82a\x16CV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a\x1A%W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1A>W__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a\x0EwW__\xFD[__\x835`\x1E\x19\x846\x03\x01\x81\x12a\x1AgW__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1A\x80W__\xFD[` \x01\x91P`\x07\x81\x90\x1B6\x03\x82\x13\x15a\x0EwW__\xFD[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x805`\x03\x81\x10a\x16XW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\xC9W__\xFD[a\x14g\x82a\x1A\xABV[_`\x80\x82\x84\x03\x12\x80\x15a\x1A\xE3W__\xFD[Pa\x1A\xECa\x17\x90V[a\x1A\xF5\x83a\x16CV[\x81Ra\x1B\x03` \x84\x01a\x1A\xABV[` \x82\x01Ra\x1B\x14`@\x84\x01a\x16]V[`@\x82\x01Ra\x1B%``\x84\x01a\x16]V[``\x82\x01R\x93\x92PPPV[\x81\x81\x03\x81\x81\x11\x15a\x14jWcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[_\x82a\x1BjWcNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[P\x06\x90V[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a\x1B\xA9WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE\xA2dipfsX\"\x12 \x19\x18\x07'}3\0\xB0\xC3I\xD7\xC3\xCC\x9C\x87\x7F1\xA6\x14\xE5\x01\xBF\xF39E\x0FCR\xFB\x98\xECYdsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405234801561000f575f5ffd5b506004361061011c575f3560e01c8063a37ea515116100a9578063d44142211161006e578063d44142211461038a578063ddececb2146103b1578063e30c3978146103d4578063f2fde38b146103e5578063f940e385146103f8575f5ffd5b8063a37ea5151461025d578063aade375b1461028f578063b3d5e45f14610313578063c46e3a661461034b578063cf1a0f2214610355575f5ffd5b8063715018a6116100ef578063715018a6146101fd57806379ba5097146102055780638da5cb5b1461020d578063955a72441461021d5780639ee512f214610244575f5ffd5b80630f439bd91461012057806312622e5b1461016a578063363cc427146101a95780634e60c8bb146101e8575b5f5ffd5b6040805180820182525f8082526020918201528151808301835260095465ffffffffffff16808252600a549183019182528351908152905191810191909152015b60405180910390f35b6101917f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b039091168152602001610161565b6101d07f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160a01b039091168152602001610161565b6101fb6101f63660046115ea565b61040b565b005b6101fb6104f1565b6101fb610504565b5f546001600160a01b03166101d0565b6101d07f000000000000000000000000000000000000000000000000000000000000000081565b6101d071777735367b36bc9b61c50022d9d0700db4ec81565b61027061026b3660046116b0565b610583565b604080516001600160a01b039093168352602083019190915201610161565b6102e6604080516060810182525f8082526020820181905291810191909152506040805160608101825260075481526008546001600160a01b0381166020830152600160a01b900460ff1615159181019190915290565b60408051825181526020808401516001600160a01b03169082015291810151151590820152606001610161565b61032661032136600461170c565b6106ae565b6040805193151584526001600160a01b03909216602084015290820152606001610161565b610191620f424081565b61037c7f000000000000000000000000000000000000000000000000000000000000000081565b604051908152602001610161565b61037c7f000000000000000000000000000000000000000000000000000000000000000081565b6103c46103bf3660046118b1565b610851565b6040519015158152602001610161565b6001546001600160a01b03166101d0565b6101fb6103f336600461190a565b610891565b6101fb610406366004611923565b610901565b3371777735367b36bc9b61c50022d9d0700db4ec1461043d57604051636edaef2f60e11b815260040160405180910390fd5b610445610a33565b6104526020820182611954565b61ffff165f036104655761046582610a8a565b61046e81610c55565b600754600854600954600a54604080519485526001600160a01b0384166020860152600160a01b90930460ff1615159284019290925265ffffffffffff16606083015260808201527fabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e97349060a00160405180910390a16104ed6001600255565b5050565b6104f9610dca565b6105025f610e23565b565b60015433906001600160a01b031681146105775760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b60648201526084015b60405180910390fd5b61058081610e23565b50565b5f8060e183101561059857508390505f6106a5565b5f6105a58486018661197c565b90506105b2818888610851565b6105c257855f92509250506106a5565b6041816060015151146105db57855f92509250506106a5565b5f5f61063e610634848051602080830151604093840151845165ffffffffffff909416848401526001600160a01b0390911683850152606080840191909152835180840390910181526080909201909252805191012090565b8460600151610e3c565b90925090505f816004811115610656576106566119ad565b14158061066a57506001600160a01b038216155b1561067d57875f945094505050506106a5565b819450876001600160a01b0316856001600160a01b0316146106a157826040015193505b5050505b94509492505050565b5f5f5f5f5f6106bf8a8a8a8a610583565b60405163508b724360e11b81526001600160a01b038c81166004830152602482018390529294509092505f917f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610732573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061075691906119c1565b90508061076f576001875f955095509550505050610846565b896001600160a01b0316836001600160a01b031603610799575f8a5f955095509550505050610846565b60405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610803573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061082791906119c1565b61083c575f8a5f955095509550505050610846565b505f945090925090505b955095509592505050565b5f8265ffffffffffff16845f015165ffffffffffff161480156108895750816001600160a01b031684602001516001600160a01b0316145b949350505050565b610899610dca565b600180546001600160a01b0383166001600160a01b031990911681179091556108c95f546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b610909610dca565b610911610a33565b6001600160a01b0381166109385760405163e6c4247b60e01b815260040160405180910390fd5b5f6001600160a01b03831661096157504761095c6001600160a01b03831682610e7e565b6109dd565b6040516370a0823160e01b81523060048201526001600160a01b038416906370a0823190602401602060405180830381865afa1580156109a3573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906109c791906119e0565b90506109dd6001600160a01b0384168383610e89565b604080516001600160a01b038086168252841660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a1506104ed6001600255565b6002805403610a845760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c00604482015260640161056e565b60028055565b5f610ac9610a9b60208401846119f7565b610aab604085016020860161190a565b610ab86040860186611a10565b6008546001600160a01b03166106ae565b60088054931515600160a01b026001600160a81b03199094166001600160a01b039093169290921792909217905590508015610c30576001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de610b3e604085016020860161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044016020604051808303815f875af1158015610b88573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610bac91906119e0565b50600854604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b158015610c19575f5ffd5b505af1158015610c2b573d5f5f3e3d5ffd5b505050505b600754610c4e90610c446080850185611a52565b8560600135610edb565b6007555050565b5f5f610c5f6110c3565b600a54919350915015610c8e57600a548214610c8e576040516349645ffd60e01b815260040160405180910390fd5b600a81905560095465ffffffffffff16610cae60408501602086016119f7565b65ffffffffffff161115610dc5577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663c9a0b8c86040518060600160405280866020016020810190610d0991906119f7565b65ffffffffffff1681526020018660400135815260200186606001358152506040518263ffffffff1660e01b8152600401610d689190815165ffffffffffff168152602080830151908201526040918201519181019190915260600190565b5f604051808303815f87803b158015610d7f575f5ffd5b505af1158015610d91573d5f5f3e3d5ffd5b50610da69250505060408401602085016119f7565b6009805465ffffffffffff191665ffffffffffff929092169190911790555b505050565b5f546001600160a01b031633146105025760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161056e565b600180546001600160a01b031916905561058081611160565b5f5f8251604103610e70576020830151604084015160608501515f1a610e64878285856111af565b94509450505050610e77565b505f905060025b9250929050565b6104ed82825a611269565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b179052610dc59084906112ac565b83825f5b818110156110995736868683818110610efa57610efa611a97565b90506080020190505f610f1e826020016020810190610f199190611ab9565b61137f565b90508015611072575f6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de610f66606086016040870161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018590526044016020604051808303815f875af1158015610fb0573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610fd491906119e0565b90506001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663be32d1f4611015608086016060870161190a565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044015f604051808303815f87803b15801561105a575f5ffd5b505af115801561106c573d5f5f3e3d5ffd5b50505050505b61108a8561108536859003850185611ad2565b611407565b94505050806001019050610edf565b508282146110ba576040516388c4700b60e01b815260040160405180910390fd5b50949350505050565b5f80806110d1600143611b31565b90506110db6115ca565b46611fe08201525f5b60ff811080156110f75750806001018310155b15611128575f198184030180408360ff8306610100811061111a5761111a611a97565b6020020152506001016110e4565b506120008120935081408161113e60ff85611b50565b610100811061114f5761114f611a97565b602002015261200090209293915050565b5f80546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08311156111e457505f905060036106a5565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015611235573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b03811661125d575f600192509250506106a5565b965f9650945050505050565b815f0361127557505050565b61128f83838360405180602001604052805f815250611470565b610dc557604051634c67134d60e11b815260040160405180910390fd5b5f611300826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166114ad9092919063ffffffff16565b905080515f148061132057508080602001905181019061132091906119c1565b610dc55760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b606482015260840161056e565b5f6002826002811115611394576113946119ad565b036113c057507f0000000000000000000000000000000000000000000000000000000000000000919050565b60018260028111156113d4576113d46119ad565b0361140057507f0000000000000000000000000000000000000000000000000000000000000000919050565b505f919050565b80515f9065ffffffffffff16158061143357505f82602001516002811115611431576114316119ad565b145b61146557828260405160200161144a929190611b6f565b60405160208183030381529060405280519060200120611467565b825b90505b92915050565b5f6001600160a01b03851661149857604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b606061088984845f85855f5f866001600160a01b031685876040516114d29190611bdb565b5f6040518083038185875af1925050503d805f811461150c576040519150601f19603f3d011682016040523d82523d5f602084013e611511565b606091505b50915091506115228783838761152d565b979650505050505050565b6060831561159b5782515f03611594576001600160a01b0385163b6115945760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000604482015260640161056e565b5081610889565b61088983838151156115b05781518083602001fd5b8060405162461bcd60e51b815260040161056e9190611bf1565b604051806120000160405280610100906020820280368337509192915050565b5f5f82840360a08112156115fc575f5ffd5b83356001600160401b03811115611611575f5ffd5b840160a08187031215611622575f5ffd5b92506080601f1982011215611635575f5ffd5b506020830190509250929050565b803565ffffffffffff81168114611658575f5ffd5b919050565b80356001600160a01b0381168114611658575f5ffd5b5f5f83601f840112611683575f5ffd5b5081356001600160401b03811115611699575f5ffd5b602083019150836020828501011115610e77575f5ffd5b5f5f5f5f606085870312156116c3575f5ffd5b6116cc85611643565b93506116da6020860161165d565b925060408501356001600160401b038111156116f4575f5ffd5b61170087828801611673565b95989497509550505050565b5f5f5f5f5f60808688031215611720575f5ffd5b61172986611643565b94506117376020870161165d565b935060408601356001600160401b03811115611751575f5ffd5b61175d88828901611673565b909450925061177090506060870161165d565b90509295509295909350565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156117b2576117b261177c565b60405290565b604051601f8201601f191681016001600160401b03811182821017156117e0576117e061177c565b604052919050565b5f608082840312156117f8575f5ffd5b611800611790565b905061180b82611643565b81526118196020830161165d565b60208201526040820135604082015260608201356001600160401b03811115611840575f5ffd5b8201601f81018413611850575f5ffd5b80356001600160401b038111156118695761186961177c565b61187c601f8201601f19166020016117b8565b818152856020838501011115611890575f5ffd5b816020840160208301375f6020838301015280606085015250505092915050565b5f5f5f606084860312156118c3575f5ffd5b83356001600160401b038111156118d8575f5ffd5b6118e4868287016117e8565b9350506118f360208501611643565b91506119016040850161165d565b90509250925092565b5f6020828403121561191a575f5ffd5b6114678261165d565b5f5f60408385031215611934575f5ffd5b61193d8361165d565b915061194b6020840161165d565b90509250929050565b5f60208284031215611964575f5ffd5b813561ffff81168114611975575f5ffd5b9392505050565b5f6020828403121561198c575f5ffd5b81356001600160401b038111156119a1575f5ffd5b610889848285016117e8565b634e487b7160e01b5f52602160045260245ffd5b5f602082840312156119d1575f5ffd5b81518015158114611975575f5ffd5b5f602082840312156119f0575f5ffd5b5051919050565b5f60208284031215611a07575f5ffd5b61146782611643565b5f5f8335601e19843603018112611a25575f5ffd5b8301803591506001600160401b03821115611a3e575f5ffd5b602001915036819003821315610e77575f5ffd5b5f5f8335601e19843603018112611a67575f5ffd5b8301803591506001600160401b03821115611a80575f5ffd5b6020019150600781901b3603821315610e77575f5ffd5b634e487b7160e01b5f52603260045260245ffd5b803560038110611658575f5ffd5b5f60208284031215611ac9575f5ffd5b61146782611aab565b5f6080828403128015611ae3575f5ffd5b50611aec611790565b611af583611643565b8152611b0360208401611aab565b6020820152611b146040840161165d565b6040820152611b256060840161165d565b60608201529392505050565b8181038181111561146a57634e487b7160e01b5f52601160045260245ffd5b5f82611b6a57634e487b7160e01b5f52601260045260245ffd5b500690565b5f60a08201905083825265ffffffffffff8351166020830152602083015160038110611ba957634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fea2646970667358221220191807277d3300b0c349d7c3cc9c877f31a614e501bff339450f4352fb98ec5964736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R4\x80\x15a\0\x0FW__\xFD[P`\x046\x10a\x01\x1CW_5`\xE0\x1C\x80c\xA3~\xA5\x15\x11a\0\xA9W\x80c\xD4AB!\x11a\0nW\x80c\xD4AB!\x14a\x03\x8AW\x80c\xDD\xEC\xEC\xB2\x14a\x03\xB1W\x80c\xE3\x0C9x\x14a\x03\xD4W\x80c\xF2\xFD\xE3\x8B\x14a\x03\xE5W\x80c\xF9@\xE3\x85\x14a\x03\xF8W__\xFD[\x80c\xA3~\xA5\x15\x14a\x02]W\x80c\xAA\xDE7[\x14a\x02\x8FW\x80c\xB3\xD5\xE4_\x14a\x03\x13W\x80c\xC4n:f\x14a\x03KW\x80c\xCF\x1A\x0F\"\x14a\x03UW__\xFD[\x80cqP\x18\xA6\x11a\0\xEFW\x80cqP\x18\xA6\x14a\x01\xFDW\x80cy\xBAP\x97\x14a\x02\x05W\x80c\x8D\xA5\xCB[\x14a\x02\rW\x80c\x95ZrD\x14a\x02\x1DW\x80c\x9E\xE5\x12\xF2\x14a\x02DW__\xFD[\x80c\x0FC\x9B\xD9\x14a\x01 W\x80c\x12b.[\x14a\x01jW\x80c6<\xC4'\x14a\x01\xA9W\x80cN`\xC8\xBB\x14a\x01\xE8W[__\xFD[`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83R`\tTe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80\x82R`\nT\x91\x83\x01\x91\x82R\x83Q\x90\x81R\x90Q\x91\x81\x01\x91\x90\x91R\x01[`@Q\x80\x91\x03\x90\xF3[a\x01\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x01aV[a\x01\xD0\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01a\x01aV[a\x01\xFBa\x01\xF66`\x04a\x15\xEAV[a\x04\x0BV[\0[a\x01\xFBa\x04\xF1V[a\x01\xFBa\x05\x04V[_T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xD0V[a\x01\xD0\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[a\x01\xD0qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[a\x02pa\x02k6`\x04a\x16\xB0V[a\x05\x83V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x83R` \x83\x01\x91\x90\x91R\x01a\x01aV[a\x02\xE6`@\x80Q``\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x91\x90\x91RP`@\x80Q``\x81\x01\x82R`\x07T\x81R`\x08T`\x01`\x01`\xA0\x1B\x03\x81\x16` \x83\x01R`\x01`\xA0\x1B\x90\x04`\xFF\x16\x15\x15\x91\x81\x01\x91\x90\x91R\x90V[`@\x80Q\x82Q\x81R` \x80\x84\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x82\x01R\x91\x81\x01Q\x15\x15\x90\x82\x01R``\x01a\x01aV[a\x03&a\x03!6`\x04a\x17\x0CV[a\x06\xAEV[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x01aV[a\x01\x91b\x0FB@\x81V[a\x03|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q\x90\x81R` \x01a\x01aV[a\x03|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[a\x03\xC4a\x03\xBF6`\x04a\x18\xB1V[a\x08QV[`@Q\x90\x15\x15\x81R` \x01a\x01aV[`\x01T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xD0V[a\x01\xFBa\x03\xF36`\x04a\x19\nV[a\x08\x91V[a\x01\xFBa\x04\x066`\x04a\x19#V[a\t\x01V[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x04=W`@Qcn\xDA\xEF/`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x04Ea\n3V[a\x04R` \x82\x01\x82a\x19TV[a\xFF\xFF\x16_\x03a\x04eWa\x04e\x82a\n\x8AV[a\x04n\x81a\x0CUV[`\x07T`\x08T`\tT`\nT`@\x80Q\x94\x85R`\x01`\x01`\xA0\x1B\x03\x84\x16` \x86\x01R`\x01`\xA0\x1B\x90\x93\x04`\xFF\x16\x15\x15\x92\x84\x01\x92\x90\x92Re\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x83\x01R`\x80\x82\x01R\x7F\xAB\xE1\xAB+\xA2,g*\xDB\xC2\x9E5\xDE6\xDBx\xE8\xB2\xD2\xCE]`\x02c)\xD5-\xA5\xF3\x1E\x974\x90`\xA0\x01`@Q\x80\x91\x03\x90\xA1a\x04\xED`\x01`\x02UV[PPV[a\x04\xF9a\r\xCAV[a\x05\x02_a\x0E#V[V[`\x01T3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x05wW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[a\x05\x80\x81a\x0E#V[PV[_\x80`\xE1\x83\x10\x15a\x05\x98WP\x83\x90P_a\x06\xA5V[_a\x05\xA5\x84\x86\x01\x86a\x19|V[\x90Pa\x05\xB2\x81\x88\x88a\x08QV[a\x05\xC2W\x85_\x92P\x92PPa\x06\xA5V[`A\x81``\x01QQ\x14a\x05\xDBW\x85_\x92P\x92PPa\x06\xA5V[__a\x06>a\x064\x84\x80Q` \x80\x83\x01Q`@\x93\x84\x01Q\x84Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x94\x16\x84\x84\x01R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x83\x85\x01R``\x80\x84\x01\x91\x90\x91R\x83Q\x80\x84\x03\x90\x91\x01\x81R`\x80\x90\x92\x01\x90\x92R\x80Q\x91\x01 \x90V[\x84``\x01Qa\x0E<V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a\x06VWa\x06Va\x19\xADV[\x14\x15\x80a\x06jWP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15[\x15a\x06}W\x87_\x94P\x94PPPPa\x06\xA5V[\x81\x94P\x87`\x01`\x01`\xA0\x1B\x03\x16\x85`\x01`\x01`\xA0\x1B\x03\x16\x14a\x06\xA1W\x82`@\x01Q\x93P[PPP[\x94P\x94\x92PPPV[_____a\x06\xBF\x8A\x8A\x8A\x8Aa\x05\x83V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8C\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x92\x94P\x90\x92P_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x072W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x07V\x91\x90a\x19\xC1V[\x90P\x80a\x07oW`\x01\x87_\x95P\x95P\x95PPPPa\x08FV[\x89`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x03a\x07\x99W_\x8A_\x95P\x95P\x95PPPPa\x08FV[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x08\x03W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x08'\x91\x90a\x19\xC1V[a\x08<W_\x8A_\x95P\x95P\x95PPPPa\x08FV[P_\x94P\x90\x92P\x90P[\x95P\x95P\x95\x92PPPV[_\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x80\x15a\x08\x89WP\x81`\x01`\x01`\xA0\x1B\x03\x16\x84` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14[\x94\x93PPPPV[a\x08\x99a\r\xCAV[`\x01\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x08\xC9_T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\t\ta\r\xCAV[a\t\x11a\n3V[`\x01`\x01`\xA0\x1B\x03\x81\x16a\t8W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\taWPGa\t\\`\x01`\x01`\xA0\x1B\x03\x83\x16\x82a\x0E~V[a\t\xDDV[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x84\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\t\xA3W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\t\xC7\x91\x90a\x19\xE0V[\x90Pa\t\xDD`\x01`\x01`\xA0\x1B\x03\x84\x16\x83\x83a\x0E\x89V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x86\x16\x82R\x84\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\x04\xED`\x01`\x02UV[`\x02\x80T\x03a\n\x84W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1F`$\x82\x01R\x7FReentrancyGuard: reentrant call\0`D\x82\x01R`d\x01a\x05nV[`\x02\x80UV[_a\n\xC9a\n\x9B` \x84\x01\x84a\x19\xF7V[a\n\xAB`@\x85\x01` \x86\x01a\x19\nV[a\n\xB8`@\x86\x01\x86a\x1A\x10V[`\x08T`\x01`\x01`\xA0\x1B\x03\x16a\x06\xAEV[`\x08\x80T\x93\x15\x15`\x01`\xA0\x1B\x02`\x01`\x01`\xA8\x1B\x03\x19\x90\x94\x16`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x92\x90\x92\x17\x92\x90\x92\x17\x90U\x90P\x80\x15a\x0C0W`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x0B>`@\x85\x01` \x86\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x0B\x88W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0B\xAC\x91\x90a\x19\xE0V[P`\x08T`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x0C\x19W__\xFD[PZ\xF1\x15\x80\x15a\x0C+W=__>=_\xFD[PPPP[`\x07Ta\x0CN\x90a\x0CD`\x80\x85\x01\x85a\x1ARV[\x85``\x015a\x0E\xDBV[`\x07UPPV[__a\x0C_a\x10\xC3V[`\nT\x91\x93P\x91P\x15a\x0C\x8EW`\nT\x82\x14a\x0C\x8EW`@QcId_\xFD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\n\x81\x90U`\tTe\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x0C\xAE`@\x85\x01` \x86\x01a\x19\xF7V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\r\xC5W\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16c\xC9\xA0\xB8\xC8`@Q\x80``\x01`@R\x80\x86` \x01` \x81\x01\x90a\r\t\x91\x90a\x19\xF7V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01\x86`@\x015\x81R` \x01\x86``\x015\x81RP`@Q\x82c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01a\rh\x91\x90\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x83\x01Q\x90\x82\x01R`@\x91\x82\x01Q\x91\x81\x01\x91\x90\x91R``\x01\x90V[_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\r\x7FW__\xFD[PZ\xF1\x15\x80\x15a\r\x91W=__>=_\xFD[Pa\r\xA6\x92PPP`@\x84\x01` \x85\x01a\x19\xF7V[`\t\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90U[PPPV[_T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x05\x02W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x05nV[`\x01\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x05\x80\x81a\x11`V[__\x82Q`A\x03a\x0EpW` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa\x0Ed\x87\x82\x85\x85a\x11\xAFV[\x94P\x94PPPPa\x0EwV[P_\x90P`\x02[\x92P\x92\x90PV[a\x04\xED\x82\x82Za\x12iV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\r\xC5\x90\x84\x90a\x12\xACV[\x83\x82_[\x81\x81\x10\x15a\x10\x99W6\x86\x86\x83\x81\x81\x10a\x0E\xFAWa\x0E\xFAa\x1A\x97V[\x90P`\x80\x02\x01\x90P_a\x0F\x1E\x82` \x01` \x81\x01\x90a\x0F\x19\x91\x90a\x1A\xB9V[a\x13\x7FV[\x90P\x80\x15a\x10rW_`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x0Ff``\x86\x01`@\x87\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x85\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x0F\xB0W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0F\xD4\x91\x90a\x19\xE0V[\x90P`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c\xBE2\xD1\xF4a\x10\x15`\x80\x86\x01``\x87\x01a\x19\nV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x10ZW__\xFD[PZ\xF1\x15\x80\x15a\x10lW=__>=_\xFD[PPPPP[a\x10\x8A\x85a\x10\x856\x85\x90\x03\x85\x01\x85a\x1A\xD2V[a\x14\x07V[\x94PPP\x80`\x01\x01\x90Pa\x0E\xDFV[P\x82\x82\x14a\x10\xBAW`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94\x93PPPPV[_\x80\x80a\x10\xD1`\x01Ca\x1B1V[\x90Pa\x10\xDBa\x15\xCAV[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\x10\xF7WP\x80`\x01\x01\x83\x10\x15[\x15a\x11(W_\x19\x81\x84\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\x11\x1AWa\x11\x1Aa\x1A\x97V[` \x02\x01RP`\x01\x01a\x10\xE4V[Pa \0\x81 \x93P\x81@\x81a\x11>`\xFF\x85a\x1BPV[a\x01\0\x81\x10a\x11OWa\x11Oa\x1A\x97V[` \x02\x01Ra \0\x90 \x92\x93\x91PPV[_\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x84U`@Q\x91\x90\x92\x16\x92\x83\x91\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x91\x90\xA3PPV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a\x11\xE4WP_\x90P`\x03a\x06\xA5V[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a\x125W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a\x12]W_`\x01\x92P\x92PPa\x06\xA5V[\x96_\x96P\x94PPPPPV[\x81_\x03a\x12uWPPPV[a\x12\x8F\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa\x14pV[a\r\xC5W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x13\0\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a\x14\xAD\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a\x13 WP\x80\x80` \x01\x90Q\x81\x01\x90a\x13 \x91\x90a\x19\xC1V[a\r\xC5W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\x05nV[_`\x02\x82`\x02\x81\x11\x15a\x13\x94Wa\x13\x94a\x19\xADV[\x03a\x13\xC0WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[`\x01\x82`\x02\x81\x11\x15a\x13\xD4Wa\x13\xD4a\x19\xADV[\x03a\x14\0WP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[P_\x91\x90PV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x143WP_\x82` \x01Q`\x02\x81\x11\x15a\x141Wa\x141a\x19\xADV[\x14[a\x14eW\x82\x82`@Q` \x01a\x14J\x92\x91\x90a\x1BoV[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a\x14gV[\x82[\x90P[\x92\x91PPV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a\x14\x98W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a\x08\x89\x84\x84_\x85\x85__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa\x14\xD2\x91\x90a\x1B\xDBV[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a\x15\x0CW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x15\x11V[``\x91P[P\x91P\x91Pa\x15\"\x87\x83\x83\x87a\x15-V[\x97\x96PPPPPPPV[``\x83\x15a\x15\x9BW\x82Q_\x03a\x15\x94W`\x01`\x01`\xA0\x1B\x03\x85\x16;a\x15\x94W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x05nV[P\x81a\x08\x89V[a\x08\x89\x83\x83\x81Q\x15a\x15\xB0W\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05n\x91\x90a\x1B\xF1V[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[__\x82\x84\x03`\xA0\x81\x12\x15a\x15\xFCW__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x11W__\xFD[\x84\x01`\xA0\x81\x87\x03\x12\x15a\x16\"W__\xFD[\x92P`\x80`\x1F\x19\x82\x01\x12\x15a\x165W__\xFD[P` \x83\x01\x90P\x92P\x92\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x16XW__\xFD[\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x16XW__\xFD[__\x83`\x1F\x84\x01\x12a\x16\x83W__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\x99W__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a\x0EwW__\xFD[____``\x85\x87\x03\x12\x15a\x16\xC3W__\xFD[a\x16\xCC\x85a\x16CV[\x93Pa\x16\xDA` \x86\x01a\x16]V[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x16\xF4W__\xFD[a\x17\0\x87\x82\x88\x01a\x16sV[\x95\x98\x94\x97P\x95PPPPV[_____`\x80\x86\x88\x03\x12\x15a\x17 W__\xFD[a\x17)\x86a\x16CV[\x94Pa\x177` \x87\x01a\x16]V[\x93P`@\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x17QW__\xFD[a\x17]\x88\x82\x89\x01a\x16sV[\x90\x94P\x92Pa\x17p\x90P``\x87\x01a\x16]V[\x90P\x92\x95P\x92\x95\x90\x93PV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x17\xB2Wa\x17\xB2a\x17|V[`@R\x90V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a\x17\xE0Wa\x17\xE0a\x17|V[`@R\x91\x90PV[_`\x80\x82\x84\x03\x12\x15a\x17\xF8W__\xFD[a\x18\0a\x17\x90V[\x90Pa\x18\x0B\x82a\x16CV[\x81Ra\x18\x19` \x83\x01a\x16]V[` \x82\x01R`@\x82\x015`@\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18@W__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a\x18PW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18iWa\x18ia\x17|V[a\x18|`\x1F\x82\x01`\x1F\x19\x16` \x01a\x17\xB8V[\x81\x81R\x85` \x83\x85\x01\x01\x11\x15a\x18\x90W__\xFD[\x81` \x84\x01` \x83\x017_` \x83\x83\x01\x01R\x80``\x85\x01RPPP\x92\x91PPV[___``\x84\x86\x03\x12\x15a\x18\xC3W__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\x18\xD8W__\xFD[a\x18\xE4\x86\x82\x87\x01a\x17\xE8V[\x93PPa\x18\xF3` \x85\x01a\x16CV[\x91Pa\x19\x01`@\x85\x01a\x16]V[\x90P\x92P\x92P\x92V[_` \x82\x84\x03\x12\x15a\x19\x1AW__\xFD[a\x14g\x82a\x16]V[__`@\x83\x85\x03\x12\x15a\x194W__\xFD[a\x19=\x83a\x16]V[\x91Pa\x19K` \x84\x01a\x16]V[\x90P\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a\x19dW__\xFD[\x815a\xFF\xFF\x81\x16\x81\x14a\x19uW__\xFD[\x93\x92PPPV[_` \x82\x84\x03\x12\x15a\x19\x8CW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a\x19\xA1W__\xFD[a\x08\x89\x84\x82\x85\x01a\x17\xE8V[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a\x19\xD1W__\xFD[\x81Q\x80\x15\x15\x81\x14a\x19uW__\xFD[_` \x82\x84\x03\x12\x15a\x19\xF0W__\xFD[PQ\x91\x90PV[_` \x82\x84\x03\x12\x15a\x1A\x07W__\xFD[a\x14g\x82a\x16CV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a\x1A%W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1A>W__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a\x0EwW__\xFD[__\x835`\x1E\x19\x846\x03\x01\x81\x12a\x1AgW__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a\x1A\x80W__\xFD[` \x01\x91P`\x07\x81\x90\x1B6\x03\x82\x13\x15a\x0EwW__\xFD[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x805`\x03\x81\x10a\x16XW__\xFD[_` \x82\x84\x03\x12\x15a\x1A\xC9W__\xFD[a\x14g\x82a\x1A\xABV[_`\x80\x82\x84\x03\x12\x80\x15a\x1A\xE3W__\xFD[Pa\x1A\xECa\x17\x90V[a\x1A\xF5\x83a\x16CV[\x81Ra\x1B\x03` \x84\x01a\x1A\xABV[` \x82\x01Ra\x1B\x14`@\x84\x01a\x16]V[`@\x82\x01Ra\x1B%``\x84\x01a\x16]V[``\x82\x01R\x93\x92PPPV[\x81\x81\x03\x81\x81\x11\x15a\x14jWcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[_\x82a\x1BjWcNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[P\x06\x90V[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a\x1B\xA9WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE\xA2dipfsX\"\x12 \x19\x18\x07'}3\0\xB0\xC3I\xD7\xC3\xCC\x9C\x87\x7F1\xA6\x14\xE5\x01\xBF\xF39E\x0FCR\xFB\x98\xECYdsolcC\0\x08\x1E\x003",
    );
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BlockParams { uint16 blockIndex; uint48 anchorBlockNumber; bytes32 anchorBlockHash; bytes32 anchorStateRoot; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlockParams {
        #[allow(missing_docs)]
        pub blockIndex: u16,
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub anchorBlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            u16,
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
        impl ::core::convert::From<BlockParams> for UnderlyingRustTuple<'_> {
            fn from(value: BlockParams) -> Self {
                (
                    value.blockIndex,
                    value.anchorBlockNumber,
                    value.anchorBlockHash,
                    value.anchorStateRoot,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlockParams {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    blockIndex: tuple.0,
                    anchorBlockNumber: tuple.1,
                    anchorBlockHash: tuple.2,
                    anchorStateRoot: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlockParams {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlockParams {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::SolType>::tokenize(&self.blockIndex),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorStateRoot),
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
        impl alloy_sol_types::SolType for BlockParams {
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
        impl alloy_sol_types::SolStruct for BlockParams {
            const NAME: &'static str = "BlockParams";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlockParams(uint16 blockIndex,uint48 anchorBlockNumber,bytes32 anchorBlockHash,bytes32 anchorStateRoot)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.blockIndex)
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.anchorBlockNumber,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.anchorBlockHash,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.anchorStateRoot,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlockParams {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        16,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.blockIndex,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorBlockHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorStateRoot,
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
                    &rust.blockIndex,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.anchorBlockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.anchorBlockHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.anchorStateRoot,
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
struct BlockState { uint48 anchorBlockNumber; bytes32 ancestorsHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlockState {
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub ancestorsHash: alloy::sol_types::private::FixedBytes<32>,
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
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
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
        impl ::core::convert::From<BlockState> for UnderlyingRustTuple<'_> {
            fn from(value: BlockState) -> Self {
                (value.anchorBlockNumber, value.ancestorsHash)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlockState {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    anchorBlockNumber: tuple.0,
                    ancestorsHash: tuple.1,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for BlockState {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for BlockState {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.ancestorsHash),
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
        impl alloy_sol_types::SolType for BlockState {
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
        impl alloy_sol_types::SolStruct for BlockState {
            const NAME: &'static str = "BlockState";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "BlockState(uint48 anchorBlockNumber,bytes32 ancestorsHash)",
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
                            &self.anchorBlockNumber,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.ancestorsHash)
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for BlockState {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.ancestorsHash,
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
                    &rust.anchorBlockNumber,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.ancestorsHash,
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
struct ProposalParams { uint48 proposalId; address proposer; bytes proverAuth; bytes32 bondInstructionsHash; LibBonds.BondInstruction[] bondInstructions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposalParams {
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub proverAuth: alloy::sol_types::private::Bytes,
        #[allow(missing_docs)]
        pub bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Bytes,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
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
        impl ::core::convert::From<ProposalParams> for UnderlyingRustTuple<'_> {
            fn from(value: ProposalParams) -> Self {
                (
                    value.proposalId,
                    value.proposer,
                    value.proverAuth,
                    value.bondInstructionsHash,
                    value.bondInstructions,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposalParams {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposalId: tuple.0,
                    proposer: tuple.1,
                    proverAuth: tuple.2,
                    bondInstructionsHash: tuple.3,
                    bondInstructions: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProposalParams {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProposalParams {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.proposer,
                    ),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.proverAuth,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructionsHash),
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
        impl alloy_sol_types::SolType for ProposalParams {
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
        impl alloy_sol_types::SolStruct for ProposalParams {
            const NAME: &'static str = "ProposalParams";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProposalParams(uint48 proposalId,address proposer,bytes proverAuth,bytes32 bondInstructionsHash,LibBonds.BondInstruction[] bondInstructions)",
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
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalId)
                        .0,
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proposer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proverAuth,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.bondInstructionsHash,
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
        impl alloy_sol_types::EventTopic for ProposalParams {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalId,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposer,
                    )
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proverAuth,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructionsHash,
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
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposalId,
                    out,
                );
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposer,
                    out,
                );
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proverAuth,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.bondInstructionsHash,
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
struct ProposalState { bytes32 bondInstructionsHash; address designatedProver; bool isLowBondProposal; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposalState {
        #[allow(missing_docs)]
        pub bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub designatedProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub isLowBondProposal: bool,
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
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Bool,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::FixedBytes<32>,
            alloy::sol_types::private::Address,
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
        impl ::core::convert::From<ProposalState> for UnderlyingRustTuple<'_> {
            fn from(value: ProposalState) -> Self {
                (
                    value.bondInstructionsHash,
                    value.designatedProver,
                    value.isLowBondProposal,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProposalState {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    bondInstructionsHash: tuple.0,
                    designatedProver: tuple.1,
                    isLowBondProposal: tuple.2,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProposalState {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProposalState {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructionsHash),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver,
                    ),
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isLowBondProposal,
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
        impl alloy_sol_types::SolType for ProposalState {
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
        impl alloy_sol_types::SolStruct for ProposalState {
            const NAME: &'static str = "ProposalState";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProposalState(bytes32 bondInstructionsHash,address designatedProver,bool isLowBondProposal)",
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.designatedProver,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::eip712_data_word(
                            &self.isLowBondProposal,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProposalState {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.bondInstructionsHash,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.designatedProver,
                    )
                    + <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.isLowBondProposal,
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
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.designatedProver,
                    out,
                );
                <alloy::sol_types::sol_data::Bool as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.isLowBondProposal,
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
struct ProverAuth { uint48 proposalId; address proposer; uint256 provingFee; bytes signature; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProverAuth {
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub provingFee: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub signature: alloy::sol_types::private::Bytes,
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
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Uint<256>,
            alloy::sol_types::sol_data::Bytes,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::Address,
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
        impl ::core::convert::From<ProverAuth> for UnderlyingRustTuple<'_> {
            fn from(value: ProverAuth) -> Self {
                (value.proposalId, value.proposer, value.provingFee, value.signature)
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ProverAuth {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    proposalId: tuple.0,
                    proposer: tuple.1,
                    provingFee: tuple.2,
                    signature: tuple.3,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for ProverAuth {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for ProverAuth {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.proposer,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.provingFee),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self.signature,
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
        impl alloy_sol_types::SolType for ProverAuth {
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
        impl alloy_sol_types::SolStruct for ProverAuth {
            const NAME: &'static str = "ProverAuth";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "ProverAuth(uint48 proposalId,address proposer,uint256 provingFee,bytes signature)",
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::eip712_data_word(
                            &self.proposer,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.provingFee)
                        .0,
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::eip712_data_word(
                            &self.signature,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for ProverAuth {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalId,
                    )
                    + <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposer,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.provingFee,
                    )
                    + <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.signature,
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
                <alloy::sol_types::sol_data::Address as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposer,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    256,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.provingFee,
                    out,
                );
                <alloy::sol_types::sol_data::Bytes as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.signature,
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
    /**Custom error with signature `AncestorsHashMismatch()` and selector `0x49645ffd`.
```solidity
error AncestorsHashMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct AncestorsHashMismatch;
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
        impl ::core::convert::From<AncestorsHashMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: AncestorsHashMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for AncestorsHashMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for AncestorsHashMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "AncestorsHashMismatch()";
            const SELECTOR: [u8; 4] = [73u8, 100u8, 95u8, 253u8];
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
    /**Custom error with signature `InvalidAddress()` and selector `0xe6c4247b`.
```solidity
error InvalidAddress();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidAddress;
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
        impl ::core::convert::From<InvalidAddress> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidAddress) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidAddress {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidAddress {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidAddress()";
            const SELECTOR: [u8; 4] = [230u8, 196u8, 36u8, 123u8];
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
    /**Custom error with signature `InvalidL1ChainId()` and selector `0xca40667b`.
```solidity
error InvalidL1ChainId();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidL1ChainId;
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
        impl ::core::convert::From<InvalidL1ChainId> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidL1ChainId) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidL1ChainId {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidL1ChainId {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidL1ChainId()";
            const SELECTOR: [u8; 4] = [202u8, 64u8, 102u8, 123u8];
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
    /**Custom error with signature `InvalidL2ChainId()` and selector `0xa16c4ba8`.
```solidity
error InvalidL2ChainId();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidL2ChainId;
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
        impl ::core::convert::From<InvalidL2ChainId> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidL2ChainId) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidL2ChainId {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidL2ChainId {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidL2ChainId()";
            const SELECTOR: [u8; 4] = [161u8, 108u8, 75u8, 168u8];
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
    /**Custom error with signature `InvalidSender()` and selector `0xddb5de5e`.
```solidity
error InvalidSender();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidSender;
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
        impl ::core::convert::From<InvalidSender> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidSender) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidSender {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidSender {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidSender()";
            const SELECTOR: [u8; 4] = [221u8, 181u8, 222u8, 94u8];
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
    /**Event with signature `Anchored(bytes32,address,bool,uint48,bytes32)` and selector `0xabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e9734`.
```solidity
event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 anchorBlockNumber, bytes32 ancestorsHash);
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
        pub bondInstructionsHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub designatedProver: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub isLowBondProposal: bool,
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub ancestorsHash: alloy::sol_types::private::FixedBytes<32>,
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
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bool,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Anchored(bytes32,address,bool,uint48,bytes32)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                171u8, 225u8, 171u8, 43u8, 162u8, 44u8, 103u8, 42u8, 219u8, 194u8, 158u8,
                53u8, 222u8, 54u8, 219u8, 120u8, 232u8, 178u8, 210u8, 206u8, 93u8, 96u8,
                2u8, 99u8, 41u8, 213u8, 45u8, 165u8, 243u8, 30u8, 151u8, 52u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    bondInstructionsHash: data.0,
                    designatedProver: data.1,
                    isLowBondProposal: data.2,
                    anchorBlockNumber: data.3,
                    ancestorsHash: data.4,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.bondInstructionsHash),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.designatedProver,
                    ),
                    <alloy::sol_types::sol_data::Bool as alloy_sol_types::SolType>::tokenize(
                        &self.isLowBondProposal,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.ancestorsHash),
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
constructor(address _checkpointStore, address _bondManager, uint256 _livenessBond, uint256 _provabilityBond, uint64 _l1ChainId, address _owner);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct constructorCall {
        #[allow(missing_docs)]
        pub _checkpointStore: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _bondManager: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _livenessBond: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _provabilityBond: alloy::sol_types::private::primitives::aliases::U256,
        #[allow(missing_docs)]
        pub _l1ChainId: u64,
        #[allow(missing_docs)]
        pub _owner: alloy::sol_types::private::Address,
    }
    const _: () = {
        use alloy::sol_types as alloy_sol_types;
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::primitives::aliases::U256,
                alloy::sol_types::private::primitives::aliases::U256,
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
                        value._checkpointStore,
                        value._bondManager,
                        value._livenessBond,
                        value._provabilityBond,
                        value._l1ChainId,
                        value._owner,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for constructorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _checkpointStore: tuple.0,
                        _bondManager: tuple.1,
                        _livenessBond: tuple.2,
                        _provabilityBond: tuple.3,
                        _l1ChainId: tuple.4,
                        _owner: tuple.5,
                    }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolConstructor for constructorCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
                alloy::sol_types::sol_data::Uint<256>,
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._checkpointStore,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._bondManager,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._livenessBond),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self._provabilityBond),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._l1ChainId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._owner,
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
    /**Function with signature `_isMatchingProverAuthContext((uint48,address,uint256,bytes),uint48,address)` and selector `0xddececb2`.
```solidity
function _isMatchingProverAuthContext(ProverAuth memory _auth, uint48 _proposalId, address _proposer) external pure returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct _isMatchingProverAuthContextCall {
        #[allow(missing_docs)]
        pub _auth: <ProverAuth as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub _proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _proposer: alloy::sol_types::private::Address,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`_isMatchingProverAuthContext((uint48,address,uint256,bytes),uint48,address)`](_isMatchingProverAuthContextCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct _isMatchingProverAuthContextReturn {
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
                ProverAuth,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ProverAuth as alloy::sol_types::SolType>::RustType,
                alloy::sol_types::private::primitives::aliases::U48,
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
            impl ::core::convert::From<_isMatchingProverAuthContextCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: _isMatchingProverAuthContextCall) -> Self {
                    (value._auth, value._proposalId, value._proposer)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for _isMatchingProverAuthContextCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _auth: tuple.0,
                        _proposalId: tuple.1,
                        _proposer: tuple.2,
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
            impl ::core::convert::From<_isMatchingProverAuthContextReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: _isMatchingProverAuthContextReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for _isMatchingProverAuthContextReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for _isMatchingProverAuthContextCall {
            type Parameters<'a> = (
                ProverAuth,
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "_isMatchingProverAuthContext((uint48,address,uint256,bytes),uint48,address)";
            const SELECTOR: [u8; 4] = [221u8, 236u8, 236u8, 178u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <ProverAuth as alloy_sol_types::SolType>::tokenize(&self._auth),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self._proposalId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._proposer,
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
                        let r: _isMatchingProverAuthContextReturn = r.into();
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
                        let r: _isMatchingProverAuthContextReturn = r.into();
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
    #[derive()]
    /**Function with signature `anchorV4((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint16,uint48,bytes32,bytes32))` and selector `0x4e60c8bb`.
```solidity
function anchorV4(ProposalParams memory _proposalParams, BlockParams memory _blockParams) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV4Call {
        #[allow(missing_docs)]
        pub _proposalParams: <ProposalParams as alloy::sol_types::SolType>::RustType,
        #[allow(missing_docs)]
        pub _blockParams: <BlockParams as alloy::sol_types::SolType>::RustType,
    }
    ///Container type for the return parameters of the [`anchorV4((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint16,uint48,bytes32,bytes32))`](anchorV4Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct anchorV4Return {}
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
            type UnderlyingSolTuple<'a> = (ProposalParams, BlockParams);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ProposalParams as alloy::sol_types::SolType>::RustType,
                <BlockParams as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<anchorV4Call> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV4Call) -> Self {
                    (value._proposalParams, value._blockParams)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV4Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _proposalParams: tuple.0,
                        _blockParams: tuple.1,
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
            impl ::core::convert::From<anchorV4Return> for UnderlyingRustTuple<'_> {
                fn from(value: anchorV4Return) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for anchorV4Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl anchorV4Return {
            fn _tokenize(
                &self,
            ) -> <anchorV4Call as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for anchorV4Call {
            type Parameters<'a> = (ProposalParams, BlockParams);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = anchorV4Return;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "anchorV4((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint16,uint48,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [78u8, 96u8, 200u8, 187u8];
            #[inline]
            fn new<'a>(
                tuple: <Self::Parameters<'a> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                tuple.into()
            }
            #[inline]
            fn tokenize(&self) -> Self::Token<'_> {
                (
                    <ProposalParams as alloy_sol_types::SolType>::tokenize(
                        &self._proposalParams,
                    ),
                    <BlockParams as alloy_sol_types::SolType>::tokenize(
                        &self._blockParams,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                anchorV4Return::_tokenize(ret)
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
    /**Function with signature `checkpointStore()` and selector `0x955a7244`.
```solidity
function checkpointStore() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct checkpointStoreCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`checkpointStore()`](checkpointStoreCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct checkpointStoreReturn {
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
            impl ::core::convert::From<checkpointStoreCall> for UnderlyingRustTuple<'_> {
                fn from(value: checkpointStoreCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for checkpointStoreCall {
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
            impl ::core::convert::From<checkpointStoreReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: checkpointStoreReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for checkpointStoreReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for checkpointStoreCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "checkpointStore()";
            const SELECTOR: [u8; 4] = [149u8, 90u8, 114u8, 68u8];
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
                        let r: checkpointStoreReturn = r.into();
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
                        let r: checkpointStoreReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getBlockState()` and selector `0x0f439bd9`.
```solidity
function getBlockState() external view returns (BlockState memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlockStateCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getBlockState()`](getBlockStateCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getBlockStateReturn {
        #[allow(missing_docs)]
        pub _0: <BlockState as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlockStateCall> for UnderlyingRustTuple<'_> {
                fn from(value: getBlockStateCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlockStateCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (BlockState,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <BlockState as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getBlockStateReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getBlockStateReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getBlockStateReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getBlockStateCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <BlockState as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (BlockState,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getBlockState()";
            const SELECTOR: [u8; 4] = [15u8, 67u8, 155u8, 217u8];
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
                (<BlockState as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: getBlockStateReturn = r.into();
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
                        let r: getBlockStateReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getDesignatedProver(uint48,address,bytes,address)` and selector `0xb3d5e45f`.
```solidity
function getDesignatedProver(uint48 _proposalId, address _proposer, bytes memory _proverAuth, address _currentDesignatedProver) external view returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_);
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
        #[allow(missing_docs)]
        pub _currentDesignatedProver: alloy::sol_types::private::Address,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getDesignatedProver(uint48,address,bytes,address)`](getDesignatedProverCall) function.
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
                alloy::sol_types::sol_data::Address,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::primitives::aliases::U48,
                alloy::sol_types::private::Address,
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
            impl ::core::convert::From<getDesignatedProverCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getDesignatedProverCall) -> Self {
                    (
                        value._proposalId,
                        value._proposer,
                        value._proverAuth,
                        value._currentDesignatedProver,
                    )
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
                        _currentDesignatedProver: tuple.3,
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
                alloy::sol_types::sol_data::Address,
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
            const SIGNATURE: &'static str = "getDesignatedProver(uint48,address,bytes,address)";
            const SELECTOR: [u8; 4] = [179u8, 213u8, 228u8, 95u8];
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
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._currentDesignatedProver,
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
    /**Function with signature `getProposalState()` and selector `0xaade375b`.
```solidity
function getProposalState() external view returns (ProposalState memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getProposalStateCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getProposalState()`](getProposalStateCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getProposalStateReturn {
        #[allow(missing_docs)]
        pub _0: <ProposalState as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getProposalStateCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getProposalStateCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getProposalStateCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (ProposalState,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <ProposalState as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getProposalStateReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getProposalStateReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getProposalStateReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getProposalStateCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ProposalState as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ProposalState,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getProposalState()";
            const SELECTOR: [u8; 4] = [170u8, 222u8, 55u8, 91u8];
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
                (<ProposalState as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: getProposalStateReturn = r.into();
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
                        let r: getProposalStateReturn = r.into();
                        r._0
                    })
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
    /**Function with signature `livenessBond()` and selector `0xd4414221`.
```solidity
function livenessBond() external view returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct livenessBondCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`livenessBond()`](livenessBondCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct livenessBondReturn {
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
            impl ::core::convert::From<livenessBondCall> for UnderlyingRustTuple<'_> {
                fn from(value: livenessBondCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for livenessBondCall {
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
            impl ::core::convert::From<livenessBondReturn> for UnderlyingRustTuple<'_> {
                fn from(value: livenessBondReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for livenessBondReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for livenessBondCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "livenessBond()";
            const SELECTOR: [u8; 4] = [212u8, 65u8, 66u8, 33u8];
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
                        let r: livenessBondReturn = r.into();
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
                        let r: livenessBondReturn = r.into();
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
    /**Function with signature `provabilityBond()` and selector `0xcf1a0f22`.
```solidity
function provabilityBond() external view returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct provabilityBondCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`provabilityBond()`](provabilityBondCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct provabilityBondReturn {
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
            impl ::core::convert::From<provabilityBondCall> for UnderlyingRustTuple<'_> {
                fn from(value: provabilityBondCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for provabilityBondCall {
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
            impl ::core::convert::From<provabilityBondReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: provabilityBondReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for provabilityBondReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for provabilityBondCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "provabilityBond()";
            const SELECTOR: [u8; 4] = [207u8, 26u8, 15u8, 34u8];
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
                        let r: provabilityBondReturn = r.into();
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
                        let r: provabilityBondReturn = r.into();
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
    /**Function with signature `validateProverAuth(uint48,address,bytes)` and selector `0xa37ea515`.
```solidity
function validateProverAuth(uint48 _proposalId, address _proposer, bytes memory _proverAuth) external pure returns (address signer_, uint256 provingFee_);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct validateProverAuthCall {
        #[allow(missing_docs)]
        pub _proposalId: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub _proposer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _proverAuth: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`validateProverAuth(uint48,address,bytes)`](validateProverAuthCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct validateProverAuthReturn {
        #[allow(missing_docs)]
        pub signer_: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub provingFee_: alloy::sol_types::private::primitives::aliases::U256,
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
            impl ::core::convert::From<validateProverAuthCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: validateProverAuthCall) -> Self {
                    (value._proposalId, value._proposer, value._proverAuth)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for validateProverAuthCall {
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
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
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
            impl ::core::convert::From<validateProverAuthReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: validateProverAuthReturn) -> Self {
                    (value.signer_, value.provingFee_)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for validateProverAuthReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        signer_: tuple.0,
                        provingFee_: tuple.1,
                    }
                }
            }
        }
        impl validateProverAuthReturn {
            fn _tokenize(
                &self,
            ) -> <validateProverAuthCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                (
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.signer_,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        256,
                    > as alloy_sol_types::SolType>::tokenize(&self.provingFee_),
                )
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for validateProverAuthCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = validateProverAuthReturn;
            type ReturnTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::Uint<256>,
            );
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "validateProverAuth(uint48,address,bytes)";
            const SELECTOR: [u8; 4] = [163u8, 126u8, 165u8, 21u8];
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
                validateProverAuthReturn::_tokenize(ret)
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
    ///Container for all the [`Anchor`](self) function calls.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum AnchorCalls {
        #[allow(missing_docs)]
        ANCHOR_GAS_LIMIT(ANCHOR_GAS_LIMITCall),
        #[allow(missing_docs)]
        GOLDEN_TOUCH_ADDRESS(GOLDEN_TOUCH_ADDRESSCall),
        #[allow(missing_docs)]
        _isMatchingProverAuthContext(_isMatchingProverAuthContextCall),
        #[allow(missing_docs)]
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        anchorV4(anchorV4Call),
        #[allow(missing_docs)]
        bondManager(bondManagerCall),
        #[allow(missing_docs)]
        checkpointStore(checkpointStoreCall),
        #[allow(missing_docs)]
        getBlockState(getBlockStateCall),
        #[allow(missing_docs)]
        getDesignatedProver(getDesignatedProverCall),
        #[allow(missing_docs)]
        getProposalState(getProposalStateCall),
        #[allow(missing_docs)]
        l1ChainId(l1ChainIdCall),
        #[allow(missing_docs)]
        livenessBond(livenessBondCall),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        provabilityBond(provabilityBondCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        transferOwnership(transferOwnershipCall),
        #[allow(missing_docs)]
        validateProverAuth(validateProverAuthCall),
        #[allow(missing_docs)]
        withdraw(withdrawCall),
    }
    #[automatically_derived]
    impl AnchorCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [15u8, 67u8, 155u8, 217u8],
            [18u8, 98u8, 46u8, 91u8],
            [54u8, 60u8, 196u8, 39u8],
            [78u8, 96u8, 200u8, 187u8],
            [113u8, 80u8, 24u8, 166u8],
            [121u8, 186u8, 80u8, 151u8],
            [141u8, 165u8, 203u8, 91u8],
            [149u8, 90u8, 114u8, 68u8],
            [158u8, 229u8, 18u8, 242u8],
            [163u8, 126u8, 165u8, 21u8],
            [170u8, 222u8, 55u8, 91u8],
            [179u8, 213u8, 228u8, 95u8],
            [196u8, 110u8, 58u8, 102u8],
            [207u8, 26u8, 15u8, 34u8],
            [212u8, 65u8, 66u8, 33u8],
            [221u8, 236u8, 236u8, 178u8],
            [227u8, 12u8, 57u8, 120u8],
            [242u8, 253u8, 227u8, 139u8],
            [249u8, 64u8, 227u8, 133u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for AnchorCalls {
        const NAME: &'static str = "AnchorCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 19usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ANCHOR_GAS_LIMIT(_) => {
                    <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::GOLDEN_TOUCH_ADDRESS(_) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::_isMatchingProverAuthContext(_) => {
                    <_isMatchingProverAuthContextCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::anchorV4(_) => <anchorV4Call as alloy_sol_types::SolCall>::SELECTOR,
                Self::bondManager(_) => {
                    <bondManagerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::checkpointStore(_) => {
                    <checkpointStoreCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getBlockState(_) => {
                    <getBlockStateCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getDesignatedProver(_) => {
                    <getDesignatedProverCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getProposalState(_) => {
                    <getProposalStateCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::l1ChainId(_) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::livenessBond(_) => {
                    <livenessBondCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::provabilityBond(_) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::transferOwnership(_) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::validateProverAuth(_) => {
                    <validateProverAuthCall as alloy_sol_types::SolCall>::SELECTOR
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
            static DECODE_SHIMS: &[fn(&[u8]) -> alloy_sol_types::Result<AnchorCalls>] = &[
                {
                    fn getBlockState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getBlockStateCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::getBlockState)
                    }
                    getBlockState
                },
                {
                    fn l1ChainId(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <l1ChainIdCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::l1ChainId)
                    }
                    l1ChainId
                },
                {
                    fn bondManager(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <bondManagerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::bondManager)
                    }
                    bondManager
                },
                {
                    fn anchorV4(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <anchorV4Call as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::anchorV4)
                    }
                    anchorV4
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn owner(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::owner)
                    }
                    owner
                },
                {
                    fn checkpointStore(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <checkpointStoreCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::checkpointStore)
                    }
                    checkpointStore
                },
                {
                    fn GOLDEN_TOUCH_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::GOLDEN_TOUCH_ADDRESS)
                    }
                    GOLDEN_TOUCH_ADDRESS
                },
                {
                    fn validateProverAuth(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <validateProverAuthCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::validateProverAuth)
                    }
                    validateProverAuth
                },
                {
                    fn getProposalState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getProposalStateCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::getProposalState)
                    }
                    getProposalState
                },
                {
                    fn getDesignatedProver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::getDesignatedProver)
                    }
                    getDesignatedProver
                },
                {
                    fn ANCHOR_GAS_LIMIT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::ANCHOR_GAS_LIMIT)
                    }
                    ANCHOR_GAS_LIMIT
                },
                {
                    fn provabilityBond(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <provabilityBondCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::provabilityBond)
                    }
                    provabilityBond
                },
                {
                    fn livenessBond(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <livenessBondCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::livenessBond)
                    }
                    livenessBond
                },
                {
                    fn _isMatchingProverAuthContext(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <_isMatchingProverAuthContextCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::_isMatchingProverAuthContext)
                    }
                    _isMatchingProverAuthContext
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn withdraw(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <withdrawCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::withdraw)
                    }
                    withdraw
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
            ) -> alloy_sol_types::Result<AnchorCalls>] = &[
                {
                    fn getBlockState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getBlockStateCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::getBlockState)
                    }
                    getBlockState
                },
                {
                    fn l1ChainId(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <l1ChainIdCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::l1ChainId)
                    }
                    l1ChainId
                },
                {
                    fn bondManager(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <bondManagerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::bondManager)
                    }
                    bondManager
                },
                {
                    fn anchorV4(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <anchorV4Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::anchorV4)
                    }
                    anchorV4
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn owner(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::owner)
                    }
                    owner
                },
                {
                    fn checkpointStore(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <checkpointStoreCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::checkpointStore)
                    }
                    checkpointStore
                },
                {
                    fn GOLDEN_TOUCH_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::GOLDEN_TOUCH_ADDRESS)
                    }
                    GOLDEN_TOUCH_ADDRESS
                },
                {
                    fn validateProverAuth(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <validateProverAuthCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::validateProverAuth)
                    }
                    validateProverAuth
                },
                {
                    fn getProposalState(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getProposalStateCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::getProposalState)
                    }
                    getProposalState
                },
                {
                    fn getDesignatedProver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::getDesignatedProver)
                    }
                    getDesignatedProver
                },
                {
                    fn ANCHOR_GAS_LIMIT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::ANCHOR_GAS_LIMIT)
                    }
                    ANCHOR_GAS_LIMIT
                },
                {
                    fn provabilityBond(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <provabilityBondCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::provabilityBond)
                    }
                    provabilityBond
                },
                {
                    fn livenessBond(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <livenessBondCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::livenessBond)
                    }
                    livenessBond
                },
                {
                    fn _isMatchingProverAuthContext(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <_isMatchingProverAuthContextCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::_isMatchingProverAuthContext)
                    }
                    _isMatchingProverAuthContext
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn withdraw(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <withdrawCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::withdraw)
                    }
                    withdraw
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
                Self::GOLDEN_TOUCH_ADDRESS(inner) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::_isMatchingProverAuthContext(inner) => {
                    <_isMatchingProverAuthContextCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::anchorV4(inner) => {
                    <anchorV4Call as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::bondManager(inner) => {
                    <bondManagerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::checkpointStore(inner) => {
                    <checkpointStoreCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getBlockState(inner) => {
                    <getBlockStateCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getDesignatedProver(inner) => {
                    <getDesignatedProverCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getProposalState(inner) => {
                    <getProposalStateCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::l1ChainId(inner) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::livenessBond(inner) => {
                    <livenessBondCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::provabilityBond(inner) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::renounceOwnership(inner) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::validateProverAuth(inner) => {
                    <validateProverAuthCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::GOLDEN_TOUCH_ADDRESS(inner) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::_isMatchingProverAuthContext(inner) => {
                    <_isMatchingProverAuthContextCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::anchorV4(inner) => {
                    <anchorV4Call as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::checkpointStore(inner) => {
                    <checkpointStoreCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getBlockState(inner) => {
                    <getBlockStateCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::getProposalState(inner) => {
                    <getProposalStateCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::l1ChainId(inner) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::livenessBond(inner) => {
                    <livenessBondCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::owner(inner) => {
                    <ownerCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::provabilityBond(inner) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::validateProverAuth(inner) => {
                    <validateProverAuthCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
    ///Container for all the [`Anchor`](self) custom errors.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum AnchorErrors {
        #[allow(missing_docs)]
        AncestorsHashMismatch(AncestorsHashMismatch),
        #[allow(missing_docs)]
        BondInstructionsHashMismatch(BondInstructionsHashMismatch),
        #[allow(missing_docs)]
        ETH_TRANSFER_FAILED(ETH_TRANSFER_FAILED),
        #[allow(missing_docs)]
        InvalidAddress(InvalidAddress),
        #[allow(missing_docs)]
        InvalidAnchorBlockNumber(InvalidAnchorBlockNumber),
        #[allow(missing_docs)]
        InvalidBlockIndex(InvalidBlockIndex),
        #[allow(missing_docs)]
        InvalidL1ChainId(InvalidL1ChainId),
        #[allow(missing_docs)]
        InvalidL2ChainId(InvalidL2ChainId),
        #[allow(missing_docs)]
        InvalidSender(InvalidSender),
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
        ZeroBlockCount(ZeroBlockCount),
    }
    #[automatically_derived]
    impl AnchorErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [33u8, 160u8, 13u8, 103u8],
            [34u8, 147u8, 41u8, 199u8],
            [73u8, 100u8, 95u8, 253u8],
            [74u8, 57u8, 50u8, 156u8],
            [89u8, 180u8, 82u8, 239u8],
            [136u8, 196u8, 112u8, 11u8],
            [152u8, 206u8, 38u8, 154u8],
            [161u8, 108u8, 75u8, 168u8],
            [173u8, 16u8, 54u8, 31u8],
            [202u8, 34u8, 239u8, 118u8],
            [202u8, 64u8, 102u8, 123u8],
            [221u8, 181u8, 222u8, 94u8],
            [224u8, 165u8, 170u8, 129u8],
            [230u8, 196u8, 36u8, 123u8],
            [241u8, 203u8, 2u8, 53u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for AnchorErrors {
        const NAME: &'static str = "AnchorErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 15usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::AncestorsHashMismatch(_) => {
                    <AncestorsHashMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::BondInstructionsHashMismatch(_) => {
                    <BondInstructionsHashMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ETH_TRANSFER_FAILED(_) => {
                    <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidAddress(_) => {
                    <InvalidAddress as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidAnchorBlockNumber(_) => {
                    <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidBlockIndex(_) => {
                    <InvalidBlockIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidL1ChainId(_) => {
                    <InvalidL1ChainId as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidL2ChainId(_) => {
                    <InvalidL2ChainId as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidSender(_) => {
                    <InvalidSender as alloy_sol_types::SolError>::SELECTOR
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
            static DECODE_SHIMS: &[fn(&[u8]) -> alloy_sol_types::Result<AnchorErrors>] = &[
                {
                    fn NonZeroAnchorStateRoot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::NonZeroAnchorStateRoot)
                    }
                    NonZeroAnchorStateRoot
                },
                {
                    fn ProposalIdMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ProposalIdMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::ProposalIdMismatch)
                    }
                    ProposalIdMismatch
                },
                {
                    fn AncestorsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <AncestorsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::AncestorsHashMismatch)
                    }
                    AncestorsHashMismatch
                },
                {
                    fn NonZeroBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::NonZeroBlockIndex)
                    }
                    NonZeroBlockIndex
                },
                {
                    fn InvalidBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidBlockIndex as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidBlockIndex)
                    }
                    InvalidBlockIndex
                },
                {
                    fn BondInstructionsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::BondInstructionsHashMismatch)
                    }
                    BondInstructionsHashMismatch
                },
                {
                    fn ETH_TRANSFER_FAILED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::ETH_TRANSFER_FAILED)
                    }
                    ETH_TRANSFER_FAILED
                },
                {
                    fn InvalidL2ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidL2ChainId as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidL2ChainId)
                    }
                    InvalidL2ChainId
                },
                {
                    fn NonZeroAnchorBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::NonZeroAnchorBlockHash)
                    }
                    NonZeroAnchorBlockHash
                },
                {
                    fn ZeroBlockCount(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZeroBlockCount as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::ZeroBlockCount)
                    }
                    ZeroBlockCount
                },
                {
                    fn InvalidL1ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidL1ChainId as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidL1ChainId)
                    }
                    InvalidL1ChainId
                },
                {
                    fn InvalidSender(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidSender as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidSender)
                    }
                    InvalidSender
                },
                {
                    fn ProposerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ProposerMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::ProposerMismatch)
                    }
                    ProposerMismatch
                },
                {
                    fn InvalidAddress(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidAddress as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidAddress)
                    }
                    InvalidAddress
                },
                {
                    fn InvalidAnchorBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidAnchorBlockNumber)
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
            ) -> alloy_sol_types::Result<AnchorErrors>] = &[
                {
                    fn NonZeroAnchorStateRoot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroAnchorStateRoot as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::NonZeroAnchorStateRoot)
                    }
                    NonZeroAnchorStateRoot
                },
                {
                    fn ProposalIdMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ProposalIdMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ProposalIdMismatch)
                    }
                    ProposalIdMismatch
                },
                {
                    fn AncestorsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <AncestorsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::AncestorsHashMismatch)
                    }
                    AncestorsHashMismatch
                },
                {
                    fn NonZeroBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroBlockIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::NonZeroBlockIndex)
                    }
                    NonZeroBlockIndex
                },
                {
                    fn InvalidBlockIndex(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidBlockIndex as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidBlockIndex)
                    }
                    InvalidBlockIndex
                },
                {
                    fn BondInstructionsHashMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <BondInstructionsHashMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::BondInstructionsHashMismatch)
                    }
                    BondInstructionsHashMismatch
                },
                {
                    fn ETH_TRANSFER_FAILED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ETH_TRANSFER_FAILED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ETH_TRANSFER_FAILED)
                    }
                    ETH_TRANSFER_FAILED
                },
                {
                    fn InvalidL2ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidL2ChainId as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidL2ChainId)
                    }
                    InvalidL2ChainId
                },
                {
                    fn NonZeroAnchorBlockHash(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <NonZeroAnchorBlockHash as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::NonZeroAnchorBlockHash)
                    }
                    NonZeroAnchorBlockHash
                },
                {
                    fn ZeroBlockCount(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZeroBlockCount as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ZeroBlockCount)
                    }
                    ZeroBlockCount
                },
                {
                    fn InvalidL1ChainId(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidL1ChainId as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidL1ChainId)
                    }
                    InvalidL1ChainId
                },
                {
                    fn InvalidSender(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidSender as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidSender)
                    }
                    InvalidSender
                },
                {
                    fn ProposerMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ProposerMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ProposerMismatch)
                    }
                    ProposerMismatch
                },
                {
                    fn InvalidAddress(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidAddress as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidAddress)
                    }
                    InvalidAddress
                },
                {
                    fn InvalidAnchorBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidAnchorBlockNumber)
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
                Self::AncestorsHashMismatch(inner) => {
                    <AncestorsHashMismatch as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::InvalidAddress(inner) => {
                    <InvalidAddress as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::InvalidL1ChainId(inner) => {
                    <InvalidL1ChainId as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidL2ChainId(inner) => {
                    <InvalidL2ChainId as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidSender(inner) => {
                    <InvalidSender as alloy_sol_types::SolError>::abi_encoded_size(inner)
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
                Self::AncestorsHashMismatch(inner) => {
                    <AncestorsHashMismatch as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::InvalidAddress(inner) => {
                    <InvalidAddress as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::InvalidL1ChainId(inner) => {
                    <InvalidL1ChainId as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidL2ChainId(inner) => {
                    <InvalidL2ChainId as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidSender(inner) => {
                    <InvalidSender as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::ZeroBlockCount(inner) => {
                    <ZeroBlockCount as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`Anchor`](self) events.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum AnchorEvents {
        #[allow(missing_docs)]
        Anchored(Anchored),
        #[allow(missing_docs)]
        OwnershipTransferStarted(OwnershipTransferStarted),
        #[allow(missing_docs)]
        OwnershipTransferred(OwnershipTransferred),
        #[allow(missing_docs)]
        Withdrawn(Withdrawn),
    }
    #[automatically_derived]
    impl AnchorEvents {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 32usize]] = &[
            [
                56u8, 209u8, 107u8, 140u8, 172u8, 34u8, 217u8, 159u8, 199u8, 193u8, 36u8,
                185u8, 205u8, 13u8, 226u8, 211u8, 250u8, 31u8, 174u8, 244u8, 32u8, 191u8,
                231u8, 145u8, 216u8, 195u8, 98u8, 215u8, 101u8, 226u8, 39u8, 0u8,
            ],
            [
                139u8, 224u8, 7u8, 156u8, 83u8, 22u8, 89u8, 20u8, 19u8, 68u8, 205u8,
                31u8, 208u8, 164u8, 242u8, 132u8, 25u8, 73u8, 127u8, 151u8, 34u8, 163u8,
                218u8, 175u8, 227u8, 180u8, 24u8, 111u8, 107u8, 100u8, 87u8, 224u8,
            ],
            [
                171u8, 225u8, 171u8, 43u8, 162u8, 44u8, 103u8, 42u8, 219u8, 194u8, 158u8,
                53u8, 222u8, 54u8, 219u8, 120u8, 232u8, 178u8, 210u8, 206u8, 93u8, 96u8,
                2u8, 99u8, 41u8, 213u8, 45u8, 165u8, 243u8, 30u8, 151u8, 52u8,
            ],
            [
                209u8, 193u8, 159u8, 188u8, 212u8, 85u8, 26u8, 94u8, 223u8, 182u8, 109u8,
                67u8, 210u8, 227u8, 55u8, 192u8, 72u8, 55u8, 175u8, 218u8, 52u8, 130u8,
                180u8, 43u8, 223u8, 86u8, 154u8, 143u8, 204u8, 218u8, 229u8, 251u8,
            ],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolEventInterface for AnchorEvents {
        const NAME: &'static str = "AnchorEvents";
        const COUNT: usize = 4usize;
        fn decode_raw_log(
            topics: &[alloy_sol_types::Word],
            data: &[u8],
        ) -> alloy_sol_types::Result<Self> {
            match topics.first().copied() {
                Some(<Anchored as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <Anchored as alloy_sol_types::SolEvent>::decode_raw_log(topics, data)
                        .map(Self::Anchored)
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
    impl alloy_sol_types::private::IntoLogData for AnchorEvents {
        fn to_log_data(&self) -> alloy_sol_types::private::LogData {
            match self {
                Self::Anchored(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OwnershipTransferStarted(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::OwnershipTransferred(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::Withdrawn(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
            }
        }
        fn into_log_data(self) -> alloy_sol_types::private::LogData {
            match self {
                Self::Anchored(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OwnershipTransferStarted(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::OwnershipTransferred(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
                Self::Withdrawn(inner) => {
                    alloy_sol_types::private::IntoLogData::into_log_data(inner)
                }
            }
        }
    }
    use alloy::contract as alloy_contract;
    /**Creates a new wrapper around an on-chain [`Anchor`](self) contract instance.

See the [wrapper's documentation](`AnchorInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(address: alloy_sol_types::private::Address, provider: P) -> AnchorInstance<P, N> {
        AnchorInstance::<P, N>::new(address, provider)
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
        _checkpointStore: alloy::sol_types::private::Address,
        _bondManager: alloy::sol_types::private::Address,
        _livenessBond: alloy::sol_types::private::primitives::aliases::U256,
        _provabilityBond: alloy::sol_types::private::primitives::aliases::U256,
        _l1ChainId: u64,
        _owner: alloy::sol_types::private::Address,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<AnchorInstance<P, N>>,
    > {
        AnchorInstance::<
            P,
            N,
        >::deploy(
            provider,
            _checkpointStore,
            _bondManager,
            _livenessBond,
            _provabilityBond,
            _l1ChainId,
            _owner,
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
        _checkpointStore: alloy::sol_types::private::Address,
        _bondManager: alloy::sol_types::private::Address,
        _livenessBond: alloy::sol_types::private::primitives::aliases::U256,
        _provabilityBond: alloy::sol_types::private::primitives::aliases::U256,
        _l1ChainId: u64,
        _owner: alloy::sol_types::private::Address,
    ) -> alloy_contract::RawCallBuilder<P, N> {
        AnchorInstance::<
            P,
            N,
        >::deploy_builder(
            provider,
            _checkpointStore,
            _bondManager,
            _livenessBond,
            _provabilityBond,
            _l1ChainId,
            _owner,
        )
    }
    /**A [`Anchor`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`Anchor`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct AnchorInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for AnchorInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("AnchorInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    #[automatically_derived]
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > AnchorInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`Anchor`](self) contract instance.

See the [wrapper's documentation](`AnchorInstance`) for more details.*/
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
            _checkpointStore: alloy::sol_types::private::Address,
            _bondManager: alloy::sol_types::private::Address,
            _livenessBond: alloy::sol_types::private::primitives::aliases::U256,
            _provabilityBond: alloy::sol_types::private::primitives::aliases::U256,
            _l1ChainId: u64,
            _owner: alloy::sol_types::private::Address,
        ) -> alloy_contract::Result<AnchorInstance<P, N>> {
            let call_builder = Self::deploy_builder(
                provider,
                _checkpointStore,
                _bondManager,
                _livenessBond,
                _provabilityBond,
                _l1ChainId,
                _owner,
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
            _checkpointStore: alloy::sol_types::private::Address,
            _bondManager: alloy::sol_types::private::Address,
            _livenessBond: alloy::sol_types::private::primitives::aliases::U256,
            _provabilityBond: alloy::sol_types::private::primitives::aliases::U256,
            _l1ChainId: u64,
            _owner: alloy::sol_types::private::Address,
        ) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                provider,
                [
                    &BYTECODE[..],
                    &alloy_sol_types::SolConstructor::abi_encode(
                        &constructorCall {
                            _checkpointStore,
                            _bondManager,
                            _livenessBond,
                            _provabilityBond,
                            _l1ChainId,
                            _owner,
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
    impl<P: ::core::clone::Clone, N> AnchorInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> AnchorInstance<P, N> {
            AnchorInstance {
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
    > AnchorInstance<P, N> {
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
        ///Creates a new call builder for the [`GOLDEN_TOUCH_ADDRESS`] function.
        pub fn GOLDEN_TOUCH_ADDRESS(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, GOLDEN_TOUCH_ADDRESSCall, N> {
            self.call_builder(&GOLDEN_TOUCH_ADDRESSCall)
        }
        ///Creates a new call builder for the [`_isMatchingProverAuthContext`] function.
        pub fn _isMatchingProverAuthContext(
            &self,
            _auth: <ProverAuth as alloy::sol_types::SolType>::RustType,
            _proposalId: alloy::sol_types::private::primitives::aliases::U48,
            _proposer: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, _isMatchingProverAuthContextCall, N> {
            self.call_builder(
                &_isMatchingProverAuthContextCall {
                    _auth,
                    _proposalId,
                    _proposer,
                },
            )
        }
        ///Creates a new call builder for the [`acceptOwnership`] function.
        pub fn acceptOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, acceptOwnershipCall, N> {
            self.call_builder(&acceptOwnershipCall)
        }
        ///Creates a new call builder for the [`anchorV4`] function.
        pub fn anchorV4(
            &self,
            _proposalParams: <ProposalParams as alloy::sol_types::SolType>::RustType,
            _blockParams: <BlockParams as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, anchorV4Call, N> {
            self.call_builder(
                &anchorV4Call {
                    _proposalParams,
                    _blockParams,
                },
            )
        }
        ///Creates a new call builder for the [`bondManager`] function.
        pub fn bondManager(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, bondManagerCall, N> {
            self.call_builder(&bondManagerCall)
        }
        ///Creates a new call builder for the [`checkpointStore`] function.
        pub fn checkpointStore(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, checkpointStoreCall, N> {
            self.call_builder(&checkpointStoreCall)
        }
        ///Creates a new call builder for the [`getBlockState`] function.
        pub fn getBlockState(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, getBlockStateCall, N> {
            self.call_builder(&getBlockStateCall)
        }
        ///Creates a new call builder for the [`getDesignatedProver`] function.
        pub fn getDesignatedProver(
            &self,
            _proposalId: alloy::sol_types::private::primitives::aliases::U48,
            _proposer: alloy::sol_types::private::Address,
            _proverAuth: alloy::sol_types::private::Bytes,
            _currentDesignatedProver: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, getDesignatedProverCall, N> {
            self.call_builder(
                &getDesignatedProverCall {
                    _proposalId,
                    _proposer,
                    _proverAuth,
                    _currentDesignatedProver,
                },
            )
        }
        ///Creates a new call builder for the [`getProposalState`] function.
        pub fn getProposalState(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, getProposalStateCall, N> {
            self.call_builder(&getProposalStateCall)
        }
        ///Creates a new call builder for the [`l1ChainId`] function.
        pub fn l1ChainId(&self) -> alloy_contract::SolCallBuilder<&P, l1ChainIdCall, N> {
            self.call_builder(&l1ChainIdCall)
        }
        ///Creates a new call builder for the [`livenessBond`] function.
        pub fn livenessBond(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, livenessBondCall, N> {
            self.call_builder(&livenessBondCall)
        }
        ///Creates a new call builder for the [`owner`] function.
        pub fn owner(&self) -> alloy_contract::SolCallBuilder<&P, ownerCall, N> {
            self.call_builder(&ownerCall)
        }
        ///Creates a new call builder for the [`pendingOwner`] function.
        pub fn pendingOwner(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, pendingOwnerCall, N> {
            self.call_builder(&pendingOwnerCall)
        }
        ///Creates a new call builder for the [`provabilityBond`] function.
        pub fn provabilityBond(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, provabilityBondCall, N> {
            self.call_builder(&provabilityBondCall)
        }
        ///Creates a new call builder for the [`renounceOwnership`] function.
        pub fn renounceOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, renounceOwnershipCall, N> {
            self.call_builder(&renounceOwnershipCall)
        }
        ///Creates a new call builder for the [`transferOwnership`] function.
        pub fn transferOwnership(
            &self,
            newOwner: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, transferOwnershipCall, N> {
            self.call_builder(&transferOwnershipCall { newOwner })
        }
        ///Creates a new call builder for the [`validateProverAuth`] function.
        pub fn validateProverAuth(
            &self,
            _proposalId: alloy::sol_types::private::primitives::aliases::U48,
            _proposer: alloy::sol_types::private::Address,
            _proverAuth: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, validateProverAuthCall, N> {
            self.call_builder(
                &validateProverAuthCall {
                    _proposalId,
                    _proposer,
                    _proverAuth,
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
    > AnchorInstance<P, N> {
        /// Creates a new event filter using this contract instance's provider and address.
        ///
        /// Note that the type can be any event, not just those defined in this contract.
        /// Prefer using the other methods for building type-safe event filters.
        pub fn event_filter<E: alloy_sol_types::SolEvent>(
            &self,
        ) -> alloy_contract::Event<&P, E, N> {
            alloy_contract::Event::new_sol(&self.provider, &self.address)
        }
        ///Creates a new event filter for the [`Anchored`] event.
        pub fn Anchored_filter(&self) -> alloy_contract::Event<&P, Anchored, N> {
            self.event_filter::<Anchored>()
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
        ///Creates a new event filter for the [`Withdrawn`] event.
        pub fn Withdrawn_filter(&self) -> alloy_contract::Event<&P, Withdrawn, N> {
            self.event_filter::<Withdrawn>()
        }
    }
}
