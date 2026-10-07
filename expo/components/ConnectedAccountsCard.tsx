import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import * as Haptics from "expo-haptics";
import { Link2, Unlink } from "lucide-react-native";
import { useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";
import { PlatformBadge } from "@/components/PlatformBadge";
import { useToast } from "@/components/Toast";
import {
  CONNECT_LABEL,
  CONNECT_PROVIDERS,
  useConnect,
  useConnections,
  useDisconnect,
  type ConnectProvider,
} from "@/lib/useConnections";

// Settings card: GitHub and Reddit connections, so adding a GitHub or Reddit
// account on People also follows it there (YouTube has its own card above).
export function ConnectedAccountsCard() {
  const { data: connections = [], isLoading } = useConnections();
  const connect = useConnect();
  const disconnect = useDisconnect();
  const showToast = useToast();
  const { t } = useTranslation();

  const onConnect = (provider: ConnectProvider) => {
    void Haptics.selectionAsync();
    connect.mutate(provider, {
      onSuccess: (connection) => {
        if (!connection) return;
        showToast(
          connection.accountName
            ? t("connections.connectedAsToast", { provider: CONNECT_LABEL[provider], name: connection.accountName })
            : t("connections.connectedToast", { provider: CONNECT_LABEL[provider] }),
          "success",
        );
      },
      onError: (e) => showToast(e instanceof Error ? e.message : t("connections.connectFailed", { provider: CONNECT_LABEL[provider] }), "error"),
    });
  };

  const onDisconnect = (provider: ConnectProvider) => {
    void Haptics.selectionAsync();
    disconnect.mutate(provider, {
      onSuccess: () => showToast(t("connections.disconnectedToast", { provider: CONNECT_LABEL[provider] }), "success"),
      onError: (e) => showToast(e instanceof Error ? e.message : t("connections.disconnectFailed", { provider: CONNECT_LABEL[provider] }), "error"),
    });
  };

  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Link2 size={18} color={Colors.accent} />
        <Text style={styles.cardTitle}>GitHub & Reddit</Text>
      </View>
      <Text style={styles.cardDesc}>
        {t("connections.desc")}
      </Text>
      {CONNECT_PROVIDERS.map((provider) => {
        const connection = connections.find((c) => c.provider === provider);
        const busy = (connect.isPending && connect.variables === provider) ||
          (disconnect.isPending && disconnect.variables === provider);
        return (
          <View key={provider} style={styles.row}>
            <View style={styles.rowLeft}>
              <PlatformBadge platform={provider} size="md" />
              <View style={{ flex: 1 }}>
                <Text style={styles.rowTitle}>{CONNECT_LABEL[provider]}</Text>
                <Text style={styles.rowSub} numberOfLines={1}>
                  {connection
                    ? connection.accountName
                      ? t("connections.connectedAs", { name: connection.accountName })
                      : t("connections.connected")
                    : t("connections.notConnected")}
                </Text>
              </View>
            </View>
            <Pressable
              disabled={busy || isLoading}
              onPress={() => (connection ? onDisconnect(provider) : onConnect(provider))}
              style={({ pressed }) => [styles.btn, (pressed || busy) && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel={t(connection ? "connections.disconnectLabel" : "connections.connectLabel", { provider: CONNECT_LABEL[provider] })}
            >
              {busy ? (
                <ActivityIndicator size="small" color={Colors.accent} />
              ) : connection ? (
                <Unlink size={15} color={Colors.destructive} />
              ) : (
                <Link2 size={15} color={Colors.accent} />
              )}
              <Text style={[styles.btnText, connection && { color: Colors.destructive }]}>
                {connection ? t("connections.disconnect") : t("connections.connect")}
              </Text>
            </Pressable>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 18,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    marginBottom: 14,
  },
  cardHeader: { flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 8 },
  cardTitle: { fontSize: 16, fontWeight: "700" as const, color: Colors.textPrimary },
  cardDesc: { fontSize: 12, color: Colors.textMuted, lineHeight: 17, marginBottom: 8 },
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
    paddingVertical: 12,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
  },
  rowLeft: { flexDirection: "row", alignItems: "center", gap: 12, flex: 1, minWidth: 0 },
  rowTitle: { fontSize: 14, fontWeight: "600" as const, color: Colors.textPrimary },
  rowSub: { fontSize: 12, color: Colors.textMuted, marginTop: 2 },
  btn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 9,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.input,
  },
  btnText: { fontSize: 13, fontWeight: "600" as const, color: Colors.accent },
  pressed: { opacity: 0.7 },
});
