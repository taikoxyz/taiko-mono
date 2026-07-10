import os
import stat
import subprocess
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]

SCRIPT_FILES = [
    SCRIPT_DIR / "configure_sgx_verifier.sh",
    SCRIPT_DIR / "deploy_automata_dcap.sh",
    SCRIPT_DIR / "setup_sgx_pccs_extras.sh",
    SCRIPT_DIR / "deploy_devnet_sgx_own_pccs.sh",
    SCRIPT_DIR / "deploy_sgx_verifiers_with_existing_automata.sh",
    SCRIPT_DIR / "README.md",
]


def _write_executable(path: Path, body: str) -> None:
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def test_configure_sgx_verifier_defaults_attribute_policy_when_trusting_mrenclave(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log_file = tmp_path / "commands.log"

    _write_executable(
        bin_dir / "cast",
        f"""#!/bin/sh
echo "cast $*" >> "{log_file}"
if [ "$1" = "call" ]; then
  echo "0"
fi
""",
    )
    _write_executable(
        bin_dir / "forge",
        f"""#!/bin/sh
echo "forge SET_ATTRIBUTE_POLICY=$SET_ATTRIBUTE_POLICY ATTRIBUTE_POLICY_MRENCLAVE=$ATTRIBUTE_POLICY_MRENCLAVE ATTRIBUTE_POLICY_MASK=$ATTRIBUTE_POLICY_MASK ATTRIBUTE_POLICY_EXPECTED=$ATTRIBUTE_POLICY_EXPECTED" >> "{log_file}"
""",
    )

    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{bin_dir}:{env['PATH']}",
            "PRIVATE_KEY": "0x" + "11" * 32,
            "FORK_URL": "https://example.invalid/rpc",
            "SGX_VERIFIER_ADDRESS": "0x" + "22" * 20,
        }
    )

    result = subprocess.run(
        [
            str(SCRIPT_DIR / "configure_sgx_verifier.sh"),
            "--mrenclave",
            "0x" + "33" * 32,
        ],
        cwd=SCRIPT_DIR.parents[2],
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr + result.stdout
    log = log_file.read_text()
    assert "enclaveAttributePolicyVersion(bytes32)(uint32)" in log
    assert "SET_ATTRIBUTE_POLICY=true" in log
    assert "ATTRIBUTE_POLICY_MASK=0xffffffffffffffff0000000000000000" in log
    assert "ATTRIBUTE_POLICY_EXPECTED=0x05000000000000000000000000000000" in log


def test_sgx_verifier_scripts_do_not_contain_local_private_paths():
    forbidden = [
        "/ho" + "me/",
        "provider" + "-log-check",
        "raiko2" + "-k8s",
        "/path" + "/to",
        "/pa" + "th/",
    ]

    for path in SCRIPT_FILES:
        assert path.exists(), f"missing expected script/doc: {path}"
        text = path.read_text()
        for marker in forbidden:
            assert marker not in text, f"{path} contains private/local marker {marker!r}"


def test_devnet_wrapper_requires_explicit_local_inputs():
    text = (SCRIPT_DIR / "deploy_devnet_sgx_own_pccs.sh").read_text()

    assert 'DEVNET_ENV="${DEVNET_ENV:-}"' in text
    assert 'SGX_BOOTSTRAP_JSON="${SGX_BOOTSTRAP_JSON:-}"' in text
    assert "DEVNET_ENV is not set" in text
    assert "SGX_BOOTSTRAP_JSON is not set" in text


def test_devnet_wrapper_registers_quotes_with_attributes_policy():
    text = (SCRIPT_DIR / "deploy_devnet_sgx_own_pccs.sh").read_text()

    assert "--attribute-policy" in text
    assert "--mrenclave" in text
    assert "--mrsigner" in text
    assert "--quote" in text


def test_deploy_automata_exports_selected_p256_in_summary():
    text = (SCRIPT_DIR / "deploy_automata_dcap.sh").read_text()

    assert 'P256="$P256_RIP7212_PRECOMPILE"' in text
    assert 'P256="$DAIMO_P256"' in text
    assert "--arg p256" in text
    assert "p256: $p256" in text


def test_devnet_wrapper_passes_deployed_p256_to_sgx_pccs_setup():
    text = (SCRIPT_DIR / "deploy_devnet_sgx_own_pccs.sh").read_text()

    assert "P256=$(jq -r '.p256 // empty' \"$OUTPUT_JSON\")" in text
    assert "missing P256 in $OUTPUT_JSON" in text
    assert 'P256="$P256" \\' in text


def test_deploy_automata_defaults_to_pinned_automata_refs():
    text = (SCRIPT_DIR / "deploy_automata_dcap.sh").read_text()

    assert 'AUTOMATA_PCCS_REF="${AUTOMATA_PCCS_REF:-main}"' not in text
    assert 'AUTOMATA_DCAP_REF="${AUTOMATA_DCAP_REF:-main}"' not in text
    assert "7bcb8c7ee6dfb91923c70a32d047db18f3eced1b" in text
    assert "ae7d6c480a5cf06bd5b3d9e16bb7461b93deda14" in text


def test_setup_sgx_pccs_extras_does_not_match_bare_already_errors():
    text = (SCRIPT_DIR / "setup_sgx_pccs_extras.sh").read_text()

    assert "AlreadyExists|already|" not in text
    assert "Duplicate_Collateral" in text


def test_setup_sgx_pccs_extras_sorts_tcb_eval_numbers_before_selecting_standard():
    text = (SCRIPT_DIR / "setup_sgx_pccs_extras.sh").read_text()

    assert "eligible = []" in text
    assert "eligible.sort(" in text
