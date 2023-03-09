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

    bytes32 public constant genesisBlockHash = keccak256("genesisBlockHash");
    address public constant alice = 0xc8885E210E59Dba0164Ba7CDa25f607e6d586B7A;
    address public constant bob = 0x000000000000000000636F6e736F6c652e6c6f67;

    AddressManager public addressManager;

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        uint64 feeBase = 1E18;
        L1 = new TaikoL1();
        L1.init(address(addressManager), genesisBlockHash, feeBase);

        tko = new TaikoToken();
        tko.init(address(addressManager), "TaikoToken", "TKO");

        // register all addresses
        _registerAddress("taiko_token", address(tko));

        // set proto_broker to this address to mint some TKO
        _registerAddress("proto_broker", address(this));
        tko.mint(address(this), 1E9 ether);

        // set proto_broker to L1
        _registerAddress("proto_broker", address(L1));
    }

    function proposeBlock(
        address proposer,
        uint256 txListSize
    ) internal returns (TaikoData.BlockMetadata memory meta) {
        uint64 gasLimit = 1000000;
        bytes memory txList = new bytes(txListSize);
        TaikoData.BlockMetadataInput memory input = TaikoData
            .BlockMetadataInput({
                beneficiary: proposer,
                gasLimit: gasLimit,
                txListHash: keccak256(txList)
            });

        TaikoData.StateVariables memory variables = L1.getStateVariables();

        uint256 mixHash;
        unchecked {
            mixHash = block.prevrandao * variables.nextBlockId;
        }
        meta.id = variables.nextBlockId;
        meta.l1Height = block.number - 1;
        meta.l1Hash = blockhash(block.number - 1);
        meta.beneficiary = proposer;
        meta.txListHash = keccak256(txList);
        meta.mixHash = bytes32(mixHash);
        meta.gasLimit = gasLimit;
        meta.timestamp = uint64(block.timestamp);

        vm.prank(proposer, proposer);
        bytes32 metaHash = L1.proposeBlock(input, txList);

        assertEq(metaHash, keccak256(abi.encode(meta)));
    }

    function proveBlock(
        address prover,
        TaikoData.Config memory conf,
        uint256 blockId,
        bytes32 parentHash,
        TaikoData.BlockMetadata memory meta
    ) internal returns (bytes32 blockHash) {
        bytes32[8] memory logsBloom;

        BlockHeader memory header = BlockHeader({
            parentHash: parentHash,
            ommersHash: LibBlockHeader.EMPTY_OMMERS_HASH,
            beneficiary: meta.beneficiary,
            stateRoot: bytes32(blockId + 200),
            transactionsRoot: bytes32(blockId + 201),
            receiptsRoot: bytes32(blockId + 202),
            logsBloom: logsBloom,
            difficulty: 0,
            height: uint128(blockId),
            gasLimit: uint64(meta.gasLimit + conf.anchorTxGasLimit),
            gasUsed: uint64(100),
            timestamp: meta.timestamp,
            extraData: new bytes(0),
            mixHash: bytes32(meta.mixHash),
            nonce: 0,
            baseFeePerGas: 10000
        });

        blockHash = LibBlockHeader.hashBlockHeader(header);

        TaikoData.ZKProof memory zkproof = TaikoData.ZKProof({
            data: new bytes(100),
            circuitId: 1
        });

        TaikoData.ValidBlockEvidence memory evidence = TaikoData
            .ValidBlockEvidence({
                meta: meta,
                zkproof: zkproof,
                header: header,
                signalRoot: bytes32(blockId + 400),
                prover: prover
            });
        vm.prank(prover, prover);
        L1.proveBlock(blockId, evidence);
    }

    function testProposeSingleBlock() external {
        _depositTaikoToken(alice, 1E6, 100);
        _depositTaikoToken(bob, 1E6, 100);

        bytes32 parentHash = genesisBlockHash;

        TaikoData.Config memory conf = L1.getConfig();
        for (uint blockId = 1; blockId < conf.maxNumBlocks * 2; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(alice, 1024);
            parentHash = proveBlock(bob, conf, blockId, parentHash, meta);
        }
    }

    function _registerAddress(string memory name, address addr) internal {
        string memory key = string.concat(
            Strings.toString(block.chainid),
            ".",
            name
        );
        addressManager.setAddress(key, addr);
    }

    function _depositTaikoToken(
        address who,
        uint256 amountTko,
        uint amountEth
    ) private {
        vm.deal(who, amountEth * 1 ether);
        tko.transfer(who, amountTko * 1 ether);
        vm.prank(who, who);
        L1.deposit(amountTko);
    }
}
