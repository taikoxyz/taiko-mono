import { BigNumber, Contract, ethers } from "ethers";

const MESSAGE_TUPLE =
  "tuple(uint64 id,uint64 fee,uint32 gasLimit,address from,uint64 srcChainId,address srcOwner,uint64 destChainId,address destOwner,address to,uint256 value,bytes data)";

const BRIDGE_ABI = [
  `event MessageSent(bytes32 indexed msgHash, ${MESSAGE_TUPLE} message)`,
  `function sendMessage(${MESSAGE_TUPLE} _message) payable returns (bytes32 msgHash, ${MESSAGE_TUPLE} message)`,
  "function getMessageMinGasLimit(uint256 dataLength) pure returns (uint32)",
];

const INVOCABLE_ABI = ["function onMessageInvocation(bytes data)"];

// Creation code for runtime bytecode 0x60006000fd: always revert.
const REVERTER_CREATION_CODE = "0x6005600c60003960056000f360006000fd";

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

function printHelp() {
  console.log(`
Usage:
  SRC_RPC=<source rpc> DEST_RPC=<destination rpc> SRC_BRIDGE=<source bridge> \\
  PRIVATE_KEY=<sender private key> \\
  pnpm exec ts-node --transpile-only --compiler-options '{"module":"CommonJS","moduleResolution":"Node"}' \\
  script/shared/CreateRetriableMessage.ts

Required:
  SRC_RPC           Source chain RPC URL.
  DEST_RPC          Destination chain RPC URL. Used to deploy the default reverting receiver and infer chain ID.
  SRC_BRIDGE        Bridge address on the source chain. BRIDGE is also accepted.
  PRIVATE_KEY       Sender private key. The same key deploys the default reverting receiver on destination.

Optional:
  TO                Existing destination target. If omitted, an always-revert contract is deployed.
  DEST_CHAIN_ID     Destination chain ID. Defaults to DEST_RPC chain ID.
  SRC_OWNER         Defaults to sender address.
  DEST_OWNER        Defaults to sender address.
  FEE               Defaults to 0.
  VALUE             Defaults to 0.
  GAS_LIMIT         Defaults to Bridge.getMessageMinGasLimit(data.length) + 50000.
  DATA              Defaults to the onMessageInvocation(bytes) selector.

Output:
  The script prints the source sendMessage transaction hash as SRC_TX_HASH for ProcessBridgeMessage.ts.
`);
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}

function optionalAddress(name: string, defaultValue: string): string {
  const value = process.env[name] ?? defaultValue;
  return ethers.utils.getAddress(value);
}

function envBigNumber(name: string, defaultValue: string): BigNumber {
  return BigNumber.from(process.env[name] ?? defaultValue);
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

function envBool(name: string, defaultValue: boolean): boolean {
  const value = process.env[name];
  if (value === undefined) return defaultValue;
  return ["1", "true", "yes", "y"].includes(value.toLowerCase());
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

async function deployRevertingReceiver(wallet: ethers.Wallet): Promise<string> {
  const tx = await wallet.sendTransaction({ data: REVERTER_CREATION_CODE });
  console.log(stableJson({ deployRevertingReceiverTx: tx.hash }));
  const receipt = await tx.wait();
  if (!receipt.contractAddress) throw new Error("Receiver deployment did not return a contract address");
  return ethers.utils.getAddress(receipt.contractAddress);
}

async function main() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    printHelp();
    return;
  }

  const srcProvider = new ethers.providers.JsonRpcProvider(requiredEnv("SRC_RPC"));
  const destProvider = new ethers.providers.JsonRpcProvider(requiredEnv("DEST_RPC"));
  const privateKey = requiredEnv("PRIVATE_KEY");
  const srcWallet = new ethers.Wallet(privateKey, srcProvider);
  const destWallet = new ethers.Wallet(privateKey, destProvider);
  const srcBridgeAddress = ethers.utils.getAddress(process.env.SRC_BRIDGE ?? requiredEnv("BRIDGE"));
  const bridge = new Contract(srcBridgeAddress, BRIDGE_ABI, srcWallet);
  const data =
    process.env.DATA ??
    new ethers.utils.Interface(INVOCABLE_ABI).getSighash("onMessageInvocation");
  const to = process.env.TO ? ethers.utils.getAddress(process.env.TO) : await deployRevertingReceiver(destWallet);
  const destChainId = BigNumber.from(
    process.env.DEST_CHAIN_ID ?? (await destProvider.getNetwork()).chainId,
  );
  const fee = envBigNumber("FEE", "0");
  const value = envBigNumber("VALUE", "0");
  const minGasLimit = BigNumber.from(await bridge.getMessageMinGasLimit(ethers.utils.arrayify(data).length));
  const gasLimit = envNumber("GAS_LIMIT") ?? minGasLimit.add(50_000).toNumber();

  const message: BridgeMessage = {
    id: BigNumber.from(0),
    fee,
    gasLimit,
    from: ethers.constants.AddressZero,
    srcChainId: BigNumber.from(0),
    srcOwner: optionalAddress("SRC_OWNER", srcWallet.address),
    destChainId,
    destOwner: optionalAddress("DEST_OWNER", srcWallet.address),
    to,
    value,
    data,
  };

  if (!envBool("SEND", true)) {
    console.log(stableJson({ srcBridge: srcBridgeAddress, message }));
    return;
  }

  const tx = await bridge.sendMessage(messageToTuple(message), { value: value.add(fee) });
  console.log(stableJson({ sendMessageTx: tx.hash }));
  const receipt = await tx.wait();
  const bridgeInterface = new ethers.utils.Interface(BRIDGE_ABI);
  const topic = bridgeInterface.getEventTopic("MessageSent");
  const messageLog = receipt.logs.find(
    (log: ethers.providers.Log) =>
      log.address.toLowerCase() === srcBridgeAddress.toLowerCase() && log.topics[0] === topic,
  );

  if (!messageLog) throw new Error("MessageSent log not found in sendMessage receipt");

  const parsed = bridgeInterface.parseLog(messageLog);
  const sentMessage = toMessage(parsed.args.message);
  console.log(
    stableJson({
      SRC_TX_HASH: receipt.transactionHash,
      msgHash: parsed.args.msgHash,
      srcBridge: srcBridgeAddress,
      revertingReceiver: to,
      message: sentMessage,
    }),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
