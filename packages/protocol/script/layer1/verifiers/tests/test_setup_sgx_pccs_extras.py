import subprocess
from pathlib import Path


def test_extracts_fmspc_from_sgx_bootstrap_quote():
    protocol_root = Path(__file__).resolve().parents[4]
    script = protocol_root / "script/layer1/verifiers/setup_sgx_pccs_extras.sh"
    bootstrap = Path("/tmp/provider-log-check-20260519/raiko2-sgx/config/bootstrap.json")

    assert bootstrap.is_file(), f"missing local SGX bootstrap fixture: {bootstrap}"

    result = subprocess.run(
        ["bash", str(script), "--extract-fmspc", str(bootstrap)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.stdout.strip() == "00606a000000"


def test_deploy_script_deploys_helpers_individually_and_verifies_code():
    protocol_root = Path(__file__).resolve().parents[4]
    script = protocol_root / "script/layer1/verifiers/deploy_automata_dcap.sh"
    text = script.read_text()

    assert "make deploy-helpers RPC_URL" not in text
    assert "deploy_helper_if_missing" in text
    assert "wait_for_code" in text
    for label, sig in [
        ("EnclaveIdentityHelper", "deployEnclaveIdentityHelper()"),
        ("FmspcTcbHelper", "deployFmspcTcbHelper()"),
        ("PCKHelper", "deployPckHelper()"),
        ("X509CRLHelper", "deployX509CrlHelper()"),
        ("TcbEvalHelper", "deployTcbEvalHelper()"),
    ]:
        assert f'deploy_helper_if_missing "{label}" "{sig}"' in text


def test_deploy_script_skips_daimo_p256_when_rip7212_is_available():
    protocol_root = Path(__file__).resolve().parents[4]
    script = protocol_root / "script/layer1/verifiers/deploy_automata_dcap.sh"
    text = script.read_text()

    assert 'DEPLOY_DAIMO_P256="${DEPLOY_DAIMO_P256:-auto}"' in text
    assert "P256_RIP7212_TEST_INPUT" in text
    assert "supports_rip7212_p256" in text
    assert "RIP-7212 P256 precompile verified" in text
    assert "Skipping Daimo P256 deployment" in text
    assert 'wait_for_code "Daimo P256Verifier"' in text


def test_deploy_script_fallback_registers_quote_verifiers():
    protocol_root = Path(__file__).resolve().parents[4]
    script = protocol_root / "script/layer1/verifiers/deploy_automata_dcap.sh"
    text = script.read_text()

    assert "new V${VER}QuoteVerifier@0x" in text
    assert "ensure_quote_verifier_registered" in text
    assert 'quoteVerifiers(uint16)(address)' in text
    assert 'setAuthorized(address,bool)' in text
    assert 'setQuoteVerifier(address)' in text


def test_setup_script_fails_hard_for_required_writes():
    protocol_root = Path(__file__).resolve().parents[4]
    script = protocol_root / "script/layer1/verifiers/setup_sgx_pccs_extras.sh"
    text = script.read_text()

    assert "require_code \"PCKHelper/X509Helper\"" in text
    assert "AccessControl" not in text
    assert 'PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-false}"' in text
    assert "tcbevaluationdatanumbers unavailable" in text
    assert "TCB_EVAL_API_SGX" in text
    assert "0x9f4daa9e" in text
    assert 'FMSPC_TCB_UPLOAD_MODE="${FMSPC_TCB_UPLOAD_MODE:-direct-storage}"' in text
    assert "EncodeSgxFmspcTcbStorage.s.sol:EncodeSgxFmspcTcbStorage" in text
    assert "direct storage attest FMSPC TCB main" in text
    assert "direct storage attest FMSPC TCB issue/eval" in text
    assert "direct storage attest FMSPC TCB contentHash" in text
    assert "upsertFmspcTcb(tcbEval=$TCB_EVAL,fmspc=$FMSPC)" in text
    assert "send_with_gas \"$ENCLAVE_ID_GAS_LIMIT\" \"upsertEnclaveIdentity" in text
    for line in text.splitlines():
        if "send \"" in line and any(
            token in line
            for token in (
                "grantDao",
                "grantRoles",
                "setFmspcTcbDaoVersionedAddr",
                "setQeIdDaoVersionedAddr",
                "upsert",
            )
        ):
            assert "|| true" not in line


def test_fmspc_direct_storage_encoder_outputs_storage_records():
    protocol_root = Path(__file__).resolve().parents[4]
    encoder = protocol_root / "script/layer1/verifiers/EncodeSgxFmspcTcbStorage.s.sol"
    text = encoder.read_text()

    assert "FMSPC_TCB_MAGIC = 0xbb69b29c" in text
    assert "basic.id == TcbId.SGX" in text
    assert "basic.version == 3" in text
    assert "tcbIssueEvaluation" in text
    assert "fmspcTcbContentHash" in text
    for filename in (
        "tcb_key.hex",
        "tcb_data.hex",
        "tcb_sha256.hex",
        "issue_eval_key.hex",
        "issue_eval_data.hex",
        "content_hash_key.hex",
        "content_hash_data.hex",
    ):
        assert filename in text


def test_configure_sgx_verifier_supports_secure_attribute_policy():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/configure_sgx_verifier.sh"
    script = protocol_root / "script/layer1/verifiers/ConfigureSgxVerifier.s.sol"

    wrapper_text = wrapper.read_text()
    script_text = script.read_text()

    assert "--attribute-policy HASH MASK EXPECTED" in wrapper_text
    assert "SET_ATTRIBUTE_POLICY=false" in wrapper_text
    assert "ATTRIBUTE_POLICY_MRENCLAVE" in wrapper_text
    assert "ATTRIBUTE_POLICY_MASK" in wrapper_text
    assert "ATTRIBUTE_POLICY_EXPECTED" in wrapper_text
    assert 'AUTO_ATTRIBUTE_POLICY_ON_MRENCLAVE="${AUTO_ATTRIBUTE_POLICY_ON_MRENCLAVE:-true}"' in wrapper_text
    assert 'DEFAULT_ATTRIBUTE_POLICY_MASK="${DEFAULT_ATTRIBUTE_POLICY_MASK:-0xffffffffffffffff0000000000000000}"' in wrapper_text
    assert 'DEFAULT_ATTRIBUTE_POLICY_EXPECTED="${DEFAULT_ATTRIBUTE_POLICY_EXPECTED:-0x05000000000000000000000000000000}"' in wrapper_text
    assert "maybe_default_attribute_policy_for_mrenclave" in wrapper_text
    assert "enclaveAttributePolicyVersion(bytes32)(uint32)" in wrapper_text

    assert "import { SecureSgxVerifier }" in script_text
    assert 'vm.envOr("SET_ATTRIBUTE_POLICY", false)' in script_text
    assert "function _envBytes16" in script_text
    assert "setEnclaveAttributePolicy(mrEnclave, mask, expected)" in script_text


def test_configure_sgx_verifier_defaults_attribute_policy_when_trusting_mrenclave(tmp_path):
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/configure_sgx_verifier.sh"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "cast.log"
    fake_cast = bin_dir / "cast"
    fake_cast.write_text(
        f"""#!/bin/bash
set -e
if [[ "$1" == "call" ]]; then
    echo 0
    exit 0
fi
if [[ "$1" == "send" ]]; then
    printf '%s\\n' "$*" >> "{log}"
    exit 0
fi
echo "unexpected cast invocation: $*" >&2
exit 1
"""
    )
    fake_cast.chmod(0o755)

    mrenclave = "0x" + "11" * 32
    result = subprocess.run(
        ["bash", str(wrapper), "--mrenclave", mrenclave],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "PRIVATE_KEY": "0xabc",
            "FORK_URL": "https://example.invalid/rpc",
            "SGX_VERIFIER_ADDRESS": "0x" + "22" * 20,
            "SKIP_SIMULATION": "true",
        },
    )

    calls = log.read_text()
    assert "Default attribute policy enabled for MRENCLAVE" in result.stdout
    assert "setEnclaveAttributePolicy(bytes32,bytes16,bytes16)" in calls
    assert mrenclave in calls
    assert "0xffffffffffffffff0000000000000000" in calls
    assert "0x05000000000000000000000000000000" in calls
    assert "setMrEnclave(bytes32,bool)" in calls


def test_configure_sgx_verifier_redacts_rpc_in_logs():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/configure_sgx_verifier.sh"
    text = wrapper.read_text()

    assert "redact_rpc()" in text
    assert 'echo "RPC: $(redact_rpc "$FORK_URL")"' in text
    assert 'echo "RPC: $FORK_URL"' not in text


def test_configure_sgx_verifier_can_skip_local_simulation_for_rip7212_chains():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/configure_sgx_verifier.sh"
    text = wrapper.read_text()

    assert 'SKIP_SIMULATION="${SKIP_SIMULATION:-false}"' in text
    assert "run_with_cast()" in text
    assert 'cast send "$SGX_VERIFIER_ADDRESS"' in text
    assert '"registerInstance(bytes)"' in text
    assert 'REGISTER_INSTANCE_GAS_LIMIT="${REGISTER_INSTANCE_GAS_LIMIT:-8000000}"' in text


def test_devnet_wrapper_runs_full_own_pccs_two_secure_sgx_flow():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/deploy_devnet_sgx_own_pccs.sh"
    text = wrapper.read_text()

    assert 'DEVNET_ENV="${DEVNET_ENV:-/home/yue/works/taiko/raiko2-k8s/devnet.env}"' in text
    assert 'INTEL_API_SGX="${INTEL_API_SGX:-https://127.0.0.1:8081/sgx/certification/v4}"' in text
    assert 'PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-true}"' in text
    assert 'DEPLOY_DAIMO_P256="${DEPLOY_DAIMO_P256:-auto}"' in text
    assert "deploy_automata_dcap.sh" in text
    assert "setup_sgx_pccs_extras.sh" in text
    assert 'DEPLOY_SECURE_SGX_VERIFIERS="${DEPLOY_SECURE_SGX_VERIFIERS:-true}"' in text
    assert 'TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-}"' in text
    assert 'ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID="${ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID:-false}"' in text
    assert "TAIKO_CHAIN_ID must be set to the Taiko L2 chain ID" in text
    assert "taikoChainId=$TAIKO_CHAIN_ID" in text
    assert 'SECURE_SGX_GETH_VERIFIER="${SECURE_SGX_GETH_VERIFIER:-}"' in text
    assert 'SECURE_SGX_RETH_VERIFIER="${SECURE_SGX_RETH_VERIFIER:-}"' in text
    assert '${SECURE_SGX_VERIFIER:-}' not in text
    assert 'SGX_GETH_BOOTSTRAP_JSON="${SGX_GETH_BOOTSTRAP_JSON:-}"' in text
    assert 'SGX_RETH_BOOTSTRAP_JSON="${SGX_RETH_BOOTSTRAP_JSON:-}"' in text
    assert 'elif [[ -f "$SGX_RETH_BOOTSTRAP_JSON" ]]; then' in text
    assert 'elif [[ -f "$SGX_GETH_BOOTSTRAP_JSON" ]]; then' in text
    assert "REGISTER_SECURE_SGX=true requires SGX_BOOTSTRAP_JSON" not in text
    assert 'REGISTER_SECURE_SGX="${REGISTER_SECURE_SGX:-false}"' in text
    assert 'REGISTER_SECURE_SGX_TARGET="${REGISTER_SECURE_SGX_TARGET:-reth}"' in text
    assert 'FAKE_QUOTE_SMOKE="${FAKE_QUOTE_SMOKE:-true}"' in text
    assert 'deploy_secure_sgx_verifier "geth"' in text
    assert 'deploy_secure_sgx_verifier "reth"' in text
    assert 'run_fake_quote_smoke "geth" "$SECURE_SGX_GETH_VERIFIER"' in text
    assert 'run_fake_quote_smoke "reth" "$SECURE_SGX_RETH_VERIFIER"' in text
    assert "fake SGX quote rejected as expected for geth" in text
    assert "fake SGX quote rejected as expected for reth" in text
    assert 'cast call "$verifier" "registerInstance(bytes)" "$FAKE_SGX_QUOTE"' in text
    assert 'require_bootstrap_json "geth" "$SGX_GETH_BOOTSTRAP_JSON"' in text
    assert 'require_bootstrap_json "reth" "$SGX_RETH_BOOTSTRAP_JSON"' in text
    assert 'register_real_sgx_quote "geth" "$SECURE_SGX_GETH_VERIFIER" "$SGX_GETH_BOOTSTRAP_JSON"' in text
    assert 'register_real_sgx_quote "reth" "$SECURE_SGX_RETH_VERIFIER" "$SGX_RETH_BOOTSTRAP_JSON"' in text
    assert "must be different" in text
    assert 'SKIP_SIMULATION=true' in text
    assert "SecureSgxVerifier.sol:SecureSgxVerifier" in text
    assert "configure_sgx_verifier.sh" in text
    assert "--attribute-policy" in text
    assert "--quote" in text
    assert "SecureSgxGethVerifier" in text
    assert "SecureSgxRethVerifier" in text
    assert "taiko_chain_id" in text
    assert "sgx_geth_quote_info_json" in text
    assert "sgx_reth_quote_info_json" in text


def test_existing_automata_wrapper_deploys_two_secure_sgx_verifiers_without_collateral_or_policy_setup():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/deploy_sgx_verifiers_with_existing_automata.sh"
    text = wrapper.read_text()

    assert 'NETWORK="${NETWORK:-}"' in text
    assert 'RPC_URL="${RPC_URL:-${FORK_URL:-}}"' in text
    assert "HOODI_TAIKO_CHAIN_ID=167013" in text
    assert "MAINNET_TAIKO_CHAIN_ID=167000" in text
    assert "0x488797321FA4272AF9d0eD4cDAe5Ec7a0210cBD5" in text
    assert "0xebA89cA02449070b902A5DDc406eE709940e280E" in text
    assert "0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261" in text
    assert "0x8d7C954960a36a7596d7eA4945dDf891967ca8A3" in text
    assert 'AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"' in text
    assert 'SGX_GETH_AUTOMATA_DCAP_ATTESTATION="${SGX_GETH_AUTOMATA_DCAP_ATTESTATION:-${AUTOMATA_DCAP_ATTESTATION:-}}"' in text
    assert 'SGX_RETH_AUTOMATA_DCAP_ATTESTATION="${SGX_RETH_AUTOMATA_DCAP_ATTESTATION:-${AUTOMATA_DCAP_ATTESTATION:-}}"' in text
    assert 'deploy_secure_sgx_verifier "geth" "$SGX_GETH_AUTOMATA_DCAP_ATTESTATION"' in text
    assert 'deploy_secure_sgx_verifier "reth" "$SGX_RETH_AUTOMATA_DCAP_ATTESTATION"' in text
    assert "contracts/layer1/verifiers/SecureSgxVerifier.sol:SecureSgxVerifier" in text
    assert "SecureSgxGethVerifier" in text
    assert "SecureSgxRethVerifier" in text
    assert 'require_code "SGX geth Automata attester"' in text
    assert 'require_code "SGX reth Automata attester"' in text
    assert "must be different" in text
    assert 'FAKE_QUOTE_SMOKE="${FAKE_QUOTE_SMOKE:-true}"' in text
    assert 'cast call "$verifier" "registerInstance(bytes)" "$FAKE_SGX_QUOTE"' in text

    assert "SGX_BOOTSTRAP_JSON" not in text
    assert "setup_sgx_pccs_extras.sh" not in text
    assert "deploy_automata_dcap.sh" not in text
    assert "configure_sgx_verifier.sh" not in text
    assert "--mrenclave" not in text
    assert "--mrsigner" not in text
    assert "--quote" not in text
