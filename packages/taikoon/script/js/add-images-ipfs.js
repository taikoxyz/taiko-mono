const path = require('path')
const fs = require('fs')
const fsPromises = fs.promises

// Helper function to form the metadata JSON object
function populateNFTMetadata(name, description, CID) {
    return {
        name,
        description,
        image: CID,
    }
}

async function main() {
    console.log(`Configuring the IPFS instance...`)
    const { create } = await import('ipfs-http-client')
    const ipfs = create()
    const endpointConfig = await ipfs.getEndpointConfig()
    console.log(`IPFS configured to connect via: `)
    console.debug(endpointConfig)
    console.log(` `)

    // Get the images to upload from the local filesystem (/images)
    console.log(`Importing images from the images/ directory...`)
    const imgDirPath = path.join(path.resolve(__dirname, '../../data'), 'images')
    const filesName = await fsPromises.readdir(imgDirPath, (err) => {
        if (err) {
            console.log('Import from directory failed: ', err)
        }
    })
    const imagesName = filesName.filter((fileName) => fileName.includes('.png'))
    let imagesData = []
    for await (const imageName of imagesName) {
        let imageFilePath = path.join(path.resolve(__dirname, '../../data'), 'images', imageName)
        let imageData = await fsPromises.readFile(imageFilePath)
        imagesData.push(imageData)
    }
    console.log(`Imported images as buffered data\n`)

    // Uploading images to IPFS
    console.log(`Uploading image data to IPFS...`)
    let imageCIDs = []
    let imagesSummary = []
    let imageCount = 1
    for await (const imageData of imagesData) {
        let { cid: imageCID } = await ipfs.add({
            content: imageData,
        })
        imageCIDs.push(imageCID)
        imagesSummary.push({ imageCID, imageCount })
        console.log(`Image added to IPFS with CID of ${imageCID}`)
        imageCount++
    }
    console.log(` `)



    // Add the metadata to IPFS
    console.log(`Adding metadata to IPFS...`);
    let metadataCIDs = [];
    let taikoonId = 0
    for await (const imageCID of imageCIDs) {
        taikoonId++
        const {cid: metadataCID} = await ipfs.add({
            // NOTE: You can implement different name & descriptions for each metadata
            content: JSON.stringify(populateNFTMetadata(`Taikoon ${taikoonId}`, "A Taikoon", imageCID.toString()))
        })

        // write into a file
        fs.writeFileSync(
            path.join(path.resolve(__dirname, '../../data'), 'metadata', `${taikoonId}.json`),
            JSON.stringify(populateNFTMetadata(`Taikoon ${taikoonId}`, "A Taikoon", imageCID.toString()))
        )


        console.log(path.join(path.resolve(__dirname, '../../data'), 'metadata', `${taikoonId}.json`))
        metadataCIDs.push(metadataCID);
        for (let i = 0; i < imagesSummary.length; i ++) {
            if (imagesSummary[i].imageCID == imageCID) {
                imagesSummary[i].metadataCID = metadataCID
            }
        };
        //console.log(`Metadata with image CID ${imageCID} added to IPFS with CID of ${metadataCID}`);
    }
    console.log(` `);

    fs.writeFileSync(
        path.join(path.resolve(__dirname, '../../data'), 'metadata', 'summary.json'),
        JSON.stringify({imagesSummary})
    )


}

main()
