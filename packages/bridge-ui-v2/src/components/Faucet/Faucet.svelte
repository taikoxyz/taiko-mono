<script lang="ts">
  import { type Chain, getWalletClient } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { MintableError, testERC20Tokens, type Token } from '$libs/token';
  import { checkMintable } from '$libs/token/checkMintable';
  import { srcChain } from '$stores/network';
  import { PUBLIC_L1_CHAIN_NAME } from '$env/static/public';

  let minting = false;
  let checkingMintable = false;
  let selectedToken: Maybe<Token>;
  let mintButtonEnabled = false;
  let reasonNoMintable = '';

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

  async function shouldEnableMintButton(token: Maybe<Token>, network: Maybe<Chain>) {
    checkingMintable = true;
    reasonNoMintable = '';

    try {
      await checkMintable(token, network);
      return true;
    } catch (error) {
      console.error(error);

      const { cause } = error as Error;

      switch (cause) {
        case MintableError.TOKEN_UNDEFINED:
          reasonNoMintable = $t('faucet.warning.no_token', { values: { network: PUBLIC_L1_CHAIN_NAME } });
          break;
        case MintableError.NETWORK_UNDEFINED:
          reasonNoMintable = $t('faucet.warning.no_network', { values: { network: PUBLIC_L1_CHAIN_NAME } });
          break;
        case MintableError.WRONG_CHAIN:
          reasonNoMintable = $t('faucet.warning.wrong_chain', { values: { network: PUBLIC_L1_CHAIN_NAME } });
          break;
        case MintableError.NOT_CONNECTED:
          reasonNoMintable = $t('faucet.warning.no_connected');
          break;
        case MintableError.INSUFFICIENT_BALANCE:
          reasonNoMintable = $t('faucet.warning.insufficient_balance');
          break;
        case MintableError.TOKEN_MINTED:
          reasonNoMintable = $t('faucet.warning.already_minted');
          break;
        default:
          reasonNoMintable = $t('faucet.warning.unknown');
          break;
      }
    } finally {
      checkingMintable = false;
    }

    return false;
  }

  // $: shouldEnableMintButton(selectedToken, $srcChain).then((enable) => (mintButtonEnabled = enable));
</script>

<Card class="md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('chain_selector.currently_on')} bind:value={$srcChain} />
      <TokenDropdown tokens={testERC20Tokens} bind:value={selectedToken} />
    </div>

    <Button type="primary" class="px-[28px] py-[14px]" disabled={!mintButtonEnabled} on:click={mint}>
      <span class="body-bold">
        {$t('faucet.button.mint')}
      </span>
    </Button>

    {#if reasonNoMintable}
      <div class="h-sep" />

      <Alert type="warning" forceColumnFlow>
        {reasonNoMintable}
      </Alert>
    {/if}
  </div>
</Card>
