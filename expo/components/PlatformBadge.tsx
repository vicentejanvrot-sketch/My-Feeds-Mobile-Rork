import { View } from "react-native";
import Svg, { Circle, Path } from "react-native-svg";
import { Colors } from "@/constants/colors";
import { Platform, PLATFORM_META } from "@/lib/platforms";

// Official platform logos (Simple Icons, 24x24 viewBox). Same shapes as the
// web PlatformBadge and ios/MyFeeds/Models/PlatformLogo.swift.
const YOUTUBE_PATH =
  "M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z";
const YOUTUBE_PLAY = "M9.545 15.568V8.432L15.818 12l-6.273 3.568z";
const X_PATH =
  "M14.234 10.162 22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299-.929-1.329L3.076 1.56h3.182l5.965 8.532.929 1.329 7.754 11.09h-3.182z";
const REDDIT_PATH =
  "M12 0C5.373 0 0 5.373 0 12c0 3.314 1.343 6.314 3.515 8.485l-2.286 2.286C.775 23.225 1.097 24 1.738 24H12c6.627 0 12-5.373 12-12S18.627 0 12 0Zm4.388 3.199c1.104 0 1.999.895 1.999 1.999 0 1.105-.895 2-1.999 2-.946 0-1.739-.657-1.947-1.539v.002c-1.147.162-2.032 1.15-2.032 2.341v.007c1.776.067 3.4.567 4.686 1.363.473-.363 1.064-.58 1.707-.58 1.547 0 2.802 1.254 2.802 2.802 0 1.117-.655 2.081-1.601 2.531-.088 3.256-3.637 5.876-7.997 5.876-4.361 0-7.905-2.617-7.998-5.87-.954-.447-1.614-1.415-1.614-2.538 0-1.548 1.255-2.802 2.803-2.802.645 0 1.239.218 1.712.585 1.275-.79 2.881-1.291 4.64-1.365v-.01c0-1.663 1.263-3.034 2.88-3.207.188-.911.993-1.595 1.959-1.595Zm-8.085 8.376c-.784 0-1.459.78-1.506 1.797-.047 1.016.64 1.429 1.426 1.429.786 0 1.371-.369 1.418-1.385.047-1.017-.553-1.841-1.338-1.841Zm7.406 0c-.786 0-1.385.824-1.338 1.841.047 1.017.634 1.385 1.418 1.385.785 0 1.473-.413 1.426-1.429-.046-1.017-.721-1.797-1.506-1.797Zm-3.703 4.013c-.974 0-1.907.048-2.77.135-.147.015-.241.168-.183.305.483 1.154 1.622 1.964 2.953 1.964 1.33 0 2.47-.81 2.953-1.964.057-.137-.037-.29-.184-.305-.863-.087-1.795-.135-2.769-.135Z";

// The logo as it appears on the platform: red YouTube button with a white play
// arrow, white X on the dark theme, white Snoo on the orange Reddit bubble.
export function PlatformLogo({ platform, size }: { platform: Platform; size: number }) {
  if (platform === "youtube") {
    return (
      <Svg width={size} height={size} viewBox="0 0 24 24">
        <Path d={YOUTUBE_PLAY} fill="#FFFFFF" />
        <Path d={YOUTUBE_PATH} fill="#FF0000" />
      </Svg>
    );
  }
  if (platform === "x") {
    return (
      <Svg width={size * 0.8} height={size * 0.8} viewBox="0 0 24 24">
        <Path d={X_PATH} fill={Colors.textPrimary} />
      </Svg>
    );
  }
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
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
