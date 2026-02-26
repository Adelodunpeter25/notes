import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";

const rootDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const sourceSvg = path.join(rootDir, "shared/assets/notes-icon.svg");

const targets = [
  { file: "mobile/assets/icon.png", size: 1024 },
  { file: "mobile/assets/adaptive-icon.png", size: 1024 },
  { file: "mobile/assets/splash-icon.png", size: 1024 },
  { file: "mobile/assets/favicon.png", size: 48 },

  { file: "desktop/src-tauri/icons/icon.png", size: 512 },
  { file: "desktop/src-tauri/icons/32x32.png", size: 32 },
  { file: "desktop/src-tauri/icons/128x128.png", size: 128 },
  { file: "desktop/src-tauri/icons/128x128@2x.png", size: 256 },
  { file: "desktop/src-tauri/icons/StoreLogo.png", size: 50 },
  { file: "desktop/src-tauri/icons/Square30x30Logo.png", size: 30 },
  { file: "desktop/src-tauri/icons/Square44x44Logo.png", size: 44 },
  { file: "desktop/src-tauri/icons/Square71x71Logo.png", size: 71 },
  { file: "desktop/src-tauri/icons/Square89x89Logo.png", size: 89 },
  { file: "desktop/src-tauri/icons/Square107x107Logo.png", size: 107 },
  { file: "desktop/src-tauri/icons/Square142x142Logo.png", size: 142 },
  { file: "desktop/src-tauri/icons/Square150x150Logo.png", size: 150 },
  { file: "desktop/src-tauri/icons/Square284x284Logo.png", size: 284 },
  { file: "desktop/src-tauri/icons/Square310x310Logo.png", size: 310 },
];

async function generate() {
  const svgBuffer = await fs.readFile(sourceSvg);

  for (const target of targets) {
    const outputPath = path.join(rootDir, target.file);
    await fs.mkdir(path.dirname(outputPath), { recursive: true });

    await sharp(svgBuffer)
      .resize(target.size, target.size, { fit: "contain" })
      .png()
      .toFile(outputPath);

    console.log(`generated ${target.file} (${target.size}x${target.size})`);
  }
}

generate().catch((error) => {
  console.error(error);
  process.exit(1);
});
