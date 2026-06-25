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

    assert "import { SecureSgxVerifier }" in script_text
    assert 'vm.envOr("SET_ATTRIBUTE_POLICY", false)' in script_text
    assert "function _envBytes16" in script_text
    assert "setEnclaveAttributePolicy(mrEnclave, mask, expected)" in script_text


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


def test_devnet_wrapper_runs_full_own_pccs_secure_sgx_flow():
    protocol_root = Path(__file__).resolve().parents[4]
    wrapper = protocol_root / "script/layer1/verifiers/deploy_devnet_sgx_own_pccs.sh"
    text = wrapper.read_text()

    assert 'DEVNET_ENV="${DEVNET_ENV:-/home/yue/works/taiko/raiko2-k8s/devnet.env}"' in text
    assert 'INTEL_API_SGX="${INTEL_API_SGX:-https://127.0.0.1:8081/sgx/certification/v4}"' in text
    assert 'PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-true}"' in text
    assert 'DEPLOY_DAIMO_P256="${DEPLOY_DAIMO_P256:-auto}"' in text
    assert "deploy_automata_dcap.sh" in text
    assert "setup_sgx_pccs_extras.sh" in text
    assert 'DEPLOY_SECURE_SGX_VERIFIER="${DEPLOY_SECURE_SGX_VERIFIER:-true}"' in text
    assert 'REGISTER_SECURE_SGX="${REGISTER_SECURE_SGX:-false}"' in text
    assert 'FAKE_QUOTE_SMOKE="${FAKE_QUOTE_SMOKE:-true}"' in text
    assert "fake SGX quote rejected as expected" in text
    assert 'cast call "$SECURE_SGX_VERIFIER" "registerInstance(bytes)" "$FAKE_SGX_QUOTE"' in text
    assert 'SKIP_SIMULATION=true' in text
    assert "SecureSgxVerifier.sol:SecureSgxVerifier" in text
    assert "configure_sgx_verifier.sh" in text
    assert "--attribute-policy" in text
    assert "--quote" in text
