//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

contract ProverPoolImpl is EssentialContract {
    struct Staker {
        uint8 id; // [0-31]
        address prover;
        uint32 stakedAmount; // unit is 10^8, this means a max of
            // 429496729500000000 tokens, 2.3283%  of total supply
        uint16 rewardPerGas; // expected rewardPerGas
        uint16 capacity; // maximum capacity (parallel blocks)
    }

    // Then we define a mapping from id => Staker
    mapping(uint256 id => Staker) stakers;
    // We need an address to id mapping
    mapping(address prover => uint256 id) proverToId;

    // Keeping track of the 'lowest barrier to entry' by checking who is on the
    // bottom of the top32 list.
    // Top32: Pure staked TKO based !
    uint256 minimumStake;
    uint8 minimumStakerId;
    uint8 currentIdIdx;

    // Then we use a fixed size byte array to represnet the top 32 provers.
    // For each prover, we only need to keep its stakedAmount, and rewardPerGas,
    // together they takes 32+32=64 bits, or 8 bytes.

    // This is 1/4 slot
    struct Prover {
        uint32 stakedAmount; // this value will change when we slash the prover
        uint16 rewardPerGas;
    }
    // uint16 capacity; // if we add this, we should use a bytes array
    // instead of Prover array below. The capacity must be greater than a
    // threshold.

    Prover[32] public provers; // 32/4 = 8 slots

    uint256[100] private __gap;

    event ProverEntered(
        address prover,
        uint32 stakedAmount,
        uint256 rewardPerGas,
        uint16 capacity
    );
    event ProverModified(
        address prover,
        uint32 newStakedAmount,
        uint256 newRewardPerGas,
        uint16 newCapacity
    );

    modifier onlyProtocol() {
        require(
            AddressResolver(this).resolve("taiko", false) != msg.sender,
            "Only Taiko L1 can call this function"
        );
        _;
    }

    modifier onlyProver(address prover) {
        require(
            stakers[proverToId[prover]].prover != address(0),
            "Only provers can call this function"
        );
        _;
    }

    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     */
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    // @Daniel's comment: Adjust the staking. Users can use this funciton to
    // stake, re-stake, exit,
    // and change parameters.
    // @Dani: Most prob. not for exit and modify, because it would require extra
    // logic and cases. Let handle
    // modification in a separate function
    function stake(
        uint32 totalAmount,
        address prover, // This can be a 'delegate' so not using msg.sender
        uint16 rewardPerGas,
        uint16 capacity
    )
        external
        nonReentrant
    {
        // Cannot enter the pool below the minimum
        require(minimumStake < totalAmount, "Cannot enter below minimum");
        require(rewardPerGas > 0, "Cannot be less than 1");

        // The list of 32 is not full yet so kind of everybody can enter into
        // the pool
        if (provers[31].stakedAmount == 0) {
            stakers[currentIdIdx] = Staker(
                currentIdIdx, prover, totalAmount, rewardPerGas, capacity
            );
            provers[currentIdIdx] = Prover(totalAmount, rewardPerGas);
            proverToId[prover] = currentIdIdx;

            // This would not overflow the 32 because of:
            // provers[31].stakedAmount == 0
            unchecked {
                ++currentIdIdx;
            }

            // If we just filled up the last place in the array (so means full -
            // we can
            // determine which is the staker in risk)
            if (provers[31].stakedAmount != 0) {
                (minimumStakerId, minimumStake) = _determineLowestStaker();
            }
        } else {
            // List is full, we need to check which position we need to put them
            // into
            (minimumStakerId,) = _determineLowestStaker();

            // We need to overwrite it's place
            stakers[minimumStakerId] = Staker(
                minimumStakerId, prover, totalAmount, rewardPerGas, capacity
            );
            provers[minimumStakerId] = Prover(totalAmount, rewardPerGas);
            proverToId[prover] = minimumStakerId;

            // Need to determine again who is the last / lowest staker
            (minimumStakerId, minimumStake) = _determineLowestStaker();
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).burn(
            prover, totalAmount
        );

        emit ProverEntered(prover, totalAmount, rewardPerGas, capacity);
    }

    function stakePositionAdjustments(
        uint32 newTotalAmount,
        address prover, // This can be a 'delegate' so not using msg.sender
        uint16 rewardPerGas,
        uint16 capacity
    )
        external
        onlyProver(prover)
    {
        // Cannot enter the pool below the minimum - we are not allowing the
        // minium staker to lower it's position
        require(minimumStake < newTotalAmount, "Cannot enter below minimum");
        require(rewardPerGas > 0, "Cannot be less than 1");

        Staker memory mStaker = stakers[proverToId[prover]];

        if (mStaker.stakedAmount > newTotalAmount) {
            // Lowered position, so basically we just need to burn some tokens
            // for him/her
            TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
                prover, mStaker.stakedAmount - newTotalAmount
            );
        } else if (mStaker.stakedAmount < newTotalAmount) {
            // Otherwise it raised it's stake, so burn more tokens from it's
            // balance
            TaikoToken(AddressResolver(this).resolve("taiko_token", false)).burn(
                prover, newTotalAmount - mStaker.stakedAmount
            );
        }

        stakers[proverToId[prover]] = Staker(
            minimumStakerId, prover, newTotalAmount, rewardPerGas, capacity
        );
        provers[proverToId[prover]] = Prover(newTotalAmount, rewardPerGas);

        // Need to determine again who is the last / lowest staker
        (minimumStakerId, minimumStake) = _determineLowestStaker();

        emit ProverModified(prover, newTotalAmount, rewardPerGas, capacity);
    }

    // A demo how to optimize the getProver by using only 8 slots. It's still
    // a lot of slots tough.
    function getProver(
        uint32 currentFeePerGas,
        uint256 rand
    )
        external
        returns (address prover, uint32 rewardPerGas)
    {
        // readjust each prover's rate
        uint256[32] memory weights;
        uint256 totalWeight;
        uint256 i;
        for (; i < provers.length; ++i) {
            weights[i] = _calcWeight(provers[i], currentFeePerGas);
            if (weights[i] == 0) break;
            totalWeight += weights[i];
        }

        if (totalWeight == 0) {
            return (address(0), 2 * currentFeePerGas);
        }

        // Determine prover idx
        uint256 proverIdx = _pickProverIdx(weights, totalWeight, rand);

        Staker memory proverData = stakers[proverIdx];

        // If prover's capacity is at it's full, pick another one
        if (stakers[proverIdx].capacity == 0) {
            proverIdx = _pickProverIdx(
                weights,
                totalWeight,
                uint256(
                    keccak256(
                        abi.encodePacked(
                            currentFeePerGas, block.timestamp, rand
                        )
                    )
                )
            );
            proverData = stakers[proverIdx];
        }

        // If second prover's capacity is at full as well, return address(0)
        if (proverData.capacity == 0) {
            return (address(0), 2 * currentFeePerGas);
        }

        // If the reward is 2x then the current average, then cap it
        if (proverData.rewardPerGas * 2 > currentFeePerGas) {
            //Decrease capacity
            stakers[proverIdx].capacity--;
            return (proverData.prover, 2 * currentFeePerGas);
        }

        stakers[proverIdx].capacity--;
        return (proverData.prover, proverData.rewardPerGas);
    }

    // Increases the capacity of the prover
    function releaseResource(address prover) external onlyProtocol {
        if (
            stakers[proverToId[prover]].prover != address(0)
                && stakers[proverToId[prover]].capacity < type(uint16).max
        ) {
            stakers[proverToId[prover]].capacity++;
        }
    }

    // The weight is dynamic based on fee per gas.
    function _calcWeight(
        Prover memory prover,
        uint32 currentFeePerGas
    )
        private
        pure
        returns (uint256)
    {
        // Just a demo that the weight depends on the current fee per gas,
        // the prover's expected fee per gas, as well as the staking amount
        return uint256(prover.stakedAmount) * currentFeePerGas
            * currentFeePerGas / prover.rewardPerGas / prover.rewardPerGas;
    }

    // Determine staker with the least amount of token staked
    function _determineLowestStaker()
        private
        view
        returns (uint8 stakerId, uint256 minStake)
    {
        Prover[32] memory mProvers = provers;
        stakerId = 0;
        minStake = mProvers[0].stakedAmount;

        // Find the index to insert the new staker based on their balance
        for (uint8 i = 1; i < mProvers.length; i++) {
            if (mProvers[i].stakedAmount < minStake) {
                stakerId = i;
                minStake = mProvers[i].stakedAmount;
            }
        }
    }

    // Pick a random prover
    function _pickProverIdx(
        uint256[32] memory weights,
        uint256 totalWeight,
        uint256 rand
    )
        private
        pure
        returns (uint8 i)
    {
        uint256 r = rand % totalWeight;
        uint256 z;
        while (z < r && i < 32) {
            z += weights[i++];
        }
    }
}

contract ProxiedStakingProverPool is Proxied, ProverPoolImpl { }
