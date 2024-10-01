// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title LibNetwork
library LibNetwork {
    uint256 internal constant ETHEREUM_MAINNET = 1;
    uint256 internal constant ETHEREUM_ROPSTEN = 2;
    uint256 internal constant ETHEREUM_RINKEBY = 4;
    uint256 internal constant ETHEREUM_GOERLI = 5;
    uint256 internal constant ETHEREUM_KOVAN = 42;
    uint256 internal constant ETHEREUM_HOLESKY = 17_000;
    uint256 internal constant ETHEREUM_SEPOLIA = 11_155_111;

    uint64 internal constant TAIKO_MAINNET = 167_000;
    uint64 internal constant TAIKO_HEKLA = 167_009;

    /// @dev Checks if the chain ID represents an Ethereum testnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an Ethereum testnet, false otherwise.
    function isEthereumTestnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.ETHEREUM_ROPSTEN || _chainId == LibNetwork.ETHEREUM_RINKEBY
            || _chainId == LibNetwork.ETHEREUM_GOERLI || _chainId == LibNetwork.ETHEREUM_KOVAN
            || _chainId == LibNetwork.ETHEREUM_HOLESKY || _chainId == LibNetwork.ETHEREUM_SEPOLIA;
    }

    /// @dev Checks if the chain ID represents an Ethereum testnet or the Etheruem mainnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an Ethereum testnet or the Etheruem mainnet, false
    /// otherwise.
    function isEthereumMainnetOrTestnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.ETHEREUM_MAINNET || isEthereumTestnet(_chainId);
    }

    /// @dev Checks if the chain ID represents the Taiko L2 mainnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents the Taiko L2 mainnet.
    function isTaikoMainnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == TAIKO_MAINNET;
    }

    /// @dev Checks if the chain ID represents an internal Taiko devnet's base layer.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an internal Taiko devnet's base layer, false
    /// otherwise.
    function isTaikoDevnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId >= 32_300 && _chainId <= 32_400;
    }

    /// @dev Checks if the chain supports Dencun hardfork. Note that this check doesn't need to be
    /// exhaustive.
    /// @param _chainId The chain ID.
    /// @return true if the chain supports Dencun hardfork, false otherwise.
    function isDencunSupported(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.ETHEREUM_MAINNET || _chainId == LibNetwork.ETHEREUM_HOLESKY
            || _chainId == LibNetwork.ETHEREUM_SEPOLIA || isTaikoDevnet(_chainId);
    }
}
