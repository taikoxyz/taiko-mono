// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { LibProving } from "../../contracts/L1/libs/LibProving.sol";
import { LibUtils } from "../../contracts/L1/libs/LibUtils.sol";
import { TaikoData } from "../../contracts/L1/TaikoData.sol";
import { TaikoL1 } from "../../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { ProofVerifier } from "../../contracts/L1/ProofVerifier.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AddressResolver } from "../../contracts/common/AddressResolver.sol";

contract MockVerifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

abstract contract TaikoL1TestBase is TestBase {
    AddressManager public addressManager;
    TaikoToken public tko;
    SignalService public ss;
    TaikoL1 public L1;
    TaikoData.Config conf;
    uint256 internal logCount;
    ProofVerifier public pv;

    bytes32 public constant GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");
    // 1 TKO --> it is to huge. It should be in 'wei' (?).
    // Because otherwise first proposal is around: 1TKO * (1_000_000+20_000)
    // required as a deposit.
    // uint32 feePerGas = 10;
    // uint16 proofWindow = 60 minutes;
    uint64 l2GasExcess = 1e18;

    address public constant L2Treasury =
        0x859d74b52762d9ed07D1b2B8d7F93d26B1EA78Bb;
    address public constant L2SS = 0xa008AE5Ba00656a3Cc384de589579e3E52aC030C;
    address public constant TaikoL2 = 0x0082D90249342980d011C58105a03b35cCb4A315;
    address public constant L1EthVault =
        0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;

    function deployTaikoL1() internal virtual returns (TaikoL1 taikoL1);

    function setUp() public virtual {
        L1 = deployTaikoL1();
        conf = L1.getConfig();

        addressManager = new AddressManager();
        addressManager.init();

        ss = new SignalService();
        ss.init(address(addressManager));

        pv = new ProofVerifier();
        pv.init(address(addressManager));

        registerAddress("proof_verifier", address(pv));
        registerAddress("signal_service", address(ss));
        registerAddress("ether_vault", address(L1EthVault));
        registerL2Address("treasury", L2Treasury);
        registerL2Address("taiko", address(TaikoL2));
        registerL2Address("signal_service", address(L2SS));
        registerL2Address("taiko_l2", address(TaikoL2));
        registerAddress(L1.getVerifierName(100), address(new MockVerifier()));
        registerAddress(L1.getVerifierName(0), address(new MockVerifier()));

        tko = new TaikoToken();
        registerAddress("taiko_token", address(tko));
        address[] memory premintRecipients = new address[](1);
        premintRecipients[0] = address(this);

        uint256[] memory premintAmounts = new uint256[](1);
        premintAmounts[0] = 1e9 ether;

        tko.init(
            address(addressManager),
            "TaikoToken",
            "TKO",
            premintRecipients,
            premintAmounts
        );

        // Set protocol broker
        registerAddress("taiko", address(this));
        tko.mint(address(this), 1e9 ether);

        registerAddress("taiko", address(L1));

        L1.init(address(addressManager), GENESIS_BLOCK_HASH);
        printVariables("init  ");
    }

    function proposeBlock(
        address proposer,
        address prover,
        uint32 gasLimit,
        uint24 txListSize
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        TaikoData.ProverAssignment memory assignment = TaikoData
            .ProverAssignment({
            prover: prover,
            expiry: uint64(block.timestamp + 60 minutes),
            data: new bytes(0)
        });

        bytes memory txList = new bytes(txListSize);
        TaikoData.BlockMetadataInput memory input = TaikoData.BlockMetadataInput({
            proposer: proposer,
            txListHash: keccak256(txList),
            txListByteStart: 0,
            txListByteEnd: txListSize,
            cacheTxListInfo: false
        });

        TaikoData.StateVariables memory variables = L1.getStateVariables();

        uint256 _mixHash;
        unchecked {
            _mixHash = block.prevrandao * variables.numBlocks;
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
        meta.proposer = proposer;

        vm.prank(proposer, proposer);
        meta =
            L1.proposeBlock(abi.encode(input), abi.encode(assignment), txList);
    }

    function proveBlock(
        address msgSender,
        address prover,
        TaikoData.BlockMetadata memory meta,
        bytes32 parentHash,
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
            proofs: new bytes(102)
        });

        bytes32 instance = LibProving.getInstance(evidence);
        uint16 verifierId = 100;

        evidence.proofs = bytes.concat(
            bytes2(verifierId),
            bytes16(0),
            bytes16(instance),
            bytes16(0),
            bytes16(uint128(uint256(instance))),
            new bytes(100)
        );

        vm.prank(msgSender, msgSender);
        L1.proveBlock(meta.id, abi.encode(evidence));
    }

    function verifyBlock(address verifier, uint64 count) internal {
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

    function giveEthAndTko(
        address to,
        uint256 amountTko,
        uint256 amountEth
    )
        internal
    {
        vm.deal(to, amountEth);
        console2.log("TKO balance this:", tko.balanceOf(address(this)));
        console2.log(amountTko);
        tko.transfer(to, amountTko);

        vm.prank(to, to);
        tko.approve(address(L1), amountTko);

        console2.log("TKO balance:", to, tko.balanceOf(to));
        console2.log("ETH balance:", to, to.balance);
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

    function mine(uint256 counts) internal {
        vm.warp(block.timestamp + 20 * counts);
        vm.roll(block.number + counts);
    }
}
