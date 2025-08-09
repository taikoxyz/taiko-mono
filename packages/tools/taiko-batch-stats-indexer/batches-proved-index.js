// batches-proved-index.js
import { JsonRpcProvider, Contract, Interface } from "ethers";
import fs from "fs/promises";
import path from "path";
import { networks } from "./networks.js";
import { getLastScannedBlock, getL1TxFee } from "./utils.js";
import { createClient } from '@supabase/supabase-js';


const TAIKO_L1_ABI = [
  "event BatchesProved(address verifier, uint64[] batchIds, tuple(bytes32 parentHash, bytes32 postStateRoot, bytes32 withdrawRoot)[] transitions)"
];

const BOND_CREDITED_ABI = [
  "event BondCredited(address indexed user, uint256 amount)"
];
const bondCreditedInterface = new Interface(BOND_CREDITED_ABI);

// Create a single supabase client for interacting with your database
const supabaseUrl = 'https://qmjtymqzhjdkqolqwzbn.supabase.co';
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);


(async () => {
  for (const net of networks) {
    const { name, chainId, rpcUrlL1, rpcUrlL2, taikoL1Address, fromBlock, toBlock } = net;
    const providerL1 = new JsonRpcProvider(rpcUrlL1, chainId);
    const providerL2 = new JsonRpcProvider(rpcUrlL2);

    const latestBlock2 = await providerL2.getBlockNumber();
    const block = await providerL2.getBlock(latestBlock2 - 10); // warm up
    console.log(`Connected to L2 at block ${latestBlock2}, sample block ${block.number} timestamp ${block.timestamp}`);

    const latestBlock = await providerL1.getBlockNumber();
    const finalBlock = toBlock === "latest" ? latestBlock : Number(toBlock);

    const outputDir = path.join("data", name.replace(/\s+/g, "_"), "BatchProposed");
    await fs.mkdir(outputDir, { recursive: true });

    let startBlock = fromBlock || 0;

    const { data, error } = await supabase
      .from('batches_proved')
      .select('block_number')
      .order('block_number', { ascending: false })
      .limit(1);
    const maxBlock = data?.[0]?.block_number;
    startBlock = Math.max(startBlock, (maxBlock || 0) - 10);

    console.log(`\n=== ${name} ===`);
    console.log(`Fetching blocks from ${startBlock} to ${finalBlock}...`);

    const contract = new Contract(taikoL1Address, TAIKO_L1_ABI, providerL1);

    const allChunkSize = 1000;

    while (startBlock <= finalBlock) {
      const currentEnd = Math.min(startBlock + allChunkSize - 1, finalBlock);
      console.log(`Scanning BatchesProved [${startBlock}, ${currentEnd}]`);
      const provenEvents = await contract.queryFilter(contract.filters.BatchesProved(), startBlock, currentEnd);
      for (const evt of provenEvents) {
        // console.log(evt);
        const tx = await providerL1.getTransaction(evt.transactionHash);
        const from = tx.from;
        // console.log(tx);

        const { l1Rceipt: proverL1Rceipt, l1FeeEth: proverTxL1FeeEth } = await getL1TxFee(providerL1, evt.transactionHash);

        // Prover bond credited logs
        const proverL1TransactionReceipt = await providerL1.getTransactionReceipt(evt.transactionHash);
        let actualProver = null;
        let bondCreditedAmount = 0;
        for (const log of proverL1TransactionReceipt.logs) {    
          try {
            const parsed = bondCreditedInterface.parseLog(log);
            if (parsed.name === "BondCredited") {
              const { user, amount } = parsed.args;
              console.log(`BondCredited - user: ${user}, amount: ${amount.toString()}`);
              bondCreditedAmount += Number(amount) / 1e18;
  
              if (actualProver === null) {
                actualProver = user;
              } else if (actualProver.toLowerCase() !== user.toLowerCase()) {
                throw new Error(`❌ Multiple users found in BondCredited logs: ${actualProver} and ${user}`);
              }
            }
          } catch {}
        }

        const batchIds = evt.args.batchIds.map((id) => Number(id));

        for (const batchId of batchIds) {
          console.log(`Inserting batchId ${batchId}, prover ${from}, tx ${evt.transactionHash}`);

          const { error } = await supabase
            .from('batches_proved')
            .upsert({
              batch_id: batchId,
              tx_hash: evt.transactionHash,
              tx_from: from,
              block_number: evt.blockNumber,
              tx_l1_fee_eth: proverTxL1FeeEth / batchIds.length,
              prover: actualProver,
              bond_credited_amount: bondCreditedAmount / batchIds.length,
            }, { onConflict: 'batch_id,tx_hash' });

          if (error) {
            throw new Error(`Supabase upsert error for batch ${batchId}: ${error.message}`);
          }
        }
      }
      startBlock = currentEnd + 1;
    }
  }
})();
