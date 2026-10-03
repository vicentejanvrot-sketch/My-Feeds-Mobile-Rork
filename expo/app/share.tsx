// Share to My Feeds: the card that opens over the app when another app shares
// a profile or post to My Feeds (Android share sheet, see app/_layout.tsx), or
// from "Add from link" on People. Shows the account (post links show who
// posted), where it already is, a suggested collection, their other confirmed
// accounts, and adds it to one or more collections in one step. Same flow as
// the web app's ShareAddCard and the iOS share extension.
import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  BackHandler,
  KeyboardAvoidingView,
  Platform as RNPlatform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import * as Clipboard from "expo-clipboard";
import { useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Check, Lock, Plus, Rss, Sparkles, X } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { PlatformLogo } from "@/components/PlatformBadge";
import { useToast } from "@/components/Toast";
import { useAuth } from "@/lib/auth-provider";
import { PLATFORM_META, type Platform } from "@/lib/platforms";
import {
  addShared,
  createCollection,
  joinNames,
  previewShare,
  PRIORITY_NAMES,
  sortCollections,
  undoShared,
  UNSORTED_ID,
  type AddedChannel,
  type SharePreview,
} from "@/lib/shareAdd";

type Step = "input" | "loading" | "error" | "card" | "picker" | "adding" | "done";

const LINK_HINT = /(youtube\.com|youtu\.be|x\.com|twitter\.com|instagram\.com|linkedin\.com|lnkd\.in|tiktok\.com|facebook\.com|fb\.watch|reddit\.com|github\.com|music\.apple\.com|podcasts\.apple\.com|spotify)/i;

const plainName = (name: string) => name.replace(/\s*\(@[^)]*\)\s*$/, "");
const platformLabel = (p: string) => PLATFORM_META[p as Platform]?.label ?? p;

export default function ShareScreen() {
  const params = useLocalSearchParams<{ text?: string; from?: string }>();
  const shared = typeof params.text === "string" ? params.text : "";
  const fromShareSheet = params.from === "share";
  const insets = useSafeAreaInsets();
  const queryClient = useQueryClient();
  const showToast = useToast();
  const { status } = useAuth();

  const [input, setInput] = useState(shared);
  const [step, setStep] = useState<Step>(shared.trim() ? "loading" : "input");
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<SharePreview | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [addingMore, setAddingMore] = useState(false);
  const [includeAlsoOn, setIncludeAlsoOn] = useState(true);
  const [priority, setPriority] = useState(3);
  const [added, setAdded] = useState<AddedChannel[]>([]);
  // "New collection" in the picker.
  const [newOpen, setNewOpen] = useState(false);
  const [newName, setNewName] = useState("");
  const [creating, setCreating] = useState(false);

  // Leaving: from another app's share sheet, go back to that app (Android).
  const close = useCallback(() => {
    if (fromShareSheet && RNPlatform.OS === "android") {
      BackHandler.exitApp();
      return;
    }
    if (router.canGoBack()) router.back();
    else router.replace("/(tabs)");
  }, [fromShareSheet]);

  const lookUp = useCallback(async (value: string) => {
    if (!value.trim()) return;
    setStep("loading");
    setError(null);
    try {
      const p = await previewShare(value);
      setPreview(p);
      // Nothing is picked for the user: Add stays off until they choose.
      setSelected([]);
      setAddingMore(false);
      setIncludeAlsoOn(true);
      setPriority(3);
      setStep("card");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn't read that link.");
      setStep("error");
    }
  }, []);

  useEffect(() => {
    if (status === "authenticated" && shared.trim()) void lookUp(shared);
  }, [status, shared, lookUp]);

  // "Add from link" with a profile link already copied: fill it in.
  useEffect(() => {
    if (shared.trim() || RNPlatform.OS === "web") return;
    Clipboard.getStringAsync()
      .then((text) => {
        if (text && LINK_HINT.test(text)) setInput((cur) => cur || text.trim());
      })
      .catch(() => {});
  }, [shared]);

  const already = preview?.inCollections ?? [];
  const alreadyIds = useMemo(() => new Set(already.map((c) => c.agentId)), [already]);
  const nameOf = (id: string) =>
    id === UNSORTED_ID ? "Unsorted" : preview?.collections.find((c) => c.id === id)?.name ?? "";
  const isSuggested = !!preview?.suggestion && selected.length === 1 && selected[0] === preview.suggestion.agentId && !addingMore;
  const showAlreadyBox = step === "card" && already.length > 0 && !addingMore;
  const alsoNames = preview ? joinNames([...new Set(preview.alsoOn.map((a) => platformLabel(a.platform)))]) : "";
  const backLabel = "Done";

  const toggle = (id: string) => {
    if (alreadyIds.has(id)) return;
    setSelected((cur) => {
      if (cur.includes(id)) return cur.filter((c) => c !== id);
      if (id === UNSORTED_ID) return [UNSORTED_ID];
      return cur.filter((c) => c !== UNSORTED_ID).concat(id);
    });
  };

  const addLabel =
    selected.length === 0
      ? "Pick a collection"
      : selected.length === 1
      ? selected[0] === UNSORTED_ID ? "Save to Unsorted" : `Add to ${nameOf(selected[0])}`
      : `Add to ${selected.length} collections`;

  const add = async () => {
    if (!preview || selected.length === 0) return;
    setStep("adding");
    try {
      const rows = await addShared({ preview, agentIds: selected, priority, includeAlsoOn: includeAlsoOn && preview.alsoOn.length > 0 });
      setAdded(rows);
      void queryClient.invalidateQueries();
      setStep("done");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "Couldn't add that account.", "error");
      setStep("card");
    }
  };

  const createNew = async () => {
    if (!preview || !newName.trim() || creating) return;
    setCreating(true);
    try {
      const made = await createCollection(newName, preview.collections);
      setPreview((p) => (p && !p.collections.some((c) => c.id === made.id) ? { ...p, collections: [...p.collections, made] } : p));
      setSelected((cur) => (cur.includes(made.id) ? cur : cur.filter((c) => c !== UNSORTED_ID).concat(made.id)));
      setNewName("");
      setNewOpen(false);
      void queryClient.invalidateQueries({ queryKey: ["agents"] });
    } catch (e) {
      showToast(e instanceof Error ? e.message : "Couldn't create that collection.", "error");
    } finally {
      setCreating(false);
    }
  };

  const undo = async () => {
    try {
      await undoShared(added);
      void queryClient.invalidateQueries();
      setAdded([]);
      setStep("card");
      showToast("Removed", "success");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "Couldn't undo that.", "error");
    }
  };

  const pickerRows = preview
    ? sortCollections(
        [...preview.collections, { id: UNSORTED_ID, name: "Unsorted" }].filter(
          (c, _i, all) => !(c.id === UNSORTED_ID && all.some((o) => o.id !== UNSORTED_ID && o.name === "Unsorted")),
        ),
      )
    : [];

  return (
    <KeyboardAvoidingView behavior={RNPlatform.OS === "ios" ? "padding" : undefined} style={styles.backdrop}>
      <Pressable style={StyleSheet.absoluteFill} onPress={close} accessibilityLabel="Close" />
      <View style={[styles.sheet, { paddingBottom: insets.bottom + 24 }]}>
        <View style={styles.grabber} />
        <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.sheetContent} bounces={false}>
          {/* header */}
          <View style={styles.headerRow}>
            {step === "picker" ? (
              <Pressable onPress={() => setStep("card")} style={styles.roundBtn} accessibilityLabel="Back" hitSlop={6}>
                <ArrowLeft size={18} color={Colors.textPrimary} />
              </Pressable>
            ) : (
              <View style={styles.appIcon}>
                <Rss size={17} color={Colors.accent} strokeWidth={2.4} />
              </View>
            )}
            <Text style={styles.headerTitle}>{step === "picker" ? "Choose collections" : "Add to My Feeds"}</Text>
            <Pressable onPress={close} style={styles.roundBtn} accessibilityLabel="Close" hitSlop={6}>
              <X size={16} color={Colors.textSecondary} />
            </Pressable>
          </View>

          {status === "unauthenticated" ? (
            <View style={styles.block}>
              <Text style={styles.body}>Sign in to My Feeds first, then share again.</Text>
              <Pressable style={styles.primaryBtn} onPress={() => router.replace("/auth/login" as never)}>
                <Text style={styles.primaryText}>Sign in</Text>
              </Pressable>
            </View>
          ) : null}

          {status !== "unauthenticated" && step === "input" ? (
            <View style={styles.block}>
              <Text style={styles.muted}>Paste a profile or post link from YouTube, X, Instagram, LinkedIn, TikTok, Facebook or Reddit.</Text>
              <TextInput
                value={input}
                onChangeText={setInput}
                placeholder="https://www.instagram.com/name"
                placeholderTextColor={Colors.textMuted}
                autoCapitalize="none"
                autoCorrect={false}
                keyboardType="url"
                style={styles.input}
                onSubmitEditing={() => void lookUp(input)}
                accessibilityLabel="Profile or post link"
              />
              <Pressable style={[styles.primaryBtn, !input.trim() && styles.disabled]} disabled={!input.trim()} onPress={() => void lookUp(input)}>
                <Text style={styles.primaryText}>Find account</Text>
              </Pressable>
            </View>
          ) : null}

          {step === "loading" || (status === "loading" && shared.trim()) ? (
            <View style={styles.block}>
              <View style={styles.accountRow}>
                <View style={[styles.avatar, styles.skeleton]} />
                <View style={{ flex: 1, gap: 8 }}>
                  <View style={[styles.skeleton, { width: "60%", height: 14, borderRadius: 6 }]} />
                  <View style={[styles.skeleton, { width: "40%", height: 11, borderRadius: 6 }]} />
                </View>
              </View>
              <View style={styles.inline}>
                <ActivityIndicator size="small" color={Colors.accent} />
                <Text style={styles.muted}>Looking up the account…</Text>
              </View>
            </View>
          ) : null}

          {step === "error" ? (
            <View style={styles.block}>
              <View style={styles.errorBox}>
                <Text style={styles.body}>{error}</Text>
              </View>
              <View style={styles.twoBtns}>
                <Pressable style={[styles.secondaryBtn, { flex: 1 }]} onPress={() => setStep("input")}>
                  <Text style={styles.secondaryText}>Try another link</Text>
                </Pressable>
                <Pressable style={[styles.primaryBtn, { flex: 1 }]} onPress={() => void lookUp(input)}>
                  <Text style={styles.primaryText}>Try again</Text>
                </Pressable>
              </View>
            </View>
          ) : null}

          {preview && (step === "card" || step === "picker" || step === "adding") ? (
            <View style={styles.accountRow}>
              <View>
                {preview.account.thumbnail ? (
                  <Image source={{ uri: preview.account.thumbnail }} style={styles.avatar} contentFit="cover" />
                ) : (
                  <View style={[styles.avatar, styles.avatarFallback]}>
                    <Text style={styles.avatarInitial}>{plainName(preview.account.name).slice(0, 1).toUpperCase()}</Text>
                  </View>
                )}
                <View style={styles.platformDot}>
                  <PlatformLogo platform={preview.platform} size={15} />
                </View>
              </View>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text style={styles.accountName} numberOfLines={1}>{plainName(preview.account.name)}</Text>
                <Text style={styles.muted} numberOfLines={1}>
                  {preview.account.handle && !/^\d+$/.test(preview.account.handle)
                    ? `${preview.platform === "linkedin" ? "" : "@"}${preview.account.handle} · `
                    : ""}
                  {preview.platformLabel}
                </Text>
                <Text style={styles.small}>
                  {preview.kind === "post" ? "From a post you shared. This is who posted it." : "From the profile you shared."}
                </Text>
              </View>
            </View>
          ) : null}

          {preview?.account.isPrivate && (step === "card" || step === "adding") ? (
            <View style={styles.alsoBox}>
              <Lock size={16} color={Colors.textMuted} />
              <View style={{ flex: 1, gap: 2 }}>
                <Text style={styles.bodyStrong}>Private account</Text>
                <Text style={styles.muted}>
                  {`It's added as a private account: it shows on People with a button to open it in ${preview.platformLabel}. Its posts won't appear in your feed.`}
                </Text>
              </View>
            </View>
          ) : null}

          {showAlreadyBox ? (
            <View style={styles.block}>
              <View style={styles.successBox}>
                <Check size={20} color={Colors.success} />
                <View style={{ flex: 1 }}>
                  <Text style={styles.bodyStrong}>Already in {joinNames(already.map((c) => c.agentName))}</Text>
                  <Text style={styles.muted}>You already get their posts in My Feeds.</Text>
                </View>
              </View>
              <View style={styles.twoBtns}>
                <Pressable
                  style={[styles.secondaryBtn, { flex: 1 }]}
                  onPress={() => {
                    setAddingMore(true);
                    setSelected([]);
                    setStep("picker");
                  }}
                >
                  <Text style={styles.secondaryText}>Add to another</Text>
                </Pressable>
                <Pressable style={[styles.primaryBtn, { flex: 1 }]} onPress={close}>
                  <Text style={styles.primaryText}>{backLabel}</Text>
                </Pressable>
              </View>
            </View>
          ) : null}

          {preview && (step === "card" || step === "adding") && !showAlreadyBox ? (
            <View style={styles.block}>
              {addingMore ? (
                <View style={styles.inline}>
                  <Check size={15} color={Colors.success} />
                  <Text style={[styles.small, { color: Colors.success }]}>Already in {joinNames(already.map((c) => c.agentName))}</Text>
                </View>
              ) : null}

              <View style={{ gap: 10 }}>
                <View style={styles.labelRow}>
                  <Text style={styles.label}>Collection</Text>
                  <Pressable onPress={() => setStep("picker")} hitSlop={8}>
                    <Text style={styles.link}>Change</Text>
                  </Pressable>
                </View>
                <View style={styles.chips}>
                  {selected.map((id) => (
                    <Pressable key={id} onPress={() => setStep("picker")} style={styles.chip}>
                      <Text style={styles.chipText}>{nameOf(id)}</Text>
                    </Pressable>
                  ))}
                  {selected.length === 0 ? (
                    <Pressable onPress={() => setStep("picker")} style={styles.chipEmpty}>
                      <Text style={styles.muted}>Pick a collection</Text>
                    </Pressable>
                  ) : null}
                </View>
                {isSuggested && preview.suggestion?.reason ? (
                  <View style={styles.inline}>
                    <Sparkles size={14} color={Colors.accent} />
                    <Text style={[styles.small, { flex: 1 }]}>Suggested. {preview.suggestion.reason}</Text>
                  </View>
                ) : null}
              </View>

              {preview.alsoOn.length > 0 ? (
                <View style={styles.alsoBox}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.bodyStrong}>Also on {alsoNames}</Text>
                    <Text style={styles.small}>Same person, matched from their profile links. Add those too?</Text>
                  </View>
                  <Switch
                    value={includeAlsoOn}
                    onValueChange={setIncludeAlsoOn}
                    trackColor={{ true: Colors.accent, false: Colors.border }}
                    thumbColor={Colors.white}
                    accessibilityLabel="Add their other accounts too"
                  />
                </View>
              ) : null}

              <View style={{ gap: 10 }}>
                <View style={styles.labelRow}>
                  <Text style={styles.label}>Priority</Text>
                  <Text style={styles.muted}>{priority} · {PRIORITY_NAMES[priority]}</Text>
                </View>
                <View style={styles.priorityRow}>
                  {[1, 2, 3, 4, 5].map((n) => (
                    <Pressable
                      key={n}
                      onPress={() => setPriority(n)}
                      style={[styles.priorityBtn, n === priority && styles.priorityBtnActive]}
                      accessibilityState={{ selected: n === priority }}
                    >
                      <Text style={[styles.priorityText, n === priority && { color: Colors.white }]}>{n}</Text>
                    </Pressable>
                  ))}
                </View>
              </View>

              <Pressable
                style={[styles.primaryBtn, styles.bigBtn, (selected.length === 0 || step === "adding") && styles.disabled]}
                disabled={selected.length === 0 || step === "adding"}
                onPress={() => void add()}
              >
                {step === "adding" ? <ActivityIndicator size="small" color={Colors.white} /> : <Plus size={18} color={Colors.white} />}
                <Text style={styles.primaryText}>{addLabel}</Text>
              </Pressable>
            </View>
          ) : null}

          {preview && step === "picker" ? (
            <View style={styles.block}>
              {newOpen ? (
                <View style={styles.newRow}>
                  <TextInput
                    autoFocus
                    value={newName}
                    onChangeText={setNewName}
                    placeholder="New collection name"
                    placeholderTextColor={Colors.textMuted}
                    returnKeyType="done"
                    onSubmitEditing={() => void createNew()}
                    style={[styles.input, { flex: 1 }]}
                    accessibilityLabel="New collection name"
                  />
                  <Pressable
                    style={[styles.primaryBtn, (!newName.trim() || creating) && styles.disabled]}
                    disabled={!newName.trim() || creating}
                    onPress={() => void createNew()}
                  >
                    {creating ? <ActivityIndicator color={Colors.white} /> : <Text style={styles.primaryText}>Create</Text>}
                  </Pressable>
                  <Pressable
                    style={styles.roundBtn}
                    onPress={() => {
                      setNewOpen(false);
                      setNewName("");
                    }}
                    accessibilityLabel="Cancel new collection"
                  >
                    <X size={18} color={Colors.textPrimary} />
                  </Pressable>
                </View>
              ) : (
                <Pressable style={styles.newBtn} onPress={() => setNewOpen(true)}>
                  <Plus size={18} color={Colors.accent} />
                  <Text style={styles.link}>New collection</Text>
                </Pressable>
              )}
              <View style={styles.list}>
                {pickerRows.map((c, i) => {
                  const locked = alreadyIds.has(c.id);
                  const checked = locked || selected.includes(c.id);
                  const note = locked ? "Already here" : c.id === UNSORTED_ID ? "Sort it later" : c.id === preview.suggestion?.agentId ? "Suggested" : "";
                  return (
                    <Pressable
                      key={c.id}
                      disabled={locked}
                      onPress={() => toggle(c.id)}
                      style={({ pressed }) => [styles.listRow, i === pickerRows.length - 1 && { borderBottomWidth: 0 }, pressed && { backgroundColor: Colors.input }]}
                      accessibilityState={{ checked, disabled: locked }}
                    >
                      <View style={[styles.checkbox, checked && (locked ? styles.checkboxLocked : styles.checkboxOn)]}>
                        {checked ? <Check size={13} color={Colors.white} strokeWidth={3} /> : null}
                      </View>
                      <Text style={[styles.body, { flex: 1 }]} numberOfLines={1}>{c.name}</Text>
                      {note ? <Text style={styles.small}>{note}</Text> : null}
                    </Pressable>
                  );
                })}
              </View>
              <Pressable
                style={[styles.primaryBtn, styles.bigBtn, selected.length === 0 && styles.disabled]}
                disabled={selected.length === 0}
                onPress={() => setStep("card")}
              >
                <Text style={styles.primaryText}>Done</Text>
              </Pressable>
            </View>
          ) : null}

          {preview && step === "done" ? (
            <View style={[styles.block, { alignItems: "center" }]}>
              <View style={styles.doneCircle}>
                <Check size={32} color={Colors.success} strokeWidth={2.6} />
              </View>
              <Text style={styles.doneTitle}>Added {plainName(preview.account.name)}</Text>
              <Text style={styles.muted}>to {joinNames(selected.map(nameOf))}</Text>
              {includeAlsoOn && preview.alsoOn.length > 0 ? (
                <Text style={styles.small}>Their {alsoNames} accounts were added too.</Text>
              ) : null}
              <View style={[styles.twoBtns, { alignSelf: "stretch", marginTop: 12 }]}>
                <Pressable style={[styles.secondaryBtn, { flex: 1 }]} onPress={() => void undo()}>
                  <Text style={styles.secondaryText}>Undo</Text>
                </Pressable>
                <Pressable style={[styles.primaryBtn, { flex: 1.4 }]} onPress={close}>
                  <Text style={styles.primaryText}>{fromShareSheet ? `Back to ${preview.platformLabel}` : "Done"}</Text>
                </Pressable>
              </View>
            </View>
          ) : null}
        </ScrollView>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  // See-through, like the iOS share card: what's behind stays visible.
  backdrop: { flex: 1, justifyContent: "flex-end", backgroundColor: "transparent" },
  sheet: {
    maxHeight: "92%",
    backgroundColor: Colors.card,
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
    borderTopWidth: 1,
    borderColor: Colors.border,
    paddingTop: 10,
    width: "100%",
    maxWidth: 560,
    alignSelf: "center",
  },
  grabber: { width: 38, height: 5, borderRadius: 999, backgroundColor: Colors.border, alignSelf: "center", marginBottom: 8 },
  sheetContent: { paddingHorizontal: 20, paddingTop: 6, gap: 18 },
  headerRow: { flexDirection: "row", alignItems: "center", gap: 10 },
  headerTitle: { flex: 1, fontSize: 17, fontWeight: "700", color: Colors.textPrimary },
  appIcon: { width: 32, height: 32, borderRadius: 8, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  roundBtn: { width: 36, height: 36, borderRadius: 18, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  block: { gap: 16 },
  accountRow: { flexDirection: "row", alignItems: "center", gap: 14 },
  avatar: { width: 54, height: 54, borderRadius: 27 },
  avatarFallback: { backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  avatarInitial: { color: Colors.textPrimary, fontSize: 20, fontWeight: "700" },
  platformDot: {
    position: "absolute",
    right: -4,
    bottom: -4,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: Colors.card,
    borderWidth: 2,
    borderColor: Colors.card,
    alignItems: "center",
    justifyContent: "center",
  },
  skeleton: { backgroundColor: Colors.input },
  accountName: { fontSize: 17, fontWeight: "700", color: Colors.textPrimary },
  body: { fontSize: 15, color: Colors.textPrimary },
  bodyStrong: { fontSize: 14, fontWeight: "600", color: Colors.textPrimary },
  muted: { fontSize: 14, color: Colors.textSecondary },
  small: { fontSize: 12, color: Colors.textSecondary },
  inline: { flexDirection: "row", alignItems: "center", gap: 8 },
  label: { fontSize: 12, fontWeight: "600", letterSpacing: 0.8, textTransform: "uppercase", color: Colors.textSecondary },
  labelRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  link: { fontSize: 14, fontWeight: "600", color: Colors.accent },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: {
    height: 38,
    paddingHorizontal: 14,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "hsla(199, 89%, 48%, 0.55)",
    backgroundColor: "hsla(199, 89%, 48%, 0.14)",
    justifyContent: "center",
  },
  chipText: { fontSize: 14, fontWeight: "600", color: "hsl(199, 89%, 72%)" },
  chipEmpty: { height: 38, paddingHorizontal: 14, borderRadius: 999, borderWidth: 1, borderStyle: "dashed", borderColor: Colors.border, justifyContent: "center" },
  alsoBox: { flexDirection: "row", alignItems: "center", gap: 12, padding: 13, borderRadius: 12, backgroundColor: Colors.input, borderWidth: 1, borderColor: Colors.border },
  priorityRow: { flexDirection: "row", gap: 8 },
  priorityBtn: { flex: 1, height: 44, borderRadius: 10, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  priorityBtnActive: { backgroundColor: Colors.accent, borderColor: Colors.accent },
  priorityText: { fontSize: 15, fontWeight: "700", color: Colors.textPrimary },
  primaryBtn: { minHeight: 48, borderRadius: 12, backgroundColor: Colors.accent, flexDirection: "row", gap: 8, alignItems: "center", justifyContent: "center", paddingHorizontal: 14 },
  bigBtn: { minHeight: 52 },
  primaryText: { color: Colors.white, fontSize: 15, fontWeight: "700" },
  secondaryBtn: { minHeight: 48, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center", paddingHorizontal: 14 },
  secondaryText: { color: Colors.textPrimary, fontSize: 15, fontWeight: "600" },
  twoBtns: { flexDirection: "row", gap: 10 },
  disabled: { opacity: 0.45 },
  newRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  newBtn: { minHeight: 48, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.input, flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 14 },
  input: { height: 48, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.input, color: Colors.textPrimary, paddingHorizontal: 14, fontSize: 15 },
  errorBox: { padding: 12, borderRadius: 12, borderWidth: 1, borderColor: Colors.destructive, backgroundColor: Colors.destructiveBg },
  successBox: { flexDirection: "row", gap: 12, padding: 14, borderRadius: 12, borderWidth: 1, borderColor: "hsla(142, 71%, 45%, 0.35)", backgroundColor: "hsla(142, 71%, 45%, 0.1)" },
  list: { borderRadius: 12, borderWidth: 1, borderColor: Colors.border, overflow: "hidden" },
  listRow: { minHeight: 52, flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 14, borderBottomWidth: 1, borderBottomColor: Colors.border, backgroundColor: Colors.card },
  checkbox: { width: 22, height: 22, borderRadius: 6, borderWidth: 1.5, borderColor: Colors.textMuted, alignItems: "center", justifyContent: "center" },
  checkboxOn: { backgroundColor: Colors.accent, borderColor: Colors.accent },
  checkboxLocked: { backgroundColor: Colors.textMuted, borderColor: Colors.textMuted },
  doneCircle: { width: 64, height: 64, borderRadius: 32, backgroundColor: "hsla(142, 71%, 45%, 0.15)", alignItems: "center", justifyContent: "center" },
  doneTitle: { fontSize: 20, fontWeight: "700", color: Colors.textPrimary, textAlign: "center" },
});
