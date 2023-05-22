// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/common/AddressManager.sol";
import {LibUtils} from "../contracts/L1/libs/LibUtils.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

abstract contract TaikoL1TestBase is Test {
    AddressManager public addressManager;
    TaikoToken public tko;
    SignalService public ss;
    TaikoL1 public L1;
    TaikoData.Config conf;
    uint256 internal logCount;

    bytes32 public constant GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");
    uint64 feeBase = 1e8; // 1 TKO
    uint64 l2GasExcess = 1e18;

    address public constant L2Treasury = 0x859d74b52762d9ed07D1b2B8d7F93d26B1EA78Bb;
    address public constant L2SS = 0xa008AE5Ba00656a3Cc384de589579e3E52aC030C;
    address public constant TaikoL2 = 0x0082D90249342980d011C58105a03b35cCb4A315;
    address public constant L1EthVault = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;

    address public constant Alice = 0xa9bcF99f5eb19277f48b71F9b14f5960AEA58a89;
    uint256 public constant AlicePK =
        0x8fb342c39a93ad26e674cbcdc65dc45795107e1b51776aac15f9776c0e9d2cea;

    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;
    address public constant Carol = 0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant Dave = 0x400147C0Eb43D8D71b2B03037bB7B31f8f78EF5F;
    address public constant Eve = 0x50081b12838240B1bA02b3177153Bca678a86078;
    address public constant Frank = 0x430c9b60e19634e12FC6d68B7fEa7bFB26c2e419;
    address public constant George = 0x520147C0eB43d8D71b2b03037bB7b31f8F78EF5f;
    address public constant Hilbert = 0x61081B12838240B1Ba02b3177153BcA678a86078;

    // Calculation shall be done in derived contracts - based on testnet or mainnet expected proof time
    uint64 public initProofTimeIssued;
    uint16 proofTimeTarget;
    uint8 public constant ADJUSTMENT_QUOTIENT = 16;

    function deployTaikoL1() internal virtual returns (TaikoL1 taikoL1);

    function setUp() public virtual {
        L1 = deployTaikoL1();
        conf = L1.getConfig();

        addressManager = new AddressManager();
        addressManager.init();

        ss = new SignalService();
        ss.init(address(addressManager));

        registerAddress("signal_service", address(ss));
        registerAddress("ether_vault", address(L1EthVault));
        registerL2Address("treasury", L2Treasury);
        registerL2Address("taiko", address(TaikoL2));
        registerL2Address("signal_service", address(L2SS));
        registerL2Address("taiko_l2", address(TaikoL2));
        registerAddress(L1.getVerifierName(100), address(new Verifier()));
        registerAddress(L1.getVerifierName(0), address(new Verifier()));

        tko = new TaikoToken();
        registerAddress("taiko_token", address(tko));
        address[] memory premintRecipients;
        uint256[] memory premintAmounts;
        tko.init(address(addressManager), "TaikoToken", "TKO", premintRecipients, premintAmounts);

        // Set protocol broker
        registerAddress("proto_broker", address(this));
        tko.mint(address(this), 1e9 * 1e8);
        registerAddress("proto_broker", address(L1));

        // Lastly, init L1
        if (proofTimeTarget == 0 || initProofTimeIssued == 0) {
            // This just means, these tests are not focusing on the tokenomics, which is fine!
            // So here, with 500second proof time the initial proof time issued value shall be that below.
            // Calculated with 'forge script script/DetermineNewProofTimeIssued.s.sol'
            proofTimeTarget = 500;
            initProofTimeIssued = 219263;
        }
        L1.init(
            address(addressManager),
            GENESIS_BLOCK_HASH,
            feeBase,
            proofTimeTarget,
            initProofTimeIssued
        );
        printVariables("init  ");
    }

    function proposeBlock(address proposer, uint32 gasLimit, uint24 txListSize)
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        bytes memory txList = new bytes(txListSize);
        TaikoData.BlockMetadataInput memory input = TaikoData.BlockMetadataInput({
            beneficiary: proposer,
            gasLimit: gasLimit,
            txListHash: keccak256(txList),
            txListByteStart: 0,
            txListByteEnd: txListSize,
            cacheTxListInfo: 0
        });

        TaikoData.StateVariables memory variables = L1.getStateVariables();

        uint256 _mixHash;
        unchecked {
            _mixHash = block.difficulty * variables.numBlocks;
        }

        meta.id = variables.numBlocks;
        meta.timestamp = uint64(block.timestamp);
        meta.l1Height = uint64(block.number - 1);
        meta.l1Hash = blockhash(block.number - 1);
        meta.mixHash = bytes32(_mixHash);
        meta.txListHash = keccak256(txList);
        meta.txListByteStart = 0;
        meta.txListByteEnd = txListSize;
        meta.gasLimit = gasLimit;
        meta.beneficiary = proposer;
        meta.treasury = L2Treasury;

        vm.prank(proposer, proposer);
        meta = L1.proposeBlock(abi.encode(input), txList);
    }

    function proveBlock(
        address msgSender,
        address prover,
        TaikoData.BlockMetadata memory meta,
        bytes32 parentHash,
        uint32 parentGasUsed,
        uint32 gasUsed,
        bytes32 blockHash,
        bytes32 signalRoot
    ) internal {
        TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
            metaHash: LibUtils.hashMetadata(meta),
            parentHash: parentHash,
            blockHash: blockHash,
            signalRoot: signalRoot,
            graffiti: 0x0,
            prover: prover,
            parentGasUsed: parentGasUsed,
            gasUsed: gasUsed,
            verifierId: 100,
            proof: new bytes(100)
        });

        vm.prank(msgSender, msgSender);
        L1.proveBlock(meta.id, abi.encode(evidence));
    }

    function verifyBlock(address verifier, uint256 count) internal {
        vm.prank(verifier, verifier);
        L1.verifyBlocks(count);
    }

    function registerAddress(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(block.chainid, nameHash, addr);
        console2.log(block.chainid, uint256(nameHash), unicode"→", addr);
    }

    function registerL2Address(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(conf.chainId, nameHash, addr);
        console2.log(conf.chainId, uint256(nameHash), unicode"→", addr);
    }

    function depositTaikoToken(address who, uint256 amountTko, uint256 amountEth) internal {
        vm.deal(who, amountEth);
        tko.transfer(who, amountTko);
        vm.prank(who, who);
        L1.depositTaikoToken(amountTko);
    }

    function printVariables(string memory comment) internal {
        TaikoData.StateVariables memory vars = L1.getStateVariables();

        uint256 fee = L1.getBlockFee();

        string memory str = string.concat(
            Strings.toString(logCount++),
            ":[",
            Strings.toString(vars.lastVerifiedBlockId),
            unicode"→",
            Strings.toString(vars.numBlocks),
            "]",
            " fee:",
            Strings.toString(fee)
        );

        str = string.concat(
            str,
            " nextEthDepositToProcess:",
            Strings.toString(vars.nextEthDepositToProcess),
            " numEthDeposits:",
            Strings.toString(vars.numEthDeposits),
            " // ",
            comment
        );
        console2.log(str);
    }

    function mine(uint256 counts) internal {
        vm.warp(block.timestamp + 20 * counts);
        vm.roll(block.number + counts);
    }
}
