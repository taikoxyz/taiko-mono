// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/TaikoData.sol";
import "../contracts/L1/TaikoToken.sol";

contract TaikoL1Test is Test {
    TaikoToken public tko;
    TaikoL1 public L1;

    AddressManager public addressManager;
    bytes32 public genesisBlockHash;

    function registerContract(string memory name, address addr) internal {
        string memory key =string.concat(Strings.toString(block.chainid), ".", name);
        addressManager.setAddress(key, addr);
    }

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        uint256 feeBase = 1E18;
        L1 = new TaikoL1();
        L1.init(address(addressManager), genesisBlockHash, feeBase);

        tko = new TaikoToken();
        tko.init(address(addressManager), "TaikoToken", "TKO");

        // register all addresses
        registerContract("taiko_token", address(tko));
    }

    function propose(address proposer, uint256 txListSize) internal {
        bytes[] memory inputs = new bytes[](3);
        inputs[1] = bytes("txList");
        inputs[2] = bytes("txListProof");

        TaikoData.BlockMetadata memory meta = TaikoData.BlockMetadata({
            id: 0,
            l1Height: 0,
            l1Hash: 0,
            beneficiary: proposer,
            txListHash: keccak256(inputs[1]),
            txListProofHash: keccak256(inputs[2]),
            mixHash: 0,
            extraData: new bytes(10),
            gasLimit: 1000000,
            timestamp: 0
        });

        inputs[0] = abi.encode(meta);

        vm.prank(proposer, proposer);
        L1.proposeBlock(inputs);
    }



    function testProposeSingleBlock() external {
        address alice = 0xc8885E210E59Dba0164Ba7CDa25f607e6d586B7A;
        vm.deal(alice, 1 ether);
        vm.deal(address(tko), alice, 100 ether);
        log_uint256(address(tko).balanceOf(alice);

        propose(alice, 1024);
    }
}
