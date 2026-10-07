import { Fragment } from "react";
import { ScrollView, StyleSheet, Text, Linking } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Trans, useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";
import { formatDate } from "@/lib/i18n";

const SUPPORT_EMAIL = "support@travelone.ca";
const LAST_UPDATED = new Date(2026, 5, 10);
const SECTIONS = ["use", "thirdParty", "conduct", "ip", "warranty", "liability", "termination", "changes", "contact"] as const;

export default function TermsOfServiceScreen() {
  const insets = useSafeAreaInsets();
  const { t, i18n } = useTranslation();

  const handleMailto = async () => {
    try {
      await Linking.openURL(`mailto:${SUPPORT_EMAIL}`);
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
      <Text style={styles.heading}>{t("support.terms")}</Text>
      <Text style={styles.lastUpdated}>{t("legal.lastUpdated", { date: formatDate(LAST_UPDATED) })}</Text>
      {i18n.language !== "en" ? <Text style={styles.lastUpdated}>{t("legal.englishPrevails")}</Text> : null}

      <Text style={styles.paragraph}>{t("legal.terms.intro")}</Text>

      {SECTIONS.map((key) => (
        <Fragment key={key}>
          <Text style={styles.sectionHeading}>{t(`legal.terms.sections.${key}.heading`)}</Text>
          <Text style={styles.paragraph}>
            <Trans
              i18nKey={`legal.terms.sections.${key}.body`}
              values={{ email: SUPPORT_EMAIL }}
              components={{ mail: <Text style={styles.link} onPress={handleMailto} /> }}
            />
          </Text>
        </Fragment>
      ))}
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
  heading: {
    fontSize: 26,
    fontWeight: "800" as const,
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  lastUpdated: {
    fontSize: 12,
    color: Colors.textMuted,
    marginBottom: 20,
  },
  sectionHeading: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: Colors.textPrimary,
    marginTop: 18,
    marginBottom: 6,
  },
  paragraph: {
    fontSize: 14,
    color: Colors.textSecondary,
    lineHeight: 22,
    marginBottom: 10,
  },
  link: {
    color: Colors.accent,
    fontWeight: "600" as const,
  },
});
