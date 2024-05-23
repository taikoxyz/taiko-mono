const { S3 } = require("@aws-sdk/client-s3");
const { Upload } = require("@aws-sdk/lib-storage");
const fs = require("fs");
const fsPromises = fs.promises;
const path = require("path");
const dotenv = require("dotenv");
dotenv.config();

async function uploadFile(s3, params) {
  try {
    const task = new Upload({
      client: s3,
      queueSize: 3, // 3 MiB
      params,
    });

    const res = await task.done();
    return res.ETag.split('"').join("");
  } catch (error) {
    if (error) {
      console.log("task", error.message);
    }
  }
}

// Helper function to form the metadata JSON object
function populateNFTMetadata(name, description, CID) {
  return {
    name,
    description,
    image: CID,
  };
}

async function main() {
  const s3Params = {
    accessKey: process.env["4EVERLAND_ACCESS_KEY"],
    secretKey: process.env["4EVERLAND_SECRET_KEY"],
  };
  const { accessKey, secretKey } = s3Params;
  const s3 = new S3({
    endpoint: "https://endpoint.4everland.co",
    credentials: {
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
    },
    region: "4EVERLAND",
  });

  // Get the images to upload from the local filesystem (/images)
  console.log(`Importing images from the images/ directory...`);
  const imgDirPath = path.join(
    path.resolve(__dirname, "../../../data/snaefell"),
    "images",
  );
  const filesName = await fsPromises.readdir(imgDirPath, (err) => {
    if (err) {
      console.log("Import from directory failed: ", err);
    }
  });

  // Uploading images to IPFS
  console.log(`Uploading image data to IPFS...`);
  const imageCIDs = [];
  const imagesSummary = [];
  let imageCount = 1;
  const imagesName = filesName.filter((fileName) => fileName.includes(".png"));
  for await (const imageName of imagesName) {
    const imageFilePath = path.join(
      path.resolve(__dirname, "../../../data/snaefell"),
      "images",
      imageName,
    );
    const params = {
      Bucket: "snaefell-bucket",
      Key: imageName,
      ContentType: "image/png",
      Body: fs.readFileSync(imageFilePath),
    };

    const imageCID = await uploadFile(s3, params);

    imageCIDs.push(imageCID);
    imagesSummary.push({ imageCID, imageCount });
    console.log(`Image ${imageCount} added to IPFS with CID of ${imageCID}`);
    imageCount++;
  }
  console.log(` `);

  // Add the metadata to IPFS
  console.log(`Adding metadata to IPFS...`);
  let tokenId = 0;
  for await (const imageCID of imageCIDs) {
    tokenId++;

    // write into a file
    fs.writeFileSync(
      path.join(
        path.resolve(__dirname, "../../../data/snaefell"),
        "metadata",
        `${tokenId}.json`,
      ),
      JSON.stringify(
        populateNFTMetadata(
          `Snæfellsjökull Commemorative NFT`,
          "Commemorative NFT for Testnet - Alpha 1",
          imageCID.toString(),
        ),
      ),
    );

    const metadataCID = await uploadFile(s3, {
      Bucket: "snaefell-bucket",
      Key: `${tokenId}.json`,
      ContentType: "application/json",
      Body: fs.readFileSync(
        path.join(
          path.resolve(__dirname, "../../../data/snaefell"),
          "metadata",
          `${tokenId}.json`,
        ),
      ),
    });

    console.log("Metadata CID:", metadataCID);

    console.log(
      path.join(
        path.resolve(__dirname, "../../../data/snaefell"),
        "metadata",
        `${tokenId}.json`,
      ),
    );
    /*
    metadataCIDs.push(metadataCID);
    for (let i = 0; i < imagesSummary.length; i++) {
      if (imagesSummary[i].imageCID == imageCID) {
        imagesSummary[i].metadataCID = metadataCID;
      }
    } */
    // console.log(`Metadata with image CID ${imageCID} added to IPFS with CID of ${metadataCID}`);
  }
  console.log(` `);
}

main();
