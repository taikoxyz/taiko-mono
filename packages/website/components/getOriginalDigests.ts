export const getOriginalDigests = new Promise<Array<Object>>((resolve, reject) => {
  async function getOriginalDigests() {
    await fetch('https://arweave.net/graphql', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
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
                `})
    }).then((res) => res.json())
      .then((response) => {
        const originalDigests = response.data.transactions.edges
        resolve(originalDigests)
      })
      .catch((error) => {
        console.log("An error occurred: ", error);
      });
  }
  getOriginalDigests()
})