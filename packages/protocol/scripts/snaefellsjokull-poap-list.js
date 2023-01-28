"use strict";
const ethers = require("ethers");

const L2_RPC_ENDPOINT = "http://localhost:8080";
const L2_BLOCK_START_HEIGHT = 0;
const L2_BLOCK_END_HEIGHT = 1000; // TODO: change this value
const GOLDEN_TOUCH_ADDRESS = "0x0000777735367b36bC9B61C50022d9D0700dB4Ec";
const L2_BRIDGE_ADDRESS = "0x0000777700000000000000000000000000000004";

// Any user with a bridging transaction + one other type of transaction (transfer, dapp tx)
const REASON_USED_BRIDGE = "REASON_USED_BRIDGE";
const REASON_USED_OTHER_TYPES_OF_TXS = "REASON_USED_OTHER_TYPES_OF_TXS";

class Account {
  constructor(address, reason) {
    this.address = address;
    this.reasons = [reason];
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

    if (!this.accountList[idx].reasons.includes(reason)) {
      this.accountList[idx].reasons.push(reason);
    }
  }

  getEligibleAccounts() {
    return this.accountList.filter((account) => account.reasons.length >= 2);
  }
}

async function main() {
  const l2Provider = new ethers.providers.JsonRpcProvider(L2_RPC_ENDPOINT);
  const accountsList = new AccountsList();
  const bridgeInterface = new ethers.utils.Interface(
    require("../artifacts/contracts/bridge/Bridge.sol/Bridge.json").abi
  );

  const processMessageSelector = bridgeInterface.getSighash("processMessage");

  for (let i = L2_BLOCK_START_HEIGHT; i <= L2_BLOCK_END_HEIGHT; i++) {
    const block = await l2Provider.getBlockWithTransactions(i);

    for (const tx of block.transactions) {
      if (tx.from === GOLDEN_TOUCH_ADDRESS) continue; // ignore those `TaikoL2.anchor` transactions
      const receipt = await l2Provider.getTransactionReceipt(tx.hash);
      if (receipt.status !== 1) continue;

      // Bridging transaction
      if (
        tx.data &&
        tx.to === L2_BRIDGE_ADDRESS &&
        tx.data.startsWith(processMessageSelector)
      ) {
        const { message } = bridgeInterface.decodeFunctionData(
          "processMessage",
          tx.data
        );

        accountsList.addAccountWithReason(message.to, REASON_USED_BRIDGE);
        continue;
      }

      // Other types of transaction (transfer, dapp tx)
      accountsList.addAccountWithReason(
        tx.from,
        REASON_USED_OTHER_TYPES_OF_TXS
      );
    }
  }

  console.log(
    `Eligible accounts: ${accountsList.getEligibleAccounts().length}`
  );
}

main().catch(console.error);
