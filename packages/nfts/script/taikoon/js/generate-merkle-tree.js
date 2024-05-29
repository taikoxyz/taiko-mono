const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const path = require("path");
const fs = require("fs");
const ConvertCsvToJson = require("convert-csv-to-json");

async function main() {
  // Get Files in taiko/whitelist folder
  const whitelistDir = path.join(__dirname, "../../../data/taikoon/whitelist");
  const whitelistFiles = fs.readdirSync(whitelistDir);

  whitelistFiles.forEach((file) => {
    // Skip files that are not csv
    if (file.endsWith(".csv") === false) {
      return;
    }

    // extract filename without extension
    const network = file.split(".")[0];

    const inputFile = path.join(
      __dirname,
      `../../../data/taikoon/whitelist/${network}.csv`,
    );
    const outputFile = path.join(
      __dirname,
      `../../../data/taikoon/whitelist/${network}.json`,
    );
    const rawJson =
      ConvertCsvToJson.fieldDelimiter(",").getJsonFromCsv(inputFile);

    const values = rawJson.map((entry) => {
      return [entry.address, entry.freeMints];
    });

    const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

    fs.writeFileSync(
      outputFile,
      JSON.stringify({ ...tree.dump(), root: tree.root }, null, 2),
    );

    console.log(`Merkle Root for network ${network}`, tree.root);
  });
}

main()
  .then(() => {
    console.log("Done");
  })
  .catch((error) => {
    console.error("Error", error);
  });
