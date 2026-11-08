import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { saveCSV } from "./utils.js";

test("saveCSV escapes quotes and both forms of line break", async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "bridged-token-csv-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const filename = path.join(directory, "tokens.csv");
  await saveCSV(filename, [
    { symbol: 'Token "A"' },
    { symbol: "one\rtwo" },
    { symbol: "one\ntwo" },
    { symbol: "one,two" },
    { symbol: "plain" },
    {},
  ], ["symbol"]);
  assert.equal(await readFile(filename, "utf8"),
    'symbol\n"Token ""A"""\n"one\rtwo"\n"one\ntwo"\n"one,two"\nplain\n');
});
