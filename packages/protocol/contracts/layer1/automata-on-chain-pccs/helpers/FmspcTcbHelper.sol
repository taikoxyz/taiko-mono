// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JSONParserLib} from "solady/utils/JSONParserLib.sol";
import {LibString} from "solady/utils/LibString.sol";
import {DateTimeUtils} from "../utils/DateTimeUtils.sol";
import {BytesUtils} from "../utils/BytesUtils.sol";

// https://github.com/intel/SGXDataCenterAttestationPrimitives/blob/e7604e02331b3377f3766ed3653250e03af72d45/QuoteVerification/QVL/Src/AttestationLibrary/src/CertVerification/X509Constants.h#L64
uint256 constant TCB_CPUSVN_SIZE = 16;

enum TcbId {
    /// the "id" field is absent from TCBInfo V2
    /// which defaults TcbId to SGX
    /// since TDX TCBInfos are only included in V3 or above
    SGX,
    TDX
}

/**
 * @dev This is a simple representation of the TCBInfo.json in string as a Solidity object.
 * @param tcbInfo: tcbInfoJson.tcbInfo string object body
 * @param signature The signature to be passed as bytes array
 */
struct TcbInfoJsonObj {
    string tcbInfoStr;
    bytes signature;
}

/// @dev Solidity object representing TCBInfo.json excluding TCBLevels
struct TcbInfoBasic {
    /// the name "tcbType" can be confusing/misleading
    /// as the tcbType referred here in this struct is the type
    /// of TCB level composition that determines TCB level comparison logic
    /// It is not the same as the "type" parameter passed as an argument to the
    /// getTcbInfo() API method described in Section 4.2.3 of the Intel PCCS Design Document
    /// Instead, getTcbInfo() "type" argument should be checked against the "id" value of this struct
    /// which represents the TEE type for the given TCBInfo
    uint8 tcbType;
    TcbId id;
    uint32 version;
    uint64 issueDate;
    uint64 nextUpdate;
    uint32 evaluationDataNumber;
    bytes6 fmspc;
    bytes2 pceid;
}

struct TCBLevelsObj {
    uint16 pcesvn;
    uint8[] sgxComponentCpuSvns;
    uint8[] tdxComponentCpuSvns;
    uint64 tcbDateTimestamp;
    TCBStatus status;
    string[] advisoryIDs;
}

struct TDXModule {
    bytes mrsigner; // 48 bytes
    bytes8 attributes;
    bytes8 attributesMask;
}

struct TDXModuleIdentity {
    string id;
    bytes8 attributes;
    bytes8 attributesMask;
    bytes mrsigner; // 48 bytes
    TDXModuleTCBLevelsObj[] tcbLevels;
}

struct TDXModuleTCBLevelsObj {
    uint8 isvsvn;
    uint64 tcbDateTimestamp;
    TCBStatus status;
}

enum TCBStatus {
    OK,
    TCB_SW_HARDENING_NEEDED,
    TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED,
    TCB_CONFIGURATION_NEEDED,
    TCB_OUT_OF_DATE,
    TCB_OUT_OF_DATE_CONFIGURATION_NEEDED,
    TCB_REVOKED,
    TCB_UNRECOGNIZED
}

/**
 * @title FMSPC TCB Helper Contract
 * @notice This is a standalone contract that can be used by off-chain applications and smart contracts
 * to parse TCBInfo data
 */
contract FmspcTcbHelper {
    using JSONParserLib for JSONParserLib.Item;
    using LibString for string;
    using BytesUtils for bytes;

    error TCBInfo_Invalid();

    /**
     * @notice this method generates content-specific hash
     * @notice in other words, we omit the "issueDate" and "nextUpdate" fields from the preimage
     * @notice of the hash.
     * @notice hence, this allows us to keep track of the changes made ONLY to the TCBInfo content
     * @notice regardless of when the collateral is being issued and expires
     */
    function generateFmspcTcbContentHash(
        TcbInfoBasic memory tcbInfoContent,
        string memory tcbLevelsString,
        string memory tdxModuleString,
        string memory tdxModuleIdentitiesString
    ) external pure returns (bytes32 contentHash) {
        bytes memory content = abi.encodePacked(
            tcbInfoContent.tcbType,
            tcbInfoContent.id,
            tcbInfoContent.version,
            tcbInfoContent.evaluationDataNumber,
            tcbInfoContent.fmspc,
            tcbInfoContent.pceid,
            bytes(tcbLevelsString)
        );

        if (bytes(tdxModuleString).length > 0) {
            content = abi.encodePacked(content, bytes(tdxModuleString));
        }

        if (bytes(tdxModuleIdentitiesString).length > 0) {
            content = abi.encodePacked(content, bytes(tdxModuleIdentitiesString));
        }

        contentHash = keccak256(content);
    }

    function tcbLevelsObjToBytes(TCBLevelsObj calldata obj) external pure returns (bytes memory serialized) {
        // first slot = (uint64, uint64, uint64)
        uint256 firstSlot = uint256(obj.pcesvn) << (2 * 64) | uint256(obj.tcbDateTimestamp) << 64 | uint8(obj.status);

        // second slot = (padded uint16 sgxCpuSvns (16 bytes) + padded uint16 tdxCpuSvns (16 bytes))
        uint256 secondSlot;
        uint256 n = obj.sgxComponentCpuSvns.length;
        for (uint256 i = 0; i < n;) {
            uint256 v1Shift = 8 * ((2 * n) - i - 1);
            secondSlot |= uint256(obj.sgxComponentCpuSvns[i]) << v1Shift;

            unchecked {
                i++;
            }
        }
        if (obj.tdxComponentCpuSvns.length > 0) {
            for (uint256 i = 0; i < n;) {
                uint256 v2Shift = 8 * (n - i - 1);
                secondSlot |= uint256(obj.tdxComponentCpuSvns[i]) << v2Shift;

                unchecked {
                    i++;
                }
            }
        }

        // string slot = padding all advisory IDs together using '\n' as a delimiter
        bytes memory stringSlot;
        if (obj.advisoryIDs.length > 0) {
            string memory concat = obj.advisoryIDs[0];
            for (uint256 j = 1; j < obj.advisoryIDs.length; j++) {
                concat = string.concat(concat, "\n", obj.advisoryIDs[j]);
            }
            stringSlot = bytes(concat);
        }

        serialized = abi.encodePacked(firstSlot, secondSlot, stringSlot);
    }

    function tcbLevelsObjFromBytes(bytes calldata encoded) external pure returns (TCBLevelsObj memory parsed) {
        // Step 1: decode first slot
        parsed.pcesvn = uint16(bytes2(encoded[14:16]));
        parsed.tcbDateTimestamp = uint64(bytes8(encoded[16:24]));
        parsed.status = TCBStatus(uint8(bytes1(encoded[31:32])));

        // Step 2: decode second slot
        parsed.sgxComponentCpuSvns = new uint8[](16);
        parsed.tdxComponentCpuSvns = new uint8[](16);
        bytes32 encodedSlot2 = bytes32(encoded[32:64]);
        for (uint256 i = 0; i < 16;) {
            if (encodedSlot2[i] != 0) {
                parsed.sgxComponentCpuSvns[i] = uint8(bytes1(encodedSlot2[i]));
            }
            if (encodedSlot2[i + 16] != 0) {
                parsed.tdxComponentCpuSvns[i] = uint8(bytes1(encodedSlot2[i + 16]));
            }
            unchecked {
                i++;
            }
        }

        // Step 3: decode the string
        if (encoded.length > 64) {
            parsed.advisoryIDs = LibString.split(string(encoded[64:encoded.length]), "\n");
        }
    }

    function tdxModuleIdentityToBytes(TDXModuleIdentity calldata tdxModuleIdentity)
        external
        pure
        returns (bytes memory packedTdxModuleIdentity)
    {
        bytes32 slot1 = LibString.packOne(tdxModuleIdentity.id);

        // mrsigner is split into two slots
        // first slot: contains the first 32 bytes of mrsigner
        // second slot: contains the remaining 16 bytes, followed by 16 zero bytes
        bytes32 slot2 = bytes32(tdxModuleIdentity.mrsigner);
        bytes32 slot3 = bytes32(abi.encodePacked(tdxModuleIdentity.mrsigner.substring(32, 16), bytes16(0)));

        // Slot 4 is occupied by packing both the attributes and attributes mask
        // Slot 4 = (attributes, attributesMask)
        bytes32 slot4 = bytes32(tdxModuleIdentity.attributes) | bytes32(tdxModuleIdentity.attributesMask) >> 128;

        // encode the tdx module array
        uint256 n = tdxModuleIdentity.tcbLevels.length;
        uint256[] memory tdxTcbSlots = new uint256[](n);
        for (uint256 i = 0; i < n;) {
            tdxTcbSlots[i] = _tdxModuleTcbLevelsObjToSlot(tdxModuleIdentity.tcbLevels[i]);

            unchecked {
                i++;
            }
        }

        // total slots = 4 + n
        packedTdxModuleIdentity = abi.encodePacked(slot1, slot2, slot3, slot4, abi.encodePacked(tdxTcbSlots));
    }

    function tdxModuleIdentityFromBytes(bytes calldata packedTdxModuleIdentity)
        external
        pure
        returns (TDXModuleIdentity memory tdxModuleIdentity)
    {
        // decode slot 1
        tdxModuleIdentity.id = LibString.unpackOne(bytes32(packedTdxModuleIdentity[0:32]));

        // decode slots 2 and 3 to get mrsigner
        tdxModuleIdentity.mrsigner = packedTdxModuleIdentity[32:80];

        // decode tdx module identity tcb level array
        tdxModuleIdentity.attributes = bytes8(packedTdxModuleIdentity[96:104]);
        tdxModuleIdentity.attributesMask = bytes8(packedTdxModuleIdentity[112:120]);
        uint256 offset = 128;
        uint256 n = (packedTdxModuleIdentity.length - offset) / 32;
        tdxModuleIdentity.tcbLevels = new TDXModuleTCBLevelsObj[](n);

        for (uint256 i = 0; i < n;) {
            uint256 end = offset + 32;
            uint256 slot = uint256(bytes32(packedTdxModuleIdentity[offset:end]));
            tdxModuleIdentity.tcbLevels[i] = _tdxModuleTcbLevelsObjFromSlot(slot);

            offset = end;
            unchecked {
                i++;
            }
        }
    }

    // use bitmaps to represent the keys found in TCBInfo
    // all tcb types regardless of version and tee types should have these keys described below:
    // [version, issueDate, nextUpdate, fmspc, pceId, tcbType, tcbEvaluationDataNumber, tcbLevels]
    // Bits are sorted in the order of the keys above from LSB to MSB
    // e.g. if version is found, the bytes would look like 00000001
    // e.g. if both version and fmspc were found, the bytes would look like 00001001

    // the next byte contains the keys only found for V3, and TDX TCBInfos
    // [id, tdxModule, tdxModuleIdentities]

    uint8 constant TCB_VERSION_BIT = 1;
    uint8 constant TCB_ISSUE_DATE_BIT = 2;
    uint8 constant TCB_NEXT_UPDATE_BIT = 4;
    uint8 constant TCB_FMSPC_BIT = 8;
    uint8 constant TCB_PCEID_BIT = 16;
    uint8 constant TCB_TYPE_BIT = 32;
    uint8 constant TCB_EVALUATION_DATA_NUMBER_BIT = 64;
    uint8 constant TCB_LEVELS_BIT = 128;
    uint16 constant TCB_ID_BIT = 256;
    uint16 constant TCB_TDX_MODULE_BIT = 512;
    uint16 constant TCB_TDX_MODULE_IDENTITIES_BIT = 1024;

    function parseTcbString(string calldata tcbInfoStr)
        external
        pure
        returns (
            TcbInfoBasic memory tcbInfo,
            string memory tcbLevelsString,
            string memory tdxModuleString,
            string memory tdxModuleIdentitiesString
        )
    {
        JSONParserLib.Item memory root = JSONParserLib.parse(tcbInfoStr);
        JSONParserLib.Item[] memory tcbInfoObj = root.children();

        uint256 f;
        bool isTdx;
        uint256 n = root.size();

        for (uint256 i = 0; i < n;) {
            JSONParserLib.Item memory current = tcbInfoObj[i];
            string memory decodedKey = JSONParserLib.decodeString(current.key());
            string memory val = current.value();

            if (f & TCB_ID_BIT == 0 && decodedKey.eq("id")) {
                string memory idStr = JSONParserLib.decodeString(val);
                f |= TCB_ID_BIT;
                if (idStr.eq("TDX")) {
                    tcbInfo.id = TcbId.TDX;
                    isTdx = true;
                } else if (!idStr.eq("SGX")) {
                    revert TCBInfo_Invalid();
                }
            } else if (f & TCB_VERSION_BIT == 0 && decodedKey.eq("version")) {
                tcbInfo.version = uint32(JSONParserLib.parseUint(val));
                f |= TCB_VERSION_BIT;
                if (tcbInfo.version < 3) {
                    f |= TCB_ID_BIT;
                }
            } else if (f & TCB_ISSUE_DATE_BIT == 0 && decodedKey.eq("issueDate")) {
                tcbInfo.issueDate = uint64(DateTimeUtils.fromISOToTimestamp(JSONParserLib.decodeString(val)));
                f |= TCB_ISSUE_DATE_BIT;
            } else if (f & TCB_NEXT_UPDATE_BIT == 0 && decodedKey.eq("nextUpdate")) {
                tcbInfo.nextUpdate = uint64(DateTimeUtils.fromISOToTimestamp(JSONParserLib.decodeString(val)));
                f |= TCB_NEXT_UPDATE_BIT;
            } else if (f & TCB_FMSPC_BIT == 0 && decodedKey.eq("fmspc")) {
                tcbInfo.fmspc = bytes6(uint48(JSONParserLib.parseUintFromHex(JSONParserLib.decodeString(val))));
                f |= TCB_FMSPC_BIT;
            } else if (f & TCB_PCEID_BIT == 0 && decodedKey.eq("pceId")) {
                tcbInfo.pceid = bytes2(uint16(JSONParserLib.parseUintFromHex(JSONParserLib.decodeString(val))));
                f |= TCB_PCEID_BIT;
            } else if (f & TCB_TYPE_BIT == 0 && decodedKey.eq("tcbType")) {
                tcbInfo.tcbType = uint8(JSONParserLib.parseUint(val));
                f |= TCB_TYPE_BIT;
            } else if (f & TCB_EVALUATION_DATA_NUMBER_BIT == 0 && decodedKey.eq("tcbEvaluationDataNumber")) {
                tcbInfo.evaluationDataNumber = uint32(JSONParserLib.parseUint(val));
                f |= TCB_EVALUATION_DATA_NUMBER_BIT;
            } else if (
                tcbInfo.version > 2 && isTdx && (f & TCB_TDX_MODULE_BIT == 0 || f & TCB_TDX_MODULE_IDENTITIES_BIT == 0)
            ) {
                if (f & TCB_TDX_MODULE_BIT == 0 && decodedKey.eq("tdxModule")) {
                    tdxModuleString = val;
                    f |= TCB_TDX_MODULE_BIT;
                } else if (f & TCB_TDX_MODULE_IDENTITIES_BIT == 0 && decodedKey.eq("tdxModuleIdentities")) {
                    tdxModuleIdentitiesString = val;
                    f |= TCB_TDX_MODULE_IDENTITIES_BIT;
                }
            } else if (f & TCB_LEVELS_BIT == 0 && decodedKey.eq("tcbLevels")) {
                tcbLevelsString = val;
                f |= TCB_LEVELS_BIT;
            }

            unchecked {
                i++;
            }
        }

        // v2 tcbinfo does not explicitly have the "id" field
        // but we set the bit to 1 anyway to save gas by skipping the check
        // incrementing n prevents from the "id" bit to be set to 0 by masking
        if (tcbInfo.version < 3) {
            n++;
        }

        bool allFound = f == (2 ** n) - 1;

        if (!allFound) {
            revert TCBInfo_Invalid();
        }
    }

    function parseTcbLevels(uint256 version, string calldata tcbLevelsString)
        external
        pure
        returns (TCBLevelsObj[] memory tcbLevels)
    {
        JSONParserLib.Item memory root = JSONParserLib.parse(tcbLevelsString);
        JSONParserLib.Item[] memory tcbLevelsObj = root.children();
        uint256 tcbLevelsSize = tcbLevelsObj.length;
        tcbLevels = new TCBLevelsObj[](tcbLevelsSize);

        // iterating through the array
        for (uint256 i = 0; i < tcbLevelsSize; i++) {
            JSONParserLib.Item[] memory tcbObj = tcbLevelsObj[i].children();
            // iterating through individual tcb objects
            for (uint256 j = 0; j < tcbLevelsObj[i].size(); j++) {
                string memory tcbKey = JSONParserLib.decodeString(tcbObj[j].key());
                if (tcbKey.eq("tcb")) {
                    string memory tcbStr = tcbObj[j].value();
                    JSONParserLib.Item memory tcbParent = JSONParserLib.parse(tcbStr);
                    JSONParserLib.Item[] memory tcbComponents = tcbParent.children();
                    if (version == 2) {
                        (tcbLevels[i].sgxComponentCpuSvns, tcbLevels[i].pcesvn) = _parseV2Tcb(tcbComponents);
                    } else if (version == 3) {
                        (tcbLevels[i].sgxComponentCpuSvns, tcbLevels[i].tdxComponentCpuSvns, tcbLevels[i].pcesvn) =
                            _parseV3Tcb(tcbComponents);
                    } else {
                        revert TCBInfo_Invalid();
                    }
                } else if (tcbKey.eq("tcbDate")) {
                    tcbLevels[i].tcbDateTimestamp =
                        uint64(DateTimeUtils.fromISOToTimestamp(JSONParserLib.decodeString(tcbObj[j].value())));
                } else if (tcbKey.eq("tcbStatus")) {
                    tcbLevels[i].status = _getTcbStatus(JSONParserLib.decodeString(tcbObj[j].value()));
                } else if (tcbKey.eq("advisoryIDs")) {
                    JSONParserLib.Item[] memory advisoryArr = tcbObj[j].children();
                    uint256 n = tcbObj[j].size();
                    tcbLevels[i].advisoryIDs = new string[](n);
                    for (uint256 k = 0; k < n; k++) {
                        tcbLevels[i].advisoryIDs[k] = JSONParserLib.decodeString(advisoryArr[k].value());
                    }
                }
            }
        }
    }

    function parseTcbTdxModules(string calldata tdxModuleString, string calldata tdxModuleIdentitiesString)
        external
        pure
        returns (TDXModule memory module, TDXModuleIdentity[] memory moduleIdentities)
    {
        JSONParserLib.Item memory tdxModuleRoot = JSONParserLib.parse(tdxModuleString);
        JSONParserLib.Item[] memory tdxModuleItems = tdxModuleRoot.children();

        JSONParserLib.Item memory tdxModuleIdentitiesRoot = JSONParserLib.parse(tdxModuleIdentitiesString);
        JSONParserLib.Item[] memory tdxModuleIdentitiesItems = tdxModuleIdentitiesRoot.children();

        module = _parseTdxModule(tdxModuleItems);
        moduleIdentities = _parseTdxModuleIdentities(tdxModuleIdentitiesItems);
    }

    /// ====== INTERNAL METHODS BELOW ======

    function _tdxModuleTcbLevelsObjToSlot(TDXModuleTCBLevelsObj memory tdxModuleTcbLevelsObj)
        private
        pure
        returns (uint256 tdxTcbPacked)
    {
        // tcb levels within tdx module can be packed into a single slot
        // (uint64 packedIsvsvn, uint64 packedTcbDateTimestamp, uint64 packedStatus)

        tdxTcbPacked = uint256(tdxModuleTcbLevelsObj.isvsvn) << (2 * 64)
            | uint256(tdxModuleTcbLevelsObj.tcbDateTimestamp) << 64 | uint8(tdxModuleTcbLevelsObj.status);
    }

    function _tdxModuleTcbLevelsObjFromSlot(uint256 tdxTcbPacked)
        private
        pure
        returns (TDXModuleTCBLevelsObj memory tdxModuleTcbLevelsObj)
    {
        uint64 mask = 0xFFFFFFFFFFFFFFFF;

        tdxModuleTcbLevelsObj.status = TCBStatus(uint8(uint64(tdxTcbPacked & mask)));
        tdxModuleTcbLevelsObj.tcbDateTimestamp = uint64((tdxTcbPacked >> 64) & mask);
        tdxModuleTcbLevelsObj.isvsvn = uint8(uint64((tdxTcbPacked >> 128) & mask));
    }

    function _getTcbStatus(string memory statusStr) private pure returns (TCBStatus status) {
        if (statusStr.eq("UpToDate")) {
            status = TCBStatus.OK;
        } else if (statusStr.eq("OutOfDate")) {
            status = TCBStatus.TCB_OUT_OF_DATE;
        } else if (statusStr.eq("OutOfDateConfigurationNeeded")) {
            status = TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED;
        } else if (statusStr.eq("ConfigurationNeeded")) {
            status = TCBStatus.TCB_CONFIGURATION_NEEDED;
        } else if (statusStr.eq("ConfigurationAndSWHardeningNeeded")) {
            status = TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED;
        } else if (statusStr.eq("SWHardeningNeeded")) {
            status = TCBStatus.TCB_SW_HARDENING_NEEDED;
        } else if (statusStr.eq("Revoked")) {
            status = TCBStatus.TCB_REVOKED;
        } else {
            status = TCBStatus.TCB_UNRECOGNIZED;
        }
    }

    function _parseV2Tcb(JSONParserLib.Item[] memory tcbComponents)
        private
        pure
        returns (uint8[] memory sgxComponentCpuSvns, uint16 pcesvn)
    {
        sgxComponentCpuSvns = new uint8[](TCB_CPUSVN_SIZE);
        uint256 cpusvnCounter = 0;
        for (uint256 i = 0; i < tcbComponents.length; i++) {
            string memory key = JSONParserLib.decodeString(tcbComponents[i].key());
            uint256 value = JSONParserLib.parseUint(tcbComponents[i].value());
            if (key.eq("pcesvn")) {
                pcesvn = uint16(value);
            } else {
                sgxComponentCpuSvns[cpusvnCounter++] = uint8(value);
            }
        }
        if (cpusvnCounter != TCB_CPUSVN_SIZE) {
            revert TCBInfo_Invalid();
        }
    }

    function _parseV3Tcb(JSONParserLib.Item[] memory tcbComponents)
        private
        pure
        returns (uint8[] memory sgxComponentCpuSvns, uint8[] memory tdxComponentCpuSvns, uint16 pcesvn)
    {
        sgxComponentCpuSvns = new uint8[](TCB_CPUSVN_SIZE);
        tdxComponentCpuSvns = new uint8[](TCB_CPUSVN_SIZE);
        for (uint256 i = 0; i < tcbComponents.length; i++) {
            string memory key = JSONParserLib.decodeString(tcbComponents[i].key());
            if (key.eq("pcesvn")) {
                pcesvn = uint16(JSONParserLib.parseUint(tcbComponents[i].value()));
            } else {
                string memory componentKey = key;
                JSONParserLib.Item[] memory componentArr = tcbComponents[i].children();
                uint256 cpusvnCounter = 0;
                for (uint256 j = 0; j < tcbComponents[i].size(); j++) {
                    JSONParserLib.Item[] memory component = componentArr[j].children();
                    for (uint256 k = 0; k < componentArr[j].size(); k++) {
                        key = JSONParserLib.decodeString(component[k].key());
                        if (key.eq("svn")) {
                            if (componentKey.eq("tdxtcbcomponents")) {
                                tdxComponentCpuSvns[cpusvnCounter++] =
                                    uint8(JSONParserLib.parseUint(component[k].value()));
                            } else {
                                sgxComponentCpuSvns[cpusvnCounter++] =
                                    uint8(JSONParserLib.parseUint(component[k].value()));
                            }
                        }
                    }
                }
                if (cpusvnCounter != TCB_CPUSVN_SIZE) {
                    revert TCBInfo_Invalid();
                }
            }
        }
    }

    function _parseTdxModule(JSONParserLib.Item[] memory tdxModuleObj) private pure returns (TDXModule memory module) {
        for (uint256 i = 0; i < tdxModuleObj.length; i++) {
            string memory key = JSONParserLib.decodeString(tdxModuleObj[i].key());
            string memory val = JSONParserLib.decodeString(tdxModuleObj[i].value());
            if (key.eq("attributes")) {
                module.attributes = bytes8(uint64(JSONParserLib.parseUintFromHex(val)));
            }
            if (key.eq("attributesMask")) {
                module.attributesMask = bytes8(uint64(JSONParserLib.parseUintFromHex(val)));
            }
            if (key.eq("mrsigner")) {
                module.mrsigner = _getMrSignerHex(val);
            }
        }
    }

    function _parseTdxModuleIdentities(JSONParserLib.Item[] memory tdxModuleIdentitiesArr)
        private
        pure
        returns (TDXModuleIdentity[] memory identities)
    {
        uint256 n = tdxModuleIdentitiesArr.length;
        identities = new TDXModuleIdentity[](n);
        for (uint256 i = 0; i < n; i++) {
            JSONParserLib.Item[] memory currIdentity = tdxModuleIdentitiesArr[i].children();
            for (uint256 j = 0; j < tdxModuleIdentitiesArr[i].size(); j++) {
                string memory key = JSONParserLib.decodeString(currIdentity[j].key());
                if (key.eq("id")) {
                    string memory val = JSONParserLib.decodeString(currIdentity[j].value());
                    identities[i].id = val;
                }
                if (key.eq("mrsigner")) {
                    string memory val = JSONParserLib.decodeString(currIdentity[j].value());
                    identities[i].mrsigner = _getMrSignerHex(val);
                }
                if (key.eq("attributes")) {
                    string memory val = JSONParserLib.decodeString(currIdentity[j].value());
                    identities[i].attributes = bytes8(uint64(JSONParserLib.parseUintFromHex(val)));
                }
                if (key.eq("attributesMask")) {
                    string memory val = JSONParserLib.decodeString(currIdentity[j].value());
                    identities[i].attributesMask = bytes8(uint64(JSONParserLib.parseUintFromHex(val)));
                }
                if (key.eq("tcbLevels")) {
                    JSONParserLib.Item[] memory tcbLevelsArr = currIdentity[j].children();
                    uint256 x = tcbLevelsArr.length;
                    identities[i].tcbLevels = new TDXModuleTCBLevelsObj[](x);
                    for (uint256 k = 0; k < x; k++) {
                        JSONParserLib.Item[] memory tcb = tcbLevelsArr[k].children();
                        for (uint256 l = 0; l < tcb.length; l++) {
                            key = JSONParserLib.decodeString(tcb[l].key());
                            if (key.eq("tcb")) {
                                JSONParserLib.Item[] memory isvsvnObj = tcb[l].children();
                                key = JSONParserLib.decodeString(isvsvnObj[0].key());
                                if (key.eq("isvsvn")) {
                                    identities[i].tcbLevels[k].isvsvn =
                                        uint8(JSONParserLib.parseUint(isvsvnObj[0].value()));
                                } else {
                                    revert TCBInfo_Invalid();
                                }
                            }
                            if (key.eq("tcbDate")) {
                                identities[i].tcbLevels[k].tcbDateTimestamp =
                                    uint64(DateTimeUtils.fromISOToTimestamp(JSONParserLib.decodeString(tcb[l].value())));
                            }
                            if (key.eq("tcbStatus")) {
                                identities[i].tcbLevels[k].status =
                                    _getTcbStatus(JSONParserLib.decodeString(tcb[l].value()));
                            }
                        }
                    }
                }
            }
        }
    }

    function _getMrSignerHex(string memory mrSignerStr) private pure returns (bytes memory mrSignerBytes) {
        string memory mrSignerUpper16BytesStr = mrSignerStr.slice(0, 16);
        string memory mrSignerLower32BytesStr = mrSignerStr.slice(16, 48);
        uint256 mrSignerUpperBytes = JSONParserLib.parseUintFromHex(mrSignerUpper16BytesStr);
        uint256 mrSignerLowerBytes = JSONParserLib.parseUintFromHex(mrSignerLower32BytesStr);
        mrSignerBytes = abi.encodePacked(uint128(mrSignerUpperBytes), mrSignerLowerBytes);
    }
}
