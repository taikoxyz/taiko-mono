import type { GetAccountResult, Provider } from '@wagmi/core'
import { writable } from 'svelte/store'

export const account = writable<GetAccountResult<Provider>>()
