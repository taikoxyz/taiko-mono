// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AutomataInterfaces
/// @notice Local copies of Automata contract interfaces used by tests.
/// This avoids bringing in the full automata library which has compilation issues.

/// @notice Enclave identity JSON object
struct EnclaveIdentityJsonObj {
    string identityStr;
    bytes signature;
}

/// @notice TCB info JSON object
struct TcbInfoJsonObj {
    string tcbInfoStr;
    bytes signature;
}

/// @notice Enclave ID types
enum EnclaveId {
    QE,
    QVE,
    TD_QE
}

/// @notice TCB status for enclave identity
enum EnclaveIdTcbStatus {
    SGX_ENCLAVE_REPORT_ISVSVN_NOT_SUPPORTED,
    OK,
    SGX_ENCLAVE_REPORT_ISVSVN_REVOKED,
    SGX_ENCLAVE_REPORT_ISVSVN_OUT_OF_DATE
}

/// @notice TCB entry in identity object
struct Tcb {
    uint16 isvsvn;
    uint256 dateTimestamp;
    EnclaveIdTcbStatus status;
}

/// @notice Full identity object - must match the original struct layout for ABI decoding
struct IdentityObj {
    EnclaveId id;
    uint32 version;
    uint64 issueDateTimestamp;
    uint64 nextUpdateTimestamp;
    uint32 tcbEvaluationDataNumber;
    bytes4 miscselect;
    bytes4 miscselectMask;
    bytes16 attributes;
    bytes16 attributesMask;
    bytes32 mrsigner;
    uint16 isvprodid;
    Tcb[] tcb;
}

/// @notice Interface for EnclaveIdentityHelper
interface IEnclaveIdentityHelper {
    function parseIdentityString(string calldata identityStr)
        external
        pure
        returns (IdentityObj memory identity, string memory tcbLevelsString);
}

/// @notice Interface for AutomataEnclaveIdentityDao
interface IAutomataEnclaveIdentityDao {
    function upsertEnclaveIdentity(
        uint256 id,
        uint256 version,
        EnclaveIdentityJsonObj calldata identityJson
    )
        external;
}

/// @notice Interface for FmspcTcbDao
interface IFmspcTcbDao {
    function upsertFmspcTcb(TcbInfoJsonObj calldata tcbInfoJson) external;
}
