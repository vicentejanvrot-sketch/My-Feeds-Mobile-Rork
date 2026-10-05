import { router } from "expo-router";
import { useState, type ReactNode } from "react";
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
  type DimensionValue,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import * as Haptics from "expo-haptics";
import Svg, { Circle, Path } from "react-native-svg";
import { Colors } from "@/constants/colors";
import { useAuth } from "@/lib/auth-provider";

const IPAD_BREAKPOINT = 768;
const BG = "#050B1A";
const CARD_OPACITY_PHONE = 0.38;
const CARD_OPACITY_WIDE = 0.3;

// ---------------------------------------------------------------------------
// Faded platform-style cards. On phones they sit in a band above and a band
// below the sign-in column; on iPad in a rail on each side. Bands and rails
// clip them, so they never cover the logo, the app name or the sign-in box.
// ---------------------------------------------------------------------------

const CHAT = "M21 12a8 8 0 0 1-11.6 7.1L4 20l1.1-4.4A8 8 0 1 1 21 12z";
const HEART = "M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z";
const CONTRIB = [
  0, 2, 0, 1, 3, 0, 1, 4, 0, 2, 1, 0, 3, 2,
  1, 0, 3, 2, 0, 4, 1, 0, 2, 3, 0, 1, 0, 4,
  2, 3, 0, 1, 4, 2, 0, 3, 1, 0, 2, 4, 1, 0,
  0, 1, 2, 0, 3, 0, 4, 2, 0, 1, 3, 0, 2, 1,
  3, 0, 1, 4, 0, 2, 1, 3, 0, 2, 0, 4, 1, 0,
];
const GREENS = ["#10261F", "#0E4429", "#006D32", "#26A641", "#39D353"];

function Icon({ d, size = 18, color = "#8EA0C2", fill, children }: { d?: string; size?: number; color?: string; fill?: string; children?: ReactNode }) {
  return (
    <Svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={fill ?? "none"}
      stroke={fill ? "none" : color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {d ? <Path d={d} /> : null}
      {children}
    </Svg>
  );
}

function Bar({ w, h = 8, c = "#34508A" }: { w: DimensionValue; h?: number; c?: string }) {
  return <View style={{ width: w, height: h, borderRadius: h / 2, backgroundColor: c }} />;
}

function Avatar({ size = 36, c = "#22396A" }: { size?: number; c?: string }) {
  return <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: c }} />;
}

function VideoCard() {
  return (
    <View style={[cs.card, { width: 300, padding: 12, gap: 12 }]}>
      <View style={cs.thumb}>
        <View style={cs.playSoft}>
          <Icon d="M8 5v14l11-7z" fill="#E8EEF9" size={22} />
        </View>
        <View style={cs.duration}><Text style={cs.durationText}>12:48</Text></View>
        <View style={cs.progressTrack}><View style={cs.progressFill} /></View>
      </View>
      <View style={[cs.row, { alignItems: "flex-start" }]}>
        <Avatar size={34} />
        <View style={cs.col}>
          <Bar w="92%" />
          <Bar w="70%" />
          <Bar w="48%" h={7} c="#22396A" />
        </View>
      </View>
    </View>
  );
}

function RedditCard() {
  return (
    <View style={[cs.card, { width: 230, flexDirection: "row", paddingLeft: 8 }]}>
      <View style={cs.votes}>
        <Icon d="M12 4l7 8h-4v8H9v-8H5z" color="#FF6A33" />
        <Text style={cs.votesText}>2.4k</Text>
        <Icon d="M12 20l7-8h-4V4H9v8H5z" color="#5B7BB0" />
      </View>
      <View style={[cs.col, { gap: 8 }]}>
        <View style={[cs.row, { gap: 6 }]}>
          <View style={{ width: 16, height: 16, borderRadius: 8, backgroundColor: "#FF6A33" }} />
          <Bar w={60} h={7} c="#22396A" />
        </View>
        <Bar w="100%" h={10} c="#3A5794" />
        <Bar w="75%" h={10} c="#3A5794" />
        <Bar w="95%" h={7} c="#22396A" />
        <Bar w="80%" h={7} c="#22396A" />
        <View style={[cs.row, { gap: 6 }]}>
          <Icon d={CHAT} size={14} />
          <Bar w={40} h={7} c="#22396A" />
        </View>
      </View>
    </View>
  );
}

function XCard() {
  return (
    <View style={[cs.card, { width: 280, backgroundColor: "#0A101E", borderColor: "#22314F" }]}>
      <View style={cs.row}>
        <Avatar c="#2A3A5A" />
        <View style={[cs.col, { gap: 6 }]}>
          <Bar w="45%" c="#4A5D82" />
          <Bar w="32%" h={7} c="#2A3A5A" />
        </View>
      </View>
      <Bar w="100%" c="#33466B" />
      <Bar w="94%" c="#33466B" />
      <Bar w="58%" c="#33466B" />
      <View style={[cs.row, { justifyContent: "space-between", paddingRight: 30 }]}>
        <Icon d={CHAT} color="#6B7FA6" />
        <Icon d="M7 4 4 7l3 3M4 7h11a4 4 0 0 1 4 4v1M17 20l3-3-3-3M20 17H9a4 4 0 0 1-4-4v-1" color="#6B7FA6" />
        <Icon d={HEART} color="#6B7FA6" />
        <Icon d="M5 20v-8M10 20V6M15 20v-9M20 20V4" color="#6B7FA6" />
      </View>
    </View>
  );
}

function SpotifyCard() {
  return (
    <View style={[cs.card, { width: 300, gap: 12 }]}>
      <View style={[cs.row, { gap: 12 }]}>
        <LinearGradient colors={["#1F3B70", "#3A2A5E"]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ width: 52, height: 52, borderRadius: 6 }} />
        <View style={cs.col}>
          <Bar w="70%" h={10} c="#3A5794" />
          <Bar w="45%" h={7} c="#22396A" />
        </View>
        <Icon d={HEART} fill="#1ED760" />
      </View>
      <View style={[cs.row, { gap: 8 }]}>
        <Text style={cs.tiny}>1:24</Text>
        <View style={{ flex: 1, height: 4, borderRadius: 2, backgroundColor: "#22396A" }}>
          <View style={{ width: "38%", height: 4, borderRadius: 2, backgroundColor: "#1ED760" }} />
        </View>
        <Text style={cs.tiny}>3:51</Text>
      </View>
      <View style={[cs.row, { justifyContent: "center", gap: 22 }]}>
        <Icon d="M3 7h3l9 10h6M3 17h3l3-3.3M15 7h6M18 4l3 3-3 3M18 14l3 3-3 3" size={16} color="#6B7FA6" />
        <Icon d="M19 5 9 12l10 7zM5 5h2v14H5z" fill="#C9D6EE" />
        <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: "#1ED760", alignItems: "center", justifyContent: "center" }}>
          <Icon d="M8 5v14l11-7z" fill="#06120B" />
        </View>
        <Icon d="M5 5l10 7-10 7zM17 5h2v14h-2z" fill="#C9D6EE" />
        <Icon d="M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4" size={16} color="#6B7FA6" />
      </View>
    </View>
  );
}

function GithubCard() {
  const rows = [0, 1, 2, 3, 4];
  return (
    <View style={[cs.card, { width: 236, backgroundColor: "#0B1424", borderColor: "#23324D" }]}>
      <View style={[cs.row, { gap: 8 }]}>
        <Icon d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h11" size={16} />
        <Bar w={50} c="#3A5794" />
        <Text style={{ fontSize: 12, color: "#5B7BB0" }}>/</Text>
        <Bar w={70} c="#4A6BA8" />
      </View>
      <Bar w="95%" h={7} c="#22396A" />
      <Bar w="70%" h={7} c="#22396A" />
      <View style={{ gap: 3 }}>
        {rows.map((r) => (
          <View key={r} style={{ flexDirection: "row", gap: 3 }}>
            {CONTRIB.slice(r * 14, r * 14 + 14).map((lv, i) => (
              <View key={i} style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: GREENS[lv] }} />
            ))}
          </View>
        ))}
      </View>
      <View style={[cs.row, { gap: 14 }]}>
        <View style={[cs.row, { gap: 5 }]}>
          <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: "#3178C6" }} />
          <Text style={cs.meta}>TS</Text>
        </View>
        <View style={[cs.row, { gap: 4 }]}>
          <Icon d="M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z" size={13} />
          <Text style={cs.meta}>1.2k</Text>
        </View>
        <View style={[cs.row, { gap: 4 }]}>
          <Icon size={13}>
            <Circle cx={6} cy={5} r={2} />
            <Circle cx={18} cy={5} r={2} />
            <Circle cx={12} cy={19} r={2} />
            <Path d="M6 7v2a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3V7M12 12v5" />
          </Icon>
          <Text style={cs.meta}>86</Text>
        </View>
      </View>
    </View>
  );
}

function InstagramCard() {
  return (
    <View style={[cs.card, { width: 260, padding: 12 }]}>
      <View style={cs.row}>
        <LinearGradient colors={["#F9A13B", "#E1306C", "#8A3AB9"]} start={{ x: 0, y: 1 }} end={{ x: 1, y: 0 }} style={{ width: 34, height: 34, borderRadius: 17, padding: 2 }}>
          <View style={{ flex: 1, borderRadius: 15, backgroundColor: "#22396A", borderWidth: 2, borderColor: "#0D1B38" }} />
        </LinearGradient>
        <Bar w="40%" c="#3A5794" />
      </View>
      <LinearGradient colors={["#1B3A6B", "#2B2350"]} start={{ x: 0, y: 0 }} end={{ x: 0.6, y: 1 }} style={{ width: "100%", aspectRatio: 1, borderRadius: 10 }} />
      <View style={[cs.row, { gap: 14 }]}>
        <Icon d={HEART} size={20} color="#E1306C" />
        <Icon d={CHAT} size={20} />
        <Icon d="M21 3 10 14M21 3l-7 18-4-7-7-4z" size={20} />
        <View style={{ marginLeft: "auto" }}><Icon d="M6 3h12v18l-6-4-6 4z" size={20} /></View>
      </View>
      <Bar w="35%" />
    </View>
  );
}

function FacebookCard() {
  return (
    <View style={[cs.card, { width: 290 }]}>
      <View style={cs.row}>
        <Avatar />
        <View style={[cs.col, { gap: 6 }]}>
          <Bar w="50%" c="#3A5794" />
          <Bar w="25%" h={7} c="#22396A" />
        </View>
      </View>
      <Bar w="90%" c="#2A4272" />
      <View style={{ height: 120, borderRadius: 8, backgroundColor: "#16294F" }} />
      <View style={[cs.row, { gap: 6 }]}>
        <View style={{ flexDirection: "row" }}>
          <View style={[cs.react, { backgroundColor: "#1877F2" }]}>
            <Icon d="M2 10h4v11H2zM8 10l4-8c1.7 0 3 1.3 3 3l-1 5h6c1.1 0 2 .9 2 2l-2 8c-.2.6-.8 1-1.5 1H8z" size={10} fill="#FFFFFF" />
          </View>
          <View style={[cs.react, { backgroundColor: "#F33E58", marginLeft: -5 }]}>
            <Icon d="M12 21s-8-5-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 6-8 11-8 11z" size={10} fill="#FFFFFF" />
          </View>
        </View>
        <Bar w={40} h={7} c="#22396A" />
      </View>
      <View style={{ height: 1, backgroundColor: "#22396A" }} />
      <View style={[cs.row, { justifyContent: "space-around" }]}>
        <Icon d="M7 10v10H4V10zM7 10l4-7a2 2 0 0 1 3 2l-1 5h6a2 2 0 0 1 2 2l-2 7a2 2 0 0 1-2 1H7" size={17} />
        <Icon d={CHAT} size={17} />
        <Icon d="M14 5l7 7-7 7M21 12H9a6 6 0 0 0-6 6" size={17} />
      </View>
    </View>
  );
}

function AppleMusicCard() {
  const covers: [string, string][] = [
    ["#FA2D48", "#7A1E3A"],
    ["#2B4C9B", "#162A55"],
    ["#8A3AB9", "#3B1E5E"],
    ["#F27A54", "#7A2E2E"],
  ];
  return (
    <View style={[cs.card, { width: 220, padding: 12 }]}>
      <View style={[cs.row, { gap: 8 }]}>
        <Icon size={14} fill="#FA2D48">
          <Path d="M9 18V6l11-2v12" />
          <Circle cx={6} cy={18} r={3} />
          <Circle cx={17} cy={16} r={3} />
        </Icon>
        <Bar w="45%" c="#3A5794" />
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
        {covers.map((c, i) => (
          <LinearGradient key={i} colors={c} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ width: 94, height: 94, borderRadius: 8 }} />
        ))}
      </View>
      <Bar w="60%" h={7} c="#22396A" />
    </View>
  );
}

type Spot = { x: number; y: number; r: number };

function Placed({ spot, scale, opacity, children }: { spot: Spot; scale: number; opacity: number; children: ReactNode }) {
  return (
    <View
      pointerEvents="none"
      style={{
        position: "absolute",
        left: (spot.x + "%") as DimensionValue,
        top: (spot.y + "%") as DimensionValue,
        opacity,
        transformOrigin: "top left",
        transform: [{ rotate: spot.r + "deg" }, { scale }],
      }}
    >
      {children}
    </View>
  );
}

// Positions, in percent of the band or rail the card sits in.
const PHONE_TOP: Spot[] = [
  { x: -6, y: -55, r: -5 },
  { x: 30, y: -30, r: 4 },
  { x: 62, y: -22, r: -4 },
  { x: 82, y: -8, r: 6 },
];
const PHONE_BOTTOM: Spot[] = [
  { x: -6, y: 22, r: 5 },
  { x: 26, y: 14, r: -6 },
  { x: 56, y: 26, r: 4 },
  { x: 82, y: 16, r: -5 },
];
const WIDE_LEFT: Spot[] = [
  { x: -6, y: 5, r: -8 },
  { x: 55, y: 26, r: 5 },
  { x: 6, y: 46, r: 6 },
  { x: 26, y: 74, r: -4 },
];
const WIDE_RIGHT: Spot[] = [
  { x: 10, y: 9, r: -6 },
  { x: 56, y: 3, r: 7 },
  { x: 42, y: 50, r: -5 },
  { x: 8, y: 70, r: 4 },
];

// Left / top: YouTube, X, Reddit, Spotify. Right / bottom: GitHub, Instagram, Facebook, Apple Music.
function FirstSet({ spots, scale, opacity }: { spots: Spot[]; scale: number; opacity: number }) {
  return (
    <>
      <Placed spot={spots[0]} scale={scale} opacity={opacity}><VideoCard /></Placed>
      <Placed spot={spots[1]} scale={scale} opacity={opacity}><XCard /></Placed>
      <Placed spot={spots[2]} scale={scale} opacity={opacity}><RedditCard /></Placed>
      <Placed spot={spots[3]} scale={scale} opacity={opacity}><SpotifyCard /></Placed>
    </>
  );
}

function SecondSet({ spots, scale, opacity }: { spots: Spot[]; scale: number; opacity: number }) {
  return (
    <>
      <Placed spot={spots[0]} scale={scale} opacity={opacity}><GithubCard /></Placed>
      <Placed spot={spots[1]} scale={scale} opacity={opacity}><InstagramCard /></Placed>
      <Placed spot={spots[2]} scale={scale} opacity={opacity}><FacebookCard /></Placed>
      <Placed spot={spots[3]} scale={scale} opacity={opacity}><AppleMusicCard /></Placed>
    </>
  );
}

const FADE = "rgba(5,11,26,0)";

// ---------------------------------------------------------------------------

export default function LoginScreen() {
  const insets = useSafeAreaInsets();
  const { width: windowWidth, height: windowHeight } = useWindowDimensions();
  const isWide = windowWidth >= IPAD_BREAKPOINT;
  const { signIn } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // Focus states for sky-blue border
  const [emailFocused, setEmailFocused] = useState(false);
  const [passwordFocused, setPasswordFocused] = useState(false);

  // Toast
  const [toast, setToast] = useState<{ message: string; type: "error" | "success" } | null>(null);

  const showToast = (message: string, type: "error" | "success") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleSignIn = async () => {
    if (!email.trim() || !password.trim()) {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      showToast("Please fill in both email and password.", "error");
      return;
    }

    setIsLoading(true);
    const { error } = await signIn(email.trim(), password);
    setIsLoading(false);

    if (error) {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      showToast(error.message, "error");
      return;
    }

    void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    showToast("Welcome back!", "success");
    // Brief delay so the user sees the toast before navigating
    setTimeout(() => {
      router.replace("/(tabs)");
    }, 600);
  };

  // Card sizing for the background illustrations
  const bandHeight = Math.max(80, Math.min(150, windowHeight * 0.13));
  const phoneScale = windowWidth < 400 ? 0.42 : windowWidth >= 600 ? 0.72 : 0.5;
  const railWidth = Math.max(0, (windowWidth - 440) / 2);
  const wideScale = Math.max(0.5, Math.min(1, railWidth / 480)) * (windowHeight < 760 ? 0.85 : 1);

  const center = (
    <View style={[styles.center, isWide && styles.centerWide]}>
      <View style={styles.brand}>
        <View style={styles.iconGlow}>
          <Image source={require("@/assets/images/adaptive-icon.png")} style={styles.icon} resizeMode="contain" />
        </View>
        <Text style={styles.title}>My Feeds</Text>
        <Text style={styles.tagline}>Your favorite creators, organized for you.</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Sign in</Text>

        {/* Email field */}
        <Text style={styles.label}>Email</Text>
        <TextInput
          style={[styles.input, emailFocused && styles.inputFocused]}
          placeholder="you@example.com"
          placeholderTextColor="#7F8DAA"
          value={email}
          onChangeText={setEmail}
          onFocus={() => setEmailFocused(true)}
          onBlur={() => setEmailFocused(false)}
          autoCapitalize="none"
          autoComplete="email"
          autoCorrect={false}
          keyboardType="email-address"
          textContentType="emailAddress"
          editable={!isLoading}
          returnKeyType="next"
        />

        {/* Password field */}
        <View style={styles.labelRow}>
          <Text style={[styles.label, styles.labelInRow]}>Password</Text>
          <Pressable
            hitSlop={10}
            style={({ pressed }) => [pressed && { opacity: 0.6 }]}
            onPress={() => router.push("/auth/forgot-password")}
          >
            <Text style={styles.link}>Forgot password?</Text>
          </Pressable>
        </View>
        <View style={styles.passwordWrap}>
          <TextInput
            style={[styles.input, styles.inputWithToggle, passwordFocused && styles.inputFocused]}
            placeholder="Your password"
            placeholderTextColor="#7F8DAA"
            value={password}
            onChangeText={setPassword}
            onFocus={() => setPasswordFocused(true)}
            onBlur={() => setPasswordFocused(false)}
            autoCapitalize="none"
            autoComplete="password"
            autoCorrect={false}
            secureTextEntry={!showPassword}
            textContentType="password"
            editable={!isLoading}
            returnKeyType="done"
            onSubmitEditing={handleSignIn}
          />
          <Pressable
            style={styles.toggle}
            onPress={() => setShowPassword((v) => !v)}
            accessibilityRole="button"
            accessibilityLabel={showPassword ? "Hide password" : "Show password"}
          >
            <Text style={styles.toggleText}>{showPassword ? "Hide" : "Show"}</Text>
          </Pressable>
        </View>

        {/* Sign in button */}
        <Pressable
          style={({ pressed }) => [styles.button, pressed && styles.buttonPressed, isLoading && styles.buttonDisabled]}
          onPress={handleSignIn}
          disabled={isLoading}
        >
          {isLoading ? <ActivityIndicator color={Colors.white} size="small" /> : <Text style={styles.buttonText}>Sign in</Text>}
        </Pressable>

        <View style={styles.divider} />

        {/* Sign up link */}
        <Pressable
          style={({ pressed }) => [styles.signupWrap, pressed && { opacity: 0.6 }]}
          onPress={() => router.push("/auth/signup")}
        >
          <Text style={styles.signupText}>
            New to My Feeds? <Text style={styles.signupLink}>Create an account</Text>
          </Text>
        </Pressable>
      </View>

      {/* Legal links, same as the web login */}
      <View style={styles.legal}>
        <Pressable
          hitSlop={8}
          style={({ pressed }) => [styles.legalLink, pressed && { opacity: 0.6 }]}
          onPress={() => router.push("/support/privacy")}
        >
          <Text style={styles.legalText}>Privacy Policy</Text>
        </Pressable>
        <Pressable
          hitSlop={8}
          style={({ pressed }) => [styles.legalLink, pressed && { opacity: 0.6 }]}
          onPress={() => router.push("/support/terms")}
        >
          <Text style={styles.legalText}>Terms of Service</Text>
        </Pressable>
      </View>
    </View>
  );

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      keyboardVerticalOffset={-insets.bottom}
    >
      <LinearGradient
        colors={["rgba(14,140,230,0.20)", FADE]}
        start={{ x: 0.5, y: 0 }}
        end={{ x: 0.5, y: 0.5 }}
        style={StyleSheet.absoluteFill}
        pointerEvents="none"
      />

      {isWide ? (
        <ScrollView
          contentContainerStyle={[styles.wideScroll, { minHeight: windowHeight }]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.rail} pointerEvents="none">
            <FirstSet spots={WIDE_LEFT} scale={wideScale} opacity={CARD_OPACITY_WIDE} />
            <LinearGradient colors={[FADE, BG]} start={{ x: 0.5, y: 0 }} end={{ x: 1, y: 0 }} style={StyleSheet.absoluteFill} />
          </View>
          <View style={[styles.wideCenter, { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 24 }]}>{center}</View>
          <View style={styles.rail} pointerEvents="none">
            <SecondSet spots={WIDE_RIGHT} scale={wideScale} opacity={CARD_OPACITY_WIDE} />
            <LinearGradient colors={[BG, FADE]} start={{ x: 0, y: 0 }} end={{ x: 0.5, y: 0 }} style={StyleSheet.absoluteFill} />
          </View>
        </ScrollView>
      ) : (
        <ScrollView
          contentContainerStyle={[styles.phoneScroll, { minHeight: windowHeight }]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={[styles.band, { height: bandHeight + insets.top }]} pointerEvents="none">
            <FirstSet spots={PHONE_TOP} scale={phoneScale} opacity={CARD_OPACITY_PHONE} />
            <LinearGradient colors={[FADE, BG]} start={{ x: 0, y: 0.55 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
          </View>
          {center}
          <View style={[styles.band, { height: bandHeight + insets.bottom }]} pointerEvents="none">
            <SecondSet spots={PHONE_BOTTOM} scale={phoneScale} opacity={CARD_OPACITY_PHONE} />
            <LinearGradient colors={[BG, FADE]} start={{ x: 0, y: 0 }} end={{ x: 0, y: 0.45 }} style={StyleSheet.absoluteFill} />
          </View>
        </ScrollView>
      )}

      {/* Toast */}
      {toast && (
        <View
          style={[
            styles.toast,
            toast.type === "error" ? styles.toastError : styles.toastSuccess,
            { top: insets.top + 12 },
          ]}
        >
          <Text style={[styles.toastText, toast.type === "error" ? styles.toastTextError : styles.toastTextSuccess]}>
            {toast.message}
          </Text>
        </View>
      )}
    </KeyboardAvoidingView>
  );
}

const cs = StyleSheet.create({
  card: {
    backgroundColor: "#0D1B38",
    borderWidth: 1,
    borderColor: "#22396A",
    borderRadius: 18,
    padding: 14,
    gap: 10,
  },
  row: { flexDirection: "row", alignItems: "center", gap: 10 },
  col: { flex: 1, gap: 7 },
  thumb: {
    height: 158,
    borderRadius: 12,
    overflow: "hidden",
    backgroundColor: "#16294F",
    alignItems: "center",
    justifyContent: "center",
  },
  playSoft: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: "rgba(255,255,255,0.14)",
    alignItems: "center",
    justifyContent: "center",
  },
  duration: {
    position: "absolute",
    right: 8,
    bottom: 12,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    backgroundColor: "rgba(0,0,0,0.6)",
  },
  durationText: { fontSize: 11, fontWeight: "600", color: "#FFFFFF" },
  progressTrack: { position: "absolute", left: 0, right: 0, bottom: 0, height: 4, backgroundColor: "#24375E" },
  progressFill: { width: "62%", height: 4, backgroundColor: "#E5484D" },
  votes: { width: 34, alignItems: "center", gap: 4 },
  votesText: { fontSize: 11, fontWeight: "700", color: "#C9D6EE" },
  tiny: { fontSize: 10, color: "#7F8DAA" },
  meta: { fontSize: 11, color: "#8EA0C2" },
  react: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: "#0D1B38",
    alignItems: "center",
    justifyContent: "center",
  },
});

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: BG,
  },
  phoneScroll: {
    flexGrow: 1,
    justifyContent: "space-between",
  },
  wideScroll: {
    flexGrow: 1,
    flexDirection: "row",
  },
  band: {
    overflow: "hidden",
  },
  rail: {
    flex: 1,
    overflow: "hidden",
  },
  wideCenter: {
    width: 440,
    justifyContent: "center",
  },
  center: {
    paddingHorizontal: 20,
    paddingVertical: 8,
    gap: 24,
  },
  centerWide: {
    paddingHorizontal: 0,
  },
  brand: {
    alignItems: "center",
  },
  iconGlow: {
    borderRadius: 18,
    shadowColor: "#22B8F5",
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.55,
    shadowRadius: 20,
    marginBottom: 14,
  },
  icon: {
    width: 68,
    height: 68,
    borderRadius: 18,
  },
  title: {
    fontSize: 30,
    fontWeight: "700" as const,
    color: "#FFFFFF",
    textAlign: "center",
    letterSpacing: -0.5,
    marginBottom: 6,
  },
  tagline: {
    fontSize: 15,
    color: "#A9B8D6",
    textAlign: "center",
  },
  card: {
    width: "100%",
    maxWidth: 420,
    alignSelf: "center",
    backgroundColor: "rgba(10,20,40,0.94)",
    borderWidth: 1,
    borderColor: "#1C2B4D",
    borderRadius: 20,
    padding: 24,
    shadowColor: Colors.black,
    shadowOffset: { width: 0, height: 24 },
    shadowOpacity: 0.55,
    shadowRadius: 30,
    elevation: 12,
  },
  cardTitle: {
    fontSize: 20,
    fontWeight: "700" as const,
    color: "#FFFFFF",
    marginBottom: 4,
  },
  label: {
    fontSize: 14,
    fontWeight: "600" as const,
    color: "#C9D6EE",
    marginBottom: 8,
    marginTop: 16,
  },
  labelRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 16,
    marginBottom: 8,
  },
  labelInRow: {
    marginTop: 0,
    marginBottom: 0,
  },
  link: {
    color: "#7DD3FC",
    fontSize: 13,
    fontWeight: "600" as const,
  },
  input: {
    width: "100%",
    height: 50,
    backgroundColor: "#0E1A33",
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#253558",
    paddingHorizontal: 14,
    fontSize: 16,
    color: "#FFFFFF",
  },
  inputFocused: {
    borderColor: "#38BDF8",
  },
  passwordWrap: {
    position: "relative",
    justifyContent: "center",
  },
  inputWithToggle: {
    paddingRight: 68,
  },
  toggle: {
    position: "absolute",
    right: 4,
    height: 44,
    minWidth: 56,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 8,
  },
  toggleText: {
    color: "#93A6C8",
    fontSize: 13,
    fontWeight: "600" as const,
  },
  button: {
    width: "100%",
    height: 50,
    borderRadius: 12,
    backgroundColor: "#0A74BD",
    alignItems: "center",
    justifyContent: "center",
    marginTop: 24,
    shadowColor: "#0A74BD",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 12,
  },
  buttonPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  buttonText: {
    color: Colors.white,
    fontSize: 16,
    fontWeight: "700" as const,
  },
  divider: {
    height: 1,
    backgroundColor: "#1C2B4D",
    marginTop: 20,
  },
  signupWrap: {
    marginTop: 12,
    minHeight: 44,
    alignItems: "center",
    justifyContent: "center",
  },
  signupText: {
    color: "#A9B8D6",
    fontSize: 14,
    textAlign: "center",
  },
  signupLink: {
    color: "#7DD3FC",
    fontWeight: "700" as const,
  },
  legal: {
    flexDirection: "row",
    justifyContent: "center",
    gap: 20,
  },
  legalLink: {
    minHeight: 32,
    justifyContent: "center",
  },
  legalText: {
    color: "#8EA0C2",
    fontSize: 13,
  },
  // Toast
  toast: {
    position: "absolute",
    left: 16,
    right: 16,
    borderRadius: 10,
    paddingHorizontal: 16,
    paddingVertical: 13,
    zIndex: 100,
    shadowColor: Colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  toastError: {
    backgroundColor: Colors.destructiveBg,
    borderLeftWidth: 3,
    borderLeftColor: Colors.destructive,
  },
  toastSuccess: {
    backgroundColor: "hsl(142, 30%, 12%)",
    borderLeftWidth: 3,
    borderLeftColor: Colors.success,
  },
  toastText: {
    fontSize: 14,
    fontWeight: "500" as const,
  },
  toastTextError: {
    color: Colors.destructive,
  },
  toastTextSuccess: {
    color: Colors.success,
  },
});
