//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { TaikoErrors } from "./TaikoErrors.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

contract ProverPool2 is EssentialContract, IProverPool, TaikoErrors {
    struct Prover {
        uint32 amount;
        uint16 rewardPerGas;
        uint16 currentCapacity;
    }

    struct Staker {
        uint64 requestedAt;
        uint32 amount;
        uint16 totalCapacity;
    }

    Prover[32] public topProvers; // 32/4 = 8 slots
    // EXITING PROVER MAPPING
    mapping(address prover => Staker) stakers;

    // Id mappings
    mapping(uint8 id => address) idToProver;
    mapping(address prover => uint8 id) proverToId;

    // Exit period. Might fine tune later on !
    uint256 public constant EXIT_PERIOD = 1 weeks;

    // 500 means 5% if 10_000 is 100 %
    uint256 public constant SLASH_AMOUNT_IN_BP = 500; // basis points

    uint256 public ONE_TKO = 10e8;

    uint256[100] private __gap;

    event Entered(
        address prover, uint32 amount, uint16 rewardPerGas, uint16 capacity
    );

    event ChangedParameters(
        address prover, uint32 newBalance, uint16 newReward, uint16 newCapacity
    );

    event KickeOutByWithAmount(
        address kickedOut, address newProver, uint32 totalAmount
    );

    event ExitRequested(address prover, uint64 timestamp, bool fullExit);

    event Exited(address prover, uint64 timestamp);

    event Slashed(address prover, uint32 newBalance);

    modifier onlyFromProtocol() {
        if (AddressResolver(this).resolve("taiko", false) != msg.sender) {
            revert POOL_CALLER_NOT_AUTHORIZED();
        }

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

    // A demo how to optimize the assignProver by using only 8 slots. It's still
    // a lot of slots though.

    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas)
    {
        // calculate each prover's dynamic weight

        uint256[32] memory weights;
        uint256 totalWeight;

        // Iterate over in-memory array
        // Load in-memory first, so to avoid 32 SLOAD operation reading from
        // state.
        Prover[32] memory mProvers = topProvers;

        for (uint8 i; i < mProvers.length; ++i) {
            weights[i] = _calcWeight(i, mProvers[i], feePerGas);
            totalWeight += weights[i];
        }

        if (totalWeight == 0) {
            return (address(0), 0);
        }

        // Determine prover idx
        bytes32 rand =
            keccak256(abi.encode(blockhash(block.number - 1), blockId));

        // pick prover
        uint8 id;
        uint256 r = uint256(rand) % totalWeight;
        uint256 z;
        while (z < r && id < 32) {
            z += weights[++id];
        }

        topProvers[id].currentCapacity--;
        return (idToProver[id], topProvers[id].rewardPerGas);
    }

    // Increases the capacity of the prover
    // @Dani: No need to track usedCapacity on prover (exiting), they should
    // take care of
    // monitoring their own resources when they want to re-enter (!). This code
    // is already
    // more complex than a PoC should :) - no need to over-engineer.
    function releaseProver(address prover) external onlyFromProtocol {
        /// NOTE: rewardPerGas is the indicator if object is valid/existing
        if (topProvers[proverToId[prover]].rewardPerGas != 0) {
            topProvers[proverToId[prover]].currentCapacity++;
        }
    }

    function slashProver(address prover) external onlyFromProtocol {
        uint8 id = proverToId[prover];
        if (
            topProvers[id].rewardPerGas == 0 && stakers[prover].requestedAt == 0
        ) {
            revert POOL_PROVER_NOT_FOUND();
        }

        // We need to determine if the prover is an exiting prover or normal
        // (top)
        // It might happen that prover is in the exit, while also in the top, in
        // such case
        // try to punish the exiting amount

        uint32 amountToExit = stakers[prover].amount;
        uint32 amountToSlash = uint32(
            (topProvers[id].amount + amountToExit)
                * uint256(10_000 - SLASH_AMOUNT_IN_BP) / 10_000
        );

        if (amountToExit >= amountToSlash) {
            stakers[prover].amount = amountToExit - amountToSlash;
        } else {
            if (amountToExit > 0) {
                delete  stakers[prover];
                amountToSlash -= amountToExit;
            }
            topProvers[id].amount -= amountToSlash;
        }

        emit Slashed(prover, amountToSlash);
    }

    // @Daniel's comment: Adjust the staking. Users can use this funciton to
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
        address newProver = msg.sender;
        uint8 currentProverId = proverToId[msg.sender];
        if (
            topProvers[currentProverId].amount != 0
                && topProvers[currentProverId].amount <= totalAmount
        ) {
            // topProvers[id].amount == totalAmountsignals -> 'exit'
            // topProvers[id].amount < totalAmount 'partial exit'
            uint64 timestamp = uint64(block.timestamp);

            if (topProvers[currentProverId].amount == totalAmount) {
                // Full exit
                stakers[msg.sender] = Staker(
                    timestamp,
                    stakers[msg.sender].amount
                        + topProvers[currentProverId].amount,
                    capacity
                );

                // Empty in topProvers and delete from proverToId mapping
                topProvers[currentProverId] = Prover(0, 0, 0);
                delete proverToId[msg.sender];
                delete idToProver[currentProverId];

                emit ExitRequested(newProver, timestamp, true);
            } else {
                // Partial exit
                stakers[msg.sender] = Staker(
                    timestamp,
                    (
                        stakers[msg.sender].amount
                            + topProvers[currentProverId].amount
                    ),
                    capacity
                );

                topProvers[currentProverId].amount -= totalAmount;

                emit ExitRequested(newProver, timestamp, false);
            }
        } else {
            if (capacity < 100) {
                revert POOL_NOT_ENOUGH_RESOURCES();
            }

            if (rewardPerGas == 0) {
                revert POOL_REWARD_CANNOT_BE_NULL();
            }

            // This else clause can be a:
            // 1. completely new stake request (and a re-stake once prover was
            // forced kicked out and now in the Stakers)
            // 2. A modification

            // Case 2:
            if (topProvers[proverToId[newProver]].rewardPerGas != 0) {
                // This is 2. (modification) because we have this prover in the
                // list
                // totalAmount if 0 it means they dont raise the staked TKO
                // (it's fine)
                TaikoToken(AddressResolver(this).resolve("taiko_token", false))
                    .burn(
                    newProver,
                    uint64(totalAmount) * ONE_TKO // TODO: public constant
                );
                topProvers[proverToId[newProver]].amount += totalAmount;
                // New reward per gas
                topProvers[proverToId[newProver]].rewardPerGas = rewardPerGas;
                // New capacity
                topProvers[proverToId[newProver]].currentCapacity = capacity;

                emit ChangedParameters(
                    newProver, totalAmount, rewardPerGas, capacity
                );
            } else {
                // Case 1:
                // It signals a new stake request (or a re-stake if i the exit
                // queue)

                (uint8 id, uint32 minimumStake) = _determineLowestStaker();
                //This will be calculated based on the exiting amount
                uint32 burnAmount = totalAmount;
                // Cannot enter the pool below the minimum
                if (minimumStake >= totalAmount) {
                    revert POOL_NOT_MEETING_MIN_REQUIREMENTS();
                }
                // TODO: the logics should look like this:
                // 1. Find the smallest staker in the top staker list, using its
                // current

                // amount
                //    value, not the original amount value, say this is Alice.
                // 2. Compare if the new staker, Bob's amount is bigger than
                // Alice's. We may even compare
                //    capacity (not sure how the math work), note that if Bob is
                // already
                // on the exiting list, we shall reuse its tokens locked there.
                // Yes, we comply with this 1st and 2nd checks with:
                // require(minimumStake < totalAmount, "Cannot enter below
                // minimum");
                // 3. If Bob is perferred, we change Alice's status to `exiting`
                // (as if
                // Alice herself requested to exit)
                // 4. We replace Alice with Bob in the `provers` list.
                uint64 timestamp = uint64(block.timestamp);
                Prover memory replacedProver = topProvers[id];
                // NOTE: Since we not allow the rewardPerGas to be 0, we can
                // always use
                // it as a check to see if the data is non-null.
                if (replacedProver.rewardPerGas != 0) {
                    // The list is full so we need to kick someone out
                    // We need to see both the replacedProver and the newProver
                    // are in the exit queue or not ?
                    Staker memory kickedOutProver = stakers[idToProver[id]];
                    Staker memory newProverMightBeInExitQueue =
                        stakers[newProver];

                    if (kickedOutProver.requestedAt != 0) {
                        // The kicked out is also in the exit queue with some
                        // funds as well
                        kickedOutProver.requestedAt = timestamp;
                        kickedOutProver.amount += replacedProver.amount;
                    } else {
                        kickedOutProver.requestedAt = timestamp;
                        kickedOutProver.amount = replacedProver.amount;
                    }

                    if (newProverMightBeInExitQueue.requestedAt != 0) {
                        // The new one is in the exit queue so we might reuse
                        // it's allowance
                        // let's see how much is that.

                        if (newProverMightBeInExitQueue.amount <= totalAmount) {
                            // It is basically 'reverting' an exit then
                            newProverMightBeInExitQueue.amount = 0;
                            newProverMightBeInExitQueue.requestedAt = 0;
                            //We already burnt when entered into the pool
                            burnAmount =
                                totalAmount - newProverMightBeInExitQueue.amount;
                        } else {
                            newProverMightBeInExitQueue.amount -= totalAmount;
                            newProverMightBeInExitQueue.requestedAt = timestamp;

                            burnAmount -= newProverMightBeInExitQueue.amount;
                        }
                    }

                    // Write back to storage
                    stakers[idToProver[id]] = kickedOutProver;
                    stakers[newProver] = newProverMightBeInExitQueue;

                    // Rewrite it's place with the new one
                    topProvers[id] = Prover(totalAmount, rewardPerGas, capacity);

                    emit KickeOutByWithAmount(
                        idToProver[id], newProver, totalAmount
                    );

                    proverToId[newProver] = id;
                    idToProver[id] = newProver;
                } else {
                    topProvers[id] = Prover(totalAmount, rewardPerGas, capacity);
                    proverToId[newProver] = id;
                    idToProver[id] = newProver;
                }

                TaikoToken(AddressResolver(this).resolve("taiko_token", false))
                    .burn(
                    newProver,
                    uint64(burnAmount) * ONE_TKO // TODO: public constant
                );

                emit Entered(newProver, totalAmount, rewardPerGas, capacity);
            }
        }
    }

    function getAvailableCapacity()
        external
        view
        returns (uint256 totalCapacity)
    {
        Prover[32] memory mProvers = topProvers;

        // Find the index to insert the new staker based on their balance
        for (uint8 i = 0; i < mProvers.length; i++) {
            totalCapacity += mProvers[i].currentCapacity;
        }
    }

    function exit() external {
        // We need to have this prover 'flagged' as an exiting prover
        if (
            stakers[msg.sender].requestedAt == 0
                || stakers[msg.sender].requestedAt + EXIT_PERIOD >= block.timestamp
        ) {
            revert POOL_CANNOT_YET_EXIT();
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            msg.sender, stakers[msg.sender].amount * ONE_TKO
        );

        // Delete mapping
        delete stakers[msg.sender];

        emit Exited(msg.sender, uint64(block.timestamp));
    }

    // Determine the minimum required TKO to be in the pool
    function lowestStakedAmountToEnter()
        external
        view
        returns (uint32 minStakeRequired)
    {
        (, minStakeRequired) = _determineLowestStaker();

        return (minStakeRequired + 1);
    }

    // The weight is dynamic based on fee per gas.
    function _calcWeight(
        uint8 id,
        Prover memory prover,
        uint32 feePerGas
    )
        private
        view
        returns (uint256)
    {
        // If prover's capacity is 0
        // set his/her weight to 0
        if (topProvers[id].currentCapacity == 0) {
            return 0;
        }
        // Just a demo that the weight depends on the current fee per gas,
        // the prover's expected fee per gas, as well as the staking amount
        return (uint256(prover.amount) * feePerGas * feePerGas)
            / prover.rewardPerGas / prover.rewardPerGas;
    }

    // Determine staker with the least amount of token staked
    function _determineLowestStaker()
        private
        view
        returns (uint8 stakerId, uint32 minStake)
    {
        Prover[32] memory mProvers = topProvers;
        stakerId = 0;
        minStake = mProvers[0].amount;

        // Find the index to insert the new staker based on their balance
        for (uint8 i = 1; i < mProvers.length; i++) {
            if (mProvers[i].amount < minStake) {
                stakerId = i;
                minStake = mProvers[i].amount;

                if (minStake == 0) {
                    // This is an 'empty spot'
                    return (stakerId, minStake);
                }
            }
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool2 { }
