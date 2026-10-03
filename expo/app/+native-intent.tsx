// Translates links the OS hands to the app into app routes.
//
// My Feeds links open the matching screen here instead of the browser. The
// universal / App Link form is https://myfeeds.ca/open/<web app path> (the
// association files live on myfeeds.ca, and without the app that URL redirects
// to the web app); https://webapp.myfeeds.ca/<path> is understood too. Same
// paths as the web app's routes; keep in sync with
// ios/MyFeeds/Services/AppRouter.swift (WebLink). Anything else (OAuth returns
// on the rork-app:// scheme, unknown paths) opens the home screen, as before.

const WEB_APP_HOST = "webapp.myfeeds.ca";
const SITE_HOSTS = new Set(["myfeeds.ca", "www.myfeeds.ca"]);
const OPEN_PREFIX = "/open";
const STATUSES = new Set(["not_watched", "watched", "liked", "watch_later"]);

function withParams(route: string, params: Record<string, string | undefined>): string {
  const query = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== "")
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v as string)}`)
    .join("&");
  return query ? `${route}?${query}` : route;
}

// Parsed by hand rather than with URL, which isn't fully implemented in every
// React Native runtime.
function webLinkToRoute(raw: string): string | null {
  const match = /^https?:\/\/([^/?#]+)([^?#]*)(?:\?([^#]*))?/i.exec(raw);
  if (!match) return null;
  const host = match[1].toLowerCase();
  let pathname = match[2] || "/";
  if (SITE_HOSTS.has(host)) {
    if (pathname !== OPEN_PREFIX && !pathname.startsWith(OPEN_PREFIX + "/")) return null;
    pathname = pathname.slice(OPEN_PREFIX.length) || "/";
  } else if (host !== WEB_APP_HOST) {
    return null;
  }
  const search: Record<string, string> = {};
  for (const pair of (match[3] ?? "").split("&")) {
    if (!pair) continue;
    const [k, v = ""] = pair.split("=");
    try {
      search[decodeURIComponent(k)] = decodeURIComponent(v.replace(/\+/g, " "));
    } catch {
      // ignore a malformed pair
    }
  }

  const parts = pathname.split("/").filter(Boolean);
  const param = (name: string) => search[name] || undefined;
  // openedAt makes screens that are already open re-read their params.
  const openedAt = String(Date.now());

  switch (parts[0] ?? "") {
    case "":
      return "/";
    case "feed": {
      const status = param("status");
      // item and video (from the digest email) open that item over the feed:
      // a YouTube video in the player, anything else in the post reader.
      return withParams("/feed", {
        agentId: param("agent"),
        status: status && STATUSES.has(status) ? status : undefined,
        itemId: param("item"),
        videoId: param("video"),
        openedAt,
      });
    }
    case "agents":
      if (parts.length === 1) return "/agents";
      if (parts[1] === "new") return "/agent-form";
      if (parts[2] === "edit") return withParams("/agent-form", { agentId: parts[1] });
      return withParams("/agent-detail", { agentId: parts[1] });
    // The app has no run detail screen, so a run opens History.
    case "history":
    case "runs":
      return "/history";
    case "following":
      return withParams("/following", { agentId: param("agent"), openedAt });
    case "settings":
      return "/settings";
    // myfeeds.ca/open/share?url=<link>: the "Add to My Feeds" card.
    case "share":
      return withParams("/share", { text: [param("url"), param("text")].filter(Boolean).join(" ") || undefined });
    default:
      return "/";
  }
}

export function redirectSystemPath({ path, initial }: { path: string; initial: boolean }) {
  return webLinkToRoute(path) ?? "/";
}
