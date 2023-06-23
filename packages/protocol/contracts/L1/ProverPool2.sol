//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

/// TODOs:
/// - [ ] make sure prover cannot make frequent changes
contract ProverPool2 is EssentialContract, IProverPool {
    // 8 bytes
    struct Prover {
        uint32 stakedAmount;
        uint16 rewardPerGas;
        uint16 currentCapacity;
    }

    // Make sure we only use one slot
    struct Staker {
        uint64 exitRequestedAt;
        uint32 exitAmount;
        uint16 maxCapacity;
        uint8 proverId; // to indicate the staker is not a top prover
    }

    uint256 public constant EXIT_PERIOD = 1 weeks;
    uint64 public constant ONE_TKO = 10e8;
    uint32 public constant SLASH_POINTS = 500; // basis points

    mapping(address prover => Staker) public stakers;
    mapping(uint256 id => address) public idToProver;
    Prover[32] public provers; // 32/4 = 8 slots

    uint256[166] private __gap;

    event Exited(uint32 amount);
    event Slashed(address addr, uint32 amount);

    error UNAUTHORIZED();
    error EXIT_NOT_MATURE();

    modifier onlyFromProtocol() {
        if (resolve("taiko", false) != msg.sender) {
            revert UNAUTHORIZED();
        }
        _;
    }

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas)
    {
        (uint256[32] memory weights, uint256 totalWeight) =
            getWeights(feePerGas);

        if (totalWeight == 0) {
            return (address(0), 0);
        }

        // Pick a prover using a pseudo random number
        bytes32 rand =
            keccak256(abi.encode(blockhash(block.number - 1), blockId));
        uint256 r = uint256(rand) % totalWeight;
        uint256 z;
        uint8 idx;
        unchecked {
            while (z < r && idx < 32) {
                z += weights[idx++];
            }
            provers[idx].currentCapacity--;

            // Note that prover ID is 1 bigger than its index
            return (idToProver[idx + 1], provers[idx].rewardPerGas);
        }
    }

    // Increases the capacity of the prover
    function releaseProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);

        if (staker.proverId != 0 && prover.currentCapacity < staker.maxCapacity)
        {
            unchecked {
                provers[staker.proverId - 1].currentCapacity += 1;
            }
        }
    }

    // Slashes a prover
    function slashProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);
        uint32 amountToSlash =
            _calcSlashAmount(prover.stakedAmount, staker.exitAmount);

        if (amountToSlash == 0) return;

        if (amountToSlash <= staker.exitAmount) {
            stakers[addr].exitAmount -= amountToSlash;
        } else {
            stakers[addr].exitAmount = 0;

            uint32 _additional = amountToSlash - staker.exitAmount;
            if (prover.stakedAmount > _additional) {
                provers[staker.proverId - 1].stakedAmount -= _additional;
            } else {
                provers[staker.proverId - 1].stakedAmount = 0;
            }
        }

        emit Slashed(addr, amountToSlash);
    }

    // @Daniel's comment: Adjust the staking. Users can use this function to
    // stake, re-stake, exit,
    // and change parameters.
    // @Dani: Most prob. not for exit and modify, because it would require extra
    // logic and cases. Let handle
    // modification in a separate function
    function stake(
        uint32 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        external
        nonReentrant
    {
        uint256 kickedProverId;
        if (maxCapacity == 0) {
            require(amount == 0 && rewardPerGas == 0, "INVALID_PARAMS");
        } else {
            require(
                maxCapacity >= 256 && amount / maxCapacity > 10_000
                    && rewardPerGas > 0,
                "INVALID"
            );
        }

        assert(kickedProverId > 0);

        // Load data into memory
        (Staker memory staker, Prover memory prover) = getStaker(msg.sender);

        // Handle capacity
        stakers[msg.sender].maxCapacity = maxCapacity;

        // Handle staking amounts
        if (amount > prover.stakedAmount) {
            // Stake more tokens
            uint32 extraNeeded = amount - prover.stakedAmount;
            if (extraNeeded > 0) {
                if (staker.exitAmount <= extraNeeded) {
                    extraNeeded -= staker.exitAmount;
                    stakers[msg.sender].exitAmount = 0;
                } else {
                    stakers[msg.sender].exitAmount -= extraNeeded;
                    extraNeeded = 0;
                }
            }

            if (extraNeeded > 0) {
                TaikoToken(AddressResolver(this).resolve("taiko_token", false))
                    .burn(msg.sender, extraNeeded * ONE_TKO);
            }
        } else if (amount < prover.stakedAmount) {
            stakers[msg.sender].proverId = uint8(kickedProverId);
            stakers[msg.sender].exitRequestedAt = uint64(block.timestamp);
            stakers[msg.sender].exitAmount += prover.stakedAmount - amount;
        }

        if (staker.proverId == kickedProverId) {
            // re-staking
            if (provers[staker.proverId - 1].currentCapacity > maxCapacity) {
                provers[staker.proverId - 1].currentCapacity = maxCapacity;
            }
            provers[staker.proverId - 1].stakedAmount = amount;
        } else {
            Staker storage replacedStaker = stakers[idToProver[kickedProverId]];
            replacedStaker.proverId = 0;
            replacedStaker.exitAmount +=
                provers[kickedProverId - 1].stakedAmount;
            if (replacedStaker.exitAmount != 0) {
                replacedStaker.exitRequestedAt = uint64(block.timestamp);
            }
        }
    }

    // Withdraws staked tokens back from matured an exit
    function exit() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        if (
            staker.exitAmount == 0 || staker.exitRequestedAt == 0
                || block.timestamp <= staker.exitRequestedAt + EXIT_PERIOD
        ) {
            revert EXIT_NOT_MATURE();
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            msg.sender, staker.exitAmount * ONE_TKO
        );

        emit Exited(staker.exitAmount);
        staker.exitRequestedAt = 0;
        staker.exitAmount = 0;
    }

    // Returns a staker's information
    function getStaker(address addr)
        public
        view
        returns (Staker memory staker, Prover memory prover)
    {
        staker = stakers[addr];
        if (staker.proverId != 0) {
            unchecked {
                prover = provers[staker.proverId - 1];
            }
        }
    }

    // Returns the pool's current total capacity
    function getCapacity() public view returns (uint256 capacity) {
        unchecked {
            for (uint256 i; i < provers.length;) {
                capacity += provers[i].currentCapacity;
                ++i;
            }
        }
    }

    /// Returns each prover's weight dynamically based on feePerGas.
    function getWeights(uint32 feePerGas)
        public
        view
        returns (uint256[32] memory weights, uint256 totalWeight)
    {
        Prover[32] memory mProvers = provers;

        for (uint8 i; i < mProvers.length; ++i) {
            weights[i] = _calcWeight(mProvers[i], feePerGas);
            totalWeight += weights[i];
        }
    }

    // Returns the prover's dynamic weight based on the current feePerGas
    function _calcWeight(
        Prover memory prover,
        uint32 feePerGas
    )
        private
        pure
        returns (uint256)
    {
        if (prover.currentCapacity == 0) {
            return 0;
        } else {
            return (uint256(prover.stakedAmount) * feePerGas * feePerGas)
                / prover.rewardPerGas / prover.rewardPerGas;
        }
    }

    // Returns the amount of TKO to slash based on the total
    function _calcSlashAmount(
        uint32 stakedAmount,
        uint32 exitAmount
    )
        private
        pure
        returns (uint32 amountToSlash)
    {
        amountToSlash = stakedAmount + exitAmount;
        if (amountToSlash > 0) {
            amountToSlash = amountToSlash * SLASH_POINTS / 10_000;
            // make sure we can slash even if  totalAmount is as small as 1
            if (amountToSlash == 0) amountToSlash = 1;
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool2 { }
