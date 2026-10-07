import { ScrollView, StyleSheet, Text, View, Pressable, Linking, Platform } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";

const FAQ_KEYS = ["what", "youtube", "apiKeys", "storage", "delete", "help"] as const;

export default function FAQScreen() {
  const insets = useSafeAreaInsets();
  const { t } = useTranslation();
  const FAQ_DATA = FAQ_KEYS.map((k) => ({ q: t(`faq.${k}.q`), a: t(`faq.${k}.a`) }));

  const handleMailto = async () => {
    try {
      await Linking.openURL("mailto:support@travelone.ca");
    } catch {
      // mailto may not be supported on all simulators
    }
  };

  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 40 }]}
      showsVerticalScrollIndicator={false}
    >
      {FAQ_DATA.map((item, idx) => (
        <View
          key={idx}
          style={[styles.qaBlock, idx === FAQ_DATA.length - 1 && styles.lastBlock]}
        >
          <Text style={styles.question}>{item.q}</Text>
          <Text style={styles.answer}>{item.a}</Text>
        </View>
      ))}

      <Text style={styles.footer}>
        {t("faq.stillNeedHelp")}{" "}
        <Text style={styles.link} onPress={handleMailto}>
          support@travelone.ca
        </Text>
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  content: {
    paddingHorizontal: 16,
    paddingTop: 16,
  },
  qaBlock: {
    marginBottom: 20,
  },
  lastBlock: {
    marginBottom: 6,
  },
  question: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: Colors.textPrimary,
    marginBottom: 6,
    lineHeight: 22,
  },
  answer: {
    fontSize: 14,
    color: Colors.textSecondary,
    lineHeight: 21,
  },
  footer: {
    fontSize: 14,
    color: Colors.textSecondary,
    lineHeight: 21,
    marginTop: 10,
    paddingTop: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
  },
  link: {
    color: Colors.accent,
    fontWeight: "600" as const,
  },
});
