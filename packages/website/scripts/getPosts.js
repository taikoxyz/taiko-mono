const Arweave = require("arweave");
const fs = require("fs");

const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});

async function getTransanctionIds() {
  await fetch("https://arweave.net/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: `
              query {
                  transactions(
                    first: 100
                    sort: HEIGHT_DESC
                    tags: [
                      {
                        name: "Contributor"
                        values: ["0x5b796c4B197B6DfD413f177059C27963EB80af0F","0x2b1F13149C7F89622BBfB46Ae1e3ECc573Bb9331","0x381636D0E4eD0fa6aCF07D8fd821909Fb63c0d10"]
                      },
                      {
                        name: "App-Name"
                        values: "MirrorXYZ"
                      }
                    ]
                  ) {
                    edges {
                      node {
                        id
                        tags {
                          name
                          value
                        }
                      }
                    }
                  }
                }
              `,
    }),
  })
    .then((res) => res.json())
    .then((response) => {
      getPosts(response);
    })
    .catch();
}

async function getPosts(response) {
  const posts = [];
  Promise.all(
    response.data.transactions.edges.map((edge) => {
      const transactionId = edge.node.id;
      arweave.transactions
        .getData(`${transactionId}`, { decode: true, string: true })
        .then((response) => JSON.parse(response))
        .then((data) => {
          // Check if the posts have the required keys
          if (data.hasOwnProperty("wnft")) {
            // add the original digest
            data["OriginalDigest"] = edge.node.tags[4].value;
            posts.push(data);
          }

          const jsonString = JSON.stringify(posts);
          fs.writeFile("./public/posts.json", jsonString, (err) => {});
        })
        .catch();
    })
  );
}

getTransanctionIds();
