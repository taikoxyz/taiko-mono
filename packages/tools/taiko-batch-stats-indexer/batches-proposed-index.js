// index.js
import { JsonRpcProvider, Contract, Interface } from "ethers";
import fs from "fs/promises";
import path from "path";
import { networks } from "./networks.js";
import { getLastScannedBlock, getL1TxFee } from "./utils.js";
import { createClient } from '@supabase/supabase-js';

const TAIKO_L1_ABI = [
  "event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)),(bytes32,address,uint64,uint64),bytes)",
];

const BOND_DEBITED_ABI = [
  "event BondDebited(address indexed user, uint256 amount)"
];
const bondDebitedInterface = new Interface(BOND_DEBITED_ABI);

// Create a single supabase client for interacting with your database
const supabaseUrl = process.env.SUPABASE_URL;
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

    const chunkSize = 1000;

    const outputDir = path.join("data", name.replace(/\s+/g, "_"), "BatchProposed");
    await fs.mkdir(outputDir, { recursive: true });

    let startBlock = fromBlock || 0;

    const { data, error } = await supabase
      .from('batches_proposed')
      .select('block_number')
      .order('block_number', { ascending: false })
      .limit(1);
    const maxBlock = data?.[0]?.block_number;
    startBlock = Math.max(startBlock, (maxBlock || 0) - 10);

    console.log(`\n=== ${name} ===`);
    console.log(`Fetching blocks from ${startBlock} to ${finalBlock}...`);

    const contract = new Contract(taikoL1Address, TAIKO_L1_ABI, providerL1);

    while (startBlock <= finalBlock) {
      const chunkEnd = Math.min(startBlock + chunkSize - 1, finalBlock);
      console.log(`Processing chunk: [${startBlock}, ${chunkEnd}]`);

      const proposedEvents = await contract.queryFilter(contract.filters.BatchProposed(), startBlock, chunkEnd);
      console.log(`Found ${proposedEvents.length} proposed events.`);

      for (const evt of proposedEvents) {
        const info = evt.args[0];
        const meta = evt.args[1];

        const assignedProverInProposedTx = meta[1];
        const batchId = Number(meta[2]);
        const timestamp = Number(meta[3]);

        // Proposer info from L1 tx
        const tx = await providerL1.getTransaction(evt.transactionHash);
        const from = tx.from;
        const proposer = from;
        const { l1Rceipt: proposerL1Rceipt, l1FeeEth: proposerL1FeeEth } = await getL1TxFee(providerL1, evt.transactionHash);

        const proposedL1TransactionReceipt = await providerL1.getTransactionReceipt(evt.transactionHash);
        let debitedUser = null;
        let bondDebitedAmount = 0;
        for (const log of proposedL1TransactionReceipt.logs) {
          try {
            const parsed = bondDebitedInterface.parseLog(log);
            if (parsed.name === "BondDebited") {
              const { user, amount } = parsed.args;
              console.log(`BondDebited - user: ${user}, amount: ${amount.toString()}`);
              bondDebitedAmount += Number(amount) / 1e18;

              if (debitedUser === null) {
                debitedUser = user;
              } else if (debitedUser.toLowerCase() !== user.toLowerCase()) {
                throw new Error(`❌ Multiple BondDebited users found: ${debitedUser} and ${user}`);
              }
            }
          } catch {}
        }

        // base fee configuration
        const l2BaseFeeConfig = info[14];
        const l2BaseFee = {
          gasTarget: Number(l2BaseFeeConfig[0]),
          baseFeeMaxChangeDenominator: Number(l2BaseFeeConfig[1]),
          minBaseFee: Number(l2BaseFeeConfig[2]),
          targetResourceLimit: Number(l2BaseFeeConfig[3]),
          resourceLimitMultiplier: Number(l2BaseFeeConfig[4])
        };

        const blockParams = info[1].map((b, i) => ({
          index: i,
          numTransactions: Number(b[0]),
          timeShift: Number(b[1]),
          signalSlots: b[2]
        }));

        const lastBlockId = Number(info[10]);
        const anchorBlockId = Number(info[12]);
        console.log(`anchorBlockId: ${anchorBlockId}, batchId: ${batchId}, lastBlockId: ${lastBlockId}, number of blocks: ${blockParams.length}`);

        let l2TotalTips = 0;
        let l2TotalBaseFees = 0;
        let l2TxCount = 0;

        const blockCount = blockParams.length;
        const firstBlockId = lastBlockId - blockCount + 1;
        for (let i = 0; i < blockCount; i++) {
          const blockId = firstBlockId + i;

          const l2Block = await providerL2.getBlock(Number(blockId));
          l2TxCount = l2Block.transactions.length;
          console.log(`Fetching L2 block ${blockId}, number of transactions ${l2Block.transactions.length} for batch ${batchId}...`);

          const receipts = await providerL2.send("eth_getBlockReceipts", [l2Block.hash]);
          const baseFeePerGas = BigInt(l2Block.baseFeePerGas.toString());
          const blockBasedFee = BigInt(l2Block.gasUsed.toString()) * baseFeePerGas;

          for (const receipt of receipts) {
            const gasUsed = BigInt(receipt.gasUsed);
            const gasPrice = receipt.effectiveGasPrice ? BigInt(receipt.effectiveGasPrice) : BigInt(0); // fallback if field is missing
            const tip = gasPrice > baseFeePerGas ? (gasPrice - baseFeePerGas) * gasUsed : BigInt(0);
            const base = baseFeePerGas * gasUsed;
        
            l2TotalTips += Number(tip) / 1e18;
            l2TotalBaseFees += Number(base) / 1e18;
          }          
          console.log(`Tx Block ${blockId} cumulative tips so far: ${l2TotalTips} ETH, base fees: ${l2TotalBaseFees} ETH, l2TxCount: ${l2TxCount}`);
        }

        const { error } = await supabase
          .from('batches_proposed')
          .upsert({
            batch_id: batchId,
            timestamp: timestamp,
            last_block_id: lastBlockId,
            anchor_block_id: anchorBlockId,
            block_count: blockParams.length,
            l2_tx_count: l2TxCount,
            block_number: evt.blockNumber,
            tx_hash: evt.transactionHash,
            proposer: proposer,
            tx_l1_fee_eth: proposerL1FeeEth,
            assigned_proposer: assignedProverInProposedTx,
            debited_user: debitedUser,
            bond_debited_amount: bondDebitedAmount,
            l2_total_tips_eth: l2TotalTips,
            l2_total_base_fees_eth: l2TotalBaseFees,
            l2_base_fee_gas_target: l2BaseFee.gasTarget,
            l2_base_fee_base_fee_max_change_denominator: l2BaseFee.baseFeeMaxChangeDenominator,
            l2_base_fee_min_base_fee: l2BaseFee.minBaseFee,
            l2_base_fee_target_resource_limit: l2BaseFee.targetResourceLimit,
            l2_base_fee_resource_limit_multiplier: l2BaseFee.resourceLimitMultiplier,
          }, {
            onConflict: 'batch_id,tx_hash'
          });

          if (error) {
            throw new Error(`Supabase upsert error for batch ${batchId}: ${error.message}`);
          }
      }
      startBlock = chunkEnd + 1;
    }
  }
})();
