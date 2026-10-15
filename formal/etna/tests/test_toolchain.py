import importlib.util
import pathlib
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


if __name__ == '__main__':
    unittest.main()
