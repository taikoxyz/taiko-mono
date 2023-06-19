//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

contract PrototypingProverPoolImpl {
    struct Staker {
        uint8 id; // [0-31]
        address prover;
        uint32 stakedAmount; // unit is 10^8, this means a max of
            // 429496729500000000 tokens, 2.3283%  of total supply
        uint32 feePerGas; // expected feePerGas
    }

    // Then we define a mapping from id => Staker
    mapping(uint256 id => Staker) stakers;

    // Then we use a fixed size byte array to represnet the top 32 provers.
    // For each prover, we only need to keep its stakedAmount, and feePerGas,
    // together they takes 32+32=64 bits, or 8 bytes.

    // This is 1/4 slot
    struct Prover {
        uint32 stakedAmount; // this value will change when we slash the prover
        uint32 feePerGas;
    }
    // uint16 capacity; // if we add this, we should use a bytes array
    // instead of Prover array below. The capacity must be greater than a
    // threshold.

    Prover[32] public provers; // 32/4 = 8 slots

    // A demo how to optimize the getProver by using only 8 slots. It's still
    // a lot of slots tough.
    function getProver(
        uint32 currentFeePerGas,
        uint256 rand
    )
        public
        view
        returns (address prover, uint32 feePerGas)
    {
        // readjust each prover's rate
        uint256[32] memory weights;
        uint256 totalWeight;
        uint256 i;
        for (; i < 32; ++i) {
            weights[i] = _calcWeight(provers[i], currentFeePerGas);
            if (weights[i] == 0) break;
            totalWeight += weights[i];
        }

        if (totalWeight == 0) {
            return (address(0), 4 * currentFeePerGas);
        }

        uint256 r = rand % totalWeight;
        uint256 z;
        i = 0;
        while (z < r && i < 32) {
            z += weights[i];
        }
        return (stakers[i].prover, stakers[i].feePerGas);
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
            * currentFeePerGas / prover.feePerGas / prover.feePerGas;
    }
}

// One idea to try is to keep `Prover[32] public provers;` as a serialized
// byte array as the code of a contract, then we load the code then interpret
// it as data, but I'm not sure if it is cheaper than the previous solution.
contract CodeLoader {
    function loadContractCode(address contractAddress)
        public
        view
        returns (bytes memory)
    {
        bytes memory contractCode;

        assembly {
            // Retrieve the size of the code at the contract address
            let size := extcodesize(contractAddress)

            // Allocate memory for the code
            contractCode := mload(0x40)

            // Set the length of the code
            mstore(contractCode, size)

            // Retrieve the code at the contract address and store it in memory
            extcodecopy(contractAddress, add(contractCode, 0x20), 0, size)

            // Update the free memory pointer
            mstore(0x40, add(contractCode, add(size, 0x20)))
        }

        return contractCode;
    }
}
