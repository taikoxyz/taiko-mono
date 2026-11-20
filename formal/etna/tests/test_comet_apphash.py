"""Focused controls for W04's independent ABI and native receipt binding."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "conformance"
RUNNER = ROOT / "run_comet_apphash.py"
PROJECTION = ROOT / "comet_signed" / "public-votes.json"

if RUNNER.is_file():
    spec = importlib.util.spec_from_file_location("etna_test_comet_apphash", RUNNER)
    apphash = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(apphash)
else:
    apphash = None


class CometAppHashTest(unittest.TestCase):
    def require_runner(self):
        self.assertIsNotNone(apphash, "missing W04 independent encoder and receipt verifier")
        return apphash

    @staticmethod
    def fixture():
        names = json.loads(PROJECTION.read_bytes())
        points = [(names["voteKey"]["public_key"], names["voteKey"]["signer"])]
        points.extend((row["public_key"], row["ck_addr"]) for row in names["spectators"])
        members = [
            {"key": key[2:], "address": address[2:], "power": power, "priority": priority}
            for (key, address), power, priority in zip(points, (80, 19, 1), (-(1 << 63), -1, (1 << 63) - 1))
        ]
        return {"members": members[:2], "proposer": 1}, {"members": members[2:], "proposer": 0}

    def test_legacy_keccak_known_vectors(self):
        runner = self.require_runner()
        self.assertEqual(runner.keccak256(b"").hex(),
                         "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
        self.assertEqual(runner.keccak256(b"abc").hex(),
                         "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")

    def test_complete_abi_binds_order_offsets_and_signed_int64(self):
        runner = self.require_runner()
        current, next_set = self.fixture()
        el_hash = "32" * 32
        result = runner.encode_commitment(6, el_hash, current, next_set)
        preimage = result["val_bytes"]
        words = [preimage[start:start + 64] for start in range(0, len(preimage), 64)]
        a, b = current["members"]
        c, = next_set["members"]
        expected = [
            "45544e415f56414c5f53544154455f5631" + "00" * 15,
            f"{6:064x}", f"{192:064x}", f"{1:064x}", f"{480:064x}", "00" * 32,
            f"{2:064x}",
            f"{int(a['key'][:2], 16):064x}", a["key"][2:], f"{80:064x}", "ff" * 24 + "8000000000000000",
            f"{int(b['key'][:2], 16):064x}", b["key"][2:], f"{19:064x}", "ff" * 32,
            f"{1:064x}",
            f"{int(c['key'][:2], 16):064x}", c["key"][2:], f"{1:064x}", "00" * 24 + "7fffffffffffffff",
        ]
        self.assertEqual(words, expected)
        self.assertEqual(result["val_hash"], runner.keccak256(bytes.fromhex(preimage)).hex())
        self.assertEqual(result["app_bytes"], "45544e415f4150505f484153485f5631" + "00" * 16
                         + el_hash + result["val_hash"])
        self.assertEqual(len(result["app_bytes"]), 192)
        self.assertEqual(result["app_hash"], runner.keccak256(bytes.fromhex(result["app_bytes"])).hex())
        reordered = {"members": current["members"][::-1], "proposer": 1}
        self.assertNotEqual(runner.encode_commitment(6, el_hash, reordered, next_set)["val_bytes"], preimage)

    def test_priority_and_proposer_change_hash_without_changing_merkle(self):
        runner = self.require_runner()
        current, _ = self.fixture()
        independent = [
            {**current, "members": [{**current["members"][0], "priority": 5}, current["members"][1]]},
            {**current, "proposer": 0},
        ]
        baseline = runner.encode_commitment(6, "32" * 32, current, current)
        for changed in independent:
            self.assertEqual(runner.validator_merkle(current), runner.validator_merkle(changed))
            for sets in ((changed, current), (current, changed)):
                observed = runner.encode_commitment(6, "32" * 32, *sets)
                self.assertNotEqual(observed["val_bytes"], baseline["val_bytes"])
                self.assertNotEqual(observed["val_hash"], baseline["val_hash"])
                self.assertNotEqual(observed["app_hash"], baseline["app_hash"])

    def test_stale_header_apphash_and_pin_only_edits_do_not_bind(self):
        runner = self.require_runner()
        current, next_set = self.fixture()
        previous = runner.encode_commitment(5, "31" * 32, current, next_set)
        committed = runner.encode_commitment(6, "32" * 32, current, next_set)
        actual = {"header_s": previous["app_hash"], "post_s": committed}
        runner.require_receipt(actual, copy.deepcopy(actual))
        stale = copy.deepcopy(actual)
        stale["post_s"]["app_hash"] = stale["header_s"]
        with self.assertRaisesRegex(ValueError, "receipt"):
            runner.require_receipt(stale, actual)
        pin_edited = copy.deepcopy(actual)
        pin_edited["post_s"]["height"] = 5
        with self.assertRaisesRegex(ValueError, "receipt"):
            runner.require_receipt(actual, pin_edited)
        pin_edited["post_s"]["height"] = 6.0
        with self.assertRaisesRegex(ValueError, "receipt"):
            runner.require_receipt(actual, pin_edited)



    def test_priority_reference_and_raw_row_persistence(self):
        runner = self.require_runner()
        _, points, cases = runner.public_inputs()
        sets, changes = runner.expected_states(cases["late-rescale"], points)
        for height, priorities, proposer in ((3, [17, 91, -107], "A"), (5, [28, 24, -52], "A"),
                                             (8, [68, -19, -49], "B")):
            values, winner = sets[height]
            self.assertEqual([values[key][1] for key in "ABC"], priorities)
            self.assertEqual(winner, proposer)
        row = runner.expected_row(5, sets, changes, points)
        self.assertEqual(row["raw"], "1003")
        self.assertIsNone(row["stored"])
        self.assertEqual([m["priority"] for m in row["loaded"]["members"]], [77, 29, -105])
        self.assertEqual(row["loaded"]["merkle"], runner.set_view(sets[5], points)["merkle"])
        self.assertEqual(runner.varint(-1).hex(), "ff" * 9 + "01")

    def test_recovery_origin_order_offsets_and_membership(self):
        runner = self.require_runner()
        _, points, cases = runner.public_inputs()
        program = cases["recovery-origin"]
        sets, _ = runner.expected_states(program, points)
        self.assertEqual(sets[21][1], "B")
        state = runner.fixture_commitment(program, points, sets, 22)
        self.assertEqual(state["height"], 22)
        self.assertEqual(int(state["val_bytes"][64*4:64*5], 16), 192+32+4*128)
        self.assertEqual(len(sets[23][0]), 4)
        self.assertEqual(len(sets[24][0]), 3)

    def test_reject_duplicate_fields_and_nonintegers(self):
        runner = self.require_runner()
        for raw in ('{"height":1,"height":2}', '{"height":1.0}', '{"height":NaN}'):
            with self.assertRaises(ValueError):
                runner.read_json(raw)
        with self.assertRaises(ValueError):
            runner.require_receipt({"height": True}, {"height": 1})

    def test_directory_binds_filenames_and_complete_frame_bytes(self):
        import tempfile
        runner = self.require_runner()
        _, points, programs = runner.public_inputs()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            originals = {}
            for name, program in programs.items():
                sets, changes = runner.expected_states(program, points)
                initial, end = program["initial_height"], program["last_height"]
                projection = dict(schema="etna-apphash-projection-1", program=name,
                    program_sha256=runner.PROGRAM_SHA, projection_sha256=runner.PROJECTION_SHA,
                    observations=[dict(height=h, current=runner.set_view(sets[h+1],points),
                        next=runner.set_view(sets[h+2],points), commitment=runner.fixture_commitment(program,points,sets,h))
                        for h in range(initial-1,end+1)],
                    rows=[runner.expected_row(h,sets,changes,points) for h in range(initial,end+3)])
                for suffix, body in (("",projection),("-frames",runner.frame_program(name))):
                    key=name+suffix+".json"
                    originals[key]=json.dumps(body).encode()
                    (directory/key).write_bytes(originals[key])
            runner.verify_directory(directory)
            for suffix in ("", "-frames"):
                first, second = "late-rescale"+suffix+".json", "recovery-origin"+suffix+".json"
                (directory/first).write_bytes(originals[second])
                with self.assertRaisesRegex(ValueError, "filename and selected program"):
                    runner.verify_directory(directory)
                (directory/first).write_bytes(originals[first])
                (directory/second).write_bytes(originals[first])
                with self.assertRaisesRegex(ValueError, "filename and selected program"):
                    runner.verify_directory(directory)
                (directory/second).write_bytes(originals[second])
            path=directory/"late-rescale-frames.json"
            for key in ("genesis", "reopened"):
                wrong=json.loads(originals[path.name]);wrong[key]="00"+wrong[key][2:]
                path.write_text(json.dumps(wrong))
                with self.assertRaisesRegex(ValueError,"receipt value mismatch"):
                    runner.verify_directory(directory)
            path.write_bytes(originals[path.name]);runner.verify_directory(directory)

    def test_frame_shape_errors_are_controlled(self):
        runner = self.require_runner()
        for wrong in ([], None, True, {}, {"program":[]}, {"program":{}}):
            with self.assertRaises(ValueError): runner.verify_frames(wrong)

    def test_native_runtime_parser_binds_order_and_complete_diagnostics(self):
        native_spec=importlib.util.spec_from_file_location("etna_apphash_native_test",ROOT/"run_comet_apphash_native.py")
        native=importlib.util.module_from_spec(native_spec);native_spec.loader.exec_module(native)
        events=[];receipts={}
        def event(action,test=None,output=None):
            row=dict(Action=action,Package=native.PACKAGE)
            if test is not None: row["Test"]=test
            if output is not None: row["Output"]=output
            if action=="pass": row["Elapsed"]=0.042
            events.append(row)
        event("start");event("run","TestAppHash");event("output","TestAppHash","=== RUN   TestAppHash\n")
        for name in ("late-rescale","recovery-origin"):
            test="TestAppHash/"+name;event("run",test);event("output",test,"=== RUN   "+test+"\n")
            for suffix in ("","-frames"):
                key=name+suffix;receipts[key+".json"]=dict(bytes=123,sha256="ab"*32)
                event("output",test,"    apphash_test.go:123: receipt "+key+" 123 "+"ab"*32+"\n")
            event("output",test,"--- PASS: "+test+" (0.04s)\n");event("pass",test)
        event("output","TestAppHash","--- PASS: TestAppHash (0.08s)\n");event("pass","TestAppHash")
        event("output",output="PASS\n");event("output",output="ok  \t"+native.PACKAGE+"\t0.089s\n");event("pass")
        def raw(rows): return ("\n".join(json.dumps(e) for e in rows)+"\n").encode()
        native.native_outcomes(raw(events),0,receipts)
        wrong=copy.deepcopy(events);wrong[3],wrong[8]=wrong[8],wrong[3]
        with self.assertRaisesRegex(ValueError,"ordered native lifecycle"): native.native_outcomes(raw(wrong),0,receipts)
        wrong=copy.deepcopy(events);wrong[7]["Output"]="unrelated diagnostic\n"
        with self.assertRaisesRegex(ValueError,"leaf diagnostics"): native.native_outcomes(raw(wrong),0,receipts)
        wrong=copy.deepcopy(events);wrong[8]["Elapsed"]=-0.01
        with self.assertRaisesRegex(ValueError,"elapsed"): native.native_outcomes(raw(wrong),0,receipts)
        wrong=copy.deepcopy(events);wrong[5]["Output"]=wrong[5]["Output"].replace("ab"*32,"cd"*32)
        with self.assertRaisesRegex(ValueError,"receipt binding"): native.native_outcomes(raw(wrong),0,receipts)


if __name__ == "__main__":
    unittest.main()
