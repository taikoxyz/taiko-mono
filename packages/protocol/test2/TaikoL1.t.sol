// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/TaikoConfig.sol";
import "../contracts/L1/TaikoData.sol";
import "../contracts/L1/TaikoToken.sol";
import "../contracts/libs/LibBlockHeader.sol";

contract TaikoL1Test is Test {
    TaikoToken public tko;
    TaikoL1 public L1;

    AddressManager public addressManager;
    bytes32 public genesisBlockHash;

    function registerContract(string memory name, address addr) internal {
        string memory key = string.concat(
            Strings.toString(block.chainid),
            ".",
            name
        );
        addressManager.setAddress(key, addr);
    }

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        uint64 feeBase = 1E18;
        L1 = new TaikoL1();
        L1.init(address(addressManager), genesisBlockHash, feeBase);

        tko = new TaikoToken();
        tko.init(address(addressManager), "TaikoToken", "TKO");

        // register all addresses
        registerContract("taiko_token", address(tko));

        // set proto_broker to this address to mint some TKO
        registerContract("proto_broker", address(this));
        tko.mint(address(this), 1E9 ether);

        // set proto_broker to L1
        registerContract("proto_broker", address(L1));
    }

    function proposeBlock(
        address proposer,
        uint256 txListSize
    ) internal returns (TaikoData.BlockMetadata memory meta) {
        bytes memory txList = new bytes(txListSize);
        TaikoData.BlockMetadataInput memory input = TaikoData
            .BlockMetadataInput({
                beneficiary: proposer,
                gasLimit: 1000000,
                txListHash: keccak256(txList)
            });


        vm.prank(proposer, proposer);
        L1.proposeBlock(input, txList);


    }

    function proveBlock(
        address prover,
        TaikoData.Config memory conf,
        uint256 blockId,
        bytes32 parentHash,
        TaikoData.BlockMetadata memory meta
    ) internal returns (bytes32 blockHash) {
        bytes32[8] memory logsBloom;

        // BlockHeader memory header = BlockHeader({
        //     parentHash: parentHash,
        //     ommersHash: LibBlockHeader.EMPTY_OMMERS_HASH,
        //     beneficiary: meta.beneficiary,
        //     stateRoot: bytes32(blockId + 200),
        //     transactionsRoot: bytes32(blockId + 201),
        //     receiptsRoot: bytes32(blockId + 202),
        //     logsBloom: logsBloom,
        //     difficulty: 0,
        //     height: uint128(blockId),
        //     gasLimit: uint64(meta.gasLimit + conf.anchorTxGasLimit),
        //     gasUsed: uint64(100),
        //     timestamp: meta.timestamp,
        //     extraData: meta.extraData,
        //     mixHash: meta.mixHash,
        //     nonce: 0,
        //     baseFeePerGas: 10000
        // });

        // blockHash = LibBlockHeader.hashBlockHeader(header);

        // TaikoData.ZKProof memory zkproof = TaikoData.ZKProof({
        //     data: new bytes(100),
        //     circuitId: 1
        // });

        // TaikoData.ValidBlockEvidence memory evidence = TaikoData
        //     .ValidBlockEvidence({
        //         meta: meta,
        //         zkproof: zkproof,
        //         header: header,
        //         signalRoot: bytes32(blockId + 400),
        //         prover: prover
        //     });
        // bytes memory evidenceBytes = abi.encode(evidence);
        // vm.prank(prover, prover);
        // L1.proveBlock(blockId, evidenceBytes);
    }

    function teastProposeSingleBlock() external {
        address alice = 0xc8885E210E59Dba0164Ba7CDa25f607e6d586B7A;
        vm.deal(alice, 100 ether);
        tko.transfer(alice, 1E6 ether);
        // console2.logUint(tko.balanceOf(alice));

        address bob = 0x000000000000000000636F6e736F6c652e6c6f67;
        vm.deal(bob, 100 ether);

        bytes32 parentHash = genesisBlockHash;

        TaikoData.Config memory conf = L1.getConfig();
        for (uint blockId = 1; blockId < conf.maxNumBlocks * 2; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(alice, 1024);
            parentHash = proveBlock(bob, conf, blockId, parentHash, meta);
        }
    }
}
