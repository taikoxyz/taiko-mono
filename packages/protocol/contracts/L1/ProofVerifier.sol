// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {LibZKP} from "../libs/LibZKP.sol";
import {LibMerkleTrie} from "../thirdparty/LibMerkleTrie.sol";

/// @author dantaik <dan@taiko.xyz>
interface IProofVerifier {
    function verifyZKP(
        string memory verifierId,
        bytes calldata zkproof,
        bytes32 instance
    ) external view returns (bool verified);

    function verifyMKP(
        bytes memory key,
        bytes memory value,
        bytes memory proof,
        bytes32 root
    ) external pure returns (bool verified);
}

contract ProofVerifier is IProofVerifier, EssentialContract {
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    function verifyZKP(
        string memory verifierId,
        bytes calldata zkproof,
        bytes32 instance
    ) external view returns (bool) {
        return
            LibZKP.verify({
                plonkVerifier: resolve(verifierId, false),
                zkproof: zkproof,
                instance: instance
            });
    }

    function verifyMKP(
        bytes memory key,
        bytes memory value,
        bytes memory proof,
        bytes32 root
    ) external pure returns (bool) {
        return
            LibMerkleTrie.verifyInclusionProof({
                _key: key,
                _value: value,
                _proof: proof,
                _root: root
            });
    }
}
