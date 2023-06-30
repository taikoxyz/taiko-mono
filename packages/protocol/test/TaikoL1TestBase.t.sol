// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibUtils } from "../contracts/L1/libs/LibUtils.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { IProverPool } from "../contracts/L1/IProverPool.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AddressResolver } from "../contracts/common/AddressResolver.sol";

contract MockVerifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract MockProverPool is IProverPool {
    address private _prover;
    uint32 private _rewardPerGas;

    function reset(address prover, uint32 rewardPerGas) external {
        assert(prover != address(0) && rewardPerGas != 0);
        _prover = prover;
        _rewardPerGas = rewardPerGas;
    }

    function assignProver(
        uint64, /*blockId*/
        uint32 /*feePerGas*/
    )
        external
        view
        override
        returns (address, uint32)
    {
        return (_prover, _rewardPerGas);
    }

    function releaseProver(address prover) external pure override { }

    function slashProver(address prover) external pure override { }
}

abstract contract TaikoL1TestBase is Test {
    AddressManager public addressManager;
    TaikoToken public tko;
    SignalService public ss;
    TaikoL1 public L1;
    TaikoData.Config conf;
    MockProverPool public proverPool;
    uint256 internal logCount;

    // Constants of the input - it is a workaround - most probably a
    // forge/foundry issue. Issue link:
    // https://github.com/foundry-rs/foundry/issues/5200
    uint256[3] internal inputs012;

    bytes32 public constant GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");
    // 1 TKO --> it is to huge. It should be in 'wei' (?).
    // Because otherwise first proposal is around: 1TKO * (1_000_000+20_000)
    // required as a deposit.
    uint32 feePerGas = 10;
    uint16 proofWindow = 60 minutes;
    uint64 l2GasExcess = 1e18;

    address public constant L2Treasury =
        0x859d74b52762d9ed07D1b2B8d7F93d26B1EA78Bb;
    address public constant L2SS = 0xa008AE5Ba00656a3Cc384de589579e3E52aC030C;
    address public constant TaikoL2 = 0x0082D90249342980d011C58105a03b35cCb4A315;
    address public constant L1EthVault =
        0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;

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

    function deployTaikoL1() internal virtual returns (TaikoL1 taikoL1);

    function setUp() public virtual {
        L1 = deployTaikoL1();
        conf = L1.getConfig();

        addressManager = new AddressManager();
        addressManager.init();

        proverPool = new MockProverPool();

        ss = new SignalService();
        ss.init(address(addressManager));

        registerAddress("signal_service", address(ss));
        registerAddress("ether_vault", address(L1EthVault));
        registerAddress("prover_pool", address(proverPool));
        registerL2Address("treasury", L2Treasury);
        registerL2Address("taiko", address(TaikoL2));
        registerL2Address("signal_service", address(L2SS));
        registerL2Address("taiko_l2", address(TaikoL2));
        registerAddress(L1.getVerifierName(100), address(new MockVerifier()));
        registerAddress(L1.getVerifierName(0), address(new MockVerifier()));

        tko = new TaikoToken();
        registerAddress("taiko_token", address(tko));
        address[] memory premintRecipients;
        uint256[] memory premintAmounts;
        tko.init(
            address(addressManager),
            "TaikoToken",
            "TKO",
            premintRecipients,
            premintAmounts
        );

        // Set protocol broker
        registerAddress("taiko", address(this));
        tko.mint(address(this), 1e9 * 1e8);
        registerAddress("taiko", address(L1));

        L1.init(
            address(addressManager), GENESIS_BLOCK_HASH, feePerGas, proofWindow
        );
        printVariables("init  ");

        inputs012[0] =
            uint256(uint160(address(L1.resolve("signal_service", false))));
        inputs012[1] = uint256(
            uint160(address(L1.resolve(conf.chainId, "signal_service", false)))
        );
        inputs012[2] =
            uint256(uint160(address(L1.resolve(conf.chainId, "taiko", false))));
    }

    function proposeBlock(
        address proposer,
        uint32 gasLimit,
        uint24 txListSize
    )
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
            cacheTxListInfo: false
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
    )
        internal
    {
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

        bytes32 instance = getInstance(conf, L1, evidence);

        evidence.proof = bytes.concat(
            bytes16(0),
            bytes16(instance),
            bytes16(0),
            bytes16(uint128(uint256(instance))),
            new bytes(100)
        );

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
        console2.log(
            conf.chainId, string(abi.encodePacked(nameHash)), unicode"→", addr
        );
    }

    function depositTaikoToken(
        address who,
        uint64 amountTko,
        uint256 amountEth
    )
        internal
    {
        vm.deal(who, amountEth);
        tko.transfer(who, amountTko);
        console2.log("who", who);
        console2.log("balance:", tko.balanceOf(who));
        vm.prank(who, who);
        // Keep half for proving and deposit half for proposing fee
        L1.depositTaikoToken(amountTko / 2);
    }

    function printVariables(string memory comment) internal {
        TaikoData.StateVariables memory vars = L1.getStateVariables();

        string memory str = string.concat(
            Strings.toString(logCount++),
            ":[",
            Strings.toString(vars.lastVerifiedBlockId),
            unicode"→",
            Strings.toString(vars.numBlocks),
            "]"
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

    function getInstance(
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockEvidence memory evidence
    )
        internal
        view
        returns (bytes32 instance)
    {
        uint256[10] memory inputs;

        inputs[0] = inputs012[0];
        inputs[1] = inputs012[1];
        inputs[2] = inputs012[2];

        inputs[3] = uint256(evidence.metaHash);
        inputs[4] = uint256(evidence.parentHash);
        inputs[5] = uint256(evidence.blockHash);
        inputs[6] = uint256(evidence.signalRoot);
        inputs[7] = uint256(evidence.graffiti);
        inputs[8] = (uint256(uint160(evidence.prover)) << 96)
            | (uint256(evidence.parentGasUsed) << 64)
            | (uint256(evidence.gasUsed) << 32);

        // Also hash configs that will be used by circuits
        inputs[9] = uint256(config.blockMaxGasLimit) << 192
            | uint256(config.blockMaxTransactions) << 128
            | uint256(config.blockMaxTxListBytes) << 64;

        assembly {
            instance := keccak256(inputs, mul(32, 10))
        }
    }

    function mine(uint256 counts) internal {
        vm.warp(block.timestamp + 20 * counts);
        vm.roll(block.number + counts);
    }
}
