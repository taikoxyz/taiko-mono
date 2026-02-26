import { query } from "@anthropic-ai/claude-agent-sdk";

const DAYS_TO_REVIEW = 7;

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

Criteria:
1) Identify important additions that are not documented.
2) Identify removals/obsolete items that should be removed from docs.
3) Improve clarity when docs are too large, repetitive, or unclear.

Required workflow:
- Use git history/diff from the last 7 days to understand what changed.
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

async function main(): Promise<void> {
  assertAnthropicApiKey();

  const { fromDate, toDate } = getDateWindow(DAYS_TO_REVIEW);
  const prompt = buildPrompt(fromDate, toDate);

  const run = query({
    prompt,
    options: {
      cwd: process.cwd(),
      allowedTools: ["Read", "Edit", "Write", "Glob", "Grep", "Bash"],
      maxTurns: 30,
      permissionMode: "bypassPermissions",
      allowDangerouslySkipPermissions: true,
      settingSources: ["project", "user"],
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

  if (typeof finalResult.result === "string" && finalResult.result.trim()) {
    console.log(finalResult.result.trim());
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
