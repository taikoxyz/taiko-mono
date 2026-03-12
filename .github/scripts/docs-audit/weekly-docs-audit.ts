import { writeFile } from "node:fs/promises";
import path from "node:path";

import { query } from "@anthropic-ai/claude-agent-sdk";

const DAYS_TO_REVIEW = 7;
const AUDIT_CONTEXT_FILE = ".github/tmp/weekly-docs-context.md";
const DEFAULT_AUDIT_SUMMARY_PATH = ".github/tmp/weekly-docs-audit-summary.md";

const EDITABLE_DOC_BASENAMES = new Set(["AGENTS.md", "CLAUDE.md", "README.md"]);
const WRITE_TOOL_NAMES = new Set(["Edit", "Write", "MultiEdit"]);
const ALLOWED_TOOL_NAMES = new Set(["Read", "Glob", "Grep", "Edit", "Write"]);

type AgentResultMessage = {
  type: "result";
  subtype: string;
  result?: unknown;
};

function assertAnthropicApiKey(): void {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new Error("ANTHROPIC_API_KEY is required.");
  }
}

function getDateWindow(days: number): { fromDate: string; toDate: string } {
  const now = new Date();
  const start = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  return {
    fromDate: start.toISOString().slice(0, 10),
    toDate: now.toISOString().slice(0, 10),
  };
}

function buildPrompt(fromDate: string, toDate: string): string {
  return `You are running a weekly documentation freshness audit.

Analyze repository changes from ${fromDate} to ${toDate} and update docs only when needed.

Before making any edits, read ${AUDIT_CONTEXT_FILE} for the precomputed commit/file context from the last 7 days.
Use that file as your source of truth for what changed.

Criteria:
1) Identify important additions that are not documented.
2) Identify removals/obsolete items that should be removed from docs.
3) Improve clarity when docs are too large, repetitive, or unclear.

Required workflow:
- Focus on meaningful product, architecture, command, or workflow changes.
- Keep edits concise and preserve existing style.
- If no clear documentation improvement is needed, do not modify files.

Allowed file edits:
- **/AGENTS.md
- **/CLAUDE.md
- **/README.md
- files under any docs/ directory

Hard constraints:
- Do not edit source code, tests, CI workflows, lock files, or package manifests.
- Do not create placeholder or speculative docs.

At the end, provide a short summary of findings and changed files.`;
}

function isResultMessage(message: unknown): message is AgentResultMessage {
  return (
    typeof message === "object" &&
    message !== null &&
    "type" in message &&
    (message as { type?: unknown }).type === "result"
  );
}

function extractPathFromToolInput(input: Record<string, unknown>): string | null {
  const candidate = input.file_path ?? input.path;
  return typeof candidate === "string" ? candidate : null;
}

function isDocsPath(repoRoot: string, filePath: string): boolean {
  const resolvedPath = path.resolve(repoRoot, filePath);
  const relativePath = path.relative(repoRoot, resolvedPath);

  if (!relativePath || relativePath.startsWith("..") || path.isAbsolute(relativePath)) {
    return false;
  }

  const normalizedPath = relativePath.split(path.sep).join("/");
  const basename = path.posix.basename(normalizedPath);

  if (EDITABLE_DOC_BASENAMES.has(basename)) {
    return true;
  }

  return normalizedPath.split("/").includes("docs");
}

async function main(): Promise<void> {
  assertAnthropicApiKey();
  const repoRoot = process.env.REPO_ROOT ?? process.cwd();

  const { fromDate, toDate } = getDateWindow(DAYS_TO_REVIEW);
  const prompt = buildPrompt(fromDate, toDate);

  const run = query({
    prompt,
    options: {
      cwd: repoRoot,
      tools: ["Read", "Glob", "Grep", "Edit", "Write"],
      allowedTools: ["Read", "Glob", "Grep", "Edit", "Write"],
      maxTurns: 30,
      permissionMode: "dontAsk",
      canUseTool: async (toolName, input) => {
        if (!ALLOWED_TOOL_NAMES.has(toolName)) {
          return {
            behavior: "deny",
            message: `Tool ${toolName} is not allowed for docs audit.`,
          };
        }

        if (WRITE_TOOL_NAMES.has(toolName)) {
          const targetPath = extractPathFromToolInput(input);

          if (!targetPath || !isDocsPath(repoRoot, targetPath)) {
            return {
              behavior: "deny",
              message: "Docs audit may only write to AGENTS.md, CLAUDE.md, README.md, or docs/ files.",
            };
          }
        }

        return { behavior: "allow" };
      },
      settingSources: ["project"],
      systemPrompt: { type: "preset", preset: "claude_code" },
    },
  });

  let finalResult: AgentResultMessage | undefined;

  for await (const message of run) {
    if (isResultMessage(message)) {
      finalResult = message;
    }
  }

  if (!finalResult) {
    throw new Error("No result returned from Anthropic Agent SDK.");
  }

  if (finalResult.subtype !== "success") {
    throw new Error(`Docs audit agent failed: ${JSON.stringify(finalResult, null, 2)}`);
  }

  const summaryPath = process.env.AUDIT_SUMMARY_PATH
    ? path.resolve(process.env.AUDIT_SUMMARY_PATH)
    : path.resolve(repoRoot, DEFAULT_AUDIT_SUMMARY_PATH);
  const summary =
    typeof finalResult.result === "string" && finalResult.result.trim()
      ? finalResult.result.trim()
      : "No summary returned by docs audit agent.";

  await writeFile(summaryPath, `${summary}\n`, "utf8");
  console.log(summary);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
