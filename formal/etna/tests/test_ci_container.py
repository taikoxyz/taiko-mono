"""Resource-side-effect regressions for the Docker adapter, without a socket."""
import argparse
import importlib.util
import json
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ADAPTER = Path(__file__).resolve().parents[1] / "ci_container.py"
SENTINEL_IMAGE = "sha256:" + "c" * 64
SENTINEL_CONTAINER = "d" * 64
FAKE_DOCKER = r'''
import json,pathlib,sys,time
path=pathlib.Path(__file__).with_suffix('.json')
args=sys.argv[1:]
if args[:1]==['--config']:args=args[2:]
s=json.loads(path.read_text())
def save():path.write_text(json.dumps(s))
def fail(text):print(text);sys.exit(1)
if args[0]=='version':print('{}')
elif args[0]=='import':
 owner=args[args.index('--change')+1].split('=',1)[1]
 s['images']['sha256:'+'a'*64]={'owner':owner};save()
 if s['mode']=='import-fail':fail('accepted import, reply failed')
 print('sha256:'+'a'*64)
elif args[0]=='create':
 name=args[args.index('--name')+1]
 if any(v.get('name')==name for v in s['containers'].values()):fail('name collision')
 owner=args[args.index('--label')+1].split('=',1)[1]
 s['containers']['b'*64]={'owner':owner,'name':name,'running':False,'exit':0};save();print('b'*64)
elif args[0]=='start':
 identity=args[-1];s['containers'][identity]['running']=True;save()
 if s['mode']=='timeout':
  while identity in json.loads(path.read_text())['containers']:time.sleep(.02)
  sys.exit(137)
 s['containers'][identity]['running']=False
 s['containers'][identity]['exit']=7 if s['mode']=='start-fail' else 0;save()
 sys.exit(s['containers'][identity]['exit'])
elif args[0] in ('container','image'):
 kind,operation=args[:2];entries=s['containers' if kind=='container' else 'images']
 if operation=='ls':
  if s['mode']=='cleanup-fail' and kind=='container':fail('transport unavailable')
  owner=args[args.index('--filter')+1].split('=',2)[2]
  print('\n'.join(k for k,v in entries.items() if v['owner']==owner))
 elif operation=='inspect':
  identity=args[-1]
  if identity not in entries:fail('missing resource')
  v=entries[identity]
  print(json.dumps([{'Id':identity,'Config':{'Labels':{'io.taiko.etna-ci.owner':v['owner']}},'State':{'Running':v.get('running',False),'ExitCode':v.get('exit',0)}}]))
 elif operation=='rm':entries.pop(args[-1],None);save()
 else:fail('unsupported operation')
else:fail('unsupported command')
'''


class ContainerLifecycleTests(unittest.TestCase):
    def run_profile(self, mode, collision=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("source", "java", "output"):
                (root / name).mkdir()
            (root / "source/formal/etna").mkdir(parents=True)
            (root / "source/formal/etna/ci.py").write_text("raise SystemExit(0)\n")
            (root / "java/bin").mkdir()
            (root / "java/bin/java").write_text("#!/bin/sh\nexit 0\n")
            (root / "java/bin/java").chmod(0o755)
            (root / "jar").write_bytes(b"supplied tool")
            docker = root / "docker"
            docker.write_text("#!" + sys.executable + "\n" + FAKE_DOCKER)
            docker.chmod(0o755)
            state = dict(mode=mode, images={SENTINEL_IMAGE: {"owner": "unrelated"}},
                         containers={SENTINEL_CONTAINER: {"owner": "unrelated", "name": "sentinel"}})
            docker.with_suffix(".json").write_text(json.dumps(state))
            result = subprocess.run([
                sys.executable, "-B", str(ADAPTER), "--docker", str(docker),
                "--source", str(root / "source"), "--java-home", str(root / "java"),
                "--tlc-jar", str(root / "jar"), "--output-dir", str(root / "output"),
                "--runtime-dir", str(root / "runtime"), "--timeout", "1",
                "--container-name", "sentinel" if collision else "fixture",
            ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            report = root / "output/container-status.json"
            self.assertTrue(report.is_file(), result.stdout.decode())
            return result.returncode, json.loads(report.read_text()), json.loads(docker.with_suffix(".json").read_text())

    def assert_sentinels_preserved(self, state):
        self.assertEqual(state["images"].get(SENTINEL_IMAGE), {"owner": "unrelated"})
        self.assertEqual(state["containers"].get(SENTINEL_CONTAINER), {"owner": "unrelated", "name": "sentinel"})

    def assert_only_sentinels(self, state):
        self.assert_sentinels_preserved(state)
        self.assertEqual(len(state["images"]), 1)
        self.assertEqual(len(state["containers"]), 1)

    def test_success_cleans_owned_resources_and_preserves_unrelated(self):
        code, report, state = self.run_profile("success")
        self.assertEqual(code, 0, report)
        self.assertTrue(report["cleanup_ok"])
        self.assert_only_sentinels(state)

    def test_accepted_import_with_failed_reply_is_recovered_by_owner_label(self):
        code, report, state = self.run_profile("import-fail")
        self.assertNotEqual(code, 0)
        self.assertTrue(report["cleanup_ok"])
        self.assert_only_sentinels(state)

    def test_name_collision_preserves_the_existing_container(self):
        code, report, state = self.run_profile("success", collision=True)
        self.assertNotEqual(code, 0)
        self.assertTrue(report["cleanup_ok"])
        self.assert_only_sentinels(state)

    def test_start_failure_cleans_owned_resources(self):
        code, report, state = self.run_profile("start-fail")
        self.assertNotEqual(code, 0)
        self.assertTrue(report["cleanup_ok"])
        self.assert_only_sentinels(state)

    def test_timeout_cleans_owned_resources(self):
        code, report, state = self.run_profile("timeout")
        self.assertEqual(code, 124, report)
        self.assertTrue(report["cleanup_ok"])
        self.assert_only_sentinels(state)

    def test_unverifiable_cleanup_prevents_success(self):
        code, report, state = self.run_profile("cleanup-fail")
        self.assertNotEqual(code, 0)
        self.assertFalse(report["cleanup_ok"])
        self.assert_sentinels_preserved(state)


class BindingBoundaryTests(unittest.TestCase):
    def refuse(self, field, forbidden=None, executable=True):
        spec = importlib.util.spec_from_file_location("container_boundary", ADAPTER)
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("source", "java", "output", "home", "checkout"):
                (root / name).mkdir()
            for name in ("source", "home", "checkout"):
                (root / name / "formal/etna").mkdir(parents=True)
                (root / name / "formal/etna/ci.py").write_text("raise SystemExit(0)\n")
            for name in ("java", "home", "checkout"):
                (root / name / "bin").mkdir()
                tool = root / name / "bin/java"
                tool.write_text("#!/bin/sh\nexit 0\n")
                tool.chmod(0o755 if executable else 0o644)
            (root / "checkout/.git").write_text("disposable Git metadata marker\n")
            (root / "jar").write_bytes(b"supplied tool")
            marker = root / "docker-was-invoked"
            docker = root / "docker"
            docker.write_text("#!" + sys.executable + "\nfrom pathlib import Path\n"
                              + "Path(" + repr(str(marker)) + ").write_text('called')\nraise SystemExit(1)\n")
            docker.chmod(0o755)
            args = argparse.Namespace(source=root / "source", java_home=root / "java",
                                      tlc_jar=root / "jar", output_dir=root / "output",
                                      runtime_dir=root / "runtime", docker=str(docker),
                                      container_name=None, timeout=1)
            if forbidden is not None:
                setattr(args, field, root / forbidden)
            handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
            try:
                with mock.patch.object(adapter.Path, "home", return_value=root / "home"):
                    with self.assertRaises(ValueError):
                        adapter.run(args)
                self.assertFalse(marker.exists(), "forbidden binding reached the Docker boundary")
            finally:
                for sig, handler in handlers.items():
                    signal.signal(sig, handler)

    def test_every_configurable_bind_refuses_home_and_git_before_docker(self):
        for field, forbidden in (("source", "home"), ("source", "checkout"),
                                 ("java_home", "home"), ("java_home", "checkout"),
                                 ("tlc_jar", "checkout/.git"),
                                 ("output_dir", "home"), ("output_dir", "checkout")):
            with self.subTest(field=field, forbidden=forbidden):
                self.refuse(field, forbidden)

    def test_java_executable_is_required_before_docker(self):
        self.refuse("java_home", executable=False)


if __name__ == "__main__":
    unittest.main()
