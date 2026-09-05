/**
 * The destination gas headroom is derived, not guessed. This test writes the derivation down
 * where the numbers live and fails when either side changes without the other.
 */
import { gasLimitConfig } from './app.config';

/** What the bridge UI added before EIP-8037, calibrated on the pre-fork gas schedule. */
const PRE_8037_HEADROOM = {
  erc20DeployedGasLimit: 500_000,
  erc20NotDeployedGasLimit: 750_000,
  erc721DeployedGasLimit: 1_100_000,
  erc721NotDeployedGasLimit: 2_400_000,
  erc1155DeployedGasLimit: 1_100_000,
  erc1155NotDeployedGasLimit: 2_600_000,
} as const;

/** EIP-8037: 1,530 gas per state byte; 64 bytes per fresh storage slot, 120 per new account. */
const COST_PER_STATE_BYTE = 1_530;
const FRESH_SLOT_DELTA = 64 * COST_PER_STATE_BYTE - 20_000; // 97,920 replaces SSTORE's 20,000
const NEW_ACCOUNT_DELTA = 120 * COST_PER_STATE_BYTE - 32_000; // 183,600 replaces CREATE's 32,000
const CODE_BYTE_DELTA = COST_PER_STATE_BYTE - 200; // per deployed byte, replacing 200
/** Runtime size of OpenZeppelin 4.9.6's ERC1967Proxy, which every vault deploys for a new bridged token. */
const PROXY_RUNTIME_BYTES = 711;
/** Covers compiler drift on the proxy size and EIP-8038's still unpriced CREATE access cost. */
const MARGIN = 1.15;
const ROUNDING = 100_000;

const deployDelta = NEW_ACCOUNT_DELTA + PROXY_RUNTIME_BYTES * CODE_BYTE_DELTA;

/**
 * Fresh storage slots each path writes on the destination chain, worst case.
 *
 * Every "not deployed" path deploys an ERC1967Proxy (implementation slot) and initialises the
 * bridged token behind it: Initializable's version, the owner, EssentialContract's paused
 * flag, the token's own name and symbol (or, for ERC1155, a ~75-byte URI over four slots),
 * `srcToken` and `srcChainId`; the vault then records the canonical token (chain id and
 * address, symbol, name) and the canonical-to-bridged index. Four more slots are allowed for
 * a name or symbol of 32 bytes or longer, which strings store out of line in both places.
 *
 * The transfer itself: ERC20 mints into a new balance and a zero total supply; ERC721 writes
 * the owner of the id and the recipient's balance; ERC1155 writes one balance per id, and
 * the UI bridges one id at a time.
 */
const FRESH_SLOTS = {
  erc20DeployedGasLimit: 2,
  erc20NotDeployedGasLimit: 1 + 1 + 1 + 1 + 2 + 2 + 4 + 2 + 4,
  erc721DeployedGasLimit: 2,
  erc721NotDeployedGasLimit: 1 + 1 + 1 + 1 + 2 + 2 + 4 + 2 + 4,
  erc1155DeployedGasLimit: 1,
  erc1155NotDeployedGasLimit: 1 + 1 + 1 + 1 + 4 + 2 + 2 + 4 + 1 + 4,
} as const;

const requiredHeadroom = (key: keyof typeof gasLimitConfig) => {
  const deploys = key.includes('NotDeployed');
  const delta = FRESH_SLOTS[key] * FRESH_SLOT_DELTA + (deploys ? deployDelta : 0);
  return PRE_8037_HEADROOM[key] + Math.ceil(delta * MARGIN);
};

describe('gasLimitConfig under EIP-8037', () => {
  it.each(Object.keys(gasLimitConfig) as (keyof typeof gasLimitConfig)[])(
    '%s covers the state its path creates, rounded up to the next 100k',
    (key) => {
      const required = requiredHeadroom(key);

      expect(gasLimitConfig[key]).toBeGreaterThanOrEqual(required);
      expect(gasLimitConfig[key]).toBeLessThan(required + ROUNDING);
      expect(gasLimitConfig[key] % ROUNDING).toBe(0);
    },
  );

  it('prices a first-time token above an already deployed one', () => {
    expect(gasLimitConfig.erc20NotDeployedGasLimit).toBeGreaterThan(gasLimitConfig.erc20DeployedGasLimit);
    expect(gasLimitConfig.erc721NotDeployedGasLimit).toBeGreaterThan(gasLimitConfig.erc721DeployedGasLimit);
    expect(gasLimitConfig.erc1155NotDeployedGasLimit).toBeGreaterThan(gasLimitConfig.erc1155DeployedGasLimit);
  });
});
