import { ethers } from 'ethers'

import { BRIDGE_ABI } from '../../abi/Bridge'
import { ERC20_ABI } from '../../abi/ERC20'
import { TOKEN_VAULT_ABI } from '../../abi/TokenVault'
import type { ChainsRecord } from '../chain/types'
import { MessageStatus } from '../message/types'
import type { ProvidersRecord } from '../provider/types'
import type { BridgeTransaction } from '../transaction/types'
import type { TokenVaultsRecord } from '../vault/types'
import { jsonParseOrEmptyArray } from './jsonParseOrEmptyArray'

const STORAGE_PREFIX = 'transactions'

async function getBridgeMessageSent(
  userAddress: string,
  bridgeAddress: string,
  bridgeAbi: ethers.InterfaceAbi,
  provider: ethers.JsonRpcProvider,
  blockNumber: number,
) {
  const bridgeContract = new ethers.Contract(bridgeAddress, bridgeAbi, provider)

  // Gets the event MessageSent from the bridge contract
  // in the block where the transaction was mined, and find
  // our event MessageSent whose owner is the address passed in
  const messageSentEvents = (await bridgeContract.queryFilter(
    'MessageSent',
    blockNumber,
    blockNumber,
  )) as ethers.EventLog[]

  return messageSentEvents.find(
    ({ args }) => args.message.owner.toLowerCase() === userAddress.toLowerCase(),
  )
}

function getBridgeMessageStatus(
  bridgeAddress: string,
  bridgeAbi: ethers.InterfaceAbi,
  provider: ethers.JsonRpcProvider,
  msgHash: string,
): Promise<number> {
  const bridgeContract = new ethers.Contract(bridgeAddress, bridgeAbi, provider)

  return bridgeContract.getMessageStatus(msgHash)
}

async function getTokenVaultERC20Event(
  tokenVaultAddress: string,
  tokenVaultAbi: ethers.InterfaceAbi,
  provider: ethers.JsonRpcProvider,
  msgHash: string,
  blockNumber: number,
) {
  const tokenVaultContract = new ethers.Contract(tokenVaultAddress, tokenVaultAbi, provider)

  const filter = tokenVaultContract.filters.ERC20Sent(msgHash)

  const events = (await tokenVaultContract.queryFilter(
    filter,
    blockNumber,
    blockNumber,
  )) as ethers.EventLog[]

  return events.find(({ args }) => args.msgHash.toLowerCase() === msgHash.toLowerCase())
}

async function getERC20SymbolAndAmount(
  erc20Event: ethers.EventLog,
  erc20Abi: ethers.InterfaceAbi,
  provider: ethers.JsonRpcProvider,
): Promise<[string, bigint]> {
  const { token, amount } = erc20Event.args
  const erc20Contract = new ethers.Contract(token, erc20Abi, provider)

  const symbol: string = await erc20Contract.symbol()
  const amountInWei = BigInt(amount)

  return [symbol, amountInWei]
}

export class TransactionStorage {
  private readonly storage: Storage
  private readonly providers: ProvidersRecord
  private readonly chains: ChainsRecord
  private readonly tokenVaults: TokenVaultsRecord

  constructor(
    storage: Storage,
    providers: ProvidersRecord,
    chains: ChainsRecord,
    tokenVaults: TokenVaultsRecord,
  ) {
    this.storage = storage
    this.providers = providers
    this.chains = chains
    this.tokenVaults = tokenVaults
  }

  private _getTransactionsFromStorage(address: string): BridgeTransaction[] {
    const existingTransactions = this.storage.getItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`)

    return jsonParseOrEmptyArray<BridgeTransaction>(existingTransactions)
  }

  async getAllByAddress(address: string): Promise<BridgeTransaction[]> {
    const txs = this._getTransactionsFromStorage(address)

    const txsPromises = txs.map(async (tx) => {
      if (tx.from.toLowerCase() !== address.toLowerCase()) return

      const { toChainId, fromChainId, hash } = tx

      const destProvider = this.providers[toChainId]
      const srcProvider = this.providers[fromChainId]

      // Ignore transactions from chains not supported by the bridge
      if (!srcProvider) return

      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      const receipt = await srcProvider.getTransactionReceipt(hash)

      if (!receipt) {
        return tx
      }

      tx.receipt = receipt

      const srcBridgeAddress = this.chains[fromChainId].bridgeAddress

      const messageSentEvent = await getBridgeMessageSent(
        address,
        srcBridgeAddress,
        BRIDGE_ABI,
        srcProvider,
        receipt.blockNumber,
      )

      if (!messageSentEvent) {
        // No message yet, so we can't get more info from this transaction
        return tx
      }

      const { msgHash, message } = messageSentEvent.args

      // Let's add this new info to the transaction in case something else
      // fails, such as the filter for ERC20Sent events
      tx.msgHash = msgHash
      tx.message = message

      const destBridgeAddress = this.chains[toChainId].bridgeAddress

      tx.status = await getBridgeMessageStatus(destBridgeAddress, BRIDGE_ABI, destProvider, msgHash)

      // TODO: function isERC20Transfer(message: string): boolean?
      if (message.data && message.data !== '0x') {
        // We're dealing with an ERC20 transfer.
        // Let's get the symbol and amount from the TokenVault contract.

        const srcTokenVaultAddress = this.tokenVaults[fromChainId]

        const erc20Event = await getTokenVaultERC20Event(
          srcTokenVaultAddress,
          TOKEN_VAULT_ABI,
          srcProvider,
          msgHash,
          receipt.blockNumber,
        )

        if (!erc20Event) {
          return tx
        }

        ;[tx.symbol, tx.amountInWei] = await getERC20SymbolAndAmount(
          erc20Event,
          ERC20_ABI,
          srcProvider,
        )
      }

      return tx
    })

    const bridgeTxs = (await Promise.all(txsPromises)).filter(
      (tx) => Boolean(tx), // removes undefined values
    ) as BridgeTransaction[]

    // Place new transactions at the top of the list
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1))

    return bridgeTxs
  }

  async getTransactionByHash(
    address: string,
    hash: string,
  ): Promise<BridgeTransaction | undefined> {
    const txs = this._getTransactionsFromStorage(address)

    const tx = txs.find((tx) => tx.hash === hash)

    if (!tx || tx.from.toLowerCase() !== address.toLowerCase()) return

    const { toChainId, fromChainId } = tx

    const destProvider = this.providers[toChainId]
    const srcProvider = this.providers[fromChainId]

    // Ignore transactions from chains not supported by the bridge
    if (!srcProvider) return

    // Wait for transaction to be mined...
    await srcProvider.waitForTransaction(tx.hash)

    // ... and then get the receipt.
    const receipt = await srcProvider.getTransactionReceipt(tx.hash)

    if (!receipt) return tx

    tx.receipt = receipt

    const srcBridgeAddress = this.chains[fromChainId].bridgeAddress

    const messageSentEvent = await getBridgeMessageSent(
      address,
      srcBridgeAddress,
      BRIDGE_ABI,
      srcProvider,
      receipt.blockNumber,
    )

    if (!messageSentEvent) return tx

    const { msgHash, message } = messageSentEvent.args

    tx.msgHash = msgHash
    tx.message = message

    const destBridgeAddress = this.chains[toChainId].bridgeAddress

    const status = await getBridgeMessageStatus(
      destBridgeAddress,
      BRIDGE_ABI,
      destProvider,
      msgHash,
    )

    tx.status = status

    if (message.data && message.data !== '0x') {
      // Dealing with an ERC20 transfer. Let's get the symbol
      // and amount from the TokenVault contract.

      const srcTokenVaultAddress = this.tokenVaults[fromChainId]

      const erc20Event = await getTokenVaultERC20Event(
        srcTokenVaultAddress,
        TOKEN_VAULT_ABI,
        srcProvider,
        msgHash,
        receipt.blockNumber,
      )

      if (!erc20Event) {
        return tx
      }

      ;[tx.symbol, tx.amountInWei] = await getERC20SymbolAndAmount(
        erc20Event,
        ERC20_ABI,
        srcProvider,
      )
    }

    return tx
  }

  updateStorageByAddress(address: string, txs: BridgeTransaction[] = []) {
    this.storage.setItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`, JSON.stringify(txs))
  }
}
