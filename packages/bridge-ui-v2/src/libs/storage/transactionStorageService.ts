import { chains } from '../chain'
import { providers } from '../provider'
import { tokenVaults } from '../vault'
import { TransactionStorage } from './TransactionStorage'

// Singleton
export const transactionStorageService = new TransactionStorage(
  localStorage,
  providers,
  chains,
  tokenVaults,
)
