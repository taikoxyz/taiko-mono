const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

function shuffleArray(array) {
  return array; /*
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
    return array; */
}

async function main() {
  const taikoonsDir = path.join(__dirname, "../../data/original/");

  const blobs = [];
  // iterate over files in the directory
  fs.readdir(taikoonsDir, async (err, rawFiles) => {
    if (err) {
      console.error(err);
      return;
    }

    const files = shuffleArray(rawFiles);

    const finalImageSize = 32;

    for (const file of files) {
      if (!file.endsWith(".png")) continue;
      const fileIndex = file.split(".")[0];
      const sourceFilePath = path.join(taikoonsDir, file);
      const destinationFilePath = path.join(
        __dirname,
        "../../data/images/",
        file,
      );

      const sharpImage = sharp(sourceFilePath)
        .resize(finalImageSize, finalImageSize, {
          kernel: sharp.kernel.nearest,
        })
        .png({ compressionLevel: 9 });

      const contents = await sharpImage.toBuffer();
      await sharpImage.toFile(destinationFilePath);

      console.log(`Converted ${file} to 32x32 PNG.`);
    }
    console.log(`Converted ${blobs.length} Taikoon PNG files to 32x32 base64.`);

    // fs.writeFileSync(path.join(__dirname, '../../data/taikoons-32.json'), JSON.stringify({blobs}, null, 2))
  });
}

main();
