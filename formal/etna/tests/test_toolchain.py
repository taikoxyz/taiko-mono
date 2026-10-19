import importlib.util
import pathlib
import json
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ToolchainTests(unittest.TestCase):
    def test_pin_mismatch_rejected(self):
        spec = importlib.util.spec_from_file_location('pins', ROOT / 'scripts/check_toolchain.py')
        pins = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pins)
        with self.assertRaisesRegex(ValueError, 'pin mismatch'):
            pins.require_equal('charon', 'wrong', 'expected')

    def test_inventory_skips_push_payload_and_metadata(self):
        spec = importlib.util.spec_from_file_location('inventory', ROOT / 'scripts/solidity_inventory.py')
        inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(inventory)
        # PUSH2 payload contains CALL and SSTORE; metadata also contains CALL.
        ops, length = inventory.disassemble(bytes.fromhex('61f155f4a1f10002'))
        self.assertEqual(length, 4)
        self.assertEqual([x['opcode'] for x in ops], ['PUSH2', 'DELEGATECALL'])


class SolidityProvenanceTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('inventory', ROOT / 'scripts/solidity_inventory.py')
        self.inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.inventory)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.checkout = pathlib.Path(self.temp.name)
        (self.checkout / 'contracts').mkdir()
        self.source = self.checkout / 'contracts/Inbox.sol'
        self.source.write_text('pragma solidity ^0.8.30;')
        for command in [['git','init','-q'],['git','add','.'],['git','-c','user.email=test@example.com','-c','user.name=Test','commit','-qm','fixture']]:
            subprocess.run(command, cwd=self.checkout, check=True, capture_output=True)
        self.revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=self.checkout,text=True).strip()
        digest = subprocess.check_output(['cast','keccak','0x'+self.source.read_bytes().hex()],text=True).strip()
        self.metadata = {'sources':{'contracts/Inbox.sol':{'keccak256':digest}}, 'settings':{'compilationTarget':{'contracts/Inbox.sol':'Inbox'}}}

    def test_records_validated_revision_and_source_hashes(self):
        result = self.inventory.validate_sources(self.metadata, self.checkout, self.revision)
        self.assertEqual(result['source_revision'], self.revision)
        self.assertEqual(result['source_hashes'], self.metadata['sources'])

    def test_rejects_artifact_source_drift(self):
        self.source.write_text('pragma solidity ^0.8.29;')
        with self.assertRaisesRegex(ValueError, 'source hash mismatch'):
            self.inventory.validate_sources(self.metadata, self.checkout, self.revision)

    def test_rejects_rehashed_uncommitted_source(self):
        self.source.write_text('pragma solidity ^0.8.29;')
        digest = subprocess.check_output(['cast', 'keccak', '0x' + self.source.read_bytes().hex()], text=True).strip()
        self.metadata['sources']['contracts/Inbox.sol']['keccak256'] = digest
        with self.assertRaisesRegex(ValueError, 'source differs from pinned git blob'):
            self.inventory.validate_sources(self.metadata, self.checkout, self.revision)

    def test_rejects_wrong_source_revision(self):
        with self.assertRaisesRegex(ValueError, 'revision mismatch'):
            self.inventory.validate_sources(self.metadata, self.checkout, '0' * 40)

    def test_dummy_external_call_semantics_are_material_gap(self):
        gaps = self.inventory.capability_gaps('gas and EXTCODESIZE', '-- TODO: These are just dummy implementations\n| .Call => x\n| .Staticcall => x\n| .Delegatecall => x\n| .Log1 => x')
        self.assertTrue(any('dummy' in gap and 'CALL' in gap and 'log' in gap for gap in gaps))


if __name__ == '__main__':
    unittest.main()
