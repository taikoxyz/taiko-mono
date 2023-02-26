const Arweave = require("arweave");

const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});

const posts = [];
const hoursBetweenBlogPostFetches = 1

const getTransactionIds = async () => {
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
};

async function getPosts(response) {
  posts.length = 0;
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
        })
        .catch();
    })
  );
}

getTransactionIds();
setInterval(getTransactionIds, hoursBetweenBlogPostFetches * 3600000);

export default (req, res) => {
  res.json(posts);
};
