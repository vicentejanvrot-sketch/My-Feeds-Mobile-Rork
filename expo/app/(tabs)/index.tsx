import { useMemo, useState, useCallback, useEffect, useRef } from "react";
import { useQueryClient } from "@tanstack/react-query";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from "react-native";
import { useRouter, useFocusEffect } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import * as Haptics from "expo-haptics";
import {
  Bot,
  Video,
  Layers,
  Activity,
  TrendingUp,
  Rss,
  Play,
  Clock,
  CheckCircle2,
  Circle,
  Clock4,
  MoreVertical,
  Sparkles,
  Users,
  ChevronRight,
  ChevronDown,
} from "lucide-react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Trans, useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";

const statIconBlue = "hsl(199, 89%, 55%)" as const;
// Light red for the ? button, so it's easy to spot without shouting.
const HELP_RED = "#FF8A8A";
const statIconBg = "hsla(199, 89%, 55%, 0.16)" as const;
import {
  useAgents,
  useRuns,
  useRunStats,
  useItems,
  useChannelsAll,
  useStartRun,
  useDeleteAgent,
  useDashboardRealtime,
  useAgentItemCounts,
  getAgentColor,
  qk,
  extractEdgeFunctionErrorMessage,
} from "@/lib/hooks";
import { supabase } from "@/lib/supabase";
import { timeAgo, relativeTime, compactNumber } from "@/lib/format";
import { useToast } from "@/components/Toast";
import { StatusPill } from "@/components/StatusPill";
import WatchTimeStats from "@/components/WatchTimeStats";
import { useRunningOverlay } from "@/lib/running-overlay";
import type { ItemStatus, Run, Channel } from "@/lib/database";
import { OnboardingWizard, type OnboardingResult } from "@/components/onboarding/OnboardingWizard";
import { useAuth } from "@/lib/auth-provider";
import {
  HIDE_ONBOARDING_KEY,
  markOnboardingShown,
  setOnboardingHidden,
  shouldAutoOpenOnboarding,
} from "@/lib/onboarding";

const IPAD_BREAKPOINT = 768;

// The Feeds and My Collections sections open and close. They start closed,
// and how the user left them is kept on the phone, so the dashboard looks the
// same when they come back from a feed. Same on the web app and iOS.
const SECTIONS_KEY = "dashboard.sections";
type Sections = { feeds: boolean; collections: boolean };

function useDashboardSections() {
  const [sections, setSections] = useState<Sections>({ feeds: false, collections: false });
  useEffect(() => {
    void AsyncStorage.getItem(SECTIONS_KEY)
      .then((raw) => {
        if (!raw) return;
        const saved = JSON.parse(raw);
        setSections({ feeds: saved?.feeds === true, collections: saved?.collections === true });
      })
      .catch(() => undefined);
  }, []);
  const toggle = useCallback((key: keyof Sections) => {
    void Haptics.selectionAsync().catch(() => undefined);
    setSections((prev) => {
      const next = { ...prev, [key]: !prev[key] };
      void AsyncStorage.setItem(SECTIONS_KEY, JSON.stringify(next)).catch(() => undefined);
      return next;
    });
  }, []);
  return { sections, toggle };
}

export default function DashboardScreen() {
  const { sections, toggle: toggleSection } = useDashboardSections();
  const insets = useSafeAreaInsets();
  const { width: windowWidth } = useWindowDimensions();
  const isWide = windowWidth >= IPAD_BREAKPOINT;
  const router = useRouter();
  const showToast = useToast();
  const { t } = useTranslation();

  const agents = useAgents();
  const runs = useRuns(50);
  // Recent Runs and Success Rate come from the database (last 7 days), the
  // same numbers the web app and iOS show.
  const runStats = useRunStats();
  const items = useItems("all");
  const channels = useChannelsAll();
  const runAgent = useStartRun();
  const deleteAgent = useDeleteAgent();
  const overlay = useRunningOverlay();
  const queryClient = useQueryClient();

  useDashboardRealtime(!overlay.state.status);

  const scrollRef = useRef<ScrollView>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

  // Onboarding wizard: opens by itself once per launch until the user ticks
  // "Don't show this again"; the ? button next to the title opens it any time.
  const { user } = useAuth();
  const onboardingHidden = user?.user_metadata?.[HIDE_ONBOARDING_KEY] === true;
  const [wizardOpen, setWizardOpen] = useState(false);
  // A new key gives the wizard fresh state each time it opens.
  const [wizardKey, setWizardKey] = useState(0);
  const openWizard = useCallback(() => {
    markOnboardingShown();
    setWizardKey((k) => k + 1);
    setWizardOpen(true);
  }, []);
  useEffect(() => {
    let cancelled = false;
    void shouldAutoOpenOnboarding().then((open) => {
      if (open && !cancelled) openWizard();
    });
    return () => {
      cancelled = true;
    };
  }, [openWizard]);
  const handleHiddenChange = useCallback(
    async (hidden: boolean) => {
      const message = await setOnboardingHidden(hidden);
      if (message) showToast(t("dashboard.settingSaveFailed", { message }), "error");
    },
    [showToast, t],
  );

  useFocusEffect(
    useCallback(() => {
      scrollRef.current?.scrollTo({ y: 0, animated: false });
    }, []),
  );

  const refreshing =
    agents.isRefetching ||
    runs.isRefetching ||
    runStats.isRefetching ||
    items.isRefetching ||
    channels.isRefetching;
  const onRefresh = useCallback(() => {
    void agents.refetch();
    void runs.refetch();
    void runStats.refetch();
    void items.refetch();
    void channels.refetch();
  }, [agents, runs, runStats, items, channels]);

  // ── derived stats ──────────────────────────────────────────────
  const listUnsorted = agents.data ?? [];
  const list = useMemo(
    () =>
      [...listUnsorted].sort((a, b) =>
        a.name.localeCompare(b.name, undefined, { sensitivity: "base" }),
      ),
    [listUnsorted],
  );
  const agentIds = useMemo(() => list.map((a) => a.id), [list]);
  const agentCounts = useAgentItemCounts(agentIds);

  const runList = runs.data ?? [];
  const itemList = items.data ?? [];
  const channelList = channels.data ?? [];

  const perAgentChannels = useMemo(() => {
    const map: Record<string, Channel[]> = {};
    for (const ch of channelList) {
      if (!map[ch.agent_id]) map[ch.agent_id] = [];
      map[ch.agent_id].push(ch);
    }
    return map;
  }, [channelList]);

  const perAgentItems = useMemo(() => {
    const map: Record<string, { total: number; watched: number; unwatched: number; watchLater: number; liked: number }> = {};
    for (const it of itemList) {
      const idx = it.agent_id;
      if (!map[idx]) map[idx] = { total: 0, watched: 0, unwatched: 0, watchLater: 0, liked: 0 };
      map[idx].total += 1;
      if (it.user_status === "watched") map[idx].watched += 1;
      else if (it.user_status === "not_watched" || !it.user_status) map[idx].unwatched += 1;
      else if (it.user_status === "watch_later") map[idx].watchLater += 1;
      else if (it.user_status === "liked") map[idx].liked += 1;
    }
    return map;
  }, [itemList]);

  const perAgentLastRun = useMemo(() => {
    const map: Record<string, Run> = {};
    for (const r of runList) {
      if (!map[r.agent_id] && r.status === "success") map[r.agent_id] = r;
    }
    return map;
  }, [runList]);

  const recentRuns = runStats.data?.runs ?? 0;
  const successRate = runStats.data?.success_rate ?? null;

  // ── run triggers ────────────────────────────────────────────────
  type RunResult = { failed: boolean; newCount: number; error?: string };

  /** Invoke run-agent for an existing run row and wait until it finishes.
   *  Does not touch the overlay, so Run All can use it for every agent at once. */
  const executeRun = useCallback(
    async (agentId: string, runId: string): Promise<RunResult> => {
      const { error } = await supabase.functions.invoke("run-agent", {
        body: { agentId, runId },
      });
      if (error) {
        const message = await extractEdgeFunctionErrorMessage(error);
        await supabase
          .from("runs")
          .update({
            status: "failed",
            finished_at: new Date().toISOString(),
            error_summary: message,
          })
          .eq("id", runId);
        return { failed: true, newCount: 0, error: message };
      }

      // Poll the runs table until the edge function finishes processing.
      // "partial" is a finished run too; it used to be missed here, which
      // left Run All waiting forever.
      while (true) {
        const { data: polled } = await supabase
          .from("runs")
          .select("status, videos_new_count, error_summary")
          .eq("id", runId)
          .single();

        if (polled) {
          const count = (polled.videos_new_count as number) ?? 0;
          if (polled.status === "success" || polled.status === "partial") {
            return { failed: false, newCount: count };
          }
          if (polled.status === "failed" || polled.status === "cancelled") {
            return {
              failed: true,
              newCount: 0,
              error: (polled.error_summary as string) || t("runs.unknownError"),
            };
          }
        }
        await new Promise((r) => setTimeout(r, 1500));
      }
    },
    [t],
  );

  const runOne = useCallback(
    async (agentId: string, agentName: string) => {
      // Insert the run row first so we have a runId for the overlay + Realtime.
      const run = await runAgent.mutateAsync(agentId);
      // Show the overlay immediately; live progress arrives via Realtime.
      overlay.showRunning(agentName, run.id);

      const result = await executeRun(agentId, run.id);
      if (result.failed) {
        overlay.showError(agentName, result.error ?? t("runs.unknownError"));
      } else {
        overlay.showSuccess(
          agentName,
          result.newCount > 0 ? t("runs.foundNew", { count: result.newCount }) : t("runs.noNewFound"),
        );
      }
      void queryClient.invalidateQueries({ queryKey: qk.runs });
    },
    [runAgent, overlay, queryClient, executeRun, t],
  );

  const triggerRun = useCallback(
    async (agentId: string) => {
      const agent = list.find((a) => a.id === agentId);
      const agentName = agent?.name ?? t("dashboard.collectionFallback");
      void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      setPendingId(agentId);
      try {
        await runOne(agentId, agentName);
      } catch (e) {
        const msg = e instanceof Error ? e.message : t("runs.startFailed");
        overlay.showError(agentName, msg);
      } finally {
        setPendingId(null);
      }
    },
    [list, runOne, overlay, t],
  );

  const triggerRunAll = useCallback(async () => {
    if (list.length === 0) return;
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setPendingId("all");

    // Start every agent at the same time, like the web app. Running them one
    // after another made Run All take the sum of every agent's duration.
    const total = list.length;
    const label = t("dashboard.allCollectionsCount", { count: total });
    let done = 0;
    let newTotal = 0;
    const failedNames: string[] = [];
    overlay.showBatchProgress(label, 0, total, t("dashboard.runningAll"));

    await Promise.all(
      list.map(async (agent) => {
        try {
          const run = await runAgent.mutateAsync(agent.id);
          const result = await executeRun(agent.id, run.id);
          if (result.failed) failedNames.push(agent.name);
          else newTotal += result.newCount;
        } catch {
          failedNames.push(agent.name);
        }
        done += 1;
        overlay.showBatchProgress(label, done, total, t("dashboard.collectionFinished", { name: agent.name }));
      }),
    );

    void queryClient.invalidateQueries({ queryKey: qk.runs });
    const found = newTotal > 0 ? t("runs.foundNew", { count: newTotal }) : t("runs.noNewFound");
    if (failedNames.length > 0) {
      overlay.showError(label, t("dashboard.foundWithFailures", { found, names: failedNames.join(", ") }));
    } else {
      overlay.showSuccess(label, found);
    }
    setPendingId(null);
  }, [list, runAgent, executeRun, overlay, queryClient, t]);

  const handleDelete = useCallback(
    (agentId: string, agentName: string) => {
      Alert.alert(t("dashboard.deleteTitle"), t("dashboard.deleteConfirm", { name: agentName }), [
        { text: t("common.cancel"), style: "cancel" },
        {
          text: t("common.delete"),
          style: "destructive",
          onPress: async () => {
            try {
              await deleteAgent.mutateAsync(agentId);
              showToast(t("dashboard.deleted"), "success");
            } catch (e) {
              showToast(e instanceof Error ? e.message : t("dashboard.deleteFailed"), "error");
            }
          },
        },
      ]);
    },
    [deleteAgent, showToast, t],
  );

  // The wizard closes from its last screen with the new agent: say it worked,
  // and start the first run if they asked for it.
  const handleWizardClose = useCallback(
    async (result?: OnboardingResult) => {
      setWizardOpen(false);
      if (!result) return;
      showToast(t("dashboard.setUp", { name: result.agentName }), "success");
      if (!result.runNow) return;
      setPendingId(result.agentId);
      try {
        await runOne(result.agentId, result.agentName);
      } catch (e) {
        overlay.showError(result.agentName, e instanceof Error ? e.message : t("runs.startFailed"));
      } finally {
        setPendingId(null);
      }
    },
    [showToast, runOne, overlay, t],
  );

  const loading =
    agents.isLoading || runs.isLoading || items.isLoading || channels.isLoading || agentCounts.isLoading;

  return (
    <View style={styles.root}>
      <ScrollView
        ref={scrollRef}
        contentContainerStyle={[
          styles.content,
          isWide && styles.contentWide,
          { paddingTop: insets.top + 16, paddingBottom: insets.bottom + 70 },
        ]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        scrollEnabled={!overlay.state.status}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.accent} />
        }
      >
        {/* ── Header ──────────────────────────────────────────────── */}
      <View style={styles.header}>
        <View style={styles.titleRow}>
          <Text style={styles.heading}>{t("tabs.dashboard")}</Text>
          <Pressable
            onPress={openWizard}
            accessibilityRole="button"
            accessibilityLabel={t("dashboard.howItWorks")}
            hitSlop={8}
            style={({ pressed }) => [styles.helpBtn, pressed && styles.pressed]}
          >
            <Text style={styles.helpText}>?</Text>
          </Pressable>
        </View>
        <View style={styles.headerBtns}>
          <Pressable
            style={({ pressed }) => [styles.newAgentBtn, pressed && styles.pressed]}
            onPress={() => router.push("/agent-form")}
          >
            <Text style={styles.newAgentText}>{t("dashboard.newCollection")}</Text>
          </Pressable>
          {list.length > 0 ? (
            <Pressable
              style={({ pressed }) => [styles.runAllBtn, pressed && styles.pressed]}
              onPress={() => void triggerRunAll()}
              disabled={pendingId !== null}
            >
              <LinearGradient
                colors={[Colors.success, Colors.success]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={StyleSheet.absoluteFill}
              />
              {pendingId === "all" ? (
                <ActivityIndicator size="small" color={Colors.white} />
              ) : (
                <>
                  <Play size={14} color={Colors.white} fill={Colors.white} />
                  <Text style={styles.runAllText}>{t("dashboard.runAll")}</Text>
                </>
              )}
            </Pressable>
          ) : null}
        </View>
      </View>

      {loading ? (
        <View style={styles.loadingBox}>
          <ActivityIndicator color={Colors.accent} />
        </View>
      ) : (
        <>
          {/* ── Stat cards ───────────────────────────────────────── */}
          <View style={[styles.grid, isWide && styles.gridWide]}>
            <StatCard
              icon={<Bot size={20} color={statIconBlue} strokeWidth={1.75} />}
              label={t("dashboard.stats.collections")}
              value={list.length}
              isWide={isWide}
            />
            <StatCard
              icon={<Video size={20} color={statIconBlue} strokeWidth={1.75} />}
              label={t("dashboard.stats.channels")}
              value={channelList.length}
              isWide={isWide}
            />
            <StatCard
              icon={<Activity size={20} color={statIconBlue} strokeWidth={1.75} />}
              label={t("dashboard.stats.runs")}
              value={recentRuns}
              isWide={isWide}
            />
            <StatCard
              icon={<TrendingUp size={20} color={statIconBlue} strokeWidth={1.75} />}
              label={t("dashboard.stats.successRate")}
              value={successRate ?? t("dashboard.stats.notAvailable")}
              suffix={successRate !== null ? "%" : undefined}
              isWide={isWide}
            />
          </View>

          {/* ── People ─────────────────────────────────────────── */}
          <Pressable
            style={({ pressed }) => [followingStyles.card, pressed && styles.pressed]}
            onPress={() => router.push("/following")}
            accessibilityRole="button"
            accessibilityLabel={t("dashboard.peopleLabel")}
          >
            <View style={followingStyles.iconBox}>
              <Users size={18} color={statIconBlue} strokeWidth={1.75} />
            </View>
            <View style={followingStyles.body}>
              <Text style={followingStyles.title}>{t("dashboard.people")}</Text>
              <Text style={followingStyles.sub} numberOfLines={1}>{t("dashboard.peopleSub")}</Text>
            </View>
            <ChevronRight size={18} color={Colors.textMuted} />
          </Pressable>

          {/* ── Feeds ─────────────────────────────────────────────── */}
          <SectionHeader
            title={t("tabs.feeds")}
            count={list.length}
            open={sections.feeds}
            onToggle={() => toggleSection("feeds")}
            action={list.length > 0 ? t("dashboard.viewAll") : undefined}
            onAction={() => router.push("/(tabs)/feed")}
          />
          {!sections.feeds ? null : list.length === 0 ? (
            <EmptyCard text={t("dashboard.empty")} />
          ) : (
            list.map((agent, i) => {
              const accent = getAgentColor(i);
              const stats = agentCounts.data?.[agent.id] ?? { total: 0, watched: 0, unwatched: 0, watchLater: 0, liked: 0 };
              const pct = stats.total > 0 ? Math.round((stats.watched / stats.total) * 100) : 0;
              const allCaughtUp = stats.total > 0 && stats.unwatched === 0;
              return (
                <FeedCard
                  key={agent.id}
                  agent={agent}
                  accent={accent}
                  stats={stats}
                  watchedPct={pct}
                  allCaughtUp={allCaughtUp}
                  onPress={() => {
                    const status =
                      stats.unwatched > 0
                        ? "not_watched"
                        : stats.watchLater > 0
                          ? "watch_later"
                          : stats.watched > 0
                            ? "watched"
                            : "not_watched";
                    router.push({
                      pathname: "/(tabs)/feed",
                      params: { agentId: agent.id, status },
                    });
                  }}
                />
              );
            })
          )}

          {/* ── Watch Time Statistics ────────────────────────────── */}
          <WatchTimeStats />

          {/* ── My Agents ────────────────────────────────────────── */}
          <View style={styles.sectionSpacer} />
          <SectionHeader
            title={t("dashboard.myCollections")}
            count={list.length}
            open={sections.collections}
            onToggle={() => toggleSection("collections")}
          />
          {!sections.collections ? null : list.length === 0 ? (
            <EmptyCard text={t("dashboard.empty")} />
          ) : (
            list.map((agent, i) => {
              const accent = getAgentColor(i);
              const busy = pendingId === agent.id;
              const lastRun = perAgentLastRun[agent.id];
              const chCount = perAgentChannels[agent.id]?.length ?? 0;
              const newVideos = lastRun?.videos_new_count ?? 0;
              return (
                <AgentCard
                  key={agent.id}
                  agent={agent}
                  accent={accent}
                  channelCount={chCount}
                  lastRun={lastRun}
                  newVideos={newVideos}
                  busy={busy}
                  onRunNow={() => void triggerRun(agent.id)}
                  onEdit={() =>
                    router.push({ pathname: "/agent-form", params: { agentId: agent.id } })
                  }
                  onDelete={() => handleDelete(agent.id, agent.name)}
                  onTap={() =>
                    router.push({ pathname: "/(tabs)/agent-detail", params: { agentId: agent.id } })
                  }
                />
              );
            })
          )}
        </>
        )}
      </ScrollView>

      <OnboardingWizard
        key={wizardKey}
        visible={wizardOpen}
        onClose={(result) => void handleWizardClose(result)}
        hidden={onboardingHidden}
        onHiddenChange={(hidden) => void handleHiddenChange(hidden)}
      />
    </View>
  );
}

// ── Sub-components ─────────────────────────────────────────────────

function StatCard({
  icon,
  label,
  value,
  suffix,
  isWide,
}: {
  icon: React.ReactNode;
  label: string;
  value: number | string;
  suffix?: string;
  isWide?: boolean;
}) {
  return (
    <View style={[statStyles.card, isWide && statStyles.cardWide]}>
      <View style={statStyles.topRow}>
        <Text style={statStyles.label}>{label}</Text>
        <View style={statStyles.iconBox}>{icon}</View>
      </View>
      <Text style={statStyles.value}>
        {value}
        {suffix ?? ""}
      </Text>
    </View>
  );
}

const statStyles = StyleSheet.create({
  card: {
    width: "47%",
    backgroundColor: Colors.card,
    borderRadius: 8,
    padding: 14,
    borderWidth: 1,
    borderColor: "hsl(220, 25%, 18%)",
    minHeight: 94,
    justifyContent: "space-between",
  },
  cardWide: {
    width: "22%",
  },
  topRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start" },
  label: { fontSize: 12, fontWeight: "600" as const, color: Colors.textSecondary, flexShrink: 1, marginRight: 6 },
  iconBox: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", flexShrink: 0, backgroundColor: statIconBg },
  value: { fontSize: 28, fontWeight: "800" as const, color: Colors.textPrimary, marginTop: 4 },
});

/**
 * The collection's description, read-only on the card. It's written and
 * changed only when creating or editing the collection.
 */
function CardDescription({ description }: { description: string | null }) {
  if (!description?.trim()) return null;
  return <Text style={feedStyles.desc} numberOfLines={1}>{description}</Text>;
}

function FeedCard({
  agent,
  accent,
  stats,
  watchedPct,
  allCaughtUp,
  onPress,
}: {
  agent: { id: string; name: string; description: string | null };
  accent: string;
  stats: { total: number; watched: number; unwatched: number; watchLater: number; liked: number };
  watchedPct: number;
  allCaughtUp: boolean;
  onPress: () => void;
}) {
  const { t } = useTranslation();
  return (
    <Pressable style={({ pressed }) => [feedStyles.card, pressed && styles.pressed]} onPress={onPress}>
      <View style={[feedStyles.accentBar, { backgroundColor: accent }]} />
      <View style={feedStyles.body}>
        {/* top row */}
        <View style={feedStyles.topRow}>
          <View style={feedStyles.titleRow}>
            <Rss size={16} color={accent} />
            <Text style={feedStyles.name} numberOfLines={1}>{agent.name}</Text>
            {allCaughtUp ? (
              <View style={[feedStyles.caughtUpPill, { borderColor: Colors.success }]}>
                <Sparkles size={11} color={Colors.success} />
                <Text style={[feedStyles.caughtUpText, { color: Colors.success }]}>{t("dashboard.allCaughtUp")}</Text>
              </View>
            ) : null}
          </View>
        </View>

        <CardDescription description={agent.description} />

        {/* progress bar */}
        {stats.total > 0 ? (
          <View style={feedStyles.progressSection}>
            <View style={feedStyles.progressBarBg}>
              <View style={[feedStyles.progressBarFill, { width: `${watchedPct}%` as unknown as number }]} />
            </View>
            <Text style={feedStyles.progressPct}>{watchedPct}%</Text>
          </View>
        ) : (
          <Text style={feedStyles.noItems}>{t("dashboard.noItems")}</Text>
        )}

        {/* stat counts */}
        <View style={feedStyles.countRow}>
          <CountChip icon={<Layers size={12} color={Colors.textSecondary} />} value={stats.total} />
          <CountChip icon={<CheckCircle2 size={12} color={Colors.success} />} value={stats.watched} tint={Colors.success} />
          <CountChip icon={<Circle size={12} color={Colors.textMuted} />} value={stats.unwatched} tint={Colors.textMuted} />
          <CountChip icon={<Clock4 size={12} color={Colors.warning} />} value={stats.watchLater} tint={Colors.warning} />
        </View>
      </View>
    </Pressable>
  );
}

const feedStyles = StyleSheet.create({
  card: {
    flexDirection: "row",
    backgroundColor: Colors.card,
    borderRadius: 10,
    overflow: "hidden",
    marginBottom: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  accentBar: { width: 4 },
  body: { flex: 1, padding: 14 },
  topRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  titleRow: { flexDirection: "row", alignItems: "center", gap: 8, flex: 1, flexWrap: "wrap" },
  name: { fontSize: 15, fontWeight: "700" as const, color: Colors.textPrimary },
  caughtUpPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 2,
    marginLeft: 6,
  },
  caughtUpText: { fontSize: 10, fontWeight: "600" as const },
  desc: { fontSize: 12, color: Colors.textSecondary, marginTop: 4 },
  progressSection: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    marginTop: 12,
  },
  progressBarBg: {
    flex: 1,
    height: 5,
    borderRadius: 3,
    backgroundColor: "hsl(220, 20%, 18%)",
    overflow: "hidden",
  },
  progressBarFill: {
    height: "100%",
    borderRadius: 3,
    backgroundColor: Colors.success,
  },
  progressPct: { fontSize: 12, fontWeight: "700" as const, color: Colors.success, minWidth: 32, textAlign: "right" },
  noItems: { fontSize: 12, color: Colors.textMuted, marginTop: 8, fontStyle: "italic" },
  countRow: { flexDirection: "row", gap: 16, marginTop: 12 },
});

function CountChip({
  icon,
  value,
  tint,
}: {
  icon: React.ReactNode;
  value: number;
  tint?: string;
}) {
  return (
    <View style={countStyles.chip}>
      {icon}
      <Text style={[countStyles.val, tint ? { color: tint } : undefined]}>{value}</Text>
    </View>
  );
}

const countStyles = StyleSheet.create({
  chip: { flexDirection: "row", alignItems: "center", gap: 4 },
  val: { fontSize: 13, fontWeight: "700" as const, color: Colors.textPrimary },

});

function AgentCard({
  agent,
  accent,
  channelCount,
  lastRun,
  newVideos,
  busy,
  onRunNow,
  onEdit,
  onDelete,
  onTap,
}: {
  agent: { id: string; name: string; description: string | null; run_time_local: string | null };
  accent: string;
  channelCount: number;
  lastRun: Run | null;
  newVideos: number;
  busy: boolean;
  onRunNow: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onTap: () => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const { t } = useTranslation();

  return (
    <Pressable style={({ pressed }) => [agentStyles.card, pressed && styles.pressed]} onPress={onTap}>
      <View style={[agentStyles.accentBar, { backgroundColor: accent }]} />
      <View style={agentStyles.body}>
        {/* top row */}
        <View style={agentStyles.topRow}>
          <View style={agentStyles.titleArea}>
            <Bot size={16} color={accent} />
            <Text style={agentStyles.name} numberOfLines={1}>{agent.name}</Text>
          </View>
          <View style={agentStyles.actions}>
            <Pressable
              style={({ pressed }) => [agentStyles.runBtn, pressed && styles.pressed]}
              onPress={(e) => { e.stopPropagation?.(); onRunNow(); }}
              disabled={busy}
              hitSlop={8}
            >
              {busy ? (
                <ActivityIndicator size="small" color={Colors.textSecondary} />
              ) : (
                <Play size={16} color={Colors.textSecondary} fill={Colors.textSecondary} />
              )}
            </Pressable>
            <Pressable
              style={({ pressed }) => [agentStyles.menuBtn, pressed && styles.pressed]}
              onPress={(e) => { e.stopPropagation?.(); setMenuOpen((v) => !v); }}
              hitSlop={8}
            >
              <MoreVertical size={18} color={Colors.textSecondary} />
            </Pressable>
          </View>
        </View>

        {agent.description ? (
          <Text style={agentStyles.desc} numberOfLines={2}>{agent.description}</Text>
        ) : null}

        {/* dropdown menu */}
        {menuOpen ? (
          <View style={agentStyles.menu}>
            <Pressable
              style={agentStyles.menuItem}
              onPress={(e) => { e.stopPropagation?.(); setMenuOpen(false); onEdit(); }}
            >
              <Text style={agentStyles.menuText}>{t("common.edit")}</Text>
            </Pressable>
            <View style={agentStyles.menuDivider} />
            <Pressable
              style={agentStyles.menuItem}
              onPress={(e) => { e.stopPropagation?.(); setMenuOpen(false); onDelete(); }}
            >
              <Text style={[agentStyles.menuText, { color: Colors.destructive }]}>{t("common.delete")}</Text>
            </Pressable>
          </View>
        ) : null}

        {/* meta row */}
        <View style={agentStyles.metaRow}>
          <View style={agentStyles.metaChip}>
            <Video size={12} color={Colors.textSecondary} />
            <Text style={agentStyles.metaText}>{t("dashboard.channelCount", { count: channelCount })}</Text>
          </View>
          {agent.run_time_local ? (
            <View style={agentStyles.metaChip}>
              <Clock size={12} color={Colors.textSecondary} />
              <Text style={agentStyles.metaText}>{agent.run_time_local}</Text>
            </View>
          ) : null}
        </View>

        {/* last-run pill */}
        {lastRun ? (
          <View style={[agentStyles.lastRunPill, { backgroundColor: "hsla(152, 69%, 50%, 0.15)", alignSelf: "flex-start", marginTop: 8 }]}>
            <CheckCircle2 size={12} color="hsl(152, 69%, 50%)" />
            <Text style={[agentStyles.lastRunText, { color: "hsl(152, 69%, 50%)" }]}>
              {relativeTime(lastRun.started_at)}
            </Text>
          </View>
        ) : null}

        {/* New feeds from the last run: always shown (0 when none), so every card has the same line */}
        <Text style={agentStyles.foundText}>
          <Trans
            i18nKey="dashboard.foundNew"
            count={newVideos}
            values={{ shown: compactNumber(newVideos) }}
            components={{ b: <Text style={agentStyles.foundHighlight} /> }}
          />
        </Text>
      </View>
    </Pressable>
  );
}

const agentStyles = StyleSheet.create({
  card: {
    flexDirection: "row",
    backgroundColor: Colors.card,
    borderRadius: 10,
    overflow: "hidden",
    marginBottom: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  accentBar: { width: 4 },
  body: { flex: 1, padding: 14 },
  topRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  titleArea: { flexDirection: "row", alignItems: "center", gap: 8, flex: 1 },
  name: { fontSize: 15, fontWeight: "700" as const, color: Colors.textPrimary },
  actions: { flexDirection: "row", alignItems: "center", gap: 4 },
  runBtn: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  menuBtn: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  desc: { fontSize: 12, color: Colors.textSecondary, marginTop: 4, lineHeight: 17 },
  metaRow: { flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: 10, marginTop: 12 },
  metaChip: { flexDirection: "row", alignItems: "center", gap: 4 },
  metaText: { fontSize: 11, color: Colors.textSecondary },
  lastRunPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  lastRunText: { fontSize: 11, fontWeight: "600" as const },
  foundText: { fontSize: 13, color: Colors.textSecondary, marginTop: 10 },
  foundHighlight: { color: Colors.textSecondary, fontWeight: "700" as const },
  menu: {
    backgroundColor: Colors.input,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    marginTop: 8,
    overflow: "hidden",
  },
  menuItem: {
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  menuText: { fontSize: 14, color: Colors.textPrimary },
  menuDivider: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.border },
});

function SectionHeader({
  title,
  count,
  open,
  onToggle,
  action,
  onAction,
}: {
  title: string;
  count?: number;
  /** With onToggle: the section opens and closes from its title. */
  open?: boolean;
  onToggle?: () => void;
  action?: string;
  onAction?: () => void;
}) {
  const { t } = useTranslation();
  return (
    <View style={sectStyles.row}>
      {onToggle ? (
        <Pressable
          onPress={onToggle}
          hitSlop={8}
          style={sectStyles.toggle}
          accessibilityRole="button"
          accessibilityState={{ expanded: !!open }}
          accessibilityLabel={t(open ? "dashboard.sectionCollapse" : "dashboard.sectionExpand", { title })}
        >
          {open ? <ChevronDown size={16} color={Colors.textSecondary} /> : <ChevronRight size={16} color={Colors.textSecondary} />}
          <Text style={sectStyles.title}>{title}</Text>
          {count !== undefined ? <Text style={sectStyles.count}>({count})</Text> : null}
        </Pressable>
      ) : (
        <Text style={sectStyles.title}>{title}</Text>
      )}
      {action ? (
        <Pressable onPress={onAction} hitSlop={8}>
          <Text style={sectStyles.action}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const sectStyles = StyleSheet.create({
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 26,
    marginBottom: 12,
  },
  title: {
    fontSize: 13,
    fontWeight: "700" as const,
    color: Colors.textSecondary,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  action: { fontSize: 14, fontWeight: "600" as const, color: Colors.accent },
  toggle: { flexDirection: "row", alignItems: "center", gap: 6, flexShrink: 1 },
  count: { fontSize: 13, color: Colors.textMuted },
});

function EmptyCard({ text }: { text: string }) {
  return (
    <View style={emptyStyles.card}>
      <Text style={emptyStyles.text}>{text}</Text>
    </View>
  );
}

const emptyStyles = StyleSheet.create({
  card: {
    backgroundColor: Colors.card,
    borderRadius: 10,
    padding: 20,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  text: { fontSize: 13, color: Colors.textSecondary, textAlign: "center" },
});

// ── Shared styles ──────────────────────────────────────────────────
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background },
  titleRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", alignSelf: "stretch" },
  helpBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: HELP_RED,
    alignItems: "center",
    justifyContent: "center",
  },
  helpText: { color: HELP_RED, fontSize: 16, fontWeight: "700" as const, lineHeight: 18 },
  content: { paddingHorizontal: 16 },
  contentWide: {
    maxWidth: 720,
    alignSelf: "center",
    width: "100%",
  },
  header: {
    flexDirection: "column",
    alignItems: "flex-start",
    marginBottom: 20,
    gap: 12,
  },
  heading: { fontSize: 26, fontWeight: "800" as const, color: Colors.textPrimary },
  headerBtns: { flexDirection: "row", gap: 10, alignItems: "center", alignSelf: "flex-start" },
  newAgentBtn: {
    backgroundColor: Colors.accent,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 10,
  },
  newAgentText: { color: Colors.white, fontSize: 13, fontWeight: "700" as const },
  runAllBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 38,
    paddingHorizontal: 14,
    borderRadius: 10,
    overflow: "hidden",
    minWidth: 90,
    justifyContent: "center",
  },
  runAllText: { color: Colors.white, fontSize: 13, fontWeight: "700" as const },
  pressed: { opacity: 0.8, transform: [{ scale: 0.98 }] },
  loadingBox: { paddingVertical: 60, alignItems: "center" },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
  },
  gridWide: {
    gap: 16,
  },
  sectionSpacer: { height: 4 },
});

// Dashboard link to the Following screen (app/following.tsx).
const followingStyles = StyleSheet.create({
  card: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginTop: 12,
    padding: 14,
    borderRadius: 10,
    backgroundColor: Colors.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  iconBox: {
    width: 34,
    height: 34,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: statIconBg,
  },
  body: { flex: 1 },
  title: { fontSize: 15, fontWeight: "700" as const, color: Colors.textPrimary },
  sub: { fontSize: 12, color: Colors.textSecondary, marginTop: 2 },
});
