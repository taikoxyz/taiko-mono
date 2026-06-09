import { promises as fs } from "fs";
import path from "path";

/**
 * Minimal `.env` loader that mirrors `dotenv.config()` closely enough for the
 * config generators (the original vite plugins call `dotenv.config()`).
 *
 * - Loads `.env` from the given cwd (default: process.cwd()).
 * - Does NOT override variables already present in process.env.
 * - Strips surrounding single/double quotes from values.
 * - Silently no-ops if the file does not exist.
 *
 * We avoid adding the `dotenv` dependency (not installed in bridge-ui-next).
 * Next.js itself loads `.env*` for the app runtime; this loader only exists so
 * the standalone prebuild generator can read the base64 CONFIGURED_* vars.
 */
export async function loadEnv(cwd = process.cwd()) {
  const envPath = path.join(cwd, ".env");
  let raw;
  try {
    raw = await fs.readFile(envPath, "utf-8");
  } catch {
    return; // no .env file — rely on the ambient process.env
  }

  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    // Support an optional leading `export ` (the exporter writes `export KEY=...`).
    const withoutExport = trimmed.startsWith("export ")
      ? trimmed.slice("export ".length)
      : trimmed;

    const eq = withoutExport.indexOf("=");
    if (eq === -1) continue;

    const key = withoutExport.slice(0, eq).trim();
    let value = withoutExport.slice(eq + 1).trim();

    // Strip a single layer of surrounding quotes.
    if (
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))
    ) {
      value = value.slice(1, -1);
    }

    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}
