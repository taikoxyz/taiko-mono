const { createPublicClient, http } = require("viem");
const { taiko } = require("viem/chains");
const TrailblazersBadges = require('../../../out/TrailblazersBadges.sol/TrailblazersBadges.json');
const MainnetDeployment = require('../../../deployments/trailblazers-badges/mainnet.json');
const { writeFileSync, readFileSync } = require('fs');
const path = require('path')
const publicClient = createPublicClient({
    chain: taiko,
   transport: http("https://rpc.mainnet.taiko.xyz"),
  });


async function getBadgesForBlockRange(
    startBlock,
    endBlock
) {
    console.log(`Fetching badges for block range ${startBlock} - ${endBlock}`)
const logs = await publicClient.getContractEvents({
        address: MainnetDeployment.TrailblazersBadges,
    abi: TrailblazersBadges.abi,
    eventName: 'BadgeCreated',
    //fromBlock: 0n,
  //  fromBlock: 53886n,
  fromBlock: BigInt(startBlock),
  toBlock: BigInt(endBlock)
    /*args: {
        _badgeId: 0n
    }*/
  })

  return logs
}



const historyMeterFile = path.join(__dirname, '../../../badges-report.json')

async function main(){
    let historyMeter = {
        startBlock: 53886,
        endBlock: 53886,
        badges: {
            Ravers: 0,
            Robots: 0,
            Bouncers: 0,
            Masters: 0,
            Monks: 0,
            Drummers: 0,
            Androids: 0,
            Shinto: 0,
        }
    }
    try {
    historyMeter = JSON.parse(readFileSync(historyMeterFile, 'utf-8'))
    } catch (e){
        console.log('No history meter file found, starting from scratch')
        writeFileSync(historyMeterFile, JSON.stringify(historyMeter, null, 2))
    }
    console.log(historyMeter)
    const currentBlockNumber = await publicClient.getBlockNumber();
    console.log(`Current block number: ${currentBlockNumber}`)
    const percentComplete = (historyMeter.endBlock - historyMeter.startBlock) / (parseInt(currentBlockNumber.toString()) - historyMeter.startBlock) * 100
    console.log(`Percent complete: ${percentComplete}%`)


    const badgeNames = Object.keys(historyMeter.badges)

    const blockStep = 500


    if (currentBlockNumber > historyMeter.endBlock) {
        // new data, fetch time

        const logs = await getBadgesForBlockRange(
            historyMeter.endBlock,
            historyMeter.endBlock + blockStep)


        if (logs.length > 0){
            // assign badge counts
            for (const log of logs) {
                const badgeId = parseInt(log.args._badgeId.toString())
                historyMeter.badges[
                    badgeNames[badgeId]
                ] += 1
            }
        }

        historyMeter.endBlock = historyMeter.endBlock + blockStep
        writeFileSync(historyMeterFile, JSON.stringify(historyMeter, null, 2))

        return main()
    } else {
        console.log('Report up to date')
        console.log(historyMeter)
    }

}


main()
