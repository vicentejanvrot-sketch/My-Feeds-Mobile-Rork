// A private account's profile, opened inside My Feeds. My Feeds can't read a
// private account's posts (it doesn't sign in as the user), so this shows the
// platform's own page in an in-app browser. The user signs in to Instagram,
// TikTok, X or Facebook here once; the sign-in stays on this phone (the web
// view keeps its cookies) and never reaches My Feeds' servers.
import { useRef, useState } from "react";
import { ActivityIndicator, Platform as RNPlatform, Pressable, StyleSheet, Text, View } from "react-native";
import { WebView } from "react-native-webview";
import { router, useLocalSearchParams } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { ArrowLeft, ExternalLink, RotateCw, X } from "lucide-react-native";
import { useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";
import { openExternalLink } from "@/lib/open-link";

// A normal phone browser, so the platform shows its full mobile site and lets
// the user sign in (some sign-in pages turn away app web views).
const MOBILE_UA =
  RNPlatform.OS === "ios"
    ? "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    : "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36";

export default function ProfileViewer() {
  const params = useLocalSearchParams<{ url?: string; name?: string; platform?: string }>();
  const url = typeof params.url === "string" ? params.url : "";
  const name = typeof params.name === "string" ? params.name : "";
  const platformLabel = typeof params.platform === "string" ? params.platform : "";
  const insets = useSafeAreaInsets();
  const { t } = useTranslation();
  const webRef = useRef<WebView>(null);
  const [loading, setLoading] = useState(true);
  const [canGoBack, setCanGoBack] = useState(false);

  const close = () => (router.canGoBack() ? router.back() : router.replace("/(tabs)"));

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={close} style={styles.roundBtn} hitSlop={8} accessibilityLabel={t("common.close")}>
          <X size={18} color={Colors.textPrimary} />
        </Pressable>
        {canGoBack ? (
          <Pressable onPress={() => webRef.current?.goBack()} style={styles.roundBtn} hitSlop={8} accessibilityLabel={t("common.back")}>
            <ArrowLeft size={18} color={Colors.textPrimary} />
          </Pressable>
        ) : null}
        <View style={styles.titleWrap}>
          <Text style={styles.title} numberOfLines={1}>{name || t("profileViewer.profile")}</Text>
          {platformLabel ? <Text style={styles.subtitle} numberOfLines={1}>{t("profileViewer.signedInHere", { platform: platformLabel })}</Text> : null}
        </View>
        <Pressable onPress={() => webRef.current?.reload()} style={styles.roundBtn} hitSlop={8} accessibilityLabel={t("profileViewer.reload")}>
          <RotateCw size={16} color={Colors.textPrimary} />
        </Pressable>
        <Pressable onPress={() => void openExternalLink(url)} style={styles.roundBtn} hitSlop={8} accessibilityLabel={platformLabel ? t("profileViewer.openIn", { platform: platformLabel }) : t("profileViewer.openInApp")}>
          <ExternalLink size={16} color={Colors.textPrimary} />
        </Pressable>
      </View>
      {url ? (
        <View style={styles.webWrap}>
          <WebView
            ref={webRef}
            source={{ uri: url }}
            userAgent={MOBILE_UA}
            sharedCookiesEnabled
            thirdPartyCookiesEnabled
            domStorageEnabled
            javaScriptEnabled
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction={false}
            allowsBackForwardNavigationGestures
            setSupportMultipleWindows={false}
            onLoadStart={() => setLoading(true)}
            onLoadEnd={() => setLoading(false)}
            onNavigationStateChange={(s) => setCanGoBack(s.canGoBack)}
            // Links the platform would hand to its own app stay in here.
            onShouldStartLoadWithRequest={(req) => /^https?:/i.test(req.url) || req.url === "about:blank"}
            style={styles.web}
          />
          {loading ? (
            <View style={styles.loading} pointerEvents="none">
              <ActivityIndicator color={Colors.accent} />
            </View>
          ) : null}
        </View>
      ) : (
        <Text style={styles.empty}>{t("profileViewer.noLink")}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 12, paddingVertical: 8, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.border },
  roundBtn: { width: 36, height: 36, borderRadius: 18, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  titleWrap: { flex: 1, minWidth: 0, paddingHorizontal: 4 },
  title: { fontSize: 16, fontWeight: "700", color: Colors.textPrimary },
  subtitle: { fontSize: 11, color: Colors.textMuted },
  webWrap: { flex: 1 },
  web: { flex: 1, backgroundColor: Colors.background },
  loading: { position: "absolute", top: 16, left: 0, right: 0, alignItems: "center" },
  empty: { color: Colors.textSecondary, padding: 24, textAlign: "center" },
});
