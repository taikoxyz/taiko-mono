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
        _checkSgx(sgxReth, attestation, "SGX-reth");
        _checkSgx(sgxGeth, attestation, "SGX-geth");
        _checkRisc0(risc0);
        _checkSp1(sp1);
        _checkAggregation(compose, sgxGeth, sgxReth, risc0, sp1);

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

    /// @dev Asserts an SGX verifier is the strict Secure variant, wired to the shared entrypoint,
    /// on the Hoodi chain id, Taiko-owned, and fail-closed. Allowlist population is advisory
    /// (ConfigureSgxVerifier runs after deployment).
    function _checkSgx(address sgx, address attestation, string memory tag) internal {
        // The has-code hard check already recorded the [FAIL] for a codeless verifier; returning
        // here keeps the typed reads below from reverting the whole run on a codeless target.
        if (!_hasCode(sgx)) return;

        // Secure/Insecure discriminator: both implement isTcbStatusAccepted; only Secure rejects
        // out-of-date TCB. Expressed against the pinned Automata TCBStatus enum.
        bool rejectsOutOfDate = !ISgxView(sgx).isTcbStatusAccepted(uint8(TCBStatus.TCB_OUT_OF_DATE));
        bool acceptsOk = ISgxView(sgx).isTcbStatusAccepted(uint8(TCBStatus.OK));
        _hard(
            rejectsOutOfDate && acceptsOk,
            string.concat(tag, ": Secure TCB policy (rejects OUT_OF_DATE)")
        );

        // Secure-only immutable; reverts on an Insecure verifier (caught as a failure).
        try ISgxView(sgx).instanceValidityDelay() returns (uint64 d) {
            _hard(
                d == EXPECTED_VALIDITY_DELAY, string.concat(tag, ": instanceValidityDelay == 24h")
            );
        } catch {
            _hard(false, string.concat(tag, ": instanceValidityDelay getter (Secure-only) present"));
        }

        _hard(
            ISgxView(sgx).automataDcapAttestation() == attestation,
            string.concat(tag, ": automataDcapAttestation == entrypoint")
        );
        _hard(
            ISgxView(sgx).taikoChainId() == EXPECTED_CHAIN_ID,
            string.concat(tag, ": taikoChainId == TAIKO_HOODI")
        );
        _hard(ISgxView(sgx).owner() == EXPECTED_OWNER, string.concat(tag, ": owner == Hoodi owner"));
        _hard(
            ISgxView(sgx).checkLocalEnclaveReport(),
            string.concat(tag, ": checkLocalEnclaveReport == true")
        );

        // Advisory: instances are registered post-deploy by ConfigureSgxVerifier. The allowlist
        // mappings are keyed by value and cannot be enumerated on-chain, so nextInstanceId is the
        // readable proxy for "at least one instance has been registered".
        _warn(
            ISgxView(sgx).nextInstanceId() >= 1,
            string.concat(tag, ": >= 1 instance registered (advisory)")
        );

        // Advisory: the current deploy leaves the registrar unset (address(0)); a non-zero
        // registrar is a deviation worth flagging, never a hard failure.
        _warn(
            ISgxView(sgx).registrar() == address(0),
            string.concat(tag, ": registrar == address(0) (advisory)")
        );
    }

    /// @dev Asserts the Risc0 tier verifier is on the Hoodi chain id, Taiko-owned, and wired to a
    /// deployed groth16 verifier.
    function _checkRisc0(address risc0) internal {
        // The has-code hard check already recorded the [FAIL] for a codeless verifier; returning
        // here keeps the typed reads below from reverting the whole run on a codeless target.
        if (!_hasCode(risc0)) return;

        _hard(
            IRisc0View(risc0).taikoChainId() == EXPECTED_CHAIN_ID,
            "Risc0: taikoChainId == TAIKO_HOODI"
        );
        _hard(IRisc0View(risc0).owner() == EXPECTED_OWNER, "Risc0: owner == Hoodi owner");
        _hard(
            _hasCode(IRisc0View(risc0).riscoGroth16Verifier()), "Risc0: groth16 verifier has code"
        );
    }

    /// @dev Asserts the SP1 tier verifier is on the Hoodi chain id, Taiko-owned, and wired to a
    /// deployed remote verifier (the v6.1 gateway).
    function _checkSp1(address sp1) internal {
        // The has-code hard check already recorded the [FAIL] for a codeless verifier; returning
        // here keeps the typed reads below from reverting the whole run on a codeless target.
        if (!_hasCode(sp1)) return;

        _hard(ISP1View(sp1).taikoChainId() == EXPECTED_CHAIN_ID, "SP1: taikoChainId == TAIKO_HOODI");
        _hard(ISP1View(sp1).owner() == EXPECTED_OWNER, "SP1: owner == Hoodi owner");
        _hard(_hasCode(ISP1View(sp1).sp1RemoteVerifier()), "SP1: remote verifier has code");
    }

    /// @dev Asserts the MainnetVerifier aggregation shape: TDX/OP tiers disabled, and the four
    /// active tiers non-zero and mutually distinct. The inbox -> aggregator identity needs no check:
    /// `compose` is read from `inbox.getConfig().proofVerifier`, so it holds by construction.
    function _checkAggregation(
        address compose,
        address sgxGeth,
        address sgxReth,
        address risc0,
        address sp1
    )
        internal
    {
        // The has-code hard check already recorded the [FAIL] for a codeless MainnetVerifier;
        // returning here keeps the typed reads below from reverting the whole run on a codeless
        // target (e.g. a wrong --inbox, or the MainnetVerifier not deployed yet).
        if (!_hasCode(compose)) return;

        _hard(
            IComposeView(compose).tdxGethVerifier() == address(0), "Mainnet: tdxGethVerifier == 0"
        );
        _hard(IComposeView(compose).opVerifier() == address(0), "Mainnet: opVerifier == 0");
        bool distinct = sgxGeth != sgxReth && sgxGeth != risc0 && sgxGeth != sp1 && sgxReth != risc0
            && sgxReth != sp1 && risc0 != sp1;
        _hard(distinct, "Mainnet: four tiers are distinct");
        bool nonZero = sgxGeth != address(0) && sgxReth != address(0) && risc0 != address(0)
            && sp1 != address(0);
        _hard(nonZero, "Mainnet: four tiers are non-zero");
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
