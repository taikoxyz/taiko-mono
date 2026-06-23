import { BigNumber, BigNumberish, Contract, ethers } from "ethers";

const MESSAGE_TUPLE =
  "tuple(uint64 id,uint64 fee,uint32 gasLimit,address from,uint64 srcChainId,address srcOwner,uint64 destChainId,address destOwner,address to,uint256 value,bytes data)";

const BRIDGE_ABI = [
  `event MessageSent(bytes32 indexed msgHash, ${MESSAGE_TUPLE} message)`,
  `function hashMessage(${MESSAGE_TUPLE} _message) pure returns (bytes32)`,
  `function processMessage(${MESSAGE_TUPLE} _message, bytes _proof) returns (uint8 status, uint8 reason)`,
  "function signalService() view returns (address)",
];

const SIGNAL_SERVICE_ABI = [
  "function getCheckpoint(uint48 _blockNumber) view returns (tuple(uint48 blockNumber,bytes32 blockHash,bytes32 stateRoot) checkpoint)",
];

const HOP_PROOF_TUPLE =
  "tuple(uint64 chainId,uint64 blockId,bytes32 rootHash,uint8 cacheOption,bytes[] accountProof,bytes[] storageProof)[]";

type BridgeMessage = {
  id: BigNumber;
  fee: BigNumber;
  gasLimit: number;
  from: string;
  srcChainId: BigNumber;
  srcOwner: string;
  destChainId: BigNumber;
  destOwner: string;
  to: string;
  value: BigNumber;
  data: string;
};

type ProofBlock = {
  number: string;
  hash: string;
  stateRoot: string;
};

type EthGetProof = {
  accountProof: string[];
  storageProof: Array<{
    key: string;
    value: string;
    proof: string[];
  }>;
};

function printHelp() {
  console.log(`
Usage:
  SRC_RPC=<source rpc> DEST_RPC=<destination rpc> \\
  SRC_TX_HASH=<source sendMessage tx hash> DEST_BRIDGE=<destination bridge> \\
  PRIVATE_KEY=<processor private key> \\
  pnpm exec ts-node --transpile-only --compiler-options '{"module":"CommonJS","moduleResolution":"Node"}' \\
  script/shared/ProcessBridgeMessage.ts

Required:
  SRC_RPC                 Source chain RPC URL.
  DEST_RPC                Destination chain RPC URL.
  SRC_TX_HASH             Source chain transaction hash containing MessageSent.
  DEST_BRIDGE             Bridge address on the destination chain.
  PRIVATE_KEY             Required when SEND is not false.

Optional:
  SRC_BRIDGE              Filter MessageSent logs by source Bridge address.
  SRC_SIGNAL_SERVICE      Override source SignalService address.
  DEST_SIGNAL_SERVICE     Override destination SignalService address.
  MESSAGE_INDEX           Pick the nth MessageSent log after filtering. Defaults to 0 only if unique.
  MESSAGE_LOG_INDEX       Pick the receipt logIndex directly.
  PROOF_BLOCK_NUMBER      Source block number for eth_getProof. Defaults to the tx block.
  SEND                    true by default. Set false to only print message/proof.
  SKIP_CHECKPOINT_CHECK   false by default. Set true to skip destination checkpoint validation.
  SKIP_CALLSTATIC         false by default. Set true to send without callStatic.
  TX_GAS_LIMIT            Optional gas limit override for processMessage.

Notes:
  PROOF_BLOCK_NUMBER must be >= the MessageSent block and its source state root must already be
  saved in the destination SignalService checkpoint store.
`);
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}

function envBool(name: string, defaultValue: boolean): boolean {
  const value = process.env[name];
  if (value === undefined) return defaultValue;
  return ["1", "true", "yes", "y"].includes(value.toLowerCase());
}

function envNumber(name: string): number | undefined {
  const value = process.env[name];
  if (value === undefined || value === "") return undefined;
  const numberValue = Number(value);
  if (!Number.isSafeInteger(numberValue) || numberValue < 0) {
    throw new Error(`${name} must be a non-negative safe integer`);
  }
  return numberValue;
}

function toMessage(raw: ethers.utils.Result): BridgeMessage {
  return {
    id: BigNumber.from(raw.id ?? raw[0]),
    fee: BigNumber.from(raw.fee ?? raw[1]),
    gasLimit: BigNumber.from(raw.gasLimit ?? raw[2]).toNumber(),
    from: ethers.utils.getAddress(raw.from ?? raw[3]),
    srcChainId: BigNumber.from(raw.srcChainId ?? raw[4]),
    srcOwner: ethers.utils.getAddress(raw.srcOwner ?? raw[5]),
    destChainId: BigNumber.from(raw.destChainId ?? raw[6]),
    destOwner: ethers.utils.getAddress(raw.destOwner ?? raw[7]),
    to: ethers.utils.getAddress(raw.to ?? raw[8]),
    value: BigNumber.from(raw.value ?? raw[9]),
    data: raw.data ?? raw[10],
  };
}

function messageToTuple(message: BridgeMessage): unknown[] {
  return [
    message.id,
    message.fee,
    message.gasLimit,
    message.from,
    message.srcChainId,
    message.srcOwner,
    message.destChainId,
    message.destOwner,
    message.to,
    message.value,
    message.data,
  ];
}

function stableJson(value: unknown): string {
  return JSON.stringify(
    value,
    (_key, item) => {
      if (BigNumber.isBigNumber(item)) return item.toString();
      return item;
    },
    2,
  );
}

function getSignalSlot(chainId: BigNumberish, app: string, signal: string): string {
  return ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["string", "uint64", "address", "bytes32"],
      ["SIGNAL", chainId, app, signal],
    ),
  );
}

function blockTag(blockNumber: number): string {
  return ethers.utils.hexValue(blockNumber);
}

async function getBlock(provider: ethers.providers.JsonRpcProvider, blockNumber: number): Promise<ProofBlock> {
  const block = (await provider.send("eth_getBlockByNumber", [blockTag(blockNumber), false])) as ProofBlock;
  if (!block?.stateRoot || !block.hash) {
    throw new Error(`Source RPC did not return stateRoot for block ${blockNumber}`);
  }
  return block;
}

async function getSignalService(
  provider: ethers.providers.JsonRpcProvider,
  bridgeAddress: string,
  override: string | undefined,
): Promise<string> {
  if (override) return ethers.utils.getAddress(override);
  const bridge = new Contract(bridgeAddress, BRIDGE_ABI, provider);
  return ethers.utils.getAddress(await bridge.signalService());
}

async function validateCheckpoint(
  provider: ethers.providers.JsonRpcProvider,
  signalService: string,
  proofBlockNumber: number,
  sourceStateRoot: string,
) {
  const contract = new Contract(signalService, SIGNAL_SERVICE_ABI, provider);
  const checkpoint = await contract.getCheckpoint(proofBlockNumber);
  const checkpointRoot = String(checkpoint.stateRoot).toLowerCase();
  if (checkpointRoot !== sourceStateRoot.toLowerCase()) {
    throw new Error(
      [
        `Destination checkpoint stateRoot mismatch for source block ${proofBlockNumber}.`,
        `checkpoint.stateRoot=${checkpoint.stateRoot}`,
        `source.stateRoot=${sourceStateRoot}`,
        "Pick another PROOF_BLOCK_NUMBER that has been synced to the destination chain.",
      ].join("\n"),
    );
  }
}

async function main() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    printHelp();
    return;
  }

  const send = envBool("SEND", true);
  const srcProvider = new ethers.providers.JsonRpcProvider(requiredEnv("SRC_RPC"));
  const destProvider = new ethers.providers.JsonRpcProvider(requiredEnv("DEST_RPC"));
  const srcTxHash = requiredEnv("SRC_TX_HASH");
  const destBridgeAddress = ethers.utils.getAddress(requiredEnv("DEST_BRIDGE"));
  const privateKey = process.env.PRIVATE_KEY;

  if (send && !privateKey) {
    throw new Error("PRIVATE_KEY is required when SEND is true");
  }

  const bridgeInterface = new ethers.utils.Interface(BRIDGE_ABI);
  const messageSentTopic = bridgeInterface.getEventTopic("MessageSent");
  const receipt = await srcProvider.getTransactionReceipt(srcTxHash);
  if (!receipt) throw new Error(`Transaction receipt not found: ${srcTxHash}`);

  const srcBridgeFilter = process.env.SRC_BRIDGE
    ? ethers.utils.getAddress(process.env.SRC_BRIDGE).toLowerCase()
    : undefined;

  const logs = receipt.logs.filter((log) => {
    if (log.topics[0] !== messageSentTopic) return false;
    if (srcBridgeFilter && log.address.toLowerCase() !== srcBridgeFilter) return false;
    return true;
  });

  if (logs.length === 0) {
    throw new Error("No MessageSent logs found in SRC_TX_HASH");
  }

  const requestedLogIndex = envNumber("MESSAGE_LOG_INDEX");
  const requestedMessageIndex = envNumber("MESSAGE_INDEX");
  let selectedLog = logs[0];

  if (requestedLogIndex !== undefined) {
    const match = logs.find((log) => log.logIndex === requestedLogIndex);
    if (!match) throw new Error(`No filtered MessageSent log has logIndex=${requestedLogIndex}`);
    selectedLog = match;
  } else if (requestedMessageIndex !== undefined) {
    selectedLog = logs[requestedMessageIndex];
    if (!selectedLog) throw new Error(`MESSAGE_INDEX ${requestedMessageIndex} is out of range`);
  } else if (logs.length !== 1) {
    console.error(
      stableJson({
        messageSentLogs: logs.map((log, index) => ({
          index,
          logIndex: log.logIndex,
          address: log.address,
          transactionHash: log.transactionHash,
        })),
      }),
    );
    throw new Error("Multiple MessageSent logs found. Set MESSAGE_INDEX or MESSAGE_LOG_INDEX.");
  }

  const parsed = bridgeInterface.parseLog(selectedLog);
  const msgHash = parsed.args.msgHash as string;
  const message = toMessage(parsed.args.message);
  const srcBridgeAddress = ethers.utils.getAddress(selectedLog.address);
  const proofBlockNumber = envNumber("PROOF_BLOCK_NUMBER") ?? receipt.blockNumber;

  if (proofBlockNumber < receipt.blockNumber) {
    throw new Error(
      `PROOF_BLOCK_NUMBER ${proofBlockNumber} must be >= MessageSent block ${receipt.blockNumber}`,
    );
  }

  const srcSignalService = await getSignalService(
    srcProvider,
    srcBridgeAddress,
    process.env.SRC_SIGNAL_SERVICE,
  );
  const destSignalService = await getSignalService(
    destProvider,
    destBridgeAddress,
    process.env.DEST_SIGNAL_SERVICE,
  );
  const sourceBlock = await getBlock(srcProvider, proofBlockNumber);

  if (!envBool("SKIP_CHECKPOINT_CHECK", false)) {
    await validateCheckpoint(destProvider, destSignalService, proofBlockNumber, sourceBlock.stateRoot);
  }

  const signalSlot = getSignalSlot(message.srcChainId, srcBridgeAddress, msgHash);
  const rawProof = (await srcProvider.send("eth_getProof", [
    srcSignalService,
    [signalSlot],
    blockTag(proofBlockNumber),
  ])) as EthGetProof;

  const storageProof = rawProof.storageProof?.[0];
  if (!rawProof.accountProof?.length || !storageProof?.proof?.length) {
    throw new Error("eth_getProof returned an empty accountProof or storageProof");
  }
  if (BigNumber.from(storageProof.value).isZero()) {
    throw new Error(
      `Signal slot value is zero at block ${proofBlockNumber}; choose a block after MessageSent was persisted`,
    );
  }

  const encodedProof = ethers.utils.defaultAbiCoder.encode(
    [HOP_PROOF_TUPLE],
    [
      [
        [
          message.destChainId,
          proofBlockNumber,
          sourceBlock.stateRoot,
          0,
          rawProof.accountProof,
          storageProof.proof,
        ],
      ],
    ],
  );

  const normalizedMessageHash = await new Contract(destBridgeAddress, BRIDGE_ABI, destProvider).hashMessage(
    messageToTuple(message),
  );
  if (normalizedMessageHash.toLowerCase() !== msgHash.toLowerCase()) {
    throw new Error(
      `Parsed message hash mismatch: event=${msgHash}, recomputed=${normalizedMessageHash}`,
    );
  }

  console.log(
    stableJson({
      srcTxHash,
      srcBridge: srcBridgeAddress,
      srcSignalService,
      destBridge: destBridgeAddress,
      destSignalService,
      messageLogIndex: selectedLog.logIndex,
      messageBlockNumber: receipt.blockNumber,
      proofBlockNumber,
      proofBlockHash: sourceBlock.hash,
      proofStateRoot: sourceBlock.stateRoot,
      msgHash,
      signalSlot,
      message,
      proof: encodedProof,
    }),
  );

  if (!send) return;

  const signer = new ethers.Wallet(privateKey as string, destProvider);
  const destBridge = new Contract(destBridgeAddress, BRIDGE_ABI, signer);
  const overrides: ethers.PayableOverrides = {};
  const txGasLimit = envNumber("TX_GAS_LIMIT");
  if (txGasLimit !== undefined) overrides.gasLimit = txGasLimit;

  if (!envBool("SKIP_CALLSTATIC", false)) {
    const [status, reason] = await destBridge.callStatic.processMessage(
      messageToTuple(message),
      encodedProof,
      overrides,
    );
    console.log(stableJson({ callStatic: { status, reason } }));
  }

  const tx = await destBridge.processMessage(messageToTuple(message), encodedProof, overrides);
  console.log(stableJson({ txHash: tx.hash }));
  const destReceipt = await tx.wait();
  console.log(stableJson({ status: destReceipt.status, blockNumber: destReceipt.blockNumber }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
