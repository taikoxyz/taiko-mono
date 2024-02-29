// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TCBInfoStruct } from "../../../contracts/automata-attestation/lib/TCBInfoStruct.sol";
import { EnclaveIdStruct } from "../../../contracts/automata-attestation/lib/EnclaveIdStruct.sol";
import { V3Struct } from "../../../contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import { JSONParserLib } from "solady/src/utils/JSONParserLib.sol";
import { LibString } from "solady/src/utils/LibString.sol";

contract DcapTestUtils {
    using JSONParserLib for JSONParserLib.Item;
    using LibString for string;

    uint256 constant INDEX_ERROR = type(uint256).max;

    function parseTcbInfoJson(string memory tcbInfoJsonStr)
        internal
        pure
        returns (bool success, TCBInfoStruct.TCBInfo memory tcbInfo)
    {
        JSONParserLib.Item memory root = JSONParserLib.parse(tcbInfoJsonStr);
        JSONParserLib.Item[] memory children = root.children();
        JSONParserLib.Item[] memory tcbInfoObj;

        uint256 tcbInfoIndex = INDEX_ERROR;

        for (uint256 i; i < root.size(); ++i) {
            string memory decodedKey = JSONParserLib.decodeString(children[i].key());
            if (decodedKey.eq("tcbInfo")) {
                tcbInfoObj = children[i].children();
                tcbInfoIndex = i;
            }
        }

        if (tcbInfoIndex == INDEX_ERROR) {
            return (false, tcbInfo);
        }

        JSONParserLib.Item[] memory tcbLevels;

        bool pceIdFound;
        bool fmspcFound;
        bool tcbLevelsFound;

        for (uint256 i = 0; i < children[tcbInfoIndex].size(); i++) {
            JSONParserLib.Item memory current = tcbInfoObj[i];
            string memory decodedKey = JSONParserLib.decodeString(current.key());

            if (decodedKey.eq("pceId")) {
                tcbInfo.pceid = JSONParserLib.decodeString(current.value());
                pceIdFound = true;
            }

            if (decodedKey.eq("fmspc")) {
                tcbInfo.fmspc = JSONParserLib.decodeString(current.value());
                fmspcFound = true;
            }

            if (decodedKey.eq("tcbLevels")) {
                tcbLevels = current.children();
                uint256 tcbLevelsSize = current.size();
                tcbInfo.tcbLevels = new TCBInfoStruct.TCBLevelObj[](tcbLevelsSize);
                _parsev2TcbLevels(tcbInfo, tcbLevels, tcbLevelsSize);
                tcbLevelsFound = true;
            }
        }

        success = pceIdFound && fmspcFound && tcbLevelsFound;
    }

    struct EnclaveIdFlag {
        bool miscselectFound;
        bool miscselectMaskFound;
        bool attributesFound;
        bool attributesMaskFound;
        bool mrsignerFound;
        bool isvprodidFound;
        bool tcbLevelsFound;
    }

    function parseEnclaveIdentityJson(string memory enclaveIdJsonStr)
        internal
        pure
        returns (bool success, EnclaveIdStruct.EnclaveId memory enclaveId)
    {
        JSONParserLib.Item memory root = JSONParserLib.parse(enclaveIdJsonStr);
        JSONParserLib.Item[] memory children = root.children();
        JSONParserLib.Item[] memory qeIdObj;

        EnclaveIdFlag memory flag;

        for (uint256 i = 0; i < root.size(); i++) {
            string memory decodedKey = JSONParserLib.decodeString(children[i].key());
            if (decodedKey.eq("enclaveIdentity")) {
                qeIdObj = children[i].children();
                for (uint256 j = 0; j < children[i].size(); j++) {
                    decodedKey = JSONParserLib.decodeString(qeIdObj[j].key());
                    string memory decodedValue;
                    if (qeIdObj[j].isString()) {
                        decodedValue = JSONParserLib.decodeString(qeIdObj[j].value());
                    }
                    if (decodedKey.eq("miscselect")) {
                        bytes memory hexString = _fromHex(decodedValue);
                        enclaveId.miscselect = bytes4(hexString);
                        flag.miscselectFound = true;
                    }
                    if (decodedKey.eq("miscselectMask")) {
                        bytes memory hexString = _fromHex(decodedValue);
                        enclaveId.miscselectMask = bytes4(hexString);
                        flag.miscselectMaskFound = true;
                    }
                    if (decodedKey.eq("attributes")) {
                        bytes memory hexString = _fromHex(decodedValue);
                        enclaveId.attributes = bytes16(hexString);
                        flag.attributesFound = true;
                    }
                    if (decodedKey.eq("attributesMask")) {
                        bytes memory hexString = _fromHex(decodedValue);
                        enclaveId.attributesMask = bytes16(hexString);
                        flag.attributesMaskFound = true;
                    }
                    if (decodedKey.eq("mrsigner")) {
                        bytes memory hexString = _fromHex(decodedValue);
                        enclaveId.mrsigner = bytes32(hexString);
                        flag.mrsignerFound = true;
                    }
                    if (decodedKey.eq("isvprodid")) {
                        enclaveId.isvprodid = uint16(JSONParserLib.parseUint(qeIdObj[j].value()));
                        flag.isvprodidFound = true;
                    }
                    if (decodedKey.eq("tcbLevels")) {
                        JSONParserLib.Item memory current = qeIdObj[j];
                        JSONParserLib.Item[] memory tcbLevels = current.children();
                        uint256 tcbLevelsSize = current.size();
                        enclaveId.tcbLevels = new EnclaveIdStruct.TcbLevel[](tcbLevelsSize);
                        bool parsedSuccessfully =
                            _parseQuoteIdentityTcbLevels(enclaveId, tcbLevels, tcbLevelsSize);
                        flag.tcbLevelsFound = parsedSuccessfully;
                    }
                }
            }
        }

        success = flag.miscselectFound && flag.miscselectMaskFound && flag.attributesFound
            && flag.attributesMaskFound && flag.mrsignerFound && flag.isvprodidFound
            && flag.tcbLevelsFound;
    }

    function _parseQuoteIdentityTcbLevels(
        EnclaveIdStruct.EnclaveId memory enclaveId,
        JSONParserLib.Item[] memory tcbLevels,
        uint256 tcbLevelsSize
    )
        private
        pure
        returns (bool)
    {
        for (uint256 j = 0; j < tcbLevelsSize; j++) {
            JSONParserLib.Item[] memory tcbObjValue = tcbLevels[j].children();
            for (uint256 k = 0; k < tcbLevels[j].size(); k++) {
                string memory decodedKey = JSONParserLib.decodeString(tcbObjValue[k].key());
                if (decodedKey.eq("tcb")) {
                    JSONParserLib.Item memory isvsvn = (tcbObjValue[k].children())[0];
                    decodedKey = JSONParserLib.decodeString(isvsvn.key());
                    if (decodedKey.eq("isvsvn")) {
                        enclaveId.tcbLevels[j].tcb.isvsvn =
                            uint16(JSONParserLib.parseUint(isvsvn.value()));
                    } else {
                        return false;
                    }
                } else if (decodedKey.eq("tcbStatus")) {
                    string memory decodedValue = JSONParserLib.decodeString(tcbObjValue[k].value());
                    if (decodedValue.eq("UpToDate")) {
                        enclaveId.tcbLevels[j].tcbStatus = EnclaveIdStruct.EnclaveIdStatus.OK;
                    } else if (decodedValue.eq("Revoked")) {
                        enclaveId.tcbLevels[j].tcbStatus =
                            EnclaveIdStruct.EnclaveIdStatus.SGX_ENCLAVE_REPORT_ISVSVN_REVOKED;
                    }
                }
            }
        }
        return true;
    }

    function _parsev2TcbLevels(
        TCBInfoStruct.TCBInfo memory tcbInfo,
        JSONParserLib.Item[] memory tcbLevels,
        uint256 tcbLevelsSize
    )
        private
        pure
    {
        for (uint256 j = 0; j < tcbLevelsSize; j++) {
            JSONParserLib.Item[] memory tcbObjValue = tcbLevels[j].children();
            for (uint256 k = 0; k < tcbLevels[j].size(); k++) {
                string memory decodedKey = JSONParserLib.decodeString(tcbObjValue[k].key());
                if (decodedKey.eq("tcb")) {
                    JSONParserLib.Item[] memory tcb = tcbObjValue[k].children();
                    tcbInfo.tcbLevels[j].sgxTcbCompSvnArr = new uint8[](tcbObjValue[k].size() - 1);
                    for (uint256 l = 0; l < tcbObjValue[k].size(); l++) {
                        decodedKey = JSONParserLib.decodeString(tcb[l].key());
                        if (decodedKey.eq("pcesvn")) {
                            tcbInfo.tcbLevels[j].pcesvn = JSONParserLib.parseUint(tcb[l].value());
                        } else {
                            tcbInfo.tcbLevels[j].sgxTcbCompSvnArr[l] =
                                uint8(JSONParserLib.parseUint(tcb[l].value()));
                        }
                    }
                } else if (decodedKey.eq("tcbStatus")) {
                    string memory decodedValue = JSONParserLib.decodeString(tcbObjValue[k].value());
                    if (decodedValue.eq("UpToDate")) {
                        tcbInfo.tcbLevels[j].status = TCBInfoStruct.TCBStatus.OK;
                    } else if (decodedValue.eq("OutOfDate")) {
                        tcbInfo.tcbLevels[j].status = TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE;
                    } else if (decodedValue.eq("OutOfDateConfigurationNeeded")) {
                        tcbInfo.tcbLevels[j].status =
                            TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED;
                    } else if (decodedValue.eq("ConfigurationNeeded")) {
                        tcbInfo.tcbLevels[j].status =
                            TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_NEEDED;
                    } else if (decodedValue.eq("ConfigurationAndSWHardeningNeeded")) {
                        tcbInfo.tcbLevels[j].status =
                            TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED;
                    } else if (decodedValue.eq("SWHardeningNeeded")) {
                        tcbInfo.tcbLevels[j].status =
                            TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED;
                    } else if (decodedValue.eq("Revoked")) {
                        tcbInfo.tcbLevels[j].status = TCBInfoStruct.TCBStatus.TCB_REVOKED;
                    }
                }
            }
        }
    }

    // Converts a string to a hexstring (of bytes type)
    // https://ethereum.stackexchange.com/questions/39989/solidity-convert-hex-string-to-bytes

    // Convert an hexadecimal character to their value
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("failed to convert hex value");
    }

    // Convert an hexadecimal string to raw bytes
    function _fromHex(string memory s) private pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint256 i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(_fromHexChar(uint8(ss[2 * i])) * 16 + _fromHexChar(uint8(ss[2 * i + 1])));
        }
        return r;
    }
}
