//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuoteVerifier} from "./interfaces/IQuoteVerifier.sol";
import {BELE} from "./utils/BELE.sol";
import "./types/Constants.sol";
import {Header} from "./types/CommonStruct.sol";

import {Ownable} from "solady/auth/Ownable.sol";
import {EnumerableSet} from "openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// ZK-Coprocessor imports:
// NOTE (taiko vendoring): upstream imports these from the `risc0/` and `@sp1-contracts/`
// packages. They are vendored locally under ./zk/{risc0,sp1} to avoid adding remappings that
// collide with taiko-mono's existing risc0/sp1 remappings. The ZK route is unused by taiko
// (on-chain SGX attestation only); the interfaces are byte-compatible with upstream.
import {IRiscZeroVerifier} from "./zk/risc0/IRiscZeroVerifier.sol";
import {ISP1Verifier} from "./zk/sp1/ISP1Verifier.sol";
import {IPicoVerifier} from "./zk/pico/interfaces/IPicoVerifier.sol";

enum ZkCoProcessorType {
    // if the ZkCoProcessorType is included as None in the AttestationSubmitted event log
    // it indicates that the attestation of the DCAP quote is executed entirely on-chain
    None,
    RiscZero,
    Succinct,
    Pico
}

/**
 * @title ZK Co-Processor Configuration Object
 * @param latestDcapProgramIdentifier - This is the most up-to-date identifier of the ZK Program, required for
 * verification
 * @param defaultZkVerifier - Points to the address of a default ZK Verifier contract. Ideally
 * this should be pointing to a universal verifier, that may support multiple proof types and/or versions.
 */
struct ZkCoProcessorConfig {
    bytes32 latestDcapProgramIdentifier;
    address defaultZkVerifier;
}

/**
 * @title DCAP Attestation Entrypoint Base contract
 * @notice Provides full implementation of both on-chain and ZK DCAP Verification
 */
abstract contract AttestationEntrypointBase is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // use this constant to indicate that the ZK Route has been frozen
    address constant FROZEN = address(0xdead);

    error ZK_Route_Frozen(ZkCoProcessorType zkCoProcessor, bytes4 selector);
    error Cannot_Remove_ProgramIdentifier(ZkCoProcessorType zkCoProcessor, bytes32 identifier);

    mapping(ZkCoProcessorType => ZkCoProcessorConfig) _zkConfig;
    mapping(ZkCoProcessorType => EnumerableSet.Bytes32Set) _programIdConfig;
    mapping(ZkCoProcessorType => mapping(bytes4 selector => address zkVerifier)) _zkVerifierConfig;

    mapping(uint16 quoteVersion => IQuoteVerifier verifier) public quoteVerifiers;

    event AttestationSubmitted(bool success, ZkCoProcessorType verifierType, bytes output);
    event QuoteVerifierUpdated(uint16 indexed version);
    event ZkCoProcessorUpdated(ZkCoProcessorType indexed zkCoProcessor, bytes32 programIdentifier, address zkVerifier);

    event ZkProgramIdentifierRemoved(ZkCoProcessorType indexed zkCoProcessor, bytes32 programIdentifier);
    event ZkRouteAdded(ZkCoProcessorType indexed zkCoProcessor, bytes4 selector, address zkVerifier);
    event ZkRouteFrozen(ZkCoProcessorType indexed zkCoProcessor, bytes4 selector);

    constructor(address owner) {
        _initializeOwner(owner);
    }

    modifier noneZkConfigCheck(ZkCoProcessorType zkCoProcessor) {
        require(zkCoProcessor != ZkCoProcessorType.None, "Cannot use None ZK Co-Processor");
        _;
    }

    /**
     * @notice Sets the QuoteVerifier contract for specific DCAP quote version
     * @param verifier - the address of a version-specific QuoteVerifier contract
     */
    function setQuoteVerifier(address verifier) external onlyOwner {
        IQuoteVerifier quoteVerifier = IQuoteVerifier(verifier);
        uint16 version = quoteVerifier.quoteVersion();
        quoteVerifiers[version] = quoteVerifier;

        emit QuoteVerifierUpdated(version);
    }

    /**
     * @notice Sets the ZK Configuration for the given ZK Co-Processor
     */
    function setZkConfiguration(ZkCoProcessorType zkCoProcessor, ZkCoProcessorConfig memory config)
        external
        onlyOwner
        noneZkConfigCheck(zkCoProcessor)
    {
        _zkConfig[zkCoProcessor] = config;
        _programIdConfig[zkCoProcessor].add(config.latestDcapProgramIdentifier);
        emit ZkCoProcessorUpdated(zkCoProcessor, config.latestDcapProgramIdentifier, config.defaultZkVerifier);
    }

    /**
     * @notice Updates the DCAP Program Identifier for the specified ZK Co-Processor
     */
    function updateProgramIdentifier(ZkCoProcessorType zkCoProcessor, bytes32 identifier)
        external
        onlyOwner
        noneZkConfigCheck(zkCoProcessor)
    {
        require(identifier != bytes32(0), "Program identifier cannot be zero");
        ZkCoProcessorConfig storage config = _zkConfig[zkCoProcessor];
        require(config.latestDcapProgramIdentifier != identifier, "Program identifier is already the latest");
        config.latestDcapProgramIdentifier = identifier;
        _programIdConfig[zkCoProcessor].add(identifier);
        emit ZkCoProcessorUpdated(zkCoProcessor, identifier, config.defaultZkVerifier);
    }

    /**
     * @notice Deprecates a DCAP Program Identifier for the specified ZK Co-Processor
     */
    function removeProgramIdentifier(ZkCoProcessorType zkCoProcessor, bytes32 identifier)
        external
        onlyOwner
        noneZkConfigCheck(zkCoProcessor)
    {
        require(_programIdConfig[zkCoProcessor].contains(identifier), "Program identifier does not exist");
        // To remove the latest program identifier
        // you must first update it with a newer program identifier
        if (_zkConfig[zkCoProcessor].latestDcapProgramIdentifier == identifier) {
            revert Cannot_Remove_ProgramIdentifier(zkCoProcessor, identifier);
        }
        _programIdConfig[zkCoProcessor].remove(identifier);
        emit ZkProgramIdentifierRemoved(zkCoProcessor, identifier);
    }

    /**
     * @notice Adds a verifier for a specific ZK Route to override the default ZK Verifier
     */
    function addVerifyRoute(ZkCoProcessorType zkCoProcessor, bytes4 selector, address verifier)
        external
        onlyOwner
        noneZkConfigCheck(zkCoProcessor)
    {
        require(verifier != address(0), "ZK Verifier cannot be zero address");
        if (_zkVerifierConfig[zkCoProcessor][selector] == FROZEN) {
            revert ZK_Route_Frozen(zkCoProcessor, selector);
        }
        _zkVerifierConfig[zkCoProcessor][selector] = verifier;
        emit ZkRouteAdded(zkCoProcessor, selector, verifier);
    }

    /**
     * @notice PERMANENTLY freezes a ZK Route
     */
    function freezeVerifyRoute(ZkCoProcessorType zkCoProcessor, bytes4 selector)
        external
        onlyOwner
        noneZkConfigCheck(zkCoProcessor)
    {
        address verifier = _zkVerifierConfig[zkCoProcessor][selector];
        if (verifier == FROZEN) {
            revert ZK_Route_Frozen(zkCoProcessor, selector);
        }
        _zkVerifierConfig[zkCoProcessor][selector] = FROZEN;
        emit ZkRouteFrozen(zkCoProcessor, selector);
    }

    /**
     * @param zkCoProcessorType 1 - RiscZero, 2 - Succinct... etc.
     * @return this returns the latest DCAP program identifier for the specified ZK Co-processor
     */
    function programIdentifier(ZkCoProcessorType zkCoProcessorType) public view returns (bytes32) {
        return _zkConfig[zkCoProcessorType].latestDcapProgramIdentifier;
    }

    /**
     * @param zkCoProcessorType 1 - RiscZero, 2 - Succinct... etc.
     * @return this returns the list of all DCAP program identifiers for the specified ZK Co-processor
     */
    function programIdentifiers(ZkCoProcessorType zkCoProcessorType) public view returns (bytes32[] memory) {
        return _programIdConfig[zkCoProcessorType].values();
    }

    /**
     * @notice gets the default (universal) ZK verifier for the provided ZK Co-processor
     */
    function zkVerifier(ZkCoProcessorType zkCoProcessorType) public view returns (address) {
        return _zkConfig[zkCoProcessorType].defaultZkVerifier;
    }

    /**
     * @notice gets the specific ZK Verifier for the provided ZK Co-processor and proof selector
     * @notice this function will revert if the provided selector has been frozen
     * @notice otherwise, if a specific ZK verifier is not configured for the provided selector
     * @notice it will return the default ZK verifier
     */
    function zkVerifier(ZkCoProcessorType zkCoProcessorType, bytes4 selector) public view returns (address) {
        address verifier = _zkVerifierConfig[zkCoProcessorType][selector];
        if (verifier == FROZEN) {
            revert ZK_Route_Frozen(zkCoProcessorType, selector);
        } else if (verifier == address(0)) {
            return zkVerifier(zkCoProcessorType);
        } else {
            return verifier;
        }
    }

    /**
     * @notice full on-chain verification for an attestation
     * @param rawQuote - Intel DCAP Quote serialized in raw bytes
     * @param tcbEvalNumber - TCB Evaluation Data Number, pass 0 to use "update = standard" collateral
     * @return success - whether the quote has been successfully verified or not
     * @return output - the output upon completion of verification. The output data may require post-processing by the consumer.
     * For verification failures, the output is simply a UTF-8 encoded string, describing the reason for failure.
     * @dev can directly type-cast the failed output as a string
     */
    function _verifyAndAttestOnChain(bytes calldata rawQuote, uint32 tcbEvalNumber)
        internal
        returns (bool success, bytes memory output)
    {
        // Parse the header
        Header memory header;
        (success, header) = _parseQuoteHeader(rawQuote);
        if (!success) {
            return (false, bytes("Quote length is less than Header length"));
        }

        IQuoteVerifier quoteVerifier = quoteVerifiers[header.version];
        if (address(quoteVerifier) == address(0)) {
            return (false, bytes("Unsupported quote version"));
        }

        // We found a supported version, begin verifying the quote
        // Note: The quote header cannot be trusted yet, it will be validated by the Verifier library
        (success, output) = quoteVerifier.verifyQuote(header, rawQuote, tcbEvalNumber);

        emit AttestationSubmitted(success, ZkCoProcessorType.None, output);
    }

    /**
     * @notice verifies an attestation using SNARK proofs
     *
     * @param zkCoprocessor - Specify ZK Co-Processor
     * @param identifier - The identifier of the DCAP ZK Program that is used to generate proofs
     * @param output - The output of the Guest program, this includes:
     * - uint16 VerifiedOutput bytes length
     * - VerifiedOutput struct
     * - uint64 timestamp (in seconds)
     * - FMSPC TCB Info content hash
     * - QEIdentity content hash
     * - RootCA hash
     * - TCB Signing CA hash
     * - Root CRL hash
     * - Platform or Processor CRL hash
     * @param proofBytes - The encoded cryptographic proof (i.e. SNARK).
     * @param tcbEvalNumber - TCB Evaluation Data Number, pass 0 to use "update = standard" collateral
     */
    function _verifyAndAttestWithZKProof(
        ZkCoProcessorType zkCoprocessor,
        bytes32 identifier,
        bytes calldata output,
        bytes calldata proofBytes,
        uint32 tcbEvalNumber
    ) internal returns (bool success, bytes memory verifiedOutput) {
        ZkCoProcessorConfig memory zkConfig = _zkConfig[zkCoprocessor];

        // First, determine the validity of program ID and pick the appropriate ZK Verifier
        if (!_programIdConfig[zkCoprocessor].contains(identifier)) {
            return (false, bytes("Invalid ZK Program Identifier"));
        }

        bytes4 selector = bytes4(proofBytes[0:4]);
        address verifier = _zkVerifierConfig[zkCoprocessor][selector];

        if (verifier == FROZEN) {
            return (false, bytes("ZK Route has been frozen"));
        }

        if (verifier == address(0)) {
            verifier = zkConfig.defaultZkVerifier;
        }

        // the verifier must be set at this point,
        // otherwise we cannot verify the proof
        if (verifier == address(0)) {
            return (false, bytes("ZK Verifier is not configured"));
        }

        if (zkCoprocessor == ZkCoProcessorType.RiscZero) {
            IRiscZeroVerifier(verifier).verify(proofBytes, identifier, sha256(output));
        } else if (zkCoprocessor == ZkCoProcessorType.Succinct) {
            ISP1Verifier(verifier).verifyProof(identifier, output, proofBytes);
        } else if (zkCoprocessor == ZkCoProcessorType.Pico) {
            IPicoVerifier(verifier).verifyPicoProof(
                identifier,
                output,
                abi.decode(proofBytes[4:], (uint256[8]))
            );
        } else {
            return (false, bytes("Unknown ZK Co-Processor"));
        }

        // verifies the output
        uint16 version = uint16(bytes2(output[2:4]));
        IQuoteVerifier quoteVerifier = quoteVerifiers[version];
        if (address(quoteVerifier) == address(0)) {
            return (false, bytes("Unsupported quote version"));
        }
        (success, verifiedOutput) = quoteVerifier.verifyZkOutput(output, tcbEvalNumber);

        emit AttestationSubmitted(success, zkCoprocessor, verifiedOutput);
    }

    /**
     * @notice Parses the header to get basic information about the quote, such as the version, TEE types etc.
     */
    function _parseQuoteHeader(bytes calldata rawQuote) private pure returns (bool success, Header memory header) {
        success = rawQuote.length >= HEADER_LENGTH;
        if (success) {
            uint16 version = uint16(BELE.leBytesToBeUint(rawQuote[0:2]));
            bytes4 teeType = bytes4(rawQuote[4:8]);
            bytes2 attestationKeyType = bytes2(rawQuote[2:4]);
            bytes2 qeSvn = bytes2(rawQuote[8:10]);
            bytes2 pceSvn = bytes2(rawQuote[10:12]);
            bytes16 qeVendorId = bytes16(rawQuote[12:28]);
            bytes20 userData = bytes20(rawQuote[28:48]);

            header = Header({
                version: version,
                attestationKeyType: attestationKeyType,
                teeType: teeType,
                qeSvn: qeSvn,
                pceSvn: pceSvn,
                qeVendorId: qeVendorId,
                userData: userData
            });
        }
    }
}
