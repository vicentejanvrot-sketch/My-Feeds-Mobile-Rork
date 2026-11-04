import { readFile, rm, writeFile } from "node:fs/promises";

// Run only inside the newly created presentation app, not the workspace root.
const manifest = JSON.parse(await readFile("package.json", "utf8"));
if (!manifest.dependencies?.["@slidev/cli"]) throw new Error("Install Slidev in the presentation app first.");
manifest.scripts = {
  ...manifest.scripts,
  dev: "slidev slides.md --port 8080",
  build: "slidev build slides.md --out dist --base /",
  "build:dev": "slidev build slides.md --out dist --base /",
  preview: "vite preview --host 0.0.0.0 --port 8080",
};
await writeFile("package.json", JSON.stringify(manifest, null, 2) + "\n");

// Slidev merges a root index.html's <body> into the deck, so the scaffold's would boot the React
// app, compiled by Slidev's Vue JSX plugin, and crash every slide with React error #31.
const indexHtml = await readFile("index.html", "utf8").catch((error) => {
  if (error.code === "ENOENT") return "";
  throw error;
});
if (indexHtml.includes("/src/main.tsx")) await rm("index.html");
