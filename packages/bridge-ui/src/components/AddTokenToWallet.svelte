<script lang="ts">
  import { UserRejectedRequestError } from '@wagmi/core';

  import { L1_CHAIN_ID } from '../constants/envVars';
  import type { Token } from '../domain/token';
  import { token } from '../store/token';
  import MetaMask from './icons/MetaMask.svelte';
  import { errorToast, warningToast } from './NotificationToast.svelte';

  async function addTokenToWallet(customToken: Token) {
    if (!customToken) {
      errorToast('Token not selected.');
      return;
    }

    try {
      await window.ethereum.request({
        method: 'wallet_watchAsset',
        params: {
          type: 'ERC20',
          options: {
            address: customToken.addresses[L1_CHAIN_ID],
            symbol: customToken.symbol,
            decimals: customToken.decimals,
            image: customToken.logoUrl,
          },
        },
      });
    } catch (e) {
      if (e.code === 4001) {
        warningToast('Adding token has been rejected.');
      } else {
        errorToast('Failed to add token to wallet');
      }
    }
  }
</script>

<span
  class="inline-block cursor-pointer align-middle"
  on:click={() => addTokenToWallet($token)}>
  <MetaMask width={16} /></span>
