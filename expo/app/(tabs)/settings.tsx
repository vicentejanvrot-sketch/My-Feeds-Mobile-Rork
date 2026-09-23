import { useCallback, useEffect, useRef, useState } from "react";
import { useFocusEffect } from "expo-router";
import {
  ActivityIndicator,
  Alert,
  Animated,
  KeyboardAvoidingView,
  Linking,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { router } from "expo-router";
import { LinearGradient } from "expo-linear-gradient";
import * as Haptics from "expo-haptics";
import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  Mail,
  Monitor,
  Save,
  ChevronDown,
  LogOut,
  User,
  ChevronRight,
  CircleHelp,
  FileText,
  ShieldCheck,
  MessageSquare,
  Trash2,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { useAuth } from "@/lib/auth-provider";
import { useUserSettings, useUpdateSettings, useUserSettingsSafe, useDeleteAccount } from "@/lib/hooks";
import { useToast } from "@/components/Toast";
import { useVideoQuality, QUALITY_KEYS, QUALITY_LABELS } from "@/lib/useVideoQuality";
// ── Constants ─────────────────────────────────────────────────────

/** Minimal email format check — matches the web app's validator. */
function isValidEmail(v: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
}

// ── Component ─────────────────────────────────────────────────────

const IPAD_BREAKPOINT = 768;

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { width: windowWidth } = useWindowDimensions();
  const isWide = windowWidth >= IPAD_BREAKPOINT;
  const { user, signOut } = useAuth();
  const showToast = useToast();

  const settings = useUserSettings();
  const safeSettings = useUserSettingsSafe();
  const updateSettings = useUpdateSettings();

  // ── Form state ────────────────────────────────────────────────

  const scrollRef = useRef<ScrollView>(null);
  const [defaultEmail, setDefaultEmail] = useState("");

  useFocusEffect(
    useCallback(() => {
      scrollRef.current?.scrollTo({ y: 0, animated: false });
    }, []),
  );

  const deleteAccount = useDeleteAccount();

  // Shared video quality pref (synced with in-player gear menu)
  const { quality: videoQuality, setQuality: persistQuality, ready: qualityReady } = useVideoQuality();

  // Local device settings (not in Supabase)
  const [qualityOpen, setQualityOpen] = useState(false);
  const [keepScreenOn, setKeepScreenOn] = useState(false);
  const [accordionOpen, setAccordionOpen] = useState(false);
  const accordionAnim = useRef(new Animated.Value(0)).current;

  // ── Load Supabase settings (email + metadata only) ─

  useEffect(() => {
    if (settings.data) {
      setDefaultEmail(settings.data.default_email ?? "");
    }
    // Keys are intentionally NEVER pre-filled — the DB revokes SELECT
    // on the key columns, and the hook doesn't request them.
  }, [settings.data]);

  // ── Load local device settings ─────────────────────────────────

  useEffect(() => {
    AsyncStorage.getItem("@settings/keep_screen_on").then((v) => {
      setKeepScreenOn(v === "true");
    });
  }, []);

  // ── Accordion animation ────────────────────────────────────────

  const toggleAccordion = useCallback(() => {
    const next = !accordionOpen;
    setAccordionOpen(next);
    Animated.timing(accordionAnim, {
      toValue: next ? 1 : 0,
      duration: 220,
      useNativeDriver: false,
    }).start();
  }, [accordionOpen, accordionAnim]);

  const accordionHeight = accordionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 140],
  });
  const chevronRotate = accordionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", "180deg"],
  });

  // ── Keep-screen-on toggle ──────────────────────────────────────

  const handleKeepScreenOn = useCallback(
    async (val: boolean) => {
      setKeepScreenOn(val);
      // Only save the preference. The video player reads it and keeps the
      // screen awake while a video is open (turning it on here kept the whole
      // app awake until restart, and was lost after a restart).
      await AsyncStorage.setItem("@settings/keep_screen_on", String(val));
    },
    [],
  );

  // ── Quality picker ─────────────────────────────────────────────

  const handleQualitySelect = useCallback(
    async (q: string) => {
      setQualityOpen(false);
      await persistQuality(q as (typeof QUALITY_KEYS)[number]);
    },
    [persistQuality],
  );

  // ── Save handler ───────────────────────────────────────────────

  const handleSave = useCallback(async () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    // Validate email
    const email = defaultEmail.trim();
    if (email && !isValidEmail(email)) {
      showToast("Please enter a valid email address.", "error");
      return;
    }

    const payload: Record<string, string | null> = {
      default_email: email || null,
    };

    try {
      await updateSettings.mutateAsync(payload as any);
      showToast("Settings saved.", "success");
    } catch (err: any) {
      showToast(
        err?.message ?? "Failed to save settings. Please try again.",
        "error",
      );
    }
  }, [defaultEmail, updateSettings, showToast]);

  // ── Render ─────────────────────────────────────────────────────

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView
        ref={scrollRef}
        contentContainerStyle={[styles.content, isWide && styles.contentWide, { paddingTop: insets.top + 16 }]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.heading}>Settings</Text>

        {/* ── Profile card ──────────────────────────────── */}
        <View style={styles.profileCard}>
          <View style={styles.avatar}>
            <User size={22} color={Colors.accent} />
          </View>
          <View style={styles.profileInfo}>
            <Text style={styles.profileLabel}>Signed in as</Text>
            <Text style={styles.profileEmail} numberOfLines={1}>
              {user?.email ?? "—"}
            </Text>
          </View>
        </View>


        {settings.isLoading ? (
          <View style={styles.loadingBox}>
            <ActivityIndicator color={Colors.accent} />
          </View>
        ) : (
          <>
            {/* ═══ Card 1: Default Email ═══ */}
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Mail size={18} color={Colors.accent} />
                <Text style={styles.cardTitle}>Default Email</Text>
              </View>
              <Text style={styles.cardDesc}>
                Pre-filled when adding email recipients to new agents.
              </Text>
              <TextInput
                style={styles.input}
                value={defaultEmail}
                onChangeText={setDefaultEmail}
                placeholder="your@email.com"
                placeholderTextColor={Colors.textMuted}
                autoCapitalize="none"
                keyboardType="email-address"
                autoCorrect={false}
              />
            </View>

            {/* ═══ Card 2: Video Playback ═══ */}
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Monitor size={18} color={Colors.accent} />
                <Text style={styles.cardTitle}>Video Playback</Text>
              </View>
              <Text style={styles.cardDesc}>
                Configure default video playback settings.
              </Text>

              {/* Quality dropdown */}
              <Text style={styles.fieldLabel}>Default Video Quality</Text>
              <Pressable
                style={styles.dropdown}
                onPress={() => setQualityOpen((o) => !o)}
              >
                <Text style={styles.dropdownText}>{QUALITY_LABELS[videoQuality] ?? videoQuality}</Text>
                <ChevronDown
                  size={16}
                  color={Colors.textSecondary}
                  style={{
                    transform: [{ rotate: qualityOpen ? "180deg" : "0deg" }],
                  }}
                />
              </Pressable>
              {!qualityReady ? (
                <View style={styles.loadingQuality}>
                  <ActivityIndicator size="small" color={Colors.accent} />
                </View>
              ) : null}
              {qualityOpen && (
                <View style={styles.dropdownMenu}>
                  {QUALITY_KEYS.map((q) => (
                    <Pressable
                      key={q}
                      style={[
                        styles.dropdownItem,
                        q === videoQuality && styles.dropdownItemActive,
                      ]}
                      onPress={() => handleQualitySelect(q)}
                    >
                      <Text
                        style={[
                          styles.dropdownItemText,
                          q === videoQuality && styles.dropdownItemTextActive,
                        ]}
                      >
                        {QUALITY_LABELS[q]}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              )}
              <Text style={styles.helperText}>
                Videos will start playing at this quality when available. This setting is saved locally.
              </Text>

              {/* Keep screen on */}
              <View style={styles.switchRow}>
                <View style={styles.switchLabel}>
                  <Text style={styles.fieldLabel}>Keep screen on while playing</Text>
                  <Text style={styles.helperText}>
                    Prevents your device from auto-locking during video playback.
                  </Text>
                </View>
                <Switch
                  value={keepScreenOn}
                  onValueChange={handleKeepScreenOn}
                  trackColor={{
                    false: Colors.input,
                    true: Colors.accent,
                  }}
                  thumbColor={keepScreenOn ? Colors.white : Colors.textSecondary}
                />
              </View>
            </View>

            {/* ═══ Card 3: About background playback (accordion) ═══ */}
            <Pressable style={styles.card} onPress={toggleAccordion}>
              <View style={styles.accordionHeader}>
                <Text style={styles.accordionTitle}>About background playback</Text>
                <Animated.View
                  style={{ transform: [{ rotate: chevronRotate }] }}
                >
                  <ChevronDown size={18} color={Colors.textSecondary} />
                </Animated.View>
              </View>
              <Animated.View
                style={[styles.accordionBody, { maxHeight: accordionHeight }]}
              >
                <Text style={styles.accordionText}>
                  Embedded YouTube videos automatically pause when your screen locks
                  or the app moves to the background. This is expected behavior on iOS —
                  both the operating system and the official YouTube embedded player
                  enforce this to preserve battery and comply with platform policies.
                  It is not a bug in the app.
                </Text>
              </Animated.View>
            </Pressable>

            {/* ═══ Card 4: Danger Zone ═══ */}
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Trash2 size={18} color={Colors.destructive} />
                <Text style={[styles.cardTitle, { color: Colors.destructive }]}>
                  Danger Zone
                </Text>
              </View>
              <Text style={styles.cardDesc}>
                Permanently delete your account and all associated data. This action cannot be undone.
              </Text>
              <Pressable
                style={({ pressed }) => [
                  styles.deleteAccountBtn,
                  pressed && { opacity: 0.85, transform: [{ scale: 0.99 }] },
                  deleteAccount.isPending && styles.disabled,
                ]}
                onPress={() => {
                  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
                  Alert.alert(
                    "Delete Account?",
                    "This will permanently delete your account and all your data, including your agents, feeds, watch history, and saved settings. This cannot be undone.",
                    [
                      { text: "Cancel", style: "cancel" },
                      {
                        text: "Delete",
                        style: "destructive",
                        onPress: async () => {
                          try {
                            const result = await deleteAccount.mutateAsync();

                            if (result.method === "edge_function") {
                              showToast("Your account has been deleted.", "success");
                              await signOut();
                            } else {
                              // Client-fallback cleanup succeeded
                              showToast("Your account data has been deleted.", "success");
                              await signOut();
                              try {
                                await Linking.openURL(
                                  "mailto:support@travelone.ca?subject=Account%20Deletion%20Request&body=Please%20permanently%20delete%20my%20account%20login.%20My%20data%20has%20already%20been%20removed%20from%20within%20the%20app.",
                                );
                              } catch {
                                // mailto may not be supported
                              }
                            }
                          } catch {
                            showToast(
                              "Failed to delete account. Please try again or contact support@travelone.ca.",
                              "error",
                            );
                          }
                        },
                      },
                    ],
                  );
                }}
                disabled={deleteAccount.isPending}
              >
                {deleteAccount.isPending ? (
                  <ActivityIndicator size="small" color={Colors.destructive} />
                ) : (
                  <>
                    <Trash2 size={16} color={Colors.destructive} />
                    <Text style={styles.deleteAccountText}>Delete Account</Text>
                  </>
                )}
              </Pressable>
            </View>

            {/* ═══ Card 5: Support ═══ */}
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <CircleHelp size={18} color={Colors.accent} />
                <Text style={styles.cardTitle}>Support</Text>
              </View>

              <Pressable
                style={({ pressed }) => [
                  styles.supportRow,
                  pressed && styles.pressed,
                ]}
                onPress={() => router.push("/support/faq")}
              >
                <View style={styles.supportRowLeft}>
                  <CircleHelp size={18} color={Colors.textSecondary} />
                  <Text style={styles.supportRowLabel}>FAQ</Text>
                </View>
                <ChevronRight size={18} color={Colors.textMuted} />
              </Pressable>

              <View style={styles.supportDivider} />

              <Pressable
                style={({ pressed }) => [
                  styles.supportRow,
                  pressed && styles.pressed,
                ]}
                onPress={() => router.push("/support/privacy")}
              >
                <View style={styles.supportRowLeft}>
                  <ShieldCheck size={18} color={Colors.textSecondary} />
                  <Text style={styles.supportRowLabel}>Privacy Policy</Text>
                </View>
                <ChevronRight size={18} color={Colors.textMuted} />
              </Pressable>

              <View style={styles.supportDivider} />

              <Pressable
                style={({ pressed }) => [
                  styles.supportRow,
                  pressed && styles.pressed,
                ]}
                onPress={() => router.push("/support/terms")}
              >
                <View style={styles.supportRowLeft}>
                  <FileText size={18} color={Colors.textSecondary} />
                  <Text style={styles.supportRowLabel}>Terms of Service</Text>
                </View>
                <ChevronRight size={18} color={Colors.textMuted} />
              </Pressable>

              <View style={styles.supportDivider} />

              <Pressable
                style={({ pressed }) => [
                  styles.supportRow,
                  pressed && styles.pressed,
                ]}
                onPress={() => Linking.openURL("mailto:support@travelone.ca")}
              >
                <View style={styles.supportRowLeft}>
                  <MessageSquare size={18} color={Colors.textSecondary} />
                  <Text style={styles.supportRowLabel}>Contact Support</Text>
                </View>
                <ChevronRight size={18} color={Colors.textMuted} />
              </Pressable>
            </View>

            {/* ═══ Save button ═══ */}
            <Pressable
              style={({ pressed }) => [
                styles.saveBtn,
                pressed && styles.pressed,
                updateSettings.isPending && styles.disabled,
              ]}
              onPress={handleSave}
              disabled={updateSettings.isPending}
            >
              <LinearGradient
                colors={Colors.accentGradient as unknown as readonly [string, string, ...string[]]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={StyleSheet.absoluteFill}
              />
              {updateSettings.isPending ? (
                <ActivityIndicator size="small" color={Colors.white} />
              ) : (
                <View style={styles.saveInner}>
                  <Save size={17} color={Colors.white} />
                  <Text style={styles.saveText}>Save</Text>
                </View>
              )}
            </Pressable>
          </>
        )}

        {/* ── Sign out ───────────────────────────────── */}
        <Pressable
          style={({ pressed }) => [styles.signOutBtn, pressed && styles.pressed]}
          onPress={() => {
            void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
            void signOut();
          }}
        >
          <LogOut size={16} color={Colors.destructive} />
          <Text style={styles.signOutText}>Sign out</Text>
        </Pressable>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

// ── Styles ────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background },
  content: { paddingHorizontal: 16, paddingBottom: 40 },
  contentWide: { maxWidth: 720, alignSelf: "center", width: "100%" },
  heading: {
    fontSize: 26,
    fontWeight: "800" as const,
    color: Colors.textPrimary,
    marginBottom: 20,
  },

  // Profile
  profileCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    marginBottom: 20,
  },
  avatar: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: "hsl(199, 40%, 14%)",
    alignItems: "center",
    justifyContent: "center",
  },
  profileInfo: { flex: 1 },
  profileLabel: {
    fontSize: 11,
    color: Colors.textSecondary,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  profileEmail: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: Colors.textPrimary,
    marginTop: 2,
  },
  loadingBox: { paddingVertical: 50, alignItems: "center" },

  // Cards
  card: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 18,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    marginBottom: 14,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    marginBottom: 8,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: Colors.textPrimary,
  },
  cardDesc: {
    fontSize: 12,
    color: Colors.textMuted,
    lineHeight: 17,
    marginBottom: 16,
  },

  // Fields
  fieldLabel: {
    fontSize: 13,
    fontWeight: "600" as const,
    color: Colors.textSecondary,
    marginBottom: 7,
  },
  input: {
    backgroundColor: Colors.input,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    color: Colors.textPrimary,
  },
  helperText: {
    fontSize: 11,
    color: Colors.textMuted,
    lineHeight: 15,
  },

  // Dropdown (quality picker)
  dropdown: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: Colors.input,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 8,
  },
  dropdownText: {
    fontSize: 15,
    color: Colors.textPrimary,
    fontWeight: "500" as const,
  },
  dropdownMenu: {
    backgroundColor: Colors.input,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.border,
    marginBottom: 10,
    overflow: "hidden",
  },
  dropdownItem: {
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  dropdownItemActive: {
    backgroundColor: "hsla(199, 89%, 48%, 0.15)",
  },
  dropdownItemText: {
    fontSize: 15,
    color: Colors.textPrimary,
  },
  dropdownItemTextActive: {
    color: Colors.white,
    fontWeight: "600" as const,
  },
  loadingQuality: {
    paddingVertical: 8,
    alignItems: "center",
  },

  // Switch row
  switchRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 12,
    marginTop: 14,
  },
  switchLabel: {
    flex: 1,
  },

  // Accordion
  accordionHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  accordionTitle: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: Colors.textPrimary,
  },
  accordionBody: {
    overflow: "hidden",
  },
  accordionText: {
    fontSize: 13,
    color: Colors.textSecondary,
    lineHeight: 19,
    paddingTop: 12,
  },

  // Save
  saveBtn: {
    height: 48,
    borderRadius: 10,
    overflow: "hidden",
    alignItems: "center",
    justifyContent: "center",
    marginTop: 6,
  },
  saveInner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  saveText: {
    color: Colors.white,
    fontSize: 16,
    fontWeight: "700" as const,
  },
  pressed: { opacity: 0.85, transform: [{ scale: 0.99 }] },
  disabled: { opacity: 0.7 },

  // Sign out

  // Support card
  supportRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 14,
  },
  supportRowLeft: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  supportRowLabel: {
    fontSize: 15,
    fontWeight: "600" as const,
    color: Colors.textPrimary,
  },
  supportDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
  },

  // Danger Zone
  deleteAccountBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    height: 44,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.destructive,
  },
  deleteAccountText: {
    color: Colors.destructive,
    fontSize: 15,
    fontWeight: "700" as const,
  },

  signOutBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    height: 48,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.destructive,
    marginTop: 28,
  },
  signOutText: {
    color: Colors.destructive,
    fontSize: 15,
    fontWeight: "700" as const,
  },
});
