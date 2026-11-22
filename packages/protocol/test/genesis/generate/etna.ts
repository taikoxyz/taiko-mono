import { ethers } from "ethers";
import { Config, Result } from "./interface";
import { getImmutableReference, replaceImmutableValues } from "./taikoAnchor";
const path = require("path");
const { computeStorageSlots, getStorageLayout } = require("./utils");
const ARTIFACTS_PATH = path.join(__dirname, "../../../out/layer2");

const { BigNumber } = ethers;

const IMPLEMENTATION_SLOT =
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// The bounds EtnaStaking's constructor enforces; a predeploy runs no constructor, so the generator
// enforces them instead.
const TAIKO_SUPPLY = BigNumber.from(10).pow(27);
const MAX_SEATS = 128;
const MIN_VP_UNIT = 867_361_738;
const BPS = 10_000;
const MAX_MISS_LIMIT = 65_535;
const DELAY_BOUND = BigNumber.from(2).pow(48);
// The Inbox's bound on its unsettledLimit.
const MAX_UNSETTLED_LIMIT = 262_144;
// The public Taiko networks, which must never hold the devnet premint's unbacked TAIKO.
const PUBLIC_CHAIN_IDS = [167000, 167009, 167013];

// The twelve EtnaStaking immutables, in constructor order.
const STAKING_IMMUTABLES = [
    "token",
    "l1ChainId",
    "inbox",
    "minStake",
    "vpUnit",
    "nMax",
    "missLimit",
    "missSlashBps",
    "withdrawalDelay",
    "slashBountyBps",
    "slashSink",
    "forfeitBps",
];

// BridgedTaikoToken slots that its `init` and `_mint` write but no variable name reaches: the
// EIP-712 `_name` and `_version` (the ERC-20 `_name` comes first under the same name), and the
// ERC20Votes `_totalSupplyCheckpoints` array. Without the checkpoint, burning preminted TAIKO
// underflows; without the EIP-712 name and version, permits sign over an empty domain name.
const EIP712_NAME_SLOT = 353;
const EIP712_VERSION_SLOT = 354;
const TOTAL_SUPPLY_CHECKPOINTS_SLOT = 456;

const TOKEN_NAME = "Taiko Token";
const TOKEN_SYMBOL = "TAIKO";

// The Etna block of the configuration, checked and parsed.
interface EtnaParams {
    inbox: string;
    l1TaikoToken: string;
    stakingOwner: string;
    slashSink: string;
    minStake: ethers.BigNumber;
    vpUnit: ethers.BigNumber;
    nMax: ethers.BigNumber;
    missLimit: ethers.BigNumber;
    missSlashBps: ethers.BigNumber;
    withdrawalDelay: ethers.BigNumber;
    slashBountyBps: ethers.BigNumber;
    forfeitBps: ethers.BigNumber;
    premint: Array<{ account: string; amount: ethers.BigNumber }>;
    premintTotal: ethers.BigNumber;
    addresses: {
        EtnaStaking: string;
        EtnaStakingImpl: string;
        BridgedTaikoToken: string;
        BridgedTaikoTokenImpl: string;
        ERC20Vault: string;
    };
}

// checkEtnaConfig refuses an Etna block that EtnaStaking's constructor would refuse, or whose
// withdrawalDelay is below unsettledLimit + 2 + evidenceWindowBlocks. It also refuses a missing
// stakingOwner, a premint without `devnet: true`, `devnet` on a public Taiko network, and a
// premint above TAIKO's fixed supply.
export function checkEtnaConfig(config: Config): EtnaParams {
    const etna: any = config.etna;
    if (typeof etna !== "object" || etna === null) {
        throw new Error("genesis config: etna must be an object");
    }

    const params: any = {
        inbox: nonZeroAddress(etna.inbox, "etna.inbox"),
        l1TaikoToken: nonZeroAddress(etna.l1TaikoToken, "etna.l1TaikoToken"),
        stakingOwner: nonZeroAddress(etna.stakingOwner, "etna.stakingOwner"),
        slashSink: nonZeroAddress(etna.slashSink, "etna.slashSink"),
        addresses: {},
    };
    for (const name of [
        "EtnaStaking",
        "EtnaStakingImpl",
        "BridgedTaikoToken",
        "BridgedTaikoTokenImpl",
        "ERC20Vault",
    ]) {
        params.addresses[name] = nonZeroAddress(
            (config.contractAddresses as any)?.[name],
            `contractAddresses.${name}`,
        );
    }
    if (!Number.isInteger(config.l1ChainId) || config.l1ChainId <= 0) {
        throw new Error(
            "genesis config: l1ChainId must be a positive integer on an Etna network",
        );
    }

    for (const name of [
        "minStake",
        "vpUnit",
        "nMax",
        "missLimit",
        "missSlashBps",
        "withdrawalDelay",
        "slashBountyBps",
        "forfeitBps",
    ]) {
        params[name] = decimal(etna[name], `etna.${name}`);
    }
    const { minStake, vpUnit, nMax, withdrawalDelay } = params;
    const unsettledLimit = decimal(etna.unsettledLimit, "etna.unsettledLimit");
    const evidenceWindowBlocks = decimal(
        etna.evidenceWindowBlocks,
        "etna.evidenceWindowBlocks",
    );

    inRange(nMax, "etna.nMax", 1, MAX_SEATS);
    if (vpUnit.lt(MIN_VP_UNIT)) {
        throw new Error(
            `genesis config: etna.vpUnit ${vpUnit} is below ${MIN_VP_UNIT}`,
        );
    }
    if (minStake.lt(vpUnit)) {
        throw new Error(
            `genesis config: etna.minStake ${minStake} is below etna.vpUnit ${vpUnit}`,
        );
    }
    // minStake * nMax >= 10^27, checked as the constructor does: minStake >= ceil(10^27 / nMax).
    if (minStake.lt(TAIKO_SUPPLY.add(nMax).sub(1).div(nMax))) {
        throw new Error(
            "genesis config: etna.minStake * etna.nMax is below 10^27, TAIKO's supply",
        );
    }
    inRange(params.missLimit, "etna.missLimit", 1, MAX_MISS_LIMIT);
    inRange(params.missSlashBps, "etna.missSlashBps", 1, BPS);
    inRange(params.slashBountyBps, "etna.slashBountyBps", 0, BPS - 1);
    inRange(params.forfeitBps, "etna.forfeitBps", 1, BPS);
    inRange(withdrawalDelay, "etna.withdrawalDelay", 1, DELAY_BOUND.sub(1));
    inRange(unsettledLimit, "etna.unsettledLimit", 1, MAX_UNSETTLED_LIMIT);
    if (evidenceWindowBlocks.isZero()) {
        throw new Error(
            "genesis config: etna.evidenceWindowBlocks must be positive",
        );
    }
    // No single contract sees both unsettledLimit (an Inbox parameter) and the delay, so the
    // deployment checks the bound here.
    const leastDelay = unsettledLimit.add(2).add(evidenceWindowBlocks);
    if (withdrawalDelay.lt(leastDelay)) {
        throw new Error(
            `genesis config: etna.withdrawalDelay ${withdrawalDelay} is below etna.unsettledLimit + 2 + etna.evidenceWindowBlocks = ${leastDelay}`,
        );
    }

    if (typeof etna.devnet !== "boolean") {
        throw new Error("genesis config: etna.devnet must be a boolean");
    }
    if (etna.devnet && PUBLIC_CHAIN_IDS.includes(config.chainId)) {
        throw new Error(
            `genesis config: etna.devnet is refused on chain ${config.chainId}`,
        );
    }
    if (!Array.isArray(etna.premint)) {
        throw new Error("genesis config: etna.premint must be an array");
    }
    params.premint = [];
    params.premintTotal = BigNumber.from(0);
    for (const entry of etna.premint) {
        if (
            typeof entry !== "object" ||
            entry === null ||
            Object.keys(entry).length !== 1
        ) {
            throw new Error(
                "genesis config: each etna.premint entry must be one { address: amount } pair",
            );
        }
        const [key, value] = Object.entries(entry)[0];
        const account = nonZeroAddress(key, "an etna.premint account");
        if (params.premint.some((p: any) => p.account === account)) {
            throw new Error(
                `genesis config: etna.premint lists ${account} twice`,
            );
        }
        const amount = decimal(value, `etna.premint amount of ${account}`);
        if (amount.isZero()) {
            throw new Error(
                `genesis config: etna.premint amount of ${account} must be positive`,
            );
        }
        params.premint.push({ account, amount });
        params.premintTotal = params.premintTotal.add(amount);
    }
    if (params.premint.length !== 0 && etna.devnet !== true) {
        throw new Error(
            "genesis config: etna.premint needs etna.devnet true: it mints L2 TAIKO that no L1 TAIKO backs",
        );
    }
    if (params.premintTotal.gt(TAIKO_SUPPLY)) {
        throw new Error(
            `genesis config: etna.premint totals ${params.premintTotal}, above 10^27, TAIKO's supply`,
        );
    }

    return params as EtnaParams;
}

// deployEtna generates the L2 genesis alloc of the EtnaStaking and BridgedTaikoToken predeploys:
// each implementation with its immutables patched in, and each proxy initialized, owned and not
// paused. The token holds the premint, with its votes checkpoint and EIP-712 domain.
export async function deployEtna(
    config: Config,
    result: Result,
): Promise<Result> {
    const params = checkEtnaConfig(config);
    const { addresses } = params;

    const proxy = require(
        path.join(ARTIFACTS_PATH, "./ERC1967Proxy.sol/ERC1967Proxy.json"),
    );
    const uupsReferences: any = getImmutableReference("UUPSUpgradeable", [
        "__self",
    ]);
    const essentialReferences: any = getImmutableReference(
        "EssentialContract",
        ["__resolver"],
    );
    const stakingReferences: any = getImmutableReference(
        "EtnaStaking",
        STAKING_IMMUTABLES,
    );
    const tokenReferences: any = getImmutableReference("BridgedTaikoToken", [
        "erc20Vault",
    ]);

    const stakingValues: any = {
        token: addresses.BridgedTaikoToken,
        l1ChainId: config.l1ChainId,
        inbox: params.inbox,
        minStake: params.minStake,
        vpUnit: params.vpUnit,
        nMax: params.nMax,
        missLimit: params.missLimit,
        missSlashBps: params.missSlashBps,
        withdrawalDelay: params.withdrawalDelay,
        slashBountyBps: params.slashBountyBps,
        slashSink: params.slashSink,
        forfeitBps: params.forfeitBps,
    };
    const stakingCode = patchImmutables("EtnaStaking", [
        { id: uupsReferences.__self.id, value: addresses.EtnaStakingImpl },
        { id: essentialReferences.__resolver.id, value: 0 },
        ...STAKING_IMMUTABLES.map((name) => ({
            id: stakingReferences[name].id,
            value: stakingValues[name],
        })),
    ]);
    const tokenCode = patchImmutables("BridgedTaikoToken", [
        {
            id: uupsReferences.__self.id,
            value: addresses.BridgedTaikoTokenImpl,
        },
        { id: essentialReferences.__resolver.id, value: 0 },
        { id: tokenReferences.erc20Vault.id, value: addresses.ERC20Vault },
    ]);

    const tokenLayout = await getStorageLayout("BridgedTaikoToken");
    checkTokenRawSlots(tokenLayout);

    const balances: any = {};
    for (const { account, amount } of params.premint) {
        balances[account] = amount;
    }
    const tokenSlots: any = {
        [IMPLEMENTATION_SLOT]: addresses.BridgedTaikoTokenImpl,
        [word(EIP712_NAME_SLOT)]: shortString(TOKEN_NAME),
        [word(EIP712_VERSION_SLOT)]: shortString("1"),
    };
    if (!params.premintTotal.isZero()) {
        // One checkpoint (fromBlock 0, votes = the premint total), as the premint's `_mint`
        // calls would leave it: `votes` above the 32-bit `fromBlock` in one word.
        tokenSlots[word(TOTAL_SUPPLY_CHECKPOINTS_SLOT)] = word(1);
        tokenSlots[
            ethers.utils.keccak256(word(TOTAL_SUPPLY_CHECKPOINTS_SLOT))
        ] = word(params.premintTotal.shl(32));
    }

    // EssentialContract's flags and the initializer state that `init` leaves in a proxy.
    const initialized = (owner: string) => ({
        __reentry: 1, // _FALSE
        __paused: 1, // _FALSE: not paused, unlike the ERC20Vault predeploy
        _initialized: 1,
        _initializing: false,
        _owner: owner,
    });
    // The constructor's `_disableInitializers()` leaves an implementation never initializable.
    const implementation = { _initialized: 255 };

    const contracts: { [name: string]: any } = {
        BridgedTaikoTokenImpl: {
            address: addresses.BridgedTaikoTokenImpl,
            code: tokenCode,
            layout: "BridgedTaikoToken",
            variables: implementation,
        },
        BridgedTaikoToken: {
            address: addresses.BridgedTaikoToken,
            code: proxy.deployedBytecode.object,
            layout: "BridgedTaikoToken",
            variables: Object.assign(initialized(config.contractOwner), {
                _balances: balances,
                _totalSupply: params.premintTotal,
                _name: TOKEN_NAME,
                _symbol: TOKEN_SYMBOL,
            }),
            slots: tokenSlots,
        },
        EtnaStakingImpl: {
            address: addresses.EtnaStakingImpl,
            code: stakingCode,
            layout: "EtnaStaking",
            variables: implementation,
        },
        // The staking namespace at T stays empty: no snapshot, seat or bond.
        EtnaStaking: {
            address: addresses.EtnaStaking,
            code: proxy.deployedBytecode.object,
            layout: "EtnaStaking",
            variables: initialized(params.stakingOwner),
            slots: { [IMPLEMENTATION_SLOT]: addresses.EtnaStakingImpl },
        },
    };

    for (const [contractName, contract] of Object.entries(contracts)) {
        console.log(`generating genesis.alloc for ${contractName}`);

        const storageLayout = await getStorageLayout(contract.layout);
        const storage: any = {};
        for (const slot of computeStorageSlots(
            storageLayout,
            contract.variables,
        )) {
            storage[slot.key] = slot.val;
        }
        for (const [key, val] of Object.entries(contract.slots ?? {})) {
            if (key in storage) {
                throw new Error(
                    `${contractName}: raw slot ${key} overlaps a variable`,
                );
            }
            storage[key] = val;
        }

        result.alloc[contract.address] = {
            contractName,
            storage,
            code: contract.code,
            balance: "0x0",
        };
        result.storageLayouts[contractName] = storageLayout;
    }

    return result;
}

// patchImmutables returns the runtime of the layer2 artifact `contractName` with every immutable
// set, refusing an artifact that links a library or has an immutable not in `values`.
function patchImmutables(
    contractName: string,
    values: Array<{ id: number; value: any }>,
): string {
    const artifact = require(
        path.join(ARTIFACTS_PATH, `./${contractName}.sol/${contractName}.json`),
    );
    const { immutableReferences, linkReferences } = artifact.deployedBytecode;
    if (Object.keys(linkReferences ?? {}).length !== 0) {
        throw new Error(`${contractName} links a library`);
    }
    const expected = Object.keys(immutableReferences ?? {}).sort();
    const patched = values.map(({ id }) => `${id}`).sort();
    if (JSON.stringify(expected) !== JSON.stringify(patched)) {
        throw new Error(
            `${contractName} has immutables ${expected}, but the generator patches ${patched}`,
        );
    }
    return replaceImmutableValues(
        artifact,
        values.map(({ id, value }) => ({ id, value: word(value) })),
    ).deployedBytecode.object;
}

// checkTokenRawSlots refuses a BridgedTaikoToken layout in which the raw slots moved.
function checkTokenRawSlots(layout: any) {
    const slotsOf = (label: string) =>
        layout.storage
            .filter((entry: any) => entry.label === label)
            .map((entry: any) => Number(entry.slot));
    const [, eip712Name] = slotsOf("_name");
    if (
        eip712Name !== EIP712_NAME_SLOT ||
        `${slotsOf("_version")}` !== `${EIP712_VERSION_SLOT}` ||
        `${slotsOf("_totalSupplyCheckpoints")}` !==
            `${TOTAL_SUPPLY_CHECKPOINTS_SLOT}`
    ) {
        throw new Error(
            "BridgedTaikoToken's EIP-712 or checkpoint slots moved; update etna.ts",
        );
    }
}

// shortString returns the storage word of a Solidity string of at most 31 bytes: the bytes
// left-aligned and 2 * length in the lowest byte.
function shortString(value: string): string {
    const bytes = ethers.utils.toUtf8Bytes(value);
    if (bytes.length > 31) throw new Error(`"${value}" is not a short string`);
    const slot = new Uint8Array(32);
    slot.set(bytes);
    slot[31] = bytes.length * 2;
    return ethers.utils.hexlify(slot);
}

// word returns a number or address as a 32-byte word.
function word(value: any): string {
    return ethers.utils.hexZeroPad(BigNumber.from(value).toHexString(), 32);
}

// decimal parses a non-negative integer given as a decimal string, so that no amount passes
// through a lossy JavaScript number.
function decimal(value: any, label: string): ethers.BigNumber {
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) {
        throw new Error(`genesis config: ${label} must be a decimal string`);
    }
    return BigNumber.from(value);
}

function inRange(
    value: ethers.BigNumber,
    label: string,
    min: ethers.BigNumberish,
    max: ethers.BigNumberish,
) {
    if (value.lt(min) || value.gt(max)) {
        throw new Error(
            `genesis config: ${label} ${value} is not in [${min}, ${max}]`,
        );
    }
}

function nonZeroAddress(value: any, label: string): string {
    if (!ethers.utils.isAddress(value) || BigNumber.from(value).isZero()) {
        throw new Error(`genesis config: ${label} must be a non-zero address`);
    }
    return ethers.utils.getAddress(value);
}
