// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SgxVerifier } from "./SgxVerifier.sol";
import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";

/// @title SecureSgxVerifier
/// @notice SGX verifier for mainnet/production: the strict TCB-status policy plus a per-MRENCLAVE
/// ATTRIBUTES pin. On top of the universal forbidden-attribute floor enforced by `SgxVerifier`
/// (DEBUG / PROVISION_KEY / EINITTOKEN_KEY), every allowlisted enclave measurement must declare the
/// exact ATTRIBUTES profile it is allowed to register with. Registration of an enclave with no
/// configured policy fails closed, so permissionless registration cannot admit an attribute
/// combination (e.g. a reserved bit, or a missing INIT/MODE64BIT) that the global deny-mask alone
/// would not catch.
/// @custom:security-contact security@taiko.xyz
contract SecureSgxVerifier is SgxVerifier {
    /// @notice The ATTRIBUTES profile an allowlisted enclave measurement is pinned to. A
    /// registering quote is accepted only when `quoteAttributes & mask == expected`. A zero `mask`
    /// means no policy is configured and registration for that MRENCLAVE is rejected.
    /// @param mask The ATTRIBUTES bits that are checked.
    /// @param expected The required value of the checked bits (must have no bit set outside `mask`).
    struct AttributePolicy {
        bytes16 mask;
        bytes16 expected;
    }

    /// @notice The ATTRIBUTES pin for each allowlisted application-enclave measurement.
    mapping(bytes32 mrEnclave => AttributePolicy policy) public enclaveAttributePolicy;

    /// @notice A security delay between a non-owner registration via `registerInstance` and the
    /// instance becoming usable for proof verification. It gives off-chain monitoring a window to
    /// evict a rogue self-registered instance (via `deleteInstances`) before it can prove. Owner
    /// registrations — `addInstances`, or `registerInstance` called by the owner — are NOT delayed.
    /// Set once at construction (mainnet/testnet deployments use 24 hours); it must be non-zero and
    /// must not exceed `INSTANCE_EXPIRY`.
    uint64 public immutable instanceValidityDelay;

    /// @notice Emitted when an MRENCLAVE's ATTRIBUTES pin is set or updated.
    /// @param mrEnclave The application-enclave measurement.
    /// @param mask The checked ATTRIBUTES bits.
    /// @param expected The required value of the checked bits.
    /// @param version The new policy version; instances registered under this pin record it and are
    /// revoked once it no longer matches.
    event EnclaveAttributePolicySet(
        bytes32 indexed mrEnclave, bytes16 mask, bytes16 expected, uint32 version
    );

    /// @notice Emitted when an MRENCLAVE's ATTRIBUTES pin is removed.
    /// @param mrEnclave The application-enclave measurement.
    event EnclaveAttributePolicyRemoved(bytes32 indexed mrEnclave);

    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar,
        uint64 _instanceValidityDelay
    )
        SgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    {
        // The delay must be positive (a zero delay defeats the monitoring window) and no longer than
        // the validity window itself.
        require(
            _instanceValidityDelay > 0 && _instanceValidityDelay <= INSTANCE_EXPIRY,
            SGX_INVALID_VALIDITY_DELAY()
        );
        instanceValidityDelay = _instanceValidityDelay;
    }

    /// @dev Restricts a call to the owner or `_addr` (used for `removeEnclaveAttributePolicy` with
    /// the registrar).
    /// @param _addr The additional address allowed alongside the owner.
    modifier onlyOwnerOr(address _addr) {
        require(msg.sender == owner() || msg.sender == _addr, SGX_NOT_AUTHORIZED());
        _;
    }

    /// @notice Sets (or updates) the ATTRIBUTES pin for an allowlisted enclave measurement.
    /// @dev The mask must cover every universally-forbidden bit and the expected value must clear
    /// them, so a per-enclave pin can never re-admit a debug/provisioning/launch enclave; the
    /// expected value must not assert any bit outside the mask.
    /// @param _mrEnclave The application-enclave measurement to pin.
    /// @param _mask The ATTRIBUTES bits to check (must be non-zero and cover the forbidden bits).
    /// @param _expected The required value of the checked bits.
    function setEnclaveAttributePolicy(
        bytes32 _mrEnclave,
        bytes16 _mask,
        bytes16 _expected
    )
        external
        onlyOwner
    {
        // A non-zero mask is what marks the policy as configured.
        require(_mask != bytes16(0), SGX_INVALID_ATTRIBUTE_POLICY());
        // The expected value must not assert any bit the mask does not check.
        require(_expected & ~_mask == bytes16(0), SGX_INVALID_ATTRIBUTE_POLICY());
        // The mask must check every universally-forbidden bit and the expected value must clear
        // them: the per-enclave pin can never re-admit a debug/provisioning/launch enclave.
        require(
            _mask & SGX_FORBIDDEN_ATTRIBUTE_MASK == SGX_FORBIDDEN_ATTRIBUTE_MASK,
            SGX_INVALID_ATTRIBUTE_POLICY()
        );
        require(
            _expected & SGX_FORBIDDEN_ATTRIBUTE_MASK == bytes16(0), SGX_INVALID_ATTRIBUTE_POLICY()
        );

        // Bump the version on every set (including an in-place edit) so any change revokes instances
        // registered under the previous pin. The counter is never reset, so a removed-then-re-added
        // pin gets a brand-new version and cannot re-enable previously registered instances. The
        // version shares the per-MRENCLAVE slot with the allowlist flag, so `verifyProof` reads both
        // in one SLOAD.
        uint32 version = mrEnclaveState[_mrEnclave].policyVersion + 1;
        mrEnclaveState[_mrEnclave].policyVersion = version;

        enclaveAttributePolicy[_mrEnclave] = AttributePolicy(_mask, _expected);
        emit EnclaveAttributePolicySet(_mrEnclave, _mask, _expected, version);
    }

    /// @notice Returns the current per-MRENCLAVE policy version (the generation an instance must still
    /// match to verify proofs). Zero means the pin was never set.
    /// @param _mrEnclave The application-enclave measurement.
    /// @return The current policy version.
    function enclaveAttributePolicyVersion(bytes32 _mrEnclave) external view returns (uint32) {
        return mrEnclaveState[_mrEnclave].policyVersion;
    }

    /// @notice Removes the ATTRIBUTES pin for an enclave measurement. Registration for that MRENCLAVE
    /// then fails closed until a new pin is set, and — because `verifyProof` re-checks the current pin
    /// — every instance already registered under it is revoked (invalidated, not deleted) and can no
    /// longer verify proofs.
    /// @dev Callable by the owner or the `registrar` (the SGX-instance registrar set at
    /// construction); the registrar can only remove pins, so it can fail-close a compromised enclave
    /// but cannot relax or re-admit one. When `registrar` is `address(0)`, removal is owner-only.
    /// Removal bumps the monotonic policy version (so `verifyProof` needs only a single version
    /// comparison to reject revoked instances) and the counter is never reset, so a later re-add gets
    /// a fresh version and cannot re-enable the revoked instances.
    /// @param _mrEnclave The application-enclave measurement whose pin is removed.
    function removeEnclaveAttributePolicy(bytes32 _mrEnclave) external onlyOwnerOr(registrar) {
        require(
            enclaveAttributePolicy[_mrEnclave].mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET()
        );
        // Bump the version so every instance registered under this pin is revoked at proof time by a
        // single version mismatch; no live instance can hold the bumped version because registration
        // for this MRENCLAVE is now fail-closed until a new pin is set (which bumps again).
        mrEnclaveState[_mrEnclave].policyVersion += 1;
        delete enclaveAttributePolicy[_mrEnclave];
        emit EnclaveAttributePolicyRemoved(_mrEnclave);
    }

    /// @inheritdoc SgxVerifier
    /// @dev Strict policy: accept the TCB statuses whose platform microcode is up to date — `OK`,
    /// `TCB_SW_HARDENING_NEEDED` and `TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED` (their mitigations
    /// live in configuration / enclave software pinned by the MRENCLAVE allowlist, not in microcode).
    /// The out-of-date statuses (`TCB_OUT_OF_DATE`, `TCB_OUT_OF_DATE_CONFIGURATION_NEEDED`) are
    /// rejected, where the platform may be missing the microcode that patches SGX key-extraction
    /// vulnerabilities (so the in-enclave signing key could be extractable); `TCB_CONFIGURATION_NEEDED`,
    /// `TCB_REVOKED` and `TCB_UNRECOGNIZED` are rejected too. The policy is expressed against the
    /// attestation's `TCBStatus` enum so an enum reorder is caught at compile time.
    function isTcbStatusAccepted(uint8 _status) public pure override returns (bool) {
        return _status == uint8(TCBStatus.OK) || _status == uint8(TCBStatus.TCB_SW_HARDENING_NEEDED)
            || _status == uint8(TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED);
    }

    /// @inheritdoc SgxVerifier
    /// @dev Fail-closed per-MRENCLAVE ATTRIBUTES pin: the enclave must have a configured policy and
    /// its attested ATTRIBUTES must match the pinned profile over the checked bits. Returns the
    /// current policy version so it is recorded on the instance for the `verifyProof` re-check.
    function _validateEnclaveAttributes(
        bytes32 _mrEnclave,
        bytes16 _attributes
    )
        internal
        view
        override
        returns (uint32 policyVersion_)
    {
        AttributePolicy memory policy = enclaveAttributePolicy[_mrEnclave];
        require(policy.mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET());
        require(_attributes & policy.mask == policy.expected, SGX_ATTRIBUTE_MISMATCH());
        return mrEnclaveState[_mrEnclave].policyVersion;
    }

    /// @inheritdoc SgxVerifier
    /// @dev Additionally requires the per-MRENCLAVE pin that gated registration to still be in force:
    /// any edit, or a removal (which bumps the version too), changes the version so the recorded
    /// version no longer matches and the instance is revoked. Owner-added instances (`mrEnclave == 0`)
    /// are exempt, and the base trusted-MRENCLAVE/MRSIGNER allowlist re-check still applies on top.
    /// Reads the per-MRENCLAVE slot once: it carries both the current version and the allowlist flag.
    function _isEnclaveStillTrusted(Instance memory _instance)
        internal
        view
        override
        returns (bool)
    {
        if (_instance.mrEnclave == bytes32(0)) return true;
        MrEnclaveState memory state = mrEnclaveState[_instance.mrEnclave];
        if (state.policyVersion != _instance.policyVersion) return false;
        if (!checkLocalEnclaveReport) return true;
        return state.trusted && trustedUserMrSigner[_instance.mrSigner];
    }

    /// @inheritdoc SgxVerifier
    function _validityDelay() internal view override returns (uint64) {
        return instanceValidityDelay;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error SGX_ATTRIBUTE_POLICY_NOT_SET();
    error SGX_ATTRIBUTE_MISMATCH();
    error SGX_INVALID_ATTRIBUTE_POLICY();
    error SGX_NOT_AUTHORIZED();
    error SGX_INVALID_VALIDITY_DELAY();
}
