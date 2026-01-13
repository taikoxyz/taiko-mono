// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/libs/LibTrieProof.sol";

contract LibNetworkTest is CommonTest {
    function test_isEthereumTestnet() public pure {
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_ROPSTEN));
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_RINKEBY));
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_GOERLI));
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_KOVAN));
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_HOLESKY));
        assertTrue(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_SEPOLIA));
        assertFalse(LibNetwork.isEthereumTestnet(LibNetwork.ETHEREUM_MAINNET));
        assertFalse(LibNetwork.isEthereumTestnet(LibNetwork.TAIKO_MAINNET));
    }

    function test_isEthereumMainnetOrTestnet() public pure {
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_MAINNET));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_ROPSTEN));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_RINKEBY));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_GOERLI));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_KOVAN));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_HOLESKY));
        assertTrue(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.ETHEREUM_SEPOLIA));
        assertFalse(LibNetwork.isEthereumMainnetOrTestnet(LibNetwork.TAIKO_MAINNET));
    }

    function test_isTaikoMainnet() public pure {
        assertTrue(LibNetwork.isTaikoMainnet(LibNetwork.TAIKO_MAINNET));
        assertFalse(LibNetwork.isTaikoMainnet(LibNetwork.ETHEREUM_MAINNET));
        assertFalse(LibNetwork.isTaikoMainnet(LibNetwork.TAIKO_HEKLA));
    }

    function test_isTaikoDevnet() public pure {
        assertTrue(LibNetwork.isTaikoDevnet(32_300));
        assertTrue(LibNetwork.isTaikoDevnet(32_350));
        assertTrue(LibNetwork.isTaikoDevnet(32_400));
        assertFalse(LibNetwork.isTaikoDevnet(32_299));
        assertFalse(LibNetwork.isTaikoDevnet(32_401));
        assertFalse(LibNetwork.isTaikoDevnet(LibNetwork.TAIKO_MAINNET));
    }

    function test_isDencunSupported() public pure {
        assertTrue(LibNetwork.isDencunSupported(LibNetwork.ETHEREUM_MAINNET));
        assertTrue(LibNetwork.isDencunSupported(LibNetwork.ETHEREUM_HOLESKY));
        assertTrue(LibNetwork.isDencunSupported(LibNetwork.ETHEREUM_SEPOLIA));
        assertTrue(LibNetwork.isDencunSupported(32_350)); // Taiko Devnet within range
        assertFalse(LibNetwork.isDencunSupported(LibNetwork.ETHEREUM_ROPSTEN));
        assertFalse(LibNetwork.isDencunSupported(LibNetwork.TAIKO_MAINNET));
    }
}
