// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {X509Helper, X509CertObj, Asn1Decode, NodePtr, BytesUtils} from "./X509Helper.sol";

/**
 * @title PCK X509 Certificate Parser
 * @notice This is an extension of the X509Helper library,
 * that parses the SGX Extension ASN.1 sequence as an add-on.
 * @dev This is the default library to be used as a X509 Certificate parser,
 * for all Intel DCAP-related contracts.
 */
contract PCKHelper is X509Helper {
    using Asn1Decode for bytes;
    using NodePtr for uint256;
    using BytesUtils for bytes;

    // 1.2.840.113741.1.13.1
    bytes constant SGX_EXTENSION_OID = hex"2A864886F84D010D01";
    // 1.2.840.113741.1.13.1.2
    bytes constant TCB_OID = hex"2A864886F84D010D0102";
    // 1.2.840.113741.1.13.1.2.17
    bytes constant PCESVN_OID = hex"2A864886F84D010D010211";
    // 1.2.840.113741.1.13.1.3
    bytes constant PCEID_OID = hex"2A864886F84D010D0103";
    // 1.2.840.113741.1.13.1.4
    bytes constant FMSPC_OID = hex"2A864886F84D010D0104";

    // https://github.com/intel/SGXDataCenterAttestationPrimitives/blob/e7604e02331b3377f3766ed3653250e03af72d45/QuoteVerification/QVL/Src/AttestationLibrary/src/CertVerification/X509Constants.h#L64
    uint256 constant SGX_TCB_CPUSVN_SIZE = 16;

    struct PCKTCBFlags {
        bool fmspcFound;
        bool pceidFound;
        bool tcbFound;
    }

    function parsePckExtension(bytes memory der, uint256 extensionPtr)
        external
        pure
        returns (uint16 pcesvn, uint8[] memory cpusvns, bytes memory fmspcBytes, bytes memory pceidBytes)
    {
        if (der[extensionPtr.ixs()] != 0xA3) {
            revert("Not an extension");
        }
        uint256 parentPtr = der.firstChildOf(extensionPtr);
        uint256 childPtr = der.firstChildOf(parentPtr);
        bool success;
        (success, pcesvn, cpusvns, fmspcBytes, pceidBytes) = _findPckTcbInfo(der, childPtr, parentPtr);
        require(success, "invalid SGX extension");
    }

    function _findPckTcbInfo(bytes memory der, uint256 ptr, uint256 parentPtr)
        private
        pure
        returns (bool success, uint16 pcesvn, uint8[] memory cpusvns, bytes memory fmspcBytes, bytes memory pceidBytes)
    {
        // iterate through the elements in the Extension sequence
        // until we locate the SGX Extension OID
        while (ptr != 0) {
            uint256 internalPtr = der.firstChildOf(ptr);
            if (der[internalPtr.ixs()] != 0x06) {
                return (false, pcesvn, cpusvns, fmspcBytes, pceidBytes);
            }

            if (BytesUtils.compareBytes(der.bytesAt(internalPtr), SGX_EXTENSION_OID)) {
                // 1.2.840.113741.1.13.1
                internalPtr = der.nextSiblingOf(internalPtr);
                uint256 extnValueParentPtr = der.rootOfOctetStringAt(internalPtr);
                uint256 extnValuePtr = der.firstChildOf(extnValueParentPtr);

                // Copy flags to memory to avoid stack too deep
                PCKTCBFlags memory flags;

                while (!(flags.fmspcFound && flags.pceidFound && flags.tcbFound)) {
                    uint256 extnValueOidPtr = der.firstChildOf(extnValuePtr);
                    if (der[extnValueOidPtr.ixs()] != 0x06) {
                        return (false, pcesvn, cpusvns, fmspcBytes, pceidBytes);
                    }
                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), TCB_OID)) {
                        // 1.2.840.113741.1.13.1.2
                        (flags.tcbFound, pcesvn, cpusvns) = _findTcb(der, extnValueOidPtr);
                    }
                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), PCEID_OID)) {
                        // 1.2.840.113741.1.13.1.3
                        uint256 pceidPtr = der.nextSiblingOf(extnValueOidPtr);
                        pceidBytes = der.bytesAt(pceidPtr);
                        flags.pceidFound = true;
                    }
                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), FMSPC_OID)) {
                        // 1.2.840.113741.1.13.1.4
                        uint256 fmspcPtr = der.nextSiblingOf(extnValueOidPtr);
                        fmspcBytes = der.bytesAt(fmspcPtr);
                        flags.fmspcFound = true;
                    }

                    if (extnValuePtr.ixl() < extnValueParentPtr.ixl()) {
                        extnValuePtr = der.nextSiblingOf(extnValuePtr);
                    } else {
                        break;
                    }
                }
                success = flags.fmspcFound && flags.pceidFound && flags.tcbFound;
                break;
            }

            if (ptr.ixl() < parentPtr.ixl()) {
                ptr = der.nextSiblingOf(ptr);
            } else {
                ptr = 0; // exit
            }
        }
    }

    function _findTcb(bytes memory der, uint256 oidPtr)
        private
        pure
        returns (bool success, uint16 pcesvn, uint8[] memory cpusvns)
    {
        // sibling of tcbOid
        uint256 tcbPtr = der.nextSiblingOf(oidPtr);
        // get the first svn object in the sequence
        uint256 svnParentPtr = der.firstChildOf(tcbPtr);
        cpusvns = new uint8[](SGX_TCB_CPUSVN_SIZE);
        for (uint256 i = 0; i < SGX_TCB_CPUSVN_SIZE + 1; i++) {
            uint256 svnPtr = der.firstChildOf(svnParentPtr); // OID
            uint256 svnValuePtr = der.nextSiblingOf(svnPtr); // value
            bytes memory svnValueBytes = der.bytesAt(svnValuePtr);
            uint16 svnValue =
                svnValueBytes.length < 2 ? uint16(bytes2(svnValueBytes)) / 256 : uint16(bytes2(svnValueBytes));
            if (BytesUtils.compareBytes(der.bytesAt(svnPtr), PCESVN_OID)) {
                // pcesvn is 2 bytes in size
                pcesvn = uint16(svnValue);
            } else {
                uint8 cpusvn = uint8(svnValue);
                cpusvns[i] = cpusvn;
            }

            // iterate to the next svn object in the sequence
            svnParentPtr = der.nextSiblingOf(svnParentPtr);
        }
        success = true;
    }
}
