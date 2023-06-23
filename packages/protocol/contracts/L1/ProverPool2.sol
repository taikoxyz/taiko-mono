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

contract ProverPool2 is EssentialContract, IProverPool {
    uint256 public constant EXIT_PERIOD = 1 weeks;
    uint32 public constant SLASH_POINTS = 500; // basis points
    uint64 public ONE_TKO = 10e8;

    struct Prover {
        uint32 amount;
        uint16 rewardPerGas;
        uint16 availableCapacity;
    }

    struct Staker {
        uint64 exitRequestedAt;
        uint32 exitingAmount;
        uint16 totalCapacity;
        uint8 id;
    }

    mapping(address prover => Staker) stakers;
    mapping(uint256 id => address) idToProver;
    mapping(address prover => uint256 id) proverToId;
    Prover[32] public provers; // 32/4 = 8 slots
    uint256[165] private __gap;

    error UNAUTHORIZED();
    error POOL_CANNOT_YET_EXIT();
    error POOL_NOT_ENOUGH_RESOURCES();
    error POOL_REWARD_CANNOT_BE_NULL();
    error POOL_NOT_MEETING_MIN_REQUIREMENTS();

    event Staked(
        address addr, uint32 amount, uint16 rewardPerGas, uint16 capacity
    );

    event KickeOutByWithAmount(
        address kickedOut, address newProver, uint32 totalAmount
    );

    event ExitRequested(address addr, uint64 timestamp, bool fullExit);

    event Exited(address addr, uint32 amount);

    event Slashed(address addr, uint32 newBalance);

    modifier onlyFromProtocol() {
        if (AddressResolver(this).resolve("taiko", false) != msg.sender) {
            revert UNAUTHORIZED();
        }

        _;
    }

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// Returns each prover's weight dynamically based on feePerGas.
    function getWeights(uint32 feePerGas)
        internal
        view
        returns (uint256[32] memory weights, uint256 totalWeight)
    {
        Prover[32] memory mProvers = provers;

        for (uint8 i; i < mProvers.length; ++i) {
            weights[i] = _calcWeight(mProvers[i], feePerGas);
            totalWeight += weights[i];
        }
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
            provers[idx].availableCapacity--;

            // Note that prover ID is 1 bigger than its index
            return (idToProver[idx + 1], provers[idx].rewardPerGas);
        }
    }

    // Increases the capacity of the prover
    function releaseProver(address prover) external onlyFromProtocol {
        uint256 id = stakers[prover].id;
        // the capacity being used by the protocol is totalWeight -
        // availableCapacity,  therefore, when we release a capacity, we either
        // add 1 to availableCapacity or subtract 1 from totalWeight.
        unchecked {
            if (id == 0) {
                // This prover is no longer in the top list, availableCapacity
                // is
                // supposed to be 0.
                --stakers[prover].totalCapacity;
            } else {
                ++provers[id - 1].availableCapacity;
            }
        }
    }

    function getStaker(address addr)
        public
        view
        returns (Staker memory staker, Prover memory prover)
    {
        staker = stakers[addr];
        if (staker.id != 0) {
            unchecked {
                prover = provers[staker.id - 1];
            }
        }
    }

    function getSlashAmount(uint32 totalAmount)
        public
        pure
        returns (uint32 amountToSlash)
    {
        if (totalAmount > 0) {
            amountToSlash = totalAmount * SLASH_POINTS / 10_000;
            // make sure we can slash even if  totalAmount is as small as 1
            if (amountToSlash == 0) amountToSlash = 1;
        }
    }

    function slashProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);
        uint32 amountToSlash =
            getSlashAmount(staker.exitingAmount + prover.amount);

        if (amountToSlash == 0) return;

        if (amountToSlash <= staker.exitingAmount) {
            stakers[addr].exitingAmount -= amountToSlash;
        } else {
            stakers[addr].exitingAmount = 0;

            uint32 _additional = amountToSlash - staker.exitingAmount;
            if (prover.amount > _additional) {
                provers[staker.id - 1].amount -= _additional;
            } else {
                provers[staker.id - 1].amount = 0;
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
        uint32 totalAmount,
        uint16 rewardPerGas,
        uint16 capacity
    )
        external
        nonReentrant
    {
        if (capacity > 0) {
            // check parameters here
        }

        // Load data into memory
        (Staker memory staker, Prover memory prover) = getStaker(msg.sender);

        // Handle balances
        if (totalAmount > prover.amount) {
            // Stake more tokens
            uint32 extraNeeded = totalAmount - prover.amount;
            if (extraNeeded > 0) {
                if (staker.exitingAmount <= extraNeeded) {
                    extraNeeded -= staker.exitingAmount;
                    stakers[msg.sender].exitingAmount = 0;
                } else {
                    stakers[msg.sender].exitingAmount -= extraNeeded;
                    extraNeeded = 0;
                }
            }

            if (extraNeeded > 0) {
                TaikoToken(AddressResolver(this).resolve("taiko_token", false))
                    .burn(msg.sender, extraNeeded * ONE_TKO);
            }
        } else if (totalAmount < prover.amount) {
            stakers[msg.sender].exitRequestedAt = uint64(block.timestamp);
            stakers[msg.sender].exitingAmount += prover.amount - totalAmount;
        }
    }

    /// Returns the current total available capacity
    function getAvailableCapacity() external view returns (uint256 capacity) {
        unchecked {
            for (uint256 i; i < provers.length;) {
                capacity += provers[i].availableCapacity;
                ++i;
            }
        }
    }

    function exit(address staker) external nonReentrant {
        // We need to have this prover 'flagged' as an exiting prover
        Staker storage _staker = stakers[staker];
        if (
            _staker.exitRequestedAt == 0
                || block.timestamp <= _staker.exitRequestedAt + EXIT_PERIOD
        ) {
            revert POOL_CANNOT_YET_EXIT();
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            staker, _staker.exitingAmount * ONE_TKO
        );

        emit Exited(staker, _staker.exitingAmount);

        _staker.exitRequestedAt = 0;
        _staker.exitingAmount = 0;
        // TODO(Daniel): deal with capacity?
    }

    // The weight is dynamic based on the current fee per gas.
    function _calcWeight(
        Prover memory prover,
        uint32 feePerGas
    )
        private
        pure
        returns (uint256)
    {
        if (prover.availableCapacity == 0) {
            return 0;
        } else {
            return (uint256(prover.amount) * feePerGas * feePerGas)
                / prover.rewardPerGas / prover.rewardPerGas;
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool2 { }
