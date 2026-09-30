import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack, router } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import React, { useEffect, useRef, useState } from "react";
import { ActivityIndicator, Animated, Image, Platform, Pressable, StyleSheet, Text, View } from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { ChevronLeft } from "lucide-react-native";
import { AuthProvider, useAuth } from "@/lib/auth-provider";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { ToastProvider, ToastHost } from "@/components/Toast";
import { RunningOverlayProvider, RunningOverlay } from "@/lib/running-overlay";
import { YouTubeConnectionProvider } from "@/lib/useYouTubeConnection";
import { Colors } from "@/constants/colors";

SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient();

/**
 * Inject web-only global styles so the browser experience feels native:
 * pointer cursors + subtle hover feedback on interactive elements, smooth
 * wheel scrolling, and a dark theme base behind the SPA. No-op on native.
 */
function useWebGlobalStyles(): void {
  useEffect(() => {
    if (Platform.OS !== "web" || typeof document === "undefined") return;
    const styleId = "dad-web-global-styles";
    if (document.getElementById(styleId)) return;
    const style = document.createElement("style");
    style.id = styleId;
    style.textContent = `
      html, body, #root { height: 100%; background-color: ${Colors.background}; }
      body { margin: 0; overscroll-behavior-y: none; }
      * { scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.18) transparent; }
      *::-webkit-scrollbar { width: 10px; height: 10px; }
      *::-webkit-scrollbar-thumb { background-color: rgba(255,255,255,0.18); border-radius: 8px; }
      *::-webkit-scrollbar-thumb:hover { background-color: rgba(255,255,255,0.3); }
      [role="button"], [role="link"], a, button, summary { cursor: pointer; }
      [role="button"]:hover, [role="link"]:hover { opacity: 0.85; transition: opacity 0.15s ease; }
      input, textarea { outline: none; }
      input::placeholder, textarea::placeholder { color: ${Colors.textMuted}; }
    `;
    document.head.appendChild(style);
  }, []);
}

/**
 * Full-screen branded splash that stays visible for a fixed 3 seconds after the
 * app is ready, then fades out to reveal the underlying screen (login or tabs).
 */
function TimedSplash({ onDone }: { onDone: () => void }) {
  const opacity = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const timer = setTimeout(() => {
      Animated.timing(opacity, {
        toValue: 0,
        duration: 400,
        useNativeDriver: Platform.OS !== "web",
      }).start(() => onDone());
    }, 3000);
    return () => clearTimeout(timer);
  }, [opacity, onDone]);

  return (
    <Animated.View style={[styles.splash, { opacity }]} pointerEvents="none">
      <Image
        source={require("@/assets/images/splash-screen.png")}
        style={styles.splashImage}
        resizeMode="contain"
      />
    </Animated.View>
  );
}

function AuthGate() {
  const { status } = useAuth();

  useEffect(() => {
    if (status !== "loading") {
      SplashScreen.hideAsync();
    }
  }, [status]);

  if (status === "loading") {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color={Colors.accent} />
      </View>
    );
  }

  // Always register both screen groups so React Navigation never
  // gets stuck on a stale screen when auth state changes.
  // Each group layout contains its own redirect guard.
  return (
    <YouTubeConnectionProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="auth" options={{ headerShown: false }} />
        <Stack.Screen
          name="modal"
          options={{ presentation: "modal", headerShown: false }}
        />
        <Stack.Screen
          name="post-reader"
          options={{
            presentation: "modal",
            headerShown: false,
            contentStyle: { backgroundColor: Colors.background },
          }}
        />
        <Stack.Screen
          name="downloads"
          options={{ headerShown: false, contentStyle: { backgroundColor: Colors.background } }}
        />
        <Stack.Screen
          name="video-player"
          options={{
            presentation: "modal",
            headerShown: false,
            contentStyle: { backgroundColor: Colors.background },
          }}
        />
        <Stack.Screen
          name="support/faq"
          options={{
            headerShown: true,
            title: "FAQ",
            headerStyle: { backgroundColor: Colors.background },
            headerTintColor: Colors.textPrimary,
            headerShadowVisible: false,
            headerBackVisible: false,
            headerLeft: () => (
              <Pressable
                onPress={() => router.replace("/(tabs)")}
                style={styles.backBtn}
                hitSlop={8}
              >
                <ChevronLeft size={22} color={Colors.textPrimary} />
                <Text style={styles.backLabel}>Back</Text>
              </Pressable>
            ),
          }}
        />
        <Stack.Screen
          name="support/privacy"
          options={{
            headerShown: true,
            title: "Privacy Policy",
            headerStyle: { backgroundColor: Colors.background },
            headerTintColor: Colors.textPrimary,
            headerShadowVisible: false,
            headerBackVisible: false,
            headerLeft: () => (
              <Pressable
                onPress={() => router.replace("/(tabs)")}
                style={styles.backBtn}
                hitSlop={8}
              >
                <ChevronLeft size={22} color={Colors.textPrimary} />
                <Text style={styles.backLabel}>Back</Text>
              </Pressable>
            ),
          }}
        />
        <Stack.Screen
          name="support/terms"
          options={{
            headerShown: true,
            title: "Terms of Service",
            headerStyle: { backgroundColor: Colors.background },
            headerTintColor: Colors.textPrimary,
            headerShadowVisible: false,
            headerBackVisible: false,
            headerLeft: () => (
              <Pressable
                onPress={() => router.replace("/(tabs)")}
                style={styles.backBtn}
                hitSlop={8}
              >
                <ChevronLeft size={22} color={Colors.textPrimary} />
                <Text style={styles.backLabel}>Back</Text>
              </Pressable>
            ),
          }}
        />
        <Stack.Screen name="+not-found" />
      </Stack>
    </YouTubeConnectionProvider>
  );
}

export default function RootLayout() {
  useWebGlobalStyles();
  const [splashDone, setSplashDone] = useState<boolean>(false);

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <SafeAreaProvider>
          <RunningOverlayProvider>
            <ToastProvider>
              <GestureHandlerRootView style={styles.root}>
                <AuthGate />
                <ToastHost />
                <RunningOverlay />
                {!splashDone ? (
                  <TimedSplash onDone={() => setSplashDone(true)} />
                ) : null}
              </GestureHandlerRootView>
            </ToastProvider>
          </RunningOverlayProvider>
        </SafeAreaProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  loading: {
    flex: 1,
    backgroundColor: Colors.background,
    alignItems: "center",
    justifyContent: "center",
  },
  splash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "#000108",
    alignItems: "center",
    justifyContent: "center",
    zIndex: 9999,
  },
  splashImage: {
    width: "100%",
    height: "100%",
  },
  backBtn: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    gap: 4,
    marginLeft: -4,
    paddingVertical: 4,
    paddingRight: 8,
  },
  backLabel: {
    fontSize: 17,
    color: Colors.textPrimary,
  },
});
