"use strict";
// An example configuration of a new Etna devnet L2: the default configuration on chain 167001,
// with the root-only EtnaSignalService and the EtnaStaking and bridged TAIKO predeploys. Generate
// it with `GENESIS_CONFIG=test/genesis/data/genesis_config_etna.js pnpm genesis:gen`.
const base = require("./genesis_config.js");

const CHAIN_ID = 167001;

// 7,812,500 TAIKO in base units, one minStake.
const PREMINT_PER_SEED_ACCOUNT = "7812500000000000000000000";

module.exports = Object.assign({}, base, {
  chainId: CHAIN_ID,
  // The EtnaSignalService's `usesBeaconRoots`, a boolean. A new Etna network must use true, so the
  // SignalService accepts no checkpoint after genesis and resolves proofs through EIP-4788 (Etna
  // SPEC START-10-5); script/layer2/build_etna_genesis.py refuses anything else.
  usesBeaconRoots: true,
  // The default configuration's addresses, on this chain id.
  contractAddresses: Object.getOwnPropertyDescriptor(
    base,
    "contractAddresses",
  ).get.call({ chainId: CHAIN_ID }),
  // The EtnaStaking predeploy's parameters, with every number a decimal string. The staking
  // token is the bridged TAIKO predeploy and the L1 chain id is `l1ChainId`.
  etna: {
    // The Etna Inbox proxy on L1; replace it with the deployed one.
    inbox: "0x00000000000000000000000000000000000100bb",
    // The TAIKO token on L1, which the L2 ERC20Vault maps to the bridged TAIKO predeploy.
    l1TaikoToken: "0x00000000000000000000000000000000000100cc",
    // The staking owner, the DAO's execution address on L2: on this devnet, the contract owner.
    stakingOwner: base.contractOwner,
    minStake: "7812500000000000000000000",
    vpUnit: "1000000000",
    nMax: "128",
    missLimit: "3600",
    missSlashBps: "1000",
    withdrawalDelay: "302402",
    // The Inbox's unsettledLimit and the double-sign evidence window, both in L2 blocks. Neither
    // is a staking parameter: withdrawalDelay must be at least their sum plus 2.
    unsettledLimit: "151200",
    evidenceWindowBlocks: "151200",
    slashBountyBps: "1000",
    slashSink: base.contractOwner,
    forfeitBps: "1000",
    // Allows the premint, which is L2 TAIKO that no L1 TAIKO backs. The generator refuses it on
    // chains 167000, 167009 and 167013.
    devnet: true,
    premint: base.seedAccounts.map((seedAccount) => ({
      [Object.keys(seedAccount)[0]]: PREMINT_PER_SEED_ACCOUNT,
    })),
  },
});
