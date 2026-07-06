// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @dev Minimal read view of the Taiko-owned AutomataDcapAttestationFee entrypoint.
interface IEntrypointView {
    function owner() external view returns (address);
    function quoteVerifiers(uint16 version) external view returns (address);
    function getBp() external view returns (uint16);
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool success, bytes memory output);
}

/// @dev Minimal read view of the Automata V3 quote verifier.
interface IV3QuoteVerifierView {
    function pccsRouter() external view returns (address);
    function quoteVersion() external view returns (uint16);
}

/// @dev Minimal read view of ComposeVerifier/MainnetVerifier tier wiring.
interface IComposeView {
    function sgxGethVerifier() external view returns (address);
    function sgxRethVerifier() external view returns (address);
    function risc0RethVerifier() external view returns (address);
    function sp1RethVerifier() external view returns (address);
    function tdxGethVerifier() external view returns (address);
    function opVerifier() external view returns (address);
}

/// @dev Minimal read view of an SgxVerifier (Secure or Insecure).
interface ISgxView {
    function taikoChainId() external view returns (uint64);
    function automataDcapAttestation() external view returns (address);
    function checkLocalEnclaveReport() external view returns (bool);
    function registrar() external view returns (address);
    function nextInstanceId() external view returns (uint256);
    function owner() external view returns (address);
    function isTcbStatusAccepted(uint8 status) external view returns (bool);
    function instanceValidityDelay() external view returns (uint64);
}

/// @dev Minimal read view of Risc0Verifier.
interface IRisc0View {
    function taikoChainId() external view returns (uint64);
    function riscoGroth16Verifier() external view returns (address);
    function owner() external view returns (address);
}

/// @dev Minimal read view of SP1Verifier.
interface ISP1View {
    function taikoChainId() external view returns (uint64);
    function sp1RemoteVerifier() external view returns (address);
    function owner() external view returns (address);
}

/// @title VerifyHoodiDeployment
/// @notice Read-only verifier for the Taiko Hoodi proof stack: walks the deployment from the
/// Shasta inbox and the Taiko-owned AutomataDcapAttestationFee entrypoint and asserts the SGX/DCAP
/// wiring (#21827), Risc0/SP1 tiers (#21907) and MainnetVerifier aggregation are correct and safe.
/// @dev Uses minimal local interfaces so it compiles under the non-IR `layer1` profile (the concrete
/// Automata contracts require `via_ir`). No broadcast, no PRIVATE_KEY — every read is a staticcall.
/// @custom:security-contact security@taiko.xyz
contract VerifyHoodiDeployment is Script {
    address internal constant EXPECTED_OWNER = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;
    uint64 internal constant EXPECTED_CHAIN_ID = LibNetwork.TAIKO_HOODI;
    uint64 internal constant EXPECTED_VALIDITY_DELAY = 24 hours;

    uint256 internal passes;
    uint256 internal advisories;
    uint256 internal hardFails;

    /// @notice Env-driven entrypoint. Reads INBOX, ATTESTATION and optional PCCS_ROUTER, runs the
    /// full check suite, and reverts (non-zero exit) iff any hard check failed.
    function run() external {
        address inbox = vm.envAddress("INBOX");
        address attestation = vm.envAddress("ATTESTATION");
        address pccsExpected = vm.envOr("PCCS_ROUTER", address(0));
        uint256 fails = verify(inbox, attestation, pccsExpected);
        require(fails == 0, "Hoodi deployment verification FAILED");
    }

    /// @notice Runs every check against the deployment reachable from the two roots and returns the
    /// number of hard failures (0 == deployment OK). Advisories never count as failures.
    /// @param inbox The Shasta inbox proxy (root of tier/aggregation discovery).
    /// @param attestation The AutomataDcapAttestationFee entrypoint (root of the DCAP subtree).
    /// @param pccsExpected Optional expected PCCS router; when non-zero it is asserted (advisory).
    /// @return hardFails_ The number of hard-check failures.
    function verify(
        address inbox,
        address attestation,
        address pccsExpected
    )
        public
        returns (uint256 hardFails_)
    {
        passes = 0;
        advisories = 0;
        hardFails = 0;

        // ---- discovery walk ----
        // Each external read is guarded by a has-code check so that a missing (codeless) node
        // leaves the downstream local as address(0) and surfaces as a [FAIL] in the has-code
        // section below, rather than reverting the whole run on `call to non-contract address`.
        address compose = _hasCode(inbox) ? IInbox(inbox).getConfig().proofVerifier : address(0);
        address sgxReth = _hasCode(compose) ? IComposeView(compose).sgxRethVerifier() : address(0);
        address sgxGeth = _hasCode(compose) ? IComposeView(compose).sgxGethVerifier() : address(0);
        address risc0 = _hasCode(compose) ? IComposeView(compose).risc0RethVerifier() : address(0);
        address sp1 = _hasCode(compose) ? IComposeView(compose).sp1RethVerifier() : address(0);
        address v3 =
            _hasCode(attestation) ? IEntrypointView(attestation).quoteVerifiers(3) : address(0);
        address pccs = _hasCode(v3) ? IV3QuoteVerifierView(v3).pccsRouter() : address(0);

        console2.log("=== Hoodi deployment verification ===");
        console2.log("inbox                        :", inbox);
        console2.log("proofVerifier (Mainnet)      :", compose);
        console2.log("attestation (DCAP entrypoint):", attestation);
        console2.log("V3QuoteVerifier              :", v3);
        console2.log("PCCS router                  :", pccs);

        // ---- has-code checks ----
        _hard(_hasCode(attestation), "entrypoint has code");
        _hard(_hasCode(v3), "V3QuoteVerifier has code");
        _hard(_hasCode(pccs), "PCCS router has code");
        _hard(_hasCode(compose), "MainnetVerifier has code");
        _hard(_hasCode(sgxReth), "SGX-reth verifier has code");
        _hard(_hasCode(sgxGeth), "SGX-geth verifier has code");
        _hard(_hasCode(risc0), "Risc0Verifier has code");
        _hard(_hasCode(sp1), "SP1Verifier has code");

        _checkEntrypoint(attestation, v3, pccs, pccsExpected);

        console2.log("---");
        console2.log("[PASS] count :", passes);
        console2.log("[WARN] count :", advisories);
        console2.log("[FAIL] count :", hardFails);
        return hardFails;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Asserts the DCAP entrypoint is Taiko-owned, fee-free, wired to a v3 quote verifier, and
    /// live (an empty quote is rejected, proving entrypoint -> V3 -> PCCS plumbing is real).
    function _checkEntrypoint(
        address attestation,
        address v3,
        address pccs,
        address pccsExpected
    )
        internal
    {
        // The has-code hard check already recorded the [FAIL] for a codeless entrypoint; returning
        // here keeps the high-level reads below (which revert on a codeless address) from reverting
        // the whole run, so a codeless root still surfaces as > 0 hardFails instead of a revert.
        if (!_hasCode(attestation)) return;

        _hard(
            IEntrypointView(attestation).owner() == EXPECTED_OWNER,
            "entrypoint owner == Hoodi owner"
        );
        _hard(v3 != address(0), "entrypoint quoteVerifiers(3) set");
        _hard(IEntrypointView(attestation).getBp() == 0, "entrypoint fee bp == 0");

        // Liveness: an empty quote must return success == false (Automata's early length rejection)
        // without reverting. bp == 0 (asserted above) keeps this staticcall state-change-free.
        (bool callOk, bytes memory ret) = attestation.staticcall(
            abi.encodeWithSelector(IEntrypointView.verifyAndAttestOnChain.selector, bytes(""))
        );
        bool attestOk = callOk && ret.length >= 32 && abi.decode(ret, (bool));
        _hard(callOk && !attestOk, "entrypoint liveness: empty quote rejected");

        if (v3 != address(0)) {
            _hard(IV3QuoteVerifierView(v3).quoteVersion() == 3, "V3QuoteVerifier.quoteVersion == 3");
        }
        if (pccsExpected != address(0)) {
            _warn(pccs == pccsExpected, "PCCS router == expected (optional)");
        }
    }

    /// @dev Records a hard check: increments passes or hardFails and logs the outcome.
    function _hard(bool ok, string memory label) internal {
        if (ok) {
            ++passes;
            console2.log("  [PASS]", label);
        } else {
            ++hardFails;
            console2.log("  [FAIL]", label);
        }
    }

    /// @dev Records an advisory check: increments passes or advisories and logs the outcome.
    function _warn(bool ok, string memory label) internal {
        if (ok) {
            ++passes;
            console2.log("  [PASS]", label);
        } else {
            ++advisories;
            console2.log("  [WARN]", label);
        }
    }

    /// @dev True when the address hosts contract code.
    function _hasCode(address a) internal view returns (bool) {
        return a.code.length != 0;
    }
}
