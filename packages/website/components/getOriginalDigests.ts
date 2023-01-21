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
                  values: "0x381636D0E4eD0fa6aCF07D8fd821909Fb63c0d10"
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