// SPDX-License-Identifier: MIT
// Original source: https://github.com/JonahGroendal/asn1-decode
pragma solidity 0.8.24;

// Inspired by PufferFinance/rave - Apache-2.0 license
// https://github.com/JonahGroendal/asn1-decode/blob/5c2d1469fc678513753786acb441e597969192ec/contracts/Asn1Decode.sol

import "./BytesUtils.sol";

/// @title NodePtr
/// @custom:security-contact security@taiko.xyz
library NodePtr {
    // Unpack first byte index
    function ixs(uint256 self) internal pure returns (uint256) {
        return uint80(self);
    }
    // Unpack first content byte index

    function ixf(uint256 self) internal pure returns (uint256) {
        return uint80(self >> 80);
    }
    // Unpack last content byte index

    function ixl(uint256 self) internal pure returns (uint256) {
        return uint80(self >> 160);
    }
    // Pack 3 uint80s into a uint256

    function getPtr(uint256 _ixs, uint256 _ixf, uint256 _ixl) internal pure returns (uint256) {
        _ixs |= _ixf << 80;
        _ixs |= _ixl << 160;
        return _ixs;
    }
}

/// @title Asn1Decode
/// @custom:security-contact security@taiko.xyz
library Asn1Decode {
    using NodePtr for uint256;
    using BytesUtils for bytes;

    /*
    * @dev Get the root node. First step in traversing an ASN1 structure
    * @param der The DER-encoded ASN1 structure
    * @return A pointer to the outermost node
    */
    function root(bytes memory der) internal pure returns (uint256) {
        return _readNodeLength(der, 0);
    }

    /*
    * @dev Get the root node of an ASN1 structure that's within a bit string value
    * @param der The DER-encoded ASN1 structure
    * @return A pointer to the outermost node
    */
    function rootOfBitStringAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {
        require(der[ptr.ixs()] == 0x03, "Not type BIT STRING");
        return _readNodeLength(der, ptr.ixf() + 1);
    }

    /*
    * @dev Get the root node of an ASN1 structure that's within an octet string value
    * @param der The DER-encoded ASN1 structure
    * @return A pointer to the outermost node
    */
    function rootOfOctetStringAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {
        require(der[ptr.ixs()] == 0x04, "Not type OCTET STRING");
        return _readNodeLength(der, ptr.ixf());
    }

    /*
    * @dev Get the next sibling node
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return A pointer to the next sibling node
    */
    function nextSiblingOf(bytes memory der, uint256 ptr) internal pure returns (uint256) {
        return _readNodeLength(der, ptr.ixl() + 1);
    }

    /*
    * @dev Get the first child node of the current node
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return A pointer to the first child node
    */
    function firstChildOf(bytes memory der, uint256 ptr) internal pure returns (uint256) {
        require(der[ptr.ixs()] & 0x20 == 0x20, "Not a constructed type");
        return _readNodeLength(der, ptr.ixf());
    }

    /*
    * @dev Use for looping through children of a node (either i or j).
    * @param i Pointer to an ASN1 node
    * @param j Pointer to another ASN1 node of the same ASN1 structure
    * @return true iff j is child of i or i is child of j.
    */
    function isChildOf(uint256 i, uint256 j) internal pure returns (bool) {
        return (
            ((i.ixf() <= j.ixs()) && (j.ixl() <= i.ixl()))
                || ((j.ixf() <= i.ixs()) && (i.ixl() <= j.ixl()))
        );
    }

    /*
    * @dev Extract value of node from DER-encoded structure
    * @param der The der-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return Value bytes of node
    */
    function bytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {
        return der.substring(ptr.ixf(), ptr.ixl() + 1 - ptr.ixf());
    }

    /*
    * @dev Extract entire node from DER-encoded structure
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return All bytes of node
    */
    function allBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {
        return der.substring(ptr.ixs(), ptr.ixl() + 1 - ptr.ixs());
    }

    /*
    * @dev Extract value of node from DER-encoded structure
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return Value bytes of node as bytes32
    */
    function bytes32At(bytes memory der, uint256 ptr) internal pure returns (bytes32) {
        return der.readBytesN(ptr.ixf(), ptr.ixl() + 1 - ptr.ixf());
    }

    /*
    * @dev Extract value of node from DER-encoded structure
    * @param der The der-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return Uint value of node
    */
    function uintAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {
        require(der[ptr.ixs()] == 0x02, "Not type INTEGER");
        require(der[ptr.ixf()] & 0x80 == 0, "Not positive");
        uint256 len = ptr.ixl() + 1 - ptr.ixf();
        return uint256(der.readBytesN(ptr.ixf(), len) >> (32 - len) * 8);
    }

    /*
    * @dev Extract value of a positive integer node from DER-encoded structure
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return Value bytes of a positive integer node
    */
    function uintBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {
        require(der[ptr.ixs()] == 0x02, "Not type INTEGER");
        require(der[ptr.ixf()] & 0x80 == 0, "Not positive");
        uint256 valueLength = ptr.ixl() + 1 - ptr.ixf();
        if (der[ptr.ixf()] == 0) {
            return der.substring(ptr.ixf() + 1, valueLength - 1);
        } else {
            return der.substring(ptr.ixf(), valueLength);
        }
    }

    function keccakOfBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes32) {
        return der.keccak(ptr.ixf(), ptr.ixl() + 1 - ptr.ixf());
    }

    function keccakOfAllBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes32) {
        return der.keccak(ptr.ixs(), ptr.ixl() + 1 - ptr.ixs());
    }

    /*
    * @dev Extract value of bitstring node from DER-encoded structure
    * @param der The DER-encoded ASN1 structure
    * @param ptr Points to the indices of the current node
    * @return Value of bitstring converted to bytes
    */
    function bitstringAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {
        require(der[ptr.ixs()] == 0x03, "ixs Not type BIT STRING 0x03");
        // Only 00 padded bitstr can be converted to bytestr!
        require(der[ptr.ixf()] == 0x00, "ixf Not 0");
        uint256 valueLength = ptr.ixl() + 1 - ptr.ixf();
        return der.substring(ptr.ixf() + 1, valueLength - 1);
    }

    function _readNodeLength(bytes memory der, uint256 ix) private pure returns (uint256) {
        uint256 length;
        uint80 ixFirstContentByte;
        uint80 ixLastContentByte;
        if ((der[ix + 1] & 0x80) == 0) {
            length = uint8(der[ix + 1]);
            ixFirstContentByte = uint80(ix + 2);
            ixLastContentByte = uint80(ixFirstContentByte + length - 1);
        } else {
            uint8 lengthbytesLength = uint8(der[ix + 1] & 0x7F);
            if (lengthbytesLength == 1) {
                length = der.readUint8(ix + 2);
            } else if (lengthbytesLength == 2) {
                length = der.readUint16(ix + 2);
            } else {
                length = uint256(
                    der.readBytesN(ix + 2, lengthbytesLength) >> (32 - lengthbytesLength) * 8
                );
            }
            ixFirstContentByte = uint80(ix + 2 + lengthbytesLength);
            ixLastContentByte = uint80(ixFirstContentByte + length - 1);
        }
        return NodePtr.getPtr(ix, ixFirstContentByte, ixLastContentByte);
    }
}
