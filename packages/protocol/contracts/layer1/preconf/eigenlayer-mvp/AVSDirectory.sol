// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IAVSDirectory} from "../interfaces/eigenlayer-mvp/IAVSDirectory.sol";

contract AVSDirectory is IAVSDirectory {
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 private constant OPERATOR_AVS_REGISTRATION_TYPEHASH =
        keccak256("OperatorAVSRegistration(address operator,address avs,bytes32 salt,uint256 expiry)");

    function registerOperatorToAVS(address operator, IAVSDirectory.SignatureWithSaltAndExpiry memory operatorSignature)
        external
    {}

    function deregisterOperatorFromAVS(address operator) external {}

    function calculateOperatorAVSRegistrationDigestHash(address operator, address avs, bytes32 salt, uint256 expiry)
        public
        view
        returns (bytes32)
    {
        // calculate the struct hash
        bytes32 structHash = keccak256(abi.encode(OPERATOR_AVS_REGISTRATION_TYPEHASH, operator, avs, salt, expiry));
        // calculate the digest hash
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", _calculateDomainSeparator(), structHash));
        return digestHash;
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("EigenLayer")), block.chainid, address(this)));
    }
}
