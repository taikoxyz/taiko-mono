<script lang="ts">
  import { type Chain, getWalletClient, switchNetwork } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { MintableError, testERC20Tokens, type Token } from '$libs/token';
  import { checkMintable } from '$libs/token/checkMintable';
  import { srcChain } from '$stores/network';
  import { PUBLIC_L1_CHAIN_ID, PUBLIC_L1_CHAIN_NAME } from '$env/static/public';
  import { Modal } from '$components/Modal';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import { UserRejectedRequestError } from 'viem';
  import { warningToast } from '$components/NotificationToast';
  import { account } from '$stores/account';

  let minting = false;
  let checkingMintable = false;
  let switchingNetwork = false;

  let selectedToken: Maybe<Token>;
  let mintButtonEnabled = false;
  let reasonNoMintable = '';

  async function switchNetworkToL1() {
    if (switchingNetwork) return;

    switchingNetwork = true;

    try {
      await switchNetwork({ chainId: parseInt(PUBLIC_L1_CHAIN_ID) });
    } catch (error) {
      console.error(error);

      if (error instanceof UserRejectedRequestError) {
        warningToast($t('messages.switch_chain.rejected'));
      }
    } finally {
      switchingNetwork = false;
    }
  }

  async function mint() {
    // A token and a source chain must be selected in order to be able to mint
    if (!selectedToken || !$srcChain) return;

    // ... and of course, our wallet must be connected
    const walletClient = await getWalletClient({ chainId: $srcChain.id });
    if (!walletClient) return;

    // Let's begin the minting process
    minting = true;

    try {
      // TODO
    } finally {
      minting = false;
    }
  }

  function isUserConnected(user: Maybe<typeof $account>) {
    return user?.isConnected;
  }

  function isWrongChain(network: Maybe<Chain>) {
    return network?.id.toString() !== PUBLIC_L1_CHAIN_ID;
  }

  // async function shouldEnableMintButton(token: Maybe<Token>, network: Maybe<Chain>) {
  //   checkingMintable = true;
  //   reasonNoMintable = '';

  //   try {
  //     await checkMintable(token, network);
  //     return true;
  //   } catch (error) {
  //     console.error(error);

  //     const { cause } = error as Error;

  //     switch (cause) {
  //       case MintableError.TOKEN_UNDEFINED:
  //         reasonNoMintable = $t('faucet.warning.no_token', { values: { network: PUBLIC_L1_CHAIN_NAME } });
  //         break;
  //       case MintableError.NETWORK_UNDEFINED:
  //         reasonNoMintable = $t('faucet.warning.no_network', { values: { network: PUBLIC_L1_CHAIN_NAME } });
  //         break;
  //       case MintableError.WRONG_CHAIN:
  //         reasonNoMintable = $t('faucet.warning.wrong_chain', { values: { network: PUBLIC_L1_CHAIN_NAME } });
  //         break;
  //       case MintableError.NOT_CONNECTED:
  //         reasonNoMintable = $t('faucet.warning.no_connected');
  //         break;
  //       case MintableError.INSUFFICIENT_BALANCE:
  //         reasonNoMintable = $t('faucet.warning.insufficient_balance');
  //         break;
  //       case MintableError.TOKEN_MINTED:
  //         reasonNoMintable = $t('faucet.warning.already_minted');
  //         break;
  //       default:
  //         reasonNoMintable = $t('faucet.warning.unknown');
  //         break;
  //     }
  //   } finally {
  //     checkingMintable = false;
  //   }

  //   return false;
  // }

  // $: shouldEnableMintButton(selectedToken, $srcChain).then((enable) => (mintButtonEnabled = enable));
  $: connected = isUserConnected($account);
  $: wrongChain = isWrongChain($srcChain);
</script>

<Card class="md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('chain_selector.currently_on')} value={$srcChain} />
      <TokenDropdown tokens={testERC20Tokens} bind:value={selectedToken} />
    </div>

    {#if !connected}
      <Alert type="warning" forceColumnFlow>
        {$t('messages.account.required')}
      </Alert>
    {:else if wrongChain}
      <Alert type="warning" forceColumnFlow>
        {$t('faucet.wrong_chain.message', { values: { network: PUBLIC_L1_CHAIN_NAME } })}
      </Alert>

      <Button type="primary" class="px-[28px] py-[14px]" on:click={switchNetworkToL1}>
        {#if switchingNetwork}
          <Spinner />
          <span>{$t('faucet.wrong_chain.switching')}</span>
        {:else}
          <Icon type="up-down" fillClass="fill-white" class="rotate-90" size={24} />
          <span class="body-bold">
            {$t('faucet.wrong_chain.button', { values: { network: PUBLIC_L1_CHAIN_NAME } })}
          </span>
        {/if}
      </Button>
    {:else}
      <Button type="primary" class="px-[28px] py-[14px]" disabled={!mintButtonEnabled} on:click={mint}>
        <span class="body-bold">
          {$t('faucet.button.mint')}
        </span>
      </Button>
    {/if}

    <!-- {#if reasonNoMintable}
      <div class="h-sep" />

      <Alert type="warning" forceColumnFlow>
        {reasonNoMintable}
      </Alert>
    {/if} -->
  </div>
</Card>

<!-- <Modal title={$t('')}>

</Modal> -->
