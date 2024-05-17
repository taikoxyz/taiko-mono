const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const path = require("path");
const fs = require("fs");
const ConvertCsvToJson = require("convert-csv-to-json");

async function main(network) {
  const inputFile = path.join(__dirname, `../../data/whitelist/${network}.csv`);
  const outputFile = path.join(
    __dirname,
    `../../data/whitelist/${network}.json`,
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

    console.log(`Merkle Root for network ${network}`, tree.root)
}

main('hardhat')
main('holesky')
main('devnet')
