// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Compilation anchor for the upstream Automata DCAP contracts. Nothing imports these
/// sources at deploy time — `DeployUnzenContracts` (profile layer1) deploys them from the
/// pre-built `out/layer1o` artifacts via `vm.getCode` — so this file exists purely to make
/// `pnpm compile:l1o` emit those artifacts. The upstream code only compiles under via_ir, so
/// this file builds under profile.layer1o and is skipped by profile.layer1 (see foundry.toml).
/// @custom:security-contact security@taiko.xyz
import {
    AutomataDcapAttestationFee
} from "@automata-network/automata-dcap-attestation/contracts/AutomataDcapAttestationFee.sol";
import {
    V3QuoteVerifier
} from "@automata-network/automata-dcap-attestation/contracts/verifiers/V3QuoteVerifier.sol";
import { P256Verifier } from "@p256-verifier/contracts/P256Verifier.sol";
