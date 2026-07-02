// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IDcapAttestation } from "./IDcapAttestation.sol";
import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title SgxVerifier
/// @notice Abstract base that verifies SGX signature proofs onchain using attested SGX instances.
/// Each instance is registered via remote attestation and can verify proofs until expiry. The
/// TCB-status acceptance policy is left abstract so that per-network subclasses define it (the
/// strict mainnet policy must remain the secure default).
/// @dev Side-channel protection is achieved through mandatory instance expiry (INSTANCE_EXPIRY),
/// requiring periodic re-attestation with new keypairs.
/// @custom:security-contact security@taiko.xyz
abstract contract SgxVerifier is IProofVerifier, Ownable2Step, ReentrancyGuard {
    /// @dev Each public-private key pair (Ethereum address) is generated within
    /// the SGX program when it boots up. The off-chain remote attestation
    /// ensures the validity of the program hash and has the capability of
    /// bootstrapping the network with trustworthy instances.
    /// @dev `mrEnclave`, `mrSigner` and `policyVersion` let `verifyProof` re-check the *current*
    /// enclave policy at proof time, so revoking trust in a measurement/signer (or changing/removing
    /// its policy) also stops its already-registered instances — a registration-time-only check
    /// cannot.
    struct Instance {
        // The instance's ECDSA address (SGX signing key); the unit of identity for proof signatures.
        address addr;
        // Unix time from which the instance may verify proofs (after the registration validity delay
        // for non-owner registrations); it stays valid until `validSince + INSTANCE_EXPIRY`.
        uint64 validSince;
        // The per-MRENCLAVE policy version in force when this instance registered. `verifyProof`
        // rejects the instance once the subclass's current version for `mrEnclave` no longer matches,
        // so editing — or removing and re-adding — that policy revokes instances registered under the
        // old policy. Zero for owner-added instances and subclasses with no versioned policy.
        uint32 policyVersion;
        // The attested application-enclave measurement (MRENCLAVE) this instance registered with, or
        // `bytes32(0)` for an owner-added instance (`addInstances`) that carries no attestation and is
        // therefore exempt from the proof-time policy re-check.
        bytes32 mrEnclave;
        // The attested enclave signer (MRSIGNER) this instance registered with (`bytes32(0)` for
        // owner-added instances). Re-checked against the trusted-MRSIGNER allowlist at proof time
        // while the local report check is enforced, so untrusting a signer revokes its instances.
        bytes32 mrSigner;
    }

    /// @notice The expiry time for the SGX instance (3 months).
    uint64 public constant INSTANCE_EXPIRY = 90 days;

    /// @dev SGX ATTRIBUTES.FLAGS bits that a production application enclave must never set. In DCAP
    /// quote bytes the 16-byte ATTRIBUTES field is FLAGS (low 8 bytes, little-endian) followed by
    /// XFRM, so these FLAGS bits live in the first byte. Enforced uniformly on every network (it is
    /// NOT part of the per-network policy): such an enclave must never be trusted on-chain.
    /// DEBUG(0x02): the host can read/write enclave memory, so the in-enclave signing key is
    /// extractable.
    /// PROVISION_KEY(0x10): the enclave can derive platform-identifying provisioning keys.
    /// EINITTOKEN_KEY(0x20): the enclave can derive the launch-token key, a launch-enclave-only
    /// privilege an application enclave must never hold.
    /// Subclasses may pin the remaining bits per-MRENCLAVE via `_validateEnclaveAttributes`.
    bytes16 internal constant SGX_FORBIDDEN_ATTRIBUTE_MASK =
        bytes16(0x32000000000000000000000000000000);
    /// @dev DEBUG bit (bit 1) of the little-endian SGX ATTRIBUTES flags. A subset of
    /// `SGX_FORBIDDEN_ATTRIBUTE_MASK`, checked separately so a debug enclave reverts with the
    /// dedicated `SGX_DEBUG_ENCLAVE` error (the migration's headline security guard).
    uint8 private constant SGX_FLAGS_DEBUG = 0x02;

    /// @dev Field offsets within the Automata DCAP `Output` header: quoteVersion (BE uint16) at 0,
    /// quoteBodyType (BE uint16) at 2, tcbStatus (1 byte) at 4, fmspc (6 bytes) at 5; the quote
    /// body follows at offset 11 (= 2 + 2 + 1 + 6).
    uint256 private constant OUTPUT_VERSION_OFFSET = 0;
    uint256 private constant OUTPUT_BODY_TYPE_OFFSET = 2;
    uint256 private constant OUTPUT_TCB_STATUS_OFFSET = 4;
    uint256 private constant OUTPUT_BODY_OFFSET = 11;
    /// @dev `quoteBodyType` value identifying an SGX Enclave Report body.
    uint8 private constant SGX_QUOTE_BODY_TYPE = 1;
    /// @dev Quote version handled by this verifier (Intel DCAP V3 / SGX).
    uint8 private constant SGX_QUOTE_VERSION = 3;
    /// @dev Length of an Intel SGX quote header.
    uint256 private constant HEADER_LENGTH = 48;
    /// @dev Length of an SGX Enclave Report body.
    uint256 private constant ENCLAVE_REPORT_LENGTH = 384;
    /// @dev MRENCLAVE offset within the raw quote (header + enclave-report offset 64).
    uint256 private constant MRENCLAVE_OFFSET = HEADER_LENGTH + 64;
    /// @dev MRSIGNER offset within the raw quote (header + enclave-report offset 128).
    uint256 private constant MRSIGNER_OFFSET = HEADER_LENGTH + 128;
    /// @dev reportData offset within the raw quote (header + enclave-report offset 320).
    uint256 private constant REPORT_DATA_OFFSET = HEADER_LENGTH + 320;
    /// @dev `attributes` offset within the raw quote (header + enclave-report offset 48).
    uint256 private constant ATTRIBUTES_OFFSET = HEADER_LENGTH + 48;

    uint64 public immutable taikoChainId;
    address public immutable automataDcapAttestation;

    /// @notice The address authorized to register SGX instances via `registerInstance`.
    /// @dev If set to a non-zero address, only this address may call `registerInstance`.
    /// If set to `address(0)`, `registerInstance` is permissionless and callable by anyone.
    address public immutable registrar;

    /// @dev For gas savings, we assign each SGX instance with an ID to minimize storage operations.
    uint256 public nextInstanceId;

    /// @dev One SGX instance is uniquely identified (on-chain) by its ECDSA public key
    /// (or rather ethereum address). The instance address remains valid for INSTANCE_EXPIRY
    /// duration (90 days) to protect against side-channel attacks through forced key expiry.
    /// After expiry, the instance must be re-attested and registered with a new address.
    mapping(uint256 instanceId => Instance instance) public instances;

    /// @dev One address shall be registered (during attestation) only once, otherwise it could
    /// bypass this contract's expiry check by always registering with the same attestation and
    /// getting multiple valid instanceIds.
    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;

    /// @dev Per-MRENCLAVE state, packed into a single slot so `verifyProof` reads the allowlist flag
    /// and the policy version in one SLOAD.
    struct MrEnclaveState {
        // Whether this MRENCLAVE is on the trusted allowlist (set via `setMrEnclave`, enforced at
        // registration and proof time while `checkLocalEnclaveReport` is on).
        bool trusted;
        // The current per-MRENCLAVE policy generation, maintained by versioned subclasses
        // (`SecureSgxVerifier`); always 0 in the base / non-versioned subclasses. `verifyProof`
        // rejects an instance whose recorded `policyVersion` no longer equals this value.
        uint32 policyVersion;
    }

    /// @dev Relocated from the replaced AutomataDcapV3Attestation contract. The new Automata DCAP
    /// entrypoint verifies quote authenticity and TCB status but does NOT allowlist the application
    /// enclave's identity, so the trusted MRENCLAVE/MRSIGNER policy is enforced here to preserve the
    /// pre-migration security model. Enabled by default (set in the constructor); toggle off with
    /// toggleLocalReportCheck().
    bool public checkLocalEnclaveReport;
    /// @dev Trusted-MRENCLAVE allowlist + policy version, co-located per measurement. Exposed via the
    /// `trustedUserMrEnclave` view (allowlist flag) and, in versioned subclasses, a policy-version
    /// view; `internal` so those subclasses can maintain the version in the same slot.
    mapping(bytes32 mrEnclave => MrEnclaveState state) internal mrEnclaveState;
    mapping(bytes32 mrSigner => bool trusted) public trustedUserMrSigner;

    /// @notice Emitted when a new SGX instance is added to the registry.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    /// @param replaced Reserved for future use (always zero address).
    /// @param validSince The time since the instance is valid.
    event InstanceAdded(
        uint256 indexed id, address indexed instance, address indexed replaced, uint256 validSince
    );

    /// @notice Emitted when an SGX instance is deleted from the registry.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    event InstanceDeleted(uint256 indexed id, address indexed instance);

    /// @notice Emitted when an SGX instance's remaining validity delay is cancelled.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    /// @param validSince The new (current) time from which the instance is valid.
    event InstancePromoted(uint256 indexed id, address indexed instance, uint64 validSince);

    /// @notice Emitted when a trusted MRENCLAVE value is updated.
    /// @param mrEnclave The MRENCLAVE value.
    /// @param trusted Whether the value is trusted.
    event MrEnclaveUpdated(bytes32 indexed mrEnclave, bool trusted);

    /// @notice Emitted when a trusted MRSIGNER value is updated.
    /// @param mrSigner The MRSIGNER value.
    /// @param trusted Whether the value is trusted.
    event MrSignerUpdated(bytes32 indexed mrSigner, bool trusted);

    /// @notice Emitted when enforcement of the local enclave identity allowlist is toggled.
    /// @param checkLocalEnclaveReport Whether the allowlist is enforced.
    event LocalReportCheckToggled(bool checkLocalEnclaveReport);

    error SGX_ALREADY_ATTESTED();
    error SGX_DEBUG_ENCLAVE();
    error SGX_FORBIDDEN_ATTRIBUTES();
    error SGX_INVALID_ATTESTATION();
    error SGX_INVALID_INSTANCE();
    error SGX_INSTANCE_NOT_DELAYED();
    error SGX_INVALID_PROOF();
    error SGX_INVALID_CHAIN_ID();
    error SGX_NOT_REGISTRAR();

    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    ) {
        require(_taikoChainId != 0, SGX_INVALID_CHAIN_ID());
        taikoChainId = _taikoChainId;
        automataDcapAttestation = _automataDcapAttestation;
        registrar = _registrar;

        // Enforce the trusted MRENCLAVE/MRSIGNER allowlist by default (fail-closed): until the owner
        // trusts at least one MRENCLAVE and MRSIGNER, no instance can register. Disable with
        // toggleLocalReportCheck() if the Automata entrypoint alone is considered sufficient.
        checkLocalEnclaveReport = true;

        _transferOwnership(_owner);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param _instances The address array of trusted SGX instances.
    /// @return The respective instanceId array per addresses.
    function addInstances(address[] calldata _instances)
        external
        onlyOwner
        returns (uint256[] memory)
    {
        // Owner-added instances carry no attested measurement, so they record no MRENCLAVE/MRSIGNER/
        // policy version and are exempt from the proof-time enclave-policy re-check.
        return _addInstances(_instances, true, bytes32(0), bytes32(0), 0);
    }

    /// @notice Deletes SGX instances from the registry.
    /// @param _ids The ids array of SGX instances.
    function deleteInstances(uint256[] calldata _ids) external onlyOwner {
        uint256 size = _ids.length;
        for (uint256 i; i < size; ++i) {
            uint256 idx = _ids[i];

            require(instances[idx].addr != address(0), SGX_INVALID_INSTANCE());

            emit InstanceDeleted(idx, instances[idx].addr);

            delete instances[idx];
        }
    }

    /// @notice Cancels the remaining validity delay on already-attested instances, making them
    /// usable immediately.
    /// @dev Recovery path for a front-run permissionless registration: because `registerInstance`
    /// is permissionless (when no `registrar` is set) and grants the instant-valid path only to the
    /// owner, anyone can copy a pending quote from the mempool and register it first, forcing the
    /// instance through the validity delay; the replay guard then blocks the owner from
    /// re-registering the same enclave key. The instance still belongs to the attested enclave, so
    /// the owner can adopt it here instead of provisioning a new keypair. Owner-only, so it grants no
    /// power beyond `addInstances` (which already registers instant-valid). It only ever moves
    /// `validSince` earlier, and only for a not-yet-active instance, so it can never extend an
    /// instance's lifetime or revive an expired one. A duplicate id within `_ids` reverts
    /// `SGX_INSTANCE_NOT_DELAYED` on its second occurrence (the first already set `validSince` to
    /// now), which is harmless — the owner controls the input.
    /// @param _ids The ids array of SGX instances to promote.
    function promoteInstances(uint256[] calldata _ids) external onlyOwner {
        uint64 nowTs = uint64(block.timestamp);
        uint256 size = _ids.length;
        for (uint256 i; i < size; ++i) {
            uint256 idx = _ids[i];
            Instance storage inst = instances[idx];

            require(inst.addr != address(0), SGX_INVALID_INSTANCE());
            // Only a still-delayed (not-yet-active) instance can be promoted. This both makes the
            // operation a pure delay cancellation and prevents it from pushing an active instance's
            // expiry (`validSince + INSTANCE_EXPIRY`) further into the future.
            require(inst.validSince > nowTs, SGX_INSTANCE_NOT_DELAYED());

            inst.validSince = nowTs;
            emit InstancePromoted(idx, inst.addr, nowTs);
        }
    }

    /// @notice Sets whether a given MRENCLAVE is trusted for instance registration.
    /// @param _mrEnclave The MRENCLAVE value.
    /// @param _trusted Whether the value is trusted.
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external onlyOwner {
        mrEnclaveState[_mrEnclave].trusted = _trusted;
        emit MrEnclaveUpdated(_mrEnclave, _trusted);
    }

    /// @notice Returns whether a given MRENCLAVE is on the trusted allowlist.
    /// @param _mrEnclave The MRENCLAVE value.
    /// @return Whether the MRENCLAVE is trusted.
    function trustedUserMrEnclave(bytes32 _mrEnclave) external view returns (bool) {
        return mrEnclaveState[_mrEnclave].trusted;
    }

    /// @notice Sets whether a given MRSIGNER is trusted for instance registration.
    /// @param _mrSigner The MRSIGNER value.
    /// @param _trusted Whether the value is trusted.
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external onlyOwner {
        trustedUserMrSigner[_mrSigner] = _trusted;
        emit MrSignerUpdated(_mrSigner, _trusted);
    }

    /// @notice Toggles enforcement of the trusted MRENCLAVE/MRSIGNER allowlist.
    function toggleLocalReportCheck() external onlyOwner {
        checkLocalEnclaveReport = !checkLocalEnclaveReport;
        emit LocalReportCheckToggled(checkLocalEnclaveReport);
    }

    /// @notice Adds an SGX instance after remote attestation is verified fully on-chain.
    /// @dev Migrated to the Automata DCAP attestation entrypoint
    /// (`IDcapAttestation.verifyAndAttestOnChain`), which consumes a raw quote and reads Intel
    /// collateral from on-chain PCCS. The trusted MRENCLAVE/MRSIGNER allowlist and the TCB-status
    /// acceptance policy are enforced here (previously in AutomataDcapV3Attestation).
    /// @dev A non-owner (permissionless or registrar) registration is subject to the validity
    /// delay; an owner-submitted registration is as trusted as `addInstances` and takes effect
    /// immediately.
    /// @param _rawQuote The raw Intel DCAP v3 (SGX) attestation quote.
    /// @return The respective instanceId.
    function registerInstance(bytes calldata _rawQuote) external nonReentrant returns (uint256) {
        // When a registrar is configured, only it may register instances; otherwise registration
        // is permissionless.
        require(registrar == address(0) || msg.sender == registrar, SGX_NOT_REGISTRAR());

        // Fail fast with a clear error if this verifier was deployed without an attestation
        // entrypoint (e.g. a dummy-verifier deployment).
        require(automataDcapAttestation != address(0), SGX_INVALID_ATTESTATION());

        // Reject anything too short to hold a header + SGX enclave report body before the
        // expensive attestation call. This also guarantees every fixed-offset slice below
        // (attributes, MRENCLAVE, MRSIGNER, reportData) is in bounds.
        require(
            _rawQuote.length >= HEADER_LENGTH + ENCLAVE_REPORT_LENGTH, SGX_INVALID_ATTESTATION()
        );

        // The Taiko-owned attestation entrypoint runs feeless, so forward zero value; this function
        // is non-payable, so stray ETH can never be sent here or trapped in the verifier.
        (bool verified, bytes memory output) =
            IDcapAttestation(automataDcapAttestation).verifyAndAttestOnChain{ value: 0 }(_rawQuote);
        require(verified, SGX_INVALID_ATTESTATION());

        // `output` is the serialized Automata `Output`; require a full SGX enclave report body.
        require(
            output.length >= OUTPUT_BODY_OFFSET + ENCLAVE_REPORT_LENGTH, SGX_INVALID_ATTESTATION()
        );
        // quoteVersion is a big-endian uint16 at output[0:2]; this verifier handles V3 only.
        require(
            uint8(output[OUTPUT_VERSION_OFFSET]) == 0
                && uint8(output[OUTPUT_VERSION_OFFSET + 1]) == SGX_QUOTE_VERSION,
            SGX_INVALID_ATTESTATION()
        );
        // quoteBodyType is a big-endian uint16 at output[2:4]; 1 == SGX Enclave Report.
        require(
            uint8(output[OUTPUT_BODY_TYPE_OFFSET]) == 0
                && uint8(output[OUTPUT_BODY_TYPE_OFFSET + 1]) == SGX_QUOTE_BODY_TYPE,
            SGX_INVALID_ATTESTATION()
        );
        // Reject quotes whose platform TCB is not up to date (see isTcbStatusAccepted).
        require(
            isTcbStatusAccepted(uint8(output[OUTPUT_TCB_STATUS_OFFSET])), SGX_INVALID_ATTESTATION()
        );

        // Bind the fields read from the raw quote below (DEBUG attributes, MRENCLAVE/MRSIGNER,
        // reportData) to the enclave report the entrypoint actually authenticated. Automata's
        // verifier copies the raw enclave report into the Output body verbatim
        // (output[OUTPUT_BODY_OFFSET : +ENCLAVE_REPORT_LENGTH] == _rawQuote enclave report) and
        // verifies its integrity, so requiring byte-equality proves those fields come from verified
        // bytes — not attacker-controlled data outside the authenticated region. Reading the body
        // from `output` (memory) needs assembly; the prior output.length check makes the region
        // safe to hash.
        bytes32 verifiedBodyHash;
        assembly {
            verifiedBodyHash := keccak256(
                add(add(output, 0x20), OUTPUT_BODY_OFFSET),
                ENCLAVE_REPORT_LENGTH
            )
        }
        require(
            verifiedBodyHash
                == keccak256(_rawQuote[HEADER_LENGTH:HEADER_LENGTH + ENCLAVE_REPORT_LENGTH]),
            SGX_INVALID_ATTESTATION()
        );

        // Reject DEBUG-mode enclaves: a debug enclave's memory (including the in-enclave signing
        // key recorded in reportData) is readable and writable by the host, so its quotes must
        // never be trusted on-chain. SECURITY-CRITICAL: omitting this DEBUG-attribute check lets a
        // host-controlled debug enclave forge SGX proofs (a gap previously exploited in production);
        // this guard must never be removed or weakened. DEBUG is bit 1 of the SGX ATTRIBUTES flags;
        // the flags are little-endian, so the bit lives in the low byte of the 16-byte `attributes`
        // field at enclave-report offset 48 (raw-quote offset HEADER_LENGTH + 48).
        require((uint8(_rawQuote[ATTRIBUTES_OFFSET]) & SGX_FLAGS_DEBUG) == 0, SGX_DEBUG_ENCLAVE());

        // Read the authenticated MRENCLAVE, MRSIGNER and full 16-byte ATTRIBUTES (FLAGS || XFRM) from
        // the verified enclave report for the attribute policies below; all are bound to the report by
        // the body-hash check above. MRENCLAVE and MRSIGNER are recorded on the instance so
        // `verifyProof` can re-check the current allowlist/policy at proof time.
        bytes32 mrEnclave = bytes32(_rawQuote[MRENCLAVE_OFFSET:MRENCLAVE_OFFSET + 32]);
        bytes32 mrSigner = bytes32(_rawQuote[MRSIGNER_OFFSET:MRSIGNER_OFFSET + 32]);
        bytes16 attributes = bytes16(_rawQuote[ATTRIBUTES_OFFSET:ATTRIBUTES_OFFSET + 16]);

        // Universal forbidden-attribute floor, enforced on every network (DEBUG / PROVISION_KEY /
        // EINITTOKEN_KEY). DEBUG is also rejected above with a dedicated error; the remaining bits
        // are caught here so even the lenient devnet verifier can never admit a provisioning or
        // launch enclave.
        require(attributes & SGX_FORBIDDEN_ATTRIBUTE_MASK == bytes16(0), SGX_FORBIDDEN_ATTRIBUTES());

        // Per-network enclave-identity policy on top of the universal floor. The strict mainnet
        // subclass pins the full ATTRIBUTES profile per allowlisted MRENCLAVE; the base/devnet
        // implementation is a no-op. It returns the policy version to bind to the instance so
        // `verifyProof` can revoke the instance if that policy is later changed or removed (0 when the
        // subclass has no versioned policy).
        uint32 policyVersion = _validateEnclaveAttributes(mrEnclave, attributes);

        if (checkLocalEnclaveReport) {
            require(
                mrEnclaveState[mrEnclave].trusted && trustedUserMrSigner[mrSigner],
                SGX_INVALID_ATTESTATION()
            );
        }

        // The SGX program embeds its freshly generated instance address in the first 20 bytes of
        // the report's reportData; we trust the off-chain prover to do so (unchanged from the
        // pre-migration design). A zero address is rejected by _addInstances, and the value is
        // bound to the verified enclave report by the body-hash check above.
        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_rawQuote[REPORT_DATA_OFFSET:REPORT_DATA_OFFSET + 20]));

        // An owner-submitted registration is as trusted as `addInstances`, so it skips the validity
        // delay; permissionless (and registrar) registrations remain delayed. The attested MRENCLAVE,
        // MRSIGNER and policy version are recorded so `verifyProof` can re-check the current enclave
        // policy and allowlist.
        return
            _addInstances(addresses, msg.sender == owner(), mrEnclave, mrSigner, policyVersion)[0];
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _aggregatedProvingHash,
        bytes calldata _proof
    )
        external
        view
    {
        require(_proof.length == 89, SGX_INVALID_PROOF());

        uint32 id = uint32(bytes4(_proof[:4]));
        address instance = address(bytes20(_proof[4:24]));
        require(_isInstanceValid(id, instance), SGX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), instance, taikoChainId
        );

        // Verify the signature was created by the registered instance
        bytes memory signature = _proof[24:];
        require(instance == ECDSA.recover(signatureHash, signature), SGX_INVALID_PROOF());
    }

    /// @notice Returns whether a platform TCB status is accepted by this verifier's network policy.
    /// @dev The TCB-status acceptance policy is defined by per-network subclasses. Each subclass
    /// expresses its policy against Automata's `TCBStatus` enum (the same pinned on-chain-pccs
    /// package the attestation entrypoint uses to produce `tcbStatus`), so the on-chain policy and
    /// the entrypoint cannot diverge and a dependency bump that reorders the enum is caught at
    /// compile time. The strict mainnet policy must remain the secure default.
    /// @param _status The TCB status code from the attestation output.
    /// @return Whether the status is accepted.
    function isTcbStatusAccepted(uint8 _status) public pure virtual returns (bool);

    /// @dev Hook for an additional, per-network enclave-identity policy enforced during
    /// `registerInstance`, run after the universal forbidden-attribute floor. The base
    /// implementation is a no-op (the floor is the only attribute check) and is intended only for
    /// non-production (devnet) verifiers; production subclasses MUST override this to pin the full
    /// ATTRIBUTES profile per allowlisted MRENCLAVE. An override MUST revert to reject a
    /// registration. Parameters are the attested application-enclave measurement and its 16-byte
    /// ATTRIBUTES (FLAGS || XFRM) field, both authenticated by the attestation.
    /// @return policyVersion_ The version of the per-MRENCLAVE policy that admitted this registration.
    /// It is recorded on the instance and re-checked in `verifyProof` (via `_isEnclaveStillTrusted`)
    /// so a later policy change or removal revokes the instance. The base returns 0 (no versioned
    /// policy).
    function _validateEnclaveAttributes(
        bytes32,
        bytes16
    )
        internal
        view
        virtual
        returns (uint32 policyVersion_)
    {
        return 0;
    }

    /// @dev Re-evaluates at proof time whether a stored instance's attested enclave is still trusted
    /// under the verifier's *current* policy, so revoking trust in a measurement/signer also stops its
    /// already-registered instances (a registration-time-only check cannot). Owner-added instances
    /// (`addInstances`) carry no attested measurement (`mrEnclave == 0`) and are always trusted; the
    /// owner revokes them with `deleteInstances`. The base re-checks the trusted-MRENCLAVE and
    /// trusted-MRSIGNER allowlist exactly as `registerInstance` did, and only while it is enforced.
    /// Production subclasses override this to additionally require the per-MRENCLAVE policy that gated
    /// registration to still be configured and unchanged (matched by version). Takes the whole stored
    /// `Instance` so subclasses can consult any recorded field without a signature change.
    /// @param _instance The stored instance record being verified.
    /// @return Whether the instance may still verify proofs.
    function _isEnclaveStillTrusted(Instance memory _instance)
        internal
        view
        virtual
        returns (bool)
    {
        if (_instance.mrEnclave == bytes32(0)) return true;
        if (!checkLocalEnclaveReport) return true;
        return
            mrEnclaveState[_instance.mrEnclave].trusted && trustedUserMrSigner[_instance.mrSigner];
    }

    /// @dev The delay applied to a non-owner `registerInstance` registration before the instance
    /// becomes usable, giving off-chain monitoring a window to evict a rogue self-registered instance
    /// (via `deleteInstances`) before it can prove. Owner registrations — `addInstances`, or
    /// `registerInstance` called by the owner — are never delayed. The base applies no delay;
    /// production subclasses override this to return their configured delay (which must not exceed
    /// `INSTANCE_EXPIRY`).
    /// @return The registration validity delay, in seconds.
    function _validityDelay() internal view virtual returns (uint64) {
        return 0;
    }

    function _addInstances(
        address[] memory _instances,
        bool instantValid,
        bytes32 _mrEnclave,
        bytes32 _mrSigner,
        uint32 _policyVersion
    )
        private
        returns (uint256[] memory ids)
    {
        uint256 size = _instances.length;
        ids = new uint256[](size);

        uint64 validSince = uint64(block.timestamp);

        if (!instantValid) {
            validSince += _validityDelay();
        }

        for (uint256 i; i < size; ++i) {
            require(!addressRegistered[_instances[i]], SGX_ALREADY_ATTESTED());

            addressRegistered[_instances[i]] = true;

            require(_instances[i] != address(0), SGX_INVALID_INSTANCE());

            instances[nextInstanceId] =
                Instance(_instances[i], validSince, _policyVersion, _mrEnclave, _mrSigner);
            ids[i] = nextInstanceId;

            emit InstanceAdded(nextInstanceId, _instances[i], address(0), validSince);

            ++nextInstanceId;
        }
    }

    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        require(instance != address(0), SGX_INVALID_INSTANCE());

        Instance memory inst = instances[id];
        require(instance == inst.addr, SGX_INVALID_INSTANCE());

        // Re-check the current enclave policy: an instance whose MRENCLAVE/MRSIGNER trust or policy
        // has since been revoked or changed is rejected even before expiry (revocation, not deletion).
        if (!_isEnclaveStillTrusted(inst)) return false;

        return
            inst.validSince <= block.timestamp
                && block.timestamp <= inst.validSince + INSTANCE_EXPIRY;
    }
}
