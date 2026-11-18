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
        #[allow(dead_code)]
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
        __provider: P,
    ) -> ICheckpointStoreInstance<P, N> {
        ICheckpointStoreInstance::<P, N>::new(address, __provider)
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
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > ICheckpointStoreInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`ICheckpointStore`](self) contract instance.

See the [wrapper's documentation](`ICheckpointStoreInstance`) for more details.*/
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

interface SignalService {
    error ACCESS_DENIED();
    error ContentLengthMismatch();
    error EmptyItem();
    error FUNC_NOT_IMPLEMENTED();
    error INVALID_PAUSE_STATUS();
    error InvalidDataRemainder();
    error InvalidHeader();
    error LTP_INVALID_ACCOUNT_PROOF();
    error LTP_INVALID_INCLUSION_PROOF();
    error REENTRANT_CALL();
    error SS_CHECKPOINTS_CLOSED();
    error SS_CHECKPOINT_NOT_FOUND();
    error SS_EMPTY_PROOF();
    error SS_INVALID_BLOCK_ID();
    error SS_INVALID_CHECKPOINT();
    error SS_INVALID_PROOF_LENGTH();
    error SS_SIGNAL_NOT_RECEIVED();
    error SS_STATE_ROOT_NOT_FOUND();
    error SS_UNAUTHORIZED();
    error UnexpectedList();
    error UnexpectedString();
    error ZERO_ADDRESS();
    error ZERO_VALUE();

    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);
    event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
    event Initialized(uint8 version);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    constructor(address authorizedSyncer, address remoteSignalService, address _pauser, uint64 _beaconRootsFrom);

    function BEACON_ROOTS() external view returns (address);
    function VERSION() external view returns (uint256);
    function acceptOwnership() external;
    function beaconRootsFrom() external view returns (uint64);
    function getCheckpoint(uint48 _blockNumber) external view returns (ICheckpointStore.Checkpoint memory checkpoint);
    function getSignalSlot(uint64 _chainId, address _app, bytes32 _signal) external pure returns (bytes32);
    function impl() external view returns (address);
    function inNonReentrant() external view returns (bool);
    function init(address _owner) external;
    function isSignalSent(address _app, bytes32 _signal) external view returns (bool);
    function isSignalSent(bytes32 _signalSlot) external view returns (bool);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pauser() external view returns (address);
    function pendingOwner() external view returns (address);
    function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes memory _proof) external returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function resolver() external view returns (address);
    function saveCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external;
    function sendSignal(bytes32 _signal) external returns (bytes32);
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes memory _proof) external view;
}
```

...which was generated by the following JSON ABI:
```json
[
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "authorizedSyncer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "remoteSignalService",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_pauser",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_beaconRootsFrom",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "BEACON_ROOTS",
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
    "name": "VERSION",
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
    "name": "beaconRootsFrom",
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
    "name": "getCheckpoint",
    "inputs": [
      {
        "name": "_blockNumber",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSignalSlot",
    "inputs": [
      {
        "name": "_chainId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_app",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signal",
        "type": "bytes32",
        "internalType": "bytes32"
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
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isSignalSent",
    "inputs": [
      {
        "name": "_app",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signal",
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
    "name": "isSignalSent",
    "inputs": [
      {
        "name": "_signalSlot",
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
    "name": "pauser",
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
    "name": "proveSignalReceived",
    "inputs": [
      {
        "name": "_chainId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_app",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signal",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_proof",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
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
    "name": "saveCheckpoint",
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
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "sendSignal",
    "inputs": [
      {
        "name": "_signal",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
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
    "name": "verifySignalReceived",
    "inputs": [
      {
        "name": "_chainId",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "_app",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signal",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_proof",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
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
    "name": "CheckpointSaved",
    "inputs": [
      {
        "name": "blockNumber",
        "type": "uint48",
        "indexed": true,
        "internalType": "uint48"
      },
      {
        "name": "blockHash",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "stateRoot",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
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
    "name": "SignalSent",
    "inputs": [
      {
        "name": "app",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "signal",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "slot",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "value",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
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
    "name": "ContentLengthMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EmptyItem",
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
    "name": "InvalidDataRemainder",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidHeader",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LTP_INVALID_ACCOUNT_PROOF",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LTP_INVALID_INCLUSION_PROOF",
    "inputs": []
  },
  {
    "type": "error",
    "name": "REENTRANT_CALL",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_CHECKPOINTS_CLOSED",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_CHECKPOINT_NOT_FOUND",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_EMPTY_PROOF",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_INVALID_BLOCK_ID",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_INVALID_CHECKPOINT",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_INVALID_PROOF_LENGTH",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_SIGNAL_NOT_RECEIVED",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_STATE_ROOT_NOT_FOUND",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SS_UNAUTHORIZED",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnexpectedList",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnexpectedString",
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
pub mod SignalService {
    use super::*;
    use alloy::sol_types as alloy_sol_types;
    /// The creation / init bytecode of the contract.
    ///
    /// ```text
    ///0x61014060405230608052348015610014575f5ffd5b50604051613aa0380380613aa08339810160408190526100339161018d565b61003b6100b6565b6001600160a01b0384166100625760405163538ba4f960e01b815260040160405180910390fd5b6001600160a01b0383166100895760405163538ba4f960e01b815260040160405180910390fd5b6001600160a01b0393841660c05291831660e052909116610100526001600160401b0316610120526101ec565b5f54610100900460ff16156101215760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b5f5460ff90811614610170575f805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b80516001600160a01b0381168114610188575f5ffd5b919050565b5f5f5f5f608085870312156101a0575f5ffd5b6101a985610172565b93506101b760208601610172565b92506101c560408601610172565b60608601519092506001600160401b03811681146101e1575f5ffd5b939692955090935050565b60805160a05160c05160e051610100516101205161383561026b5f395f818161045a015281816113e301528181611415015261160801525f81816104a50152610fee01525f61139c01525f610b5501525f6101a701525f81816106ae015281816106ee015281816107d001528181610810015261088701526138355ff3fe608060405260043610610195575f3560e01c80638026b921116100e75780639bce53b511610087578063ce9d082011610062578063ce9d0820146104e6578063e30c397814610505578063f2fde38b14610522578063ffa1ad7414610541575f5ffd5b80639bce53b5146104495780639fd0506d14610494578063c9a0b8c8146104c7575f5ffd5b80638da5cb5b116100c25780638da5cb5b146103cf5780638e899f80146103ec578063910af6ed1461040b57806391f3f74b1461042a575f5ffd5b80638026b9211461035e5780638456cb59146103a75780638abf6077146103bb575f5ffd5b80634f1ef286116101525780635c975abb1161012d5780635c975abb146102f757806366ca2bc014610317578063715018a61461033657806379ba50971461034a575f5ffd5b80634f1ef2861461029c57806352d1902d146102af57806356d7e8fd146102d1575f5ffd5b806304f3bcec1461019957806319ab453c146101e45780633075db561461020557806332676bc61461024a5780633659cfe6146102695780633f4ba83a14610288575b5f5ffd5b3480156101a4575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b3480156101ef575f5ffd5b506102036101fe366004612f84565b610555565b005b348015610210575f5ffd5b5060027fa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b5c60ff16145b60405190151581526020016101db565b348015610255575f5ffd5b5061023a610264366004612f9d565b61068e565b348015610274575f5ffd5b50610203610283366004612f84565b6106a4565b348015610293575f5ffd5b5061020361076b565b6102036102aa36600461309c565b6107c6565b3480156102ba575f5ffd5b506102c361087b565b6040519081526020016101db565b3480156102dc575f5ffd5b506101c7720f3df6d732807ef1319fb7b8bb8522d0beac0281565b348015610302575f5ffd5b5061023a60c954610100900460ff1660021490565b348015610322575f5ffd5b506102c36103313660046130e6565b61092c565b348015610341575f5ffd5b50610203610938565b348015610355575f5ffd5b50610203610949565b348015610369575f5ffd5b5061037d6103783660046130fd565b6109c0565b60408051825165ffffffffffff1681526020808401519082015291810151908201526060016101db565b3480156103b2575f5ffd5b506102036109f2565b3480156103c6575f5ffd5b506101c7610a47565b3480156103da575f5ffd5b506033546001600160a01b03166101c7565b3480156103f7575f5ffd5b5061023a6104063660046130e6565b610a55565b348015610416575f5ffd5b506102c3610425366004613138565b610a66565b348015610435575f5ffd5b506102c36104443660046131cb565b610adf565b348015610454575f5ffd5b5061047c7f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b0390911681526020016101db565b34801561049f575f5ffd5b506101c77f000000000000000000000000000000000000000000000000000000000000000081565b3480156104d2575f5ffd5b506102036104e1366004613205565b610b4a565b3480156104f1575f5ffd5b50610203610500366004613138565b610cda565b348015610510575f5ffd5b506065546001600160a01b03166101c7565b34801561052d575f5ffd5b5061020361053c366004612f84565b610cf6565b34801561054c575f5ffd5b506102c3600181565b5f54610100900460ff161580801561057357505f54600160ff909116105b8061058c5750303b15801561058c57505f5460ff166001145b6105f45760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b60648201526084015b60405180910390fd5b5f805460ff191660011790558015610615575f805461ff0019166101001790555b6001600160a01b03821661063c5760405163538ba4f960e01b815260040160405180910390fd5b61064582610d67565b801561068a575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b5050565b5f6106998383610dc5565b151590505b92915050565b6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001630036106ec5760405162461bcd60e51b81526004016105eb9061321e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031661071e610e29565b6001600160a01b0316146107445760405162461bcd60e51b81526004016105eb9061326a565b61074d81610e44565b604080515f8082526020820190925261076891839190610e4c565b50565b610773610fbb565b61078760c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a16107c4335f610fec565b565b6001600160a01b037f000000000000000000000000000000000000000000000000000000000000000016300361080e5760405162461bcd60e51b81526004016105eb9061321e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610840610e29565b6001600160a01b0316146108665760405162461bcd60e51b81526004016105eb9061326a565b61086f82610e44565b61068a82826001610e4c565b5f306001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461091a5760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c000000000000000060648201526084016105eb565b505f5160206137b95f395f51905f5290565b5f61069e338384611016565b6109406110e3565b6107c45f61113d565b60655433906001600160a01b031681146109b75760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b60648201526084016105eb565b6107688161113d565b6109e960405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b61069e82611156565b6109fa611200565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a16107c4336001610fec565b5f610a50610e29565b905090565b5f610a5e825490565b151592915050565b5f610a6f611200565b610a7c8686868686611232565b60015f81815260fd6020527f6443157f7701a627e53184b74fce0d403f4bf9bc1aaa0bc17c9ee17e10ec8b8f90610ab4898989610adf565b815260208101919091526040015f908120805460ff1916921515929092179091559695505050505050565b6040516514d251d3905360d21b60208201526001600160c01b031960c085901b1660268201526bffffffffffffffffffffffff19606084901b16602e820152604281018290525f906062016040516020818303038152906040528051906020012090505b9392505050565b336001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610b9357604051631f67751f60e01b815260040160405180910390fd5b610b9b6113d8565b610bb85760405163cadcfbdb60e01b815260040160405180910390fd5b6040810135610bda576040516362d16b9d60e01b815260040160405180910390fd5b6020810135610bfc576040516362d16b9d60e01b815260040160405180910390fd5b604080518082018252602080840180358352928401358183015260015f90815260fe90915290917f457c8a48b4735f56b938837eb0a8a5f9c55f23c1a85767ce3b65c3e59d3d32b79190610c5090856130fd565b65ffffffffffff1681526020808201929092526040015f208251815591810151600190920191909155610c85908201826130fd565b65ffffffffffff167ff726c53cbb9e62552afc4a8f1bb1d01fa9272e526a7e3a69eba93b778b3f42a682602001358360400135604051610ccf929190918252602082015260400190565b60405180910390a250565b610ce2611200565b610cef8585858585611232565b5050505050565b610cfe6110e3565b606580546001600160a01b0383166001600160a01b03199091168117909155610d2f6033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b5f54610100900460ff16610d8d5760405162461bcd60e51b81526004016105eb906132b6565b610d9561143a565b610db36001600160a01b03821615610dad578161113d565b3361113d565b5060c9805461ff001916610100179055565b5f6001600160a01b038316610ded5760405163538ba4f960e01b815260040160405180910390fd5b81610e0b5760405163ec73295960e01b815260040160405180910390fd5b5f610e17468585610adf565b9050610e21815490565b949350505050565b5f5160206137b95f395f51905f52546001600160a01b031690565b6107686110e3565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff1615610e8457610e7f83611460565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa925050508015610ede575060408051601f3d908101601f19168201909252610edb91810190613301565b60015b610f415760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b60648201526084016105eb565b5f5160206137b95f395f51905f528114610faf5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b60648201526084016105eb565b50610e7f8383836114fb565b610fcf60c954610100900460ff1660021490565b6107c45760405163bae6e2a960e01b815260040160405180910390fd5b7f0000000000000000000000000000000000000000000000000000000000000000610e7f81611525565b5f6001600160a01b03841661103e5760405163538ba4f960e01b815260040160405180910390fd5b8261105c5760405163ec73295960e01b815260040160405180910390fd5b8161107a5760405163ec73295960e01b815260040160405180910390fd5b611085468585610adf565b828155604080516001600160a01b038716815260208101869052908101829052606081018490529091507f0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e9739060800160405180910390a19392505050565b6033546001600160a01b031633146107c45760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016105eb565b606580546001600160a01b031916905561076881611563565b61117f60405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b65ffffffffffff82165f9081527f457c8a48b4735f56b938837eb0a8a5f9c55f23c1a85767ce3b65c3e59d3d32b7602052604090208054806111d457604051633ca5d64760e21b815260040160405180910390fd5b6040805160608101825265ffffffffffff90951685526020850191909152600190910154908301525090565b61121460c954610100900460ff1660021490565b156107c45760405163bae6e2a960e01b815260040160405180910390fd5b6001600160a01b0384166112595760405163538ba4f960e01b815260040160405180910390fd5b826112775760405163ec73295960e01b815260040160405180910390fd5b5f611283868686610adf565b90505f8290036112e0575f8181527f6443157f7701a627e53184b74fce0d403f4bf9bc1aaa0bc17c9ee17e10ec8b8f602052604090205460ff166112da57604051632213945760e11b815260040160405180910390fd5b50610cef565b5f6112ed838501856133d5565b905080516001146113115760405163073c8b9760e31b815260040160405180910390fd5b5f815f815181106113245761132461351b565b602002602001015190508060800151515f1480611344575060a081015151155b1561136257604051630b92daef60e21b815260040160405180910390fd5b5f61137082602001516115b4565b905081604001518114611396576040516362d16b9d60e01b815260040160405180910390fd5b6113cc817f0000000000000000000000000000000000000000000000000000000000000000868a86608001518760a0015161174b565b50505050505050505050565b5f6001600160401b037f0000000000000000000000000000000000000000000000000000000000000000161580610a505750506001600160401b037f000000000000000000000000000000000000000000000000000000000000000016421090565b5f54610100900460ff166107c45760405162461bcd60e51b81526004016105eb906132b6565b6001600160a01b0381163b6114cd5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b60648201526084016105eb565b5f5160206137b95f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b61150483611858565b5f825111806115105750805b15610e7f5761151f8383611897565b50505050565b6033546001600160a01b03163314806115465750336001600160a01b038216145b610768576040516395383ea160e01b815260040160405180910390fd5b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f6115bd6113d8565b156116065765ffffffffffff6001600160401b03831611156115f2576040516378b5904b60e11b815260040160405180910390fd5b6115fb82611156565b604001519050611728565b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b0316826001600160401b03161015611659576040516378b5904b60e11b815260040160405180910390fd5b604080516001600160401b03841660208201525f918291720f3df6d732807ef1319fb7b8bb8522d0beac02910160408051601f19818403018152908290526116a091613546565b5f60405180830381855afa9150503d805f81146116d8576040519150601f19603f3d011682016040523d82523d5f602084013e6116dd565b606091505b50915091508115806116f157508051602014155b1561170f57604051635433b27d60e11b815260040160405180910390fd5b808060200190518101906117239190613301565b925050505b8061174657604051635433b27d60e11b815260040160405180910390fd5b919050565b5f82515f146117f3576040516bffffffffffffffffffffffff19606088901b1660208201525f9061178f90603401604051602081830303815290604052858a6118bc565b905080515f036117b257604051630414cd5b60e31b815260040160405180910390fd5b5f6117bc826118de565b90506117e1816002815181106117d4576117d461351b565b60200260200101516118f1565b6117ea90613551565b925050506117f6565b50855b5f61182d8660405160200161180d91815260200190565b60408051601f1981840301815291905261182687611970565b8585611983565b90508061184d57604051638d9a4db360e01b815260040160405180910390fd5b509695505050505050565b61186181611460565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060610b4383836040518060600160405280602781526020016137d9602791396119a6565b60605f6118c885611a10565b90506118d5818585611a42565b95945050505050565b606061069e6118ec836122b0565b612302565b60605f5f5f6118ff85612480565b919450925090505f81600181111561191957611919613577565b14611937576040516307fe6cb960e21b815260040160405180910390fd5b611941828461359f565b85511461196157604051630b8aa6f760e31b815260040160405180910390fd5b6118d585602001518484612763565b606061069e61197e836127f3565b61290f565b5f5f61198e86611a10565b905061199c81868686612962565b9695505050505050565b60605f5f856001600160a01b0316856040516119c29190613546565b5f60405180830381855af49150503d805f81146119fa576040519150601f19603f3d011682016040523d82523d5f602084013e6119ff565b606091505b509150915061199c86838387612988565b60608180519060200120604051602001611a2c91815260200190565b6040516020818303038152906040529050919050565b60605f845111611a8c5760405162461bcd60e51b81526020600482015260156024820152744d65726b6c65547269653a20656d707479206b657960581b60448201526064016105eb565b5f611a9684612a00565b90505f611aa286612aea565b90505f84604051602001611ab891815260200190565b60408051601f1981840301815291905290505f805b8451811015612259575f858281518110611ae957611ae961351b565b602002602001015190508451831115611b5b5760405162461bcd60e51b815260206004820152602e60248201527f4d65726b6c65547269653a206b657920696e646578206578636565647320746f60448201526d0e8c2d840d6caf240d8cadccee8d60931b60648201526084016105eb565b825f03611bf95780518051602091820120604051611ba892611b8292910190815260200190565b604051602081830303815290604052858051602091820120825192909101919091201490565b611bf45760405162461bcd60e51b815260206004820152601d60248201527f4d65726b6c65547269653a20696e76616c696420726f6f74206861736800000060448201526064016105eb565b611cef565b805151602011611c7f5780518051602091820120604051611c2392611b8292910190815260200190565b611bf45760405162461bcd60e51b815260206004820152602760248201527f4d65726b6c65547269653a20696e76616c6964206c6172676520696e7465726e6044820152660c2d840d0c2e6d60cb1b60648201526084016105eb565b805184516020808701919091208251919092012014611cef5760405162461bcd60e51b815260206004820152602660248201527f4d65726b6c65547269653a20696e76616c696420696e7465726e616c206e6f646044820152650ca40d0c2e6d60d31b60648201526084016105eb565b611cfb6010600161359f565b81602001515103611e935784518303611e2d57611d2881602001516010815181106117d4576117d461351b565b96505f875111611da05760405162461bcd60e51b815260206004820152603b60248201527f4d65726b6c65547269653a2076616c7565206c656e677468206d75737420626560448201527f2067726561746572207468616e207a65726f20286272616e636829000000000060648201526084016105eb565b60018651611dae91906135b2565b8214611e225760405162461bcd60e51b815260206004820152603a60248201527f4d65726b6c65547269653a2076616c7565206e6f6465206d757374206265206c60448201527f617374206e6f646520696e2070726f6f6620286272616e63682900000000000060648201526084016105eb565b505050505050610b43565b5f858481518110611e4057611e4061351b565b602001015160f81c60f81b60f81c90505f82602001518260ff1681518110611e6a57611e6a61351b565b60200260200101519050611e7d81612b4b565b9550611e8a60018661359f565b94505050612250565b6002816020015151036121f7575f611eaa82612b6f565b90505f815f81518110611ebf57611ebf61351b565b016020015160f81c90505f611ed56002836135d9565b611ee09060026135fa565b90505f611ef0848360ff16612b92565b90505f611efd8a89612b92565b90505f611f0a8383612bc7565b905080835114611f825760405162461bcd60e51b815260206004820152603a60248201527f4d65726b6c65547269653a20706174682072656d61696e646572206d7573742060448201527f736861726520616c6c206e6962626c65732077697468206b657900000000000060648201526084016105eb565b60ff851660021480611f97575060ff85166003145b1561213757808251146120125760405162461bcd60e51b815260206004820152603d60248201527f4d65726b6c65547269653a206b65792072656d61696e646572206d757374206260448201527f65206964656e746963616c20746f20706174682072656d61696e64657200000060648201526084016105eb565b61202c87602001516001815181106117d4576117d461351b565b9c505f8d51116120a45760405162461bcd60e51b815260206004820152603960248201527f4d65726b6c65547269653a2076616c7565206c656e677468206d75737420626560448201527f2067726561746572207468616e207a65726f20286c656166290000000000000060648201526084016105eb565b60018c516120b291906135b2565b88146121265760405162461bcd60e51b815260206004820152603860248201527f4d65726b6c65547269653a2076616c7565206e6f6465206d757374206265206c60448201527f617374206e6f646520696e2070726f6f6620286c65616629000000000000000060648201526084016105eb565b505050505050505050505050610b43565b60ff8516158061214a575060ff85166001145b156121895761217687602001516001815181106121695761216961351b565b6020026020010151612b4b565b9950612182818a61359f565b98506121ec565b60405162461bcd60e51b815260206004820152603260248201527f4d65726b6c65547269653a2072656365697665642061206e6f64652077697468604482015271040c2dc40eadcd6dcdeeedc40e0e4caccd2f60731b60648201526084016105eb565b505050505050612250565b60405162461bcd60e51b815260206004820152602860248201527f4d65726b6c65547269653a20726563656976656420616e20756e706172736561604482015267626c65206e6f646560c01b60648201526084016105eb565b50600101611acd565b5060405162461bcd60e51b815260206004820152602560248201527f4d65726b6c65547269653a2072616e206f7574206f662070726f6f6620656c656044820152646d656e747360d81b60648201526084016105eb565b604080518082019091525f808252602082015281515f036122e457604051635ab458fb60e01b815260040160405180910390fd5b50604080518082019091528151815260209182019181019190915290565b60605f5f5f61231085612480565b91945092509050600181600181111561232b5761232b613577565b14612349576040516325ce355f60e11b815260040160405180910390fd5b8451612355838561359f565b1461237357604051630b8aa6f760e31b815260040160405180910390fd5b604080516020808252610420820190925290816020015b604080518082019091525f808252602082015281526020019060019003908161238a5790505093505f835b8651811015612474575f5f6123f96040518060400160405280858c5f01516123dd91906135b2565b8152602001858c602001516123f2919061359f565b9052612480565b509150915060405180604001604052808383612415919061359f565b8152602001848b6020015161242a919061359f565b81525088858151811061243f5761243f61351b565b602090810291909101015261245560018561359f565b9350612461818361359f565b61246b908461359f565b925050506123b5565b50845250919392505050565b5f5f5f835f01515f036124a657604051635ab458fb60e01b815260040160405180910390fd5b602084015180515f1a607f81116124c8575f60015f945094509450505061275c565b60b7811161255d575f6124dc6080836135b2565b905080875f015111612501576040516366c9448560e01b815260040160405180910390fd5b6001838101516001600160f81b031916908214801561252d5750600160ff1b6001600160f81b03198216105b1561254b5760405163babb01dd60e01b815260040160405180910390fd5b506001955093505f925061275c915050565b60bf811161263b575f61257160b7836135b2565b905080875f015111612596576040516366c9448560e01b815260040160405180910390fd5b60018301516001600160f81b0319165f8190036125c65760405163babb01dd60e01b815260040160405180910390fd5b600184015160088302610100031c603781116125f55760405163babb01dd60e01b815260040160405180910390fd5b6125ff818461359f565b89511161261f576040516366c9448560e01b815260040160405180910390fd5b61262a83600161359f565b975095505f945061275c9350505050565b60f78111612685575f61264f60c0836135b2565b905080875f015111612674576040516366c9448560e01b815260040160405180910390fd5b60019550935084925061275c915050565b5f61269160f7836135b2565b905080875f0151116126b6576040516366c9448560e01b815260040160405180910390fd5b60018301516001600160f81b0319165f8190036126e65760405163babb01dd60e01b815260040160405180910390fd5b600184015160088302610100031c603781116127155760405163babb01dd60e01b815260040160405180910390fd5b61271f818461359f565b89511161273f576040516366c9448560e01b815260040160405180910390fd5b61274a83600161359f565b975095506001945061275c9350505050565b9193909250565b6060816001600160401b0381111561277d5761277d612fc5565b6040519080825280601f01601f1916602001820160405280156127a7576020820181803683370190505b5090508115610b43575f6127bb848661359f565b9050602082015f5b848110156127db5782810151828201526020016127c3565b848111156127e9575f858301525b5050509392505050565b60605f8260405160200161280991815260200190565b60408051601f1981840301815291905290505f5b6020811015612855578181815181106128385761283861351b565b01602001516001600160f81b0319165f036128555760010161281d565b6128608160206135b2565b6001600160401b0381111561287757612877612fc5565b6040519080825280601f01601f1916602001820160405280156128a1576020820181803683370190505b5092505f5b83518110156129075782826128ba81613613565b9350815181106128cc576128cc61351b565b602001015160f81c60f81b8482815181106128e9576128e961351b565b60200101906001600160f81b03191690815f1a9053506001016128a6565b505050919050565b60608151600114801561293b57506080825f815181106129315761293161351b565b016020015160f81c105b15612944575090565b61295082516080612c4a565b82604051602001611a2c92919061362b565b5f6118d584612972878686611a42565b8051602091820120825192909101919091201490565b606083156129f65782515f036129ef576001600160a01b0385163b6129ef5760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e747261637400000060448201526064016105eb565b5081610e21565b610e218383612def565b8051606090806001600160401b03811115612a1d57612a1d612fc5565b604051908082528060200260200182016040528015612a6257816020015b6040805180820190915260608082526020820152815260200190600190039081612a3b5790505b5091505f5b81811015612ae3576040518060400160405280858381518110612a8c57612a8c61351b565b60200260200101518152602001612abb868481518110612aae57612aae61351b565b60200260200101516118de565b815250838281518110612ad057612ad061351b565b6020908102919091010152600101612a67565b5050919050565b606080604051905082518060011b603f8101601f191683016040528083525060208401602083015f5b83811015612b40578060011b8201818401515f1a8060041c8253600f811660018301535050600101612b13565b509295945050505050565b60606020825f015110612b6657612b61826118f1565b61069e565b61069e82612e19565b606061069e612b8d83602001515f815181106117d4576117d461351b565b612aea565b606082518210612bb0575060408051602081019091525f815261069e565b610b438383848651612bc291906135b2565b612e2d565b5f5f8251845110612bd9578251612bdc565b83515b90505b8082108015612c335750828281518110612bfb57612bfb61351b565b602001015160f81c60f81b6001600160f81b031916848381518110612c2257612c2261351b565b01602001516001600160f81b031916145b15612c4357816001019150612bdf565b5092915050565b60606038831015612cae5760408051600180825281830190925290602082018180368337019050509050612c7e828461363f565b60f81b815f81518110612c9357612c9361351b565b60200101906001600160f81b03191690815f1a90535061069e565b5f60015b612cbc8186613658565b15612ce25781612ccb81613613565b9250612cdb90506101008261366b565b9050612cb2565b612ced82600161359f565b6001600160401b03811115612d0457612d04612fc5565b6040519080825280601f01601f191660200182016040528015612d2e576020820181803683370190505b509250612d3b848361363f565b612d4690603761363f565b60f81b835f81518110612d5b57612d5b61351b565b60200101906001600160f81b03191690815f1a905350600190505b818111612de757610100612d8a82846135b2565b612d9690610100613765565b612da09087613658565b612daa9190613770565b60f81b838281518110612dbf57612dbf61351b565b60200101906001600160f81b03191690815f1a90535080612ddf81613613565b915050612d76565b505092915050565b815115612dff5781518083602001fd5b8060405162461bcd60e51b81526004016105eb9190613783565b606061069e82602001515f845f0151612763565b60608182601f011015612e735760405162461bcd60e51b815260206004820152600e60248201526d736c6963655f6f766572666c6f7760901b60448201526064016105eb565b828284011015612eb65760405162461bcd60e51b815260206004820152600e60248201526d736c6963655f6f766572666c6f7760901b60448201526064016105eb565b81830184511015612efd5760405162461bcd60e51b8152602060048201526011602482015270736c6963655f6f75744f66426f756e647360781b60448201526064016105eb565b606082158015612f1b5760405191505f825260208201604052612f65565b6040519150601f8416801560200281840101858101878315602002848b0101015b81831015612f54578051835260209283019201612f3c565b5050858452601f01601f1916604052505b50949350505050565b80356001600160a01b0381168114611746575f5ffd5b5f60208284031215612f94575f5ffd5b610b4382612f6e565b5f5f60408385031215612fae575f5ffd5b612fb783612f6e565b946020939093013593505050565b634e487b7160e01b5f52604160045260245ffd5b60405160c081016001600160401b0381118282101715612ffb57612ffb612fc5565b60405290565b604051601f8201601f191681016001600160401b038111828210171561302957613029612fc5565b604052919050565b5f82601f830112613040575f5ffd5b81356001600160401b0381111561305957613059612fc5565b61306c601f8201601f1916602001613001565b818152846020838601011115613080575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f604083850312156130ad575f5ffd5b6130b683612f6e565b915060208301356001600160401b038111156130d0575f5ffd5b6130dc85828601613031565b9150509250929050565b5f602082840312156130f6575f5ffd5b5035919050565b5f6020828403121561310d575f5ffd5b813565ffffffffffff81168114610b43575f5ffd5b80356001600160401b0381168114611746575f5ffd5b5f5f5f5f5f6080868803121561314c575f5ffd5b61315586613122565b945061316360208701612f6e565b93506040860135925060608601356001600160401b03811115613184575f5ffd5b8601601f81018813613194575f5ffd5b80356001600160401b038111156131a9575f5ffd5b8860208284010111156131ba575f5ffd5b959894975092955050506020019190565b5f5f5f606084860312156131dd575f5ffd5b6131e684613122565b92506131f460208501612f6e565b929592945050506040919091013590565b5f6060828403128015613216575f5ffd5b509092915050565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b5f60208284031215613311575f5ffd5b5051919050565b5f6001600160401b0382111561333057613330612fc5565b5060051b60200190565b803560048110611746575f5ffd5b5f82601f830112613357575f5ffd5b813561336a61336582613318565b613001565b8082825260208201915060208360051b86010192508583111561338b575f5ffd5b602085015b838110156133cb5780356001600160401b038111156133ad575f5ffd5b6133bc886020838a0101613031565b84525060209283019201613390565b5095945050505050565b5f602082840312156133e5575f5ffd5b81356001600160401b038111156133fa575f5ffd5b8201601f8101841361340a575f5ffd5b803561341861336582613318565b8082825260208201915060208360051b850101925086831115613439575f5ffd5b602084015b8381101561184d5780356001600160401b0381111561345b575f5ffd5b850160c0818a03601f19011215613470575f5ffd5b613478612fd9565b61348460208301613122565b815261349260408301613122565b6020820152606082013560408201526134ad6080830161333a565b606082015260a08201356001600160401b038111156134ca575f5ffd5b6134d98b602083860101613348565b60808301525060c08201356001600160401b038111156134f7575f5ffd5b6135068b602083860101613348565b60a0830152508452506020928301920161343e565b634e487b7160e01b5f52603260045260245ffd5b5f81518060208401855e5f93019283525090919050565b5f610b43828461352f565b80516020808301519190811015613571575f198160200360031b1b821691505b50919050565b634e487b7160e01b5f52602160045260245ffd5b634e487b7160e01b5f52601160045260245ffd5b8082018082111561069e5761069e61358b565b8181038181111561069e5761069e61358b565b634e487b7160e01b5f52601260045260245ffd5b5f60ff8316806135eb576135eb6135c5565b8060ff84160691505092915050565b60ff828116828216039081111561069e5761069e61358b565b5f600182016136245761362461358b565b5060010190565b5f610e21613639838661352f565b8461352f565b60ff818116838216019081111561069e5761069e61358b565b5f82613666576136666135c5565b500490565b808202811582820484141761069e5761069e61358b565b6001815b60018411156136bd578085048111156136a1576136a161358b565b60018416156136af57908102905b60019390931c928002613686565b935093915050565b5f826136d35750600161069e565b816136df57505f61069e565b81600181146136f557600281146136ff5761371b565b600191505061069e565b60ff8411156137105761371061358b565b50506001821b61069e565b5060208310610133831016604e8410600b841016171561373e575081810a61069e565b61374a5f198484613682565b805f190482111561375d5761375d61358b565b029392505050565b5f610b4383836136c5565b5f8261377e5761377e6135c5565b500690565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220ad5f0eb9ae284af51317b799a7dbd39b3efabbbff4df7cd4af3a48380762a45164736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"a\x01@`@R0`\x80R4\x80\x15a\0\x14W__\xFD[P`@Qa:\xA08\x03\x80a:\xA0\x839\x81\x01`@\x81\x90Ra\x003\x91a\x01\x8DV[a\0;a\0\xB6V[`\x01`\x01`\xA0\x1B\x03\x84\x16a\0bW`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x83\x16a\0\x89W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x93\x84\x16`\xC0R\x91\x83\x16`\xE0R\x90\x91\x16a\x01\0R`\x01`\x01`@\x1B\x03\x16a\x01 Ra\x01\xECV[_Ta\x01\0\x90\x04`\xFF\x16\x15a\x01!W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FInitializable: contract is initi`D\x82\x01Rfalizing`\xC8\x1B`d\x82\x01R`\x84\x01`@Q\x80\x91\x03\x90\xFD[_T`\xFF\x90\x81\x16\x14a\x01pW_\x80T`\xFF\x19\x16`\xFF\x90\x81\x17\x90\x91U`@Q\x90\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[V[\x80Q`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x01\x88W__\xFD[\x91\x90PV[____`\x80\x85\x87\x03\x12\x15a\x01\xA0W__\xFD[a\x01\xA9\x85a\x01rV[\x93Pa\x01\xB7` \x86\x01a\x01rV[\x92Pa\x01\xC5`@\x86\x01a\x01rV[``\x86\x01Q\x90\x92P`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x01\xE1W__\xFD[\x93\x96\x92\x95P\x90\x93PPV[`\x80Q`\xA0Q`\xC0Q`\xE0Qa\x01\0Qa\x01 Qa85a\x02k_9_\x81\x81a\x04Z\x01R\x81\x81a\x13\xE3\x01R\x81\x81a\x14\x15\x01Ra\x16\x08\x01R_\x81\x81a\x04\xA5\x01Ra\x0F\xEE\x01R_a\x13\x9C\x01R_a\x0BU\x01R_a\x01\xA7\x01R_\x81\x81a\x06\xAE\x01R\x81\x81a\x06\xEE\x01R\x81\x81a\x07\xD0\x01R\x81\x81a\x08\x10\x01Ra\x08\x87\x01Ra85_\xF3\xFE`\x80`@R`\x046\x10a\x01\x95W_5`\xE0\x1C\x80c\x80&\xB9!\x11a\0\xE7W\x80c\x9B\xCES\xB5\x11a\0\x87W\x80c\xCE\x9D\x08 \x11a\0bW\x80c\xCE\x9D\x08 \x14a\x04\xE6W\x80c\xE3\x0C9x\x14a\x05\x05W\x80c\xF2\xFD\xE3\x8B\x14a\x05\"W\x80c\xFF\xA1\xADt\x14a\x05AW__\xFD[\x80c\x9B\xCES\xB5\x14a\x04IW\x80c\x9F\xD0Pm\x14a\x04\x94W\x80c\xC9\xA0\xB8\xC8\x14a\x04\xC7W__\xFD[\x80c\x8D\xA5\xCB[\x11a\0\xC2W\x80c\x8D\xA5\xCB[\x14a\x03\xCFW\x80c\x8E\x89\x9F\x80\x14a\x03\xECW\x80c\x91\n\xF6\xED\x14a\x04\x0BW\x80c\x91\xF3\xF7K\x14a\x04*W__\xFD[\x80c\x80&\xB9!\x14a\x03^W\x80c\x84V\xCBY\x14a\x03\xA7W\x80c\x8A\xBF`w\x14a\x03\xBBW__\xFD[\x80cO\x1E\xF2\x86\x11a\x01RW\x80c\\\x97Z\xBB\x11a\x01-W\x80c\\\x97Z\xBB\x14a\x02\xF7W\x80cf\xCA+\xC0\x14a\x03\x17W\x80cqP\x18\xA6\x14a\x036W\x80cy\xBAP\x97\x14a\x03JW__\xFD[\x80cO\x1E\xF2\x86\x14a\x02\x9CW\x80cR\xD1\x90-\x14a\x02\xAFW\x80cV\xD7\xE8\xFD\x14a\x02\xD1W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x01\x99W\x80c\x19\xABE<\x14a\x01\xE4W\x80c0u\xDBV\x14a\x02\x05W\x80c2gk\xC6\x14a\x02JW\x80c6Y\xCF\xE6\x14a\x02iW\x80c?K\xA8:\x14a\x02\x88W[__\xFD[4\x80\x15a\x01\xA4W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x01\xEFW__\xFD[Pa\x02\x03a\x01\xFE6`\x04a/\x84V[a\x05UV[\0[4\x80\x15a\x02\x10W__\xFD[P`\x02\x7F\xA5\x05Or\x84S\xD3\xDB\xE9S\xBD\xC4>M\x0C\xB9~f.\xA3-yX\x19\x0F=\xC2\xDA1\xD9r\x1B\\`\xFF\x16\x14[`@Q\x90\x15\x15\x81R` \x01a\x01\xDBV[4\x80\x15a\x02UW__\xFD[Pa\x02:a\x02d6`\x04a/\x9DV[a\x06\x8EV[4\x80\x15a\x02tW__\xFD[Pa\x02\x03a\x02\x836`\x04a/\x84V[a\x06\xA4V[4\x80\x15a\x02\x93W__\xFD[Pa\x02\x03a\x07kV[a\x02\x03a\x02\xAA6`\x04a0\x9CV[a\x07\xC6V[4\x80\x15a\x02\xBAW__\xFD[Pa\x02\xC3a\x08{V[`@Q\x90\x81R` \x01a\x01\xDBV[4\x80\x15a\x02\xDCW__\xFD[Pa\x01\xC7r\x0F=\xF6\xD72\x80~\xF11\x9F\xB7\xB8\xBB\x85\"\xD0\xBE\xAC\x02\x81V[4\x80\x15a\x03\x02W__\xFD[Pa\x02:`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x03\"W__\xFD[Pa\x02\xC3a\x0316`\x04a0\xE6V[a\t,V[4\x80\x15a\x03AW__\xFD[Pa\x02\x03a\t8V[4\x80\x15a\x03UW__\xFD[Pa\x02\x03a\tIV[4\x80\x15a\x03iW__\xFD[Pa\x03}a\x03x6`\x04a0\xFDV[a\t\xC0V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x90\x82\x01R\x91\x81\x01Q\x90\x82\x01R``\x01a\x01\xDBV[4\x80\x15a\x03\xB2W__\xFD[Pa\x02\x03a\t\xF2V[4\x80\x15a\x03\xC6W__\xFD[Pa\x01\xC7a\nGV[4\x80\x15a\x03\xDAW__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xC7V[4\x80\x15a\x03\xF7W__\xFD[Pa\x02:a\x04\x066`\x04a0\xE6V[a\nUV[4\x80\x15a\x04\x16W__\xFD[Pa\x02\xC3a\x04%6`\x04a18V[a\nfV[4\x80\x15a\x045W__\xFD[Pa\x02\xC3a\x04D6`\x04a1\xCBV[a\n\xDFV[4\x80\x15a\x04TW__\xFD[Pa\x04|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x01\xDBV[4\x80\x15a\x04\x9FW__\xFD[Pa\x01\xC7\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\xD2W__\xFD[Pa\x02\x03a\x04\xE16`\x04a2\x05V[a\x0BJV[4\x80\x15a\x04\xF1W__\xFD[Pa\x02\x03a\x05\x006`\x04a18V[a\x0C\xDAV[4\x80\x15a\x05\x10W__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x01\xC7V[4\x80\x15a\x05-W__\xFD[Pa\x02\x03a\x05<6`\x04a/\x84V[a\x0C\xF6V[4\x80\x15a\x05LW__\xFD[Pa\x02\xC3`\x01\x81V[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x05sWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x05\x8CWP0;\x15\x80\x15a\x05\x8CWP_T`\xFF\x16`\x01\x14[a\x05\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x06\x15W_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[`\x01`\x01`\xA0\x1B\x03\x82\x16a\x06<W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x06E\x82a\rgV[\x80\x15a\x06\x8AW_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPV[_a\x06\x99\x83\x83a\r\xC5V[\x15\x15\x90P[\x92\x91PPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x06\xECW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\x1EV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x07\x1Ea\x0E)V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x07DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2jV[a\x07M\x81a\x0EDV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x07h\x91\x83\x91\x90a\x0ELV[PV[a\x07sa\x0F\xBBV[a\x07\x87`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x07\xC43_a\x0F\xECV[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x08\x0EW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\x1EV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x08@a\x0E)V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x08fW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2jV[a\x08o\x82a\x0EDV[a\x06\x8A\x82\x82`\x01a\x0ELV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\t\x1AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[P_Q` a7\xB9_9_Q\x90_R\x90V[_a\x06\x9E3\x83\x84a\x10\x16V[a\t@a\x10\xE3V[a\x07\xC4_a\x11=V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\t\xB7W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[a\x07h\x81a\x11=V[a\t\xE9`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[a\x06\x9E\x82a\x11VV[a\t\xFAa\x12\0V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x07\xC43`\x01a\x0F\xECV[_a\nPa\x0E)V[\x90P\x90V[_a\n^\x82T\x90V[\x15\x15\x92\x91PPV[_a\noa\x12\0V[a\n|\x86\x86\x86\x86\x86a\x122V[`\x01_\x81\x81R`\xFD` R\x7FdC\x15\x7Fw\x01\xA6'\xE51\x84\xB7O\xCE\r@?K\xF9\xBC\x1A\xAA\x0B\xC1|\x9E\xE1~\x10\xEC\x8B\x8F\x90a\n\xB4\x89\x89\x89a\n\xDFV[\x81R` \x81\x01\x91\x90\x91R`@\x01_\x90\x81 \x80T`\xFF\x19\x16\x92\x15\x15\x92\x90\x92\x17\x90\x91U\x96\x95PPPPPPV[`@Qe\x14\xD2Q\xD3\x90S`\xD2\x1B` \x82\x01R`\x01`\x01`\xC0\x1B\x03\x19`\xC0\x85\x90\x1B\x16`&\x82\x01Rk\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19``\x84\x90\x1B\x16`.\x82\x01R`B\x81\x01\x82\x90R_\x90`b\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P[\x93\x92PPPV[3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0B\x93W`@Qc\x1Fgu\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x9Ba\x13\xD8V[a\x0B\xB8W`@Qc\xCA\xDC\xFB\xDB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x81\x015a\x0B\xDAW`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x81\x015a\x0B\xFCW`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R` \x80\x84\x01\x805\x83R\x92\x84\x015\x81\x83\x01R`\x01_\x90\x81R`\xFE\x90\x91R\x90\x91\x7FE|\x8AH\xB4s_V\xB98\x83~\xB0\xA8\xA5\xF9\xC5_#\xC1\xA8Wg\xCE;e\xC3\xE5\x9D=2\xB7\x91\x90a\x0CP\x90\x85a0\xFDV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x82\x01\x92\x90\x92R`@\x01_ \x82Q\x81U\x91\x81\x01Q`\x01\x90\x92\x01\x91\x90\x91Ua\x0C\x85\x90\x82\x01\x82a0\xFDV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x7F\xF7&\xC5<\xBB\x9EbU*\xFCJ\x8F\x1B\xB1\xD0\x1F\xA9'.Rj~:i\xEB\xA9;w\x8B?B\xA6\x82` \x015\x83`@\x015`@Qa\x0C\xCF\x92\x91\x90\x91\x82R` \x82\x01R`@\x01\x90V[`@Q\x80\x91\x03\x90\xA2PV[a\x0C\xE2a\x12\0V[a\x0C\xEF\x85\x85\x85\x85\x85a\x122V[PPPPPV[a\x0C\xFEa\x10\xE3V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\r/`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[_Ta\x01\0\x90\x04`\xFF\x16a\r\x8DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\xB6V[a\r\x95a\x14:V[a\r\xB3`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\r\xADW\x81a\x11=V[3a\x11=V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\r\xEDW`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x81a\x0E\x0BW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0E\x17F\x85\x85a\n\xDFV[\x90Pa\x0E!\x81T\x90V[\x94\x93PPPPV[_Q` a7\xB9_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x07ha\x10\xE3V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x0E\x84Wa\x0E\x7F\x83a\x14`V[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x0E\xDEWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x0E\xDB\x91\x81\x01\x90a3\x01V[`\x01[a\x0FAW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[_Q` a7\xB9_9_Q\x90_R\x81\x14a\x0F\xAFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[Pa\x0E\x7F\x83\x83\x83a\x14\xFBV[a\x0F\xCF`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x07\xC4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x0E\x7F\x81a\x15%V[_`\x01`\x01`\xA0\x1B\x03\x84\x16a\x10>W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82a\x10\\W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x81a\x10zW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x10\x85F\x85\x85a\n\xDFV[\x82\x81U`@\x80Q`\x01`\x01`\xA0\x1B\x03\x87\x16\x81R` \x81\x01\x86\x90R\x90\x81\x01\x82\x90R``\x81\x01\x84\x90R\x90\x91P\x7F\n\xD2\xD1\x08f\n!\x1FG\xBF\x7F\xB4:\x04C\xCA\xE1\x81bI\x95\xD3\xD4+\x88\xEEhy\xD2\0\xE9s\x90`\x80\x01`@Q\x80\x91\x03\x90\xA1\x93\x92PPPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x07\xC4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x05\xEBV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x07h\x81a\x15cV[a\x11\x7F`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x16_\x90\x81R\x7FE|\x8AH\xB4s_V\xB98\x83~\xB0\xA8\xA5\xF9\xC5_#\xC1\xA8Wg\xCE;e\xC3\xE5\x9D=2\xB7` R`@\x90 \x80T\x80a\x11\xD4W`@Qc<\xA5\xD6G`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q``\x81\x01\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R` \x85\x01\x91\x90\x91R`\x01\x90\x91\x01T\x90\x83\x01RP\x90V[a\x12\x14`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x07\xC4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x84\x16a\x12YW`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82a\x12wW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x12\x83\x86\x86\x86a\n\xDFV[\x90P_\x82\x90\x03a\x12\xE0W_\x81\x81R\x7FdC\x15\x7Fw\x01\xA6'\xE51\x84\xB7O\xCE\r@?K\xF9\xBC\x1A\xAA\x0B\xC1|\x9E\xE1~\x10\xEC\x8B\x8F` R`@\x90 T`\xFF\x16a\x12\xDAW`@Qc\"\x13\x94W`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[Pa\x0C\xEFV[_a\x12\xED\x83\x85\x01\x85a3\xD5V[\x90P\x80Q`\x01\x14a\x13\x11W`@Qc\x07<\x8B\x97`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81_\x81Q\x81\x10a\x13$Wa\x13$a5\x1BV[` \x02` \x01\x01Q\x90P\x80`\x80\x01QQ_\x14\x80a\x13DWP`\xA0\x81\x01QQ\x15[\x15a\x13bW`@Qc\x0B\x92\xDA\xEF`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x13p\x82` \x01Qa\x15\xB4V[\x90P\x81`@\x01Q\x81\x14a\x13\x96W`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x13\xCC\x81\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x86\x8A\x86`\x80\x01Q\x87`\xA0\x01Qa\x17KV[PPPPPPPPPPV[_`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x15\x80a\nPWPP`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16B\x10\x90V[_Ta\x01\0\x90\x04`\xFF\x16a\x07\xC4W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\xB6V[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\x14\xCDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[_Q` a7\xB9_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a\x15\x04\x83a\x18XV[_\x82Q\x11\x80a\x15\x10WP\x80[\x15a\x0E\x7FWa\x15\x1F\x83\x83a\x18\x97V[PPPPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14\x80a\x15FWP3`\x01`\x01`\xA0\x1B\x03\x82\x16\x14[a\x07hW`@Qc\x958>\xA1`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a\x15\xBDa\x13\xD8V[\x15a\x16\x06We\xFF\xFF\xFF\xFF\xFF\xFF`\x01`\x01`@\x1B\x03\x83\x16\x11\x15a\x15\xF2W`@Qcx\xB5\x90K`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x15\xFB\x82a\x11VV[`@\x01Q\x90Pa\x17(V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16\x82`\x01`\x01`@\x1B\x03\x16\x10\x15a\x16YW`@Qcx\xB5\x90K`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q`\x01`\x01`@\x1B\x03\x84\x16` \x82\x01R_\x91\x82\x91r\x0F=\xF6\xD72\x80~\xF11\x9F\xB7\xB8\xBB\x85\"\xD0\xBE\xAC\x02\x91\x01`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x90\x82\x90Ra\x16\xA0\x91a5FV[_`@Q\x80\x83\x03\x81\x85Z\xFA\x91PP=\x80_\x81\x14a\x16\xD8W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x16\xDDV[``\x91P[P\x91P\x91P\x81\x15\x80a\x16\xF1WP\x80Q` \x14\x15[\x15a\x17\x0FW`@QcT3\xB2}`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80\x80` \x01\x90Q\x81\x01\x90a\x17#\x91\x90a3\x01V[\x92PPP[\x80a\x17FW`@QcT3\xB2}`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x91\x90PV[_\x82Q_\x14a\x17\xF3W`@Qk\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19``\x88\x90\x1B\x16` \x82\x01R_\x90a\x17\x8F\x90`4\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x85\x8Aa\x18\xBCV[\x90P\x80Q_\x03a\x17\xB2W`@Qc\x04\x14\xCD[`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x17\xBC\x82a\x18\xDEV[\x90Pa\x17\xE1\x81`\x02\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[` \x02` \x01\x01Qa\x18\xF1V[a\x17\xEA\x90a5QV[\x92PPPa\x17\xF6V[P\x85[_a\x18-\x86`@Q` \x01a\x18\r\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90Ra\x18&\x87a\x19pV[\x85\x85a\x19\x83V[\x90P\x80a\x18MW`@Qc\x8D\x9AM\xB3`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x96\x95PPPPPPV[a\x18a\x81a\x14`V[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x0BC\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a7\xD9`'\x919a\x19\xA6V[``_a\x18\xC8\x85a\x1A\x10V[\x90Pa\x18\xD5\x81\x85\x85a\x1ABV[\x95\x94PPPPPV[``a\x06\x9Ea\x18\xEC\x83a\"\xB0V[a#\x02V[``___a\x18\xFF\x85a$\x80V[\x91\x94P\x92P\x90P_\x81`\x01\x81\x11\x15a\x19\x19Wa\x19\x19a5wV[\x14a\x197W`@Qc\x07\xFEl\xB9`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x19A\x82\x84a5\x9FV[\x85Q\x14a\x19aW`@Qc\x0B\x8A\xA6\xF7`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x18\xD5\x85` \x01Q\x84\x84a'cV[``a\x06\x9Ea\x19~\x83a'\xF3V[a)\x0FV[__a\x19\x8E\x86a\x1A\x10V[\x90Pa\x19\x9C\x81\x86\x86\x86a)bV[\x96\x95PPPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa\x19\xC2\x91\x90a5FV[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a\x19\xFAW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x19\xFFV[``\x91P[P\x91P\x91Pa\x19\x9C\x86\x83\x83\x87a)\x88V[``\x81\x80Q\x90` \x01 `@Q` \x01a\x1A,\x91\x81R` \x01\x90V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x90P\x91\x90PV[``_\x84Q\x11a\x1A\x8CW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x15`$\x82\x01RtMerkleTrie: empty key`X\x1B`D\x82\x01R`d\x01a\x05\xEBV[_a\x1A\x96\x84a*\0V[\x90P_a\x1A\xA2\x86a*\xEAV[\x90P_\x84`@Q` \x01a\x1A\xB8\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x90P_\x80[\x84Q\x81\x10\x15a\"YW_\x85\x82\x81Q\x81\x10a\x1A\xE9Wa\x1A\xE9a5\x1BV[` \x02` \x01\x01Q\x90P\x84Q\x83\x11\x15a\x1B[W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FMerkleTrie: key index exceeds to`D\x82\x01Rm\x0E\x8C-\x84\rl\xAF$\r\x8C\xAD\xCC\xEE\x8D`\x93\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[\x82_\x03a\x1B\xF9W\x80Q\x80Q` \x91\x82\x01 `@Qa\x1B\xA8\x92a\x1B\x82\x92\x91\x01\x90\x81R` \x01\x90V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x85\x80Q` \x91\x82\x01 \x82Q\x92\x90\x91\x01\x91\x90\x91 \x14\x90V[a\x1B\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FMerkleTrie: invalid root hash\0\0\0`D\x82\x01R`d\x01a\x05\xEBV[a\x1C\xEFV[\x80QQ` \x11a\x1C\x7FW\x80Q\x80Q` \x91\x82\x01 `@Qa\x1C#\x92a\x1B\x82\x92\x91\x01\x90\x81R` \x01\x90V[a\x1B\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FMerkleTrie: invalid large intern`D\x82\x01Rf\x0C-\x84\r\x0C.m`\xCB\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[\x80Q\x84Q` \x80\x87\x01\x91\x90\x91 \x82Q\x91\x90\x92\x01 \x14a\x1C\xEFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FMerkleTrie: invalid internal nod`D\x82\x01Re\x0C\xA4\r\x0C.m`\xD3\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[a\x1C\xFB`\x10`\x01a5\x9FV[\x81` \x01QQ\x03a\x1E\x93W\x84Q\x83\x03a\x1E-Wa\x1D(\x81` \x01Q`\x10\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[\x96P_\x87Q\x11a\x1D\xA0W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`;`$\x82\x01R\x7FMerkleTrie: value length must be`D\x82\x01R\x7F greater than zero (branch)\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\x01\x86Qa\x1D\xAE\x91\x90a5\xB2V[\x82\x14a\x1E\"W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`:`$\x82\x01R\x7FMerkleTrie: value node must be l`D\x82\x01R\x7Fast node in proof (branch)\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPa\x0BCV[_\x85\x84\x81Q\x81\x10a\x1E@Wa\x1E@a5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B`\xF8\x1C\x90P_\x82` \x01Q\x82`\xFF\x16\x81Q\x81\x10a\x1EjWa\x1Eja5\x1BV[` \x02` \x01\x01Q\x90Pa\x1E}\x81a+KV[\x95Pa\x1E\x8A`\x01\x86a5\x9FV[\x94PPPa\"PV[`\x02\x81` \x01QQ\x03a!\xF7W_a\x1E\xAA\x82a+oV[\x90P_\x81_\x81Q\x81\x10a\x1E\xBFWa\x1E\xBFa5\x1BV[\x01` \x01Q`\xF8\x1C\x90P_a\x1E\xD5`\x02\x83a5\xD9V[a\x1E\xE0\x90`\x02a5\xFAV[\x90P_a\x1E\xF0\x84\x83`\xFF\x16a+\x92V[\x90P_a\x1E\xFD\x8A\x89a+\x92V[\x90P_a\x1F\n\x83\x83a+\xC7V[\x90P\x80\x83Q\x14a\x1F\x82W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`:`$\x82\x01R\x7FMerkleTrie: path remainder must `D\x82\x01R\x7Fshare all nibbles with key\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\xFF\x85\x16`\x02\x14\x80a\x1F\x97WP`\xFF\x85\x16`\x03\x14[\x15a!7W\x80\x82Q\x14a \x12W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`=`$\x82\x01R\x7FMerkleTrie: key remainder must b`D\x82\x01R\x7Fe identical to path remainder\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[a ,\x87` \x01Q`\x01\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[\x9CP_\x8DQ\x11a \xA4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`9`$\x82\x01R\x7FMerkleTrie: value length must be`D\x82\x01R\x7F greater than zero (leaf)\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\x01\x8CQa \xB2\x91\x90a5\xB2V[\x88\x14a!&W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FMerkleTrie: value node must be l`D\x82\x01R\x7Fast node in proof (leaf)\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPPPPPPPa\x0BCV[`\xFF\x85\x16\x15\x80a!JWP`\xFF\x85\x16`\x01\x14[\x15a!\x89Wa!v\x87` \x01Q`\x01\x81Q\x81\x10a!iWa!ia5\x1BV[` \x02` \x01\x01Qa+KV[\x99Pa!\x82\x81\x8Aa5\x9FV[\x98Pa!\xECV[`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`2`$\x82\x01R\x7FMerkleTrie: received a node with`D\x82\x01Rq\x04\x0C-\xC4\x0E\xAD\xCDm\xCD\xEE\xED\xC4\x0E\x0EL\xAC\xCD/`s\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPa\"PV[`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`(`$\x82\x01R\x7FMerkleTrie: received an unparsea`D\x82\x01Rgble node`\xC0\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[P`\x01\x01a\x1A\xCDV[P`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`%`$\x82\x01R\x7FMerkleTrie: ran out of proof ele`D\x82\x01Rdments`\xD8\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81Q_\x03a\"\xE4W`@QcZ\xB4X\xFB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P`@\x80Q\x80\x82\x01\x90\x91R\x81Q\x81R` \x91\x82\x01\x91\x81\x01\x91\x90\x91R\x90V[``___a#\x10\x85a$\x80V[\x91\x94P\x92P\x90P`\x01\x81`\x01\x81\x11\x15a#+Wa#+a5wV[\x14a#IW`@Qc%\xCE5_`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x84Qa#U\x83\x85a5\x9FV[\x14a#sW`@Qc\x0B\x8A\xA6\xF7`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q` \x80\x82Ra\x04 \x82\x01\x90\x92R\x90\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a#\x8AW\x90PP\x93P_\x83[\x86Q\x81\x10\x15a$tW__a#\xF9`@Q\x80`@\x01`@R\x80\x85\x8C_\x01Qa#\xDD\x91\x90a5\xB2V[\x81R` \x01\x85\x8C` \x01Qa#\xF2\x91\x90a5\x9FV[\x90Ra$\x80V[P\x91P\x91P`@Q\x80`@\x01`@R\x80\x83\x83a$\x15\x91\x90a5\x9FV[\x81R` \x01\x84\x8B` \x01Qa$*\x91\x90a5\x9FV[\x81RP\x88\x85\x81Q\x81\x10a$?Wa$?a5\x1BV[` \x90\x81\x02\x91\x90\x91\x01\x01Ra$U`\x01\x85a5\x9FV[\x93Pa$a\x81\x83a5\x9FV[a$k\x90\x84a5\x9FV[\x92PPPa#\xB5V[P\x84RP\x91\x93\x92PPPV[___\x83_\x01Q_\x03a$\xA6W`@QcZ\xB4X\xFB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x84\x01Q\x80Q_\x1A`\x7F\x81\x11a$\xC8W_`\x01_\x94P\x94P\x94PPPa'\\V[`\xB7\x81\x11a%]W_a$\xDC`\x80\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a%\x01W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x81\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x82\x14\x80\x15a%-WP`\x01`\xFF\x1B`\x01`\x01`\xF8\x1B\x03\x19\x82\x16\x10[\x15a%KW`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P`\x01\x95P\x93P_\x92Pa'\\\x91PPV[`\xBF\x81\x11a&;W_a%q`\xB7\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a%\x96W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x81\x90\x03a%\xC6W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x84\x01Q`\x08\x83\x02a\x01\0\x03\x1C`7\x81\x11a%\xF5W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a%\xFF\x81\x84a5\x9FV[\x89Q\x11a&\x1FW`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a&*\x83`\x01a5\x9FV[\x97P\x95P_\x94Pa'\\\x93PPPPV[`\xF7\x81\x11a&\x85W_a&O`\xC0\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a&tW`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x95P\x93P\x84\x92Pa'\\\x91PPV[_a&\x91`\xF7\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a&\xB6W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x81\x90\x03a&\xE6W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x84\x01Q`\x08\x83\x02a\x01\0\x03\x1C`7\x81\x11a'\x15W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a'\x1F\x81\x84a5\x9FV[\x89Q\x11a'?W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a'J\x83`\x01a5\x9FV[\x97P\x95P`\x01\x94Pa'\\\x93PPPPV[\x91\x93\x90\x92PV[``\x81`\x01`\x01`@\x1B\x03\x81\x11\x15a'}Wa'}a/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a'\xA7W` \x82\x01\x81\x806\x837\x01\x90P[P\x90P\x81\x15a\x0BCW_a'\xBB\x84\x86a5\x9FV[\x90P` \x82\x01_[\x84\x81\x10\x15a'\xDBW\x82\x81\x01Q\x82\x82\x01R` \x01a'\xC3V[\x84\x81\x11\x15a'\xE9W_\x85\x83\x01R[PPP\x93\x92PPPV[``_\x82`@Q` \x01a(\t\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x90P_[` \x81\x10\x15a(UW\x81\x81\x81Q\x81\x10a(8Wa(8a5\x1BV[\x01` \x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x03a(UW`\x01\x01a(\x1DV[a(`\x81` a5\xB2V[`\x01`\x01`@\x1B\x03\x81\x11\x15a(wWa(wa/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a(\xA1W` \x82\x01\x81\x806\x837\x01\x90P[P\x92P_[\x83Q\x81\x10\x15a)\x07W\x82\x82a(\xBA\x81a6\x13V[\x93P\x81Q\x81\x10a(\xCCWa(\xCCa5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B\x84\x82\x81Q\x81\x10a(\xE9Wa(\xE9a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP`\x01\x01a(\xA6V[PPP\x91\x90PV[``\x81Q`\x01\x14\x80\x15a);WP`\x80\x82_\x81Q\x81\x10a)1Wa)1a5\x1BV[\x01` \x01Q`\xF8\x1C\x10[\x15a)DWP\x90V[a)P\x82Q`\x80a,JV[\x82`@Q` \x01a\x1A,\x92\x91\x90a6+V[_a\x18\xD5\x84a)r\x87\x86\x86a\x1ABV[\x80Q` \x91\x82\x01 \x82Q\x92\x90\x91\x01\x91\x90\x91 \x14\x90V[``\x83\x15a)\xF6W\x82Q_\x03a)\xEFW`\x01`\x01`\xA0\x1B\x03\x85\x16;a)\xEFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x05\xEBV[P\x81a\x0E!V[a\x0E!\x83\x83a-\xEFV[\x80Q``\x90\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a*\x1DWa*\x1Da/\xC5V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a*bW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R``\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a*;W\x90P[P\x91P_[\x81\x81\x10\x15a*\xE3W`@Q\x80`@\x01`@R\x80\x85\x83\x81Q\x81\x10a*\x8CWa*\x8Ca5\x1BV[` \x02` \x01\x01Q\x81R` \x01a*\xBB\x86\x84\x81Q\x81\x10a*\xAEWa*\xAEa5\x1BV[` \x02` \x01\x01Qa\x18\xDEV[\x81RP\x83\x82\x81Q\x81\x10a*\xD0Wa*\xD0a5\x1BV[` \x90\x81\x02\x91\x90\x91\x01\x01R`\x01\x01a*gV[PP\x91\x90PV[``\x80`@Q\x90P\x82Q\x80`\x01\x1B`?\x81\x01`\x1F\x19\x16\x83\x01`@R\x80\x83RP` \x84\x01` \x83\x01_[\x83\x81\x10\x15a+@W\x80`\x01\x1B\x82\x01\x81\x84\x01Q_\x1A\x80`\x04\x1C\x82S`\x0F\x81\x16`\x01\x83\x01SPP`\x01\x01a+\x13V[P\x92\x95\x94PPPPPV[``` \x82_\x01Q\x10a+fWa+a\x82a\x18\xF1V[a\x06\x9EV[a\x06\x9E\x82a.\x19V[``a\x06\x9Ea+\x8D\x83` \x01Q_\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[a*\xEAV[``\x82Q\x82\x10a+\xB0WP`@\x80Q` \x81\x01\x90\x91R_\x81Ra\x06\x9EV[a\x0BC\x83\x83\x84\x86Qa+\xC2\x91\x90a5\xB2V[a.-V[__\x82Q\x84Q\x10a+\xD9W\x82Qa+\xDCV[\x83Q[\x90P[\x80\x82\x10\x80\x15a,3WP\x82\x82\x81Q\x81\x10a+\xFBWa+\xFBa5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B`\x01`\x01`\xF8\x1B\x03\x19\x16\x84\x83\x81Q\x81\x10a,\"Wa,\"a5\x1BV[\x01` \x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16\x14[\x15a,CW\x81`\x01\x01\x91Pa+\xDFV[P\x92\x91PPV[```8\x83\x10\x15a,\xAEW`@\x80Q`\x01\x80\x82R\x81\x83\x01\x90\x92R\x90` \x82\x01\x81\x806\x837\x01\x90PP\x90Pa,~\x82\x84a6?V[`\xF8\x1B\x81_\x81Q\x81\x10a,\x93Wa,\x93a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SPa\x06\x9EV[_`\x01[a,\xBC\x81\x86a6XV[\x15a,\xE2W\x81a,\xCB\x81a6\x13V[\x92Pa,\xDB\x90Pa\x01\0\x82a6kV[\x90Pa,\xB2V[a,\xED\x82`\x01a5\x9FV[`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x04Wa-\x04a/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a-.W` \x82\x01\x81\x806\x837\x01\x90P[P\x92Pa-;\x84\x83a6?V[a-F\x90`7a6?V[`\xF8\x1B\x83_\x81Q\x81\x10a-[Wa-[a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP`\x01\x90P[\x81\x81\x11a-\xE7Wa\x01\0a-\x8A\x82\x84a5\xB2V[a-\x96\x90a\x01\0a7eV[a-\xA0\x90\x87a6XV[a-\xAA\x91\x90a7pV[`\xF8\x1B\x83\x82\x81Q\x81\x10a-\xBFWa-\xBFa5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP\x80a-\xDF\x81a6\x13V[\x91PPa-vV[PP\x92\x91PPV[\x81Q\x15a-\xFFW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x91\x90a7\x83V[``a\x06\x9E\x82` \x01Q_\x84_\x01Qa'cV[``\x81\x82`\x1F\x01\x10\x15a.sW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x0E`$\x82\x01Rmslice_overflow`\x90\x1B`D\x82\x01R`d\x01a\x05\xEBV[\x82\x82\x84\x01\x10\x15a.\xB6W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x0E`$\x82\x01Rmslice_overflow`\x90\x1B`D\x82\x01R`d\x01a\x05\xEBV[\x81\x83\x01\x84Q\x10\x15a.\xFDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x11`$\x82\x01Rpslice_outOfBounds`x\x1B`D\x82\x01R`d\x01a\x05\xEBV[``\x82\x15\x80\x15a/\x1BW`@Q\x91P_\x82R` \x82\x01`@Ra/eV[`@Q\x91P`\x1F\x84\x16\x80\x15` \x02\x81\x84\x01\x01\x85\x81\x01\x87\x83\x15` \x02\x84\x8B\x01\x01\x01[\x81\x83\x10\x15a/TW\x80Q\x83R` \x92\x83\x01\x92\x01a/<V[PP\x85\x84R`\x1F\x01`\x1F\x19\x16`@RP[P\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x17FW__\xFD[_` \x82\x84\x03\x12\x15a/\x94W__\xFD[a\x0BC\x82a/nV[__`@\x83\x85\x03\x12\x15a/\xAEW__\xFD[a/\xB7\x83a/nV[\x94` \x93\x90\x93\x015\x93PPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a/\xFBWa/\xFBa/\xC5V[`@R\x90V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a0)Wa0)a/\xC5V[`@R\x91\x90PV[_\x82`\x1F\x83\x01\x12a0@W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0YWa0Ya/\xC5V[a0l`\x1F\x82\x01`\x1F\x19\x16` \x01a0\x01V[\x81\x81R\x84` \x83\x86\x01\x01\x11\x15a0\x80W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a0\xADW__\xFD[a0\xB6\x83a/nV[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xD0W__\xFD[a0\xDC\x85\x82\x86\x01a01V[\x91PP\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a0\xF6W__\xFD[P5\x91\x90PV[_` \x82\x84\x03\x12\x15a1\rW__\xFD[\x815e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0BCW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x17FW__\xFD[_____`\x80\x86\x88\x03\x12\x15a1LW__\xFD[a1U\x86a1\"V[\x94Pa1c` \x87\x01a/nV[\x93P`@\x86\x015\x92P``\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a1\x84W__\xFD[\x86\x01`\x1F\x81\x01\x88\x13a1\x94W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a1\xA9W__\xFD[\x88` \x82\x84\x01\x01\x11\x15a1\xBAW__\xFD[\x95\x98\x94\x97P\x92\x95PPP` \x01\x91\x90V[___``\x84\x86\x03\x12\x15a1\xDDW__\xFD[a1\xE6\x84a1\"V[\x92Pa1\xF4` \x85\x01a/nV[\x92\x95\x92\x94PPP`@\x91\x90\x91\x015\x90V[_``\x82\x84\x03\x12\x80\x15a2\x16W__\xFD[P\x90\x92\x91PPV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a3\x11W__\xFD[PQ\x91\x90PV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a30Wa30a/\xC5V[P`\x05\x1B` \x01\x90V[\x805`\x04\x81\x10a\x17FW__\xFD[_\x82`\x1F\x83\x01\x12a3WW__\xFD[\x815a3ja3e\x82a3\x18V[a0\x01V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a3\x8BW__\xFD[` \x85\x01[\x83\x81\x10\x15a3\xCBW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xADW__\xFD[a3\xBC\x88` \x83\x8A\x01\x01a01V[\x84RP` \x92\x83\x01\x92\x01a3\x90V[P\x95\x94PPPPPV[_` \x82\x84\x03\x12\x15a3\xE5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xFAW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a4\nW__\xFD[\x805a4\x18a3e\x82a3\x18V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a49W__\xFD[` \x84\x01[\x83\x81\x10\x15a\x18MW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a4[W__\xFD[\x85\x01`\xC0\x81\x8A\x03`\x1F\x19\x01\x12\x15a4pW__\xFD[a4xa/\xD9V[a4\x84` \x83\x01a1\"V[\x81Ra4\x92`@\x83\x01a1\"V[` \x82\x01R``\x82\x015`@\x82\x01Ra4\xAD`\x80\x83\x01a3:V[``\x82\x01R`\xA0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xCAW__\xFD[a4\xD9\x8B` \x83\x86\x01\x01a3HV[`\x80\x83\x01RP`\xC0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xF7W__\xFD[a5\x06\x8B` \x83\x86\x01\x01a3HV[`\xA0\x83\x01RP\x84RP` \x92\x83\x01\x92\x01a4>V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[_\x81Q\x80` \x84\x01\x85^_\x93\x01\x92\x83RP\x90\x91\x90PV[_a\x0BC\x82\x84a5/V[\x80Q` \x80\x83\x01Q\x91\x90\x81\x10\x15a5qW_\x19\x81` \x03`\x03\x1B\x1B\x82\x16\x91P[P\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[\x81\x81\x03\x81\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_`\xFF\x83\x16\x80a5\xEBWa5\xEBa5\xC5V[\x80`\xFF\x84\x16\x06\x91PP\x92\x91PPV[`\xFF\x82\x81\x16\x82\x82\x16\x03\x90\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[_`\x01\x82\x01a6$Wa6$a5\x8BV[P`\x01\x01\x90V[_a\x0E!a69\x83\x86a5/V[\x84a5/V[`\xFF\x81\x81\x16\x83\x82\x16\x01\x90\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[_\x82a6fWa6fa5\xC5V[P\x04\x90V[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x06\x9EWa\x06\x9Ea5\x8BV[`\x01\x81[`\x01\x84\x11\x15a6\xBDW\x80\x85\x04\x81\x11\x15a6\xA1Wa6\xA1a5\x8BV[`\x01\x84\x16\x15a6\xAFW\x90\x81\x02\x90[`\x01\x93\x90\x93\x1C\x92\x80\x02a6\x86V[\x93P\x93\x91PPV[_\x82a6\xD3WP`\x01a\x06\x9EV[\x81a6\xDFWP_a\x06\x9EV[\x81`\x01\x81\x14a6\xF5W`\x02\x81\x14a6\xFFWa7\x1BV[`\x01\x91PPa\x06\x9EV[`\xFF\x84\x11\x15a7\x10Wa7\x10a5\x8BV[PP`\x01\x82\x1Ba\x06\x9EV[P` \x83\x10a\x013\x83\x10\x16`N\x84\x10`\x0B\x84\x10\x16\x17\x15a7>WP\x81\x81\na\x06\x9EV[a7J_\x19\x84\x84a6\x82V[\x80_\x19\x04\x82\x11\x15a7]Wa7]a5\x8BV[\x02\x93\x92PPPV[_a\x0BC\x83\x83a6\xC5V[_\x82a7~Wa7~a5\xC5V[P\x06\x90V[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \xAD_\x0E\xB9\xAE(J\xF5\x13\x17\xB7\x99\xA7\xDB\xD3\x9B>\xFA\xBB\xBF\xF4\xDF|\xD4\xAF:H8\x07b\xA4QdsolcC\0\x08\x1E\x003",
    );
    /// The runtime bytecode of the contract, as deployed on the network.
    ///
    /// ```text
    ///0x608060405260043610610195575f3560e01c80638026b921116100e75780639bce53b511610087578063ce9d082011610062578063ce9d0820146104e6578063e30c397814610505578063f2fde38b14610522578063ffa1ad7414610541575f5ffd5b80639bce53b5146104495780639fd0506d14610494578063c9a0b8c8146104c7575f5ffd5b80638da5cb5b116100c25780638da5cb5b146103cf5780638e899f80146103ec578063910af6ed1461040b57806391f3f74b1461042a575f5ffd5b80638026b9211461035e5780638456cb59146103a75780638abf6077146103bb575f5ffd5b80634f1ef286116101525780635c975abb1161012d5780635c975abb146102f757806366ca2bc014610317578063715018a61461033657806379ba50971461034a575f5ffd5b80634f1ef2861461029c57806352d1902d146102af57806356d7e8fd146102d1575f5ffd5b806304f3bcec1461019957806319ab453c146101e45780633075db561461020557806332676bc61461024a5780633659cfe6146102695780633f4ba83a14610288575b5f5ffd5b3480156101a4575f5ffd5b507f00000000000000000000000000000000000000000000000000000000000000005b6040516001600160a01b0390911681526020015b60405180910390f35b3480156101ef575f5ffd5b506102036101fe366004612f84565b610555565b005b348015610210575f5ffd5b5060027fa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b5c60ff16145b60405190151581526020016101db565b348015610255575f5ffd5b5061023a610264366004612f9d565b61068e565b348015610274575f5ffd5b50610203610283366004612f84565b6106a4565b348015610293575f5ffd5b5061020361076b565b6102036102aa36600461309c565b6107c6565b3480156102ba575f5ffd5b506102c361087b565b6040519081526020016101db565b3480156102dc575f5ffd5b506101c7720f3df6d732807ef1319fb7b8bb8522d0beac0281565b348015610302575f5ffd5b5061023a60c954610100900460ff1660021490565b348015610322575f5ffd5b506102c36103313660046130e6565b61092c565b348015610341575f5ffd5b50610203610938565b348015610355575f5ffd5b50610203610949565b348015610369575f5ffd5b5061037d6103783660046130fd565b6109c0565b60408051825165ffffffffffff1681526020808401519082015291810151908201526060016101db565b3480156103b2575f5ffd5b506102036109f2565b3480156103c6575f5ffd5b506101c7610a47565b3480156103da575f5ffd5b506033546001600160a01b03166101c7565b3480156103f7575f5ffd5b5061023a6104063660046130e6565b610a55565b348015610416575f5ffd5b506102c3610425366004613138565b610a66565b348015610435575f5ffd5b506102c36104443660046131cb565b610adf565b348015610454575f5ffd5b5061047c7f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160401b0390911681526020016101db565b34801561049f575f5ffd5b506101c77f000000000000000000000000000000000000000000000000000000000000000081565b3480156104d2575f5ffd5b506102036104e1366004613205565b610b4a565b3480156104f1575f5ffd5b50610203610500366004613138565b610cda565b348015610510575f5ffd5b506065546001600160a01b03166101c7565b34801561052d575f5ffd5b5061020361053c366004612f84565b610cf6565b34801561054c575f5ffd5b506102c3600181565b5f54610100900460ff161580801561057357505f54600160ff909116105b8061058c5750303b15801561058c57505f5460ff166001145b6105f45760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b60648201526084015b60405180910390fd5b5f805460ff191660011790558015610615575f805461ff0019166101001790555b6001600160a01b03821661063c5760405163538ba4f960e01b815260040160405180910390fd5b61064582610d67565b801561068a575f805461ff0019169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b5050565b5f6106998383610dc5565b151590505b92915050565b6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001630036106ec5760405162461bcd60e51b81526004016105eb9061321e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031661071e610e29565b6001600160a01b0316146107445760405162461bcd60e51b81526004016105eb9061326a565b61074d81610e44565b604080515f8082526020820190925261076891839190610e4c565b50565b610773610fbb565b61078760c9805461ff001916610100179055565b6040513381527f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa9060200160405180910390a16107c4335f610fec565b565b6001600160a01b037f000000000000000000000000000000000000000000000000000000000000000016300361080e5760405162461bcd60e51b81526004016105eb9061321e565b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316610840610e29565b6001600160a01b0316146108665760405162461bcd60e51b81526004016105eb9061326a565b61086f82610e44565b61068a82826001610e4c565b5f306001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161461091a5760405162461bcd60e51b815260206004820152603860248201527f555550535570677261646561626c653a206d757374206e6f742062652063616c60448201527f6c6564207468726f7567682064656c656761746563616c6c000000000000000060648201526084016105eb565b505f5160206137b95f395f51905f5290565b5f61069e338384611016565b6109406110e3565b6107c45f61113d565b60655433906001600160a01b031681146109b75760405162461bcd60e51b815260206004820152602960248201527f4f776e61626c6532537465703a2063616c6c6572206973206e6f7420746865206044820152683732bb9037bbb732b960b91b60648201526084016105eb565b6107688161113d565b6109e960405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b61069e82611156565b6109fa611200565b60c9805461ff0019166102001790556040513381527f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2589060200160405180910390a16107c4336001610fec565b5f610a50610e29565b905090565b5f610a5e825490565b151592915050565b5f610a6f611200565b610a7c8686868686611232565b60015f81815260fd6020527f6443157f7701a627e53184b74fce0d403f4bf9bc1aaa0bc17c9ee17e10ec8b8f90610ab4898989610adf565b815260208101919091526040015f908120805460ff1916921515929092179091559695505050505050565b6040516514d251d3905360d21b60208201526001600160c01b031960c085901b1660268201526bffffffffffffffffffffffff19606084901b16602e820152604281018290525f906062016040516020818303038152906040528051906020012090505b9392505050565b336001600160a01b037f00000000000000000000000000000000000000000000000000000000000000001614610b9357604051631f67751f60e01b815260040160405180910390fd5b610b9b6113d8565b610bb85760405163cadcfbdb60e01b815260040160405180910390fd5b6040810135610bda576040516362d16b9d60e01b815260040160405180910390fd5b6020810135610bfc576040516362d16b9d60e01b815260040160405180910390fd5b604080518082018252602080840180358352928401358183015260015f90815260fe90915290917f457c8a48b4735f56b938837eb0a8a5f9c55f23c1a85767ce3b65c3e59d3d32b79190610c5090856130fd565b65ffffffffffff1681526020808201929092526040015f208251815591810151600190920191909155610c85908201826130fd565b65ffffffffffff167ff726c53cbb9e62552afc4a8f1bb1d01fa9272e526a7e3a69eba93b778b3f42a682602001358360400135604051610ccf929190918252602082015260400190565b60405180910390a250565b610ce2611200565b610cef8585858585611232565b5050505050565b610cfe6110e3565b606580546001600160a01b0383166001600160a01b03199091168117909155610d2f6033546001600160a01b031690565b6001600160a01b03167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a350565b5f54610100900460ff16610d8d5760405162461bcd60e51b81526004016105eb906132b6565b610d9561143a565b610db36001600160a01b03821615610dad578161113d565b3361113d565b5060c9805461ff001916610100179055565b5f6001600160a01b038316610ded5760405163538ba4f960e01b815260040160405180910390fd5b81610e0b5760405163ec73295960e01b815260040160405180910390fd5b5f610e17468585610adf565b9050610e21815490565b949350505050565b5f5160206137b95f395f51905f52546001600160a01b031690565b6107686110e3565b7f4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd91435460ff1615610e8457610e7f83611460565b505050565b826001600160a01b03166352d1902d6040518163ffffffff1660e01b8152600401602060405180830381865afa925050508015610ede575060408051601f3d908101601f19168201909252610edb91810190613301565b60015b610f415760405162461bcd60e51b815260206004820152602e60248201527f45524331393637557067726164653a206e657720696d706c656d656e7461746960448201526d6f6e206973206e6f74205555505360901b60648201526084016105eb565b5f5160206137b95f395f51905f528114610faf5760405162461bcd60e51b815260206004820152602960248201527f45524331393637557067726164653a20756e737570706f727465642070726f786044820152681a58589b195555525160ba1b60648201526084016105eb565b50610e7f8383836114fb565b610fcf60c954610100900460ff1660021490565b6107c45760405163bae6e2a960e01b815260040160405180910390fd5b7f0000000000000000000000000000000000000000000000000000000000000000610e7f81611525565b5f6001600160a01b03841661103e5760405163538ba4f960e01b815260040160405180910390fd5b8261105c5760405163ec73295960e01b815260040160405180910390fd5b8161107a5760405163ec73295960e01b815260040160405180910390fd5b611085468585610adf565b828155604080516001600160a01b038716815260208101869052908101829052606081018490529091507f0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e9739060800160405180910390a19392505050565b6033546001600160a01b031633146107c45760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016105eb565b606580546001600160a01b031916905561076881611563565b61117f60405180606001604052805f65ffffffffffff1681526020015f81526020015f81525090565b65ffffffffffff82165f9081527f457c8a48b4735f56b938837eb0a8a5f9c55f23c1a85767ce3b65c3e59d3d32b7602052604090208054806111d457604051633ca5d64760e21b815260040160405180910390fd5b6040805160608101825265ffffffffffff90951685526020850191909152600190910154908301525090565b61121460c954610100900460ff1660021490565b156107c45760405163bae6e2a960e01b815260040160405180910390fd5b6001600160a01b0384166112595760405163538ba4f960e01b815260040160405180910390fd5b826112775760405163ec73295960e01b815260040160405180910390fd5b5f611283868686610adf565b90505f8290036112e0575f8181527f6443157f7701a627e53184b74fce0d403f4bf9bc1aaa0bc17c9ee17e10ec8b8f602052604090205460ff166112da57604051632213945760e11b815260040160405180910390fd5b50610cef565b5f6112ed838501856133d5565b905080516001146113115760405163073c8b9760e31b815260040160405180910390fd5b5f815f815181106113245761132461351b565b602002602001015190508060800151515f1480611344575060a081015151155b1561136257604051630b92daef60e21b815260040160405180910390fd5b5f61137082602001516115b4565b905081604001518114611396576040516362d16b9d60e01b815260040160405180910390fd5b6113cc817f0000000000000000000000000000000000000000000000000000000000000000868a86608001518760a0015161174b565b50505050505050505050565b5f6001600160401b037f0000000000000000000000000000000000000000000000000000000000000000161580610a505750506001600160401b037f000000000000000000000000000000000000000000000000000000000000000016421090565b5f54610100900460ff166107c45760405162461bcd60e51b81526004016105eb906132b6565b6001600160a01b0381163b6114cd5760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b60648201526084016105eb565b5f5160206137b95f395f51905f5280546001600160a01b0319166001600160a01b0392909216919091179055565b61150483611858565b5f825111806115105750805b15610e7f5761151f8383611897565b50505050565b6033546001600160a01b03163314806115465750336001600160a01b038216145b610768576040516395383ea160e01b815260040160405180910390fd5b603380546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a35050565b5f6115bd6113d8565b156116065765ffffffffffff6001600160401b03831611156115f2576040516378b5904b60e11b815260040160405180910390fd5b6115fb82611156565b604001519050611728565b7f00000000000000000000000000000000000000000000000000000000000000006001600160401b0316826001600160401b03161015611659576040516378b5904b60e11b815260040160405180910390fd5b604080516001600160401b03841660208201525f918291720f3df6d732807ef1319fb7b8bb8522d0beac02910160408051601f19818403018152908290526116a091613546565b5f60405180830381855afa9150503d805f81146116d8576040519150601f19603f3d011682016040523d82523d5f602084013e6116dd565b606091505b50915091508115806116f157508051602014155b1561170f57604051635433b27d60e11b815260040160405180910390fd5b808060200190518101906117239190613301565b925050505b8061174657604051635433b27d60e11b815260040160405180910390fd5b919050565b5f82515f146117f3576040516bffffffffffffffffffffffff19606088901b1660208201525f9061178f90603401604051602081830303815290604052858a6118bc565b905080515f036117b257604051630414cd5b60e31b815260040160405180910390fd5b5f6117bc826118de565b90506117e1816002815181106117d4576117d461351b565b60200260200101516118f1565b6117ea90613551565b925050506117f6565b50855b5f61182d8660405160200161180d91815260200190565b60408051601f1981840301815291905261182687611970565b8585611983565b90508061184d57604051638d9a4db360e01b815260040160405180910390fd5b509695505050505050565b61186181611460565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a250565b6060610b4383836040518060600160405280602781526020016137d9602791396119a6565b60605f6118c885611a10565b90506118d5818585611a42565b95945050505050565b606061069e6118ec836122b0565b612302565b60605f5f5f6118ff85612480565b919450925090505f81600181111561191957611919613577565b14611937576040516307fe6cb960e21b815260040160405180910390fd5b611941828461359f565b85511461196157604051630b8aa6f760e31b815260040160405180910390fd5b6118d585602001518484612763565b606061069e61197e836127f3565b61290f565b5f5f61198e86611a10565b905061199c81868686612962565b9695505050505050565b60605f5f856001600160a01b0316856040516119c29190613546565b5f60405180830381855af49150503d805f81146119fa576040519150601f19603f3d011682016040523d82523d5f602084013e6119ff565b606091505b509150915061199c86838387612988565b60608180519060200120604051602001611a2c91815260200190565b6040516020818303038152906040529050919050565b60605f845111611a8c5760405162461bcd60e51b81526020600482015260156024820152744d65726b6c65547269653a20656d707479206b657960581b60448201526064016105eb565b5f611a9684612a00565b90505f611aa286612aea565b90505f84604051602001611ab891815260200190565b60408051601f1981840301815291905290505f805b8451811015612259575f858281518110611ae957611ae961351b565b602002602001015190508451831115611b5b5760405162461bcd60e51b815260206004820152602e60248201527f4d65726b6c65547269653a206b657920696e646578206578636565647320746f60448201526d0e8c2d840d6caf240d8cadccee8d60931b60648201526084016105eb565b825f03611bf95780518051602091820120604051611ba892611b8292910190815260200190565b604051602081830303815290604052858051602091820120825192909101919091201490565b611bf45760405162461bcd60e51b815260206004820152601d60248201527f4d65726b6c65547269653a20696e76616c696420726f6f74206861736800000060448201526064016105eb565b611cef565b805151602011611c7f5780518051602091820120604051611c2392611b8292910190815260200190565b611bf45760405162461bcd60e51b815260206004820152602760248201527f4d65726b6c65547269653a20696e76616c6964206c6172676520696e7465726e6044820152660c2d840d0c2e6d60cb1b60648201526084016105eb565b805184516020808701919091208251919092012014611cef5760405162461bcd60e51b815260206004820152602660248201527f4d65726b6c65547269653a20696e76616c696420696e7465726e616c206e6f646044820152650ca40d0c2e6d60d31b60648201526084016105eb565b611cfb6010600161359f565b81602001515103611e935784518303611e2d57611d2881602001516010815181106117d4576117d461351b565b96505f875111611da05760405162461bcd60e51b815260206004820152603b60248201527f4d65726b6c65547269653a2076616c7565206c656e677468206d75737420626560448201527f2067726561746572207468616e207a65726f20286272616e636829000000000060648201526084016105eb565b60018651611dae91906135b2565b8214611e225760405162461bcd60e51b815260206004820152603a60248201527f4d65726b6c65547269653a2076616c7565206e6f6465206d757374206265206c60448201527f617374206e6f646520696e2070726f6f6620286272616e63682900000000000060648201526084016105eb565b505050505050610b43565b5f858481518110611e4057611e4061351b565b602001015160f81c60f81b60f81c90505f82602001518260ff1681518110611e6a57611e6a61351b565b60200260200101519050611e7d81612b4b565b9550611e8a60018661359f565b94505050612250565b6002816020015151036121f7575f611eaa82612b6f565b90505f815f81518110611ebf57611ebf61351b565b016020015160f81c90505f611ed56002836135d9565b611ee09060026135fa565b90505f611ef0848360ff16612b92565b90505f611efd8a89612b92565b90505f611f0a8383612bc7565b905080835114611f825760405162461bcd60e51b815260206004820152603a60248201527f4d65726b6c65547269653a20706174682072656d61696e646572206d7573742060448201527f736861726520616c6c206e6962626c65732077697468206b657900000000000060648201526084016105eb565b60ff851660021480611f97575060ff85166003145b1561213757808251146120125760405162461bcd60e51b815260206004820152603d60248201527f4d65726b6c65547269653a206b65792072656d61696e646572206d757374206260448201527f65206964656e746963616c20746f20706174682072656d61696e64657200000060648201526084016105eb565b61202c87602001516001815181106117d4576117d461351b565b9c505f8d51116120a45760405162461bcd60e51b815260206004820152603960248201527f4d65726b6c65547269653a2076616c7565206c656e677468206d75737420626560448201527f2067726561746572207468616e207a65726f20286c656166290000000000000060648201526084016105eb565b60018c516120b291906135b2565b88146121265760405162461bcd60e51b815260206004820152603860248201527f4d65726b6c65547269653a2076616c7565206e6f6465206d757374206265206c60448201527f617374206e6f646520696e2070726f6f6620286c65616629000000000000000060648201526084016105eb565b505050505050505050505050610b43565b60ff8516158061214a575060ff85166001145b156121895761217687602001516001815181106121695761216961351b565b6020026020010151612b4b565b9950612182818a61359f565b98506121ec565b60405162461bcd60e51b815260206004820152603260248201527f4d65726b6c65547269653a2072656365697665642061206e6f64652077697468604482015271040c2dc40eadcd6dcdeeedc40e0e4caccd2f60731b60648201526084016105eb565b505050505050612250565b60405162461bcd60e51b815260206004820152602860248201527f4d65726b6c65547269653a20726563656976656420616e20756e706172736561604482015267626c65206e6f646560c01b60648201526084016105eb565b50600101611acd565b5060405162461bcd60e51b815260206004820152602560248201527f4d65726b6c65547269653a2072616e206f7574206f662070726f6f6620656c656044820152646d656e747360d81b60648201526084016105eb565b604080518082019091525f808252602082015281515f036122e457604051635ab458fb60e01b815260040160405180910390fd5b50604080518082019091528151815260209182019181019190915290565b60605f5f5f61231085612480565b91945092509050600181600181111561232b5761232b613577565b14612349576040516325ce355f60e11b815260040160405180910390fd5b8451612355838561359f565b1461237357604051630b8aa6f760e31b815260040160405180910390fd5b604080516020808252610420820190925290816020015b604080518082019091525f808252602082015281526020019060019003908161238a5790505093505f835b8651811015612474575f5f6123f96040518060400160405280858c5f01516123dd91906135b2565b8152602001858c602001516123f2919061359f565b9052612480565b509150915060405180604001604052808383612415919061359f565b8152602001848b6020015161242a919061359f565b81525088858151811061243f5761243f61351b565b602090810291909101015261245560018561359f565b9350612461818361359f565b61246b908461359f565b925050506123b5565b50845250919392505050565b5f5f5f835f01515f036124a657604051635ab458fb60e01b815260040160405180910390fd5b602084015180515f1a607f81116124c8575f60015f945094509450505061275c565b60b7811161255d575f6124dc6080836135b2565b905080875f015111612501576040516366c9448560e01b815260040160405180910390fd5b6001838101516001600160f81b031916908214801561252d5750600160ff1b6001600160f81b03198216105b1561254b5760405163babb01dd60e01b815260040160405180910390fd5b506001955093505f925061275c915050565b60bf811161263b575f61257160b7836135b2565b905080875f015111612596576040516366c9448560e01b815260040160405180910390fd5b60018301516001600160f81b0319165f8190036125c65760405163babb01dd60e01b815260040160405180910390fd5b600184015160088302610100031c603781116125f55760405163babb01dd60e01b815260040160405180910390fd5b6125ff818461359f565b89511161261f576040516366c9448560e01b815260040160405180910390fd5b61262a83600161359f565b975095505f945061275c9350505050565b60f78111612685575f61264f60c0836135b2565b905080875f015111612674576040516366c9448560e01b815260040160405180910390fd5b60019550935084925061275c915050565b5f61269160f7836135b2565b905080875f0151116126b6576040516366c9448560e01b815260040160405180910390fd5b60018301516001600160f81b0319165f8190036126e65760405163babb01dd60e01b815260040160405180910390fd5b600184015160088302610100031c603781116127155760405163babb01dd60e01b815260040160405180910390fd5b61271f818461359f565b89511161273f576040516366c9448560e01b815260040160405180910390fd5b61274a83600161359f565b975095506001945061275c9350505050565b9193909250565b6060816001600160401b0381111561277d5761277d612fc5565b6040519080825280601f01601f1916602001820160405280156127a7576020820181803683370190505b5090508115610b43575f6127bb848661359f565b9050602082015f5b848110156127db5782810151828201526020016127c3565b848111156127e9575f858301525b5050509392505050565b60605f8260405160200161280991815260200190565b60408051601f1981840301815291905290505f5b6020811015612855578181815181106128385761283861351b565b01602001516001600160f81b0319165f036128555760010161281d565b6128608160206135b2565b6001600160401b0381111561287757612877612fc5565b6040519080825280601f01601f1916602001820160405280156128a1576020820181803683370190505b5092505f5b83518110156129075782826128ba81613613565b9350815181106128cc576128cc61351b565b602001015160f81c60f81b8482815181106128e9576128e961351b565b60200101906001600160f81b03191690815f1a9053506001016128a6565b505050919050565b60608151600114801561293b57506080825f815181106129315761293161351b565b016020015160f81c105b15612944575090565b61295082516080612c4a565b82604051602001611a2c92919061362b565b5f6118d584612972878686611a42565b8051602091820120825192909101919091201490565b606083156129f65782515f036129ef576001600160a01b0385163b6129ef5760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e747261637400000060448201526064016105eb565b5081610e21565b610e218383612def565b8051606090806001600160401b03811115612a1d57612a1d612fc5565b604051908082528060200260200182016040528015612a6257816020015b6040805180820190915260608082526020820152815260200190600190039081612a3b5790505b5091505f5b81811015612ae3576040518060400160405280858381518110612a8c57612a8c61351b565b60200260200101518152602001612abb868481518110612aae57612aae61351b565b60200260200101516118de565b815250838281518110612ad057612ad061351b565b6020908102919091010152600101612a67565b5050919050565b606080604051905082518060011b603f8101601f191683016040528083525060208401602083015f5b83811015612b40578060011b8201818401515f1a8060041c8253600f811660018301535050600101612b13565b509295945050505050565b60606020825f015110612b6657612b61826118f1565b61069e565b61069e82612e19565b606061069e612b8d83602001515f815181106117d4576117d461351b565b612aea565b606082518210612bb0575060408051602081019091525f815261069e565b610b438383848651612bc291906135b2565b612e2d565b5f5f8251845110612bd9578251612bdc565b83515b90505b8082108015612c335750828281518110612bfb57612bfb61351b565b602001015160f81c60f81b6001600160f81b031916848381518110612c2257612c2261351b565b01602001516001600160f81b031916145b15612c4357816001019150612bdf565b5092915050565b60606038831015612cae5760408051600180825281830190925290602082018180368337019050509050612c7e828461363f565b60f81b815f81518110612c9357612c9361351b565b60200101906001600160f81b03191690815f1a90535061069e565b5f60015b612cbc8186613658565b15612ce25781612ccb81613613565b9250612cdb90506101008261366b565b9050612cb2565b612ced82600161359f565b6001600160401b03811115612d0457612d04612fc5565b6040519080825280601f01601f191660200182016040528015612d2e576020820181803683370190505b509250612d3b848361363f565b612d4690603761363f565b60f81b835f81518110612d5b57612d5b61351b565b60200101906001600160f81b03191690815f1a905350600190505b818111612de757610100612d8a82846135b2565b612d9690610100613765565b612da09087613658565b612daa9190613770565b60f81b838281518110612dbf57612dbf61351b565b60200101906001600160f81b03191690815f1a90535080612ddf81613613565b915050612d76565b505092915050565b815115612dff5781518083602001fd5b8060405162461bcd60e51b81526004016105eb9190613783565b606061069e82602001515f845f0151612763565b60608182601f011015612e735760405162461bcd60e51b815260206004820152600e60248201526d736c6963655f6f766572666c6f7760901b60448201526064016105eb565b828284011015612eb65760405162461bcd60e51b815260206004820152600e60248201526d736c6963655f6f766572666c6f7760901b60448201526064016105eb565b81830184511015612efd5760405162461bcd60e51b8152602060048201526011602482015270736c6963655f6f75744f66426f756e647360781b60448201526064016105eb565b606082158015612f1b5760405191505f825260208201604052612f65565b6040519150601f8416801560200281840101858101878315602002848b0101015b81831015612f54578051835260209283019201612f3c565b5050858452601f01601f1916604052505b50949350505050565b80356001600160a01b0381168114611746575f5ffd5b5f60208284031215612f94575f5ffd5b610b4382612f6e565b5f5f60408385031215612fae575f5ffd5b612fb783612f6e565b946020939093013593505050565b634e487b7160e01b5f52604160045260245ffd5b60405160c081016001600160401b0381118282101715612ffb57612ffb612fc5565b60405290565b604051601f8201601f191681016001600160401b038111828210171561302957613029612fc5565b604052919050565b5f82601f830112613040575f5ffd5b81356001600160401b0381111561305957613059612fc5565b61306c601f8201601f1916602001613001565b818152846020838601011115613080575f5ffd5b816020850160208301375f918101602001919091529392505050565b5f5f604083850312156130ad575f5ffd5b6130b683612f6e565b915060208301356001600160401b038111156130d0575f5ffd5b6130dc85828601613031565b9150509250929050565b5f602082840312156130f6575f5ffd5b5035919050565b5f6020828403121561310d575f5ffd5b813565ffffffffffff81168114610b43575f5ffd5b80356001600160401b0381168114611746575f5ffd5b5f5f5f5f5f6080868803121561314c575f5ffd5b61315586613122565b945061316360208701612f6e565b93506040860135925060608601356001600160401b03811115613184575f5ffd5b8601601f81018813613194575f5ffd5b80356001600160401b038111156131a9575f5ffd5b8860208284010111156131ba575f5ffd5b959894975092955050506020019190565b5f5f5f606084860312156131dd575f5ffd5b6131e684613122565b92506131f460208501612f6e565b929592945050506040919091013590565b5f6060828403128015613216575f5ffd5b509092915050565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b19195b1959d85d1958d85b1b60a21b606082015260800190565b6020808252602c908201527f46756e6374696f6e206d7573742062652063616c6c6564207468726f7567682060408201526b6163746976652070726f787960a01b606082015260800190565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b5f60208284031215613311575f5ffd5b5051919050565b5f6001600160401b0382111561333057613330612fc5565b5060051b60200190565b803560048110611746575f5ffd5b5f82601f830112613357575f5ffd5b813561336a61336582613318565b613001565b8082825260208201915060208360051b86010192508583111561338b575f5ffd5b602085015b838110156133cb5780356001600160401b038111156133ad575f5ffd5b6133bc886020838a0101613031565b84525060209283019201613390565b5095945050505050565b5f602082840312156133e5575f5ffd5b81356001600160401b038111156133fa575f5ffd5b8201601f8101841361340a575f5ffd5b803561341861336582613318565b8082825260208201915060208360051b850101925086831115613439575f5ffd5b602084015b8381101561184d5780356001600160401b0381111561345b575f5ffd5b850160c0818a03601f19011215613470575f5ffd5b613478612fd9565b61348460208301613122565b815261349260408301613122565b6020820152606082013560408201526134ad6080830161333a565b606082015260a08201356001600160401b038111156134ca575f5ffd5b6134d98b602083860101613348565b60808301525060c08201356001600160401b038111156134f7575f5ffd5b6135068b602083860101613348565b60a0830152508452506020928301920161343e565b634e487b7160e01b5f52603260045260245ffd5b5f81518060208401855e5f93019283525090919050565b5f610b43828461352f565b80516020808301519190811015613571575f198160200360031b1b821691505b50919050565b634e487b7160e01b5f52602160045260245ffd5b634e487b7160e01b5f52601160045260245ffd5b8082018082111561069e5761069e61358b565b8181038181111561069e5761069e61358b565b634e487b7160e01b5f52601260045260245ffd5b5f60ff8316806135eb576135eb6135c5565b8060ff84160691505092915050565b60ff828116828216039081111561069e5761069e61358b565b5f600182016136245761362461358b565b5060010190565b5f610e21613639838661352f565b8461352f565b60ff818116838216019081111561069e5761069e61358b565b5f82613666576136666135c5565b500490565b808202811582820484141761069e5761069e61358b565b6001815b60018411156136bd578085048111156136a1576136a161358b565b60018416156136af57908102905b60019390931c928002613686565b935093915050565b5f826136d35750600161069e565b816136df57505f61069e565b81600181146136f557600281146136ff5761371b565b600191505061069e565b60ff8411156137105761371061358b565b50506001821b61069e565b5060208310610133831016604e8410600b841016171561373e575081810a61069e565b61374a5f198484613682565b805f190482111561375d5761375d61358b565b029392505050565b5f610b4383836136c5565b5f8261377e5761377e6135c5565b500690565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f8301168401019150509291505056fe360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220ad5f0eb9ae284af51317b799a7dbd39b3efabbbff4df7cd4af3a48380762a45164736f6c634300081e0033
    /// ```
    #[rustfmt::skip]
    #[allow(clippy::all)]
    pub static DEPLOYED_BYTECODE: alloy_sol_types::private::Bytes = alloy_sol_types::private::Bytes::from_static(
        b"`\x80`@R`\x046\x10a\x01\x95W_5`\xE0\x1C\x80c\x80&\xB9!\x11a\0\xE7W\x80c\x9B\xCES\xB5\x11a\0\x87W\x80c\xCE\x9D\x08 \x11a\0bW\x80c\xCE\x9D\x08 \x14a\x04\xE6W\x80c\xE3\x0C9x\x14a\x05\x05W\x80c\xF2\xFD\xE3\x8B\x14a\x05\"W\x80c\xFF\xA1\xADt\x14a\x05AW__\xFD[\x80c\x9B\xCES\xB5\x14a\x04IW\x80c\x9F\xD0Pm\x14a\x04\x94W\x80c\xC9\xA0\xB8\xC8\x14a\x04\xC7W__\xFD[\x80c\x8D\xA5\xCB[\x11a\0\xC2W\x80c\x8D\xA5\xCB[\x14a\x03\xCFW\x80c\x8E\x89\x9F\x80\x14a\x03\xECW\x80c\x91\n\xF6\xED\x14a\x04\x0BW\x80c\x91\xF3\xF7K\x14a\x04*W__\xFD[\x80c\x80&\xB9!\x14a\x03^W\x80c\x84V\xCBY\x14a\x03\xA7W\x80c\x8A\xBF`w\x14a\x03\xBBW__\xFD[\x80cO\x1E\xF2\x86\x11a\x01RW\x80c\\\x97Z\xBB\x11a\x01-W\x80c\\\x97Z\xBB\x14a\x02\xF7W\x80cf\xCA+\xC0\x14a\x03\x17W\x80cqP\x18\xA6\x14a\x036W\x80cy\xBAP\x97\x14a\x03JW__\xFD[\x80cO\x1E\xF2\x86\x14a\x02\x9CW\x80cR\xD1\x90-\x14a\x02\xAFW\x80cV\xD7\xE8\xFD\x14a\x02\xD1W__\xFD[\x80c\x04\xF3\xBC\xEC\x14a\x01\x99W\x80c\x19\xABE<\x14a\x01\xE4W\x80c0u\xDBV\x14a\x02\x05W\x80c2gk\xC6\x14a\x02JW\x80c6Y\xCF\xE6\x14a\x02iW\x80c?K\xA8:\x14a\x02\x88W[__\xFD[4\x80\x15a\x01\xA4W__\xFD[P\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0[`@Q`\x01`\x01`\xA0\x1B\x03\x90\x91\x16\x81R` \x01[`@Q\x80\x91\x03\x90\xF3[4\x80\x15a\x01\xEFW__\xFD[Pa\x02\x03a\x01\xFE6`\x04a/\x84V[a\x05UV[\0[4\x80\x15a\x02\x10W__\xFD[P`\x02\x7F\xA5\x05Or\x84S\xD3\xDB\xE9S\xBD\xC4>M\x0C\xB9~f.\xA3-yX\x19\x0F=\xC2\xDA1\xD9r\x1B\\`\xFF\x16\x14[`@Q\x90\x15\x15\x81R` \x01a\x01\xDBV[4\x80\x15a\x02UW__\xFD[Pa\x02:a\x02d6`\x04a/\x9DV[a\x06\x8EV[4\x80\x15a\x02tW__\xFD[Pa\x02\x03a\x02\x836`\x04a/\x84V[a\x06\xA4V[4\x80\x15a\x02\x93W__\xFD[Pa\x02\x03a\x07kV[a\x02\x03a\x02\xAA6`\x04a0\x9CV[a\x07\xC6V[4\x80\x15a\x02\xBAW__\xFD[Pa\x02\xC3a\x08{V[`@Q\x90\x81R` \x01a\x01\xDBV[4\x80\x15a\x02\xDCW__\xFD[Pa\x01\xC7r\x0F=\xF6\xD72\x80~\xF11\x9F\xB7\xB8\xBB\x85\"\xD0\xBE\xAC\x02\x81V[4\x80\x15a\x03\x02W__\xFD[Pa\x02:`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[4\x80\x15a\x03\"W__\xFD[Pa\x02\xC3a\x0316`\x04a0\xE6V[a\t,V[4\x80\x15a\x03AW__\xFD[Pa\x02\x03a\t8V[4\x80\x15a\x03UW__\xFD[Pa\x02\x03a\tIV[4\x80\x15a\x03iW__\xFD[Pa\x03}a\x03x6`\x04a0\xFDV[a\t\xC0V[`@\x80Q\x82Qe\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x84\x01Q\x90\x82\x01R\x91\x81\x01Q\x90\x82\x01R``\x01a\x01\xDBV[4\x80\x15a\x03\xB2W__\xFD[Pa\x02\x03a\t\xF2V[4\x80\x15a\x03\xC6W__\xFD[Pa\x01\xC7a\nGV[4\x80\x15a\x03\xDAW__\xFD[P`3T`\x01`\x01`\xA0\x1B\x03\x16a\x01\xC7V[4\x80\x15a\x03\xF7W__\xFD[Pa\x02:a\x04\x066`\x04a0\xE6V[a\nUV[4\x80\x15a\x04\x16W__\xFD[Pa\x02\xC3a\x04%6`\x04a18V[a\nfV[4\x80\x15a\x045W__\xFD[Pa\x02\xC3a\x04D6`\x04a1\xCBV[a\n\xDFV[4\x80\x15a\x04TW__\xFD[Pa\x04|\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[`@Q`\x01`\x01`@\x1B\x03\x90\x91\x16\x81R` \x01a\x01\xDBV[4\x80\x15a\x04\x9FW__\xFD[Pa\x01\xC7\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x81V[4\x80\x15a\x04\xD2W__\xFD[Pa\x02\x03a\x04\xE16`\x04a2\x05V[a\x0BJV[4\x80\x15a\x04\xF1W__\xFD[Pa\x02\x03a\x05\x006`\x04a18V[a\x0C\xDAV[4\x80\x15a\x05\x10W__\xFD[P`eT`\x01`\x01`\xA0\x1B\x03\x16a\x01\xC7V[4\x80\x15a\x05-W__\xFD[Pa\x02\x03a\x05<6`\x04a/\x84V[a\x0C\xF6V[4\x80\x15a\x05LW__\xFD[Pa\x02\xC3`\x01\x81V[_Ta\x01\0\x90\x04`\xFF\x16\x15\x80\x80\x15a\x05sWP_T`\x01`\xFF\x90\x91\x16\x10[\x80a\x05\x8CWP0;\x15\x80\x15a\x05\x8CWP_T`\xFF\x16`\x01\x14[a\x05\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FInitializable: contract is alrea`D\x82\x01Rm\x19\x1EH\x1A[\x9A]\x1AX[\x1A^\x99Y`\x92\x1B`d\x82\x01R`\x84\x01[`@Q\x80\x91\x03\x90\xFD[_\x80T`\xFF\x19\x16`\x01\x17\x90U\x80\x15a\x06\x15W_\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90U[`\x01`\x01`\xA0\x1B\x03\x82\x16a\x06<W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x06E\x82a\rgV[\x80\x15a\x06\x8AW_\x80Ta\xFF\0\x19\x16\x90U`@Q`\x01\x81R\x7F\x7F&\xB8?\xF9n\x1F+jh/\x138R\xF6y\x8A\t\xC4e\xDA\x95\x92\x14`\xCE\xFB8G@$\x98\x90` \x01`@Q\x80\x91\x03\x90\xA1[PPV[_a\x06\x99\x83\x83a\r\xC5V[\x15\x15\x90P[\x92\x91PPV[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x06\xECW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\x1EV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x07\x1Ea\x0E)V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x07DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2jV[a\x07M\x81a\x0EDV[`@\x80Q_\x80\x82R` \x82\x01\x90\x92Ra\x07h\x91\x83\x91\x90a\x0ELV[PV[a\x07sa\x0F\xBBV[a\x07\x87`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[`@Q3\x81R\x7F]\xB9\xEE\nI[\xF2\xE6\xFF\x9C\x91\xA7\x83L\x1B\xA4\xFD\xD2D\xA5\xE8\xAANS{\xD3\x8A\xEA\xE4\xB0s\xAA\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x07\xC43_a\x0F\xECV[V[`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x160\x03a\x08\x0EW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\x1EV[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`\xA0\x1B\x03\x16a\x08@a\x0E)V[`\x01`\x01`\xA0\x1B\x03\x16\x14a\x08fW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2jV[a\x08o\x82a\x0EDV[a\x06\x8A\x82\x82`\x01a\x0ELV[_0`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\t\x1AW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FUUPSUpgradeable: must not be cal`D\x82\x01R\x7Fled through delegatecall\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[P_Q` a7\xB9_9_Q\x90_R\x90V[_a\x06\x9E3\x83\x84a\x10\x16V[a\t@a\x10\xE3V[a\x07\xC4_a\x11=V[`eT3\x90`\x01`\x01`\xA0\x1B\x03\x16\x81\x14a\t\xB7W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FOwnable2Step: caller is not the `D\x82\x01Rh72\xBB\x907\xBB\xB72\xB9`\xB9\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[a\x07h\x81a\x11=V[a\t\xE9`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[a\x06\x9E\x82a\x11VV[a\t\xFAa\x12\0V[`\xC9\x80Ta\xFF\0\x19\x16a\x02\0\x17\x90U`@Q3\x81R\x7Fb\xE7\x8C\xEA\x01\xBE\xE3 \xCDNB\x02p\xB5\xEAt\0\r\x11\xB0\xC9\xF7GT\xEB\xDB\xFCTK\x05\xA2X\x90` \x01`@Q\x80\x91\x03\x90\xA1a\x07\xC43`\x01a\x0F\xECV[_a\nPa\x0E)V[\x90P\x90V[_a\n^\x82T\x90V[\x15\x15\x92\x91PPV[_a\noa\x12\0V[a\n|\x86\x86\x86\x86\x86a\x122V[`\x01_\x81\x81R`\xFD` R\x7FdC\x15\x7Fw\x01\xA6'\xE51\x84\xB7O\xCE\r@?K\xF9\xBC\x1A\xAA\x0B\xC1|\x9E\xE1~\x10\xEC\x8B\x8F\x90a\n\xB4\x89\x89\x89a\n\xDFV[\x81R` \x81\x01\x91\x90\x91R`@\x01_\x90\x81 \x80T`\xFF\x19\x16\x92\x15\x15\x92\x90\x92\x17\x90\x91U\x96\x95PPPPPPV[`@Qe\x14\xD2Q\xD3\x90S`\xD2\x1B` \x82\x01R`\x01`\x01`\xC0\x1B\x03\x19`\xC0\x85\x90\x1B\x16`&\x82\x01Rk\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19``\x84\x90\x1B\x16`.\x82\x01R`B\x81\x01\x82\x90R_\x90`b\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x80Q\x90` \x01 \x90P[\x93\x92PPPV[3`\x01`\x01`\xA0\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x14a\x0B\x93W`@Qc\x1Fgu\x1F`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x0B\x9Ba\x13\xD8V[a\x0B\xB8W`@Qc\xCA\xDC\xFB\xDB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x81\x015a\x0B\xDAW`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x81\x015a\x0B\xFCW`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q\x80\x82\x01\x82R` \x80\x84\x01\x805\x83R\x92\x84\x015\x81\x83\x01R`\x01_\x90\x81R`\xFE\x90\x91R\x90\x91\x7FE|\x8AH\xB4s_V\xB98\x83~\xB0\xA8\xA5\xF9\xC5_#\xC1\xA8Wg\xCE;e\xC3\xE5\x9D=2\xB7\x91\x90a\x0CP\x90\x85a0\xFDV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x80\x82\x01\x92\x90\x92R`@\x01_ \x82Q\x81U\x91\x81\x01Q`\x01\x90\x92\x01\x91\x90\x91Ua\x0C\x85\x90\x82\x01\x82a0\xFDV[e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x7F\xF7&\xC5<\xBB\x9EbU*\xFCJ\x8F\x1B\xB1\xD0\x1F\xA9'.Rj~:i\xEB\xA9;w\x8B?B\xA6\x82` \x015\x83`@\x015`@Qa\x0C\xCF\x92\x91\x90\x91\x82R` \x82\x01R`@\x01\x90V[`@Q\x80\x91\x03\x90\xA2PV[a\x0C\xE2a\x12\0V[a\x0C\xEF\x85\x85\x85\x85\x85a\x122V[PPPPPV[a\x0C\xFEa\x10\xE3V[`e\x80T`\x01`\x01`\xA0\x1B\x03\x83\x16`\x01`\x01`\xA0\x1B\x03\x19\x90\x91\x16\x81\x17\x90\x91Ua\r/`3T`\x01`\x01`\xA0\x1B\x03\x16\x90V[`\x01`\x01`\xA0\x1B\x03\x16\x7F8\xD1k\x8C\xAC\"\xD9\x9F\xC7\xC1$\xB9\xCD\r\xE2\xD3\xFA\x1F\xAE\xF4 \xBF\xE7\x91\xD8\xC3b\xD7e\xE2'\0`@Q`@Q\x80\x91\x03\x90\xA3PV[_Ta\x01\0\x90\x04`\xFF\x16a\r\x8DW`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\xB6V[a\r\x95a\x14:V[a\r\xB3`\x01`\x01`\xA0\x1B\x03\x82\x16\x15a\r\xADW\x81a\x11=V[3a\x11=V[P`\xC9\x80Ta\xFF\0\x19\x16a\x01\0\x17\x90UV[_`\x01`\x01`\xA0\x1B\x03\x83\x16a\r\xEDW`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x81a\x0E\x0BW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x0E\x17F\x85\x85a\n\xDFV[\x90Pa\x0E!\x81T\x90V[\x94\x93PPPPV[_Q` a7\xB9_9_Q\x90_RT`\x01`\x01`\xA0\x1B\x03\x16\x90V[a\x07ha\x10\xE3V[\x7FI\x10\xFD\xFA\x16\xFE\xD3&\x0E\xD0\xE7\x14\x7F|\xC6\xDA\x11\xA6\x02\x08\xB5\xB9@m\x12\xA65aO\xFD\x91CT`\xFF\x16\x15a\x0E\x84Wa\x0E\x7F\x83a\x14`V[PPPV[\x82`\x01`\x01`\xA0\x1B\x03\x16cR\xD1\x90-`@Q\x81c\xFF\xFF\xFF\xFF\x16`\xE0\x1B\x81R`\x04\x01` `@Q\x80\x83\x03\x81\x86Z\xFA\x92PPP\x80\x15a\x0E\xDEWP`@\x80Q`\x1F=\x90\x81\x01`\x1F\x19\x16\x82\x01\x90\x92Ra\x0E\xDB\x91\x81\x01\x90a3\x01V[`\x01[a\x0FAW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FERC1967Upgrade: new implementati`D\x82\x01Rmon is not UUPS`\x90\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[_Q` a7\xB9_9_Q\x90_R\x81\x14a\x0F\xAFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`)`$\x82\x01R\x7FERC1967Upgrade: unsupported prox`D\x82\x01Rh\x1AXX\x9B\x19UURQ`\xBA\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[Pa\x0E\x7F\x83\x83\x83a\x14\xFBV[a\x0F\xCF`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[a\x07\xC4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0a\x0E\x7F\x81a\x15%V[_`\x01`\x01`\xA0\x1B\x03\x84\x16a\x10>W`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82a\x10\\W`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x81a\x10zW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x10\x85F\x85\x85a\n\xDFV[\x82\x81U`@\x80Q`\x01`\x01`\xA0\x1B\x03\x87\x16\x81R` \x81\x01\x86\x90R\x90\x81\x01\x82\x90R``\x81\x01\x84\x90R\x90\x91P\x7F\n\xD2\xD1\x08f\n!\x1FG\xBF\x7F\xB4:\x04C\xCA\xE1\x81bI\x95\xD3\xD4+\x88\xEEhy\xD2\0\xE9s\x90`\x80\x01`@Q\x80\x91\x03\x90\xA1\x93\x92PPPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14a\x07\xC4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01\x81\x90R`$\x82\x01R\x7FOwnable: caller is not the owner`D\x82\x01R`d\x01a\x05\xEBV[`e\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16\x90Ua\x07h\x81a\x15cV[a\x11\x7F`@Q\x80``\x01`@R\x80_e\xFF\xFF\xFF\xFF\xFF\xFF\x16\x81R` \x01_\x81R` \x01_\x81RP\x90V[e\xFF\xFF\xFF\xFF\xFF\xFF\x82\x16_\x90\x81R\x7FE|\x8AH\xB4s_V\xB98\x83~\xB0\xA8\xA5\xF9\xC5_#\xC1\xA8Wg\xCE;e\xC3\xE5\x9D=2\xB7` R`@\x90 \x80T\x80a\x11\xD4W`@Qc<\xA5\xD6G`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q``\x81\x01\x82Re\xFF\xFF\xFF\xFF\xFF\xFF\x90\x95\x16\x85R` \x85\x01\x91\x90\x91R`\x01\x90\x91\x01T\x90\x83\x01RP\x90V[a\x12\x14`\xC9Ta\x01\0\x90\x04`\xFF\x16`\x02\x14\x90V[\x15a\x07\xC4W`@Qc\xBA\xE6\xE2\xA9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01`\x01`\xA0\x1B\x03\x84\x16a\x12YW`@QcS\x8B\xA4\xF9`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x82a\x12wW`@Qc\xECs)Y`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x12\x83\x86\x86\x86a\n\xDFV[\x90P_\x82\x90\x03a\x12\xE0W_\x81\x81R\x7FdC\x15\x7Fw\x01\xA6'\xE51\x84\xB7O\xCE\r@?K\xF9\xBC\x1A\xAA\x0B\xC1|\x9E\xE1~\x10\xEC\x8B\x8F` R`@\x90 T`\xFF\x16a\x12\xDAW`@Qc\"\x13\x94W`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[Pa\x0C\xEFV[_a\x12\xED\x83\x85\x01\x85a3\xD5V[\x90P\x80Q`\x01\x14a\x13\x11W`@Qc\x07<\x8B\x97`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_\x81_\x81Q\x81\x10a\x13$Wa\x13$a5\x1BV[` \x02` \x01\x01Q\x90P\x80`\x80\x01QQ_\x14\x80a\x13DWP`\xA0\x81\x01QQ\x15[\x15a\x13bW`@Qc\x0B\x92\xDA\xEF`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x13p\x82` \x01Qa\x15\xB4V[\x90P\x81`@\x01Q\x81\x14a\x13\x96W`@Qcb\xD1k\x9D`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x13\xCC\x81\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x86\x8A\x86`\x80\x01Q\x87`\xA0\x01Qa\x17KV[PPPPPPPPPPV[_`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16\x15\x80a\nPWPP`\x01`\x01`@\x1B\x03\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x16B\x10\x90V[_Ta\x01\0\x90\x04`\xFF\x16a\x07\xC4W`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x90a2\xB6V[`\x01`\x01`\xA0\x1B\x03\x81\x16;a\x14\xCDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`-`$\x82\x01R\x7FERC1967: new implementation is n`D\x82\x01Rl\x1B\xDD\x08\x18H\x18\xDB\xDB\x9D\x1C\x98X\xDD`\x9A\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[_Q` a7\xB9_9_Q\x90_R\x80T`\x01`\x01`\xA0\x1B\x03\x19\x16`\x01`\x01`\xA0\x1B\x03\x92\x90\x92\x16\x91\x90\x91\x17\x90UV[a\x15\x04\x83a\x18XV[_\x82Q\x11\x80a\x15\x10WP\x80[\x15a\x0E\x7FWa\x15\x1F\x83\x83a\x18\x97V[PPPPV[`3T`\x01`\x01`\xA0\x1B\x03\x163\x14\x80a\x15FWP3`\x01`\x01`\xA0\x1B\x03\x82\x16\x14[a\x07hW`@Qc\x958>\xA1`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`3\x80T`\x01`\x01`\xA0\x1B\x03\x83\x81\x16`\x01`\x01`\xA0\x1B\x03\x19\x83\x16\x81\x17\x90\x93U`@Q\x91\x16\x91\x90\x82\x90\x7F\x8B\xE0\x07\x9CS\x16Y\x14\x13D\xCD\x1F\xD0\xA4\xF2\x84\x19I\x7F\x97\"\xA3\xDA\xAF\xE3\xB4\x18okdW\xE0\x90_\x90\xA3PPV[_a\x15\xBDa\x13\xD8V[\x15a\x16\x06We\xFF\xFF\xFF\xFF\xFF\xFF`\x01`\x01`@\x1B\x03\x83\x16\x11\x15a\x15\xF2W`@Qcx\xB5\x90K`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x15\xFB\x82a\x11VV[`@\x01Q\x90Pa\x17(V[\x7F\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\x01`\x01`@\x1B\x03\x16\x82`\x01`\x01`@\x1B\x03\x16\x10\x15a\x16YW`@Qcx\xB5\x90K`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q`\x01`\x01`@\x1B\x03\x84\x16` \x82\x01R_\x91\x82\x91r\x0F=\xF6\xD72\x80~\xF11\x9F\xB7\xB8\xBB\x85\"\xD0\xBE\xAC\x02\x91\x01`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x90\x82\x90Ra\x16\xA0\x91a5FV[_`@Q\x80\x83\x03\x81\x85Z\xFA\x91PP=\x80_\x81\x14a\x16\xD8W`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x16\xDDV[``\x91P[P\x91P\x91P\x81\x15\x80a\x16\xF1WP\x80Q` \x14\x15[\x15a\x17\x0FW`@QcT3\xB2}`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x80\x80` \x01\x90Q\x81\x01\x90a\x17#\x91\x90a3\x01V[\x92PPP[\x80a\x17FW`@QcT3\xB2}`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x91\x90PV[_\x82Q_\x14a\x17\xF3W`@Qk\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x19``\x88\x90\x1B\x16` \x82\x01R_\x90a\x17\x8F\x90`4\x01`@Q` \x81\x83\x03\x03\x81R\x90`@R\x85\x8Aa\x18\xBCV[\x90P\x80Q_\x03a\x17\xB2W`@Qc\x04\x14\xCD[`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[_a\x17\xBC\x82a\x18\xDEV[\x90Pa\x17\xE1\x81`\x02\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[` \x02` \x01\x01Qa\x18\xF1V[a\x17\xEA\x90a5QV[\x92PPPa\x17\xF6V[P\x85[_a\x18-\x86`@Q` \x01a\x18\r\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90Ra\x18&\x87a\x19pV[\x85\x85a\x19\x83V[\x90P\x80a\x18MW`@Qc\x8D\x9AM\xB3`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P\x96\x95PPPPPPV[a\x18a\x81a\x14`V[`@Q`\x01`\x01`\xA0\x1B\x03\x82\x16\x90\x7F\xBC|\xD7Z \xEE'\xFD\x9A\xDE\xBA\xB3 A\xF7U!M\xBCk\xFF\xA9\x0C\xC0\"[9\xDA.\\-;\x90_\x90\xA2PV[``a\x0BC\x83\x83`@Q\x80``\x01`@R\x80`'\x81R` \x01a7\xD9`'\x919a\x19\xA6V[``_a\x18\xC8\x85a\x1A\x10V[\x90Pa\x18\xD5\x81\x85\x85a\x1ABV[\x95\x94PPPPPV[``a\x06\x9Ea\x18\xEC\x83a\"\xB0V[a#\x02V[``___a\x18\xFF\x85a$\x80V[\x91\x94P\x92P\x90P_\x81`\x01\x81\x11\x15a\x19\x19Wa\x19\x19a5wV[\x14a\x197W`@Qc\x07\xFEl\xB9`\xE2\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x19A\x82\x84a5\x9FV[\x85Q\x14a\x19aW`@Qc\x0B\x8A\xA6\xF7`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a\x18\xD5\x85` \x01Q\x84\x84a'cV[``a\x06\x9Ea\x19~\x83a'\xF3V[a)\x0FV[__a\x19\x8E\x86a\x1A\x10V[\x90Pa\x19\x9C\x81\x86\x86\x86a)bV[\x96\x95PPPPPPV[``__\x85`\x01`\x01`\xA0\x1B\x03\x16\x85`@Qa\x19\xC2\x91\x90a5FV[_`@Q\x80\x83\x03\x81\x85Z\xF4\x91PP=\x80_\x81\x14a\x19\xFAW`@Q\x91P`\x1F\x19`?=\x01\x16\x82\x01`@R=\x82R=_` \x84\x01>a\x19\xFFV[``\x91P[P\x91P\x91Pa\x19\x9C\x86\x83\x83\x87a)\x88V[``\x81\x80Q\x90` \x01 `@Q` \x01a\x1A,\x91\x81R` \x01\x90V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x90P\x91\x90PV[``_\x84Q\x11a\x1A\x8CW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x15`$\x82\x01RtMerkleTrie: empty key`X\x1B`D\x82\x01R`d\x01a\x05\xEBV[_a\x1A\x96\x84a*\0V[\x90P_a\x1A\xA2\x86a*\xEAV[\x90P_\x84`@Q` \x01a\x1A\xB8\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x90P_\x80[\x84Q\x81\x10\x15a\"YW_\x85\x82\x81Q\x81\x10a\x1A\xE9Wa\x1A\xE9a5\x1BV[` \x02` \x01\x01Q\x90P\x84Q\x83\x11\x15a\x1B[W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`.`$\x82\x01R\x7FMerkleTrie: key index exceeds to`D\x82\x01Rm\x0E\x8C-\x84\rl\xAF$\r\x8C\xAD\xCC\xEE\x8D`\x93\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[\x82_\x03a\x1B\xF9W\x80Q\x80Q` \x91\x82\x01 `@Qa\x1B\xA8\x92a\x1B\x82\x92\x91\x01\x90\x81R` \x01\x90V[`@Q` \x81\x83\x03\x03\x81R\x90`@R\x85\x80Q` \x91\x82\x01 \x82Q\x92\x90\x91\x01\x91\x90\x91 \x14\x90V[a\x1B\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FMerkleTrie: invalid root hash\0\0\0`D\x82\x01R`d\x01a\x05\xEBV[a\x1C\xEFV[\x80QQ` \x11a\x1C\x7FW\x80Q\x80Q` \x91\x82\x01 `@Qa\x1C#\x92a\x1B\x82\x92\x91\x01\x90\x81R` \x01\x90V[a\x1B\xF4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`'`$\x82\x01R\x7FMerkleTrie: invalid large intern`D\x82\x01Rf\x0C-\x84\r\x0C.m`\xCB\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[\x80Q\x84Q` \x80\x87\x01\x91\x90\x91 \x82Q\x91\x90\x92\x01 \x14a\x1C\xEFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`&`$\x82\x01R\x7FMerkleTrie: invalid internal nod`D\x82\x01Re\x0C\xA4\r\x0C.m`\xD3\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[a\x1C\xFB`\x10`\x01a5\x9FV[\x81` \x01QQ\x03a\x1E\x93W\x84Q\x83\x03a\x1E-Wa\x1D(\x81` \x01Q`\x10\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[\x96P_\x87Q\x11a\x1D\xA0W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`;`$\x82\x01R\x7FMerkleTrie: value length must be`D\x82\x01R\x7F greater than zero (branch)\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\x01\x86Qa\x1D\xAE\x91\x90a5\xB2V[\x82\x14a\x1E\"W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`:`$\x82\x01R\x7FMerkleTrie: value node must be l`D\x82\x01R\x7Fast node in proof (branch)\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPa\x0BCV[_\x85\x84\x81Q\x81\x10a\x1E@Wa\x1E@a5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B`\xF8\x1C\x90P_\x82` \x01Q\x82`\xFF\x16\x81Q\x81\x10a\x1EjWa\x1Eja5\x1BV[` \x02` \x01\x01Q\x90Pa\x1E}\x81a+KV[\x95Pa\x1E\x8A`\x01\x86a5\x9FV[\x94PPPa\"PV[`\x02\x81` \x01QQ\x03a!\xF7W_a\x1E\xAA\x82a+oV[\x90P_\x81_\x81Q\x81\x10a\x1E\xBFWa\x1E\xBFa5\x1BV[\x01` \x01Q`\xF8\x1C\x90P_a\x1E\xD5`\x02\x83a5\xD9V[a\x1E\xE0\x90`\x02a5\xFAV[\x90P_a\x1E\xF0\x84\x83`\xFF\x16a+\x92V[\x90P_a\x1E\xFD\x8A\x89a+\x92V[\x90P_a\x1F\n\x83\x83a+\xC7V[\x90P\x80\x83Q\x14a\x1F\x82W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`:`$\x82\x01R\x7FMerkleTrie: path remainder must `D\x82\x01R\x7Fshare all nibbles with key\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\xFF\x85\x16`\x02\x14\x80a\x1F\x97WP`\xFF\x85\x16`\x03\x14[\x15a!7W\x80\x82Q\x14a \x12W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`=`$\x82\x01R\x7FMerkleTrie: key remainder must b`D\x82\x01R\x7Fe identical to path remainder\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[a ,\x87` \x01Q`\x01\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[\x9CP_\x8DQ\x11a \xA4W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`9`$\x82\x01R\x7FMerkleTrie: value length must be`D\x82\x01R\x7F greater than zero (leaf)\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[`\x01\x8CQa \xB2\x91\x90a5\xB2V[\x88\x14a!&W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`8`$\x82\x01R\x7FMerkleTrie: value node must be l`D\x82\x01R\x7Fast node in proof (leaf)\0\0\0\0\0\0\0\0`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPPPPPPPa\x0BCV[`\xFF\x85\x16\x15\x80a!JWP`\xFF\x85\x16`\x01\x14[\x15a!\x89Wa!v\x87` \x01Q`\x01\x81Q\x81\x10a!iWa!ia5\x1BV[` \x02` \x01\x01Qa+KV[\x99Pa!\x82\x81\x8Aa5\x9FV[\x98Pa!\xECV[`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`2`$\x82\x01R\x7FMerkleTrie: received a node with`D\x82\x01Rq\x04\x0C-\xC4\x0E\xAD\xCDm\xCD\xEE\xED\xC4\x0E\x0EL\xAC\xCD/`s\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[PPPPPPa\"PV[`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`(`$\x82\x01R\x7FMerkleTrie: received an unparsea`D\x82\x01Rgble node`\xC0\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[P`\x01\x01a\x1A\xCDV[P`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`%`$\x82\x01R\x7FMerkleTrie: ran out of proof ele`D\x82\x01Rdments`\xD8\x1B`d\x82\x01R`\x84\x01a\x05\xEBV[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81Q_\x03a\"\xE4W`@QcZ\xB4X\xFB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P`@\x80Q\x80\x82\x01\x90\x91R\x81Q\x81R` \x91\x82\x01\x91\x81\x01\x91\x90\x91R\x90V[``___a#\x10\x85a$\x80V[\x91\x94P\x92P\x90P`\x01\x81`\x01\x81\x11\x15a#+Wa#+a5wV[\x14a#IW`@Qc%\xCE5_`\xE1\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[\x84Qa#U\x83\x85a5\x9FV[\x14a#sW`@Qc\x0B\x8A\xA6\xF7`\xE3\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`@\x80Q` \x80\x82Ra\x04 \x82\x01\x90\x92R\x90\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R_\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a#\x8AW\x90PP\x93P_\x83[\x86Q\x81\x10\x15a$tW__a#\xF9`@Q\x80`@\x01`@R\x80\x85\x8C_\x01Qa#\xDD\x91\x90a5\xB2V[\x81R` \x01\x85\x8C` \x01Qa#\xF2\x91\x90a5\x9FV[\x90Ra$\x80V[P\x91P\x91P`@Q\x80`@\x01`@R\x80\x83\x83a$\x15\x91\x90a5\x9FV[\x81R` \x01\x84\x8B` \x01Qa$*\x91\x90a5\x9FV[\x81RP\x88\x85\x81Q\x81\x10a$?Wa$?a5\x1BV[` \x90\x81\x02\x91\x90\x91\x01\x01Ra$U`\x01\x85a5\x9FV[\x93Pa$a\x81\x83a5\x9FV[a$k\x90\x84a5\x9FV[\x92PPPa#\xB5V[P\x84RP\x91\x93\x92PPPV[___\x83_\x01Q_\x03a$\xA6W`@QcZ\xB4X\xFB`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[` \x84\x01Q\x80Q_\x1A`\x7F\x81\x11a$\xC8W_`\x01_\x94P\x94P\x94PPPa'\\V[`\xB7\x81\x11a%]W_a$\xDC`\x80\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a%\x01W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x81\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x82\x14\x80\x15a%-WP`\x01`\xFF\x1B`\x01`\x01`\xF8\x1B\x03\x19\x82\x16\x10[\x15a%KW`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[P`\x01\x95P\x93P_\x92Pa'\\\x91PPV[`\xBF\x81\x11a&;W_a%q`\xB7\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a%\x96W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x81\x90\x03a%\xC6W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x84\x01Q`\x08\x83\x02a\x01\0\x03\x1C`7\x81\x11a%\xF5W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a%\xFF\x81\x84a5\x9FV[\x89Q\x11a&\x1FW`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a&*\x83`\x01a5\x9FV[\x97P\x95P_\x94Pa'\\\x93PPPPV[`\xF7\x81\x11a&\x85W_a&O`\xC0\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a&tW`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x95P\x93P\x84\x92Pa'\\\x91PPV[_a&\x91`\xF7\x83a5\xB2V[\x90P\x80\x87_\x01Q\x11a&\xB6W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x83\x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x81\x90\x03a&\xE6W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[`\x01\x84\x01Q`\x08\x83\x02a\x01\0\x03\x1C`7\x81\x11a'\x15W`@Qc\xBA\xBB\x01\xDD`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a'\x1F\x81\x84a5\x9FV[\x89Q\x11a'?W`@Qcf\xC9D\x85`\xE0\x1B\x81R`\x04\x01`@Q\x80\x91\x03\x90\xFD[a'J\x83`\x01a5\x9FV[\x97P\x95P`\x01\x94Pa'\\\x93PPPPV[\x91\x93\x90\x92PV[``\x81`\x01`\x01`@\x1B\x03\x81\x11\x15a'}Wa'}a/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a'\xA7W` \x82\x01\x81\x806\x837\x01\x90P[P\x90P\x81\x15a\x0BCW_a'\xBB\x84\x86a5\x9FV[\x90P` \x82\x01_[\x84\x81\x10\x15a'\xDBW\x82\x81\x01Q\x82\x82\x01R` \x01a'\xC3V[\x84\x81\x11\x15a'\xE9W_\x85\x83\x01R[PPP\x93\x92PPPV[``_\x82`@Q` \x01a(\t\x91\x81R` \x01\x90V[`@\x80Q`\x1F\x19\x81\x84\x03\x01\x81R\x91\x90R\x90P_[` \x81\x10\x15a(UW\x81\x81\x81Q\x81\x10a(8Wa(8a5\x1BV[\x01` \x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16_\x03a(UW`\x01\x01a(\x1DV[a(`\x81` a5\xB2V[`\x01`\x01`@\x1B\x03\x81\x11\x15a(wWa(wa/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a(\xA1W` \x82\x01\x81\x806\x837\x01\x90P[P\x92P_[\x83Q\x81\x10\x15a)\x07W\x82\x82a(\xBA\x81a6\x13V[\x93P\x81Q\x81\x10a(\xCCWa(\xCCa5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B\x84\x82\x81Q\x81\x10a(\xE9Wa(\xE9a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP`\x01\x01a(\xA6V[PPP\x91\x90PV[``\x81Q`\x01\x14\x80\x15a);WP`\x80\x82_\x81Q\x81\x10a)1Wa)1a5\x1BV[\x01` \x01Q`\xF8\x1C\x10[\x15a)DWP\x90V[a)P\x82Q`\x80a,JV[\x82`@Q` \x01a\x1A,\x92\x91\x90a6+V[_a\x18\xD5\x84a)r\x87\x86\x86a\x1ABV[\x80Q` \x91\x82\x01 \x82Q\x92\x90\x91\x01\x91\x90\x91 \x14\x90V[``\x83\x15a)\xF6W\x82Q_\x03a)\xEFW`\x01`\x01`\xA0\x1B\x03\x85\x16;a)\xEFW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x1D`$\x82\x01R\x7FAddress: call to non-contract\0\0\0`D\x82\x01R`d\x01a\x05\xEBV[P\x81a\x0E!V[a\x0E!\x83\x83a-\xEFV[\x80Q``\x90\x80`\x01`\x01`@\x1B\x03\x81\x11\x15a*\x1DWa*\x1Da/\xC5V[`@Q\x90\x80\x82R\x80` \x02` \x01\x82\x01`@R\x80\x15a*bW\x81` \x01[`@\x80Q\x80\x82\x01\x90\x91R``\x80\x82R` \x82\x01R\x81R` \x01\x90`\x01\x90\x03\x90\x81a*;W\x90P[P\x91P_[\x81\x81\x10\x15a*\xE3W`@Q\x80`@\x01`@R\x80\x85\x83\x81Q\x81\x10a*\x8CWa*\x8Ca5\x1BV[` \x02` \x01\x01Q\x81R` \x01a*\xBB\x86\x84\x81Q\x81\x10a*\xAEWa*\xAEa5\x1BV[` \x02` \x01\x01Qa\x18\xDEV[\x81RP\x83\x82\x81Q\x81\x10a*\xD0Wa*\xD0a5\x1BV[` \x90\x81\x02\x91\x90\x91\x01\x01R`\x01\x01a*gV[PP\x91\x90PV[``\x80`@Q\x90P\x82Q\x80`\x01\x1B`?\x81\x01`\x1F\x19\x16\x83\x01`@R\x80\x83RP` \x84\x01` \x83\x01_[\x83\x81\x10\x15a+@W\x80`\x01\x1B\x82\x01\x81\x84\x01Q_\x1A\x80`\x04\x1C\x82S`\x0F\x81\x16`\x01\x83\x01SPP`\x01\x01a+\x13V[P\x92\x95\x94PPPPPV[``` \x82_\x01Q\x10a+fWa+a\x82a\x18\xF1V[a\x06\x9EV[a\x06\x9E\x82a.\x19V[``a\x06\x9Ea+\x8D\x83` \x01Q_\x81Q\x81\x10a\x17\xD4Wa\x17\xD4a5\x1BV[a*\xEAV[``\x82Q\x82\x10a+\xB0WP`@\x80Q` \x81\x01\x90\x91R_\x81Ra\x06\x9EV[a\x0BC\x83\x83\x84\x86Qa+\xC2\x91\x90a5\xB2V[a.-V[__\x82Q\x84Q\x10a+\xD9W\x82Qa+\xDCV[\x83Q[\x90P[\x80\x82\x10\x80\x15a,3WP\x82\x82\x81Q\x81\x10a+\xFBWa+\xFBa5\x1BV[` \x01\x01Q`\xF8\x1C`\xF8\x1B`\x01`\x01`\xF8\x1B\x03\x19\x16\x84\x83\x81Q\x81\x10a,\"Wa,\"a5\x1BV[\x01` \x01Q`\x01`\x01`\xF8\x1B\x03\x19\x16\x14[\x15a,CW\x81`\x01\x01\x91Pa+\xDFV[P\x92\x91PPV[```8\x83\x10\x15a,\xAEW`@\x80Q`\x01\x80\x82R\x81\x83\x01\x90\x92R\x90` \x82\x01\x81\x806\x837\x01\x90PP\x90Pa,~\x82\x84a6?V[`\xF8\x1B\x81_\x81Q\x81\x10a,\x93Wa,\x93a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SPa\x06\x9EV[_`\x01[a,\xBC\x81\x86a6XV[\x15a,\xE2W\x81a,\xCB\x81a6\x13V[\x92Pa,\xDB\x90Pa\x01\0\x82a6kV[\x90Pa,\xB2V[a,\xED\x82`\x01a5\x9FV[`\x01`\x01`@\x1B\x03\x81\x11\x15a-\x04Wa-\x04a/\xC5V[`@Q\x90\x80\x82R\x80`\x1F\x01`\x1F\x19\x16` \x01\x82\x01`@R\x80\x15a-.W` \x82\x01\x81\x806\x837\x01\x90P[P\x92Pa-;\x84\x83a6?V[a-F\x90`7a6?V[`\xF8\x1B\x83_\x81Q\x81\x10a-[Wa-[a5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP`\x01\x90P[\x81\x81\x11a-\xE7Wa\x01\0a-\x8A\x82\x84a5\xB2V[a-\x96\x90a\x01\0a7eV[a-\xA0\x90\x87a6XV[a-\xAA\x91\x90a7pV[`\xF8\x1B\x83\x82\x81Q\x81\x10a-\xBFWa-\xBFa5\x1BV[` \x01\x01\x90`\x01`\x01`\xF8\x1B\x03\x19\x16\x90\x81_\x1A\x90SP\x80a-\xDF\x81a6\x13V[\x91PPa-vV[PP\x92\x91PPV[\x81Q\x15a-\xFFW\x81Q\x80\x83` \x01\xFD[\x80`@QbF\x1B\xCD`\xE5\x1B\x81R`\x04\x01a\x05\xEB\x91\x90a7\x83V[``a\x06\x9E\x82` \x01Q_\x84_\x01Qa'cV[``\x81\x82`\x1F\x01\x10\x15a.sW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x0E`$\x82\x01Rmslice_overflow`\x90\x1B`D\x82\x01R`d\x01a\x05\xEBV[\x82\x82\x84\x01\x10\x15a.\xB6W`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x0E`$\x82\x01Rmslice_overflow`\x90\x1B`D\x82\x01R`d\x01a\x05\xEBV[\x81\x83\x01\x84Q\x10\x15a.\xFDW`@QbF\x1B\xCD`\xE5\x1B\x81R` `\x04\x82\x01R`\x11`$\x82\x01Rpslice_outOfBounds`x\x1B`D\x82\x01R`d\x01a\x05\xEBV[``\x82\x15\x80\x15a/\x1BW`@Q\x91P_\x82R` \x82\x01`@Ra/eV[`@Q\x91P`\x1F\x84\x16\x80\x15` \x02\x81\x84\x01\x01\x85\x81\x01\x87\x83\x15` \x02\x84\x8B\x01\x01\x01[\x81\x83\x10\x15a/TW\x80Q\x83R` \x92\x83\x01\x92\x01a/<V[PP\x85\x84R`\x1F\x01`\x1F\x19\x16`@RP[P\x94\x93PPPPV[\x805`\x01`\x01`\xA0\x1B\x03\x81\x16\x81\x14a\x17FW__\xFD[_` \x82\x84\x03\x12\x15a/\x94W__\xFD[a\x0BC\x82a/nV[__`@\x83\x85\x03\x12\x15a/\xAEW__\xFD[a/\xB7\x83a/nV[\x94` \x93\x90\x93\x015\x93PPPV[cNH{q`\xE0\x1B_R`A`\x04R`$_\xFD[`@Q`\xC0\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a/\xFBWa/\xFBa/\xC5V[`@R\x90V[`@Q`\x1F\x82\x01`\x1F\x19\x16\x81\x01`\x01`\x01`@\x1B\x03\x81\x11\x82\x82\x10\x17\x15a0)Wa0)a/\xC5V[`@R\x91\x90PV[_\x82`\x1F\x83\x01\x12a0@W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a0YWa0Ya/\xC5V[a0l`\x1F\x82\x01`\x1F\x19\x16` \x01a0\x01V[\x81\x81R\x84` \x83\x86\x01\x01\x11\x15a0\x80W__\xFD[\x81` \x85\x01` \x83\x017_\x91\x81\x01` \x01\x91\x90\x91R\x93\x92PPPV[__`@\x83\x85\x03\x12\x15a0\xADW__\xFD[a0\xB6\x83a/nV[\x91P` \x83\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a0\xD0W__\xFD[a0\xDC\x85\x82\x86\x01a01V[\x91PP\x92P\x92\x90PV[_` \x82\x84\x03\x12\x15a0\xF6W__\xFD[P5\x91\x90PV[_` \x82\x84\x03\x12\x15a1\rW__\xFD[\x815e\xFF\xFF\xFF\xFF\xFF\xFF\x81\x16\x81\x14a\x0BCW__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x16\x81\x14a\x17FW__\xFD[_____`\x80\x86\x88\x03\x12\x15a1LW__\xFD[a1U\x86a1\"V[\x94Pa1c` \x87\x01a/nV[\x93P`@\x86\x015\x92P``\x86\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a1\x84W__\xFD[\x86\x01`\x1F\x81\x01\x88\x13a1\x94W__\xFD[\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a1\xA9W__\xFD[\x88` \x82\x84\x01\x01\x11\x15a1\xBAW__\xFD[\x95\x98\x94\x97P\x92\x95PPP` \x01\x91\x90V[___``\x84\x86\x03\x12\x15a1\xDDW__\xFD[a1\xE6\x84a1\"V[\x92Pa1\xF4` \x85\x01a/nV[\x92\x95\x92\x94PPP`@\x91\x90\x91\x015\x90V[_``\x82\x84\x03\x12\x80\x15a2\x16W__\xFD[P\x90\x92\x91PPV[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rk\x19\x19[\x19Y\xD8]\x19X\xD8[\x1B`\xA2\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`,\x90\x82\x01R\x7FFunction must be called through `@\x82\x01Rkactive proxy`\xA0\x1B``\x82\x01R`\x80\x01\x90V[` \x80\x82R`+\x90\x82\x01R\x7FInitializable: contract is not i`@\x82\x01Rjnitializing`\xA8\x1B``\x82\x01R`\x80\x01\x90V[_` \x82\x84\x03\x12\x15a3\x11W__\xFD[PQ\x91\x90PV[_`\x01`\x01`@\x1B\x03\x82\x11\x15a30Wa30a/\xC5V[P`\x05\x1B` \x01\x90V[\x805`\x04\x81\x10a\x17FW__\xFD[_\x82`\x1F\x83\x01\x12a3WW__\xFD[\x815a3ja3e\x82a3\x18V[a0\x01V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x86\x01\x01\x92P\x85\x83\x11\x15a3\x8BW__\xFD[` \x85\x01[\x83\x81\x10\x15a3\xCBW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xADW__\xFD[a3\xBC\x88` \x83\x8A\x01\x01a01V[\x84RP` \x92\x83\x01\x92\x01a3\x90V[P\x95\x94PPPPPV[_` \x82\x84\x03\x12\x15a3\xE5W__\xFD[\x815`\x01`\x01`@\x1B\x03\x81\x11\x15a3\xFAW__\xFD[\x82\x01`\x1F\x81\x01\x84\x13a4\nW__\xFD[\x805a4\x18a3e\x82a3\x18V[\x80\x82\x82R` \x82\x01\x91P` \x83`\x05\x1B\x85\x01\x01\x92P\x86\x83\x11\x15a49W__\xFD[` \x84\x01[\x83\x81\x10\x15a\x18MW\x805`\x01`\x01`@\x1B\x03\x81\x11\x15a4[W__\xFD[\x85\x01`\xC0\x81\x8A\x03`\x1F\x19\x01\x12\x15a4pW__\xFD[a4xa/\xD9V[a4\x84` \x83\x01a1\"V[\x81Ra4\x92`@\x83\x01a1\"V[` \x82\x01R``\x82\x015`@\x82\x01Ra4\xAD`\x80\x83\x01a3:V[``\x82\x01R`\xA0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xCAW__\xFD[a4\xD9\x8B` \x83\x86\x01\x01a3HV[`\x80\x83\x01RP`\xC0\x82\x015`\x01`\x01`@\x1B\x03\x81\x11\x15a4\xF7W__\xFD[a5\x06\x8B` \x83\x86\x01\x01a3HV[`\xA0\x83\x01RP\x84RP` \x92\x83\x01\x92\x01a4>V[cNH{q`\xE0\x1B_R`2`\x04R`$_\xFD[_\x81Q\x80` \x84\x01\x85^_\x93\x01\x92\x83RP\x90\x91\x90PV[_a\x0BC\x82\x84a5/V[\x80Q` \x80\x83\x01Q\x91\x90\x81\x10\x15a5qW_\x19\x81` \x03`\x03\x1B\x1B\x82\x16\x91P[P\x91\x90PV[cNH{q`\xE0\x1B_R`!`\x04R`$_\xFD[cNH{q`\xE0\x1B_R`\x11`\x04R`$_\xFD[\x80\x82\x01\x80\x82\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[\x81\x81\x03\x81\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[cNH{q`\xE0\x1B_R`\x12`\x04R`$_\xFD[_`\xFF\x83\x16\x80a5\xEBWa5\xEBa5\xC5V[\x80`\xFF\x84\x16\x06\x91PP\x92\x91PPV[`\xFF\x82\x81\x16\x82\x82\x16\x03\x90\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[_`\x01\x82\x01a6$Wa6$a5\x8BV[P`\x01\x01\x90V[_a\x0E!a69\x83\x86a5/V[\x84a5/V[`\xFF\x81\x81\x16\x83\x82\x16\x01\x90\x81\x11\x15a\x06\x9EWa\x06\x9Ea5\x8BV[_\x82a6fWa6fa5\xC5V[P\x04\x90V[\x80\x82\x02\x81\x15\x82\x82\x04\x84\x14\x17a\x06\x9EWa\x06\x9Ea5\x8BV[`\x01\x81[`\x01\x84\x11\x15a6\xBDW\x80\x85\x04\x81\x11\x15a6\xA1Wa6\xA1a5\x8BV[`\x01\x84\x16\x15a6\xAFW\x90\x81\x02\x90[`\x01\x93\x90\x93\x1C\x92\x80\x02a6\x86V[\x93P\x93\x91PPV[_\x82a6\xD3WP`\x01a\x06\x9EV[\x81a6\xDFWP_a\x06\x9EV[\x81`\x01\x81\x14a6\xF5W`\x02\x81\x14a6\xFFWa7\x1BV[`\x01\x91PPa\x06\x9EV[`\xFF\x84\x11\x15a7\x10Wa7\x10a5\x8BV[PP`\x01\x82\x1Ba\x06\x9EV[P` \x83\x10a\x013\x83\x10\x16`N\x84\x10`\x0B\x84\x10\x16\x17\x15a7>WP\x81\x81\na\x06\x9EV[a7J_\x19\x84\x84a6\x82V[\x80_\x19\x04\x82\x11\x15a7]Wa7]a5\x8BV[\x02\x93\x92PPPV[_a\x0BC\x83\x83a6\xC5V[_\x82a7~Wa7~a5\xC5V[P\x06\x90V[` \x81R_\x82Q\x80` \x84\x01R\x80` \x85\x01`@\x85\x01^_`@\x82\x85\x01\x01R`@`\x1F\x19`\x1F\x83\x01\x16\x84\x01\x01\x91PP\x92\x91PPV\xFE6\x08\x94\xA1;\xA1\xA3!\x06g\xC8(I-\xB9\x8D\xCA> v\xCC75\xA9 \xA3\xCAP]8+\xBCAddress: low-level delegate call failed\xA2dipfsX\"\x12 \xAD_\x0E\xB9\xAE(J\xF5\x13\x17\xB7\x99\xA7\xDB\xD3\x9B>\xFA\xBB\xBF\xF4\xDF|\xD4\xAF:H8\x07b\xA4QdsolcC\0\x08\x1E\x003",
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
    /**Custom error with signature `ContentLengthMismatch()` and selector `0x66c94485`.
```solidity
error ContentLengthMismatch();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct ContentLengthMismatch;
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
        impl ::core::convert::From<ContentLengthMismatch> for UnderlyingRustTuple<'_> {
            fn from(value: ContentLengthMismatch) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for ContentLengthMismatch {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for ContentLengthMismatch {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "ContentLengthMismatch()";
            const SELECTOR: [u8; 4] = [102u8, 201u8, 68u8, 133u8];
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
    /**Custom error with signature `EmptyItem()` and selector `0x5ab458fb`.
```solidity
error EmptyItem();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct EmptyItem;
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
        impl ::core::convert::From<EmptyItem> for UnderlyingRustTuple<'_> {
            fn from(value: EmptyItem) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for EmptyItem {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for EmptyItem {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "EmptyItem()";
            const SELECTOR: [u8; 4] = [90u8, 180u8, 88u8, 251u8];
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
    /**Custom error with signature `InvalidDataRemainder()` and selector `0x5c5537b8`.
```solidity
error InvalidDataRemainder();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidDataRemainder;
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
        impl ::core::convert::From<InvalidDataRemainder> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidDataRemainder) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidDataRemainder {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidDataRemainder {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidDataRemainder()";
            const SELECTOR: [u8; 4] = [92u8, 85u8, 55u8, 184u8];
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
    /**Custom error with signature `InvalidHeader()` and selector `0xbabb01dd`.
```solidity
error InvalidHeader();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct InvalidHeader;
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
        impl ::core::convert::From<InvalidHeader> for UnderlyingRustTuple<'_> {
            fn from(value: InvalidHeader) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for InvalidHeader {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for InvalidHeader {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "InvalidHeader()";
            const SELECTOR: [u8; 4] = [186u8, 187u8, 1u8, 221u8];
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
    /**Custom error with signature `LTP_INVALID_ACCOUNT_PROOF()` and selector `0x20a66ad8`.
```solidity
error LTP_INVALID_ACCOUNT_PROOF();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LTP_INVALID_ACCOUNT_PROOF;
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
        impl ::core::convert::From<LTP_INVALID_ACCOUNT_PROOF>
        for UnderlyingRustTuple<'_> {
            fn from(value: LTP_INVALID_ACCOUNT_PROOF) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for LTP_INVALID_ACCOUNT_PROOF {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for LTP_INVALID_ACCOUNT_PROOF {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "LTP_INVALID_ACCOUNT_PROOF()";
            const SELECTOR: [u8; 4] = [32u8, 166u8, 106u8, 216u8];
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
    /**Custom error with signature `LTP_INVALID_INCLUSION_PROOF()` and selector `0x8d9a4db3`.
```solidity
error LTP_INVALID_INCLUSION_PROOF();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct LTP_INVALID_INCLUSION_PROOF;
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
        impl ::core::convert::From<LTP_INVALID_INCLUSION_PROOF>
        for UnderlyingRustTuple<'_> {
            fn from(value: LTP_INVALID_INCLUSION_PROOF) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>>
        for LTP_INVALID_INCLUSION_PROOF {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for LTP_INVALID_INCLUSION_PROOF {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "LTP_INVALID_INCLUSION_PROOF()";
            const SELECTOR: [u8; 4] = [141u8, 154u8, 77u8, 179u8];
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
    /**Custom error with signature `SS_CHECKPOINTS_CLOSED()` and selector `0xcadcfbdb`.
```solidity
error SS_CHECKPOINTS_CLOSED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_CHECKPOINTS_CLOSED;
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
        impl ::core::convert::From<SS_CHECKPOINTS_CLOSED> for UnderlyingRustTuple<'_> {
            fn from(value: SS_CHECKPOINTS_CLOSED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_CHECKPOINTS_CLOSED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_CHECKPOINTS_CLOSED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_CHECKPOINTS_CLOSED()";
            const SELECTOR: [u8; 4] = [202u8, 220u8, 251u8, 219u8];
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
    /**Custom error with signature `SS_CHECKPOINT_NOT_FOUND()` and selector `0xf297591c`.
```solidity
error SS_CHECKPOINT_NOT_FOUND();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_CHECKPOINT_NOT_FOUND;
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
        impl ::core::convert::From<SS_CHECKPOINT_NOT_FOUND> for UnderlyingRustTuple<'_> {
            fn from(value: SS_CHECKPOINT_NOT_FOUND) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_CHECKPOINT_NOT_FOUND {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_CHECKPOINT_NOT_FOUND {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_CHECKPOINT_NOT_FOUND()";
            const SELECTOR: [u8; 4] = [242u8, 151u8, 89u8, 28u8];
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
    /**Custom error with signature `SS_EMPTY_PROOF()` and selector `0x2e4b6bbc`.
```solidity
error SS_EMPTY_PROOF();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_EMPTY_PROOF;
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
        impl ::core::convert::From<SS_EMPTY_PROOF> for UnderlyingRustTuple<'_> {
            fn from(value: SS_EMPTY_PROOF) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_EMPTY_PROOF {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_EMPTY_PROOF {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_EMPTY_PROOF()";
            const SELECTOR: [u8; 4] = [46u8, 75u8, 107u8, 188u8];
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
    /**Custom error with signature `SS_INVALID_BLOCK_ID()` and selector `0xf16b2096`.
```solidity
error SS_INVALID_BLOCK_ID();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_INVALID_BLOCK_ID;
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
        impl ::core::convert::From<SS_INVALID_BLOCK_ID> for UnderlyingRustTuple<'_> {
            fn from(value: SS_INVALID_BLOCK_ID) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_INVALID_BLOCK_ID {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_INVALID_BLOCK_ID {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_INVALID_BLOCK_ID()";
            const SELECTOR: [u8; 4] = [241u8, 107u8, 32u8, 150u8];
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
    /**Custom error with signature `SS_INVALID_CHECKPOINT()` and selector `0x62d16b9d`.
```solidity
error SS_INVALID_CHECKPOINT();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_INVALID_CHECKPOINT;
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
        impl ::core::convert::From<SS_INVALID_CHECKPOINT> for UnderlyingRustTuple<'_> {
            fn from(value: SS_INVALID_CHECKPOINT) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_INVALID_CHECKPOINT {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_INVALID_CHECKPOINT {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_INVALID_CHECKPOINT()";
            const SELECTOR: [u8; 4] = [98u8, 209u8, 107u8, 157u8];
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
    /**Custom error with signature `SS_INVALID_PROOF_LENGTH()` and selector `0x39e45cb8`.
```solidity
error SS_INVALID_PROOF_LENGTH();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_INVALID_PROOF_LENGTH;
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
        impl ::core::convert::From<SS_INVALID_PROOF_LENGTH> for UnderlyingRustTuple<'_> {
            fn from(value: SS_INVALID_PROOF_LENGTH) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_INVALID_PROOF_LENGTH {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_INVALID_PROOF_LENGTH {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_INVALID_PROOF_LENGTH()";
            const SELECTOR: [u8; 4] = [57u8, 228u8, 92u8, 184u8];
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
    /**Custom error with signature `SS_SIGNAL_NOT_RECEIVED()` and selector `0x442728ae`.
```solidity
error SS_SIGNAL_NOT_RECEIVED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_SIGNAL_NOT_RECEIVED;
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
        impl ::core::convert::From<SS_SIGNAL_NOT_RECEIVED> for UnderlyingRustTuple<'_> {
            fn from(value: SS_SIGNAL_NOT_RECEIVED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_SIGNAL_NOT_RECEIVED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_SIGNAL_NOT_RECEIVED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_SIGNAL_NOT_RECEIVED()";
            const SELECTOR: [u8; 4] = [68u8, 39u8, 40u8, 174u8];
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
    /**Custom error with signature `SS_STATE_ROOT_NOT_FOUND()` and selector `0xa86764fa`.
```solidity
error SS_STATE_ROOT_NOT_FOUND();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_STATE_ROOT_NOT_FOUND;
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
        impl ::core::convert::From<SS_STATE_ROOT_NOT_FOUND> for UnderlyingRustTuple<'_> {
            fn from(value: SS_STATE_ROOT_NOT_FOUND) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_STATE_ROOT_NOT_FOUND {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_STATE_ROOT_NOT_FOUND {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_STATE_ROOT_NOT_FOUND()";
            const SELECTOR: [u8; 4] = [168u8, 103u8, 100u8, 250u8];
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
    /**Custom error with signature `SS_UNAUTHORIZED()` and selector `0x1f67751f`.
```solidity
error SS_UNAUTHORIZED();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct SS_UNAUTHORIZED;
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
        impl ::core::convert::From<SS_UNAUTHORIZED> for UnderlyingRustTuple<'_> {
            fn from(value: SS_UNAUTHORIZED) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for SS_UNAUTHORIZED {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for SS_UNAUTHORIZED {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "SS_UNAUTHORIZED()";
            const SELECTOR: [u8; 4] = [31u8, 103u8, 117u8, 31u8];
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
    /**Custom error with signature `UnexpectedList()` and selector `0x1ff9b2e4`.
```solidity
error UnexpectedList();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct UnexpectedList;
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
        impl ::core::convert::From<UnexpectedList> for UnderlyingRustTuple<'_> {
            fn from(value: UnexpectedList) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for UnexpectedList {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for UnexpectedList {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "UnexpectedList()";
            const SELECTOR: [u8; 4] = [31u8, 249u8, 178u8, 228u8];
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
    /**Custom error with signature `UnexpectedString()` and selector `0x4b9c6abe`.
```solidity
error UnexpectedString();
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct UnexpectedString;
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
        impl ::core::convert::From<UnexpectedString> for UnderlyingRustTuple<'_> {
            fn from(value: UnexpectedString) -> Self {
                ()
            }
        }
        #[automatically_derived]
        #[doc(hidden)]
        impl ::core::convert::From<UnderlyingRustTuple<'_>> for UnexpectedString {
            fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                Self
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolError for UnexpectedString {
            type Parameters<'a> = UnderlyingSolTuple<'a>;
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "UnexpectedString()";
            const SELECTOR: [u8; 4] = [75u8, 156u8, 106u8, 190u8];
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
    /**Event with signature `CheckpointSaved(uint48,bytes32,bytes32)` and selector `0xf726c53cbb9e62552afc4a8f1bb1d01fa9272e526a7e3a69eba93b778b3f42a6`.
```solidity
event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct CheckpointSaved {
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
        #[automatically_derived]
        impl alloy_sol_types::SolEvent for CheckpointSaved {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (
                alloy_sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Uint<48>,
            );
            const SIGNATURE: &'static str = "CheckpointSaved(uint48,bytes32,bytes32)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                247u8, 38u8, 197u8, 60u8, 187u8, 158u8, 98u8, 85u8, 42u8, 252u8, 74u8,
                143u8, 27u8, 177u8, 208u8, 31u8, 169u8, 39u8, 46u8, 82u8, 106u8, 126u8,
                58u8, 105u8, 235u8, 169u8, 59u8, 119u8, 139u8, 63u8, 66u8, 166u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    blockNumber: topics.1,
                    blockHash: data.0,
                    stateRoot: data.1,
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
                    > as alloy_sol_types::SolType>::tokenize(&self.blockHash),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.stateRoot),
                )
            }
            #[inline]
            fn topics(&self) -> <Self::TopicList as alloy_sol_types::SolType>::RustType {
                (Self::SIGNATURE_HASH.into(), self.blockNumber.clone())
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
                    48,
                > as alloy_sol_types::EventTopic>::encode_topic(&self.blockNumber);
                Ok(())
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::private::IntoLogData for CheckpointSaved {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&CheckpointSaved> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &CheckpointSaved) -> alloy_sol_types::private::LogData {
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
    /**Event with signature `SignalSent(address,bytes32,bytes32,bytes32)` and selector `0x0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e973`.
```solidity
event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);
```*/
    #[allow(
        non_camel_case_types,
        non_snake_case,
        clippy::pub_underscore_fields,
        clippy::style
    )]
    #[derive(Clone)]
    pub struct SignalSent {
        #[allow(missing_docs)]
        pub app: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub signal: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub slot: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub value: alloy::sol_types::private::FixedBytes<32>,
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
        impl alloy_sol_types::SolEvent for SignalSent {
            type DataTuple<'a> = (
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type DataToken<'a> = <Self::DataTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type TopicList = (alloy_sol_types::sol_data::FixedBytes<32>,);
            const SIGNATURE: &'static str = "SignalSent(address,bytes32,bytes32,bytes32)";
            const SIGNATURE_HASH: alloy_sol_types::private::B256 = alloy_sol_types::private::B256::new([
                10u8, 210u8, 209u8, 8u8, 102u8, 10u8, 33u8, 31u8, 71u8, 191u8, 127u8,
                180u8, 58u8, 4u8, 67u8, 202u8, 225u8, 129u8, 98u8, 73u8, 149u8, 211u8,
                212u8, 43u8, 136u8, 238u8, 104u8, 121u8, 210u8, 0u8, 233u8, 115u8,
            ]);
            const ANONYMOUS: bool = false;
            #[allow(unused_variables)]
            #[inline]
            fn new(
                topics: <Self::TopicList as alloy_sol_types::SolType>::RustType,
                data: <Self::DataTuple<'_> as alloy_sol_types::SolType>::RustType,
            ) -> Self {
                Self {
                    app: data.0,
                    signal: data.1,
                    slot: data.2,
                    value: data.3,
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
                        &self.app,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.signal),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.slot),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self.value),
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
        impl alloy_sol_types::private::IntoLogData for SignalSent {
            fn to_log_data(&self) -> alloy_sol_types::private::LogData {
                From::from(self)
            }
            fn into_log_data(self) -> alloy_sol_types::private::LogData {
                From::from(&self)
            }
        }
        #[automatically_derived]
        impl From<&SignalSent> for alloy_sol_types::private::LogData {
            #[inline]
            fn from(this: &SignalSent) -> alloy_sol_types::private::LogData {
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
constructor(address authorizedSyncer, address remoteSignalService, address _pauser, uint64 _beaconRootsFrom);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct constructorCall {
        #[allow(missing_docs)]
        pub authorizedSyncer: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub remoteSignalService: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _pauser: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _beaconRootsFrom: u64,
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
                alloy::sol_types::sol_data::Uint<64>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::Address,
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
            impl ::core::convert::From<constructorCall> for UnderlyingRustTuple<'_> {
                fn from(value: constructorCall) -> Self {
                    (
                        value.authorizedSyncer,
                        value.remoteSignalService,
                        value._pauser,
                        value._beaconRootsFrom,
                    )
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for constructorCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        authorizedSyncer: tuple.0,
                        remoteSignalService: tuple.1,
                        _pauser: tuple.2,
                        _beaconRootsFrom: tuple.3,
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
                alloy::sol_types::sol_data::Uint<64>,
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
                        &self.authorizedSyncer,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self.remoteSignalService,
                    ),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._pauser,
                    ),
                    <alloy::sol_types::sol_data::Uint<
                        64,
                    > as alloy_sol_types::SolType>::tokenize(&self._beaconRootsFrom),
                )
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `BEACON_ROOTS()` and selector `0x56d7e8fd`.
```solidity
function BEACON_ROOTS() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BEACON_ROOTSCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`BEACON_ROOTS()`](BEACON_ROOTSCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct BEACON_ROOTSReturn {
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
            impl ::core::convert::From<BEACON_ROOTSCall> for UnderlyingRustTuple<'_> {
                fn from(value: BEACON_ROOTSCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for BEACON_ROOTSCall {
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
            impl ::core::convert::From<BEACON_ROOTSReturn> for UnderlyingRustTuple<'_> {
                fn from(value: BEACON_ROOTSReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for BEACON_ROOTSReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for BEACON_ROOTSCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "BEACON_ROOTS()";
            const SELECTOR: [u8; 4] = [86u8, 215u8, 232u8, 253u8];
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
                        let r: BEACON_ROOTSReturn = r.into();
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
                        let r: BEACON_ROOTSReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `VERSION()` and selector `0xffa1ad74`.
```solidity
function VERSION() external view returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct VERSIONCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`VERSION()`](VERSIONCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct VERSIONReturn {
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
            impl ::core::convert::From<VERSIONCall> for UnderlyingRustTuple<'_> {
                fn from(value: VERSIONCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for VERSIONCall {
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
            impl ::core::convert::From<VERSIONReturn> for UnderlyingRustTuple<'_> {
                fn from(value: VERSIONReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for VERSIONReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for VERSIONCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "VERSION()";
            const SELECTOR: [u8; 4] = [255u8, 161u8, 173u8, 116u8];
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
                        let r: VERSIONReturn = r.into();
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
                        let r: VERSIONReturn = r.into();
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
    /**Function with signature `beaconRootsFrom()` and selector `0x9bce53b5`.
```solidity
function beaconRootsFrom() external view returns (uint64);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct beaconRootsFromCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`beaconRootsFrom()`](beaconRootsFromCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct beaconRootsFromReturn {
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
            impl ::core::convert::From<beaconRootsFromCall> for UnderlyingRustTuple<'_> {
                fn from(value: beaconRootsFromCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for beaconRootsFromCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<beaconRootsFromReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: beaconRootsFromReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for beaconRootsFromReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for beaconRootsFromCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = u64;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<64>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "beaconRootsFrom()";
            const SELECTOR: [u8; 4] = [155u8, 206u8, 83u8, 181u8];
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
                        let r: beaconRootsFromReturn = r.into();
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
                        let r: beaconRootsFromReturn = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getCheckpoint(uint48)` and selector `0x8026b921`.
```solidity
function getCheckpoint(uint48 _blockNumber) external view returns (ICheckpointStore.Checkpoint memory checkpoint);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getCheckpointCall {
        #[allow(missing_docs)]
        pub _blockNumber: alloy::sol_types::private::primitives::aliases::U48,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getCheckpoint(uint48)`](getCheckpointCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getCheckpointReturn {
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
            impl ::core::convert::From<getCheckpointCall> for UnderlyingRustTuple<'_> {
                fn from(value: getCheckpointCall) -> Self {
                    (value._blockNumber,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getCheckpointCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _blockNumber: tuple.0 }
                }
            }
        }
        {
            #[doc(hidden)]
            #[allow(dead_code)]
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
            impl ::core::convert::From<getCheckpointReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getCheckpointReturn) -> Self {
                    (value.checkpoint,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getCheckpointReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { checkpoint: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getCheckpointCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::Uint<48>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType;
            type ReturnTuple<'a> = (ICheckpointStore::Checkpoint,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getCheckpoint(uint48)";
            const SELECTOR: [u8; 4] = [128u8, 38u8, 185u8, 33u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._blockNumber),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                (
                    <ICheckpointStore::Checkpoint as alloy_sol_types::SolType>::tokenize(
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
                        let r: getCheckpointReturn = r.into();
                        r.checkpoint
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
                        let r: getCheckpointReturn = r.into();
                        r.checkpoint
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `getSignalSlot(uint64,address,bytes32)` and selector `0x91f3f74b`.
```solidity
function getSignalSlot(uint64 _chainId, address _app, bytes32 _signal) external pure returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getSignalSlotCall {
        #[allow(missing_docs)]
        pub _chainId: u64,
        #[allow(missing_docs)]
        pub _app: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _signal: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`getSignalSlot(uint64,address,bytes32)`](getSignalSlotCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct getSignalSlotReturn {
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
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u64,
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
            impl ::core::convert::From<getSignalSlotCall> for UnderlyingRustTuple<'_> {
                fn from(value: getSignalSlotCall) -> Self {
                    (value._chainId, value._app, value._signal)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getSignalSlotCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _chainId: tuple.0,
                        _app: tuple.1,
                        _signal: tuple.2,
                    }
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
            impl ::core::convert::From<getSignalSlotReturn> for UnderlyingRustTuple<'_> {
                fn from(value: getSignalSlotReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for getSignalSlotReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for getSignalSlotCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "getSignalSlot(uint64,address,bytes32)";
            const SELECTOR: [u8; 4] = [145u8, 243u8, 247u8, 75u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._chainId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._app,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._signal),
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
                        let r: getSignalSlotReturn = r.into();
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
                        let r: getSignalSlotReturn = r.into();
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
    /**Function with signature `isSignalSent(address,bytes32)` and selector `0x32676bc6`.
```solidity
function isSignalSent(address _app, bytes32 _signal) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isSignalSent_0Call {
        #[allow(missing_docs)]
        pub _app: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _signal: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isSignalSent(address,bytes32)`](isSignalSent_0Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isSignalSent_0Return {
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
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
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
            impl ::core::convert::From<isSignalSent_0Call> for UnderlyingRustTuple<'_> {
                fn from(value: isSignalSent_0Call) -> Self {
                    (value._app, value._signal)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for isSignalSent_0Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _app: tuple.0,
                        _signal: tuple.1,
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
            impl ::core::convert::From<isSignalSent_0Return>
            for UnderlyingRustTuple<'_> {
                fn from(value: isSignalSent_0Return) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isSignalSent_0Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isSignalSent_0Call {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Address,
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
            const SIGNATURE: &'static str = "isSignalSent(address,bytes32)";
            const SELECTOR: [u8; 4] = [50u8, 103u8, 107u8, 198u8];
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
                        &self._app,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._signal),
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
                        let r: isSignalSent_0Return = r.into();
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
                        let r: isSignalSent_0Return = r.into();
                        r._0
                    })
            }
        }
    };
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    /**Function with signature `isSignalSent(bytes32)` and selector `0x8e899f80`.
```solidity
function isSignalSent(bytes32 _signalSlot) external view returns (bool);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isSignalSent_1Call {
        #[allow(missing_docs)]
        pub _signalSlot: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`isSignalSent(bytes32)`](isSignalSent_1Call) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct isSignalSent_1Return {
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
            impl ::core::convert::From<isSignalSent_1Call> for UnderlyingRustTuple<'_> {
                fn from(value: isSignalSent_1Call) -> Self {
                    (value._signalSlot,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for isSignalSent_1Call {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _signalSlot: tuple.0 }
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
            impl ::core::convert::From<isSignalSent_1Return>
            for UnderlyingRustTuple<'_> {
                fn from(value: isSignalSent_1Return) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for isSignalSent_1Return {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for isSignalSent_1Call {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = bool;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Bool,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "isSignalSent(bytes32)";
            const SELECTOR: [u8; 4] = [142u8, 137u8, 159u8, 128u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._signalSlot),
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
                        let r: isSignalSent_1Return = r.into();
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
                        let r: isSignalSent_1Return = r.into();
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
    /**Function with signature `pauser()` and selector `0x9fd0506d`.
```solidity
function pauser() external view returns (address);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pauserCall;
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`pauser()`](pauserCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct pauserReturn {
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
            impl ::core::convert::From<pauserCall> for UnderlyingRustTuple<'_> {
                fn from(value: pauserCall) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pauserCall {
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
            impl ::core::convert::From<pauserReturn> for UnderlyingRustTuple<'_> {
                fn from(value: pauserReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for pauserReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for pauserCall {
            type Parameters<'a> = ();
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::Address;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Address,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "pauser()";
            const SELECTOR: [u8; 4] = [159u8, 208u8, 80u8, 109u8];
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
                        let r: pauserReturn = r.into();
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
                        let r: pauserReturn = r.into();
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
    /**Function with signature `proveSignalReceived(uint64,address,bytes32,bytes)` and selector `0x910af6ed`.
```solidity
function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes memory _proof) external returns (uint256);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct proveSignalReceivedCall {
        #[allow(missing_docs)]
        pub _chainId: u64,
        #[allow(missing_docs)]
        pub _app: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _signal: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _proof: alloy::sol_types::private::Bytes,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`proveSignalReceived(uint64,address,bytes32,bytes)`](proveSignalReceivedCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct proveSignalReceivedReturn {
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
            type UnderlyingSolTuple<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u64,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::FixedBytes<32>,
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
            impl ::core::convert::From<proveSignalReceivedCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: proveSignalReceivedCall) -> Self {
                    (value._chainId, value._app, value._signal, value._proof)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for proveSignalReceivedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _chainId: tuple.0,
                        _app: tuple.1,
                        _signal: tuple.2,
                        _proof: tuple.3,
                    }
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
            impl ::core::convert::From<proveSignalReceivedReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: proveSignalReceivedReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for proveSignalReceivedReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for proveSignalReceivedCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::primitives::aliases::U256;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::Uint<256>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "proveSignalReceived(uint64,address,bytes32,bytes)";
            const SELECTOR: [u8; 4] = [145u8, 10u8, 246u8, 237u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._chainId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._app,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._signal),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._proof,
                    ),
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
                        let r: proveSignalReceivedReturn = r.into();
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
                        let r: proveSignalReceivedReturn = r.into();
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
    /**Function with signature `saveCheckpoint((uint48,bytes32,bytes32))` and selector `0xc9a0b8c8`.
```solidity
function saveCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct saveCheckpointCall {
        #[allow(missing_docs)]
        pub _checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
    }
    ///Container type for the return parameters of the [`saveCheckpoint((uint48,bytes32,bytes32))`](saveCheckpointCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct saveCheckpointReturn {}
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
            impl ::core::convert::From<saveCheckpointCall> for UnderlyingRustTuple<'_> {
                fn from(value: saveCheckpointCall) -> Self {
                    (value._checkpoint,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for saveCheckpointCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _checkpoint: tuple.0 }
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
            impl ::core::convert::From<saveCheckpointReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: saveCheckpointReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for saveCheckpointReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl saveCheckpointReturn {
            fn _tokenize(
                &self,
            ) -> <saveCheckpointCall as alloy_sol_types::SolCall>::ReturnToken<'_> {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for saveCheckpointCall {
            type Parameters<'a> = (ICheckpointStore::Checkpoint,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = saveCheckpointReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "saveCheckpoint((uint48,bytes32,bytes32))";
            const SELECTOR: [u8; 4] = [201u8, 160u8, 184u8, 200u8];
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
                saveCheckpointReturn::_tokenize(ret)
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
    /**Function with signature `sendSignal(bytes32)` and selector `0x66ca2bc0`.
```solidity
function sendSignal(bytes32 _signal) external returns (bytes32);
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct sendSignalCall {
        #[allow(missing_docs)]
        pub _signal: alloy::sol_types::private::FixedBytes<32>,
    }
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Default, Debug, PartialEq, Eq, Hash)]
    ///Container type for the return parameters of the [`sendSignal(bytes32)`](sendSignalCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct sendSignalReturn {
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
            impl ::core::convert::From<sendSignalCall> for UnderlyingRustTuple<'_> {
                fn from(value: sendSignalCall) -> Self {
                    (value._signal,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for sendSignalCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _signal: tuple.0 }
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
            impl ::core::convert::From<sendSignalReturn> for UnderlyingRustTuple<'_> {
                fn from(value: sendSignalReturn) -> Self {
                    (value._0,)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>> for sendSignalReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self { _0: tuple.0 }
                }
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for sendSignalCall {
            type Parameters<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = alloy::sol_types::private::FixedBytes<32>;
            type ReturnTuple<'a> = (alloy::sol_types::sol_data::FixedBytes<32>,);
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "sendSignal(bytes32)";
            const SELECTOR: [u8; 4] = [102u8, 202u8, 43u8, 192u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._signal),
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
                        let r: sendSignalReturn = r.into();
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
                        let r: sendSignalReturn = r.into();
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
    /**Function with signature `verifySignalReceived(uint64,address,bytes32,bytes)` and selector `0xce9d0820`.
```solidity
function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes memory _proof) external view;
```*/
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct verifySignalReceivedCall {
        #[allow(missing_docs)]
        pub _chainId: u64,
        #[allow(missing_docs)]
        pub _app: alloy::sol_types::private::Address,
        #[allow(missing_docs)]
        pub _signal: alloy::sol_types::private::FixedBytes<32>,
        #[allow(missing_docs)]
        pub _proof: alloy::sol_types::private::Bytes,
    }
    ///Container type for the return parameters of the [`verifySignalReceived(uint64,address,bytes32,bytes)`](verifySignalReceivedCall) function.
    #[allow(non_camel_case_types, non_snake_case, clippy::pub_underscore_fields)]
    #[derive(Clone)]
    pub struct verifySignalReceivedReturn {}
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
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Bytes,
            );
            #[doc(hidden)]
            type UnderlyingRustTuple<'a> = (
                u64,
                alloy::sol_types::private::Address,
                alloy::sol_types::private::FixedBytes<32>,
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
            impl ::core::convert::From<verifySignalReceivedCall>
            for UnderlyingRustTuple<'_> {
                fn from(value: verifySignalReceivedCall) -> Self {
                    (value._chainId, value._app, value._signal, value._proof)
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for verifySignalReceivedCall {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {
                        _chainId: tuple.0,
                        _app: tuple.1,
                        _signal: tuple.2,
                        _proof: tuple.3,
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
            impl ::core::convert::From<verifySignalReceivedReturn>
            for UnderlyingRustTuple<'_> {
                fn from(value: verifySignalReceivedReturn) -> Self {
                    ()
                }
            }
            #[automatically_derived]
            #[doc(hidden)]
            impl ::core::convert::From<UnderlyingRustTuple<'_>>
            for verifySignalReceivedReturn {
                fn from(tuple: UnderlyingRustTuple<'_>) -> Self {
                    Self {}
                }
            }
        }
        impl verifySignalReceivedReturn {
            fn _tokenize(
                &self,
            ) -> <verifySignalReceivedCall as alloy_sol_types::SolCall>::ReturnToken<
                '_,
            > {
                ()
            }
        }
        #[automatically_derived]
        impl alloy_sol_types::SolCall for verifySignalReceivedCall {
            type Parameters<'a> = (
                alloy::sol_types::sol_data::Uint<64>,
                alloy::sol_types::sol_data::Address,
                alloy::sol_types::sol_data::FixedBytes<32>,
                alloy::sol_types::sol_data::Bytes,
            );
            type Token<'a> = <Self::Parameters<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            type Return = verifySignalReceivedReturn;
            type ReturnTuple<'a> = ();
            type ReturnToken<'a> = <Self::ReturnTuple<
                'a,
            > as alloy_sol_types::SolType>::Token<'a>;
            const SIGNATURE: &'static str = "verifySignalReceived(uint64,address,bytes32,bytes)";
            const SELECTOR: [u8; 4] = [206u8, 157u8, 8u8, 32u8];
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
                    > as alloy_sol_types::SolType>::tokenize(&self._chainId),
                    <alloy::sol_types::sol_data::Address as alloy_sol_types::SolType>::tokenize(
                        &self._app,
                    ),
                    <alloy::sol_types::sol_data::FixedBytes<
                        32,
                    > as alloy_sol_types::SolType>::tokenize(&self._signal),
                    <alloy::sol_types::sol_data::Bytes as alloy_sol_types::SolType>::tokenize(
                        &self._proof,
                    ),
                )
            }
            #[inline]
            fn tokenize_returns(ret: &Self::Return) -> Self::ReturnToken<'_> {
                verifySignalReceivedReturn::_tokenize(ret)
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
    ///Container for all the [`SignalService`](self) function calls.
    #[derive(Clone)]
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive()]
    pub enum SignalServiceCalls {
        #[allow(missing_docs)]
        BEACON_ROOTS(BEACON_ROOTSCall),
        #[allow(missing_docs)]
        VERSION(VERSIONCall),
        #[allow(missing_docs)]
        acceptOwnership(acceptOwnershipCall),
        #[allow(missing_docs)]
        beaconRootsFrom(beaconRootsFromCall),
        #[allow(missing_docs)]
        getCheckpoint(getCheckpointCall),
        #[allow(missing_docs)]
        getSignalSlot(getSignalSlotCall),
        #[allow(missing_docs)]
        r#impl(implCall),
        #[allow(missing_docs)]
        inNonReentrant(inNonReentrantCall),
        #[allow(missing_docs)]
        init(initCall),
        #[allow(missing_docs)]
        isSignalSent_0(isSignalSent_0Call),
        #[allow(missing_docs)]
        isSignalSent_1(isSignalSent_1Call),
        #[allow(missing_docs)]
        owner(ownerCall),
        #[allow(missing_docs)]
        pause(pauseCall),
        #[allow(missing_docs)]
        paused(pausedCall),
        #[allow(missing_docs)]
        pauser(pauserCall),
        #[allow(missing_docs)]
        pendingOwner(pendingOwnerCall),
        #[allow(missing_docs)]
        proveSignalReceived(proveSignalReceivedCall),
        #[allow(missing_docs)]
        proxiableUUID(proxiableUUIDCall),
        #[allow(missing_docs)]
        renounceOwnership(renounceOwnershipCall),
        #[allow(missing_docs)]
        resolver(resolverCall),
        #[allow(missing_docs)]
        saveCheckpoint(saveCheckpointCall),
        #[allow(missing_docs)]
        sendSignal(sendSignalCall),
        #[allow(missing_docs)]
        transferOwnership(transferOwnershipCall),
        #[allow(missing_docs)]
        unpause(unpauseCall),
        #[allow(missing_docs)]
        upgradeTo(upgradeToCall),
        #[allow(missing_docs)]
        upgradeToAndCall(upgradeToAndCallCall),
        #[allow(missing_docs)]
        verifySignalReceived(verifySignalReceivedCall),
    }
    impl SignalServiceCalls {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [4u8, 243u8, 188u8, 236u8],
            [25u8, 171u8, 69u8, 60u8],
            [48u8, 117u8, 219u8, 86u8],
            [50u8, 103u8, 107u8, 198u8],
            [54u8, 89u8, 207u8, 230u8],
            [63u8, 75u8, 168u8, 58u8],
            [79u8, 30u8, 242u8, 134u8],
            [82u8, 209u8, 144u8, 45u8],
            [86u8, 215u8, 232u8, 253u8],
            [92u8, 151u8, 90u8, 187u8],
            [102u8, 202u8, 43u8, 192u8],
            [113u8, 80u8, 24u8, 166u8],
            [121u8, 186u8, 80u8, 151u8],
            [128u8, 38u8, 185u8, 33u8],
            [132u8, 86u8, 203u8, 89u8],
            [138u8, 191u8, 96u8, 119u8],
            [141u8, 165u8, 203u8, 91u8],
            [142u8, 137u8, 159u8, 128u8],
            [145u8, 10u8, 246u8, 237u8],
            [145u8, 243u8, 247u8, 75u8],
            [155u8, 206u8, 83u8, 181u8],
            [159u8, 208u8, 80u8, 109u8],
            [201u8, 160u8, 184u8, 200u8],
            [206u8, 157u8, 8u8, 32u8],
            [227u8, 12u8, 57u8, 120u8],
            [242u8, 253u8, 227u8, 139u8],
            [255u8, 161u8, 173u8, 116u8],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(resolver),
            ::core::stringify!(init),
            ::core::stringify!(inNonReentrant),
            ::core::stringify!(isSignalSent_0),
            ::core::stringify!(upgradeTo),
            ::core::stringify!(unpause),
            ::core::stringify!(upgradeToAndCall),
            ::core::stringify!(proxiableUUID),
            ::core::stringify!(BEACON_ROOTS),
            ::core::stringify!(paused),
            ::core::stringify!(sendSignal),
            ::core::stringify!(renounceOwnership),
            ::core::stringify!(acceptOwnership),
            ::core::stringify!(getCheckpoint),
            ::core::stringify!(pause),
            ::core::stringify!(r#impl),
            ::core::stringify!(owner),
            ::core::stringify!(isSignalSent_1),
            ::core::stringify!(proveSignalReceived),
            ::core::stringify!(getSignalSlot),
            ::core::stringify!(beaconRootsFrom),
            ::core::stringify!(pauser),
            ::core::stringify!(saveCheckpoint),
            ::core::stringify!(verifySignalReceived),
            ::core::stringify!(pendingOwner),
            ::core::stringify!(transferOwnership),
            ::core::stringify!(VERSION),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <resolverCall as alloy_sol_types::SolCall>::SIGNATURE,
            <initCall as alloy_sol_types::SolCall>::SIGNATURE,
            <inNonReentrantCall as alloy_sol_types::SolCall>::SIGNATURE,
            <isSignalSent_0Call as alloy_sol_types::SolCall>::SIGNATURE,
            <upgradeToCall as alloy_sol_types::SolCall>::SIGNATURE,
            <unpauseCall as alloy_sol_types::SolCall>::SIGNATURE,
            <upgradeToAndCallCall as alloy_sol_types::SolCall>::SIGNATURE,
            <proxiableUUIDCall as alloy_sol_types::SolCall>::SIGNATURE,
            <BEACON_ROOTSCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pausedCall as alloy_sol_types::SolCall>::SIGNATURE,
            <sendSignalCall as alloy_sol_types::SolCall>::SIGNATURE,
            <renounceOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <acceptOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <getCheckpointCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pauseCall as alloy_sol_types::SolCall>::SIGNATURE,
            <implCall as alloy_sol_types::SolCall>::SIGNATURE,
            <ownerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <isSignalSent_1Call as alloy_sol_types::SolCall>::SIGNATURE,
            <proveSignalReceivedCall as alloy_sol_types::SolCall>::SIGNATURE,
            <getSignalSlotCall as alloy_sol_types::SolCall>::SIGNATURE,
            <beaconRootsFromCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pauserCall as alloy_sol_types::SolCall>::SIGNATURE,
            <saveCheckpointCall as alloy_sol_types::SolCall>::SIGNATURE,
            <verifySignalReceivedCall as alloy_sol_types::SolCall>::SIGNATURE,
            <pendingOwnerCall as alloy_sol_types::SolCall>::SIGNATURE,
            <transferOwnershipCall as alloy_sol_types::SolCall>::SIGNATURE,
            <VERSIONCall as alloy_sol_types::SolCall>::SIGNATURE,
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
    impl alloy_sol_types::SolInterface for SignalServiceCalls {
        const NAME: &'static str = "SignalServiceCalls";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 27usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::BEACON_ROOTS(_) => {
                    <BEACON_ROOTSCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::VERSION(_) => <VERSIONCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::acceptOwnership(_) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::beaconRootsFrom(_) => {
                    <beaconRootsFromCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getCheckpoint(_) => {
                    <getCheckpointCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::getSignalSlot(_) => {
                    <getSignalSlotCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::r#impl(_) => <implCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::inNonReentrant(_) => {
                    <inNonReentrantCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::init(_) => <initCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::isSignalSent_0(_) => {
                    <isSignalSent_0Call as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::isSignalSent_1(_) => {
                    <isSignalSent_1Call as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::owner(_) => <ownerCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pause(_) => <pauseCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::paused(_) => <pausedCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pauser(_) => <pauserCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::pendingOwner(_) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proveSignalReceived(_) => {
                    <proveSignalReceivedCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::proxiableUUID(_) => {
                    <proxiableUUIDCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::renounceOwnership(_) => {
                    <renounceOwnershipCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::resolver(_) => <resolverCall as alloy_sol_types::SolCall>::SELECTOR,
                Self::saveCheckpoint(_) => {
                    <saveCheckpointCall as alloy_sol_types::SolCall>::SELECTOR
                }
                Self::sendSignal(_) => {
                    <sendSignalCall as alloy_sol_types::SolCall>::SELECTOR
                }
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
                Self::verifySignalReceived(_) => {
                    <verifySignalReceivedCall as alloy_sol_types::SolCall>::SELECTOR
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
            ) -> alloy_sol_types::Result<SignalServiceCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::resolver)
                    }
                    resolver
                },
                {
                    fn init(data: &[u8]) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::init)
                    }
                    init
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn isSignalSent_0(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <isSignalSent_0Call as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::isSignalSent_0)
                    }
                    isSignalSent_0
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn BEACON_ROOTS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <BEACON_ROOTSCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::BEACON_ROOTS)
                    }
                    BEACON_ROOTS
                },
                {
                    fn paused(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::paused)
                    }
                    paused
                },
                {
                    fn sendSignal(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <sendSignalCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::sendSignal)
                    }
                    sendSignal
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn getCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <getCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::getCheckpoint)
                    }
                    getCheckpoint
                },
                {
                    fn pause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::owner)
                    }
                    owner
                },
                {
                    fn isSignalSent_1(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <isSignalSent_1Call as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::isSignalSent_1)
                    }
                    isSignalSent_1
                },
                {
                    fn proveSignalReceived(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <proveSignalReceivedCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::proveSignalReceived)
                    }
                    proveSignalReceived
                },
                {
                    fn getSignalSlot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <getSignalSlotCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::getSignalSlot)
                    }
                    getSignalSlot
                },
                {
                    fn beaconRootsFrom(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <beaconRootsFromCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::beaconRootsFrom)
                    }
                    beaconRootsFrom
                },
                {
                    fn pauser(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pauserCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::pauser)
                    }
                    pauser
                },
                {
                    fn saveCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <saveCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::saveCheckpoint)
                    }
                    saveCheckpoint
                },
                {
                    fn verifySignalReceived(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <verifySignalReceivedCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::verifySignalReceived)
                    }
                    verifySignalReceived
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn VERSION(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <VERSIONCall as alloy_sol_types::SolCall>::abi_decode_raw(data)
                            .map(SignalServiceCalls::VERSION)
                    }
                    VERSION
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
            ) -> alloy_sol_types::Result<SignalServiceCalls>] = &[
                {
                    fn resolver(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <resolverCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::resolver)
                    }
                    resolver
                },
                {
                    fn init(data: &[u8]) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <initCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::init)
                    }
                    init
                },
                {
                    fn inNonReentrant(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <inNonReentrantCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::inNonReentrant)
                    }
                    inNonReentrant
                },
                {
                    fn isSignalSent_0(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <isSignalSent_0Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::isSignalSent_0)
                    }
                    isSignalSent_0
                },
                {
                    fn upgradeTo(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <upgradeToCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::upgradeTo)
                    }
                    upgradeTo
                },
                {
                    fn unpause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <unpauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::unpause)
                    }
                    unpause
                },
                {
                    fn upgradeToAndCall(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <upgradeToAndCallCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::upgradeToAndCall)
                    }
                    upgradeToAndCall
                },
                {
                    fn proxiableUUID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <proxiableUUIDCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::proxiableUUID)
                    }
                    proxiableUUID
                },
                {
                    fn BEACON_ROOTS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <BEACON_ROOTSCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::BEACON_ROOTS)
                    }
                    BEACON_ROOTS
                },
                {
                    fn paused(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pausedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::paused)
                    }
                    paused
                },
                {
                    fn sendSignal(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <sendSignalCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::sendSignal)
                    }
                    sendSignal
                },
                {
                    fn renounceOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <renounceOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::renounceOwnership)
                    }
                    renounceOwnership
                },
                {
                    fn acceptOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::acceptOwnership)
                    }
                    acceptOwnership
                },
                {
                    fn getCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <getCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::getCheckpoint)
                    }
                    getCheckpoint
                },
                {
                    fn pause(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pauseCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::pause)
                    }
                    pause
                },
                {
                    fn r#impl(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <implCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::r#impl)
                    }
                    r#impl
                },
                {
                    fn owner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <ownerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::owner)
                    }
                    owner
                },
                {
                    fn isSignalSent_1(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <isSignalSent_1Call as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::isSignalSent_1)
                    }
                    isSignalSent_1
                },
                {
                    fn proveSignalReceived(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <proveSignalReceivedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::proveSignalReceived)
                    }
                    proveSignalReceived
                },
                {
                    fn getSignalSlot(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <getSignalSlotCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::getSignalSlot)
                    }
                    getSignalSlot
                },
                {
                    fn beaconRootsFrom(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <beaconRootsFromCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::beaconRootsFrom)
                    }
                    beaconRootsFrom
                },
                {
                    fn pauser(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pauserCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::pauser)
                    }
                    pauser
                },
                {
                    fn saveCheckpoint(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <saveCheckpointCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::saveCheckpoint)
                    }
                    saveCheckpoint
                },
                {
                    fn verifySignalReceived(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <verifySignalReceivedCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::verifySignalReceived)
                    }
                    verifySignalReceived
                },
                {
                    fn pendingOwner(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <pendingOwnerCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::pendingOwner)
                    }
                    pendingOwner
                },
                {
                    fn transferOwnership(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <transferOwnershipCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::transferOwnership)
                    }
                    transferOwnership
                },
                {
                    fn VERSION(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceCalls> {
                        <VERSIONCall as alloy_sol_types::SolCall>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceCalls::VERSION)
                    }
                    VERSION
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
                Self::BEACON_ROOTS(inner) => {
                    <BEACON_ROOTSCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::VERSION(inner) => {
                    <VERSIONCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::beaconRootsFrom(inner) => {
                    <beaconRootsFromCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getCheckpoint(inner) => {
                    <getCheckpointCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::getSignalSlot(inner) => {
                    <getSignalSlotCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::init(inner) => {
                    <initCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::isSignalSent_0(inner) => {
                    <isSignalSent_0Call as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::isSignalSent_1(inner) => {
                    <isSignalSent_1Call as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::pauser(inner) => {
                    <pauserCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::proveSignalReceived(inner) => {
                    <proveSignalReceivedCall as alloy_sol_types::SolCall>::abi_encoded_size(
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
                Self::saveCheckpoint(inner) => {
                    <saveCheckpointCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
                Self::sendSignal(inner) => {
                    <sendSignalCall as alloy_sol_types::SolCall>::abi_encoded_size(inner)
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
                Self::verifySignalReceived(inner) => {
                    <verifySignalReceivedCall as alloy_sol_types::SolCall>::abi_encoded_size(
                        inner,
                    )
                }
            }
        }
        #[inline]
        fn abi_encode_raw(&self, out: &mut alloy_sol_types::private::Vec<u8>) {
            match self {
                Self::BEACON_ROOTS(inner) => {
                    <BEACON_ROOTSCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::VERSION(inner) => {
                    <VERSIONCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::acceptOwnership(inner) => {
                    <acceptOwnershipCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::beaconRootsFrom(inner) => {
                    <beaconRootsFromCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getCheckpoint(inner) => {
                    <getCheckpointCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::getSignalSlot(inner) => {
                    <getSignalSlotCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::isSignalSent_0(inner) => {
                    <isSignalSent_0Call as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::isSignalSent_1(inner) => {
                    <isSignalSent_1Call as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::pauser(inner) => {
                    <pauserCall as alloy_sol_types::SolCall>::abi_encode_raw(inner, out)
                }
                Self::pendingOwner(inner) => {
                    <pendingOwnerCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::proveSignalReceived(inner) => {
                    <proveSignalReceivedCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::saveCheckpoint(inner) => {
                    <saveCheckpointCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::sendSignal(inner) => {
                    <sendSignalCall as alloy_sol_types::SolCall>::abi_encode_raw(
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
                Self::verifySignalReceived(inner) => {
                    <verifySignalReceivedCall as alloy_sol_types::SolCall>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
            }
        }
    }
    ///Container for all the [`SignalService`](self) custom errors.
    #[derive(Clone)]
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum SignalServiceErrors {
        #[allow(missing_docs)]
        ACCESS_DENIED(ACCESS_DENIED),
        #[allow(missing_docs)]
        ContentLengthMismatch(ContentLengthMismatch),
        #[allow(missing_docs)]
        EmptyItem(EmptyItem),
        #[allow(missing_docs)]
        FUNC_NOT_IMPLEMENTED(FUNC_NOT_IMPLEMENTED),
        #[allow(missing_docs)]
        INVALID_PAUSE_STATUS(INVALID_PAUSE_STATUS),
        #[allow(missing_docs)]
        InvalidDataRemainder(InvalidDataRemainder),
        #[allow(missing_docs)]
        InvalidHeader(InvalidHeader),
        #[allow(missing_docs)]
        LTP_INVALID_ACCOUNT_PROOF(LTP_INVALID_ACCOUNT_PROOF),
        #[allow(missing_docs)]
        LTP_INVALID_INCLUSION_PROOF(LTP_INVALID_INCLUSION_PROOF),
        #[allow(missing_docs)]
        REENTRANT_CALL(REENTRANT_CALL),
        #[allow(missing_docs)]
        SS_CHECKPOINTS_CLOSED(SS_CHECKPOINTS_CLOSED),
        #[allow(missing_docs)]
        SS_CHECKPOINT_NOT_FOUND(SS_CHECKPOINT_NOT_FOUND),
        #[allow(missing_docs)]
        SS_EMPTY_PROOF(SS_EMPTY_PROOF),
        #[allow(missing_docs)]
        SS_INVALID_BLOCK_ID(SS_INVALID_BLOCK_ID),
        #[allow(missing_docs)]
        SS_INVALID_CHECKPOINT(SS_INVALID_CHECKPOINT),
        #[allow(missing_docs)]
        SS_INVALID_PROOF_LENGTH(SS_INVALID_PROOF_LENGTH),
        #[allow(missing_docs)]
        SS_SIGNAL_NOT_RECEIVED(SS_SIGNAL_NOT_RECEIVED),
        #[allow(missing_docs)]
        SS_STATE_ROOT_NOT_FOUND(SS_STATE_ROOT_NOT_FOUND),
        #[allow(missing_docs)]
        SS_UNAUTHORIZED(SS_UNAUTHORIZED),
        #[allow(missing_docs)]
        UnexpectedList(UnexpectedList),
        #[allow(missing_docs)]
        UnexpectedString(UnexpectedString),
        #[allow(missing_docs)]
        ZERO_ADDRESS(ZERO_ADDRESS),
        #[allow(missing_docs)]
        ZERO_VALUE(ZERO_VALUE),
    }
    impl SignalServiceErrors {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 4usize]] = &[
            [24u8, 87u8, 31u8, 30u8],
            [31u8, 103u8, 117u8, 31u8],
            [31u8, 249u8, 178u8, 228u8],
            [32u8, 166u8, 106u8, 216u8],
            [46u8, 75u8, 107u8, 188u8],
            [57u8, 228u8, 92u8, 184u8],
            [68u8, 39u8, 40u8, 174u8],
            [75u8, 156u8, 106u8, 190u8],
            [83u8, 139u8, 164u8, 249u8],
            [90u8, 180u8, 88u8, 251u8],
            [92u8, 85u8, 55u8, 184u8],
            [98u8, 209u8, 107u8, 157u8],
            [102u8, 201u8, 68u8, 133u8],
            [141u8, 154u8, 77u8, 179u8],
            [149u8, 56u8, 62u8, 161u8],
            [168u8, 103u8, 100u8, 250u8],
            [186u8, 187u8, 1u8, 221u8],
            [186u8, 230u8, 226u8, 169u8],
            [202u8, 220u8, 251u8, 219u8],
            [223u8, 198u8, 13u8, 133u8],
            [236u8, 115u8, 41u8, 89u8],
            [241u8, 107u8, 32u8, 150u8],
            [242u8, 151u8, 89u8, 28u8],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(FUNC_NOT_IMPLEMENTED),
            ::core::stringify!(SS_UNAUTHORIZED),
            ::core::stringify!(UnexpectedList),
            ::core::stringify!(LTP_INVALID_ACCOUNT_PROOF),
            ::core::stringify!(SS_EMPTY_PROOF),
            ::core::stringify!(SS_INVALID_PROOF_LENGTH),
            ::core::stringify!(SS_SIGNAL_NOT_RECEIVED),
            ::core::stringify!(UnexpectedString),
            ::core::stringify!(ZERO_ADDRESS),
            ::core::stringify!(EmptyItem),
            ::core::stringify!(InvalidDataRemainder),
            ::core::stringify!(SS_INVALID_CHECKPOINT),
            ::core::stringify!(ContentLengthMismatch),
            ::core::stringify!(LTP_INVALID_INCLUSION_PROOF),
            ::core::stringify!(ACCESS_DENIED),
            ::core::stringify!(SS_STATE_ROOT_NOT_FOUND),
            ::core::stringify!(InvalidHeader),
            ::core::stringify!(INVALID_PAUSE_STATUS),
            ::core::stringify!(SS_CHECKPOINTS_CLOSED),
            ::core::stringify!(REENTRANT_CALL),
            ::core::stringify!(ZERO_VALUE),
            ::core::stringify!(SS_INVALID_BLOCK_ID),
            ::core::stringify!(SS_CHECKPOINT_NOT_FOUND),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::SIGNATURE,
            <SS_UNAUTHORIZED as alloy_sol_types::SolError>::SIGNATURE,
            <UnexpectedList as alloy_sol_types::SolError>::SIGNATURE,
            <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::SIGNATURE,
            <SS_EMPTY_PROOF as alloy_sol_types::SolError>::SIGNATURE,
            <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::SIGNATURE,
            <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::SIGNATURE,
            <UnexpectedString as alloy_sol_types::SolError>::SIGNATURE,
            <ZERO_ADDRESS as alloy_sol_types::SolError>::SIGNATURE,
            <EmptyItem as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidDataRemainder as alloy_sol_types::SolError>::SIGNATURE,
            <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::SIGNATURE,
            <ContentLengthMismatch as alloy_sol_types::SolError>::SIGNATURE,
            <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::SIGNATURE,
            <ACCESS_DENIED as alloy_sol_types::SolError>::SIGNATURE,
            <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::SIGNATURE,
            <InvalidHeader as alloy_sol_types::SolError>::SIGNATURE,
            <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::SIGNATURE,
            <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::SIGNATURE,
            <REENTRANT_CALL as alloy_sol_types::SolError>::SIGNATURE,
            <ZERO_VALUE as alloy_sol_types::SolError>::SIGNATURE,
            <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::SIGNATURE,
            <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::SIGNATURE,
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
    impl alloy_sol_types::SolInterface for SignalServiceErrors {
        const NAME: &'static str = "SignalServiceErrors";
        const MIN_DATA_LENGTH: usize = 0usize;
        const COUNT: usize = 23usize;
        #[inline]
        fn selector(&self) -> [u8; 4] {
            match self {
                Self::ACCESS_DENIED(_) => {
                    <ACCESS_DENIED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::ContentLengthMismatch(_) => {
                    <ContentLengthMismatch as alloy_sol_types::SolError>::SELECTOR
                }
                Self::EmptyItem(_) => <EmptyItem as alloy_sol_types::SolError>::SELECTOR,
                Self::FUNC_NOT_IMPLEMENTED(_) => {
                    <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::INVALID_PAUSE_STATUS(_) => {
                    <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidDataRemainder(_) => {
                    <InvalidDataRemainder as alloy_sol_types::SolError>::SELECTOR
                }
                Self::InvalidHeader(_) => {
                    <InvalidHeader as alloy_sol_types::SolError>::SELECTOR
                }
                Self::LTP_INVALID_ACCOUNT_PROOF(_) => {
                    <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::SELECTOR
                }
                Self::LTP_INVALID_INCLUSION_PROOF(_) => {
                    <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::SELECTOR
                }
                Self::REENTRANT_CALL(_) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_CHECKPOINTS_CLOSED(_) => {
                    <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_CHECKPOINT_NOT_FOUND(_) => {
                    <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_EMPTY_PROOF(_) => {
                    <SS_EMPTY_PROOF as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_INVALID_BLOCK_ID(_) => {
                    <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_INVALID_CHECKPOINT(_) => {
                    <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_INVALID_PROOF_LENGTH(_) => {
                    <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_SIGNAL_NOT_RECEIVED(_) => {
                    <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_STATE_ROOT_NOT_FOUND(_) => {
                    <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::SELECTOR
                }
                Self::SS_UNAUTHORIZED(_) => {
                    <SS_UNAUTHORIZED as alloy_sol_types::SolError>::SELECTOR
                }
                Self::UnexpectedList(_) => {
                    <UnexpectedList as alloy_sol_types::SolError>::SELECTOR
                }
                Self::UnexpectedString(_) => {
                    <UnexpectedString as alloy_sol_types::SolError>::SELECTOR
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
            ) -> alloy_sol_types::Result<SignalServiceErrors>] = &[
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn SS_UNAUTHORIZED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_UNAUTHORIZED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_UNAUTHORIZED)
                    }
                    SS_UNAUTHORIZED
                },
                {
                    fn UnexpectedList(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <UnexpectedList as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::UnexpectedList)
                    }
                    UnexpectedList
                },
                {
                    fn LTP_INVALID_ACCOUNT_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::LTP_INVALID_ACCOUNT_PROOF)
                    }
                    LTP_INVALID_ACCOUNT_PROOF
                },
                {
                    fn SS_EMPTY_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_EMPTY_PROOF as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_EMPTY_PROOF)
                    }
                    SS_EMPTY_PROOF
                },
                {
                    fn SS_INVALID_PROOF_LENGTH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_PROOF_LENGTH)
                    }
                    SS_INVALID_PROOF_LENGTH
                },
                {
                    fn SS_SIGNAL_NOT_RECEIVED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_SIGNAL_NOT_RECEIVED)
                    }
                    SS_SIGNAL_NOT_RECEIVED
                },
                {
                    fn UnexpectedString(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <UnexpectedString as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::UnexpectedString)
                    }
                    UnexpectedString
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(SignalServiceErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn EmptyItem(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <EmptyItem as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(SignalServiceErrors::EmptyItem)
                    }
                    EmptyItem
                },
                {
                    fn InvalidDataRemainder(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <InvalidDataRemainder as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::InvalidDataRemainder)
                    }
                    InvalidDataRemainder
                },
                {
                    fn SS_INVALID_CHECKPOINT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_CHECKPOINT)
                    }
                    SS_INVALID_CHECKPOINT
                },
                {
                    fn ContentLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ContentLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::ContentLengthMismatch)
                    }
                    ContentLengthMismatch
                },
                {
                    fn LTP_INVALID_INCLUSION_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::LTP_INVALID_INCLUSION_PROOF)
                    }
                    LTP_INVALID_INCLUSION_PROOF
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn SS_STATE_ROOT_NOT_FOUND(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_STATE_ROOT_NOT_FOUND)
                    }
                    SS_STATE_ROOT_NOT_FOUND
                },
                {
                    fn InvalidHeader(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <InvalidHeader as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::InvalidHeader)
                    }
                    InvalidHeader
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn SS_CHECKPOINTS_CLOSED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_CHECKPOINTS_CLOSED)
                    }
                    SS_CHECKPOINTS_CLOSED
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw(data)
                            .map(SignalServiceErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
                },
                {
                    fn SS_INVALID_BLOCK_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_BLOCK_ID)
                    }
                    SS_INVALID_BLOCK_ID
                },
                {
                    fn SS_CHECKPOINT_NOT_FOUND(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::abi_decode_raw(
                                data,
                            )
                            .map(SignalServiceErrors::SS_CHECKPOINT_NOT_FOUND)
                    }
                    SS_CHECKPOINT_NOT_FOUND
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
            ) -> alloy_sol_types::Result<SignalServiceErrors>] = &[
                {
                    fn FUNC_NOT_IMPLEMENTED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <FUNC_NOT_IMPLEMENTED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::FUNC_NOT_IMPLEMENTED)
                    }
                    FUNC_NOT_IMPLEMENTED
                },
                {
                    fn SS_UNAUTHORIZED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_UNAUTHORIZED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_UNAUTHORIZED)
                    }
                    SS_UNAUTHORIZED
                },
                {
                    fn UnexpectedList(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <UnexpectedList as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::UnexpectedList)
                    }
                    UnexpectedList
                },
                {
                    fn LTP_INVALID_ACCOUNT_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::LTP_INVALID_ACCOUNT_PROOF)
                    }
                    LTP_INVALID_ACCOUNT_PROOF
                },
                {
                    fn SS_EMPTY_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_EMPTY_PROOF as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_EMPTY_PROOF)
                    }
                    SS_EMPTY_PROOF
                },
                {
                    fn SS_INVALID_PROOF_LENGTH(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_PROOF_LENGTH)
                    }
                    SS_INVALID_PROOF_LENGTH
                },
                {
                    fn SS_SIGNAL_NOT_RECEIVED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_SIGNAL_NOT_RECEIVED)
                    }
                    SS_SIGNAL_NOT_RECEIVED
                },
                {
                    fn UnexpectedString(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <UnexpectedString as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::UnexpectedString)
                    }
                    UnexpectedString
                },
                {
                    fn ZERO_ADDRESS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ZERO_ADDRESS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::ZERO_ADDRESS)
                    }
                    ZERO_ADDRESS
                },
                {
                    fn EmptyItem(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <EmptyItem as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::EmptyItem)
                    }
                    EmptyItem
                },
                {
                    fn InvalidDataRemainder(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <InvalidDataRemainder as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::InvalidDataRemainder)
                    }
                    InvalidDataRemainder
                },
                {
                    fn SS_INVALID_CHECKPOINT(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_CHECKPOINT)
                    }
                    SS_INVALID_CHECKPOINT
                },
                {
                    fn ContentLengthMismatch(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ContentLengthMismatch as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::ContentLengthMismatch)
                    }
                    ContentLengthMismatch
                },
                {
                    fn LTP_INVALID_INCLUSION_PROOF(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::LTP_INVALID_INCLUSION_PROOF)
                    }
                    LTP_INVALID_INCLUSION_PROOF
                },
                {
                    fn ACCESS_DENIED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ACCESS_DENIED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::ACCESS_DENIED)
                    }
                    ACCESS_DENIED
                },
                {
                    fn SS_STATE_ROOT_NOT_FOUND(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_STATE_ROOT_NOT_FOUND)
                    }
                    SS_STATE_ROOT_NOT_FOUND
                },
                {
                    fn InvalidHeader(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <InvalidHeader as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::InvalidHeader)
                    }
                    InvalidHeader
                },
                {
                    fn INVALID_PAUSE_STATUS(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <INVALID_PAUSE_STATUS as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::INVALID_PAUSE_STATUS)
                    }
                    INVALID_PAUSE_STATUS
                },
                {
                    fn SS_CHECKPOINTS_CLOSED(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_CHECKPOINTS_CLOSED)
                    }
                    SS_CHECKPOINTS_CLOSED
                },
                {
                    fn REENTRANT_CALL(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <REENTRANT_CALL as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::REENTRANT_CALL)
                    }
                    REENTRANT_CALL
                },
                {
                    fn ZERO_VALUE(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <ZERO_VALUE as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::ZERO_VALUE)
                    }
                    ZERO_VALUE
                },
                {
                    fn SS_INVALID_BLOCK_ID(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_INVALID_BLOCK_ID)
                    }
                    SS_INVALID_BLOCK_ID
                },
                {
                    fn SS_CHECKPOINT_NOT_FOUND(
                        data: &[u8],
                    ) -> alloy_sol_types::Result<SignalServiceErrors> {
                        <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::abi_decode_raw_validate(
                                data,
                            )
                            .map(SignalServiceErrors::SS_CHECKPOINT_NOT_FOUND)
                    }
                    SS_CHECKPOINT_NOT_FOUND
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
                Self::ContentLengthMismatch(inner) => {
                    <ContentLengthMismatch as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::EmptyItem(inner) => {
                    <EmptyItem as alloy_sol_types::SolError>::abi_encoded_size(inner)
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
                Self::InvalidDataRemainder(inner) => {
                    <InvalidDataRemainder as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::InvalidHeader(inner) => {
                    <InvalidHeader as alloy_sol_types::SolError>::abi_encoded_size(inner)
                }
                Self::LTP_INVALID_ACCOUNT_PROOF(inner) => {
                    <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::LTP_INVALID_INCLUSION_PROOF(inner) => {
                    <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::REENTRANT_CALL(inner) => {
                    <REENTRANT_CALL as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_CHECKPOINTS_CLOSED(inner) => {
                    <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_CHECKPOINT_NOT_FOUND(inner) => {
                    <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_EMPTY_PROOF(inner) => {
                    <SS_EMPTY_PROOF as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_INVALID_BLOCK_ID(inner) => {
                    <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_INVALID_CHECKPOINT(inner) => {
                    <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_INVALID_PROOF_LENGTH(inner) => {
                    <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_SIGNAL_NOT_RECEIVED(inner) => {
                    <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_STATE_ROOT_NOT_FOUND(inner) => {
                    <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::SS_UNAUTHORIZED(inner) => {
                    <SS_UNAUTHORIZED as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::UnexpectedList(inner) => {
                    <UnexpectedList as alloy_sol_types::SolError>::abi_encoded_size(
                        inner,
                    )
                }
                Self::UnexpectedString(inner) => {
                    <UnexpectedString as alloy_sol_types::SolError>::abi_encoded_size(
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
                Self::ContentLengthMismatch(inner) => {
                    <ContentLengthMismatch as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::EmptyItem(inner) => {
                    <EmptyItem as alloy_sol_types::SolError>::abi_encode_raw(inner, out)
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
                Self::InvalidDataRemainder(inner) => {
                    <InvalidDataRemainder as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::InvalidHeader(inner) => {
                    <InvalidHeader as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::LTP_INVALID_ACCOUNT_PROOF(inner) => {
                    <LTP_INVALID_ACCOUNT_PROOF as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::LTP_INVALID_INCLUSION_PROOF(inner) => {
                    <LTP_INVALID_INCLUSION_PROOF as alloy_sol_types::SolError>::abi_encode_raw(
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
                Self::SS_CHECKPOINTS_CLOSED(inner) => {
                    <SS_CHECKPOINTS_CLOSED as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_CHECKPOINT_NOT_FOUND(inner) => {
                    <SS_CHECKPOINT_NOT_FOUND as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_EMPTY_PROOF(inner) => {
                    <SS_EMPTY_PROOF as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_INVALID_BLOCK_ID(inner) => {
                    <SS_INVALID_BLOCK_ID as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_INVALID_CHECKPOINT(inner) => {
                    <SS_INVALID_CHECKPOINT as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_INVALID_PROOF_LENGTH(inner) => {
                    <SS_INVALID_PROOF_LENGTH as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_SIGNAL_NOT_RECEIVED(inner) => {
                    <SS_SIGNAL_NOT_RECEIVED as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_STATE_ROOT_NOT_FOUND(inner) => {
                    <SS_STATE_ROOT_NOT_FOUND as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::SS_UNAUTHORIZED(inner) => {
                    <SS_UNAUTHORIZED as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::UnexpectedList(inner) => {
                    <UnexpectedList as alloy_sol_types::SolError>::abi_encode_raw(
                        inner,
                        out,
                    )
                }
                Self::UnexpectedString(inner) => {
                    <UnexpectedString as alloy_sol_types::SolError>::abi_encode_raw(
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
    ///Container for all the [`SignalService`](self) events.
    #[derive(Clone)]
    #[derive(serde::Serialize, serde::Deserialize)]
    #[derive(Debug, PartialEq, Eq, Hash)]
    pub enum SignalServiceEvents {
        #[allow(missing_docs)]
        AdminChanged(AdminChanged),
        #[allow(missing_docs)]
        BeaconUpgraded(BeaconUpgraded),
        #[allow(missing_docs)]
        CheckpointSaved(CheckpointSaved),
        #[allow(missing_docs)]
        Initialized(Initialized),
        #[allow(missing_docs)]
        OwnershipTransferStarted(OwnershipTransferStarted),
        #[allow(missing_docs)]
        OwnershipTransferred(OwnershipTransferred),
        #[allow(missing_docs)]
        Paused(Paused),
        #[allow(missing_docs)]
        SignalSent(SignalSent),
        #[allow(missing_docs)]
        Unpaused(Unpaused),
        #[allow(missing_docs)]
        Upgraded(Upgraded),
    }
    impl SignalServiceEvents {
        /// All the selectors of this enum.
        ///
        /// Note that the selectors might not be in the same order as the variants.
        /// No guarantees are made about the order of the selectors.
        ///
        /// Prefer using `SolInterface` methods instead.
        pub const SELECTORS: &'static [[u8; 32usize]] = &[
            [
                10u8, 210u8, 209u8, 8u8, 102u8, 10u8, 33u8, 31u8, 71u8, 191u8, 127u8,
                180u8, 58u8, 4u8, 67u8, 202u8, 225u8, 129u8, 98u8, 73u8, 149u8, 211u8,
                212u8, 43u8, 136u8, 238u8, 104u8, 121u8, 210u8, 0u8, 233u8, 115u8,
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
                188u8, 124u8, 215u8, 90u8, 32u8, 238u8, 39u8, 253u8, 154u8, 222u8, 186u8,
                179u8, 32u8, 65u8, 247u8, 85u8, 33u8, 77u8, 188u8, 107u8, 255u8, 169u8,
                12u8, 192u8, 34u8, 91u8, 57u8, 218u8, 46u8, 92u8, 45u8, 59u8,
            ],
            [
                247u8, 38u8, 197u8, 60u8, 187u8, 158u8, 98u8, 85u8, 42u8, 252u8, 74u8,
                143u8, 27u8, 177u8, 208u8, 31u8, 169u8, 39u8, 46u8, 82u8, 106u8, 126u8,
                58u8, 105u8, 235u8, 169u8, 59u8, 119u8, 139u8, 63u8, 66u8, 166u8,
            ],
        ];
        /// The names of the variants in the same order as `SELECTORS`.
        pub const VARIANT_NAMES: &'static [&'static str] = &[
            ::core::stringify!(SignalSent),
            ::core::stringify!(BeaconUpgraded),
            ::core::stringify!(OwnershipTransferStarted),
            ::core::stringify!(Unpaused),
            ::core::stringify!(Paused),
            ::core::stringify!(AdminChanged),
            ::core::stringify!(Initialized),
            ::core::stringify!(OwnershipTransferred),
            ::core::stringify!(Upgraded),
            ::core::stringify!(CheckpointSaved),
        ];
        /// The signatures in the same order as `SELECTORS`.
        pub const SIGNATURES: &'static [&'static str] = &[
            <SignalSent as alloy_sol_types::SolEvent>::SIGNATURE,
            <BeaconUpgraded as alloy_sol_types::SolEvent>::SIGNATURE,
            <OwnershipTransferStarted as alloy_sol_types::SolEvent>::SIGNATURE,
            <Unpaused as alloy_sol_types::SolEvent>::SIGNATURE,
            <Paused as alloy_sol_types::SolEvent>::SIGNATURE,
            <AdminChanged as alloy_sol_types::SolEvent>::SIGNATURE,
            <Initialized as alloy_sol_types::SolEvent>::SIGNATURE,
            <OwnershipTransferred as alloy_sol_types::SolEvent>::SIGNATURE,
            <Upgraded as alloy_sol_types::SolEvent>::SIGNATURE,
            <CheckpointSaved as alloy_sol_types::SolEvent>::SIGNATURE,
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
    impl alloy_sol_types::SolEventInterface for SignalServiceEvents {
        const NAME: &'static str = "SignalServiceEvents";
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
                Some(<BeaconUpgraded as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <BeaconUpgraded as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::BeaconUpgraded)
                }
                Some(<CheckpointSaved as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <CheckpointSaved as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::CheckpointSaved)
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
                Some(<SignalSent as alloy_sol_types::SolEvent>::SIGNATURE_HASH) => {
                    <SignalSent as alloy_sol_types::SolEvent>::decode_raw_log(
                            topics,
                            data,
                        )
                        .map(Self::SignalSent)
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
    impl alloy_sol_types::private::IntoLogData for SignalServiceEvents {
        fn to_log_data(&self) -> alloy_sol_types::private::LogData {
            match self {
                Self::AdminChanged(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::BeaconUpgraded(inner) => {
                    alloy_sol_types::private::IntoLogData::to_log_data(inner)
                }
                Self::CheckpointSaved(inner) => {
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
                Self::SignalSent(inner) => {
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
                Self::CheckpointSaved(inner) => {
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
                Self::SignalSent(inner) => {
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
    /**Creates a new wrapper around an on-chain [`SignalService`](self) contract instance.

See the [wrapper's documentation](`SignalServiceInstance`) for more details.*/
    #[inline]
    pub const fn new<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    >(
        address: alloy_sol_types::private::Address,
        __provider: P,
    ) -> SignalServiceInstance<P, N> {
        SignalServiceInstance::<P, N>::new(address, __provider)
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
        authorizedSyncer: alloy::sol_types::private::Address,
        remoteSignalService: alloy::sol_types::private::Address,
        _pauser: alloy::sol_types::private::Address,
        _beaconRootsFrom: u64,
    ) -> impl ::core::future::Future<
        Output = alloy_contract::Result<SignalServiceInstance<P, N>>,
    > {
        SignalServiceInstance::<
            P,
            N,
        >::deploy(
            __provider,
            authorizedSyncer,
            remoteSignalService,
            _pauser,
            _beaconRootsFrom,
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
        __provider: P,
        authorizedSyncer: alloy::sol_types::private::Address,
        remoteSignalService: alloy::sol_types::private::Address,
        _pauser: alloy::sol_types::private::Address,
        _beaconRootsFrom: u64,
    ) -> alloy_contract::RawCallBuilder<P, N> {
        SignalServiceInstance::<
            P,
            N,
        >::deploy_builder(
            __provider,
            authorizedSyncer,
            remoteSignalService,
            _pauser,
            _beaconRootsFrom,
        )
    }
    /**A [`SignalService`](self) instance.

Contains type-safe methods for interacting with an on-chain instance of the
[`SignalService`](self) contract located at a given `address`, using a given
provider `P`.

If the contract bytecode is available (see the [`sol!`](alloy_sol_types::sol!)
documentation on how to provide it), the `deploy` and `deploy_builder` methods can
be used to deploy a new instance of the contract.

See the [module-level documentation](self) for all the available methods.*/
    #[derive(Clone)]
    pub struct SignalServiceInstance<P, N = alloy_contract::private::Ethereum> {
        address: alloy_sol_types::private::Address,
        provider: P,
        _network: ::core::marker::PhantomData<N>,
    }
    #[automatically_derived]
    impl<P, N> ::core::fmt::Debug for SignalServiceInstance<P, N> {
        #[inline]
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_tuple("SignalServiceInstance").field(&self.address).finish()
        }
    }
    /// Instantiation and getters/setters.
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > SignalServiceInstance<P, N> {
        /**Creates a new wrapper around an on-chain [`SignalService`](self) contract instance.

See the [wrapper's documentation](`SignalServiceInstance`) for more details.*/
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
            authorizedSyncer: alloy::sol_types::private::Address,
            remoteSignalService: alloy::sol_types::private::Address,
            _pauser: alloy::sol_types::private::Address,
            _beaconRootsFrom: u64,
        ) -> alloy_contract::Result<SignalServiceInstance<P, N>> {
            let call_builder = Self::deploy_builder(
                __provider,
                authorizedSyncer,
                remoteSignalService,
                _pauser,
                _beaconRootsFrom,
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
            authorizedSyncer: alloy::sol_types::private::Address,
            remoteSignalService: alloy::sol_types::private::Address,
            _pauser: alloy::sol_types::private::Address,
            _beaconRootsFrom: u64,
        ) -> alloy_contract::RawCallBuilder<P, N> {
            alloy_contract::RawCallBuilder::new_raw_deploy(
                __provider,
                [
                    &BYTECODE[..],
                    &alloy_sol_types::SolConstructor::abi_encode(
                        &constructorCall {
                            authorizedSyncer,
                            remoteSignalService,
                            _pauser,
                            _beaconRootsFrom,
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
    impl<P: ::core::clone::Clone, N> SignalServiceInstance<&P, N> {
        /// Clones the provider and returns a new instance with the cloned provider.
        #[inline]
        pub fn with_cloned_provider(self) -> SignalServiceInstance<P, N> {
            SignalServiceInstance {
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
    > SignalServiceInstance<P, N> {
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
        ///Creates a new call builder for the [`BEACON_ROOTS`] function.
        pub fn BEACON_ROOTS(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, BEACON_ROOTSCall, N> {
            self.call_builder(&BEACON_ROOTSCall)
        }
        ///Creates a new call builder for the [`VERSION`] function.
        pub fn VERSION(&self) -> alloy_contract::SolCallBuilder<&P, VERSIONCall, N> {
            self.call_builder(&VERSIONCall)
        }
        ///Creates a new call builder for the [`acceptOwnership`] function.
        pub fn acceptOwnership(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, acceptOwnershipCall, N> {
            self.call_builder(&acceptOwnershipCall)
        }
        ///Creates a new call builder for the [`beaconRootsFrom`] function.
        pub fn beaconRootsFrom(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, beaconRootsFromCall, N> {
            self.call_builder(&beaconRootsFromCall)
        }
        ///Creates a new call builder for the [`getCheckpoint`] function.
        pub fn getCheckpoint(
            &self,
            _blockNumber: alloy::sol_types::private::primitives::aliases::U48,
        ) -> alloy_contract::SolCallBuilder<&P, getCheckpointCall, N> {
            self.call_builder(&getCheckpointCall { _blockNumber })
        }
        ///Creates a new call builder for the [`getSignalSlot`] function.
        pub fn getSignalSlot(
            &self,
            _chainId: u64,
            _app: alloy::sol_types::private::Address,
            _signal: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, getSignalSlotCall, N> {
            self.call_builder(
                &getSignalSlotCall {
                    _chainId,
                    _app,
                    _signal,
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
        ///Creates a new call builder for the [`init`] function.
        pub fn init(
            &self,
            _owner: alloy::sol_types::private::Address,
        ) -> alloy_contract::SolCallBuilder<&P, initCall, N> {
            self.call_builder(&initCall { _owner })
        }
        ///Creates a new call builder for the [`isSignalSent_0`] function.
        pub fn isSignalSent_0(
            &self,
            _app: alloy::sol_types::private::Address,
            _signal: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isSignalSent_0Call, N> {
            self.call_builder(
                &isSignalSent_0Call {
                    _app,
                    _signal,
                },
            )
        }
        ///Creates a new call builder for the [`isSignalSent_1`] function.
        pub fn isSignalSent_1(
            &self,
            _signalSlot: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, isSignalSent_1Call, N> {
            self.call_builder(&isSignalSent_1Call { _signalSlot })
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
        ///Creates a new call builder for the [`pauser`] function.
        pub fn pauser(&self) -> alloy_contract::SolCallBuilder<&P, pauserCall, N> {
            self.call_builder(&pauserCall)
        }
        ///Creates a new call builder for the [`pendingOwner`] function.
        pub fn pendingOwner(
            &self,
        ) -> alloy_contract::SolCallBuilder<&P, pendingOwnerCall, N> {
            self.call_builder(&pendingOwnerCall)
        }
        ///Creates a new call builder for the [`proveSignalReceived`] function.
        pub fn proveSignalReceived(
            &self,
            _chainId: u64,
            _app: alloy::sol_types::private::Address,
            _signal: alloy::sol_types::private::FixedBytes<32>,
            _proof: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, proveSignalReceivedCall, N> {
            self.call_builder(
                &proveSignalReceivedCall {
                    _chainId,
                    _app,
                    _signal,
                    _proof,
                },
            )
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
        ///Creates a new call builder for the [`saveCheckpoint`] function.
        pub fn saveCheckpoint(
            &self,
            _checkpoint: <ICheckpointStore::Checkpoint as alloy::sol_types::SolType>::RustType,
        ) -> alloy_contract::SolCallBuilder<&P, saveCheckpointCall, N> {
            self.call_builder(&saveCheckpointCall { _checkpoint })
        }
        ///Creates a new call builder for the [`sendSignal`] function.
        pub fn sendSignal(
            &self,
            _signal: alloy::sol_types::private::FixedBytes<32>,
        ) -> alloy_contract::SolCallBuilder<&P, sendSignalCall, N> {
            self.call_builder(&sendSignalCall { _signal })
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
        ///Creates a new call builder for the [`verifySignalReceived`] function.
        pub fn verifySignalReceived(
            &self,
            _chainId: u64,
            _app: alloy::sol_types::private::Address,
            _signal: alloy::sol_types::private::FixedBytes<32>,
            _proof: alloy::sol_types::private::Bytes,
        ) -> alloy_contract::SolCallBuilder<&P, verifySignalReceivedCall, N> {
            self.call_builder(
                &verifySignalReceivedCall {
                    _chainId,
                    _app,
                    _signal,
                    _proof,
                },
            )
        }
    }
    /// Event filters.
    impl<
        P: alloy_contract::private::Provider<N>,
        N: alloy_contract::private::Network,
    > SignalServiceInstance<P, N> {
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
        ///Creates a new event filter for the [`CheckpointSaved`] event.
        pub fn CheckpointSaved_filter(
            &self,
        ) -> alloy_contract::Event<&P, CheckpointSaved, N> {
            self.event_filter::<CheckpointSaved>()
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
        ///Creates a new event filter for the [`SignalSent`] event.
        pub fn SignalSent_filter(&self) -> alloy_contract::Event<&P, SignalSent, N> {
            self.event_filter::<SignalSent>()
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
