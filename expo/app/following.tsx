// Following: everyone the user follows across all agents, and where else each
// person or company has an account ("Also on"). Opened from the Dashboard.
// Same data and rules as /following on the web.
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Alert,
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
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import { formatDistanceToNow } from "date-fns";
import {
  ArrowLeft,
  Check,
  ChevronRight,
  ExternalLink,
  Link2,
  Lock,
  Merge,
  RefreshCw,
  ScanSearch,
  Search,
  Trash2,
  UserPlus,
  X,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { PlatformBadge } from "@/components/PlatformBadge";
import { useToast } from "@/components/Toast";
import { useAgents, useChannelsAll, useDeleteChannel } from "@/lib/hooks";
import { openExternalLink } from "@/lib/open-link";
import { useYouTubeConnection } from "@/lib/useYouTubeConnection";
import { followOnPlatform, isConnectProvider, useConnections } from "@/lib/useConnections";
import { PLATFORM_META, isFollowableAccount, type Platform } from "@/lib/platforms";
import {
  buildPeople,
  initials,
  isPersonSource,
  personSummary,
  sameNameAs,
  type FoundAccount,
  type Person,
} from "@/lib/alsoOn";
import {
  useDecideLink,
  useFollowAccount,
  useIdentityLinks,
  useIdentityScans,
  useMergePeople,
  useScanSources,
  useSeparatePerson,
  scanStatus,
  type ScanJob,
} from "@/lib/useAlsoOn";

const RESCAN_AFTER_DAYS = 30;
// AIsa lookups one person's search may use (more when they're followed in
// several places, up to a cap, matching find-also-on), and AIsa's listed
// median price per call.
const MAX_LOOKUPS_PER_PERSON = 20;
const maxLookupsFor = (sources: number) => Math.min(MAX_LOOKUPS_PER_PERSON + 3 * Math.max(0, sources - 1), 30);
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
      <Text style={styles.accountPlatform} numberOfLines={1}>{platformLabel(platform)}</Text>
      <Text style={styles.accountLabel} numberOfLines={1}>{label}</Text>
      <ExternalLink size={12} color={Colors.textMuted} style={styles.noShrink} />
    </Pressable>
  );
}

function FollowButton({ account, agentId }: { account: FoundAccount; agentId: string | undefined }) {
  // Spotify podcast shows can't be followed as sources: open them instead.
  if (!isFollowableAccount(account.platform, account.url)) {
    return (
      <Pressable
        onPress={() => void openExternalLink(account.url)}
        style={({ pressed }) => [styles.openBtn, pressed && styles.pressed]}
        accessibilityRole="link"
        accessibilityLabel={PLATFORM_META[account.platform].openLabel}
      >
        <ExternalLink size={13} color={Colors.textPrimary} />
        <Text style={styles.openBtnText} numberOfLines={1}>{PLATFORM_META[account.platform].openLabel}</Text>
      </Pressable>
    );
  }
  return <FollowSourceButton account={account} agentId={agentId} />;
}

// "Add": puts the account in the chosen collection, so its posts reach the
// feed. Where the user connected that platform (YouTube, GitHub, Reddit), it
// also follows the account there; the other platforms don't let apps follow
// for their users, and the account's own link (next to its name) is there for
// following by hand. Same as the web.
function FollowSourceButton({ account, agentId }: { account: FoundAccount; agentId: string | undefined }) {
  const follow = useFollowAccount();
  const showToast = useToast();
  const youtube = useYouTubeConnection();
  const { data: connections = [] } = useConnections();
  const platform = account.platform;
  const label = platformLabel(platform);
  const connectProvider = isConnectProvider(platform) ? platform : null;
  const youtubeConnected = platform === "youtube" && youtube.status === "connected";
  const providerConnected = !!connectProvider && connections.some((c) => c.provider === connectProvider);
  return (
    <Pressable
      disabled={!agentId || follow.isPending}
      onPress={() => {
        if (!agentId) return;
        follow.mutate(
          { platform, url: account.url, agentId },
          {
            onSuccess: () => {
              if (youtubeConnected) {
                youtube
                  .subscribe(account.url)
                  .then((result) =>
                    showToast(result === "already" ? "Added. You were already subscribed on YouTube" : "Added and subscribed on YouTube", "success"),
                  )
                  .catch(() => showToast("Added, but couldn't subscribe on YouTube", "error"));
                return;
              }
              if (connectProvider && providerConnected) {
                followOnPlatform(connectProvider, account.url)
                  .then(({ already }) =>
                    showToast(already ? `Added. You already follow them on ${label}` : `Added and following on ${label}`, "success"),
                  )
                  .catch((e) => showToast(`Added, but couldn't follow on ${label}: ${e instanceof Error ? e.message : "try again"}`, "error"));
                return;
              }
              showToast("Added to your collection", "success");
            },
            onError: (e) => showToast(e instanceof Error ? e.message : "Couldn't add that account", "error"),
          },
        );
      }}
      style={({ pressed }) => [styles.followBtn, (pressed || follow.isPending) && styles.pressed]}
      accessibilityLabel={youtubeConnected || providerConnected ? `Add and follow on ${label}` : "Add to your collection"}
    >
      {follow.isPending ? (
        <ActivityIndicator size="small" color={Colors.white} />
      ) : (
        <>
          <UserPlus size={14} color={Colors.white} />
          <Text style={styles.followText}>Add</Text>
        </>
      )}
    </Pressable>
  );
}

function DecisionButtons({ account, channelIds }: { account: FoundAccount; channelIds: string[] }) {
  const decide = useDecideLink();
  const showToast = useToast();
  const run = (same: boolean) =>
    decide.mutate(
      { link: account.link, same, channelIds },
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

// "Combine with…": picks another card that's the same person (someone added
// twice under a name the search couldn't tie together) and joins the two.
// Shown in place of the person's details, inside the same sheet.
function CombinePicker({ person, people, initialPick, onCancel, onCombined }: {
  person: Person;
  people: Person[];
  initialPick: string | null;
  onCancel: () => void;
  onCombined: () => void;
}) {
  const merge = useMergePeople();
  const showToast = useToast();
  const [query, setQuery] = useState("");
  const [pickId, setPickId] = useState<string | null>(initialPick);
  const twins = new Set(sameNameAs(person, people).map((p) => p.id));
  const q = query.trim().toLowerCase();
  const candidates = people
    .filter((p) => p.id !== person.id)
    .filter((p) => !q || p.name.toLowerCase().includes(q) || p.following.some((f) => f.label.toLowerCase().includes(q)))
    .sort((a, b) => Number(twins.has(b.id)) - Number(twins.has(a.id)) || a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
  const pick = people.find((p) => p.id === pickId) ?? null;

  return (
    <View style={styles.panel}>
      <Text style={styles.panelName} numberOfLines={2}>Combine {person.name} with…</Text>
      <Text style={[styles.muted, styles.combineIntro]}>
        Pick the card that&apos;s the same person. Their accounts end up together on one card. You can separate them again later.
      </Text>
      <View style={styles.searchBox}>
        <Search size={15} color={Colors.textMuted} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder="Search people"
          placeholderTextColor={Colors.textMuted}
          style={styles.searchInput}
          autoCorrect={false}
          autoCapitalize="none"
          accessibilityLabel="Search people"
        />
      </View>
      <View style={[styles.box, styles.combineList]}>
        {candidates.length === 0 ? (
          <Text style={[styles.muted, styles.emptyList]}>Nobody matches that search.</Text>
        ) : (
          candidates.map((p, i) => {
            const active = p.id === pickId;
            return (
              <Pressable
                key={p.id}
                onPress={() => setPickId(p.id)}
                style={({ pressed }) => [
                  styles.boxRow,
                  i > 0 && styles.boxRowBorder,
                  active && styles.combineRowActive,
                  pressed && styles.rowPressed,
                ]}
                accessibilityRole="radio"
                accessibilityState={{ selected: active }}
              >
                <Avatar name={p.name} uri={p.thumbnail} />
                <View style={[styles.flex1, styles.gap6]}>
                  <View style={styles.rowTitle}>
                    <Text style={styles.rowName} numberOfLines={1}>{p.name}</Text>
                    {twins.has(p.id) ? <Text style={styles.sameNameTag}>Same name</Text> : null}
                  </View>
                  <View style={styles.chipWrap}>
                    {p.following.map((f) => (
                      <PlatformChip key={f.channel.id} platform={f.platform} variant="following" />
                    ))}
                  </View>
                </View>
                {active ? <Check size={18} color={Colors.accent} /> : null}
              </Pressable>
            );
          })
        )}
      </View>
      <View style={[styles.decisionRow, styles.combineActions]}>
        <Pressable onPress={onCancel} style={({ pressed }) => [styles.notThemBtn, pressed && styles.pressed]}>
          <Text style={styles.notThemText}>Cancel</Text>
        </Pressable>
        <Pressable
          disabled={!pick || merge.isPending}
          onPress={() => {
            if (!pick) return;
            merge.mutate(
              { into: person, other: pick },
              {
                onSuccess: () => {
                  showToast("Combined with " + pick.name, "success");
                  onCombined();
                },
                onError: (e) => showToast("Couldn't combine them: " + (e instanceof Error ? e.message : "try again"), "error"),
              },
            );
          }}
          style={({ pressed }) => [styles.samePersonBtn, (!pick || pressed || merge.isPending) && styles.disabled]}
        >
          {merge.isPending ? <ActivityIndicator size="small" color={Colors.white} /> : <Merge size={15} color={Colors.white} />}
          <Text style={styles.samePersonText}>Combine</Text>
        </Pressable>
      </View>
    </View>
  );
}

function PersonPanel({ person, people, agents, scanning, status, onRescan, onCombined }: {
  person: Person;
  people: Person[];
  agents: { id: string; name: string }[];
  scanning: boolean;
  // "Checking Taylor Swift…" while a search runs.
  status?: string | null;
  onRescan: () => void;
  // After a combine: keep this person open (their card id can change).
  onCombined: (sourceId: string) => void;
}) {
  const decide = useDecideLink();
  const showToast = useToast();
  const deleteChannel = useDeleteChannel();
  const separate = useSeparatePerson();
  // Picking a card to combine with: null when not combining, "" for no
  // card picked yet.
  const [combinePick, setCombinePick] = useState<string | null>(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => setCombinePick(null), [person.id]);
  const twins = sameNameAs(person, people);
  const startCombine = () => setCombinePick(twins.length === 1 ? twins[0].id : "");

  const confirmSeparate = () =>
    Alert.alert(
      `Separate ${person.name}'s cards?`,
      "The cards you combined go back to being separate cards. Nothing is removed from your collections.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Separate",
          onPress: () =>
            separate.mutate(
              { person },
              {
                onSuccess: () => showToast("Separated into their own cards again", "success"),
                onError: (e) => showToast("Couldn't separate them: " + (e instanceof Error ? e.message : "try again"), "error"),
              },
            ),
        },
      ],
    );
  const [agentId, setAgentId] = useState<string | undefined>(person.agentIds[0]);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => setAgentId(person.agentIds[0]), [person.id]);
  const agentName = new Map(agents.map((a) => [a.id, a.name]));

  // Stop following one of their accounts: removes that source from its
  // collection. Posts already in the feed stay.
  const confirmRemove = (a: Person["following"][number]) => {
    const collection = agentName.get(a.channel.agent_id) ?? "your collection";
    const platformName = platformLabel(a.platform);
    Alert.alert(
      `Remove ${person.name} on ${platformName}?`,
      `${a.label} is removed from ${collection}, so new posts from it stop coming in. What's already in your feed stays.` +
        (person.following.length === 1 ? " This is the only account you follow for them, so they'll leave your People list." : ""),
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Remove",
          style: "destructive",
          onPress: () =>
            deleteChannel.mutate(a.channel.id, {
              onSuccess: () => showToast(`Removed. You no longer follow them on ${platformName} here.`, "success"),
              onError: (e) => showToast("Couldn't remove it: " + (e instanceof Error ? e.message : "try again"), "error"),
            }),
        },
      ],
    );
  };

  if (combinePick !== null) {
    return (
      <CombinePicker
        person={person}
        people={people}
        initialPick={combinePick || null}
        onCancel={() => setCombinePick(null)}
        onCombined={() => {
          setCombinePick(null);
          onCombined(person.sources[0].id);
        }}
      />
    );
  }

  return (
    <View style={styles.panel}>
      <View style={styles.panelHeader}>
        <Avatar name={person.name} uri={person.thumbnail} size={56} />
        <View style={styles.flex1}>
          <Text style={styles.panelName} numberOfLines={2}>{person.name}</Text>
          <Text style={styles.muted}>{personSummary(person, platformLabel)}</Text>
        </View>
      </View>
      {people.length > 1 ? (
        <Pressable
          onPress={startCombine}
          style={({ pressed }) => [styles.outlineBtn, styles.combineBtn, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityLabel="Combine with another card that's the same person"
        >
          <Merge size={14} color={Colors.textPrimary} />
          <Text style={styles.outlineBtnText}>Combine with another card</Text>
        </Pressable>
      ) : null}

      {twins.length > 0 ? (
        <View style={styles.twinCard}>
          <Text style={styles.question}>
            {twins.length === 1 ? "Another card is" : twins.length + " other cards are"} also called{" "}
            <Text style={styles.bold}>{person.name}</Text>. If it&apos;s the same person, combine them so all their accounts are on one card.
          </Text>
          <Pressable onPress={startCombine} style={({ pressed }) => [styles.samePersonBtn, pressed && styles.pressed]}>
            <Merge size={15} color={Colors.white} />
            <Text style={styles.samePersonText}>{twins.length === 1 ? "Combine with that card" : "Choose which to combine"}</Text>
          </Pressable>
        </View>
      ) : null}

      <Text style={styles.sectionTitle}>You follow</Text>
      <View style={styles.box}>
        {person.following.map((a, i) => (
          <View key={a.channel.id} style={[styles.boxRow, i > 0 && styles.boxRowBorder]}>
            {/* Account on the first line, collection underneath, so nothing
                has to squeeze onto one line on a narrow phone. */}
            <View style={[styles.flex1, styles.gap4]}>
              <AccountLine platform={a.platform} label={a.label} url={a.url} />
              <Text style={styles.agentTag} numberOfLines={1}>
                {"In " + (agentName.get(a.channel.agent_id) ?? "a collection")}
              </Text>
              {a.channel.is_private ? (
                <>
                  <View style={styles.privateNote}>
                    <Lock size={11} color={Colors.textMuted} />
                    <Text style={styles.privateNoteText}>Private account. Its posts aren&apos;t in your feed.</Text>
                  </View>
                  <Pressable
                    onPress={() => void openExternalLink(a.url)}
                    style={({ pressed }) => [styles.openBtn, pressed && styles.pressed]}
                    accessibilityRole="link"
                    accessibilityLabel={PLATFORM_META[a.platform].openLabel}
                  >
                    <ExternalLink size={13} color={Colors.textPrimary} />
                    <Text style={styles.openBtnText} numberOfLines={1}>{PLATFORM_META[a.platform].openLabel}</Text>
                  </Pressable>
                </>
              ) : null}
            </View>
            <Pressable
              onPress={() => confirmRemove(a)}
              disabled={deleteChannel.isPending}
              hitSlop={8}
              style={({ pressed }) => [styles.removeBtn, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel={`Remove ${platformLabel(a.platform)} ${a.label}`}
            >
              <Trash2 size={16} color={Colors.textMuted} />
            </Pressable>
          </View>
        ))}
      </View>
      {person.merges.length > 0 ? (
        <View style={styles.mergedRow}>
          <Merge size={13} color={Colors.textMuted} />
          <Text style={[styles.muted, styles.flex1]}>You combined separate cards into this one.</Text>
          <Pressable onPress={confirmSeparate} disabled={separate.isPending} hitSlop={8}>
            <Text style={styles.removeLink}>Separate them</Text>
          </Pressable>
        </View>
      ) : null}

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
                        { link: a.link, same: false, channelIds: person.sources.map((c) => c.id) },
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
              <DecisionButtons account={a} channelIds={person.sources.map((c) => c.id)} />
            </View>
          ))}
        </>
      ) : null}

      {person.lastScannedAt && person.also.length === 0 && person.possible.length === 0 ? (
        <Text style={[styles.muted, styles.noneFound]}>
          No other accounts found. Their profile doesn't link anywhere we can follow, and no handle or name like theirs turned up on X, Instagram, YouTube, LinkedIn or Reddit.
        </Text>
      ) : null}

      <View style={styles.panelFooter}>
        <View style={styles.footerRow}>
          <Text style={styles.muted}>
            {person.lastScannedAt
              ? "Last searched " + formatDistanceToNow(new Date(person.lastScannedAt), { addSuffix: true })
              : "Not searched yet"}
          </Text>
          <Pressable
            disabled={scanning}
            onPress={onRescan}
            style={({ pressed }) => [styles.outlineBtn, (pressed || scanning) && styles.pressed]}
          >
            {scanning ? <ActivityIndicator size="small" color={Colors.accent} /> : <RefreshCw size={14} color={Colors.textPrimary} />}
            <Text style={styles.outlineBtnText}>{person.lastScannedAt ? "Find more accounts" : "Find accounts"}</Text>
          </Pressable>
        </View>
        {scanning && status ? <Text style={styles.muted}>{status}</Text> : null}
        {person.scanErrors.length > 0 ? (
          <Text style={styles.warningText}>Last check had a problem: {person.scanErrors[0]}</Text>
        ) : null}
        <Text style={styles.footNote}>
          Matches come from links on their own profiles, their link-in-bio page and website, and handles like theirs on other platforms. A handle alone is only ever a possible match.
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
      <ChevronRight size={18} color={Colors.textMuted} style={styles.rowChevron} />
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
              <DecisionButtons account={account} channelIds={person.sources.map((c) => c.id)} />
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
  // A collection and the Feeds tab open this screen with agentId to show that
  // collection's people (openedAt changes on every open, so it applies again).
  const params = useLocalSearchParams<{ agentId?: string; openedAt?: string }>();
  const [agentFilter, setAgentFilter] = useState<string>(params.agentId ?? "all");
  useEffect(() => {
    setAgentFilter(params.agentId ?? "all");
  }, [params.agentId, params.openedAt]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  // After two cards are combined the person's id can change, so they're found
  // again by one of their sources and the sheet stays open.
  const [followSourceId, setFollowSourceId] = useState<string | null>(null);
  const openPerson = (id: string | null) => {
    setFollowSourceId(null);
    setSelectedId(id);
  };

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

  // People followed in the chosen agent (a person can be in several), then the name search.
  const inAgent = agentFilter === "all" ? people : people.filter((p) => p.agentIds.includes(agentFilter));
  const q = query.trim().toLowerCase();
  const filtered = q
    ? inAgent.filter((p) => p.name.toLowerCase().includes(q) || p.following.some((f) => f.label.toLowerCase().includes(q)))
    : inAgent;

  const gapCount = inAgent.reduce((n, p) => n + p.also.length + p.possible.length, 0);
  const scanList = scans.data ?? [];
  const staleBefore = Date.now() - RESCAN_AFTER_DAYS * 24 * 60 * 60 * 1000;
  const scanTimes = new Map(scanList.map((s) => [s.channel_id, new Date(s.scanned_at).getTime()]));
  // One search per person, covering all of their sources, when any of them
  // hasn't been searched lately.
  const jobFor = (p: Person): ScanJob => ({ name: p.name, channelIds: p.sources.map((c) => c.id) });
  const toScan = people
    .filter((p) => p.sources.some((c) => !scanTimes.has(c.id) || (scanTimes.get(c.id) ?? 0) < staleBefore))
    .map(jobFor);
  const maxCost = (
    toScan.reduce((n, job) => n + maxLookupsFor(job.channelIds.length), 0) * AISA_PRICE_PER_CALL
  ).toFixed(2);
  const loading = sources.isLoading || scans.isLoading;
  const selected =
    (followSourceId ? people.find((p) => p.sources.some((c) => c.id === followSourceId)) : undefined) ??
    people.find((p) => p.id === selectedId) ??
    null;

  const runScan = useCallback(
    async (jobs: ScanJob[]) => {
      const result = await scan(jobs);
      if (!result) return;
      if (result.failed) {
        showToast(result.failed + " of " + result.total + " couldn't be checked. " + (result.firstError ?? ""), "error");
      } else {
        showToast(
          result.total === 1 && jobs[0] ? "Searched other platforms for " + jobs[0].name : "Searched other platforms for " + result.total + " people",
          "success",
        );
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
          <Text style={styles.heading}>People</Text>
          {isScanning || (!loading && toScan.length > 0) ? (
            <Pressable
              disabled={isScanning}
              onPress={() => void runScan(toScan)}
              style={({ pressed }) => [styles.scanBtn, (pressed || isScanning) && styles.pressed]}
              accessibilityLabel={isScanning ? "Searching" : "Find more accounts for " + toScan.length + (toScan.length === 1 ? " person" : " people")}
            >
              {isScanning ? <ActivityIndicator size="small" color={Colors.white} /> : <ScanSearch size={15} color={Colors.white} />}
              <Text style={styles.scanText}>{isScanning ? "Searching" : "Find more (" + toScan.length + ")"}</Text>
            </Pressable>
          ) : null}
        </View>
        <Text style={[styles.muted, styles.subtitle]}>Everyone you follow across your collections, and where else they are.</Text>

        <View style={styles.controlsRow}>
          <View style={styles.segment}>
            <Pressable onPress={() => setTab("all")} style={[styles.segmentBtn, tab === "all" && styles.segmentBtnActive]}>
              <Text style={[styles.segmentText, tab === "all" && styles.segmentTextActive]} numberOfLines={1}>Everyone</Text>
            </Pressable>
            <Pressable onPress={() => setTab("gaps")} style={[styles.segmentBtn, tab === "gaps" && styles.segmentBtnActive]}>
              <Text style={[styles.segmentText, tab === "gaps" && styles.segmentTextActive]} numberOfLines={1}>{"Gaps · " + gapCount}</Text>
            </Pressable>
          </View>

          <View style={styles.searchBox}>
            <Search size={15} color={Colors.textMuted} />
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
            {query ? (
              <Pressable onPress={() => setQuery("")} hitSlop={8} accessibilityLabel="Clear search">
                <X size={15} color={Colors.textMuted} />
              </Pressable>
            ) : null}
          </View>
        </View>

        {/* Filter by agent */}
        {agents.length > 1 ? (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.agentFilter}
            contentContainerStyle={styles.agentChips}
          >
            {[{ id: "all", name: "All collections" }, ...agents].map((a) => {
              const active = a.id === agentFilter;
              return (
                <Pressable
                  key={a.id}
                  onPress={() => setAgentFilter(a.id)}
                  style={[styles.agentChip, active && styles.agentChipActive]}
                  accessibilityRole="button"
                  accessibilityState={{ selected: active }}
                >
                  <Text style={[styles.agentChipText, active && styles.agentChipTextActive]}>{a.name}</Text>
                </Pressable>
              );
            })}
          </ScrollView>
        ) : null}

        {progress ? (
          <View style={styles.progressBox}>
            <View style={styles.progressTrack}>
              <View style={[styles.progressFill, { width: ((progress.done / progress.total) * 100 + "%") as unknown as number }]} />
            </View>
            <Text style={styles.muted}>
              {scanStatus(progress) + (progress.failed ? " · " + progress.failed + " couldn't be searched" : "")}
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
              {"Checks each of your " + people.length + " people and companies once: the links on their profile, their link-in-bio page and website, and handles like theirs on other platforms. Each person is searched once, across all the places you follow them, using at most " +
                MAX_LOOKUPS_PER_PERSON + " to 30 AIsa lookups, so up to about $" + maxCost + " for this first check."}
            </Text>
            <Pressable onPress={() => void runScan(toScan)} style={({ pressed }) => [styles.introBtn, pressed && styles.pressed]}>
              <ScanSearch size={16} color={Colors.white} />
              <Text style={styles.scanText}>{"Check " + toScan.length + (toScan.length === 1 ? " person" : " people")}</Text>
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
                  {people.length === 0 ? "No people or companies in your collections yet." : "Nobody matches that search."}
                </Text>
              ) : (
                filtered.map((p) => (
                  <PersonRow
                    key={p.id}
                    person={p}
                    agentNames={p.agentIds.map((id) => agentName.get(id) ?? "").filter(Boolean).join(", ")}
                    onPress={() => openPerson(p.id)}
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
          <GapsView people={filtered} agents={agents} onOpen={(id) => openPerson(id)} />
        )}
      </ScrollView>

      <Modal
        visible={!!selected}
        transparent
        animationType="slide"
        onRequestClose={() => openPerson(null)}
      >
        <View style={styles.sheetBackdrop}>
          <Pressable style={styles.flex1} onPress={() => openPerson(null)} accessibilityLabel="Close" />
          <View style={[styles.sheet, isWide && styles.sheetWide, { paddingBottom: insets.bottom + 16 }]}>
            {/* The content stops above the home indicator with the same gap as
                the sides and is clipped with rounded corners there, so the
                phone's rounded corners never cut through buttons or text. */}
            <View style={styles.sheetTop}>
              <View style={styles.grabber} />
              <Pressable onPress={() => openPerson(null)} hitSlop={10} style={styles.sheetClose} accessibilityLabel="Close">
                <X size={20} color={Colors.textSecondary} />
              </Pressable>
            </View>
            <ScrollView style={styles.sheetScroll} showsVerticalScrollIndicator={false} contentContainerStyle={styles.sheetContent}>
              {selected ? (
                <PersonPanel
                  person={selected}
                  people={people}
                  agents={agents}
                  onCombined={setFollowSourceId}
                  scanning={isScanning}
                  status={progress ? scanStatus(progress) : null}
                  onRescan={() => void runScan([jobFor(selected)])}
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
  scanText: { color: Colors.white, fontSize: 13, fontWeight: "700" as const },
  pressed: { opacity: 0.8 },
  flex1: { flex: 1 },
  gap4: { gap: 4 },
  gap6: { gap: 6 },
  gap12: { gap: 12 },
  muted: { fontSize: 12, color: Colors.textSecondary, lineHeight: 17 },
  // Tabs and search share one row, like the web.
  controlsRow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 14 },
  // Web tabs: muted track, active tab in the page background colour.
  segment: {
    flexDirection: "row",
    backgroundColor: Colors.input,
    borderRadius: 9,
    padding: 3,
  },
  segmentBtn: { height: 30, paddingHorizontal: 12, borderRadius: 7, alignItems: "center", justifyContent: "center" },
  segmentBtnActive: { backgroundColor: Colors.background },
  segmentText: { fontSize: 13, fontWeight: "600" as const, color: Colors.textSecondary },
  segmentTextActive: { color: Colors.textPrimary },
  searchBox: {
    flex: 1,
    minWidth: 0,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 36,
    paddingHorizontal: 10,
    borderRadius: 9,
    backgroundColor: Colors.input,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
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
    alignItems: "flex-start",
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  rowPressed: { backgroundColor: Colors.input },
  rowChevron: { marginTop: 2 },
  rowTitle: { flexDirection: "row", alignItems: "baseline", gap: 8 },
  rowName: { flexShrink: 1, fontSize: 15, fontWeight: "600" as const, color: Colors.textPrimary },
  rowAgents: { flexShrink: 1, fontSize: 11, color: Colors.textMuted },
  chipWrap: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    height: 26,
    paddingLeft: 6,
    paddingRight: 10,
    borderRadius: 13,
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
  // The platform name never wraps ("YouTub/e"); the handle gives way instead.
  accountLine: { flexDirection: "row", alignItems: "center", gap: 6, flexShrink: 1, minWidth: 0 },
  accountPlatform: { flexShrink: 0, fontSize: 14, fontWeight: "700" as const, color: Colors.textPrimary },
  accountLabel: { flexShrink: 1, minWidth: 0, fontSize: 14, color: Colors.textSecondary },
  noShrink: { flexShrink: 0 },
  agentTag: { fontSize: 11, color: Colors.textMuted },
  privateNote: { flexDirection: "row", alignItems: "center", gap: 4, marginTop: 2 },
  privateNoteText: { flex: 1, fontSize: 11, color: Colors.textMuted },
  openBtn: {
    alignSelf: "flex-start",
    marginTop: 2,
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    height: 32,
    paddingHorizontal: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  openBtnText: { color: Colors.textPrimary, fontSize: 12, fontWeight: "600" as const },
  removeBtn: { width: 36, height: 36, alignItems: "center", justifyContent: "center" },
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
  agentFilter: { flexGrow: 0, marginTop: -4, marginBottom: 14 },
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
  // Dark enough that the list behind the person sheet doesn't pull the eye.
  sheetBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.8)" },
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
  sheetScroll: { overflow: "hidden", borderBottomLeftRadius: 20, borderBottomRightRadius: 20 },
  sheetContent: { paddingHorizontal: 18, paddingTop: 12, paddingBottom: 12 },
  disabled: { opacity: 0.5 },
  bold: { fontWeight: "700" as const },
  combineBtn: { alignSelf: "flex-start", marginTop: 12 },
  twinCard: {
    gap: 10,
    marginTop: 14,
    padding: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "hsla(199, 89%, 48%, 0.4)",
    backgroundColor: "hsla(199, 89%, 48%, 0.08)",
  },
  mergedRow: { flexDirection: "row", alignItems: "center", gap: 6, marginTop: 8 },
  combineIntro: { marginTop: 6, marginBottom: 12 },
  combineList: { marginTop: 12 },
  combineRowActive: { backgroundColor: "hsla(199, 89%, 48%, 0.15)" },
  combineActions: { marginTop: 14 },
  sameNameTag: {
    flexShrink: 0,
    fontSize: 11,
    fontWeight: "600" as const,
    color: Colors.textSecondary,
    backgroundColor: Colors.input,
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
    overflow: "hidden",
  },
});
