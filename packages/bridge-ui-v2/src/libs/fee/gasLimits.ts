/**
 * Gas limit for processMessage call for ETH is about ~800k.
 * to make it enticing, we say 900k.
 */
export const ethGasLimit = 900000

/**
 * Gas limit for erc20 if not deployed on the dest chain already
 * is about ~2.9m so we add some more to make it enticing.
 */
export const erc20NotDeployedGasLimit = 3100000

/**
 * Gas limit for erc20 if already deployed on the dest chain is about ~1m
 * so again, add some to ensure processing.
 */
export const erc20DeployedGasLimit = 1100000
