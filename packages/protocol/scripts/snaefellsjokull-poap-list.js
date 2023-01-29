"use strict";
const ethers = require("ethers");
const fs = require("fs");

const L2_RPC_ENDPOINT = "https://l2rpc.a1.taiko.xyz";

const L2_BLOCK_START_HEIGHT = 0;
// 512862 timestamp: Thu, 05 Jan 2023 23:59:52 GMT
// 512863 timestamp: Fri, 06 Jan 2023 00:00:16 GMT
const L2_BLOCK_END_HEIGHT = 512862;

const GOLDEN_TOUCH_ADDRESS = "0x0000777735367b36bC9B61C50022d9D0700dB4Ec";
const L2_BRIDGE_ADDRESS = "0x0000777700000000000000000000000000000004";

// Any user with a bridging transaction + one other type of transaction (transfer, dapp tx)
const REASON_USED_BRIDGE = "REASON_USED_BRIDGE";
const REASON_USED_OTHER_TYPES_OF_TXS = "REASON_USED_OTHER_TYPES_OF_TXS";

const BATCH_SIZE = 5000;

class Account {
  constructor(address, reason) {
    this.address = address;
    this.reasons = [reason];
    this.txsCount = 1;
  }
}

class AccountsList {
  constructor() {
    this.accountList = [];
  }

  addAccountWithReason(address, reason) {
    const idx = this.accountList.findIndex(
      (account) => account.address === address
    );

    if (idx < 0) {
      this.accountList.push(new Account(address, reason));
      return;
    }

    this.accountList[idx].txsCount += 1;
    if (!this.accountList[idx].reasons.includes(reason)) {
      this.accountList[idx].reasons.push(reason);
    }
  }

  getEligibleAccounts() {
    return this.accountList
      .filter((account) => account.reasons.length >= 2)
      .sort((a, b) => {
        if (a.txsCount > b.txsCount) return -1;
        if (a.txsCount < b.txsCount) return 1;
        return 0;
      });
  }
}

async function main() {
  const l2Provider = new ethers.providers.JsonRpcBatchProvider(L2_RPC_ENDPOINT);
  const accountsList = new AccountsList();
  const bridgeInterface = new ethers.utils.Interface(
    require("../artifacts/contracts/bridge/Bridge.sol/Bridge.json").abi
  );

  const processMessageSelector = bridgeInterface.getSighash("processMessage");

  for (
    let i = L2_BLOCK_START_HEIGHT;
    i <= L2_BLOCK_END_HEIGHT;
    i += BATCH_SIZE
  ) {
    let batchEnd = i + BATCH_SIZE - 1;
    if (batchEnd > L2_BLOCK_END_HEIGHT) batchEnd = L2_BLOCK_END_HEIGHT;

    const batchBlockHeights = new Array(batchEnd - i + 1)
      .fill(0)
      .map((_, j) => i + j);

    await Promise.all(
      batchBlockHeights.map(async function (height) {
        console.log(`Block: ${height}`);

        const block = await l2Provider.getBlockWithTransactions(height);

        for (const tx of block.transactions) {
          if (tx.from === GOLDEN_TOUCH_ADDRESS) continue; // ignore those `TaikoL2.anchor` transactions
          const receipt = await l2Provider.getTransactionReceipt(tx.hash);
          if (receipt.status !== 1) continue;

          // Bridging transaction
          // we use `message.owner` to identify the actual user L2 account,
          // since `tx.from` is always the relayer account.
          if (
            tx.data &&
            tx.to === L2_BRIDGE_ADDRESS &&
            tx.data.startsWith(processMessageSelector)
          ) {
            const { message } = bridgeInterface.decodeFunctionData(
              "processMessage",
              tx.data
            );

            accountsList.addAccountWithReason(
              message.owner,
              REASON_USED_BRIDGE
            );
            continue;
          }

          // Other types of transaction (transfer, dapp tx)
          accountsList.addAccountWithReason(
            tx.from,
            REASON_USED_OTHER_TYPES_OF_TXS
          );
        }
      })
    );
  }

  const wallets = accountsList.getEligibleAccounts().map((account) => {
    return {
      address: account.address,
      txsCount: account.txsCount,
    };
  });

  console.log(
    `Accounts at least finished one task: ${accountsList.accountList.length}`
  );
  console.log(`Eligible accounts: ${wallets.length}`);

  fs.writeFileSync("./wallets.json", JSON.stringify({ wallets }));

  // eslint-disable-next-line no-process-exit
  process.exit(0);
}

main().catch(console.error);
