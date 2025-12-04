// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/team/SimpleTokenUnlock.sol";
import "script/BaseScript.sol";

interface ICreateCall {
    function performCreate(uint256 value, bytes calldata initCode) external returns (address);
}

// Turns dry-run json of Deploy.s.sol into MultiSend calldata for Safe wallet.
contract ProposifyDeploy is BaseScript {
    using stdJson for string;

    struct TxRecord {
        Tx transaction;
    }

    struct Tx {
        bytes input;
    }

    // Safe CreateCall (mainnet v1.4.1)
    address public constant DEFAULT_CREATE_CALL = 0x9b35Af71d77eaf8d7e40252370304687390A1A52;
    string internal constant BROADCAST_PATH = "/broadcast/Deploy.s.sol/1/dry-run/run-latest.json";

    function run() public view {
        string memory json = vm.readFile(string.concat(vm.projectRoot(), BROADCAST_PATH));
        address createCall = vm.envOr("CREATE_CALL", DEFAULT_CREATE_CALL);
        require(createCall != address(0), "create call not set");

        TxRecord[] memory txs = abi.decode(vm.parseJson(json, ".transactions"), (TxRecord[]));
        uint256 count = txs.length;
        require(count == 22, "does not match number of recipients");

        bytes[] memory inputs = new bytes[](count);
        for (uint256 i; i < count; ++i) {
            string memory key = string.concat(".transactions[", vm.toString(i), "].transaction.input");
            inputs[i] = abi.decode(vm.parseJson(json, key), (bytes));
            require(inputs[i].length != 0, "missing input");
        }

        bytes memory packed;
        for (uint256 i; i < inputs.length; ++i) {
            bytes memory createData =
                abi.encodeWithSelector(ICreateCall.performCreate.selector, 0, inputs[i]);
            packed = bytes.concat(
                packed, abi.encodePacked(uint8(1), createCall, uint256(0), createData.length, createData)
            );
        }

        bytes memory multiSendData = abi.encodeWithSignature("multiSend(bytes)", packed);
        console2.log("tx count          :", inputs.length);
        console2.log("multisend calldata:", vm.toString(multiSendData));
    }

}
