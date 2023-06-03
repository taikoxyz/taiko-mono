// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract LibEthDepositing {
    address public constant Alice = 0xa9bcF99f5eb19277f48b71F9b14f5960AEA58a89;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;
    address public constant Carol = 0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant Dave = 0x400147C0Eb43D8D71b2B03037bB7B31f8f78EF5F;
    address public constant Eve = 0x50081b12838240B1bA02b3177153Bca678a86078;
    address public constant Frank = 0x430c9b60e19634e12FC6d68B7fEa7bFB26c2e419;
    address public constant George = 0x520147C0eB43d8D71b2b03037bB7b31f8F78EF5f;
    address public constant Hilbert = 0x61081B12838240B1Ba02b3177153BcA678a86078;

    struct EthDeposit {
        address recipient;
        uint96 amount;
    }

    EthDeposit[] depositsProcessed;

    function processDeposits() public returns (bytes32 depositsRoot) {
        // Allocate one extra slot for collecting fees on L2

        depositsProcessed.push(EthDeposit(Alice, 1 ether));
        depositsProcessed.push(EthDeposit(Bob, 2 ether));
        depositsProcessed.push(EthDeposit(Carol, 3 ether));
        depositsProcessed.push(EthDeposit(Dave, 4 ether));
        depositsProcessed.push(EthDeposit(Eve, 5 ether));
        depositsProcessed.push(EthDeposit(Frank, 6 ether));
        depositsProcessed.push(EthDeposit(George, 7 ether));
        depositsProcessed.push(EthDeposit(Hilbert, 8 ether));

        EthDeposit[] memory depProcess = new EthDeposit[](
            8
        );

        depProcess[0] = depositsProcessed[0];
        depProcess[1] = depositsProcessed[1];
        depProcess[2] = depositsProcessed[2];
        depProcess[3] = depositsProcessed[3];
        depProcess[4] = depositsProcessed[4];
        depProcess[5] = depositsProcessed[5];
        depProcess[6] = depositsProcessed[6];
        depProcess[7] = depositsProcessed[7];

        assembly {
            mstore(depProcess, 8)
            depositsRoot := keccak256(add(depProcess, 0x20), mul(8, 32))
        }

        // console2.log("If i call the hash like this:");
        //console2.logBytes32(hashDeposits(depositsProcessed));

        // bytes memory serializedBytes;
        // for (uint256 i;i < depositsProcessed.length; i++) {
        //     serializedBytes= abi.encodePacked(serializedBytes,
        // serializeEthDeposit(depositsProcessed[i]));
        // }

        // console2.log("Raw bytestream is:");
        // console2.logBytes(serializedBytes);

        // console2.log("Keccak hash of that is:"); //
        // 0x8117066d69ff650d78f0d7383a10cc802c2b8c0eedd932d70994252e2438c636
        // console2.logBytes32(keccak256(serializedBytes));

        // console2.log("Keccak hash of deposit root:"); //
        // 0x0b036250add9a3bdc4414715e4c6d1cdf117101686b40b3c9e5e2a8c84d957e4
        console2.logBytes32(depositsRoot);
    }

    function hashDeposits(EthDeposit[] memory deposits)
        public
        pure
        returns (bytes32)
    {
        bytes memory buffer;

        for (uint256 i = 0; i < deposits.length; i++) {
            buffer = abi.encodePacked(
                buffer, deposits[i].recipient, deposits[i].amount
            );
        }

        return keccak256(buffer);
    }
}
