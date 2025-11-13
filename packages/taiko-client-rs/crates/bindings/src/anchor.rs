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
        uint48 anchorBlockNumber;
        bytes32 anchorBlockHash;
        bytes32 anchorStateRoot;
        bytes32 rawTxListHash;
    }
    struct BlockState {
        uint48 anchorBlockNumber;
        bytes32 ancestorsHash;
    }
    struct PreconfMetadata {
        uint48 anchorBlockNumber;
        uint48 submissionWindowEnd;
        uint48 parentSubmissionWindowEnd;
        bytes32 rawTxListHash;
        bytes32 parentRawTxListHash;
    }
    struct ProposalParams {
        uint48 submissionWindowEnd;
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
        uint48 proposalId;
    }

    error ACCESS_DENIED();
    error AncestorsHashMismatch();
    error BondInstructionsHashMismatch();
    error ETH_TRANSFER_FAILED();
    error FUNC_NOT_IMPLEMENTED();
    error INVALID_PAUSE_STATUS();
    error InvalidAddress();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidBlockNumber();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error REENTRANT_CALL();
    error ZERO_ADDRESS();
    error ZERO_VALUE();
    error ZeroBlockCount();

    event AdminChanged(address previousAdmin, address newAdmin);
    event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash);
    event BeaconUpgraded(address indexed beacon);
    event Initialized(uint8 version);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);
    event Withdrawn(address token, address to, uint256 amount);

    constructor(address _checkpointStore, address _bondManager, uint256 _livenessBond, uint256 _provabilityBond, uint64 _l1ChainId, address _owner);

    function ANCHOR_GAS_LIMIT() external view returns (uint64);
    function GOLDEN_TOUCH_ADDRESS() external view returns (address);
    function acceptOwnership() external;
    function anchorV4(ProposalParams memory _proposalParams, BlockParams memory _blockParams) external;
    function blockHashes(uint256 blockNumber) external view returns (bytes32 blockHash);
    function bondManager() external view returns (address);
    function checkpointStore() external view returns (address);
    function getBlockState() external view returns (BlockState memory);
    function getDesignatedProver(uint48 _proposalId, address _proposer, bytes memory _proverAuth, address _currentDesignatedProver) external view returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_);
    function getPreconfMetadata(uint256 _blockNumber) external view returns (PreconfMetadata memory);
    function getProposalState() external view returns (ProposalState memory);
    function impl() external view returns (address);
    function inNonReentrant() external view returns (bool);
    function l1ChainId() external view returns (uint64);
    function livenessBond() external view returns (uint256);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function provabilityBond() external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function resolver() external view returns (address);
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
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
            "name": "submissionWindowEnd",
            "type": "uint48",
            "internalType": "uint48"
          },
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
          },
          {
            "name": "rawTxListHash",
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
    "name": "blockHashes",
    "inputs": [
      {
        "name": "blockNumber",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "blockHash",
        "type": "bytes32",
        "internalType": "bytes32"
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
    "name": "getPreconfMetadata",
    "inputs": [
      {
        "name": "_blockNumber",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct Anchor.PreconfMetadata",
        "components": [
          {
            "name": "anchorBlockNumber",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "submissionWindowEnd",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "parentSubmissionWindowEnd",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "rawTxListHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "parentRawTxListHash",
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
          },
          {
            "name": "proposalId",
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
        "name": "prevAnchorBlockNumber",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
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
    "name": "InvalidBlockNumber",
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
    "name": "REENTRANT_CALL",
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
pub mod Anchor {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x61016060405230608052348015610014575f5ffd5b50604051612d78380380612d78833981016040819052610033916102a0565b61003b610163565b6001600160a01b0386166100625760405163e6c4247b60e01b815260040160405180910390fd5b6001600160a01b0385166100895760405163e6c4247b60e01b815260040160405180910390fd5b6001600160a01b0381166100b05760405163e6c4247b60e01b815260040160405180910390fd5b6001600160401b038216158015906100d1575046826001600160401b031614155b6100ee5760405163ca40667b60e01b815260040160405180910390fd5b60014611801561010557506001600160401b034611155b6101225760405163142d897560e31b815260040160405180910390fd5b6001600160a01b0380871660e052851660c0526101008490526101208390526001600160401b038216610140526101588161021f565b50505050505061031b565b5f54610100900460ff16156101ce5760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b5f5460ff9081161461021d575f805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b606580546001600160a01b03191690556102388161023b565b50565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b6001600160a01b0381168114610238575f5ffd5b5f5f5f5f5f5f60c087890312156102b5575f5ffd5b86516102c08161028c565b60208801519096506102d18161028c565b6040880151606089015160808a015192975090955093506001600160401b03811681146102fc575f5ffd5b60a088015190925061030d8161028c565b809150509295509295509295565b60805160a05160c05160e0516101005161012051610140516129b16103c75f395f61026d01525f818161067f0152611fa801525f81816106b20152611f6801525f81816104c8015261159301525f818161038d01528181610e2301528181610ef40152818161138f0152818161145d01528181611a900152611b3f01525f6101cc01525f81816107fe0152818161084701528181610abd01528181610afd0152610b7401526129b15ff3fe6080604052600436106101ba575f3560e01c806379ba5097116100f2578063aade375b11610092578063d441422111610062578063d4414221146106a1578063e30c3978146106d4578063f2fde38b146106f1578063f940e38514610710575f5ffd5b8063aade375b1461054d578063b3d5e45f14610614578063c46e3a6614610658578063cf1a0f221461066e575f5ffd5b80638da5cb5b116100cd5780638da5cb5b1461049a578063955a7244146104b75780639ee512f2146104ea578063a37ea5151461050f575f5ffd5b806379ba50971461045e5780638456cb59146104725780638abf607714610486575f5ffd5b80633659cfe61161015d5780634f1ef286116101385780634f1ef2861461040357806352d1902d146104165780635c975abb1461042a578063715018a61461044a575f5ffd5b80633659cfe6146103af5780633c7aa911146103d05780633f4ba83a146103ef575f5ffd5b8063260c534411610198578063260c5344146102a75780633075db561461031f57806334cdf78d14610343578063363cc4271461037c575f5ffd5b806304f3bcec146101be5780630f439bd91461020957806312622e5b1461025c575b5f5ffd5b3480156101c9575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b348015610214575f5ffd5b506040805180820182525f808252602091820152815180830183526101015465ffffffffffff1680825261010254918301918252835190815290519181019190915201610200565b348015610267575f5ffd5b5061028f7f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b039091168152602001610200565b3480156102b2575f5ffd5b506102c66102c136600461228b565b61072f565b60405161020091905f60a08201905065ffffffffffff835116825265ffffffffffff602084015116602083015265ffffffffffff6040840151166040830152606083015160608301526080830151608083015292915050565b34801561032a575f5ffd5b506103336107dc565b6040519015158152602001610200565b34801561034e575f5ffd5b5061036e61035d36600461228b565b60fb6020525f908152604090205481565b604051908152602001610200565b348015610387575f5ffd5b506101ec7f000000000000000000000000000000000000000000000000000000000000000081565b3480156103ba575f5ffd5b506103ce6103c93660046122bd565b6107f4565b005b3480156103db575f5ffd5b506103ce6103ea3660046122d6565b6108c4565b3480156103fa575f5ffd5b506103ce610a58565b6103ce6104113660046123f4565b610ab3565b348015610421575f5ffd5b5061036e610b68565b348015610435575f5ffd5b5061033360c954610100900460ff1660021490565b348015610455575f5ffd5b506103ce610c19565b348015610469575f5ffd5b506103ce610c2a565b34801561047d575f5ffd5b506103ce610ca1565b348015610491575f5ffd5b506101ec610cf6565b3480156104a5575f5ffd5b506033546001600160a01b03166101ec565b3480156104c2575f5ffd5b506101ec7f000000000000000000000000000000000000000000000000000000000000000081565b3480156104f5575f5ffd5b506101ec71777735367b36bc9b61c50022d9d0700db4ec81565b34801561051a575f5ffd5b5061052e610529366004612490565b610d04565b604080516001600160a01b039093168352602083019190915201610200565b348015610558575f5ffd5b506105ce604080516080810182525f808252602082018190529181018290526060810191909152506040805160808101825260ff80548252610100546001600160a01b0381166020840152600160a01b8104909116151592820192909252600160a81b90910465ffffffffffff16606082015290565b6040516102009190815181526020808301516001600160a01b03169082015260408083015115159082015260609182015165ffffffffffff169181019190915260800190565b34801561061f575f5ffd5b5061063361062e3660046124ec565b610de4565b6040805193151584526001600160a01b03909216602084015290820152606001610200565b348015610663575f5ffd5b5061028f620f424081565b348015610679575f5ffd5b5061036e7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106ac575f5ffd5b5061036e7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106df575f5ffd5b506065546001600160a01b03166101ec565b3480156106fc575f5ffd5b506103ce61070b3660046122bd565b610f87565b34801561071b575f5ffd5b506103ce61072a36600461255c565b610ff8565b6040805160a0810182525f808252602082018190529181018290526060810182905260808101919091525f82815261010360209081526040808320815160a081018352815465ffffffffffff80821680845266010000000000008304821696840196909652600160601b90910416928101929092526001810154606083015260020154608082015291036107d657604051631391e11b60e21b815260040160405180910390fd5b92915050565b5f60026107eb60c95460ff1690565b60ff1614905090565b6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001630036108455760405162461bcd60e51b815260040161083c9061258d565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610877611134565b6001600160a01b03161461089d5760405162461bcd60e51b815260040161083c906125d9565b6108a68161114f565b604080515f808252602082019092526108c191839190611157565b50565b3371777735367b36bc9b61c50022d9d0700db4ec146108f657604051636edaef2f60e11b815260040160405180910390fd5b6108fe6112c6565b61090860026112f5565b61010054600160a81b900465ffffffffffff168061092c6040850160208601612625565b65ffffffffffff1610156109535760405163229329c760e01b815260040160405180910390fd5b65ffffffffffff811661096c6040850160208601612625565b65ffffffffffff161115610983576109838361130b565b6101015465ffffffffffff1661099883611516565b6109a2848461167a565b5f6109ae60014361263e565b5f81815260fb60209081526040918290208340905560ff805461010054610101546101025486519384526001600160a01b03831695840195909552600160a01b90910490921615159381019390935265ffffffffffff808716606085015216608083015260a08201529091507fe80d555eb6906f6907b68e6ead37d1089d1fbb7e23a68f3335dd04f8aef3e1e79060c00160405180910390a1505050610a5460016112f5565b5050565b610a6061177f565b610a7460c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610ab1335f6117b0565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610afb5760405162461bcd60e51b815260040161083c9061258d565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610b2d611134565b6001600160a01b031614610b535760405162461bcd60e51b815260040161083c906125d9565b610b5c8261114f565b610a5482826001611157565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610c075760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c0000000000000000606482015260840161083c565b505f5160206129355f395f51905f5290565b610c216117b4565b610ab15f61180e565b60655433906001600160a01b03168114610c985760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b606482015260840161083c565b6108c18161180e565b610ca9611827565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610ab13360016117b0565b5f610cff611134565b905090565b5f8060e1831015610d1957508390505f610ddb565b5f610d268486018661265d565b9050610d33818888611859565b610d4357855f9250925050610ddb565b604181606001515114610d5c57855f9250925050610ddb565b5f5f610d74610d6a84611899565b84606001516118d6565b90925090505f816004811115610d8c57610d8c6126f3565b141580610da057506001600160a01b038216155b15610db357875f94509450505050610ddb565b819450876001600160a01b0316856001600160a01b031614610dd757826040015193505b5050505b94509492505050565b5f5f5f5f5f610df58a8a8a8a610d04565b60405163508b724360e11b81526001600160a01b038c81166004830152602482018390529294509092505f917f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610e68573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610e8c9190612707565b905080610ea5576001875f955095509550505050610f7c565b896001600160a01b0316836001600160a01b031603610ecf575f8a5f955095509550505050610f7c565b60405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610f39573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f5d9190612707565b610f72575f8a5f955095509550505050610f7c565b505f945090925090505b955095509592505050565b610f8f6117b4565b606580546001600160a01b0383166001600160a01b03199091168117909155610fc06033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b6110006117b4565b6110086112c6565b61101260026112f5565b6001600160a01b0381166110395760405163e6c4247b60e01b815260040160405180910390fd5b5f6001600160a01b03831661106257504761105d6001600160a01b03831682611918565b6110de565b6040516370a0823160e01b81523060048201526001600160a01b038416906370a0823190602401602060405180830381865afa1580156110a4573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906110c89190612726565b90506110de6001600160a01b0384168383611923565b604080516001600160a01b038086168252841660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a150610a5460016112f5565b5f5160206129355f395f51905f52546001600160a01b031690565b6108c16117b4565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff161561118f5761118a83611975565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa9250505080156111e9575060408051601f3d908101601f191682019092526111e691810190612726565b60015b61124c5760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b606482015260840161083c565b5f5160206129355f395f51905f5281146112ba5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b606482015260840161083c565b5061118a838383611a10565b60026112d460c95460ff1690565b60ff1603610ab15760405163dfc60d8560e01b815260040160405180910390fd5b60c9805460ff191660ff92909216919091179055565b5f61134e61131f6040840160208501612625565b61132f60608501604086016122bd565b61133c606086018661273d565b610100546001600160a01b0316610de4565b6101008054931515600160a01b026001600160a81b03199094166001600160a01b0390931692909217929092179055905080156114b7576001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de6113c460608501604086016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044016020604051808303815f875af115801561140e573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906114329190612726565b5061010054604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b1580156114a0575f5ffd5b505af11580156114b2573d5f5f3e3d5ffd5b505050505b60ff546114d5906114cb60a085018561277f565b8560800135611a3a565b60ff556114e86040830160208401612625565b610100805465ffffffffffff92909216600160a81b0265ffffffffffff60a81b199092169190911790555050565b5f5f611520611c22565b6101025491935091501561155157610102548214611551576040516349645ffd60e01b815260040160405180910390fd5b6101028190556101015465ffffffffffff166115706020850185612625565b65ffffffffffff16111561118a5760408051606081019091526001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169063c9a0b8c890806115c86020880188612625565b65ffffffffffff9081168252602088810135818401526040808a01359381019390935282516001600160e01b031960e087901b16815284519092166004830152830151602482015291015160448201526064015f604051808303815f87803b158015611632575f5ffd5b505af1158015611644573d5f5f3e3d5ffd5b50611656925050506020840184612625565b610101805465ffffffffffff191665ffffffffffff92909216919091179055505050565b5f6101038161168a60014361263e565b81526020019081526020015f2090506040518060a00160405280835f0160208101906116b69190612625565b65ffffffffffff1681526020908101906116d290860186612625565b65ffffffffffff90811682528354660100000000000090819004821660208085019190915260609687013560408086019190915260019687015494880194909452435f90815261010382528490208551815492870151958701518516600160601b0265ffffffffffff60601b199686169094026bffffffffffffffffffffffff19909316941693909317179290921691909117815592810151918301919091556080015160029091015550565b61179360c954610100900460ff1660021490565b610ab15760405163bae6e2a960e01b815260040160405180910390fd5b610a545b6033546001600160a01b03163314610ab15760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161083c565b606580546001600160a01b03191690556108c181611cbf565b61183b60c954610100900460ff1660021490565b15610ab15760405163bae6e2a960e01b815260040160405180910390fd5b5f8265ffffffffffff16845f015165ffffffffffff161480156118915750816001600160a01b031684602001516001600160a01b0316145b949350505050565b8051602080830151604080850151815165ffffffffffff90951685526001600160a01b039092169284019290925290820152606090205f906107d6565b5f5f825160410361190a576020830151604084015160608501515f1a6118fe87828585611d10565b94509450505050611911565b505f905060025b9250929050565b610a5482825a611dca565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b17905261118a908490611e0d565b6001600160a01b0381163b6119e25760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b606482015260840161083c565b5f5160206129355f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b611a1983611ee0565b5f82511180611a255750805b1561118a57611a348383611f1f565b50505050565b83825f5b81811015611bf85736868683818110611a5957611a596127c4565b90506080020190505f611a7d826020016020810190611a7891906127e6565b611f4b565b90508015611bd1575f6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de611ac560608601604087016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018590526044016020604051808303815f875af1158015611b0f573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611b339190612726565b90506001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663be32d1f4611b7460808601606087016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044015f604051808303815f87803b158015611bb9575f5ffd5b505af1158015611bcb573d5f5f3e3d5ffd5b50505050505b611be985611be4368590038501856127ff565b611fd3565b94505050806001019050611a3e565b50828214611c19576040516388c4700b60e01b815260040160405180910390fd5b50949350505050565b5f8080611c3060014361263e565b9050611c3a61226b565b46611fe08201525f5b60ff81108015611c565750806001018310155b15611c87575f198184030180408360ff83066101008110611c7957611c796127c4565b602002015250600101611c43565b5061200081209350814081611c9d60ff8561285e565b6101008110611cae57611cae6127c4565b602002015261200090209293915050565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115611d4557505f90506003610ddb565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015611d96573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116611dbe575f60019250925050610ddb565b965f9650945050505050565b815f03611dd657505050565b611df083838360405180602001604052805f815250612038565b61118a57604051634c67134d60e11b815260040160405180910390fd5b5f611e61826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166120759092919063ffffffff16565b905080515f1480611e81575080806020019051810190611e819190612707565b61118a5760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b606482015260840161083c565b611ee981611975565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060611f44838360405180606001604052806027815260200161295560279139612083565b9392505050565b5f6002826002811115611f6057611f606126f3565b03611f8c57507f0000000000000000000000000000000000000000000000000000000000000000919050565b6001826002811115611fa057611fa06126f3565b03611fcc57507f0000000000000000000000000000000000000000000000000000000000000000919050565b505f919050565b80515f9065ffffffffffff161580611fff57505f82602001516002811115611ffd57611ffd6126f3565b145b61203157828260405160200161201692919061287d565b60405160208183030381529060405280519060200120611f44565b5090919050565b5f6001600160a01b03851661206057604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b606061189184845f856120f7565b60605f5f856001600160a01b03168560405161209f91906128e9565b5f60405180830381855af49150503d805f81146120d7576040519150601f19603f3d011682016040523d82523d5f602084013e6120dc565b606091505b50915091506120ed868383876121ce565b9695505050505050565b6060824710156121585760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b606482015260840161083c565b5f5f866001600160a01b0316858760405161217391906128e9565b5f6040518083038185875af1925050503d805f81146121ad576040519150601f19603f3d011682016040523d82523d5f602084013e6121b2565b606091505b50915091506121c3878383876121ce565b979650505050505050565b6060831561223c5782515f03612235576001600160a01b0385163b6122355760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000604482015260640161083c565b5081611891565b61189183838151156122515781518083602001fd5b8060405162461bcd60e51b815260040161083c91906128ff565b604051806120000160405280610100906020820280368337509192915050565b5f6020828403121561229b575f5ffd5b5035919050565b80356001600160a01b03811681146122b8575f5ffd5b919050565b5f602082840312156122cd575f5ffd5b611f44826122a2565b5f5f82840360a08112156122e8575f5ffd5b83356001600160401b038111156122fd575f5ffd5b840160c0818703121561230e575f5ffd5b92506080601f1982011215612321575f5ffd5b506020830190509250929050565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156123655761236561232f565b60405290565b5f82601f83011261237a575f5ffd5b81356001600160401b038111156123935761239361232f565b604051601f8201601f19908116603f011681016001600160401b03811182821017156123c1576123c161232f565b6040528181528382016020018510156123d8575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f60408385031215612405575f5ffd5b61240e836122a2565b915060208301356001600160401b03811115612428575f5ffd5b6124348582860161236b565b9150509250929050565b803565ffffffffffff811681146122b8575f5ffd5b5f5f83601f840112612463575f5ffd5b5081356001600160401b03811115612479575f5ffd5b602083019150836020828501011115611911575f5ffd5b5f5f5f5f606085870312156124a3575f5ffd5b6124ac8561243e565b93506124ba602086016122a2565b925060408501356001600160401b038111156124d4575f5ffd5b6124e087828801612453565b95989497509550505050565b5f5f5f5f5f60808688031215612500575f5ffd5b6125098661243e565b9450612517602087016122a2565b935060408601356001600160401b03811115612531575f5ffd5b61253d88828901612453565b90945092506125509050606087016122a2565b90509295509295909350565b5f5f6040838503121561256d575f5ffd5b612576836122a2565b9150612584602084016122a2565b90509250929050565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b5f60208284031215612635575f5ffd5b611f448261243e565b818103818111156107d657634e487b7160e01b5f52601160045260245ffd5b5f6020828403121561266d575f5ffd5b81356001600160401b03811115612682575f5ffd5b820160808185031215612693575f5ffd5b61269b612343565b6126a48261243e565b81526126b2602083016122a2565b60208201526040828101359082015260608201356001600160401b038111156126d9575f5ffd5b6126e58682850161236b565b606083015250949350505050565b634e487b7160e01b5f52602160045260245ffd5b5f60208284031215612717575f5ffd5b81518015158114611f44575f5ffd5b5f60208284031215612736575f5ffd5b5051919050565b5f5f8335601e19843603018112612752575f5ffd5b8301803591506001600160401b0382111561276b575f5ffd5b602001915036819003821315611911575f5ffd5b5f5f8335601e19843603018112612794575f5ffd5b8301803591506001600160401b038211156127ad575f5ffd5b6020019150600781901b3603821315611911575f5ffd5b634e487b7160e01b5f52603260045260245ffd5b8035600381106122b8575f5ffd5b5f602082840312156127f6575f5ffd5b611f44826127d8565b5f6080828403128015612810575f5ffd5b50612819612343565b6128228361243e565b8152612830602084016127d8565b6020820152612841604084016122a2565b6040820152612852606084016122a2565b60608201529392505050565b5f8261287857634e487b7160e01b5f52601260045260245ffd5b500690565b5f60a08201905083825265ffffffffffff83511660208301526020830151600381106128b757634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212201b1c3cb3092f1000512444eef265ab5d969a83bd5e43383ffc096c6c6383ad5664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01``@R0`\x80R4\x80\x15a\0\x14W__\xFD[P`@Qa-x8\x03\x80a-x\x839\x81\x01`@\x81\x90Ra\x003\x91a\x02\xA0V[a\0;a\x01cV[`\x01`\x01`\xA0\x1B\x03\x86\x16a\0bW`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x85\x16a\0\x89W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x81\x16a\0\xB0W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`@\x1B\x03\x82\x16\x15\x80\x15\x90a\0\xD1WPF\x82`\x01`\x01`@\x1B\x03\x16\x14\x15[a\0\xEEW`@Qc\xCA@f{`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01F\x11\x80\x15a\x01\x05WP`\x01`\x01`@\x1B\x03F\x11\x15[a\x01\"W`@Qc\x14-\x89u`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x80\x87\x16`\xE0R\x85\x16`\xC0Ra\x01\0\x84\x90Ra\x01 \x83\x90R`\x01`\x01`@\x1B\x03\x82\x16a\x01@Ra\x01X\x81a\x02\x1FV[PPPPPPa\x03\x1BV[_Ta\x01\0\x90\x04`\xFF\x16\x15a\x01\xCEW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FInitializable: contract is initi`D\x82\x01Rfalizing`\xC8\x1B`d\x82\x01R`\x84\x01`@Q\x80\x91\x03\x90\xFD[_T`\xFF\x90\x81\x16\x14a\x02\x1DW_\x80T`\xFF\x19\x16`\xFF\x90\x81\x17\x90\x91U`@Q\x90\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x028\x81a\x02;V[PV[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x028W__\xFD[______`\xC0\x87\x89\x03\x12\x15a\x02\xB5W__\xFD[\x86Qa\x02\xC0\x81a\x02\x8CV[` \x88\x01Q\x90\x96Pa\x02\xD1\x81a\x02\x8CV[`@\x88\x01Q``\x89\x01Q`\x80\x8A\x01Q\x92\x97P\x90\x95P\x93P`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x02\xFCW__\xFD[`\xA0\x88\x01Q\x90\x92Pa\x03\r\x81a\x02\x8CV[\x80\x91PP\x92\x95P\x92\x95P\x92\x95V[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x01 Qa\x01@Qa)\xB1a\x03\xC7_9_a\x02m\x01R_\x81\x81a\x06\x7F\x01Ra\x1F\xA8\x01R_\x81\x81a\x06\xB2\x01Ra\x1Fh\x01R_\x81\x81a\x04\xC8\x01Ra\x15\x93\x01R_\x81\x81a\x03\x8D\x01R\x81\x81a\x0E#\x01R\x81\x81a\x0E\xF4\x01R\x81\x81a\x13\x8F\x01R\x81\x81a\x14]\x01R\x81\x81a\x1A\x90\x01Ra\x1B?\x01R_a\x01\xCC\x01R_\x81\x81a\x07\xFE\x01R\x81\x81a\x08G\x01R\x81\x81a\n\xBD\x01R\x81\x81a\n\xFD\x01Ra\x0Bt\x01Ra)\xB1_\xF3\xFE`\x80`@R`\x046\x10a\x01\xBAW_5`\xE0\x1C\x80cy\xBAP\x97\x11a\0\xF2W\x80c\xAA\xDE7[\x11a\0\x92W\x80c\xD4AB!\x11a\0bW\x80c\xD4AB!\x14a\x06\xA1W\x80c\xE3\x0C9x\x14a\x06\xD4W\x80c\xF2\xFD\xE3\x8B\x14a\x06\xF1W\x80c\xF9@\xE3\x85\x14a\x07\x10W__\xFD[\x80c\xAA\xDE7[\x14a\x05MW\x80c\xB3\xD5\xE4_\x14a\x06\x14W\x80c\xC4n:f\x14a\x06XW\x80c\xCF\x1A\x0F\"\x14a\x06nW__\xFD[\x80c\x8D\xA5\xCB[\x11a\0\xCDW\x80c\x8D\xA5\xCB[\x14a\x04\x9AW\x80c\x95ZrD\x14a\x04\xB7W\x80c\x9E\xE5\x12\xF2\x14a\x04\xEAW\x80c\xA3~\xA5\x15\x14a\x05\x0FW__\xFD[\x80cy\xBAP\x97\x14a\x04^W\x80c\x84V\xCBY\x14a\x04rW\x80c\x8A\xBF`w\x14a\x04\x86W__\xFD[\x80c6Y\xCF\xE6\x11a\x01]W\x80cO\x1E\xF2\x86\x11a\x018W\x80cO\x1E\xF2\x86\x14a\x04\x03W\x80cR\xD1\x90-\x14a\x04\x16W\x80c\\\x97Z\xBB\x14a\x04*W\x80cqP\x18\xA6\x14a\x04JW__\xFD[\x80c6Y\xCF\xE6\x14a\x03\xAFW\x80c<z\xA9\x11\x14a\x03\xD0W\x80c?K\xA8:\x14a\x03\xEFW__\xFD[\x80c&\x0CSD\x11a\x01\x98W\x80c&\x0CSD\x14a\x02\xA7W\x80c0u\xDBV\x14a\x03\x1FW\x80c4\xCD\xF7\x8D\x14a\x03CW\x80c6<\xC4'\x14a\x03|W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x01\xBEW\x80c\x0FC\x9B\xD9\x14a\x02\tW\x80c\x12b.[\x14a\x02\\W[__\xFD[4\x80\x15a\x01\xC9W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02\x14W__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Ra\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80\x82Ra\x01\x02T\x91\x83\x01\x91\x82R\x83Q\x90\x81R\x90Q\x91\x81\x01\x91\x90\x91R\x01a\x02\0V[4\x80\x15a\x02gW__\xFD[Pa\x02\x8F\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x02\0V[4\x80\x15a\x02\xB2W__\xFD[Pa\x02\xC6a\x02\xC16`\x04a\"\x8BV[a\x07/V[`@Qa\x02\0\x91\x90_`\xA0\x82\x01\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x84\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x84\x01Q\x16`@\x83\x01R``\x83\x01Q``\x83\x01R`\x80\x83\x01Q`\x80\x83\x01R\x92\x91PPV[4\x80\x15a\x03*W__\xFD[Pa\x033a\x07\xDCV[`@Q\x90\x15\x15\x81R` \x01a\x02\0V[4\x80\x15a\x03NW__\xFD[Pa\x03na\x03]6`\x04a\"\x8BV[`\xFB` R_\x90\x81R`@\x90 T\x81V[`@Q\x90\x81R` \x01a\x02\0V[4\x80\x15a\x03\x87W__\xFD[Pa\x01\xEC\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x03\xBAW__\xFD[Pa\x03\xCEa\x03\xC96`\x04a\"\xBDV[a\x07\xF4V[\0[4\x80\x15a\x03\xDBW__\xFD[Pa\x03\xCEa\x03\xEA6`\x04a\"\xD6V[a\x08\xC4V[4\x80\x15a\x03\xFAW__\xFD[Pa\x03\xCEa\nXV[a\x03\xCEa\x04\x116`\x04a#\xF4V[a\n\xB3V[4\x80\x15a\x04!W__\xFD[Pa\x03na\x0BhV[4\x80\x15a\x045W__\xFD[Pa\x033`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04UW__\xFD[Pa\x03\xCEa\x0C\x19V[4\x80\x15a\x04iW__\xFD[Pa\x03\xCEa\x0C*V[4\x80\x15a\x04}W__\xFD[Pa\x03\xCEa\x0C\xA1V[4\x80\x15a\x04\x91W__\xFD[Pa\x01\xECa\x0C\xF6V[4\x80\x15a\x04\xA5W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xECV[4\x80\x15a\x04\xC2W__\xFD[Pa\x01\xEC\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\xF5W__\xFD[Pa\x01\xECqww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[4\x80\x15a\x05\x1AW__\xFD[Pa\x05.a\x05)6`\x04a$\x90V[a\r\x04V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x83R` \x83\x01\x91\x90\x91R\x01a\x02\0V[4\x80\x15a\x05XW__\xFD[Pa\x05\xCE`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91RP`@\x80Q`\x80\x81\x01\x82R`\xFF\x80T\x82Ra\x01\0T`\x01`\x01`\xA0\x1B\x03\x81\x16` \x84\x01R`\x01`\xA0\x1B\x81\x04\x90\x91\x16\x15\x15\x92\x82\x01\x92\x90\x92R`\x01`\xA8\x1B\x90\x91\x04e\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R\x90V[`@Qa\x02\0\x91\x90\x81Q\x81R` \x80\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x82\x01R`@\x80\x83\x01Q\x15\x15\x90\x82\x01R``\x91\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x91\x81\x01\x91\x90\x91R`\x80\x01\x90V[4\x80\x15a\x06\x1FW__\xFD[Pa\x063a\x06.6`\x04a$\xECV[a\r\xE4V[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x02\0V[4\x80\x15a\x06cW__\xFD[Pa\x02\x8Fb\x0FB@\x81V[4\x80\x15a\x06yW__\xFD[Pa\x03n\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xACW__\xFD[Pa\x03n\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xDFW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x01\xECV[4\x80\x15a\x06\xFCW__\xFD[Pa\x03\xCEa\x07\x0B6`\x04a\"\xBDV[a\x0F\x87V[4\x80\x15a\x07\x1BW__\xFD[Pa\x03\xCEa\x07*6`\x04a%\\V[a\x0F\xF8V[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R_\x82\x81Ra\x01\x03` \x90\x81R`@\x80\x83 \x81Q`\xA0\x81\x01\x83R\x81Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x84Rf\x01\0\0\0\0\0\0\x83\x04\x82\x16\x96\x84\x01\x96\x90\x96R`\x01``\x1B\x90\x91\x04\x16\x92\x81\x01\x92\x90\x92R`\x01\x81\x01T``\x83\x01R`\x02\x01T`\x80\x82\x01R\x91\x03a\x07\xD6W`@Qc\x13\x91\xE1\x1B`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x92\x91PPV[_`\x02a\x07\xEB`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x08EW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\x8DV[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x08wa\x114V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x08\x9DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\xD9V[a\x08\xA6\x81a\x11OV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x08\xC1\x91\x83\x91\x90a\x11WV[PV[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x08\xF6W`@Qcn\xDA\xEF/`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x08\xFEa\x12\xC6V[a\t\x08`\x02a\x12\xF5V[a\x01\0T`\x01`\xA8\x1B\x90\x04e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80a\t,`@\x85\x01` \x86\x01a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x15a\tSW`@Qc\"\x93)\xC7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16a\tl`@\x85\x01` \x86\x01a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\t\x83Wa\t\x83\x83a\x13\x0BV[a\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16a\t\x98\x83a\x15\x16V[a\t\xA2\x84\x84a\x16zV[_a\t\xAE`\x01Ca&>V[_\x81\x81R`\xFB` \x90\x81R`@\x91\x82\x90 \x83@\x90U`\xFF\x80Ta\x01\0Ta\x01\x01Ta\x01\x02T\x86Q\x93\x84R`\x01`\x01`\xA0\x1B\x03\x83\x16\x95\x84\x01\x95\x90\x95R`\x01`\xA0\x1B\x90\x91\x04\x90\x92\x16\x15\x15\x93\x81\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x80\x87\x16``\x85\x01R\x16`\x80\x83\x01R`\xA0\x82\x01R\x90\x91P\x7F\xE8\rU^\xB6\x90oi\x07\xB6\x8En\xAD7\xD1\x08\x9D\x1F\xBB~#\xA6\x8F35\xDD\x04\xF8\xAE\xF3\xE1\xE7\x90`\xC0\x01`@Q\x80\x91\x03\x90\xA1PPPa\nT`\x01a\x12\xF5V[PPV[a\n`a\x17\x7FV[a\nt`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xB13_a\x17\xB0V[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\xFBW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\x8DV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0B-a\x114V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0BSW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\xD9V[a\x0B\\\x82a\x11OV[a\nT\x82\x82`\x01a\x11WV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0C\x07W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x08<V[P_Q` a)5_9_Q\x90_R\x90V[a\x0C!a\x17\xB4V[a\n\xB1_a\x18\x0EV[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0C\x98W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\x08<V[a\x08\xC1\x81a\x18\x0EV[a\x0C\xA9a\x18'V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xB13`\x01a\x17\xB0V[_a\x0C\xFFa\x114V[\x90P\x90V[_\x80`\xE1\x83\x10\x15a\r\x19WP\x83\x90P_a\r\xDBV[_a\r&\x84\x86\x01\x86a&]V[\x90Pa\r3\x81\x88\x88a\x18YV[a\rCW\x85_\x92P\x92PPa\r\xDBV[`A\x81``\x01QQ\x14a\r\\W\x85_\x92P\x92PPa\r\xDBV[__a\rta\rj\x84a\x18\x99V[\x84``\x01Qa\x18\xD6V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a\r\x8CWa\r\x8Ca&\xF3V[\x14\x15\x80a\r\xA0WP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15[\x15a\r\xB3W\x87_\x94P\x94PPPPa\r\xDBV[\x81\x94P\x87`\x01`\x01`\xA0\x1B\x03\x16\x85`\x01`\x01`\xA0\x1B\x03\x16\x14a\r\xD7W\x82`@\x01Q\x93P[PPP[\x94P\x94\x92PPPV[_____a\r\xF5\x8A\x8A\x8A\x8Aa\r\x04V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8C\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x92\x94P\x90\x92P_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0EhW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0E\x8C\x91\x90a'\x07V[\x90P\x80a\x0E\xA5W`\x01\x87_\x95P\x95P\x95PPPPa\x0F|V[\x89`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x03a\x0E\xCFW_\x8A_\x95P\x95P\x95PPPPa\x0F|V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0F9W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0F]\x91\x90a'\x07V[a\x0FrW_\x8A_\x95P\x95P\x95PPPPa\x0F|V[P_\x94P\x90\x92P\x90P[\x95P\x95P\x95\x92PPPV[a\x0F\x8Fa\x17\xB4V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x0F\xC0`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\x10\0a\x17\xB4V[a\x10\x08a\x12\xC6V[a\x10\x12`\x02a\x12\xF5V[`\x01`\x01`\xA0\x1B\x03\x81\x16a\x109W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\x10bWPGa\x10]`\x01`\x01`\xA0\x1B\x03\x83\x16\x82a\x19\x18V[a\x10\xDEV[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x84\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x10\xA4W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x10\xC8\x91\x90a'&V[\x90Pa\x10\xDE`\x01`\x01`\xA0\x1B\x03\x84\x16\x83\x83a\x19#V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x86\x16\x82R\x84\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\nT`\x01a\x12\xF5V[_Q` a)5_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x08\xC1a\x17\xB4V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x11\x8FWa\x11\x8A\x83a\x19uV[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x11\xE9WP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x11\xE6\x91\x81\x01\x90a'&V[`\x01[a\x12LW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\x08<V[_Q` a)5_9_Q\x90_R\x81\x14a\x12\xBAW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\x08<V[Pa\x11\x8A\x83\x83\x83a\x1A\x10V[`\x02a\x12\xD4`\xC9T`\xFF\x16\x90V[`\xFF\x16\x03a\n\xB1W`@Qc\xDF\xC6\r\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xC9\x80T`\xFF\x19\x16`\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[_a\x13Na\x13\x1F`@\x84\x01` \x85\x01a&%V[a\x13/``\x85\x01`@\x86\x01a\"\xBDV[a\x13<``\x86\x01\x86a'=V[a\x01\0T`\x01`\x01`\xA0\x1B\x03\x16a\r\xE4V[a\x01\0\x80T\x93\x15\x15`\x01`\xA0\x1B\x02`\x01`\x01`\xA8\x1B\x03\x19\x90\x94\x16`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x92\x90\x92\x17\x92\x90\x92\x17\x90U\x90P\x80\x15a\x14\xB7W`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x13\xC4``\x85\x01`@\x86\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x14\x0EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x142\x91\x90a'&V[Pa\x01\0T`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x14\xA0W__\xFD[PZ\xF1\x15\x80\x15a\x14\xB2W=__>=_\xFD[PPPP[`\xFFTa\x14\xD5\x90a\x14\xCB`\xA0\x85\x01\x85a'\x7FV[\x85`\x80\x015a\x1A:V[`\xFFUa\x14\xE8`@\x83\x01` \x84\x01a&%V[a\x01\0\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16`\x01`\xA8\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF`\xA8\x1B\x19\x90\x92\x16\x91\x90\x91\x17\x90UPPV[__a\x15 a\x1C\"V[a\x01\x02T\x91\x93P\x91P\x15a\x15QWa\x01\x02T\x82\x14a\x15QW`@QcId_\xFD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x01\x02\x81\x90Ua\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x15p` \x85\x01\x85a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\x11\x8AW`@\x80Q``\x81\x01\x90\x91R`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xC9\xA0\xB8\xC8\x90\x80a\x15\xC8` \x88\x01\x88a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x88\x81\x015\x81\x84\x01R`@\x80\x8A\x015\x93\x81\x01\x93\x90\x93R\x82Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x87\x90\x1B\x16\x81R\x84Q\x90\x92\x16`\x04\x83\x01R\x83\x01Q`$\x82\x01R\x91\x01Q`D\x82\x01R`d\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x162W__\xFD[PZ\xF1\x15\x80\x15a\x16DW=__>=_\xFD[Pa\x16V\x92PPP` \x84\x01\x84a&%V[a\x01\x01\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UPPPV[_a\x01\x03\x81a\x16\x8A`\x01Ca&>V[\x81R` \x01\x90\x81R` \x01_ \x90P`@Q\x80`\xA0\x01`@R\x80\x83_\x01` \x81\x01\x90a\x16\xB6\x91\x90a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x90\x81\x01\x90a\x16\xD2\x90\x86\x01\x86a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R\x83Tf\x01\0\0\0\0\0\0\x90\x81\x90\x04\x82\x16` \x80\x85\x01\x91\x90\x91R``\x96\x87\x015`@\x80\x86\x01\x91\x90\x91R`\x01\x96\x87\x01T\x94\x88\x01\x94\x90\x94RC_\x90\x81Ra\x01\x03\x82R\x84\x90 \x85Q\x81T\x92\x87\x01Q\x95\x87\x01Q\x85\x16`\x01``\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF``\x1B\x19\x96\x86\x16\x90\x94\x02k\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x93\x16\x94\x16\x93\x90\x93\x17\x17\x92\x90\x92\x16\x91\x90\x91\x17\x81U\x92\x81\x01Q\x91\x83\x01\x91\x90\x91U`\x80\x01Q`\x02\x90\x91\x01UPV[a\x17\x93`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\n\xB1W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\nT[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\n\xB1W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x08<V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x08\xC1\x81a\x1C\xBFV[a\x18;`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\n\xB1W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x80\x15a\x18\x91WP\x81`\x01`\x01`\xA0\x1B\x03\x16\x84` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14[\x94\x93PPPPV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16\x92\x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 _\x90a\x07\xD6V[__\x82Q`A\x03a\x19\nW` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa\x18\xFE\x87\x82\x85\x85a\x1D\x10V[\x94P\x94PPPPa\x19\x11V[P_\x90P`\x02[\x92P\x92\x90PV[a\nT\x82\x82Za\x1D\xCAV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\x11\x8A\x90\x84\x90a\x1E\rV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\x19\xE2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\x08<V[_Q` a)5_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a\x1A\x19\x83a\x1E\xE0V[_\x82Q\x11\x80a\x1A%WP\x80[\x15a\x11\x8AWa\x1A4\x83\x83a\x1F\x1FV[PPPPV[\x83\x82_[\x81\x81\x10\x15a\x1B\xF8W6\x86\x86\x83\x81\x81\x10a\x1AYWa\x1AYa'\xC4V[\x90P`\x80\x02\x01\x90P_a\x1A}\x82` \x01` \x81\x01\x90a\x1Ax\x91\x90a'\xE6V[a\x1FKV[\x90P\x80\x15a\x1B\xD1W_`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x1A\xC5``\x86\x01`@\x87\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x85\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x1B\x0FW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1B3\x91\x90a'&V[\x90P`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c\xBE2\xD1\xF4a\x1Bt`\x80\x86\x01``\x87\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x1B\xB9W__\xFD[PZ\xF1\x15\x80\x15a\x1B\xCBW=__>=_\xFD[PPPPP[a\x1B\xE9\x85a\x1B\xE46\x85\x90\x03\x85\x01\x85a'\xFFV[a\x1F\xD3V[\x94PPP\x80`\x01\x01\x90Pa\x1A>V[P\x82\x82\x14a\x1C\x19W`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94\x93PPPPV[_\x80\x80a\x1C0`\x01Ca&>V[\x90Pa\x1C:a\"kV[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\x1CVWP\x80`\x01\x01\x83\x10\x15[\x15a\x1C\x87W_\x19\x81\x84\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\x1CyWa\x1Cya'\xC4V[` \x02\x01RP`\x01\x01a\x1CCV[Pa \0\x81 \x93P\x81@\x81a\x1C\x9D`\xFF\x85a(^V[a\x01\0\x81\x10a\x1C\xAEWa\x1C\xAEa'\xC4V[` \x02\x01Ra \0\x90 \x92\x93\x91PPV[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a\x1DEWP_\x90P`\x03a\r\xDBV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a\x1D\x96W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a\x1D\xBEW_`\x01\x92P\x92PPa\r\xDBV[\x96_\x96P\x94PPPPPV[\x81_\x03a\x1D\xD6WPPPV[a\x1D\xF0\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa 8V[a\x11\x8AW`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1Ea\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a u\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a\x1E\x81WP\x80\x80` \x01\x90Q\x81\x01\x90a\x1E\x81\x91\x90a'\x07V[a\x11\x8AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\x08<V[a\x1E\xE9\x81a\x19uV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x1FD\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a)U`'\x919a \x83V[\x93\x92PPPV[_`\x02\x82`\x02\x81\x11\x15a\x1F`Wa\x1F`a&\xF3V[\x03a\x1F\x8CWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[`\x01\x82`\x02\x81\x11\x15a\x1F\xA0Wa\x1F\xA0a&\xF3V[\x03a\x1F\xCCWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[P_\x91\x90PV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1F\xFFWP_\x82` \x01Q`\x02\x81\x11\x15a\x1F\xFDWa\x1F\xFDa&\xF3V[\x14[a 1W\x82\x82`@Q` \x01a \x16\x92\x91\x90a(}V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a\x1FDV[P\x90\x91\x90PV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a `W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a\x18\x91\x84\x84_\x85a \xF7V[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa \x9F\x91\x90a(\xE9V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a \xD7W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a \xDCV[``\x91P[P\x91P\x91Pa \xED\x86\x83\x83\x87a!\xCEV[\x96\x95PPPPPPV[``\x82G\x10\x15a!XW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FAddress: insufficient balance fo`D\x82\x01Re\x1C\x88\x18\xD8[\x1B`\xD2\x1B`d\x82\x01R`\x84\x01a\x08<V[__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa!s\x91\x90a(\xE9V[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a!\xADW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a!\xB2V[``\x91P[P\x91P\x91Pa!\xC3\x87\x83\x83\x87a!\xCEV[\x97\x96PPPPPPPV[``\x83\x15a\"<W\x82Q_\x03a\"5W`\x01`\x01`\xA0\x1B\x03\x85\x16;a\"5W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x08<V[P\x81a\x18\x91V[a\x18\x91\x83\x83\x81Q\x15a\"QW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x91\x90a(\xFFV[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[_` \x82\x84\x03\x12\x15a\"\x9BW__\xFD[P5\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\"\xB8W__\xFD[\x91\x90PV[_` \x82\x84\x03\x12\x15a\"\xCDW__\xFD[a\x1FD\x82a\"\xA2V[__\x82\x84\x03`\xA0\x81\x12\x15a\"\xE8W__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\"\xFDW__\xFD[\x84\x01`\xC0\x81\x87\x03\x12\x15a#\x0EW__\xFD[\x92P`\x80`\x1F\x19\x82\x01\x12\x15a#!W__\xFD[P` \x83\x01\x90P\x92P\x92\x90PV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a#eWa#ea#/V[`@R\x90V[_\x82`\x1F\x83\x01\x12a#zW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a#\x93Wa#\x93a#/V[`@Q`\x1F\x82\x01`\x1F\x19\x90\x81\x16`?\x01\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a#\xC1Wa#\xC1a#/V[`@R\x81\x81R\x83\x82\x01` \x01\x85\x10\x15a#\xD8W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a$\x05W__\xFD[a$\x0E\x83a\"\xA2V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a$(W__\xFD[a$4\x85\x82\x86\x01a#kV[\x91PP\x92P\x92\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\"\xB8W__\xFD[__\x83`\x1F\x84\x01\x12a$cW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a$yW__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a\x19\x11W__\xFD[____``\x85\x87\x03\x12\x15a$\xA3W__\xFD[a$\xAC\x85a$>V[\x93Pa$\xBA` \x86\x01a\"\xA2V[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a$\xD4W__\xFD[a$\xE0\x87\x82\x88\x01a$SV[\x95\x98\x94\x97P\x95PPPPV[_____`\x80\x86\x88\x03\x12\x15a%\0W__\xFD[a%\t\x86a$>V[\x94Pa%\x17` \x87\x01a\"\xA2V[\x93P`@\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a%1W__\xFD[a%=\x88\x82\x89\x01a$SV[\x90\x94P\x92Pa%P\x90P``\x87\x01a\"\xA2V[\x90P\x92\x95P\x92\x95\x90\x93PV[__`@\x83\x85\x03\x12\x15a%mW__\xFD[a%v\x83a\"\xA2V[\x91Pa%\x84` \x84\x01a\"\xA2V[\x90P\x92P\x92\x90PV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a&5W__\xFD[a\x1FD\x82a$>V[\x81\x81\x03\x81\x81\x11\x15a\x07\xD6WcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a&mW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a&\x82W__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a&\x93W__\xFD[a&\x9Ba#CV[a&\xA4\x82a$>V[\x81Ra&\xB2` \x83\x01a\"\xA2V[` \x82\x01R`@\x82\x81\x015\x90\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a&\xD9W__\xFD[a&\xE5\x86\x82\x85\x01a#kV[``\x83\x01RP\x94\x93PPPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a'\x17W__\xFD[\x81Q\x80\x15\x15\x81\x14a\x1FDW__\xFD[_` \x82\x84\x03\x12\x15a'6W__\xFD[PQ\x91\x90PV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a'RW__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a'kW__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a\x19\x11W__\xFD[__\x835`\x1E\x19\x846\x03\x01\x81\x12a'\x94W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a'\xADW__\xFD[` \x01\x91P`\x07\x81\x90\x1B6\x03\x82\x13\x15a\x19\x11W__\xFD[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x805`\x03\x81\x10a\"\xB8W__\xFD[_` \x82\x84\x03\x12\x15a'\xF6W__\xFD[a\x1FD\x82a'\xD8V[_`\x80\x82\x84\x03\x12\x80\x15a(\x10W__\xFD[Pa(\x19a#CV[a(\"\x83a$>V[\x81Ra(0` \x84\x01a'\xD8V[` \x82\x01Ra(A`@\x84\x01a\"\xA2V[`@\x82\x01Ra(R``\x84\x01a\"\xA2V[``\x82\x01R\x93\x92PPPV[_\x82a(xWcNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[P\x06\x90V[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a(\xB7WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \x1B\x1C<\xB3\t/\x10\0Q$D\xEE\xF2e\xAB]\x96\x9A\x83\xBD^C8?\xFC\tllc\x83\xADVdsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x6080604052600436106101ba575f3560e01c806379ba5097116100f2578063aade375b11610092578063d441422111610062578063d4414221146106a1578063e30c3978146106d4578063f2fde38b146106f1578063f940e38514610710575f5ffd5b8063aade375b1461054d578063b3d5e45f14610614578063c46e3a6614610658578063cf1a0f221461066e575f5ffd5b80638da5cb5b116100cd5780638da5cb5b1461049a578063955a7244146104b75780639ee512f2146104ea578063a37ea5151461050f575f5ffd5b806379ba50971461045e5780638456cb59146104725780638abf607714610486575f5ffd5b80633659cfe61161015d5780634f1ef286116101385780634f1ef2861461040357806352d1902d146104165780635c975abb1461042a578063715018a61461044a575f5ffd5b80633659cfe6146103af5780633c7aa911146103d05780633f4ba83a146103ef575f5ffd5b8063260c534411610198578063260c5344146102a75780633075db561461031f57806334cdf78d14610343578063363cc4271461037c575f5ffd5b806304f3bcec146101be5780630f439bd91461020957806312622e5b1461025c575b5f5ffd5b3480156101c9575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b348015610214575f5ffd5b506040805180820182525f808252602091820152815180830183526101015465ffffffffffff1680825261010254918301918252835190815290519181019190915201610200565b348015610267575f5ffd5b5061028f7f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b039091168152602001610200565b3480156102b2575f5ffd5b506102c66102c136600461228b565b61072f565b60405161020091905f60a08201905065ffffffffffff835116825265ffffffffffff602084015116602083015265ffffffffffff6040840151166040830152606083015160608301526080830151608083015292915050565b34801561032a575f5ffd5b506103336107dc565b6040519015158152602001610200565b34801561034e575f5ffd5b5061036e61035d36600461228b565b60fb6020525f908152604090205481565b604051908152602001610200565b348015610387575f5ffd5b506101ec7f000000000000000000000000000000000000000000000000000000000000000081565b3480156103ba575f5ffd5b506103ce6103c93660046122bd565b6107f4565b005b3480156103db575f5ffd5b506103ce6103ea3660046122d6565b6108c4565b3480156103fa575f5ffd5b506103ce610a58565b6103ce6104113660046123f4565b610ab3565b348015610421575f5ffd5b5061036e610b68565b348015610435575f5ffd5b5061033360c954610100900460ff1660021490565b348015610455575f5ffd5b506103ce610c19565b348015610469575f5ffd5b506103ce610c2a565b34801561047d575f5ffd5b506103ce610ca1565b348015610491575f5ffd5b506101ec610cf6565b3480156104a5575f5ffd5b506033546001600160a01b03166101ec565b3480156104c2575f5ffd5b506101ec7f000000000000000000000000000000000000000000000000000000000000000081565b3480156104f5575f5ffd5b506101ec71777735367b36bc9b61c50022d9d0700db4ec81565b34801561051a575f5ffd5b5061052e610529366004612490565b610d04565b604080516001600160a01b039093168352602083019190915201610200565b348015610558575f5ffd5b506105ce604080516080810182525f808252602082018190529181018290526060810191909152506040805160808101825260ff80548252610100546001600160a01b0381166020840152600160a01b8104909116151592820192909252600160a81b90910465ffffffffffff16606082015290565b6040516102009190815181526020808301516001600160a01b03169082015260408083015115159082015260609182015165ffffffffffff169181019190915260800190565b34801561061f575f5ffd5b5061063361062e3660046124ec565b610de4565b6040805193151584526001600160a01b03909216602084015290820152606001610200565b348015610663575f5ffd5b5061028f620f424081565b348015610679575f5ffd5b5061036e7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106ac575f5ffd5b5061036e7f000000000000000000000000000000000000000000000000000000000000000081565b3480156106df575f5ffd5b506065546001600160a01b03166101ec565b3480156106fc575f5ffd5b506103ce61070b3660046122bd565b610f87565b34801561071b575f5ffd5b506103ce61072a36600461255c565b610ff8565b6040805160a0810182525f808252602082018190529181018290526060810182905260808101919091525f82815261010360209081526040808320815160a081018352815465ffffffffffff80821680845266010000000000008304821696840196909652600160601b90910416928101929092526001810154606083015260020154608082015291036107d657604051631391e11b60e21b815260040160405180910390fd5b92915050565b5f60026107eb60c95460ff1690565b60ff1614905090565b6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001630036108455760405162461bcd60e51b815260040161083c9061258d565b60405180910390fd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610877611134565b6001600160a01b03161461089d5760405162461bcd60e51b815260040161083c906125d9565b6108a68161114f565b604080515f808252602082019092526108c191839190611157565b50565b3371777735367b36bc9b61c50022d9d0700db4ec146108f657604051636edaef2f60e11b815260040160405180910390fd5b6108fe6112c6565b61090860026112f5565b61010054600160a81b900465ffffffffffff168061092c6040850160208601612625565b65ffffffffffff1610156109535760405163229329c760e01b815260040160405180910390fd5b65ffffffffffff811661096c6040850160208601612625565b65ffffffffffff161115610983576109838361130b565b6101015465ffffffffffff1661099883611516565b6109a2848461167a565b5f6109ae60014361263e565b5f81815260fb60209081526040918290208340905560ff805461010054610101546101025486519384526001600160a01b03831695840195909552600160a01b90910490921615159381019390935265ffffffffffff808716606085015216608083015260a08201529091507fe80d555eb6906f6907b68e6ead37d1089d1fbb7e23a68f3335dd04f8aef3e1e79060c00160405180910390a1505050610a5460016112f5565b5050565b610a6061177f565b610a7460c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a1610ab1335f6117b0565b565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000163003610afb5760405162461bcd60e51b815260040161083c9061258d565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610b2d611134565b6001600160a01b031614610b535760405162461bcd60e51b815260040161083c906125d9565b610b5c8261114f565b610a5482826001611157565b5f306001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610c075760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c0000000000000000606482015260840161083c565b505f5160206129355f395f51905f5290565b610c216117b4565b610ab15f61180e565b60655433906001600160a01b03168114610c985760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b606482015260840161083c565b6108c18161180e565b610ca9611827565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a1610ab13360016117b0565b5f610cff611134565b905090565b5f8060e1831015610d1957508390505f610ddb565b5f610d268486018661265d565b9050610d33818888611859565b610d4357855f9250925050610ddb565b604181606001515114610d5c57855f9250925050610ddb565b5f5f610d74610d6a84611899565b84606001516118d6565b90925090505f816004811115610d8c57610d8c6126f3565b141580610da057506001600160a01b038216155b15610db357875f94509450505050610ddb565b819450876001600160a01b0316856001600160a01b031614610dd757826040015193505b5050505b94509492505050565b5f5f5f5f5f610df58a8a8a8a610d04565b60405163508b724360e11b81526001600160a01b038c81166004830152602482018390529294509092505f917f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610e68573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610e8c9190612707565b905080610ea5576001875f955095509550505050610f7c565b896001600160a01b0316836001600160a01b031603610ecf575f8a5f955095509550505050610f7c565b60405163508b724360e11b81526001600160a01b0384811660048301525f60248301527f0000000000000000000000000000000000000000000000000000000000000000169063a116e48690604401602060405180830381865afa158015610f39573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f5d9190612707565b610f72575f8a5f955095509550505050610f7c565b505f945090925090505b955095509592505050565b610f8f6117b4565b606580546001600160a01b0383166001600160a01b03199091168117909155610fc06033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b6110006117b4565b6110086112c6565b61101260026112f5565b6001600160a01b0381166110395760405163e6c4247b60e01b815260040160405180910390fd5b5f6001600160a01b03831661106257504761105d6001600160a01b03831682611918565b6110de565b6040516370a0823160e01b81523060048201526001600160a01b038416906370a0823190602401602060405180830381865afa1580156110a4573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906110c89190612726565b90506110de6001600160a01b0384168383611923565b604080516001600160a01b038086168252841660208201529081018290527fd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb9060600160405180910390a150610a5460016112f5565b5f5160206129355f395f51905f52546001600160a01b031690565b6108c16117b4565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff161561118f5761118a83611975565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa9250505080156111e9575060408051601f3d908101601f191682019092526111e691810190612726565b60015b61124c5760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b606482015260840161083c565b5f5160206129355f395f51905f5281146112ba5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b606482015260840161083c565b5061118a838383611a10565b60026112d460c95460ff1690565b60ff1603610ab15760405163dfc60d8560e01b815260040160405180910390fd5b60c9805460ff191660ff92909216919091179055565b5f61134e61131f6040840160208501612625565b61132f60608501604086016122bd565b61133c606086018661273d565b610100546001600160a01b0316610de4565b6101008054931515600160a01b026001600160a81b03199094166001600160a01b0390931692909217929092179055905080156114b7576001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de6113c460608501604086016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044016020604051808303815f875af115801561140e573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906114329190612726565b5061010054604051632f8cb47d60e21b81526001600160a01b039182166004820152602481018390527f00000000000000000000000000000000000000000000000000000000000000009091169063be32d1f4906044015f604051808303815f87803b1580156114a0575f5ffd5b505af11580156114b2573d5f5f3e3d5ffd5b505050505b60ff546114d5906114cb60a085018561277f565b8560800135611a3a565b60ff556114e86040830160208401612625565b610100805465ffffffffffff92909216600160a81b0265ffffffffffff60a81b199092169190911790555050565b5f5f611520611c22565b6101025491935091501561155157610102548214611551576040516349645ffd60e01b815260040160405180910390fd5b6101028190556101015465ffffffffffff166115706020850185612625565b65ffffffffffff16111561118a5760408051606081019091526001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169063c9a0b8c890806115c86020880188612625565b65ffffffffffff9081168252602088810135818401526040808a01359381019390935282516001600160e01b031960e087901b16815284519092166004830152830151602482015291015160448201526064015f604051808303815f87803b158015611632575f5ffd5b505af1158015611644573d5f5f3e3d5ffd5b50611656925050506020840184612625565b610101805465ffffffffffff191665ffffffffffff92909216919091179055505050565b5f6101038161168a60014361263e565b81526020019081526020015f2090506040518060a00160405280835f0160208101906116b69190612625565b65ffffffffffff1681526020908101906116d290860186612625565b65ffffffffffff90811682528354660100000000000090819004821660208085019190915260609687013560408086019190915260019687015494880194909452435f90815261010382528490208551815492870151958701518516600160601b0265ffffffffffff60601b199686169094026bffffffffffffffffffffffff19909316941693909317179290921691909117815592810151918301919091556080015160029091015550565b61179360c954610100900460ff1660021490565b610ab15760405163bae6e2a960e01b815260040160405180910390fd5b610a545b6033546001600160a01b03163314610ab15760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161083c565b606580546001600160a01b03191690556108c181611cbf565b61183b60c954610100900460ff1660021490565b15610ab15760405163bae6e2a960e01b815260040160405180910390fd5b5f8265ffffffffffff16845f015165ffffffffffff161480156118915750816001600160a01b031684602001516001600160a01b0316145b949350505050565b8051602080830151604080850151815165ffffffffffff90951685526001600160a01b039092169284019290925290820152606090205f906107d6565b5f5f825160410361190a576020830151604084015160608501515f1a6118fe87828585611d10565b94509450505050611911565b505f905060025b9250929050565b610a5482825a611dca565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b17905261118a908490611e0d565b6001600160a01b0381163b6119e25760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b606482015260840161083c565b5f5160206129355f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b611a1983611ee0565b5f82511180611a255750805b1561118a57611a348383611f1f565b50505050565b83825f5b81811015611bf85736868683818110611a5957611a596127c4565b90506080020190505f611a7d826020016020810190611a7891906127e6565b611f4b565b90508015611bd1575f6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663391396de611ac560608601604087016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018590526044016020604051808303815f875af1158015611b0f573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611b339190612726565b90506001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001663be32d1f4611b7460808601606087016122bd565b6040516001600160e01b031960e084901b1681526001600160a01b039091166004820152602481018490526044015f604051808303815f87803b158015611bb9575f5ffd5b505af1158015611bcb573d5f5f3e3d5ffd5b50505050505b611be985611be4368590038501856127ff565b611fd3565b94505050806001019050611a3e565b50828214611c19576040516388c4700b60e01b815260040160405180910390fd5b50949350505050565b5f8080611c3060014361263e565b9050611c3a61226b565b46611fe08201525f5b60ff81108015611c565750806001018310155b15611c87575f198184030180408360ff83066101008110611c7957611c796127c4565b602002015250600101611c43565b5061200081209350814081611c9d60ff8561285e565b6101008110611cae57611cae6127c4565b602002015261200090209293915050565b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115611d4557505f90506003610ddb565b604080515f8082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015611d96573d5f5f3e3d5ffd5b5050604051601f1901519150506001600160a01b038116611dbe575f60019250925050610ddb565b965f9650945050505050565b815f03611dd657505050565b611df083838360405180602001604052805f815250612038565b61118a57604051634c67134d60e11b815260040160405180910390fd5b5f611e61826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166120759092919063ffffffff16565b905080515f1480611e81575080806020019051810190611e819190612707565b61118a5760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b606482015260840161083c565b611ee981611975565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060611f44838360405180606001604052806027815260200161295560279139612083565b9392505050565b5f6002826002811115611f6057611f606126f3565b03611f8c57507f0000000000000000000000000000000000000000000000000000000000000000919050565b6001826002811115611fa057611fa06126f3565b03611fcc57507f0000000000000000000000000000000000000000000000000000000000000000919050565b505f919050565b80515f9065ffffffffffff161580611fff57505f82602001516002811115611ffd57611ffd6126f3565b145b61203157828260405160200161201692919061287d565b60405160208183030381529060405280519060200120611f44565b5090919050565b5f6001600160a01b03851661206057604051634c67134d60e11b815260040160405180910390fd5b5f5f835160208501878988f195945050505050565b606061189184845f856120f7565b60605f5f856001600160a01b03168560405161209f91906128e9565b5f60405180830381855af49150503d805f81146120d7576040519150601f19603f3d011682016040523d82523d5f602084013e6120dc565b606091505b50915091506120ed868383876121ce565b9695505050505050565b6060824710156121585760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b606482015260840161083c565b5f5f866001600160a01b0316858760405161217391906128e9565b5f6040518083038185875af1925050503d805f81146121ad576040519150601f19603f3d011682016040523d82523d5f602084013e6121b2565b606091505b50915091506121c3878383876121ce565b979650505050505050565b6060831561223c5782515f03612235576001600160a01b0385163b6122355760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000604482015260640161083c565b5081611891565b61189183838151156122515781518083602001fd5b8060405162461bcd60e51b815260040161083c91906128ff565b604051806120000160405280610100906020820280368337509192915050565b5f6020828403121561229b575f5ffd5b5035919050565b80356001600160a01b03811681146122b8575f5ffd5b919050565b5f602082840312156122cd575f5ffd5b611f44826122a2565b5f5f82840360a08112156122e8575f5ffd5b83356001600160401b038111156122fd575f5ffd5b840160c0818703121561230e575f5ffd5b92506080601f1982011215612321575f5ffd5b506020830190509250929050565b634e487b7160e01b5f52604160045260245ffd5b604051608081016001600160401b03811182821017156123655761236561232f565b60405290565b5f82601f83011261237a575f5ffd5b81356001600160401b038111156123935761239361232f565b604051601f8201601f19908116603f011681016001600160401b03811182821017156123c1576123c161232f565b6040528181528382016020018510156123d8575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f60408385031215612405575f5ffd5b61240e836122a2565b915060208301356001600160401b03811115612428575f5ffd5b6124348582860161236b565b9150509250929050565b803565ffffffffffff811681146122b8575f5ffd5b5f5f83601f840112612463575f5ffd5b5081356001600160401b03811115612479575f5ffd5b602083019150836020828501011115611911575f5ffd5b5f5f5f5f606085870312156124a3575f5ffd5b6124ac8561243e565b93506124ba602086016122a2565b925060408501356001600160401b038111156124d4575f5ffd5b6124e087828801612453565b95989497509550505050565b5f5f5f5f5f60808688031215612500575f5ffd5b6125098661243e565b9450612517602087016122a2565b935060408601356001600160401b03811115612531575f5ffd5b61253d88828901612453565b90945092506125509050606087016122a2565b90509295509295909350565b5f5f6040838503121561256d575f5ffd5b612576836122a2565b9150612584602084016122a2565b90509250929050565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b5f60208284031215612635575f5ffd5b611f448261243e565b818103818111156107d657634e487b7160e01b5f52601160045260245ffd5b5f6020828403121561266d575f5ffd5b81356001600160401b03811115612682575f5ffd5b820160808185031215612693575f5ffd5b61269b612343565b6126a48261243e565b81526126b2602083016122a2565b60208201526040828101359082015260608201356001600160401b038111156126d9575f5ffd5b6126e58682850161236b565b606083015250949350505050565b634e487b7160e01b5f52602160045260245ffd5b5f60208284031215612717575f5ffd5b81518015158114611f44575f5ffd5b5f60208284031215612736575f5ffd5b5051919050565b5f5f8335601e19843603018112612752575f5ffd5b8301803591506001600160401b0382111561276b575f5ffd5b602001915036819003821315611911575f5ffd5b5f5f8335601e19843603018112612794575f5ffd5b8301803591506001600160401b038211156127ad575f5ffd5b6020019150600781901b3603821315611911575f5ffd5b634e487b7160e01b5f52603260045260245ffd5b8035600381106122b8575f5ffd5b5f602082840312156127f6575f5ffd5b611f44826127d8565b5f6080828403128015612810575f5ffd5b50612819612343565b6128228361243e565b8152612830602084016127d8565b6020820152612841604084016122a2565b6040820152612852606084016122a2565b60608201529392505050565b5f8261287857634e487b7160e01b5f52601260045260245ffd5b500690565b5f60a08201905083825265ffffffffffff83511660208301526020830151600381106128b757634e487b7160e01b5f52602160045260245ffd5b6040838101919091528301516001600160a01b0390811660608085019190915290930151909216608090910152919050565b5f82518060208501845e5f920191825250919050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212201b1c3cb3092f1000512444eef265ab5d969a83bd5e43383ffc096c6c6383ad5664736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R`\x046\x10a\x01\xBAW_5`\xE0\x1C\x80cy\xBAP\x97\x11a\0\xF2W\x80c\xAA\xDE7[\x11a\0\x92W\x80c\xD4AB!\x11a\0bW\x80c\xD4AB!\x14a\x06\xA1W\x80c\xE3\x0C9x\x14a\x06\xD4W\x80c\xF2\xFD\xE3\x8B\x14a\x06\xF1W\x80c\xF9@\xE3\x85\x14a\x07\x10W__\xFD[\x80c\xAA\xDE7[\x14a\x05MW\x80c\xB3\xD5\xE4_\x14a\x06\x14W\x80c\xC4n:f\x14a\x06XW\x80c\xCF\x1A\x0F\"\x14a\x06nW__\xFD[\x80c\x8D\xA5\xCB[\x11a\0\xCDW\x80c\x8D\xA5\xCB[\x14a\x04\x9AW\x80c\x95ZrD\x14a\x04\xB7W\x80c\x9E\xE5\x12\xF2\x14a\x04\xEAW\x80c\xA3~\xA5\x15\x14a\x05\x0FW__\xFD[\x80cy\xBAP\x97\x14a\x04^W\x80c\x84V\xCBY\x14a\x04rW\x80c\x8A\xBF`w\x14a\x04\x86W__\xFD[\x80c6Y\xCF\xE6\x11a\x01]W\x80cO\x1E\xF2\x86\x11a\x018W\x80cO\x1E\xF2\x86\x14a\x04\x03W\x80cR\xD1\x90-\x14a\x04\x16W\x80c\\\x97Z\xBB\x14a\x04*W\x80cqP\x18\xA6\x14a\x04JW__\xFD[\x80c6Y\xCF\xE6\x14a\x03\xAFW\x80c<z\xA9\x11\x14a\x03\xD0W\x80c?K\xA8:\x14a\x03\xEFW__\xFD[\x80c&\x0CSD\x11a\x01\x98W\x80c&\x0CSD\x14a\x02\xA7W\x80c0u\xDBV\x14a\x03\x1FW\x80c4\xCD\xF7\x8D\x14a\x03CW\x80c6<\xC4'\x14a\x03|W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x01\xBEW\x80c\x0FC\x9B\xD9\x14a\x02\tW\x80c\x12b.[\x14a\x02\\W[__\xFD[4\x80\x15a\x01\xC9W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x02\x14W__\xFD[P`@\x80Q\x80\x82\x01\x82R_\x80\x82R` \x91\x82\x01R\x81Q\x80\x83\x01\x83Ra\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80\x82Ra\x01\x02T\x91\x83\x01\x91\x82R\x83Q\x90\x81R\x90Q\x91\x81\x01\x91\x90\x91R\x01a\x02\0V[4\x80\x15a\x02gW__\xFD[Pa\x02\x8F\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x02\0V[4\x80\x15a\x02\xB2W__\xFD[Pa\x02\xC6a\x02\xC16`\x04a\"\x8BV[a\x07/V[`@Qa\x02\0\x91\x90_`\xA0\x82\x01\x90Pe\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16\x82Re\xFF\xFF\xFF\xFF\xFF\xFF` \x84\x01Q\x16` \x83\x01Re\xFF\xFF\xFF\xFF\xFF\xFF`@\x84\x01Q\x16`@\x83\x01R``\x83\x01Q``\x83\x01R`\x80\x83\x01Q`\x80\x83\x01R\x92\x91PPV[4\x80\x15a\x03*W__\xFD[Pa\x033a\x07\xDCV[`@Q\x90\x15\x15\x81R` \x01a\x02\0V[4\x80\x15a\x03NW__\xFD[Pa\x03na\x03]6`\x04a\"\x8BV[`\xFB` R_\x90\x81R`@\x90 T\x81V[`@Q\x90\x81R` \x01a\x02\0V[4\x80\x15a\x03\x87W__\xFD[Pa\x01\xEC\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x03\xBAW__\xFD[Pa\x03\xCEa\x03\xC96`\x04a\"\xBDV[a\x07\xF4V[\0[4\x80\x15a\x03\xDBW__\xFD[Pa\x03\xCEa\x03\xEA6`\x04a\"\xD6V[a\x08\xC4V[4\x80\x15a\x03\xFAW__\xFD[Pa\x03\xCEa\nXV[a\x03\xCEa\x04\x116`\x04a#\xF4V[a\n\xB3V[4\x80\x15a\x04!W__\xFD[Pa\x03na\x0BhV[4\x80\x15a\x045W__\xFD[Pa\x033`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x04UW__\xFD[Pa\x03\xCEa\x0C\x19V[4\x80\x15a\x04iW__\xFD[Pa\x03\xCEa\x0C*V[4\x80\x15a\x04}W__\xFD[Pa\x03\xCEa\x0C\xA1V[4\x80\x15a\x04\x91W__\xFD[Pa\x01\xECa\x0C\xF6V[4\x80\x15a\x04\xA5W__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xECV[4\x80\x15a\x04\xC2W__\xFD[Pa\x01\xEC\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\xF5W__\xFD[Pa\x01\xECqww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x81V[4\x80\x15a\x05\x1AW__\xFD[Pa\x05.a\x05)6`\x04a$\x90V[a\r\x04V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x83R` \x83\x01\x91\x90\x91R\x01a\x02\0V[4\x80\x15a\x05XW__\xFD[Pa\x05\xCE`@\x80Q`\x80\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x91\x90\x91RP`@\x80Q`\x80\x81\x01\x82R`\xFF\x80T\x82Ra\x01\0T`\x01`\x01`\xA0\x1B\x03\x81\x16` \x84\x01R`\x01`\xA0\x1B\x81\x04\x90\x91\x16\x15\x15\x92\x82\x01\x92\x90\x92R`\x01`\xA8\x1B\x90\x91\x04e\xFF\xFF\xFF\xFF\xFF\xFF\x16``\x82\x01R\x90V[`@Qa\x02\0\x91\x90\x81Q\x81R` \x80\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x16\x90\x82\x01R`@\x80\x83\x01Q\x15\x15\x90\x82\x01R``\x91\x82\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x91\x81\x01\x91\x90\x91R`\x80\x01\x90V[4\x80\x15a\x06\x1FW__\xFD[Pa\x063a\x06.6`\x04a$\xECV[a\r\xE4V[`@\x80Q\x93\x15\x15\x84R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16` \x84\x01R\x90\x82\x01R``\x01a\x02\0V[4\x80\x15a\x06cW__\xFD[Pa\x02\x8Fb\x0FB@\x81V[4\x80\x15a\x06yW__\xFD[Pa\x03n\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xACW__\xFD[Pa\x03n\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x06\xDFW__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x01\xECV[4\x80\x15a\x06\xFCW__\xFD[Pa\x03\xCEa\x07\x0B6`\x04a\"\xBDV[a\x0F\x87V[4\x80\x15a\x07\x1BW__\xFD[Pa\x03\xCEa\x07*6`\x04a%\\V[a\x0F\xF8V[`@\x80Q`\xA0\x81\x01\x82R_\x80\x82R` \x82\x01\x81\x90R\x91\x81\x01\x82\x90R``\x81\x01\x82\x90R`\x80\x81\x01\x91\x90\x91R_\x82\x81Ra\x01\x03` \x90\x81R`@\x80\x83 \x81Q`\xA0\x81\x01\x83R\x81Te\xFF\xFF\xFF\xFF\xFF\xFF\x80\x82\x16\x80\x84Rf\x01\0\0\0\0\0\0\x83\x04\x82\x16\x96\x84\x01\x96\x90\x96R`\x01``\x1B\x90\x91\x04\x16\x92\x81\x01\x92\x90\x92R`\x01\x81\x01T``\x83\x01R`\x02\x01T`\x80\x82\x01R\x91\x03a\x07\xD6W`@Qc\x13\x91\xE1\x1B`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x92\x91PPV[_`\x02a\x07\xEB`\xC9T`\xFF\x16\x90V[`\xFF\x16\x14\x90P\x90V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x08EW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\x8DV[`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x08wa\x114V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x08\x9DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\xD9V[a\x08\xA6\x81a\x11OV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x08\xC1\x91\x83\x91\x90a\x11WV[PV[3qww56{6\xBC\x9Ba\xC5\0\"\xD9\xD0p\r\xB4\xEC\x14a\x08\xF6W`@Qcn\xDA\xEF/`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x08\xFEa\x12\xC6V[a\t\x08`\x02a\x12\xF5V[a\x01\0T`\x01`\xA8\x1B\x90\x04e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x80a\t,`@\x85\x01` \x86\x01a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x10\x15a\tSW`@Qc\"\x93)\xC7`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16a\tl`@\x85\x01` \x86\x01a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\t\x83Wa\t\x83\x83a\x13\x0BV[a\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16a\t\x98\x83a\x15\x16V[a\t\xA2\x84\x84a\x16zV[_a\t\xAE`\x01Ca&>V[_\x81\x81R`\xFB` \x90\x81R`@\x91\x82\x90 \x83@\x90U`\xFF\x80Ta\x01\0Ta\x01\x01Ta\x01\x02T\x86Q\x93\x84R`\x01`\x01`\xA0\x1B\x03\x83\x16\x95\x84\x01\x95\x90\x95R`\x01`\xA0\x1B\x90\x91\x04\x90\x92\x16\x15\x15\x93\x81\x01\x93\x90\x93Re\xFF\xFF\xFF\xFF\xFF\xFF\x80\x87\x16``\x85\x01R\x16`\x80\x83\x01R`\xA0\x82\x01R\x90\x91P\x7F\xE8\rU^\xB6\x90oi\x07\xB6\x8En\xAD7\xD1\x08\x9D\x1F\xBB~#\xA6\x8F35\xDD\x04\xF8\xAE\xF3\xE1\xE7\x90`\xC0\x01`@Q\x80\x91\x03\x90\xA1PPPa\nT`\x01a\x12\xF5V[PPV[a\n`a\x17\x7FV[a\nt`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xB13_a\x17\xB0V[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\n\xFBW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\x8DV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x0B-a\x114V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x0BSW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x90a%\xD9V[a\x0B\\\x82a\x11OV[a\nT\x82\x82`\x01a\x11WV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0C\x07W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x08<V[P_Q` a)5_9_Q\x90_R\x90V[a\x0C!a\x17\xB4V[a\n\xB1_a\x18\x0EV[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\x0C\x98W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\x08<V[a\x08\xC1\x81a\x18\x0EV[a\x0C\xA9a\x18'V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\n\xB13`\x01a\x17\xB0V[_a\x0C\xFFa\x114V[\x90P\x90V[_\x80`\xE1\x83\x10\x15a\r\x19WP\x83\x90P_a\r\xDBV[_a\r&\x84\x86\x01\x86a&]V[\x90Pa\r3\x81\x88\x88a\x18YV[a\rCW\x85_\x92P\x92PPa\r\xDBV[`A\x81``\x01QQ\x14a\r\\W\x85_\x92P\x92PPa\r\xDBV[__a\rta\rj\x84a\x18\x99V[\x84``\x01Qa\x18\xD6V[\x90\x92P\x90P_\x81`\x04\x81\x11\x15a\r\x8CWa\r\x8Ca&\xF3V[\x14\x15\x80a\r\xA0WP`\x01`\x01`\xA0\x1B\x03\x82\x16\x15[\x15a\r\xB3W\x87_\x94P\x94PPPPa\r\xDBV[\x81\x94P\x87`\x01`\x01`\xA0\x1B\x03\x16\x85`\x01`\x01`\xA0\x1B\x03\x16\x14a\r\xD7W\x82`@\x01Q\x93P[PPP[\x94P\x94\x92PPPV[_____a\r\xF5\x8A\x8A\x8A\x8Aa\r\x04V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x8C\x81\x16`\x04\x83\x01R`$\x82\x01\x83\x90R\x92\x94P\x90\x92P_\x91\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0EhW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0E\x8C\x91\x90a'\x07V[\x90P\x80a\x0E\xA5W`\x01\x87_\x95P\x95P\x95PPPPa\x0F|V[\x89`\x01`\x01`\xA0\x1B\x03\x16\x83`\x01`\x01`\xA0\x1B\x03\x16\x03a\x0E\xCFW_\x8A_\x95P\x95P\x95PPPPa\x0F|V[`@QcP\x8BrC`\xE1\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x84\x81\x16`\x04\x83\x01R_`$\x83\x01R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xA1\x16\xE4\x86\x90`D\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x0F9W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x0F]\x91\x90a'\x07V[a\x0FrW_\x8A_\x95P\x95P\x95PPPPa\x0F|V[P_\x94P\x90\x92P\x90P[\x95P\x95P\x95\x92PPPV[a\x0F\x8Fa\x17\xB4V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\x0F\xC0`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[a\x10\0a\x17\xB4V[a\x10\x08a\x12\xC6V[a\x10\x12`\x02a\x12\xF5V[`\x01`\x01`\xA0\x1B\x03\x81\x16a\x109W`@Qc\xE6\xC4${`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\x10bWPGa\x10]`\x01`\x01`\xA0\x1B\x03\x83\x16\x82a\x19\x18V[a\x10\xDEV[`@Qcp\xA0\x821`\xE0\x1B\x81R0`\x04\x82\x01R`\x01`\x01`\xA0\x1B\x03\x84\x16\x90cp\xA0\x821\x90`$\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x15\x80\x15a\x10\xA4W=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x10\xC8\x91\x90a'&V[\x90Pa\x10\xDE`\x01`\x01`\xA0\x1B\x03\x84\x16\x83\x83a\x19#V[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x80\x86\x16\x82R\x84\x16` \x82\x01R\x90\x81\x01\x82\x90R\x7F\xD1\xC1\x9F\xBC\xD4U\x1A^\xDF\xB6mC\xD2\xE37\xC0H7\xAF\xDA4\x82\xB4+\xDFV\x9A\x8F\xCC\xDA\xE5\xFB\x90``\x01`@Q\x80\x91\x03\x90\xA1Pa\nT`\x01a\x12\xF5V[_Q` a)5_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x08\xC1a\x17\xB4V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x11\x8FWa\x11\x8A\x83a\x19uV[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x11\xE9WP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x11\xE6\x91\x81\x01\x90a'&V[`\x01[a\x12LW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\x08<V[_Q` a)5_9_Q\x90_R\x81\x14a\x12\xBAW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\x08<V[Pa\x11\x8A\x83\x83\x83a\x1A\x10V[`\x02a\x12\xD4`\xC9T`\xFF\x16\x90V[`\xFF\x16\x03a\n\xB1W`@Qc\xDF\xC6\r\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\xC9\x80T`\xFF\x19\x16`\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[_a\x13Na\x13\x1F`@\x84\x01` \x85\x01a&%V[a\x13/``\x85\x01`@\x86\x01a\"\xBDV[a\x13<``\x86\x01\x86a'=V[a\x01\0T`\x01`\x01`\xA0\x1B\x03\x16a\r\xE4V[a\x01\0\x80T\x93\x15\x15`\x01`\xA0\x1B\x02`\x01`\x01`\xA8\x1B\x03\x19\x90\x94\x16`\x01`\x01`\xA0\x1B\x03\x90\x93\x16\x92\x90\x92\x17\x92\x90\x92\x17\x90U\x90P\x80\x15a\x14\xB7W`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x13\xC4``\x85\x01`@\x86\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x14\x0EW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x142\x91\x90a'&V[Pa\x01\0T`@Qc/\x8C\xB4}`\xE2\x1B\x81R`\x01`\x01`\xA0\x1B\x03\x91\x82\x16`\x04\x82\x01R`$\x81\x01\x83\x90R\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x90\x91\x16\x90c\xBE2\xD1\xF4\x90`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x14\xA0W__\xFD[PZ\xF1\x15\x80\x15a\x14\xB2W=__>=_\xFD[PPPP[`\xFFTa\x14\xD5\x90a\x14\xCB`\xA0\x85\x01\x85a'\x7FV[\x85`\x80\x015a\x1A:V[`\xFFUa\x14\xE8`@\x83\x01` \x84\x01a&%V[a\x01\0\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16`\x01`\xA8\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF`\xA8\x1B\x19\x90\x92\x16\x91\x90\x91\x17\x90UPPV[__a\x15 a\x1C\"V[a\x01\x02T\x91\x93P\x91P\x15a\x15QWa\x01\x02T\x82\x14a\x15QW`@QcId_\xFD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x01\x02\x81\x90Ua\x01\x01Te\xFF\xFF\xFF\xFF\xFF\xFF\x16a\x15p` \x85\x01\x85a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x11\x15a\x11\x8AW`@\x80Q``\x81\x01\x90\x91R`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x90c\xC9\xA0\xB8\xC8\x90\x80a\x15\xC8` \x88\x01\x88a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R` \x88\x81\x015\x81\x84\x01R`@\x80\x8A\x015\x93\x81\x01\x93\x90\x93R\x82Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x87\x90\x1B\x16\x81R\x84Q\x90\x92\x16`\x04\x83\x01R\x83\x01Q`$\x82\x01R\x91\x01Q`D\x82\x01R`d\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x162W__\xFD[PZ\xF1\x15\x80\x15a\x16DW=__>=_\xFD[Pa\x16V\x92PPP` \x84\x01\x84a&%V[a\x01\x01\x80Te\xFF\xFF\xFF\xFF\xFF\xFF\x19\x16e\xFF\xFF\xFF\xFF\xFF\xFF\x92\x90\x92\x16\x91\x90\x91\x17\x90UPPPV[_a\x01\x03\x81a\x16\x8A`\x01Ca&>V[\x81R` \x01\x90\x81R` \x01_ \x90P`@Q\x80`\xA0\x01`@R\x80\x83_\x01` \x81\x01\x90a\x16\xB6\x91\x90a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x90\x81\x01\x90a\x16\xD2\x90\x86\x01\x86a&%V[e\xFF\xFF\xFF\xFF\xFF\xFF\x90\x81\x16\x82R\x83Tf\x01\0\0\0\0\0\0\x90\x81\x90\x04\x82\x16` \x80\x85\x01\x91\x90\x91R``\x96\x87\x015`@\x80\x86\x01\x91\x90\x91R`\x01\x96\x87\x01T\x94\x88\x01\x94\x90\x94RC_\x90\x81Ra\x01\x03\x82R\x84\x90 \x85Q\x81T\x92\x87\x01Q\x95\x87\x01Q\x85\x16`\x01``\x1B\x02e\xFF\xFF\xFF\xFF\xFF\xFF``\x1B\x19\x96\x86\x16\x90\x94\x02k\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19\x90\x93\x16\x94\x16\x93\x90\x93\x17\x17\x92\x90\x92\x16\x91\x90\x91\x17\x81U\x92\x81\x01Q\x91\x83\x01\x91\x90\x91U`\x80\x01Q`\x02\x90\x91\x01UPV[a\x17\x93`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\n\xB1W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\nT[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\n\xB1W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x08<V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x08\xC1\x81a\x1C\xBFV[a\x18;`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\n\xB1W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x82e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x84_\x01Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x14\x80\x15a\x18\x91WP\x81`\x01`\x01`\xA0\x1B\x03\x16\x84` \x01Q`\x01`\x01`\xA0\x1B\x03\x16\x14[\x94\x93PPPPV[\x80Q` \x80\x83\x01Q`@\x80\x85\x01Q\x81Qe\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R`\x01`\x01`\xA0\x1B\x03\x90\x92\x16\x92\x84\x01\x92\x90\x92R\x90\x82\x01R``\x90 _\x90a\x07\xD6V[__\x82Q`A\x03a\x19\nW` \x83\x01Q`@\x84\x01Q``\x85\x01Q_\x1Aa\x18\xFE\x87\x82\x85\x85a\x1D\x10V[\x94P\x94PPPPa\x19\x11V[P_\x90P`\x02[\x92P\x92\x90PV[a\nT\x82\x82Za\x1D\xCAV[`@\x80Q`\x01`\x01`\xA0\x1B\x03\x84\x16`$\x82\x01R`D\x80\x82\x01\x84\x90R\x82Q\x80\x83\x03\x90\x91\x01\x81R`d\x90\x91\x01\x90\x91R` \x81\x01\x80Q`\x01`\x01`\xE0\x1B\x03\x16c\xA9\x05\x9C\xBB`\xE0\x1B\x17\x90Ra\x11\x8A\x90\x84\x90a\x1E\rV[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\x19\xE2W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\x08<V[_Q` a)5_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a\x1A\x19\x83a\x1E\xE0V[_\x82Q\x11\x80a\x1A%WP\x80[\x15a\x11\x8AWa\x1A4\x83\x83a\x1F\x1FV[PPPPV[\x83\x82_[\x81\x81\x10\x15a\x1B\xF8W6\x86\x86\x83\x81\x81\x10a\x1AYWa\x1AYa'\xC4V[\x90P`\x80\x02\x01\x90P_a\x1A}\x82` \x01` \x81\x01\x90a\x1Ax\x91\x90a'\xE6V[a\x1FKV[\x90P\x80\x15a\x1B\xD1W_`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c9\x13\x96\xDEa\x1A\xC5``\x86\x01`@\x87\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x85\x90R`D\x01` `@Q\x80\x83\x03\x81_\x87Z\xF1\x15\x80\x15a\x1B\x0FW=__>=_\xFD[PPPP`@Q=`\x1F\x19`\x1F\x82\x01\x16\x82\x01\x80`@RP\x81\x01\x90a\x1B3\x91\x90a'&V[\x90P`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16c\xBE2\xD1\xF4a\x1Bt`\x80\x86\x01``\x87\x01a\"\xBDV[`@Q`\x01`\x01`\xE0\x1B\x03\x19`\xE0\x84\x90\x1B\x16\x81R`\x01`\x01`\xA0\x1B\x03\x90\x91\x16`\x04\x82\x01R`$\x81\x01\x84\x90R`D\x01_`@Q\x80\x83\x03\x81_\x87\x80;\x15\x80\x15a\x1B\xB9W__\xFD[PZ\xF1\x15\x80\x15a\x1B\xCBW=__>=_\xFD[PPPPP[a\x1B\xE9\x85a\x1B\xE46\x85\x90\x03\x85\x01\x85a'\xFFV[a\x1F\xD3V[\x94PPP\x80`\x01\x01\x90Pa\x1A>V[P\x82\x82\x14a\x1C\x19W`@Qc\x88\xC4p\x0B`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x94\x93PPPPV[_\x80\x80a\x1C0`\x01Ca&>V[\x90Pa\x1C:a\"kV[Fa\x1F\xE0\x82\x01R_[`\xFF\x81\x10\x80\x15a\x1CVWP\x80`\x01\x01\x83\x10\x15[\x15a\x1C\x87W_\x19\x81\x84\x03\x01\x80@\x83`\xFF\x83\x06a\x01\0\x81\x10a\x1CyWa\x1Cya'\xC4V[` \x02\x01RP`\x01\x01a\x1CCV[Pa \0\x81 \x93P\x81@\x81a\x1C\x9D`\xFF\x85a(^V[a\x01\0\x81\x10a\x1C\xAEWa\x1C\xAEa'\xC4V[` \x02\x01Ra \0\x90 \x92\x93\x91PPV[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_\x80\x7F\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF]WnsW\xA4P\x1D\xDF\xE9/Fh\x1B \xA0\x83\x11\x15a\x1DEWP_\x90P`\x03a\r\xDBV[`@\x80Q_\x80\x82R` \x82\x01\x80\x84R\x89\x90R`\xFF\x88\x16\x92\x82\x01\x92\x90\x92R``\x81\x01\x86\x90R`\x80\x81\x01\x85\x90R`\x01\x90`\xA0\x01` `@Q` \x81\x03\x90\x80\x84\x03\x90\x85Z\xFA\x15\x80\x15a\x1D\x96W=__>=_\xFD[PP`@Q`\x1F\x19\x01Q\x91PP`\x01`\x01`\xA0\x1B\x03\x81\x16a\x1D\xBEW_`\x01\x92P\x92PPa\r\xDBV[\x96_\x96P\x94PPPPPV[\x81_\x03a\x1D\xD6WPPPV[a\x1D\xF0\x83\x83\x83`@Q\x80` \x01`@R\x80_\x81RPa 8V[a\x11\x8AW`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x1Ea\x82`@Q\x80`@\x01`@R\x80` \x81R` \x01\x7FSafeERC20: low-level call failed\x81RP\x85`\x01`\x01`\xA0\x1B\x03\x16a u\x90\x92\x91\x90c\xFF\xFF\xFF\xFF\x16V[\x90P\x80Q_\x14\x80a\x1E\x81WP\x80\x80` \x01\x90Q\x81\x01\x90a\x1E\x81\x91\x90a'\x07V[a\x11\x8AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`*`$\x82\x01R\x7FSafeERC20: ERC20 operation did n`D\x82\x01Ri\x1B\xDD\x08\x1C\xDDX\xD8\xD9YY`\xB2\x1B`d\x82\x01R`\x84\x01a\x08<V[a\x1E\xE9\x81a\x19uV[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x1FD\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a)U`'\x919a \x83V[\x93\x92PPPV[_`\x02\x82`\x02\x81\x11\x15a\x1F`Wa\x1F`a&\xF3V[\x03a\x1F\x8CWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[`\x01\x82`\x02\x81\x11\x15a\x1F\xA0Wa\x1F\xA0a&\xF3V[\x03a\x1F\xCCWP\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x91\x90PV[P_\x91\x90PV[\x80Q_\x90e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x15\x80a\x1F\xFFWP_\x82` \x01Q`\x02\x81\x11\x15a\x1F\xFDWa\x1F\xFDa&\xF3V[\x14[a 1W\x82\x82`@Q` \x01a \x16\x92\x91\x90a(}V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 a\x1FDV[P\x90\x91\x90PV[_`\x01`\x01`\xA0\x1B\x03\x85\x16a `W`@QcLg\x13M`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[__\x83Q` \x85\x01\x87\x89\x88\xF1\x95\x94PPPPPV[``a\x18\x91\x84\x84_\x85a \xF7V[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa \x9F\x91\x90a(\xE9V[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a \xD7W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a \xDCV[``\x91P[P\x91P\x91Pa \xED\x86\x83\x83\x87a!\xCEV[\x96\x95PPPPPPV[``\x82G\x10\x15a!XW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FAddress: insufficient balance fo`D\x82\x01Re\x1C\x88\x18\xD8[\x1B`\xD2\x1B`d\x82\x01R`\x84\x01a\x08<V[__\x86`\x01`\x01`\xA0\x1B\x03\x16\x85\x87`@Qa!s\x91\x90a(\xE9V[_`@Q\x80\x83\x03\x81\x85\x87Z\xF1\x92PPP=\x80_\x81\x14a!\xADW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a!\xB2V[``\x91P[P\x91P\x91Pa!\xC3\x87\x83\x83\x87a!\xCEV[\x97\x96PPPPPPPV[``\x83\x15a\"<W\x82Q_\x03a\"5W`\x01`\x01`\xA0\x1B\x03\x85\x16;a\"5W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x08<V[P\x81a\x18\x91V[a\x18\x91\x83\x83\x81Q\x15a\"QW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x08<\x91\x90a(\xFFV[`@Q\x80a \0\x01`@R\x80a\x01\0\x90` \x82\x02\x806\x837P\x91\x92\x91PPV[_` \x82\x84\x03\x12\x15a\"\x9BW__\xFD[P5\x91\x90PV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\"\xB8W__\xFD[\x91\x90PV[_` \x82\x84\x03\x12\x15a\"\xCDW__\xFD[a\x1FD\x82a\"\xA2V[__\x82\x84\x03`\xA0\x81\x12\x15a\"\xE8W__\xFD[\x835`\x01`\x01`@\x1B\x03\x81\x11\x15a\"\xFDW__\xFD[\x84\x01`\xC0\x81\x87\x03\x12\x15a#\x0EW__\xFD[\x92P`\x80`\x1F\x19\x82\x01\x12\x15a#!W__\xFD[P` \x83\x01\x90P\x92P\x92\x90PV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\x80\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a#eWa#ea#/V[`@R\x90V[_\x82`\x1F\x83\x01\x12a#zW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a#\x93Wa#\x93a#/V[`@Q`\x1F\x82\x01`\x1F\x19\x90\x81\x16`?\x01\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a#\xC1Wa#\xC1a#/V[`@R\x81\x81R\x83\x82\x01` \x01\x85\x10\x15a#\xD8W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a$\x05W__\xFD[a$\x0E\x83a\"\xA2V[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a$(W__\xFD[a$4\x85\x82\x86\x01a#kV[\x91PP\x92P\x92\x90PV[\x805e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\"\xB8W__\xFD[__\x83`\x1F\x84\x01\x12a$cW__\xFD[P\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a$yW__\xFD[` \x83\x01\x91P\x83` \x82\x85\x01\x01\x11\x15a\x19\x11W__\xFD[____``\x85\x87\x03\x12\x15a$\xA3W__\xFD[a$\xAC\x85a$>V[\x93Pa$\xBA` \x86\x01a\"\xA2V[\x92P`@\x85\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a$\xD4W__\xFD[a$\xE0\x87\x82\x88\x01a$SV[\x95\x98\x94\x97P\x95PPPPV[_____`\x80\x86\x88\x03\x12\x15a%\0W__\xFD[a%\t\x86a$>V[\x94Pa%\x17` \x87\x01a\"\xA2V[\x93P`@\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a%1W__\xFD[a%=\x88\x82\x89\x01a$SV[\x90\x94P\x92Pa%P\x90P``\x87\x01a\"\xA2V[\x90P\x92\x95P\x92\x95\x90\x93PV[__`@\x83\x85\x03\x12\x15a%mW__\xFD[a%v\x83a\"\xA2V[\x91Pa%\x84` \x84\x01a\"\xA2V[\x90P\x92P\x92\x90PV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a&5W__\xFD[a\x1FD\x82a$>V[\x81\x81\x03\x81\x81\x11\x15a\x07\xD6WcNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a&mW__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a&\x82W__\xFD[\x82\x01`\x80\x81\x85\x03\x12\x15a&\x93W__\xFD[a&\x9Ba#CV[a&\xA4\x82a$>V[\x81Ra&\xB2` \x83\x01a\"\xA2V[` \x82\x01R`@\x82\x81\x015\x90\x82\x01R``\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a&\xD9W__\xFD[a&\xE5\x86\x82\x85\x01a#kV[``\x83\x01RP\x94\x93PPPPV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[_` \x82\x84\x03\x12\x15a'\x17W__\xFD[\x81Q\x80\x15\x15\x81\x14a\x1FDW__\xFD[_` \x82\x84\x03\x12\x15a'6W__\xFD[PQ\x91\x90PV[__\x835`\x1E\x19\x846\x03\x01\x81\x12a'RW__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a'kW__\xFD[` \x01\x91P6\x81\x90\x03\x82\x13\x15a\x19\x11W__\xFD[__\x835`\x1E\x19\x846\x03\x01\x81\x12a'\x94W__\xFD[\x83\x01\x805\x91P`\x01`\x01`@\x1B\x03\x82\x11\x15a'\xADW__\xFD[` \x01\x91P`\x07\x81\x90\x1B6\x03\x82\x13\x15a\x19\x11W__\xFD[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[\x805`\x03\x81\x10a\"\xB8W__\xFD[_` \x82\x84\x03\x12\x15a'\xF6W__\xFD[a\x1FD\x82a'\xD8V[_`\x80\x82\x84\x03\x12\x80\x15a(\x10W__\xFD[Pa(\x19a#CV[a(\"\x83a$>V[\x81Ra(0` \x84\x01a'\xD8V[` \x82\x01Ra(A`@\x84\x01a\"\xA2V[`@\x82\x01Ra(R``\x84\x01a\"\xA2V[``\x82\x01R\x93\x92PPPV[_\x82a(xWcNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[P\x06\x90V[_`\xA0\x82\x01\x90P\x83\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x83Q\x16` \x83\x01R` \x83\x01Q`\x03\x81\x10a(\xB7WcNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[`@\x83\x81\x01\x91\x90\x91R\x83\x01Q`\x01`\x01`\xA0\x1B\x03\x90\x81\x16``\x80\x85\x01\x91\x90\x91R\x90\x93\x01Q\x90\x92\x16`\x80\x90\x91\x01R\x91\x90PV[_\x82Q\x80` \x85\x01\x84^_\x92\x01\x91\x82RP\x91\x90PV[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \x1B\x1C<\xB3\t/\x10\0Q$D\xEE\xF2e\xAB]\x96\x9A\x83\xBD^C8?\xFC\tllc\x83\xADVdsolcC\0\x08\x1E\x003",
    );
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct BlockParams { uint48 anchorBlockNumber; bytes32 anchorBlockHash; bytes32 anchorStateRoot; bytes32 rawTxListHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BlockParams {
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub anchorBlockHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub anchorStateRoot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub rawTxListHash: alloy::sol_types::private::FixedBytes<32>,
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
            alloy::sol_types::sol_data::FixedBytes<32>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
            alloy::sol_types::private::FixedBytes<32>,
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
                    value.anchorBlockNumber,
                    value.anchorBlockHash,
                    value.anchorStateRoot,
                    value.rawTxListHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for BlockParams {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    anchorBlockNumber: tuple.0,
                    anchorBlockHash: tuple.1,
                    anchorStateRoot: tuple.2,
                    rawTxListHash: tuple.3,
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
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorStateRoot),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.rawTxListHash),
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
                    "BlockParams(uint48 anchorBlockNumber,bytes32 anchorBlockHash,bytes32 anchorStateRoot,bytes32 rawTxListHash)",
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
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.rawTxListHash)
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
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.rawTxListHash,
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
                    &rust.anchorBlockHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.anchorStateRoot,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.rawTxListHash,
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
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**```solidity
struct PreconfMetadata { uint48 anchorBlockNumber; uint48 submissionWindowEnd; uint48 parentSubmissionWindowEnd; bytes32 rawTxListHash; bytes32 parentRawTxListHash; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct PreconfMetadata {
        #[allow(missing_docs)]
        pub anchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub submissionWindowEnd: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub parentSubmissionWindowEnd: alloy::sol_types::private::primitives::aliases::U48,
        #[allow(missing_docs)]
        pub rawTxListHash: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub parentRawTxListHash: alloy::sol_types::private::FixedBytes<32>,
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
        impl ::core::convert::From<PreconfMetadata> for UnderlyingRustTuple<'_> {
            fn from(value: PreconfMetadata) -> Self {
                (
                    value.anchorBlockNumber,
                    value.submissionWindowEnd,
                    value.parentSubmissionWindowEnd,
                    value.rawTxListHash,
                    value.parentRawTxListHash,
                )
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for PreconfMetadata {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self {
                    anchorBlockNumber: tuple.0,
                    submissionWindowEnd: tuple.1,
                    parentSubmissionWindowEnd: tuple.2,
                    rawTxListHash: tuple.3,
                    parentRawTxListHash: tuple.4,
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolValue for PreconfMetadata {
            type SolType = Self;
        }
        #[automatically_derived]
        impl alloy_sol_types::private::SolTypeValue<Self> for PreconfMetadata {
            #[inline]
            fn stv_to_tokens(&self) -> <Self as alloy_sol_types::SolType>::Token<'_> {
                (
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.anchorBlockNumber),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.submissionWindowEnd),
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.parentSubmissionWindowEnd,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.rawTxListHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.parentRawTxListHash),
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
        impl alloy_sol_types::SolType for PreconfMetadata {
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
        impl alloy_sol_types::SolStruct for PreconfMetadata {
            const NAME: &'static str = "PreconfMetadata";
            #[inline]
            fn eip712_root_type() -> alloy_sol_types::private::Cow<'static, str> {
                alloy_sol_types::private::Cow::Borrowed(
                    "PreconfMetadata(uint48 anchorBlockNumber,uint48 submissionWindowEnd,uint48 parentSubmissionWindowEnd,bytes32 rawTxListHash,bytes32 parentRawTxListHash)",
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.submissionWindowEnd,
                        )
                        .0,
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.parentSubmissionWindowEnd,
                        )
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.rawTxListHash)
                        .0,
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.parentRawTxListHash,
                        )
                        .0,
                ]
                    .concat()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::EventTopic for PreconfMetadata {
            #[inline]
            fn topic_preimage_length(rust: &Self::RustType) -> usize {
                0usize
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.anchorBlockNumber,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.submissionWindowEnd,
                    )
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.parentSubmissionWindowEnd,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.rawTxListHash,
                    )
                    + <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.parentRawTxListHash,
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
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.submissionWindowEnd,
                    out,
                );
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.parentSubmissionWindowEnd,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.rawTxListHash,
                    out,
                );
                <alloy::sol_types::sol_data::FixedBytes<
                    32,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.parentRawTxListHash,
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
struct ProposalParams { uint48 submissionWindowEnd; uint48 proposalId; address proposer; bytes proverAuth; bytes32 bondInstructionsHash; LibBonds.BondInstruction[] bondInstructions; }
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ProposalParams {
        #[allow(missing_docs)]
        pub submissionWindowEnd: alloy::sol_types::private::primitives::aliases::U48,
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
            alloy::sol_types::sol_data::Uint<48>,
            alloy::sol_types::sol_data::Address,
            alloy::sol_types::sol_data::Bytes,
            alloy::sol_types::sol_data::FixedBytes<32>,
            alloy::sol_types::sol_data::Array<LibBonds::BondInstruction>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::primitives::aliases::U48,
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
                    value.submissionWindowEnd,
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
                    submissionWindowEnd: tuple.0,
                    proposalId: tuple.1,
                    proposer: tuple.2,
                    proverAuth: tuple.3,
                    bondInstructionsHash: tuple.4,
                    bondInstructions: tuple.5,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.submissionWindowEnd),
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
                    "ProposalParams(uint48 submissionWindowEnd,uint48 proposalId,address proposer,bytes proverAuth,bytes32 bondInstructionsHash,LibBonds.BondInstruction[] bondInstructions)",
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
                    > as alloy_sol_types::SolType>::eip712_data_word(
                            &self.submissionWindowEnd,
                        )
                        .0,
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
                        &rust.submissionWindowEnd,
                    )
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
                    &rust.submissionWindowEnd,
                    out,
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
struct ProposalState { bytes32 bondInstructionsHash; address designatedProver; bool isLowBondProposal; uint48 proposalId; }
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
        #[allow(missing_docs)]
        pub proposalId: alloy::sol_types::private::primitives::aliases::U48,
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
            alloy::sol_types::sol_data::Uint<48>,
        );
        #[doc(hidden)]
        type UnderlyingRustTuple<'a> = (
            alloy::sol_types::private::FixedBytes<32>,
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
        impl ::core::convert::From<ProposalState> for UnderlyingRustTuple<'_> {
            fn from(value: ProposalState) -> Self {
                (
                    value.bondInstructionsHash,
                    value.designatedProver,
                    value.isLowBondProposal,
                    value.proposalId,
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
                    proposalId: tuple.3,
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::tokenize(&self.proposalId),
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
                    "ProposalState(bytes32 bondInstructionsHash,address designatedProver,bool isLowBondProposal,uint48 proposalId)",
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
                    <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::SolType>::eip712_data_word(&self.proposalId)
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
                    + <alloy::sol_types::sol_data::Uint<
                        48,
                    > as alloy_sol_types::EventTopic>::topic_preimage_length(
                        &rust.proposalId,
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
                <alloy::sol_types::sol_data::Uint<
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic_preimage(
                    &rust.proposalId,
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
    /**Custom error with signature `InvalidBlockNumber()` and selector `0x4e47846c`.
```solidity
error InvalidBlockNumber();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidBlockNumber;
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
        impl ::core::convert::From<InvalidBlockNumber> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidBlockNumber) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidBlockNumber {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidBlockNumber {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidBlockNumber()";
            const SELECTOR: [u8; 4] = [78u8, 71u8, 132u8, 108u8];
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
    /**Event with signature `Anchored(bytes32,address,bool,uint48,uint48,bytes32)` and selector `0xe80d555eb6906f6907b68e6ead37d1089d1fbb7e23a68f3335dd04f8aef3e1e7`.
```solidity
event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash);
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
        pub prevAnchorBlockNumber: alloy::sol_types::private::primitives::aliases::U48,
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
                alloy::sol_types::sol_data::Uint<48>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "Anchored(bytes32,address,bool,uint48,uint48,bytes32)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                232u8, 13u8, 85u8, 94u8, 182u8, 144u8, 111u8, 105u8, 7u8, 182u8, 142u8,
                110u8, 173u8, 55u8, 209u8, 8u8, 157u8, 31u8, 187u8, 126u8, 35u8, 166u8,
                143u8, 51u8, 53u8, 221u8, 4u8, 248u8, 174u8, 243u8, 225u8, 231u8,
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
                    prevAnchorBlockNumber: data.3,
                    anchorBlockNumber: data.4,
                    ancestorsHash: data.5,
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
                    > as alloy_sol_types::SolType>::tokenize(
                        &self.prevAnchorBlockNumber,
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
    /**Function with signature `anchorV4((uint48,uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint48,bytes32,bytes32,bytes32))` and selector `0x3c7aa911`.
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
    ///Container type for the return parameters of the [`anchorV4((uint48,uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint48,bytes32,bytes32,bytes32))`](anchorV4Call) function.
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
            const SIGNATURE: &'static str = "anchorV4((uint48,uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]),(uint48,bytes32,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [60u8, 122u8, 169u8, 17u8];
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
    /**Function with signature `blockHashes(uint256)` and selector `0x34cdf78d`.
```solidity
function blockHashes(uint256 blockNumber) external view returns (bytes32 blockHash);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blockHashesCall {
        #[allow(missing_docs)]
        pub blockNumber: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`blockHashes(uint256)`](blockHashesCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct blockHashesReturn {
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
            impl ::core::convert::From<blockHashesCall> for UnderlyingRustTuple<'_> {
                fn from(value: blockHashesCall) -> Self {
                    (value.blockNumber,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for blockHashesCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { blockNumber: tuple.0 }
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
            impl ::core::convert::From<blockHashesReturn> for UnderlyingRustTuple<'_> {
                fn from(value: blockHashesReturn) -> Self {
                    (value.blockHash,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for blockHashesReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { blockHash: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for blockHashesCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "blockHashes(uint256)";
            const SELECTOR: [u8; 4] = [52u8, 205u8, 247u8, 141u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self.blockNumber),
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
                        let r: blockHashesReturn = r.into();
                        r.blockHash
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
                        let r: blockHashesReturn = r.into();
                        r.blockHash
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
    /**Function with signature `getPreconfMetadata(uint256)` and selector `0x260c5344`.
```solidity
function getPreconfMetadata(uint256 _blockNumber) external view returns (PreconfMetadata memory);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getPreconfMetadataCall {
        #[allow(missing_docs)]
        pub _blockNumber: alloy::sol_types::private::primitives::aliases::U256,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getPreconfMetadata(uint256)`](getPreconfMetadataCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getPreconfMetadataReturn {
        #[allow(missing_docs)]
        pub _0: <PreconfMetadata as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getPreconfMetadataCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: getPreconfMetadataCall) -> Self {
                    (value._blockNumber,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getPreconfMetadataCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _blockNumber: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            type UnderlyingSolTuple<'a> = (PreconfMetadata,);
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                <PreconfMetadata as alloy::sol_types::SolType>::RustType,
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
            impl ::core::convert::From<getPreconfMetadataReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: getPreconfMetadataReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for getPreconfMetadataReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getPreconfMetadataCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <PreconfMetadata as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (PreconfMetadata,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getPreconfMetadata(uint256)";
            const SELECTOR: [u8; 4] = [38u8, 12u8, 83u8, 68u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._blockNumber),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (<PreconfMetadata as alloy_sol_types::SolType>::tokenize(ret),)
            }
            #[inline]
            fn abi_decode_returns(data: &[u8]) -> alloy_sol_types::Result<Self::Return> {
                <Self::ReturnTuple<
                    '_,
                > as alloy_sol_types::SolType>::abi_decode_sequence(data)
                    .map(|r| {
                        let r: getPreconfMetadataReturn = r.into();
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
                        let r: getPreconfMetadataReturn = r.into();
                        r._0
                    })
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
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        anchorV4(anchorV4Call),
        #[allow(missing_docs)]
        blockHashes(blockHashesCall),
        #[allow(missing_docs)]
        bondManager(bondManagerCall),
        #[allow(missing_docs)]
        checkpointStore(checkpointStoreCall),
        #[allow(missing_docs)]
        getBlockState(getBlockStateCall),
        #[allow(missing_docs)]
        getDesignatedProver(getDesignatedProverCall),
        #[allow(missing_docs)]
        getPreconfMetadata(getPreconfMetadataCall),
        #[allow(missing_docs)]
        getProposalState(getProposalStateCall),
        #[allow(missing_docs)]
        r#impl(implCall),
        #[allow(missing_docs)]
        inNonReentrant(inNonReentrantCall),
        #[allow(missing_docs)]
        l1ChainId(l1ChainIdCall),
        #[allow(missing_docs)]
        livenessBond(livenessBondCall),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pause(pauseCall),
        #[allow(missing_docs)]
        paused(pausedCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        provabilityBond(provabilityBondCall),
        #[allow(missing_docs)]
        proxiableUUID(proxiableUUIDCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        resolver(resolverCall),
        #[allow(missing_docs)]
        transferOwnership(transferOwnershipCall),
        #[allow(missing_docs)]
        unpause(unpauseCall),
        #[allow(missing_docs)]
        upgradeTo(upgradeToCall),
        #[allow(missing_docs)]
        upgradeToAndCall(upgradeToAndCallCall),
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
            [4u8, 243u8, 188u8, 236u8],
            [15u8, 67u8, 155u8, 217u8],
            [18u8, 98u8, 46u8, 91u8],
            [38u8, 12u8, 83u8, 68u8],
            [48u8, 117u8, 219u8, 86u8],
            [52u8, 205u8, 247u8, 141u8],
            [54u8, 60u8, 196u8, 39u8],
            [54u8, 89u8, 207u8, 230u8],
            [60u8, 122u8, 169u8, 17u8],
            [63u8, 75u8, 168u8, 58u8],
            [79u8, 30u8, 242u8, 134u8],
            [82u8, 209u8, 144u8, 45u8],
            [92u8, 151u8, 90u8, 187u8],
            [113u8, 80u8, 24u8, 166u8],
            [121u8, 186u8, 80u8, 151u8],
            [132u8, 86u8, 203u8, 89u8],
            [138u8, 191u8, 96u8, 119u8],
            [141u8, 165u8, 203u8, 91u8],
            [149u8, 90u8, 114u8, 68u8],
            [158u8, 229u8, 18u8, 242u8],
            [163u8, 126u8, 165u8, 21u8],
            [170u8, 222u8, 55u8, 91u8],
            [179u8, 213u8, 228u8, 95u8],
            [196u8, 110u8, 58u8, 102u8],
            [207u8, 26u8, 15u8, 34u8],
            [212u8, 65u8, 66u8, 33u8],
            [227u8, 12u8, 57u8, 120u8],
            [242u8, 253u8, 227u8, 139u8],
            [249u8, 64u8, 227u8, 133u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for AnchorCalls {
        const NAME: &'static str = "AnchorCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 29usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ANCHOR_GAS_LIMIT(_) => {
                    <ANCHOR_GAS_LIMITCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::GOLDEN_TOUCH_ADDRESS(_) => {
                    <GOLDEN_TOUCH_ADDRESSCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::anchorV4(_) => <anchorV4Call as alloy_sol_types::SolCall>::SELECTOR,
                Self::blockHashes(_) => {
                    <blockHashesCall as alloy_sol_types::SolCall>::SELECTOR
                }
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
                Self::getPreconfMetadata(_) => {
                    <getPreconfMetadataCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getProposalState(_) => {
                    <getProposalStateCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::r#impl(_) => <implCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::inNonReentrant(_) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::l1ChainId(_) => {
                    <l1ChainIdCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::livenessBond(_) => {
                    <livenessBondCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pause(_) => <pauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::paused(_) => <pausedCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::provabilityBond(_) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proxiableUUID(_) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::resolver(_) => <resolverCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::transferOwnership(_) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::unpause(_) => <unpauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::upgradeTo(_) => {
                    <upgradeToCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::upgradeToAndCall(_) => {
                    <upgradeToAndCallCall as alloy_sol_types::SolCall>::SELECTOR
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
                    fn resolver(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::resolver)
                    }
                    resolver
                },
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
                    fn getPreconfMetadata(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getPreconfMetadataCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::getPreconfMetadata)
                    }
                    getPreconfMetadata
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn blockHashes(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <blockHashesCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::blockHashes)
                    }
                    blockHashes
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
                    fn upgradeTo(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn anchorV4(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <anchorV4Call as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::anchorV4)
                    }
                    anchorV4
                },
                {
                    fn unpause(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn paused(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::paused)
                    }
                    paused
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
                    fn pause(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(AnchorCalls::r#impl)
                    }
                    r#impl
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
                    fn resolver(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::resolver)
                    }
                    resolver
                },
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
                    fn getPreconfMetadata(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <getPreconfMetadataCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::getPreconfMetadata)
                    }
                    getPreconfMetadata
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn blockHashes(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <blockHashesCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::blockHashes)
                    }
                    blockHashes
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
                    fn upgradeTo(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::upgradeTo)
                    }
                    upgradeTo
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
                    fn unpause(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn paused(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::paused)
                    }
                    paused
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
                    fn pause(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(data: &[u8]) -> alloy_sol_types::Result<AnchorCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorCalls::r#impl)
                    }
                    r#impl
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
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::anchorV4(inner) => {
                    <anchorV4Call as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::blockHashes(inner) => {
                    <blockHashesCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
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
                Self::getPreconfMetadata(inner) => {
                    <getPreconfMetadataCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getProposalState(inner) => {
                    <getProposalStateCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::provabilityBond(inner) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::blockHashes(inner) => {
                    <blockHashesCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::getPreconfMetadata(inner) => {
                    <getPreconfMetadataCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::r#impl(inner) => {
                    <implCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::inNonReentrant(inner) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::provabilityBond(inner) => {
                    <provabilityBondCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::transferOwnership(inner) => {
                    <transferOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
        ACCESS_DENIED(ACCESS_DENIED),
        #[allow(missing_docs)]
        AncestorsHashMismatch(AncestorsHashMismatch),
        #[allow(missing_docs)]
        BondInstructionsHashMismatch(BondInstructionsHashMismatch),
        #[allow(missing_docs)]
        ETH_TRANSFER_FAILED(ETH_TRANSFER_FAILED),
        #[allow(missing_docs)]
        FUNC_NOT_IMPLEMENTED(FUNC_NOT_IMPLEMENTED),
        #[allow(missing_docs)]
        INVALID_PAUSE_STATUS(INVALID_PAUSE_STATUS),
        #[allow(missing_docs)]
        InvalidAddress(InvalidAddress),
        #[allow(missing_docs)]
        InvalidAnchorBlockNumber(InvalidAnchorBlockNumber),
        #[allow(missing_docs)]
        InvalidBlockIndex(InvalidBlockIndex),
        #[allow(missing_docs)]
        InvalidBlockNumber(InvalidBlockNumber),
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
        REENTRANT_CALL(REENTRANT_CALL),
        #[allow(missing_docs)]
        ZERO_ADDRESS(ZERO_ADDRESS),
        #[allow(missing_docs)]
        ZERO_VALUE(ZERO_VALUE),
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
            [24u8, 87u8, 31u8, 30u8],
            [33u8, 160u8, 13u8, 103u8],
            [34u8, 147u8, 41u8, 199u8],
            [73u8, 100u8, 95u8, 253u8],
            [74u8, 57u8, 50u8, 156u8],
            [78u8, 71u8, 132u8, 108u8],
            [83u8, 139u8, 164u8, 249u8],
            [89u8, 180u8, 82u8, 239u8],
            [136u8, 196u8, 112u8, 11u8],
            [149u8, 56u8, 62u8, 161u8],
            [152u8, 206u8, 38u8, 154u8],
            [161u8, 108u8, 75u8, 168u8],
            [173u8, 16u8, 54u8, 31u8],
            [186u8, 230u8, 226u8, 169u8],
            [202u8, 34u8, 239u8, 118u8],
            [202u8, 64u8, 102u8, 123u8],
            [221u8, 181u8, 222u8, 94u8],
            [223u8, 198u8, 13u8, 133u8],
            [224u8, 165u8, 170u8, 129u8],
            [230u8, 196u8, 36u8, 123u8],
            [236u8, 115u8, 41u8, 89u8],
            [241u8, 203u8, 2u8, 53u8],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolInterface for AnchorErrors {
        const NAME: &'static str = "AnchorErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 22usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ACCESS_DENIED(_) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::AncestorsHashMismatch(_) => {
                    <AncestorsHashMismatch as alloy_sol_types::SolError>::SELECTOR
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
                Self::InvalidAddress(_) => {
                    <InvalidAddress as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidAnchorBlockNumber(_) => {
                    <InvalidAnchorBlockNumber as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidBlockIndex(_) => {
                    <InvalidBlockIndex as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidBlockNumber(_) => {
                    <InvalidBlockNumber as alloy_sol_types::SolError>::SELECTOR
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
                Self::REENTRANT_CALL(_) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::SELECTOR
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
            static DECODE_SHIMS: &[fn(&[u8]) -> alloy_sol_types::Result<AnchorErrors>] = &[
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
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
                    fn InvalidBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidBlockNumber as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::InvalidBlockNumber)
                    }
                    InvalidBlockNumber
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(AnchorErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
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
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
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
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
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
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(AnchorErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
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
                    fn ZERO_VALUE(data: &[u8]) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(AnchorErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
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
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
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
                    fn InvalidBlockNumber(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <InvalidBlockNumber as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::InvalidBlockNumber)
                    }
                    InvalidBlockNumber
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
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
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
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
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
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
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<AnchorErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
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
                    fn ZERO_VALUE(data: &[u8]) -> alloy_sol_types::Result<AnchorErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(AnchorErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
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
                Self::ACCESS_DENIED(inner) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
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
                Self::InvalidBlockNumber(inner) => {
                    <InvalidBlockNumber as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::InvalidBlockNumber(inner) => {
                    <InvalidBlockNumber as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encode_raw(
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
    ///Container for all the [`Anchor`](self) events.
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum AnchorEvents {
        #[allow(missing_docs)]
        AdminChanged(AdminChanged),
        #[allow(missing_docs)]
        Anchored(Anchored),
        #[allow(missing_docs)]
        BeaconUpgraded(BeaconUpgraded),
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
    impl AnchorEvents {
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
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ],
            [
                209u8, 193u8, 159u8, 188u8, 212u8, 85u8, 26u8, 94u8, 223u8, 182u8, 109u8,
                67u8, 210u8, 227u8, 55u8, 192u8, 72u8, 55u8, 175u8, 218u8, 52u8, 130u8,
                180u8, 43u8, 223u8, 86u8, 154u8, 143u8, 204u8, 218u8, 229u8, 251u8,
            ],
            [
                232u8, 13u8, 85u8, 94u8, 182u8, 144u8, 111u8, 105u8, 7u8, 182u8, 142u8,
                110u8, 173u8, 55u8, 209u8, 8u8, 157u8, 31u8, 187u8, 126u8, 35u8, 166u8,
                143u8, 51u8, 53u8, 221u8, 4u8, 248u8, 174u8, 243u8, 225u8, 231u8,
            ],
        ];
    }
    #[automatically_derived]
    impl alloy_sol_types::SolEventInterface for AnchorEvents {
        const NAME: &'static str = "AnchorEvents";
        const COUNT: usize = 10usize;
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
    impl alloy_sol_types::private::IntoLogData for AnchorEvents {
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
        ///Creates a new call builder for the [`blockHashes`] function.
        pub fn blockHashes(
            &self,
            blockNumber: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, blockHashesCall, N> {
            self.call_builder(&blockHashesCall { blockNumber })
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
        ///Creates a new call builder for the [`getPreconfMetadata`] function.
        pub fn getPreconfMetadata(
            &self,
            _blockNumber: alloy::sol_types::private::primitives::aliases::U256,
        ) -> alloy_contract::SolCallBuilder<&P, getPreconfMetadataCall, N> {
            self.call_builder(
                &getPreconfMetadataCall {
                    _blockNumber,
                },
            )
        }
        ///Creates a new call builder for the [`getProposalState`] function.
        pub fn getProposalState(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, getProposalStateCall, N> {
            self.call_builder(&getProposalStateCall)
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
        ///Creates a new call builder for the [`provabilityBond`] function.
        pub fn provabilityBond(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, provabilityBondCall, N> {
            self.call_builder(&provabilityBondCall)
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
