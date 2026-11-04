import { supabase } from "@/lib/supabase";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import i18n from "@/lib/i18n";

/**
 * Running a collection, shared by the Dashboard, the Collections tab and the
 * collection screen. Same steps as the iOS app (RunningOverlayStore).
 *
 * run-agent does the whole scan before it answers, so its reply already says
 * how the run ended. The app used to ignore that reply and poll the run row
 * until it changed, with no limit. Two things left that row "running" for
 * good, so Run All never finished on the phone:
 *  - a collection with no sources turned on: run-agent logs its own failed run
 *    and never touches the row the app made;
 *  - a run whose edge function died before finishing.
 * The web app doesn't wait for its runs, which is why it looked fast.
 */

export type RunOutcome = {
  status: "success" | "partial" | "failed" | "skipped";
  newCount: number;
  error?: string;
};

type RunAgentReply = {
  success?: boolean;
  skipped?: boolean;
  reason?: string;
  status?: string;
  videosNew?: number;
};

const POLL_MS = 1500;
// Supabase stops an edge function after 400 seconds. A run still "running"
// after this long is never going to finish, so stop waiting for it.
const MAX_WAIT_MS = 7 * 60 * 1000;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Insert the run row the overlay and History follow. */
export async function startRunRow(agentId: string): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from("runs")
    .insert({ agent_id: agentId, status: "running", started_at: new Date().toISOString() })
    .select("id")
    .single();
  if (error) throw error;
  return data as { id: string };
}

async function markFailed(runId: string, message: string) {
  await supabase
    .from("runs")
    .update({ status: "failed", finished_at: new Date().toISOString(), error_summary: message })
    .eq("id", runId);
}

/**
 * The gateway gives up after 150 seconds (504) while run-agent keeps going,
 * and a dropped connection doesn't stop it either. In both cases the run row
 * still finishes, so wait for it instead of calling the run failed.
 */
function mayStillBeRunning(error: unknown): boolean {
  const e = error as { name?: string; context?: { status?: number } };
  if (e?.name === "FunctionsFetchError") return true;
  if (e?.name === "FunctionsHttpError" && e.context?.status === 504) return true;
  return false;
}

/** Invoke run-agent for an existing run row and wait until the run ends. */
export async function runAgentAndWait(agentId: string, runId: string): Promise<RunOutcome> {
  const startedAt = Date.now();
  const { data, error } = await supabase.functions.invoke<RunAgentReply>("run-agent", {
    body: { agentId, runId },
  });

  if (!error) {
    if (data?.skipped) {
      // No sources turned on. run-agent already logged a failed run for it,
      // so drop the row the app made instead of leaving it "running".
      await supabase.from("runs").delete().eq("id", runId);
      return { status: "skipped", newCount: 0, error: i18n.t("runs.noSources") };
    }
    if (data?.status === "success" || data?.status === "partial") {
      return { status: data.status, newCount: data.videosNew ?? 0 };
    }
    // Any other reply: read the run row below.
  } else if (!mayStillBeRunning(error)) {
    const message = await extractEdgeFunctionErrorMessage(error);
    await markFailed(runId, message);
    return { status: "failed", newCount: 0, error: message };
  }

  while (Date.now() - startedAt < MAX_WAIT_MS) {
    const { data: row, error: rowError } = await supabase
      .from("runs")
      .select("status, videos_new_count, error_summary")
      .eq("id", runId)
      .maybeSingle();

    if (!rowError && !row) {
      return { status: "failed", newCount: 0, error: i18n.t("runs.unknownError") };
    }
    if (row) {
      const count = (row.videos_new_count as number) ?? 0;
      if (row.status === "success" || row.status === "partial") {
        return { status: row.status, newCount: count };
      }
      if (row.status === "failed" || row.status === "cancelled") {
        return {
          status: "failed",
          newCount: 0,
          error: (row.error_summary as string) || i18n.t("runs.unknownError"),
        };
      }
    }
    await sleep(POLL_MS);
  }

  const message = i18n.t("runs.timedOut");
  await markFailed(runId, message);
  return { status: "failed", newCount: 0, error: message };
}

/** Overlay message for a finished single run. */
export function outcomeMessage(outcome: RunOutcome): string {
  if (outcome.status === "partial") {
    return outcome.newCount > 0
      ? i18n.t("overlay.foundPartial", { count: outcome.newCount })
      : i18n.t("overlay.partialNone");
  }
  return outcome.newCount > 0
    ? i18n.t("runs.foundNew", { count: outcome.newCount })
    : i18n.t("runs.noNewFound");
}

export type BatchResult = { newTotal: number; failedNames: string[] };

/**
 * Run every collection at the same time and wait for all of them. Collections
 * with no sources turned on are skipped quietly; they aren't failures.
 */
export async function runAllAgents(
  agents: { id: string; name: string }[],
  onFinished: (agentName: string, done: number, total: number) => void,
): Promise<BatchResult> {
  const total = agents.length;
  let done = 0;
  let newTotal = 0;
  const failedNames: string[] = [];

  await Promise.all(
    agents.map(async (agent) => {
      try {
        const run = await startRunRow(agent.id);
        const outcome = await runAgentAndWait(agent.id, run.id);
        if (outcome.status === "failed") failedNames.push(agent.name);
        else newTotal += outcome.newCount;
      } catch {
        failedNames.push(agent.name);
      }
      done += 1;
      onFinished(agent.name, done, total);
    }),
  );

  return { newTotal, failedNames };
}
