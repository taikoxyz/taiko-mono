// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../contracts/team/proving/ProverSet.sol";
import "../test/DeployCapability.sol";

contract DeployProverSet is DeployCapability {
    // FOR HEKLA, change to mainnet ROLLUP_ADDRESS_MANAGER if deploying on mainnet.
    address public constant ROLLUP_ADDRESS_MANAGER = 0x1F027871F286Cf4B7F898B21298E7B3e090a8403;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // User should run the following command from proposer EOA before running this script:
        // `forge script --chain-id 17000 --broadcast --rpc-url {YOUR_RPC_URL}
        // --private-key=$PRIVATE_KEY script/DeployProverSetUtil.s.sol:DeployProverSetUtil`
        // Take the output and replace the following address.
        address proverSet = 0x2623ee5c74CB532EE1CAA47B5624DCe9b14ec51A;

        // Then run the script as follows
        // `forge script --chain-id 17000 --rpc-url {YOUR_RPC_URL} --private-key=$PRIVATE_KEY
        // --broadcast script/DeployProverSet.s.sol:DeployProverSet`

        // check that a contract is present at address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(proverSet)
        }
        require(codeSize > 0, "proverSet is not a contract");

        // If you are working with a third party prover, this will likely need to be set to their
        // prover address.
        // This gives this address the authorization to withdraw their deposited TAIKO should they
        // choose to.
        address admin = msg.sender;

        address proxyAddy = deployProverSetWithProxy(msg.sender, admin, proverSet);
        // With the following address you can register as proxy on Etherscan and access the
        // implementation contract.
        // Check the implementation, addressManager and admin address match the expected values.
        console2.log("Proxy Address: %s", proxyAddy);
    }

    function deployProverSetWithProxy(
        address owner,
        address admin,
        address proverSet
    )
        internal
        returns (address proxyAddress)
    {
        addressNotNull(owner, "owner");
        addressNotNull(proverSet, "proverSet");

        address proxy = deployProxy({
            name: "prover_set",
            impl: proverSet,
            data: abi.encodeCall(ProverSet.init, (owner, admin, ROLLUP_ADDRESS_MANAGER))
        });
        return proxy;
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
