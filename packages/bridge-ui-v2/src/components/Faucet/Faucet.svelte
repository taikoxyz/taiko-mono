<script lang="ts">
  import { type Chain, switchNetwork } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon } from '$components/Icon';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { PUBLIC_L1_CHAIN_ID, PUBLIC_L1_CHAIN_NAME, PUBLIC_L1_EXPLORER_URL } from '$env/static/public';
  import { InsufficientBalanceError, MintError, TokenMintedError } from '$libs/error';
  import { testERC20Tokens, type Token } from '$libs/token';
  import { checkMintable, mint } from '$libs/token';
  import { account, network, pendingTransactions } from '$stores';

  let minting = false;
  let checkingMintable = false;
  let switchingNetwork = false;

  let selectedToken: Token;
  let mintButtonEnabled = false;
  let reasonNotMintable = '';

  async function switchNetworkToL1() {
    if (switchingNetwork) return;

    switchingNetwork = true;

    try {
      await switchNetwork({ chainId: Number(PUBLIC_L1_CHAIN_ID) });
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast($t('messages.network.rejected'));
      }
    } finally {
      switchingNetwork = false;
    }
  }

  async function mintToken() {
    // During loading state we make sure the user cannot use this function
    if (checkingMintable || minting) return;

    // Token and source chain are needed to mint
    if (!selectedToken || !$network) return;

    // Let's begin the minting process
    minting = true;

    try {
      const txHash = await mint(selectedToken, $network.id);

      infoToast(
        $t('faucet.mint.tx', {
          values: {
            token: selectedToken.symbol,
            url: `${PUBLIC_L1_EXPLORER_URL}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('faucet.mint.success', {
          values: {
            token: selectedToken.symbol,
          },
        }),
      );
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast($t('faucet.mint.rejected'));
          break;
        case err instanceof MintError:
          // TODO: see contract for all possible errors
          errorToast($t('faucet.mint.error'));
          break;
        default:
          errorToast($t('faucet.mint.unknown_error'));
          break;
      }
    } finally {
      minting = false;
    }
  }

  function isUserConnected(user: Maybe<typeof $account>) {
    return Boolean(user?.isConnected);
  }

  function isWrongChain(network: Maybe<Chain>) {
    return Boolean(network?.id.toString() !== PUBLIC_L1_CHAIN_ID);
  }

  // This function will check whether or not the button to mint should be
  // enabled. If it shouldn't it'll also set the reason why so we can inform
  // the user why they can't mint
  async function updateMintButtonState(token?: Token, network?: Chain) {
    if (!token || !network) return false;

    checkingMintable = true;
    mintButtonEnabled = false;
    reasonNotMintable = '';

    try {
      await checkMintable(token, network.id);
      mintButtonEnabled = true;
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof InsufficientBalanceError:
          reasonNotMintable = $t('faucet.warning.insufficient_balance');
          break;
        case err instanceof TokenMintedError:
          reasonNotMintable = $t('faucet.warning.token_minted');
          break;
        default:
          reasonNotMintable = $t('faucet.warning.unknown');
          break;
      }
    } finally {
      checkingMintable = false;
    }
  }

  function getAlertMessage(connected: boolean, wrongChain: boolean, reasonNotMintable: string) {
    if (!connected) return $t('messages.account.required');
    if (wrongChain) return $t('faucet.wrong_chain.message', { values: { network: PUBLIC_L1_CHAIN_NAME } });
    if (reasonNotMintable) return reasonNotMintable;
  }

  $: connected = isUserConnected($account);
  $: wrongChain = isWrongChain($network);
  $: alertMessage = getAlertMessage(connected, wrongChain, reasonNotMintable);

  $: updateMintButtonState(selectedToken, $network);
</script>

<Card class="w-full md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.description')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('chain_selector.currently_on')} value={$network} switchWallet small />
      <TokenDropdown tokens={testERC20Tokens} bind:value={selectedToken} />
    </div>

    {#if alertMessage}
      <Alert type="warning" forceColumnFlow>
        {alertMessage}
      </Alert>
    {/if}

    {#if connected && wrongChain}
      <!-- We give the user an easier way to switch chains with this button -->
      <Button
        type="primary"
        class="px-[28px] py-[14px] rounded-full w-full"
        loading={switchingNetwork}
        on:click={switchNetworkToL1}>
        {#if switchingNetwork}
          <span>{$t('messages.network.switching')}</span>
        {:else}
          <Icon type="up-down" fillClass="fill-white" class="rotate-90" size={24} />
          <span class="body-bold">
            {$t('faucet.wrong_chain.button', { values: { network: PUBLIC_L1_CHAIN_NAME } })}
          </span>
        {/if}
      </Button>
    {:else}
      <Button
        type="primary"
        class="px-[28px] py-[14px] rounded-full w-full"
        disabled={!mintButtonEnabled}
        loading={checkingMintable || minting}
        on:click={mintToken}>
        <span class="body-bold">
          {#if checkingMintable}
            {$t('faucet.button.checking')}
          {:else if minting}
            {$t('faucet.button.minting')}
          {:else}
            {$t('faucet.button.mint')}
          {/if}
        </span>
      </Button>
    {/if}
  </div>
</Card>
