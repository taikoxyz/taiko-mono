// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {IXchainSync} from "../common/IXchainSync.sol";
import {LibMath} from "../libs/LibMath.sol";
import {Lib1559Math} from "../libs/Lib1559Math.sol";
import {TaikoL2Signer} from "./TaikoL2Signer.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {console2} from "forge-std/console2.sol";

contract TaikoL2 is EssentialContract, TaikoL2Signer, IXchainSync {
    using SafeCastUpgradeable for uint256;
    using LibMath for uint256;

    struct VerifiedBlock {
        bytes32 blockHash;
        bytes32 signalRoot;
    }

    struct EIP1559Params {
        uint64 basefee;
        uint64 gasIssuedPerSecond;
        uint64 gasExcessMax;
        uint64 gasTarget;
        uint64 ratio2x1x;
    }
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    mapping(uint256 blockNumber => VerifiedBlock) private _l1VerifiedBlocks;

    // A hash to check te integrity of public inputs.
    bytes32 public publicInputHash;

    uint128 public yscale;
    uint64 public xscale;
    uint64 public gasIssuedPerSecond;

    uint64 public parentTimestamp;
    uint64 public latestSyncedL1Height;
    uint64 public basefee;
    uint64 public gasExcess;

    uint256[45] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    // Captures all block variables mentioned in
    // https://docs.soliditylang.org/en/v0.8.18/units-and-global-variables.html
    event BlockVars(
        uint64 number,
        uint64 basefee,
        uint64 gaslimit,
        uint64 timestamp,
        bytes32 parentHash,
        uint256 prevrandao,
        address coinbase,
        uint32 chainid
    );

    error L2_BASEFEE_MISMATCH(uint64 expected, uint64 actual);
    error L2_INVALID_1559_PARAMS();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH(bytes32 expected, bytes32 actual);
    error L2_TOO_LATE();

    error M1559_UNEXPECTED_CHANGE(uint64 expected, uint64 actual);
    error M1559_OUT_OF_STOCK();

    /**********************
     * Constructor         *
     **********************/

    function init(
        address _addressManager,
        EIP1559Params calldata _param1559
    ) external initializer {
        if (block.chainid <= 1 || block.chainid >= type(uint32).max)
            revert L2_INVALID_CHAIN_ID();
        if (block.number > 1) revert L2_TOO_LATE();

        if (_param1559.gasIssuedPerSecond != 0) {
            if (
                _param1559.gasIssuedPerSecond == 0 ||
                _param1559.gasExcessMax == 0 ||
                _param1559.gasTarget == 0 ||
                _param1559.ratio2x1x == 0
            ) revert L2_INVALID_1559_PARAMS();

            uint128 _xscale;
            (_xscale, yscale) = Lib1559Math.calculateScales({
                xExcessMax: _param1559.gasExcessMax,
                price: _param1559.basefee,
                target: _param1559.gasTarget,
                ratio2x1x: _param1559.ratio2x1x
            });

            if (_xscale == 0 || _xscale >= type(uint64).max || yscale == 0)
                revert L2_INVALID_1559_PARAMS();
            xscale = uint64(_xscale);

            basefee = _param1559.basefee;
            gasIssuedPerSecond = _param1559.gasIssuedPerSecond;
            gasExcess = _param1559.gasExcessMax / 2;
        }

        parentTimestamp = uint64(block.timestamp);

        EssentialContract._init(_addressManager);

        (publicInputHash, ) = _calcPublicInputHash(block.number);
        if (block.number > 0) {
            uint256 parentHeight = block.number - 1;
            _l2Hashes[parentHeight] = blockhash(parentHeight);
        }
    }

    /**********************
     * External Functions *
     **********************/

    /**
     * Persist the latest L1 block height and hash to L2 for cross-layer
     * message verification (eg. bridging). This function will also check
     * certain block-level global variables because they are not part of the
     * Trie structure.
     *
     * A circuit will verify the integrity among:
     * -  l1Hash, l1SignalRoot, and l1SignalServiceAddress
     * -  (l1Hash and l1SignalServiceAddress) are both hashed into of the
     *    ZKP's instance.
     *
     * This transaction shall be the first transaction in every L2 block.
     *
     * @param l1Height The latest L1 block height when this block was proposed.
     * @param l1Hash The latest L1 block hash when this block was proposed.
     * @param l1SignalRoot The latest value of the L1 "signal service storage root".
     */

    function anchor(
        uint64 l1Height,
        bytes32 l1Hash,
        bytes32 l1SignalRoot
    ) external {
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        uint256 parentHeight = block.number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        (bytes32 prevPIH, bytes32 currPIH) = _calcPublicInputHash(parentHeight);

        if (publicInputHash != prevPIH) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH(publicInputHash, prevPIH);
        }

        // replace the oldest block hash with the parent's blockhash
        publicInputHash = currPIH;
        _l2Hashes[parentHeight] = parentHash;

        latestSyncedL1Height = l1Height;
        _l1VerifiedBlocks[l1Height] = VerifiedBlock(l1Hash, l1SignalRoot);

        emit XchainSynced(l1Height, l1Hash, l1SignalRoot);

        // Check EIP-1559 basefee
        if (gasIssuedPerSecond != 0) {
            (basefee, gasExcess) = _calcBasefee(
                block.timestamp - parentTimestamp,
                uint64(block.gaslimit)
            );
        }

        if (block.basefee != basefee)
            revert L2_BASEFEE_MISMATCH(basefee, uint64(block.basefee));

        parentTimestamp = uint64(block.timestamp);

        // We emit this event so circuits can grab its data to verify block variables.
        // If plonk lookup table already has all these data, we can still use this
        // event for debugging purpose.

        emit BlockVars({
            number: uint64(block.number),
            basefee: basefee,
            gaslimit: uint64(block.gaslimit),
            timestamp: uint64(block.timestamp),
            parentHash: parentHash,
            prevrandao: block.prevrandao,
            coinbase: block.coinbase,
            chainid: uint32(block.chainid)
        });
    }

    /**********************
     * Public Functions   *
     **********************/

    function getBasefee(
        uint32 timeSinceNow,
        uint64 gasLimit
    ) public view returns (uint64 _basefee) {
        (_basefee, ) = _calcBasefee(
            timeSinceNow + block.timestamp - parentTimestamp,
            gasLimit
        );
    }

    function getXchainBlockHash(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1VerifiedBlocks[_number].blockHash;
    }

    function getXchainSignalRoot(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1VerifiedBlocks[_number].signalRoot;
    }

    function getBlockHash(uint256 number) public view returns (bytes32) {
        if (number >= block.number) {
            return 0;
        } else if (number < block.number && number >= block.number - 256) {
            return blockhash(number);
        } else {
            return _l2Hashes[number];
        }
    }

    /**********************
     * Private Functions  *
     **********************/

    function _calcPublicInputHash(
        uint256 blockNumber
    ) private view returns (bytes32 prevPIH, bytes32 currPIH) {
        bytes32[256] memory inputs;
        unchecked {
            // put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && blockNumber >= i + 1; ++i) {
                uint256 j = blockNumber - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            prevPIH := keccak256(inputs, mul(256, 32))
        }

        inputs[blockNumber % 255] = blockhash(blockNumber);
        assembly {
            currPIH := keccak256(inputs, mul(256, 32))
        }
    }

    function _calcBasefee(
        uint256 timeSinceParent,
        uint64 gasLimit
    ) private view returns (uint64 _basefee, uint64 _gasExcess) {
        uint256 gasIssued = gasIssuedPerSecond * timeSinceParent;

        _gasExcess = gasExcess > gasIssued ? uint64(gasExcess - gasIssued) : 0;

        uint256 __basefee = Lib1559Math.calculatePrice({
            xscale: xscale,
            yscale: yscale,
            xExcess: _gasExcess,
            xPurchase: gasLimit
        });

        // Very important to cap basefee uint64
        _basefee = uint64(__basefee.min(type(uint64).max));

        // Very important to cap _gasExcess uint64
        _gasExcess = uint64(
            (uint256(_gasExcess) + gasLimit).min(type(uint64).max)
        );

        console2.log("excess:", _gasExcess);
        console2.log("gasLimit:", gasLimit);
        console2.log("_basefee:", _basefee);
    }
}
