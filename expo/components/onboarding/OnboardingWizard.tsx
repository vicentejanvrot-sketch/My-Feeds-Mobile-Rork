import { useState } from "react";
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Modal,
  Platform as RNPlatform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Check, Play, Plus, Rss, Trash2, X as XIcon } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-provider";
import { extractEdgeFunctionErrorMessage, qk } from "@/lib/hooks";
import { PlatformBadge } from "@/components/PlatformBadge";
import { ReadWatchTour } from "@/components/onboarding/ReadWatchTour";
import { Platform, PLATFORMS, PLATFORM_META, detectPlatform } from "@/lib/platforms";

// Onboarding wizard, same flow as the web OnboardingWizard: create an agent
// (its name is its topic), add its sources, then a per-platform tour of
// reading and watching in the app. Saves to the same tables and the same
// add-source edge function as the rest of the app. It opens on the Dashboard
// until the user ticks "Don't show this again", and from the Dashboard's
// floating help button any time. "See how it works" jumps to the tour only.

export interface OnboardingResult {
  agentId: string;
  agentName: string;
  runNow: boolean;
}

interface OnboardingWizardProps {
  visible: boolean;
  // result is set when the user reached the last screen, so the caller can
  // show the success message and start a run.
  onClose: (result?: OnboardingResult) => void;
  /** The user ticked "Don't show this again". */
  hidden: boolean;
  onHiddenChange: (hidden: boolean) => void;
}

interface AddedSource {
  id: string;
  platform: Platform;
  name: string;
}

const STEP_LABELS = ["Your collection", "Sources", "Read & watch"];
const LAST_STEP = 4;

function deviceTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "America/Edmonton";
  } catch {
    return "America/Edmonton";
  }
}

export function OnboardingWizard({ visible, onClose, hidden, onHiddenChange }: OnboardingWizardProps) {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const [step, setStep] = useState(0);
  const [name, setName] = useState("");
  const [emailMe, setEmailMe] = useState(true);
  const [agentId, setAgentId] = useState<string | null>(null);
  const [savedName, setSavedName] = useState("");
  const [savedEmailMe, setSavedEmailMe] = useState(true);
  const [saving, setSaving] = useState(false);
  const [finishing, setFinishing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Opened only to see the reading tour: no agent is created.
  const [tourOnly, setTourOnly] = useState(false);
  const [dontShow, setDontShow] = useState(hidden);

  const [platform, setPlatform] = useState<Platform>("youtube");
  // Set when a pasted link picked the platform for the user.
  const [autoPlatform, setAutoPlatform] = useState<Platform | null>(null);
  const [sourceValue, setSourceValue] = useState("");
  const [adding, setAdding] = useState(false);
  const [removingId, setRemovingId] = useState<string | null>(null);
  const [sources, setSources] = useState<AddedSource[]>([]);

  const trimmedName = name.trim();
  const meta = PLATFORM_META[platform];

  const goTo = (n: number) => {
    setError(null);
    setStep(n);
  };

  const recipientsFor = async (wantEmail: boolean): Promise<string[]> => {
    if (!wantEmail || !user) return [];
    const { data } = await supabase
      .from("user_settings")
      .select("default_email")
      .eq("user_id", user.id)
      .maybeSingle();
    const email = ((data?.default_email as string | null) || user.email || "").trim();
    return email ? [email] : [];
  };

  // Replace the agent's recipients, the same way the web app does.
  const saveRecipients = async (id: string, recipients: string[]) => {
    await supabase.from("agent_recipients").delete().eq("agent_id", id);
    if (recipients.length > 0) {
      const { error: insertError } = await supabase
        .from("agent_recipients")
        .insert(recipients.map((email) => ({ agent_id: id, email })));
      if (insertError) throw insertError;
    }
  };

  // Step 1: create the agent the first time, update it if they come back and change it.
  // No success message here; the user gets one when they finish.
  const saveAgent = async () => {
    if (!trimmedName || trimmedName.length > 100 || !user) return;
    setSaving(true);
    setError(null);
    try {
      if (!agentId) {
        const { data: agent, error: insertError } = await supabase
          .from("agents")
          .insert({
            name: trimmedName,
            description: null,
            schedule_frequency: "daily",
            run_time_local: "07:00",
            timezone: deviceTimezone(),
            lookback_hours: 36,
            include_shorts: false,
            include_live: false,
            ai_provider: "lovable",
            user_id: user.id,
          })
          .select()
          .single();
        if (insertError) throw insertError;
        await saveRecipients(agent.id as string, await recipientsFor(emailMe));
        setAgentId(agent.id as string);
        setSavedName(trimmedName);
        setSavedEmailMe(emailMe);
      } else if (trimmedName !== savedName || emailMe !== savedEmailMe) {
        if (trimmedName !== savedName) {
          const { error: updateError } = await supabase.from("agents").update({ name: trimmedName }).eq("id", agentId);
          if (updateError) throw updateError;
        }
        if (emailMe !== savedEmailMe) await saveRecipients(agentId, await recipientsFor(emailMe));
        setSavedName(trimmedName);
        setSavedEmailMe(emailMe);
      }
      void queryClient.invalidateQueries({ queryKey: qk.agents });
      goTo(2);
    } catch (e) {
      setError("Couldn't save the collection: " + (e instanceof Error ? e.message : "please try again."));
    } finally {
      setSaving(false);
    }
  };

  // Step 2: YouTube channels go straight into channels (run-agent resolves them
  // on the first run); every other platform is checked by add-source.
  const addSource = async () => {
    const value = sourceValue.trim();
    if (!value || !agentId) return;
    setError(null);
    const detected = detectPlatform(value);
    if (detected && detected !== platform) {
      setError(`That's a ${PLATFORM_META[detected].label} link. Select ${PLATFORM_META[detected].label} or paste a ${PLATFORM_META[platform].label} link.`);
      return;
    }
    if (platform === "youtube" && !/youtube\.com|youtu\.be|^@/i.test(value)) {
      setError("Paste the channel link, like youtube.com/@ChannelName.");
      return;
    }
    setAdding(true);
    try {
      if (platform === "youtube") {
        const { data, error: insertError } = await supabase
          .from("channels")
          .insert({ agent_id: agentId, channel_url: value, priority: 3 })
          .select()
          .single();
        if (insertError) throw insertError;
        setSources((prev) => [...prev, { id: data.id as string, platform: "youtube", name: value }]);
      } else {
        const { data, error: fnError } = await supabase.functions.invoke("add-source", {
          body: { agentId, platform, value, priority: 3 },
        });
        if (fnError) throw new Error(await extractEdgeFunctionErrorMessage(fnError));
        if (!data?.channel) throw new Error(data?.error ?? "Couldn't add that source.");
        const channel = data.channel as { id: string; channel_name: string };
        setSources((prev) => [...prev, { id: channel.id, platform, name: channel.channel_name }]);
      }
      setSourceValue("");
      setAutoPlatform(null);
      void queryClient.invalidateQueries({ queryKey: qk.channelsAll });
      void queryClient.invalidateQueries({ queryKey: qk.agents });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn't add that source.");
    } finally {
      setAdding(false);
    }
  };

  const removeSource = async (source: AddedSource) => {
    setRemovingId(source.id);
    setError(null);
    const { error: deleteError } = await supabase.from("channels").delete().eq("id", source.id);
    setRemovingId(null);
    if (deleteError) {
      setError("Couldn't remove it: " + deleteError.message);
      return;
    }
    setSources((prev) => prev.filter((s) => s.id !== source.id));
    void queryClient.invalidateQueries({ queryKey: qk.channelsAll });
  };

  // Last step: confirm the agent really is saved before calling it done.
  const finish = async () => {
    if (!agentId) return;
    setFinishing(true);
    setError(null);
    const { data, error: readError } = await supabase.from("agents").select("id, name").eq("id", agentId).maybeSingle();
    setFinishing(false);
    if (readError || !data) {
      setError("Something went wrong saving your collection. Check it on the Dashboard and try again.");
      return;
    }
    setSavedName(data.name as string);
    void queryClient.invalidateQueries({ queryKey: qk.agents });
    goTo(LAST_STEP);
  };

  const toggleDontShow = () => {
    const value = !dontShow;
    setDontShow(value);
    onHiddenChange(value);
  };

  const startTour = () => {
    setTourOnly(true);
    goTo(3);
  };

  const next = () => {
    if (tourOnly) {
      onClose();
      return;
    }
    if (step === 1) {
      void saveAgent();
      return;
    }
    if (step === LAST_STEP - 1) {
      void finish();
      return;
    }
    goTo(Math.min(LAST_STEP, step + 1));
  };
  const back = () => {
    if (tourOnly) {
      setTourOnly(false);
      goTo(0);
      return;
    }
    goTo(Math.max(0, step - 1));
  };

  const close = (runNow = false) => {
    if (step === LAST_STEP && agentId) onClose({ agentId, agentName: savedName, runNow });
    else onClose();
  };

  const nextDisabled =
    finishing ||
    (step === 1 && (!trimmedName || trimmedName.length > 100 || saving)) ||
    (step === 2 && sources.length === 0);
  const hint =
    step === 1 && !trimmedName ? "Give your collection a name." :
    step === 2 && sources.length === 0 ? "Add at least one source, or skip for now." : "";
  const showFooter = step >= 1 && step < LAST_STEP;

  const dontShowBox = (
    <Pressable
      onPress={toggleDontShow}
      accessibilityRole="checkbox"
      accessibilityState={{ checked: dontShow }}
      hitSlop={6}
      style={styles.checkRow}
    >
      <View style={[styles.checkBox, dontShow && styles.checkBoxOn]}>
        {dontShow ? <Check size={14} color={Colors.white} strokeWidth={3} /> : null}
      </View>
      <Text style={styles.checkText}>Don't show this again</Text>
    </Pressable>
  );

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="fullScreen" onRequestClose={() => close()}>
      <KeyboardAvoidingView
        style={[styles.root, { paddingTop: insets.top }]}
        behavior={RNPlatform.OS === "ios" ? "padding" : undefined}
      >
        {/* Header: progress + close */}
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            {showFooter && tourOnly ? (
              <Text style={styles.stepLabel}>HOW IT WORKS</Text>
            ) : showFooter ? (
              <View style={{ gap: 8 }}>
                <View style={styles.segments}>
                  {STEP_LABELS.map((label, i) => (
                    <View key={label} style={[styles.segment, step >= i + 1 && styles.segmentOn]} />
                  ))}
                </View>
                <Text style={styles.stepLabel}>
                  STEP {step} OF {STEP_LABELS.length} · {STEP_LABELS[step - 1].toUpperCase()}
                </Text>
              </View>
            ) : (
              <View style={styles.brand}>
                <Rss size={18} color={Colors.accent} />
                <Text style={styles.brandText}>My Feeds</Text>
              </View>
            )}
          </View>
          <Pressable onPress={() => close()} hitSlop={10} accessibilityLabel="Close" style={styles.closeBtn}>
            <XIcon size={20} color={Colors.textSecondary} />
          </Pressable>
        </View>

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={styles.body}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {step === 0 && (
            <View style={{ gap: 22, paddingTop: 12 }}>
              <Text style={styles.heroTitle}>Everything you follow, in one feed.</Text>
              <Text style={styles.lead}>
                My Feeds watches the topics you care about across YouTube, X, Reddit and more, sums up what's new, and
                lets you watch and read it all right here.
              </Text>
              <View style={styles.platformWrap}>
                {PLATFORMS.map((p) => (
                  <View key={p} style={styles.platformTag}>
                    <PlatformBadge platform={p} />
                    <Text style={styles.platformTagText}>{PLATFORM_META[p].label}</Text>
                  </View>
                ))}
              </View>
              <View style={{ gap: 10 }}>
                <Pressable style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]} onPress={() => goTo(1)}>
                  <Text style={styles.primaryText}>Get started</Text>
                </Pressable>
                <Pressable style={({ pressed }) => [styles.outlineBtn, pressed && styles.pressed]} onPress={startTour}>
                  <Text style={styles.outlineText}>See how it works</Text>
                </Pressable>
                <Pressable style={({ pressed }) => [styles.skipBtn, pressed && styles.pressed]} onPress={() => close()}>
                  <Text style={styles.skipText}>Skip for now</Text>
                </Pressable>
              </View>
              <Text style={styles.muted}>
                Get started builds a new collection in three quick steps. See how it works only shows how to read and watch.
              </Text>
              <View style={styles.checkSection}>
                {dontShowBox}
                <Text style={[styles.muted, { paddingLeft: 32 }]}>
                  You can open this again any time with the ? button on the Dashboard.
                </Text>
              </View>
            </View>
          )}

          {step === 1 && (
            <View style={{ gap: 20 }}>
              <View style={{ gap: 8 }}>
                <Text style={styles.title}>Build your first collection</Text>
                <Text style={styles.lead}>
                  A collection follows one topic and pulls the best posts from its sources into one stream. Its name is the
                  topic, so name it after what you want to follow.
                </Text>
              </View>
              <View style={{ gap: 8 }}>
                <Text style={styles.label}>Collection name and topic</Text>
                <TextInput
                  value={name}
                  onChangeText={setName}
                  placeholder="e.g. Crypto, AI, Power Apps"
                  placeholderTextColor={Colors.textMuted}
                  maxLength={100}
                  autoFocus
                  returnKeyType="next"
                  onSubmitEditing={() => { if (!nextDisabled) next(); }}
                  style={styles.input}
                  accessibilityLabel="Collection name and topic"
                />
              </View>
              <View style={styles.switchRow}>
                <View style={{ flex: 1, gap: 2 }}>
                  <Text style={styles.label}>Email me a digest after each run</Text>
                  <Text style={styles.muted}>Sent to your account email. You can change it on the collection later.</Text>
                </View>
                <Switch
                  value={emailMe}
                  onValueChange={setEmailMe}
                  trackColor={{ true: Colors.accent, false: Colors.border }}
                  thumbColor={Colors.white}
                  accessibilityLabel="Email me a digest after each run"
                />
              </View>
              {trimmedName ? (
                <View style={styles.previewCard}>
                  <View style={styles.previewAvatar}>
                    <Text style={styles.previewInitial}>{trimmedName.charAt(0).toUpperCase()}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.previewName} numberOfLines={1}>{trimmedName}</Text>
                    <Text style={styles.muted}>Runs daily at 7:00 AM · looks back 36 hours</Text>
                  </View>
                </View>
              ) : null}
            </View>
          )}

          {step === 2 && (
            <View style={{ gap: 20 }}>
              <View style={{ gap: 8 }}>
                <Text style={styles.title}>Add sources to {savedName || "your collection"}</Text>
                <Text style={styles.lead}>
                  Add the channels, accounts and communities this collection should watch. You can add more later from the
                  collection page.
                </Text>
              </View>

              <View style={{ gap: 10 }}>
                <Text style={styles.label}>Platform</Text>
                <View style={styles.platformGrid}>
                  {PLATFORMS.map((p) => {
                    const selected = platform === p;
                    return (
                      <Pressable
                        key={p}
                        onPress={() => { setPlatform(p); setAutoPlatform(null); setError(null); }}
                        accessibilityRole="button"
                        accessibilityState={{ selected }}
                        style={[styles.platformCell, selected && styles.platformCellOn]}
                      >
                        <PlatformBadge platform={p} size="md" />
                        <Text style={styles.platformCellText}>
                          {PLATFORM_META[p].label}
                          {PLATFORM_META[p].beta ? <Text style={styles.beta}>  BETA</Text> : null}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </View>

              <View style={{ gap: 8 }}>
                <Text style={styles.label}>{meta.sourceNoun}</Text>
                <View style={styles.addRow}>
                  <TextInput
                    value={sourceValue}
                    onChangeText={(value) => {
                      setSourceValue(value);
                      const detected = detectPlatform(value);
                      if (detected && detected !== platform) {
                        setPlatform(detected);
                        setAutoPlatform(detected);
                        setError(null);
                      } else if (!value.trim()) {
                        setAutoPlatform(null);
                      }
                    }}
                    placeholder={meta.addPlaceholder}
                    placeholderTextColor={Colors.textMuted}
                    autoCapitalize="none"
                    autoCorrect={false}
                    returnKeyType="done"
                    onSubmitEditing={() => void addSource()}
                    style={[styles.input, { flex: 1 }]}
                    accessibilityLabel={meta.sourceNoun}
                  />
                  <Pressable
                    onPress={() => void addSource()}
                    disabled={!sourceValue.trim() || adding}
                    accessibilityLabel="Add source"
                    style={({ pressed }) => [
                      styles.addBtn,
                      (!sourceValue.trim() || adding) && styles.disabled,
                      pressed && styles.pressed,
                    ]}
                  >
                    {adding ? <ActivityIndicator size="small" color={Colors.white} /> : <Plus size={20} color={Colors.white} />}
                  </Pressable>
                </View>
                {autoPlatform === platform ? (
                  <Text style={[styles.muted, { color: Colors.accent }]}>
                    That&apos;s a {meta.label} link, so {meta.label} is now selected.
                  </Text>
                ) : (
                  <Text style={styles.muted}>{meta.addHelp}</Text>
                )}
              </View>

              <View style={{ gap: 8 }}>
                <Text style={styles.label}>Added{sources.length > 0 ? ` (${sources.length})` : ""}</Text>
                {sources.length === 0 ? (
                  <View style={styles.emptyBox}>
                    <Text style={[styles.muted, { textAlign: "center" }]}>
                      Nothing yet. Add at least one source so the collection has something to watch.
                    </Text>
                  </View>
                ) : (
                  sources.map((s) => (
                    <View key={s.id} style={styles.sourceRow}>
                      <PlatformBadge platform={s.platform} />
                      <Text style={styles.sourceName} numberOfLines={1}>{s.name}</Text>
                      <Pressable
                        onPress={() => void removeSource(s)}
                        disabled={removingId === s.id}
                        hitSlop={8}
                        accessibilityLabel={`Remove ${s.name}`}
                        style={styles.iconBtn}
                      >
                        {removingId === s.id
                          ? <ActivityIndicator size="small" color={Colors.textSecondary} />
                          : <Trash2 size={18} color={Colors.textSecondary} />}
                      </Pressable>
                    </View>
                  ))
                )}
              </View>
            </View>
          )}

          {step === 3 && (
            <View style={{ gap: 18 }}>
              <View style={{ gap: 8 }}>
                <Text style={styles.title}>Watch and read without leaving</Text>
                <Text style={styles.lead}>Pick a platform to see how its posts work in My Feeds, then tap the numbers.</Text>
              </View>
              <ReadWatchTour defaultPlatform={sources[0]?.platform ?? "youtube"} />
            </View>
          )}

          {step === LAST_STEP && (
            <View style={{ gap: 22, paddingTop: 8 }}>
              <View style={styles.doneIcon}>
                <Check size={28} color={Colors.white} />
              </View>
              <View style={{ gap: 8 }}>
                <Text style={styles.heroTitle}>Your feed is ready</Text>
                <Text style={styles.lead}>
                  Run the collection now to fill your feed straight away, or let it run on its own every morning.
                </Text>
              </View>
              <View style={styles.recap}>
                <View style={styles.recapRow}>
                  <Text style={styles.muted}>Collection</Text>
                  <Text style={styles.recapValue} numberOfLines={1}>{savedName}</Text>
                </View>
                <View style={[styles.recapRow, styles.recapDivider]}>
                  <Text style={styles.muted}>Sources</Text>
                  <Text style={styles.recapValue}>{sources.length === 0 ? "None yet" : `${sources.length} added`}</Text>
                </View>
                <View style={[styles.recapRow, styles.recapDivider]}>
                  <Text style={styles.muted}>Email digest</Text>
                  <Text style={styles.recapValue}>{savedEmailMe ? "On" : "Off"}</Text>
                </View>
              </View>
              <View style={{ gap: 10 }}>
                <Pressable
                  onPress={() => close(true)}
                  disabled={sources.length === 0}
                  style={({ pressed }) => [styles.primaryBtn, sources.length === 0 && styles.disabled, pressed && styles.pressed]}
                >
                  <Play size={16} color={Colors.white} fill={Colors.white} />
                  <Text style={styles.primaryText}>Run it now</Text>
                </Pressable>
                <Pressable style={({ pressed }) => [styles.outlineBtn, pressed && styles.pressed]} onPress={() => close()}>
                  <Text style={styles.outlineText}>Go to my feed</Text>
                </Pressable>
              </View>
              <View style={styles.checkSection}>{dontShowBox}</View>
            </View>
          )}

          {error && !showFooter ? <Text style={styles.error}>{error}</Text> : null}
        </ScrollView>

        {showFooter && (
          <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, 12) }]}>
            {error ? <Text style={styles.error}>{error}</Text> : hint ? <Text style={styles.hint}>{hint}</Text> : null}
            {tourOnly ? dontShowBox : null}
            <View style={styles.footerRow}>
              <Pressable onPress={back} accessibilityLabel="Back" style={({ pressed }) => [styles.backBtn, pressed && styles.pressed]}>
                <ArrowLeft size={20} color={Colors.textPrimary} />
              </Pressable>
              {step === 2 && sources.length === 0 ? (
                <Pressable onPress={() => goTo(3)} style={({ pressed }) => [styles.skipBtn, pressed && styles.pressed]}>
                  <Text style={styles.skipText}>Skip for now</Text>
                </Pressable>
              ) : null}
              <Pressable
                onPress={next}
                disabled={nextDisabled}
                style={({ pressed }) => [styles.primaryBtn, { flex: 1 }, nextDisabled && styles.disabled, pressed && styles.pressed]}
              >
                {saving || finishing ? <ActivityIndicator size="small" color={Colors.white} /> : null}
                <Text style={styles.primaryText}>{tourOnly ? "Done" : step === LAST_STEP - 1 ? "Finish" : "Continue"}</Text>
              </Pressable>
            </View>
          </View>
        )}
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: "row", alignItems: "flex-start", gap: 12, paddingHorizontal: 20, paddingTop: 14, paddingBottom: 6 },
  closeBtn: { width: 36, height: 36, alignItems: "center", justifyContent: "center", marginTop: -6 },
  segments: { flexDirection: "row", gap: 6 },
  segment: { flex: 1, height: 4, borderRadius: 2, backgroundColor: Colors.input },
  segmentOn: { backgroundColor: Colors.accent },
  stepLabel: { color: Colors.textSecondary, fontSize: 12, fontWeight: "700" as const, letterSpacing: 0.6 },
  brand: { flexDirection: "row", alignItems: "center", gap: 8 },
  brandText: { color: Colors.accent, fontSize: 16, fontWeight: "700" as const },
  body: { paddingHorizontal: 20, paddingTop: 12, paddingBottom: 28 },
  heroTitle: { color: Colors.textPrimary, fontSize: 32, fontWeight: "800" as const, lineHeight: 38 },
  title: { color: Colors.textPrimary, fontSize: 26, fontWeight: "800" as const, lineHeight: 32 },
  lead: { color: Colors.textSecondary, fontSize: 16, lineHeight: 23 },
  label: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" as const },
  muted: { color: Colors.textSecondary, fontSize: 13, lineHeight: 18 },
  input: {
    height: 50,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.input,
    color: Colors.textPrimary,
    fontSize: 16,
    paddingHorizontal: 14,
  },
  switchRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 10,
    padding: 14,
  },
  previewCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 10,
    padding: 14,
    backgroundColor: Colors.card,
  },
  previewAvatar: {
    width: 44,
    height: 44,
    borderRadius: 10,
    backgroundColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  previewInitial: { color: Colors.white, fontSize: 20, fontWeight: "800" as const },
  previewName: { color: Colors.textPrimary, fontSize: 16, fontWeight: "700" as const },
  platformWrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  platformTag: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  platformTagText: { color: Colors.textPrimary, fontSize: 14 },
  platformGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  platformCell: {
    width: "31.5%",
    minHeight: 76,
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 10,
    paddingVertical: 10,
  },
  platformCellOn: { borderColor: Colors.accent, backgroundColor: "hsla(199, 89%, 48%, 0.12)" },
  platformCellText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "600" as const, textAlign: "center" },
  beta: { color: Colors.textMuted, fontSize: 9, fontWeight: "700" as const },
  addRow: { flexDirection: "row", gap: 8 },
  addBtn: {
    width: 50,
    height: 50,
    borderRadius: 10,
    backgroundColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  emptyBox: { borderWidth: 1, borderStyle: "dashed", borderColor: Colors.border, borderRadius: 10, padding: 16 },
  sourceRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 10,
    paddingLeft: 12,
    paddingRight: 4,
    minHeight: 48,
  },
  sourceName: { flex: 1, color: Colors.textPrimary, fontSize: 14 },
  iconBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  doneIcon: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  recap: { borderWidth: 1, borderColor: Colors.border, borderRadius: 12, backgroundColor: Colors.card },
  recapRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 16, padding: 14 },
  recapDivider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.border },
  recapValue: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" as const, flexShrink: 1, textAlign: "right" },
  footer: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingHorizontal: 20,
    paddingTop: 12,
    gap: 10,
    backgroundColor: Colors.background,
  },
  footerRow: { flexDirection: "row", alignItems: "center", gap: 10 },
  backBtn: {
    width: 50,
    height: 50,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    alignItems: "center",
    justifyContent: "center",
  },
  skipBtn: { height: 50, paddingHorizontal: 12, alignItems: "center", justifyContent: "center" },
  skipText: { color: Colors.textPrimary, fontSize: 15, fontWeight: "700" as const },
  primaryBtn: {
    height: 50,
    borderRadius: 10,
    backgroundColor: Colors.accent,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingHorizontal: 20,
  },
  primaryText: { color: Colors.white, fontSize: 16, fontWeight: "700" as const },
  outlineBtn: {
    height: 50,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    alignItems: "center",
    justifyContent: "center",
  },
  outlineText: { color: Colors.textPrimary, fontSize: 16, fontWeight: "700" as const },
  checkSection: {
    gap: 6,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingTop: 16,
  },
  checkRow: { flexDirection: "row", alignItems: "center", gap: 10, minHeight: 44 },
  checkBox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 1.5,
    borderColor: Colors.textSecondary,
    alignItems: "center",
    justifyContent: "center",
  },
  checkBoxOn: { backgroundColor: Colors.accent, borderColor: Colors.accent },
  checkText: { color: Colors.textPrimary, fontSize: 15 },
  hint: { color: Colors.textSecondary, fontSize: 13, textAlign: "center" },
  error: { color: Colors.destructive, fontSize: 13, textAlign: "center", marginTop: 8 },
  disabled: { opacity: 0.45 },
  pressed: { opacity: 0.8, transform: [{ scale: 0.98 }] },
});
