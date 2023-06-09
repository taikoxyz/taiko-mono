<script lang="ts">
  import { L1_CHAIN_ID } from '../../constants/envVars';
  import type { Token } from '../../domain/token';
  import { token } from '../../store/token';
  import { errorCodes, rpcCall } from '../../utils/injectedProvider';
  import MetaMask from '../icons/MetaMask.svelte';
  import { errorToast, warningToast } from '../NotificationToast.svelte';

  async function addTokenToWallet(customToken: Token) {
    if (!customToken) {
      errorToast('Token not selected.');
      return;
    }

    try {
      await rpcCall('wallet_watchAsset', {
        type: 'ERC20',
        options: {
          address: customToken.addresses[L1_CHAIN_ID],
          symbol: customToken.symbol,
          decimals: customToken.decimals,
          image: customToken.logoUrl,
        },
      });
    } catch (error) {
      console.error(error);

      const { cause } = error;

      if (
        [cause.code, cause?.data?.originalError?.code].includes(
          errorCodes.provider.userRejectedRequest,
        )
      ) {
        warningToast('Adding token has been rejected.');
      } else {
        errorToast('Failed to add token to wallet');
      }
    }
  }
</script>

<button on:click={() => addTokenToWallet($token)} title="Add token to wallet">
  <MetaMask width={20} />
</button>
