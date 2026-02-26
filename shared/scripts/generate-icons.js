import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import toIco from "to-ico";
import { Icns, IcnsImage } from "@fiahfy/icns";

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

  const icoSizes = [16, 24, 32, 48, 64, 128, 256];
  const icoPngs = await Promise.all(
    icoSizes.map((size) =>
      sharp(svgBuffer)
        .resize(size, size, { fit: "contain" })
        .png()
        .toBuffer(),
    ),
  );
  const icoBuffer = await toIco(icoPngs);
  const icoPath = path.join(rootDir, "desktop/src-tauri/icons/icon.ico");
  await fs.writeFile(icoPath, icoBuffer);
  console.log("generated desktop/src-tauri/icons/icon.ico");

  const icnsIconTypes = [
    { osType: "icp4", size: 16 },
    { osType: "icp5", size: 32 },
    { osType: "icp6", size: 64 },
    { osType: "ic07", size: 128 },
    { osType: "ic08", size: 256 },
    { osType: "ic09", size: 512 },
    { osType: "ic10", size: 1024 },
  ];
  const icns = new Icns();
  for (const iconType of icnsIconTypes) {
    const pngBuffer = await sharp(svgBuffer)
      .resize(iconType.size, iconType.size, { fit: "contain" })
      .png()
      .toBuffer();
    icns.append(IcnsImage.fromPNG(pngBuffer, iconType.osType));
  }
  const icnsPath = path.join(rootDir, "desktop/src-tauri/icons/icon.icns");
  await fs.writeFile(icnsPath, icns.data);
  console.log("generated desktop/src-tauri/icons/icon.icns");
}

generate().catch((error) => {
  console.error(error);
  process.exit(1);
});
