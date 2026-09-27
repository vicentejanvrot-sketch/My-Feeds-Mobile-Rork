// Following: everyone the user follows across all agents, and where else each
// person or company has an account ("Also on"). Opened from the Dashboard.
// Same data and rules as /following on the web.
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Modal,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import { formatDistanceToNow } from "date-fns";
import {
  ArrowLeft,
  Check,
  ChevronRight,
  ExternalLink,
  Link2,
  RefreshCw,
  ScanSearch,
  Search,
  UserPlus,
  X,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { PlatformBadge } from "@/components/PlatformBadge";
import { useToast } from "@/components/Toast";
import { useAgents, useChannelsAll } from "@/lib/hooks";
import { openExternalLink } from "@/lib/open-link";
import { PLATFORM_META, type Platform } from "@/lib/platforms";
import {
  buildPeople,
  initials,
  isPersonSource,
  personSummary,
  type FoundAccount,
  type Person,
} from "@/lib/alsoOn";
import {
  useDecideLink,
  useFollowAccount,
  useIdentityLinks,
  useIdentityScans,
  useScanSources,
} from "@/lib/useAlsoOn";

const RESCAN_AFTER_DAYS = 30;
// Upper bound per source, and AIsa's listed median price per call.
const MAX_LOOKUPS_PER_SOURCE = 8;
const AISA_PRICE_PER_CALL = 0.012;
const IPAD_BREAKPOINT = 768;

const platformLabel = (p: Platform) => PLATFORM_META[p].label;

function Avatar({ name, uri, size = 40 }: { name: string; uri: string | null; size?: number }) {
  const [broken, setBroken] = useState(false);
  if (uri && !broken) {
    return (
      <Image
        source={{ uri }}
        style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: Colors.input }}
        onError={() => setBroken(true)}
        contentFit="cover"
      />
    );
  }
  return (
    <View style={[styles.avatarFallback, { width: size, height: size, borderRadius: size / 2 }]}>
      <Text style={[styles.avatarText, { fontSize: size * 0.34 }]}>{initials(name)}</Text>
    </View>
  );
}

type ChipVariant = "following" | "also" | "possible";

function PlatformChip({ platform, variant }: { platform: Platform; variant: ChipVariant }) {
  return (
    <View
      style={[
        styles.chip,
        variant === "following" && styles.chipFollowing,
        variant === "also" && styles.chipAlso,
        variant === "possible" && styles.chipPossible,
      ]}
    >
      <PlatformBadge platform={platform} />
      <Text style={[styles.chipText, variant === "possible" && styles.chipTextMuted]}>
        {platformLabel(platform) + (variant === "possible" ? "?" : "")}
      </Text>
    </View>
  );
}

function AccountLine({ platform, label, url }: { platform: Platform; label: string; url: string }) {
  return (
    <Pressable
      onPress={() => void openExternalLink(url)}
      style={({ pressed }) => [styles.accountLine, pressed && styles.pressed]}
      accessibilityRole="link"
      accessibilityLabel={platformLabel(platform) + " " + label}
    >
      <PlatformBadge platform={platform} />
      <Text style={styles.accountPlatform}>{platformLabel(platform)}</Text>
      <Text style={styles.accountLabel} numberOfLines={1}>{label}</Text>
      <ExternalLink size={12} color={Colors.textMuted} />
    </Pressable>
  );
}

function FollowButton({ account, agentId }: { account: FoundAccount; agentId: string | undefined }) {
  const follow = useFollowAccount();
  const showToast = useToast();
  return (
    <Pressable
      disabled={!agentId || follow.isPending}
      onPress={() => {
        if (!agentId) return;
        follow.mutate(
          { platform: account.platform, url: account.url, agentId },
          {
            onSuccess: () => showToast("Added to your agent", "success"),
            onError: (e) => showToast(e instanceof Error ? e.message : "Couldn't add that account", "error"),
          },
        );
      }}
      style={({ pressed }) => [styles.followBtn, (pressed || follow.isPending) && styles.pressed]}
    >
      {follow.isPending ? (
        <ActivityIndicator size="small" color={Colors.white} />
      ) : (
        <>
          <UserPlus size={14} color={Colors.white} />
          <Text style={styles.followText}>Follow</Text>
        </>
      )}
    </Pressable>
  );
}

function DecisionButtons({ account }: { account: FoundAccount }) {
  const decide = useDecideLink();
  const showToast = useToast();
  const run = (same: boolean) =>
    decide.mutate(
      { link: account.link, same },
      {
        onSuccess: () => showToast(same ? "Marked as the same person" : "Removed that match", "success"),
        onError: (e) => showToast(e instanceof Error ? e.message : "Couldn't save that", "error"),
      },
    );
  return (
    <View style={styles.decisionRow}>
      <Pressable
        disabled={decide.isPending}
        onPress={() => run(true)}
        style={({ pressed }) => [styles.samePersonBtn, pressed && styles.pressed]}
      >
        <Check size={15} color={Colors.white} />
        <Text style={styles.samePersonText}>Same person</Text>
      </Pressable>
      <Pressable
        disabled={decide.isPending}
        onPress={() => run(false)}
        style={({ pressed }) => [styles.notThemBtn, pressed && styles.pressed]}
      >
        <X size={15} color={Colors.textPrimary} />
        <Text style={styles.notThemText}>Not them</Text>
      </Pressable>
    </View>
  );
}

function PersonPanel({ person, agents, scanning, onRescan }: {
  person: Person;
  agents: { id: string; name: string }[];
  scanning: boolean;
  onRescan: () => void;
}) {
  const decide = useDecideLink();
  const showToast = useToast();
  const [agentId, setAgentId] = useState<string | undefined>(person.agentIds[0]);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => setAgentId(person.agentIds[0]), [person.id]);
  const agentName = new Map(agents.map((a) => [a.id, a.name]));

  return (
    <View style={styles.panel}>
      <View style={styles.panelHeader}>
        <Avatar name={person.name} uri={person.thumbnail} size={56} />
        <View style={styles.flex1}>
          <Text style={styles.panelName} numberOfLines={2}>{person.name}</Text>
          <Text style={styles.muted}>{personSummary(person, platformLabel)}</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>You follow</Text>
      <View style={styles.box}>
        {person.following.map((a, i) => (
          <View key={a.channel.id} style={[styles.boxRow, i > 0 && styles.boxRowBorder]}>
            <View style={styles.flex1}>
              <AccountLine platform={a.platform} label={a.label} url={a.url} />
            </View>
            <Text style={styles.agentTag} numberOfLines={1}>{agentName.get(a.channel.agent_id) ?? "Agent"}</Text>
          </View>
        ))}
      </View>

      {person.also.length > 0 ? (
        <>
          <Text style={styles.sectionTitle}>Also on</Text>
          {agents.length > 1 ? (
            <View style={styles.agentPicker}>
              <Text style={styles.muted}>Add to</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.agentChips}>
                {agents.map((a) => {
                  const active = a.id === agentId;
                  return (
                    <Pressable
                      key={a.id}
                      onPress={() => setAgentId(a.id)}
                      style={[styles.agentChip, active && styles.agentChipActive]}
                    >
                      <Text style={[styles.agentChipText, active && styles.agentChipTextActive]}>{a.name}</Text>
                    </Pressable>
                  );
                })}
              </ScrollView>
            </View>
          ) : null}
          <View style={styles.box}>
            {person.also.map((a, i) => (
              <View key={a.key} style={[styles.boxRow, i > 0 && styles.boxRowBorder]}>
                <View style={[styles.flex1, styles.gap4]}>
                  <AccountLine platform={a.platform} label={a.label} url={a.url} />
                  <View style={styles.evidenceRow}>
                    <Link2 size={12} color={Colors.success} />
                    <Text style={styles.evidence}>{a.link.evidence}</Text>
                  </View>
                  <Pressable
                    onPress={() =>
                      decide.mutate(
                        { link: a.link, same: false },
                        {
                          onSuccess: () => showToast("Removed that match", "success"),
                          onError: (e) => showToast(e instanceof Error ? e.message : "Couldn't save that", "error"),
                        },
                      )
                    }
                    hitSlop={6}
                  >
                    <Text style={styles.removeLink}>Not them? Remove this match</Text>
                  </Pressable>
                </View>
                <FollowButton account={a} agentId={agentId} />
              </View>
            ))}
          </View>
        </>
      ) : null}

      {person.possible.length > 0 ? (
        <>
          <Text style={styles.sectionTitle}>Possible match</Text>
          {person.possible.map((a) => (
            <View key={a.key} style={styles.possibleCard}>
              <AccountLine platform={a.platform} label={a.label} url={a.url} />
              {a.link.display_name ? (
                <Text style={styles.muted}>Name on that profile: {a.link.display_name}</Text>
              ) : null}
              <Text style={styles.warningText}>{a.link.evidence}</Text>
              <DecisionButtons account={a} />
            </View>
          ))}
        </>
      ) : null}

      {person.lastScannedAt && person.also.length === 0 && person.possible.length === 0 ? (
        <Text style={[styles.muted, styles.noneFound]}>
          No other accounts found. Their profile doesn't link anywhere we can follow, and the same handle isn't on X, Instagram or YouTube.
        </Text>
      ) : null}

      <View style={styles.panelFooter}>
        <View style={styles.footerRow}>
          <Text style={styles.muted}>
            {person.lastScannedAt
              ? "Checked " + formatDistanceToNow(new Date(person.lastScannedAt), { addSuffix: true })
              : "Not checked yet"}
          </Text>
          <Pressable
            disabled={scanning}
            onPress={onRescan}
            style={({ pressed }) => [styles.outlineBtn, (pressed || scanning) && styles.pressed]}
          >
            {scanning ? <ActivityIndicator size="small" color={Colors.accent} /> : <RefreshCw size={14} color={Colors.textPrimary} />}
            <Text style={styles.outlineBtnText}>{person.lastScannedAt ? "Check again" : "Check now"}</Text>
          </Pressable>
        </View>
        {person.scanErrors.length > 0 ? (
          <Text style={styles.warningText}>Last check had a problem: {person.scanErrors[0]}</Text>
        ) : null}
        <Text style={styles.footNote}>
          Matches come from links on their own profiles, their link-in-bio page and website, and the same handle on other platforms. A handle alone is only ever a possible match.
        </Text>
      </View>
    </View>
  );
}

function PersonRow({ person, agentNames, onPress }: { person: Person; agentNames: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}>
      <Avatar name={person.name} uri={person.thumbnail} />
      <View style={[styles.flex1, styles.gap6]}>
        <View style={styles.rowTitle}>
          <Text style={styles.rowName} numberOfLines={1}>{person.name}</Text>
          {agentNames ? <Text style={styles.rowAgents} numberOfLines={1}>{agentNames}</Text> : null}
        </View>
        <View style={styles.chipWrap}>
          {person.following.map((a) => (
            <PlatformChip key={"f" + a.channel.id} platform={a.platform} variant="following" />
          ))}
          {person.also.map((a) => (
            <PlatformChip key={"a" + a.key} platform={a.platform} variant="also" />
          ))}
          {person.possible.map((a) => (
            <PlatformChip key={"p" + a.key} platform={a.platform} variant="possible" />
          ))}
        </View>
        <Text style={styles.muted}>{personSummary(person, platformLabel)}</Text>
      </View>
      <ChevronRight size={18} color={Colors.textMuted} />
    </Pressable>
  );
}

function GapsView({ people, agents, onOpen }: {
  people: Person[];
  agents: { id: string; name: string }[];
  onOpen: (id: string) => void;
}) {
  const agentName = new Map(agents.map((a) => [a.id, a.name]));
  const withGaps = people.filter((p) => p.also.length > 0);
  const checks = people.flatMap((p) => p.possible.map((a) => ({ person: p, account: a })));

  if (withGaps.length === 0 && checks.length === 0) {
    return (
      <View style={styles.emptyCard}>
        <Text style={styles.muted}>No gaps. You follow everyone everywhere we found them.</Text>
      </View>
    );
  }

  return (
    <View style={styles.gap12}>
      {withGaps.length > 0 ? (
        <Text style={styles.muted}>People you follow who are also somewhere you don't follow them yet.</Text>
      ) : null}
      {withGaps.map((p) => (
        <View key={p.id} style={styles.card}>
          <Pressable onPress={() => onOpen(p.id)} style={styles.gapHeader}>
            <Avatar name={p.name} uri={p.thumbnail} size={36} />
            <View style={styles.flex1}>
              <Text style={styles.rowName} numberOfLines={1}>{p.name}</Text>
              <Text style={styles.muted} numberOfLines={1}>
                {"You follow on " + p.following.map((f) => platformLabel(f.platform)).join(" and ") +
                  " · adds to " + (agentName.get(p.agentIds[0]) ?? "agent")}
              </Text>
            </View>
          </Pressable>
          {p.also.map((a) => (
            <View key={a.key} style={[styles.boxRow, styles.boxRowBorder]}>
              <View style={[styles.flex1, styles.gap4]}>
                <AccountLine platform={a.platform} label={a.label} url={a.url} />
                <Text style={styles.muted}>{a.link.evidence}</Text>
              </View>
              <FollowButton account={a} agentId={p.agentIds[0]} />
            </View>
          ))}
        </View>
      ))}

      {checks.length > 0 ? (
        <>
          <Text style={styles.sectionTitle}>Needs your check</Text>
          {checks.map(({ person, account }) => (
            <View key={person.id + account.key} style={styles.possibleCard}>
              <Text style={styles.question}>
                {"Is " + account.label + " on " + platformLabel(account.platform) + " the same " + person.name + " you follow?"}
              </Text>
              <AccountLine platform={account.platform} label={account.label} url={account.url} />
              {account.link.display_name ? (
                <Text style={styles.muted}>Name on that profile: {account.link.display_name}</Text>
              ) : null}
              <Text style={styles.warningText}>{account.link.evidence}</Text>
              <DecisionButtons account={account} />
            </View>
          ))}
        </>
      ) : null}
    </View>
  );
}

export default function FollowingScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const isWide = width >= IPAD_BREAKPOINT;
  const showToast = useToast();

  const sources = useChannelsAll();
  const links = useIdentityLinks();
  const scans = useIdentityScans();
  const agentsQuery = useAgents();
  const { scan, progress, isScanning } = useScanSources();

  const [tab, setTab] = useState<"all" | "gaps">("all");
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const agents = useMemo(
    () =>
      (agentsQuery.data ?? [])
        .map((a) => ({ id: a.id, name: a.name }))
        .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" })),
    [agentsQuery.data],
  );
  const agentName = useMemo(() => new Map(agents.map((a) => [a.id, a.name])), [agents]);
  const people = useMemo(
    () => buildPeople(sources.data ?? [], links.data ?? [], scans.data ?? []),
    [sources.data, links.data, scans.data],
  );
  const skipped = (sources.data ?? []).filter((c) => !isPersonSource(c)).length;

  const q = query.trim().toLowerCase();
  const filtered = q
    ? people.filter((p) => p.name.toLowerCase().includes(q) || p.following.some((f) => f.label.toLowerCase().includes(q)))
    : people;

  const gapCount = people.reduce((n, p) => n + p.also.length + p.possible.length, 0);
  const scanList = scans.data ?? [];
  const staleBefore = Date.now() - RESCAN_AFTER_DAYS * 24 * 60 * 60 * 1000;
  const scanTimes = new Map(scanList.map((s) => [s.channel_id, new Date(s.scanned_at).getTime()]));
  const toScan = people
    .flatMap((p) => p.sources)
    .filter((c) => !scanTimes.has(c.id) || (scanTimes.get(c.id) ?? 0) < staleBefore)
    .map((c) => c.id);
  const maxCost = (toScan.length * MAX_LOOKUPS_PER_SOURCE * AISA_PRICE_PER_CALL).toFixed(2);
  const loading = sources.isLoading || scans.isLoading;
  const selected = people.find((p) => p.id === selectedId) ?? null;

  const runScan = useCallback(
    async (ids: string[]) => {
      const result = await scan(ids);
      if (!result) return;
      if (result.failed) {
        showToast(result.failed + " of " + result.total + " couldn't be checked: " + (result.firstError ?? ""), "error");
      } else {
        showToast(result.total === 1 ? "Checked for other platforms" : "Checked " + result.total + " sources", "success");
      }
    },
    [scan, showToast],
  );

  const refreshing = sources.isRefetching || links.isRefetching || scans.isRefetching;
  const onRefresh = useCallback(() => {
    void sources.refetch();
    void links.refetch();
    void scans.refetch();
  }, [sources, links, scans]);

  const loadError = (sources.error ?? links.error ?? scans.error) as Error | null;

  return (
    <View style={styles.root}>
      <ScrollView
        contentContainerStyle={[
          styles.content,
          isWide && styles.contentWide,
          { paddingTop: insets.top + 16, paddingBottom: insets.bottom + 40 },
        ]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.accent} />}
      >
        <View style={styles.header}>
          <Pressable onPress={() => router.back()} hitSlop={8} style={styles.backBtn} accessibilityLabel="Back">
            <ArrowLeft size={20} color={Colors.textSecondary} />
          </Pressable>
          <Text style={styles.heading}>Following</Text>
          <Pressable
            disabled={isScanning || toScan.length === 0}
            onPress={() => void runScan(toScan)}
            style={({ pressed }) => [
              styles.scanBtn,
              (isScanning || toScan.length === 0) && styles.scanBtnDisabled,
              pressed && styles.pressed,
            ]}
          >
            {isScanning ? <ActivityIndicator size="small" color={Colors.white} /> : <ScanSearch size={15} color={Colors.white} />}
            <Text style={styles.scanText}>{isScanning ? "Checking" : toScan.length ? "Check " + toScan.length : "All checked"}</Text>
          </Pressable>
        </View>
        <Text style={[styles.muted, styles.subtitle]}>Everyone you follow across your agents, and where else they are.</Text>

        <View style={styles.segment}>
          <Pressable onPress={() => setTab("all")} style={[styles.segmentBtn, tab === "all" && styles.segmentBtnActive]}>
            <Text style={[styles.segmentText, tab === "all" && styles.segmentTextActive]}>Everyone</Text>
          </Pressable>
          <Pressable onPress={() => setTab("gaps")} style={[styles.segmentBtn, tab === "gaps" && styles.segmentBtnActive]}>
            <Text style={[styles.segmentText, tab === "gaps" && styles.segmentTextActive]}>{"Gaps · " + gapCount}</Text>
          </Pressable>
        </View>

        <View style={styles.searchBox}>
          <Search size={16} color={Colors.textMuted} />
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search people"
            placeholderTextColor={Colors.textMuted}
            style={styles.searchInput}
            autoCapitalize="none"
            autoCorrect={false}
            accessibilityLabel="Search people"
          />
        </View>

        {progress ? (
          <View style={styles.progressBox}>
            <View style={styles.progressTrack}>
              <View style={[styles.progressFill, { width: ((progress.done / progress.total) * 100 + "%") as unknown as number }]} />
            </View>
            <Text style={styles.muted}>
              {"Checked " + progress.done + " of " + progress.total + (progress.failed ? " · " + progress.failed + " couldn't be checked" : "")}
            </Text>
          </View>
        ) : null}

        {loadError ? (
          <View style={styles.errorCard}>
            <Text style={styles.errorText}>Couldn't load this screen: {loadError.message}</Text>
          </View>
        ) : null}

        {!loading && scanList.length === 0 && people.length > 0 && !isScanning ? (
          <View style={styles.introCard}>
            <Text style={styles.introTitle}>Find where the people you follow also post</Text>
            <Text style={styles.muted}>
              {"Checks each of your " + people.length + " people and companies once: the links on their profile, their link-in-bio page and website, and the same handle on other platforms. It uses at most " +
                MAX_LOOKUPS_PER_SOURCE + " AIsa lookups per source, so up to about $" + maxCost + " for this first check."}
            </Text>
            <Pressable onPress={() => void runScan(toScan)} style={({ pressed }) => [styles.introBtn, pressed && styles.pressed]}>
              <ScanSearch size={16} color={Colors.white} />
              <Text style={styles.scanText}>{"Check " + toScan.length + " sources"}</Text>
            </Pressable>
          </View>
        ) : null}

        {loading ? (
          <View style={styles.loadingBox}>
            <ActivityIndicator color={Colors.accent} />
          </View>
        ) : tab === "all" ? (
          <>
            <View style={styles.legend}>
              <View style={styles.legendItem}>
                <View style={[styles.legendDot, styles.chipFollowing]} />
                <Text style={styles.legendText}>You follow</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendDot, styles.chipAlso]} />
                <Text style={styles.legendText}>Also there</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendDot, styles.chipPossible]} />
                <Text style={styles.legendText}>Possible match</Text>
              </View>
            </View>
            <View style={styles.listCard}>
              {filtered.length === 0 ? (
                <Text style={[styles.muted, styles.emptyList]}>
                  {people.length === 0 ? "No people or companies in your agents yet." : "Nobody matches that search."}
                </Text>
              ) : (
                filtered.map((p) => (
                  <PersonRow
                    key={p.id}
                    person={p}
                    agentNames={p.agentIds.map((id) => agentName.get(id) ?? "").filter(Boolean).join(", ")}
                    onPress={() => setSelectedId(p.id)}
                  />
                ))
              )}
            </View>
            {skipped > 0 ? (
              <Text style={[styles.muted, styles.skippedNote]}>
                {skipped + (skipped === 1 ? " subreddit isn't" : " subreddits aren't") + " listed here, since they aren't people or companies."}
              </Text>
            ) : null}
          </>
        ) : (
          <GapsView people={filtered} agents={agents} onOpen={(id) => setSelectedId(id)} />
        )}
      </ScrollView>

      <Modal
        visible={!!selected}
        transparent
        animationType="slide"
        onRequestClose={() => setSelectedId(null)}
      >
        <View style={styles.sheetBackdrop}>
          <Pressable style={styles.flex1} onPress={() => setSelectedId(null)} accessibilityLabel="Close" />
          <View style={[styles.sheet, isWide && styles.sheetWide, { paddingBottom: insets.bottom + 16 }]}>
            <View style={styles.sheetTop}>
              <View style={styles.grabber} />
              <Pressable onPress={() => setSelectedId(null)} hitSlop={10} style={styles.sheetClose} accessibilityLabel="Close">
                <X size={20} color={Colors.textSecondary} />
              </Pressable>
            </View>
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.sheetContent}>
              {selected ? (
                <PersonPanel
                  person={selected}
                  agents={agents}
                  scanning={isScanning}
                  onRescan={() => void runScan(selected.sources.map((c) => c.id))}
                />
              ) : null}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background },
  content: { paddingHorizontal: 16 },
  contentWide: { maxWidth: 720, alignSelf: "center", width: "100%" },
  header: { flexDirection: "row", alignItems: "center", gap: 10 },
  backBtn: { padding: 4 },
  heading: { flex: 1, fontSize: 22, fontWeight: "800" as const, color: Colors.textPrimary },
  subtitle: { marginTop: 6, marginBottom: 16 },
  scanBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 36,
    paddingHorizontal: 12,
    borderRadius: 10,
    backgroundColor: Colors.accent,
  },
  scanBtnDisabled: { backgroundColor: Colors.input },
  scanText: { color: Colors.white, fontSize: 13, fontWeight: "700" as const },
  pressed: { opacity: 0.8 },
  flex1: { flex: 1 },
  gap4: { gap: 4 },
  gap6: { gap: 6 },
  gap12: { gap: 12 },
  muted: { fontSize: 12, color: Colors.textSecondary, lineHeight: 17 },
  segment: {
    flexDirection: "row",
    backgroundColor: Colors.input,
    borderRadius: 10,
    padding: 3,
    marginBottom: 12,
  },
  segmentBtn: { flex: 1, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center" },
  segmentBtnActive: { backgroundColor: Colors.card, borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.border },
  segmentText: { fontSize: 13, fontWeight: "600" as const, color: Colors.textSecondary },
  segmentTextActive: { color: Colors.textPrimary },
  searchBox: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    height: 40,
    paddingHorizontal: 12,
    borderRadius: 10,
    backgroundColor: Colors.input,
    borderWidth: 1,
    borderColor: Colors.border,
    marginBottom: 14,
  },
  searchInput: { flex: 1, fontSize: 14, color: Colors.textPrimary, paddingVertical: 0 },
  progressBox: { gap: 6, marginBottom: 14 },
  progressTrack: { height: 5, borderRadius: 3, backgroundColor: Colors.input, overflow: "hidden" },
  progressFill: { height: 5, backgroundColor: Colors.accent },
  errorCard: {
    padding: 14,
    borderRadius: 10,
    backgroundColor: Colors.destructiveBg,
    marginBottom: 14,
  },
  errorText: { color: Colors.destructive, fontSize: 13 },
  introCard: {
    gap: 8,
    padding: 16,
    borderRadius: 12,
    backgroundColor: Colors.card,
    borderWidth: 1,
    borderColor: "hsla(199, 89%, 48%, 0.4)",
    marginBottom: 16,
  },
  introTitle: { fontSize: 15, fontWeight: "700" as const, color: Colors.textPrimary },
  introBtn: {
    marginTop: 4,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    height: 42,
    borderRadius: 10,
    backgroundColor: Colors.accent,
  },
  loadingBox: { paddingVertical: 60, alignItems: "center" },
  legend: { flexDirection: "row", flexWrap: "wrap", gap: 14, marginBottom: 10 },
  legendItem: { flexDirection: "row", alignItems: "center", gap: 6 },
  legendDot: { width: 12, height: 12, borderRadius: 6, borderWidth: 1 },
  legendText: { fontSize: 11, color: Colors.textSecondary },
  listCard: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    overflow: "hidden",
  },
  emptyList: { padding: 24, textAlign: "center" },
  skippedNote: { marginTop: 10 },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  rowPressed: { backgroundColor: Colors.input },
  rowTitle: { flexDirection: "row", alignItems: "baseline", gap: 8 },
  rowName: { flexShrink: 1, fontSize: 15, fontWeight: "700" as const, color: Colors.textPrimary },
  rowAgents: { flexShrink: 1, fontSize: 11, color: Colors.textMuted },
  chipWrap: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    height: 28,
    paddingLeft: 4,
    paddingRight: 10,
    borderRadius: 14,
    borderWidth: 1,
  },
  chipFollowing: { backgroundColor: Colors.input, borderColor: Colors.input },
  chipAlso: { backgroundColor: "transparent", borderColor: Colors.accent },
  chipPossible: { backgroundColor: "transparent", borderColor: Colors.textMuted, borderStyle: "dashed" },
  chipText: { fontSize: 12, fontWeight: "600" as const, color: Colors.textPrimary },
  chipTextMuted: { color: Colors.textSecondary },
  avatarFallback: { backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  avatarText: { color: Colors.textPrimary, fontWeight: "700" as const },
  card: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  emptyCard: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 24,
    alignItems: "center",
  },
  gapHeader: { flexDirection: "row", alignItems: "center", gap: 10, paddingBottom: 8 },
  sectionTitle: {
    fontSize: 12,
    fontWeight: "700" as const,
    color: Colors.textSecondary,
    textTransform: "uppercase",
    letterSpacing: 0.6,
    marginTop: 18,
    marginBottom: 8,
  },
  box: {
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    backgroundColor: Colors.background,
  },
  boxRow: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 12, paddingVertical: 10 },
  boxRowBorder: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.border },
  accountLine: { flexDirection: "row", alignItems: "center", gap: 6, flexShrink: 1 },
  accountPlatform: { fontSize: 14, fontWeight: "700" as const, color: Colors.textPrimary },
  accountLabel: { flexShrink: 1, fontSize: 14, color: Colors.textSecondary },
  agentTag: { maxWidth: "40%", fontSize: 11, color: Colors.textMuted },
  evidenceRow: { flexDirection: "row", alignItems: "flex-start", gap: 5 },
  evidence: { flex: 1, fontSize: 12, color: Colors.success, lineHeight: 16 },
  removeLink: { fontSize: 12, color: Colors.textMuted, textDecorationLine: "underline" },
  followBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 36,
    minWidth: 86,
    justifyContent: "center",
    paddingHorizontal: 12,
    borderRadius: 10,
    backgroundColor: Colors.accent,
  },
  followText: { color: Colors.white, fontSize: 13, fontWeight: "700" as const },
  possibleCard: {
    gap: 8,
    padding: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderStyle: "dashed",
    borderColor: Colors.textMuted,
    marginBottom: 10,
  },
  question: { fontSize: 14, color: Colors.textPrimary, lineHeight: 19 },
  warningText: { fontSize: 12, color: Colors.warning, lineHeight: 16 },
  decisionRow: { flexDirection: "row", gap: 8 },
  samePersonBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    height: 40,
    borderRadius: 10,
    backgroundColor: Colors.accent,
  },
  samePersonText: { color: Colors.white, fontSize: 14, fontWeight: "700" as const },
  notThemBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    height: 40,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.card,
  },
  notThemText: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" as const },
  agentPicker: { gap: 6, marginBottom: 10 },
  agentChips: { gap: 8 },
  agentChip: {
    height: 32,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: Colors.border,
    justifyContent: "center",
  },
  agentChipActive: { borderColor: Colors.accent, backgroundColor: "hsla(199, 89%, 48%, 0.15)" },
  agentChipText: { fontSize: 13, color: Colors.textSecondary, fontWeight: "600" as const },
  agentChipTextActive: { color: Colors.textPrimary },
  outlineBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 34,
    paddingHorizontal: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  outlineBtnText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "600" as const },
  noneFound: { marginTop: 16 },
  panel: { paddingBottom: 8 },
  panelHeader: { flexDirection: "row", alignItems: "center", gap: 12 },
  panelName: { fontSize: 20, fontWeight: "800" as const, color: Colors.textPrimary },
  panelFooter: {
    marginTop: 20,
    paddingTop: 14,
    gap: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
  },
  footerRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 10 },
  footNote: { fontSize: 11, color: Colors.textMuted, lineHeight: 15 },
  sheetBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.6)" },
  sheet: {
    maxHeight: "88%",
    backgroundColor: Colors.card,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  sheetWide: { width: "100%", maxWidth: 640, alignSelf: "center" },
  sheetTop: { alignItems: "center", paddingTop: 8, paddingBottom: 4 },
  grabber: { width: 40, height: 5, borderRadius: 3, backgroundColor: Colors.border },
  sheetClose: { position: "absolute", right: 14, top: 10, padding: 4 },
  sheetContent: { paddingHorizontal: 18, paddingTop: 12 },
});
