import { View } from "react-native";
import Svg, { Circle, Defs, LinearGradient, Path, Rect, Stop, Text as SvgText } from "react-native-svg";
import { Colors } from "@/constants/colors";
import { Platform, PLATFORM_META } from "@/lib/platforms";

// Official platform logos (Simple Icons, 24x24 viewBox; LinkedIn drawn as its
// blue "in" tile). Same shapes as the web PlatformBadge and
// ios/MyFeeds/Models/PlatformLogo.swift.
const YOUTUBE_PATH =
  "M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z";
const YOUTUBE_PLAY = "M9.545 15.568V8.432L15.818 12l-6.273 3.568z";
const X_PATH =
  "M14.234 10.162 22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299-.929-1.329L3.076 1.56h3.182l5.965 8.532.929 1.329 7.754 11.09h-3.182z";
const INSTAGRAM_PATH =
  "M7.0301.084c-1.2768.0602-2.1487.264-2.911.5634-.7888.3075-1.4575.72-2.1228 1.3877-.6652.6677-1.075 1.3368-1.3802 2.127-.2954.7638-.4956 1.6365-.552 2.914-.0564 1.2775-.0689 1.6882-.0626 4.947.0062 3.2586.0206 3.6671.0825 4.9473.061 1.2765.264 2.1482.5635 2.9107.308.7889.72 1.4573 1.388 2.1228.6679.6655 1.3365 1.0743 2.1285 1.38.7632.295 1.6361.4961 2.9134.552 1.2773.056 1.6884.069 4.9462.0627 3.2578-.0062 3.668-.0207 4.9478-.0814 1.28-.0607 2.147-.2652 2.9098-.5633.7889-.3086 1.4578-.72 2.1228-1.3881.665-.6682 1.0745-1.3378 1.3795-2.1284.2957-.7632.4966-1.636.552-2.9124.056-1.2809.0692-1.6898.063-4.948-.0063-3.2583-.021-3.6668-.0817-4.9465-.0607-1.2797-.264-2.1487-.5633-2.9117-.3084-.7889-.72-1.4568-1.3876-2.1228C21.2982 1.33 20.628.9208 19.8378.6165 19.074.321 18.2017.1197 16.9244.0645 15.6471.0093 15.236-.005 11.977.0014 8.718.0076 8.31.0215 7.0301.0839m.1402 21.6932c-1.17-.0509-1.8053-.2453-2.2287-.408-.5606-.216-.96-.4771-1.3819-.895-.422-.4178-.6811-.8186-.9-1.378-.1644-.4234-.3624-1.058-.4171-2.228-.0595-1.2645-.072-1.6442-.079-4.848-.007-3.2037.0053-3.583.0607-4.848.05-1.169.2456-1.805.408-2.2282.216-.5613.4762-.96.895-1.3816.4188-.4217.8184-.6814 1.3783-.9003.423-.1651 1.0575-.3614 2.227-.4171 1.2655-.06 1.6447-.072 4.848-.079 3.2033-.007 3.5835.005 4.8495.0608 1.169.0508 1.8053.2445 2.228.408.5608.216.96.4754 1.3816.895.4217.4194.6816.8176.9005 1.3787.1653.4217.3617 1.056.4169 2.2263.0602 1.2655.0739 1.645.0796 4.848.0058 3.203-.0055 3.5834-.061 4.848-.051 1.17-.245 1.8055-.408 2.2294-.216.5604-.4763.96-.8954 1.3814-.419.4215-.8181.6811-1.3783.9-.4224.1649-1.0577.3617-2.2262.4174-1.2656.0595-1.6448.072-4.8493.079-3.2045.007-3.5825-.006-4.848-.0608M16.953 5.5864A1.44 1.44 0 1 0 18.39 4.144a1.44 1.44 0 0 0-1.437 1.4424M5.8385 12.012c.0067 3.4032 2.7706 6.1557 6.173 6.1493 3.4026-.0065 6.157-2.7701 6.1506-6.1733-.0065-3.4032-2.771-6.1565-6.174-6.1498-3.403.0067-6.156 2.771-6.1496 6.1738M8 12.0077a4 4 0 1 1 4.008 3.9921A3.9996 3.9996 0 0 1 8 12.0077";
const REDDIT_PATH =
  "M12 0C5.373 0 0 5.373 0 12c0 3.314 1.343 6.314 3.515 8.485l-2.286 2.286C.775 23.225 1.097 24 1.738 24H12c6.627 0 12-5.373 12-12S18.627 0 12 0Zm4.388 3.199c1.104 0 1.999.895 1.999 1.999 0 1.105-.895 2-1.999 2-.946 0-1.739-.657-1.947-1.539v.002c-1.147.162-2.032 1.15-2.032 2.341v.007c1.776.067 3.4.567 4.686 1.363.473-.363 1.064-.58 1.707-.58 1.547 0 2.802 1.254 2.802 2.802 0 1.117-.655 2.081-1.601 2.531-.088 3.256-3.637 5.876-7.997 5.876-4.361 0-7.905-2.617-7.998-5.87-.954-.447-1.614-1.415-1.614-2.538 0-1.548 1.255-2.802 2.803-2.802.645 0 1.239.218 1.712.585 1.275-.79 2.881-1.291 4.64-1.365v-.01c0-1.663 1.263-3.034 2.88-3.207.188-.911.993-1.595 1.959-1.595Zm-8.085 8.376c-.784 0-1.459.78-1.506 1.797-.047 1.016.64 1.429 1.426 1.429.786 0 1.371-.369 1.418-1.385.047-1.017-.553-1.841-1.338-1.841Zm7.406 0c-.786 0-1.385.824-1.338 1.841.047 1.017.634 1.385 1.418 1.385.785 0 1.473-.413 1.426-1.429-.046-1.017-.721-1.797-1.506-1.797Zm-3.703 4.013c-.974 0-1.907.048-2.77.135-.147.015-.241.168-.183.305.483 1.154 1.622 1.964 2.953 1.964 1.33 0 2.47-.81 2.953-1.964.057-.137-.037-.29-.184-.305-.863-.087-1.795-.135-2.769-.135Z";
const GITHUB_PATH =
  "M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12";

// Facebook's round "f" mark: a blue circle with the f cut out, drawn over a
// white circle so the f shows white.
const FACEBOOK_PATH =
  "M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.628 3.874 10.35 9.101 11.647Z";

const TIKTOK_PATH =
  "M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z";

// The logo as it appears on the platform: red YouTube button with a white play
// arrow, white X on the dark theme, white Snoo on the orange Reddit bubble,
// the Instagram camera in its gradient, LinkedIn's blue "in" tile and the
// GitHub Octocat mark.
// Each logo's scale inside its box, so they all look the same size: the X
// glyph fills its corners and the Instagram camera is a full square, while the
// YouTube button is only 17 of 24 tall. Keep in sync with web and iOS.
const LOGO_SCALE: Record<Platform, number> = {
  youtube: 1,
  x: 0.68,
  instagram: 0.82,
  linkedin: 0.84,
  reddit: 0.92,
  github: 0.9,
  tiktok: 0.86,
  facebook: 0.9,
};

// Zooms the 24x24 artwork out around its centre.
function viewBoxFor(platform: Platform): string {
  const side = 24 / LOGO_SCALE[platform];
  const origin = 12 - side / 2;
  return `${origin} ${origin} ${side} ${side}`;
}

export function PlatformLogo({ platform, size }: { platform: Platform; size: number }) {
  if (platform === "youtube") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Path d={YOUTUBE_PLAY} fill="#FFFFFF" />
        <Path d={YOUTUBE_PATH} fill="#FF0000" />
      </Svg>
    );
  }
  if (platform === "x") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Path d={X_PATH} fill={Colors.textPrimary} />
      </Svg>
    );
  }
  if (platform === "instagram") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Defs>
          <LinearGradient id="mfIgGradient" x1="0" y1="1" x2="1" y2="0">
            <Stop offset="0" stopColor="#FEDA75" />
            <Stop offset="0.3" stopColor="#FA7E1E" />
            <Stop offset="0.55" stopColor="#D62976" />
            <Stop offset="0.8" stopColor="#962FBF" />
            <Stop offset="1" stopColor="#4F5BD5" />
          </LinearGradient>
        </Defs>
        <Path d={INSTAGRAM_PATH} fill="url(#mfIgGradient)" />
      </Svg>
    );
  }
  if (platform === "facebook") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Circle cx={12} cy={12} r={10} fill="#FFFFFF" />
        <Path d={FACEBOOK_PATH} fill="#0866FF" />
      </Svg>
    );
  }
  if (platform === "tiktok") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Path d={TIKTOK_PATH} fill={Colors.textPrimary} />
      </Svg>
    );
  }
  if (platform === "github") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Path d={GITHUB_PATH} fill={Colors.textPrimary} />
      </Svg>
    );
  }
  if (platform === "linkedin") {
    return (
      <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
        <Rect x={0} y={0} width={24} height={24} rx={4.5} fill="#0A66C2" />
        <SvgText x={12} y={18.2} textAnchor="middle" fontWeight="700" fontSize={16} fill="#FFFFFF">in</SvgText>
      </Svg>
    );
  }
  return (
    <Svg width={size} height={size} viewBox={viewBoxFor(platform)}>
      <Circle cx={12} cy={12} r={10.5} fill="#FFFFFF" />
      <Path d={REDDIT_PATH} fill="#FF4500" />
    </Svg>
  );
}

// Platform logo used on cards, lists and filters — same look as the web app.
export function PlatformBadge({ platform, size = "sm" }: { platform: Platform; size?: "sm" | "md" }) {
  const box = size === "sm" ? 20 : 28;
  return (
    <View
      style={{ width: box, height: box, alignItems: "center", justifyContent: "center" }}
      accessibilityRole="image"
      accessibilityLabel={PLATFORM_META[platform].label}
    >
      <PlatformLogo platform={platform} size={box} />
    </View>
  );
}
