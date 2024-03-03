// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import "./SHA1.sol";

// Inspired by adria0/SolRsaVerify - GPL-3.0 license
// https://github.com/adria0/SolRsaVerify/blob/master/src/RsaVerify.sol

/*
    Copyright 2016, Adrià Massanet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Checked results with FIPS test vectors
https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/dss/186-2rsatestvectors.zip
    file SigVer15_186-3.rsp
    
 */

/// @title RsaVerify
/// @custom:security-contact security@taiko.xyz
library RsaVerify {
    /**
     * @dev Verifies a PKCSv1.5 SHA256 signature
     * @param _sha256 is the sha256 of the data
     * @param _s is the signature
     * @param _e is the exponent
     * @param _m is the modulus
     * @return true if success, false otherwise
     */
    function pkcs1Sha256(
        bytes32 _sha256,
        bytes memory _s,
        bytes memory _e,
        bytes memory _m
    )
        internal
        view
        returns (bool)
    {
        uint8[17] memory sha256ExplicitNullParam = [
            0x30,
            0x31,
            0x30,
            0x0d,
            0x06,
            0x09,
            0x60,
            0x86,
            0x48,
            0x01,
            0x65,
            0x03,
            0x04,
            0x02,
            0x01,
            0x05,
            0x00
        ];

        uint8[15] memory sha256ImplicitNullParam = [
            0x30,
            0x2f,
            0x30,
            0x0b,
            0x06,
            0x09,
            0x60,
            0x86,
            0x48,
            0x01,
            0x65,
            0x03,
            0x04,
            0x02,
            0x01
        ];

        // decipher

        bytes memory input =
            bytes.concat(bytes32(_s.length), bytes32(_e.length), bytes32(_m.length), _s, _e, _m);
        uint256 inputlen = input.length;

        uint256 decipherlen = _m.length;
        bytes memory decipher = new bytes(decipherlen);
        assembly {
            pop(
                staticcall(
                    sub(gas(), 2000),
                    5,
                    add(input, 0x20),
                    inputlen,
                    add(decipher, 0x20),
                    decipherlen
                )
            )
        }

        // Check that is well encoded:
        //
        // 0x00 || 0x01 || PS || 0x00 || DigestInfo
        // PS is padding filled with 0xff
        // DigestInfo ::= SEQUENCE {
        //    digestAlgorithm AlgorithmIdentifier,
        //      [optional algorithm parameters]
        //    digest OCTET STRING
        // }

        bool hasNullParam;
        uint256 digestAlgoWithParamLen;

        if (uint8(decipher[decipherlen - 50]) == 0x31) {
            hasNullParam = true;
            digestAlgoWithParamLen = sha256ExplicitNullParam.length;
        } else if (uint8(decipher[decipherlen - 48]) == 0x2f) {
            hasNullParam = false;
            digestAlgoWithParamLen = sha256ImplicitNullParam.length;
        } else {
            return false;
        }

        uint256 paddingLen = decipherlen - 5 - digestAlgoWithParamLen - 32;

        if (decipher[0] != 0 || decipher[1] != 0x01) {
            return false;
        }
        for (uint256 i = 2; i < 2 + paddingLen; ++i) {
            if (decipher[i] != 0xff) {
                return false;
            }
        }
        if (decipher[2 + paddingLen] != 0) {
            return false;
        }

        // check digest algorithm

        if (digestAlgoWithParamLen == sha256ExplicitNullParam.length) {
            for (uint256 i; i < digestAlgoWithParamLen; ++i) {
                if (decipher[3 + paddingLen + i] != bytes1(sha256ExplicitNullParam[i])) {
                    return false;
                }
            }
        } else {
            for (uint256 i; i < digestAlgoWithParamLen; ++i) {
                if (decipher[3 + paddingLen + i] != bytes1(sha256ImplicitNullParam[i])) {
                    return false;
                }
            }
        }

        // check digest

        if (
            decipher[3 + paddingLen + digestAlgoWithParamLen] != 0x04
                || decipher[4 + paddingLen + digestAlgoWithParamLen] != 0x20
        ) {
            return false;
        }

        for (uint256 i; i < _sha256.length; ++i) {
            if (decipher[5 + paddingLen + digestAlgoWithParamLen + i] != _sha256[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Verifies a PKCSv1.5 SHA256 signature
     * @param _data to verify
     * @param _s is the signature
     * @param _e is the exponent
     * @param _m is the modulus
     * @return 0 if success, >0 otherwise
     */
    function pkcs1Sha256Raw(
        bytes memory _data,
        bytes memory _s,
        bytes memory _e,
        bytes memory _m
    )
        internal
        view
        returns (bool)
    {
        return pkcs1Sha256(sha256(_data), _s, _e, _m);
    }

    /**
     * @dev Verifies a PKCSv1.5 SHA1 signature
     * @param _sha1 is the sha1 of the data
     * @param _s is the signature
     * @param _e is the exponent
     * @param _m is the modulus
     * @return true if success, false otherwise
     */
    function pkcs1Sha1(
        bytes20 _sha1,
        bytes memory _s,
        bytes memory _e,
        bytes memory _m
    )
        internal
        view
        returns (bool)
    {
        uint8[15] memory sha1Prefix = [
            0x30,
            0x21,
            0x30,
            0x09,
            0x06,
            0x05,
            0x2b,
            0x0e,
            0x03,
            0x02,
            0x1a,
            0x05,
            0x00,
            0x04,
            0x14
        ];

        // decipher
        bytes memory input =
            bytes.concat(bytes32(_s.length), bytes32(_e.length), bytes32(_m.length), _s, _e, _m);
        uint256 inputlen = input.length;

        uint256 decipherlen = _m.length;
        bytes memory decipher = new bytes(decipherlen);
        assembly {
            pop(
                staticcall(
                    sub(gas(), 2000),
                    5,
                    add(input, 0x20),
                    inputlen,
                    add(decipher, 0x20),
                    decipherlen
                )
            )
        }

        // Check that is well encoded:
        // 0x00 || 0x01 || PS || 0x00 || DigestInfo
        // PS is padding filled with 0xff
        // DigestInfo ::= SEQUENCE {
        //    digestAlgorithm AlgorithmIdentifier,
        //    digest OCTET STRING
        // }

        uint256 paddingLen = decipherlen - 3 - sha1Prefix.length - 20;

        if (decipher[0] != 0 || decipher[1] != 0x01) {
            return false;
        }
        for (uint256 i = 2; i < 2 + paddingLen; ++i) {
            if (decipher[i] != 0xff) {
                return false;
            }
        }
        if (decipher[2 + paddingLen] != 0) {
            return false;
        }

        // check digest algorithm
        for (uint256 i; i < sha1Prefix.length; ++i) {
            if (decipher[3 + paddingLen + i] != bytes1(sha1Prefix[i])) {
                return false;
            }
        }

        // check digest
        for (uint256 i; i < _sha1.length; ++i) {
            if (decipher[3 + paddingLen + sha1Prefix.length + i] != _sha1[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Verifies a PKCSv1.5 SHA1 signature
     * @param _data to verify
     * @param _s is the signature
     * @param _e is the exponent
     * @param _m is the modulus
     * @return 0 if success, >0 otherwise
     */
    function pkcs1Sha1Raw(
        bytes memory _data,
        bytes memory _s,
        bytes memory _e,
        bytes memory _m
    )
        internal
        view
        returns (bool)
    {
        return pkcs1Sha1(SHA1.sha1(_data), _s, _e, _m);
    }
}
