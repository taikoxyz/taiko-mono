<script lang="ts">
  import { type Chain, switchNetwork } from '@wagmi/core';
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon } from '$components/Icon';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { chains } from '$libs/chain';
  import { InsufficientBalanceError, MintError, TokenMintedError } from '$libs/error';
  import { checkMintable, mint, testERC20Tokens, type Token } from '$libs/token';
  import { account, network, pendingTransactions } from '$stores';

  let minting = false;
  let checkingMintable = false;
  let switchingNetwork = false;

  let selectedToken: Token;
  let mintButtonEnabled = false;
  let alertMessage = '';
  let mintableTokens: Token[] = [];
  const onlyMintable: boolean = true;

  async function switchNetworkToL1() {
    if (switchingNetwork) return;

    switchingNetwork = true;

    try {
      await switchNetwork({ chainId: Number(chains[0]) });
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast({title: $t('messages.network.rejected')});
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
      const explorer = chainConfig[$network.id].urls.explorer;

      infoToast({
        title: $t('faucet.mint.tx.title'),
        message: $t('faucet.mint.tx.message', {
          values: {
            token: selectedToken.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });

      await pendingTransactions.add(txHash, $network.id);

      successToast({
        title: $t('faucet.mint.success.title'),
        message: $t('faucet.mint.success.message'),
      });
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast({title: $t('faucet.mint.rejected')});
          break;
        case err instanceof MintError:
          // TODO: see contract for all possible errors
          errorToast({title: $t('faucet.mint.error')});
          break;
        default:
          errorToast({title: $t('faucet.mint.unknown_error')});
          break;
      }
    } finally {
      minting = false;
      updateMintButtonState(connected, selectedToken, $network);
    }
  }

  function isUserConnected(user: Maybe<typeof $account>) {
    return Boolean(user?.isConnected);
  }

  function isWrongChain(network: Maybe<Chain>) {
    if (!selectedToken?.addresses) {
      // nothing selected, can't determine if wrong chain
      return false;
    }
    if (network?.id) {
      return !selectedToken.addresses[network.id];
    }
    return true;
  }

  // This function will check whether or not the button to mint should be
  // enabled. If it shouldn't it'll also set the reason why so we can inform
  // the user why they can't mint
  async function updateMintButtonState(connected: boolean, token?: Token, network?: Chain) {
    if (!token || !network) return false;

    checkingMintable = true;
    mintButtonEnabled = false;
    let reasonNotMintable = '';

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
        case err instanceof ContractFunctionExecutionError:
          reasonNotMintable = $t('faucet.warning.not_mintable');
          break;
        default:
          reasonNotMintable = $t('faucet.warning.unknown');
          break;
      }
    } finally {
      checkingMintable = false;
    }

    alertMessage = getAlertMessage(connected, wrongChain, reasonNotMintable);
  }

  function getAlertMessage(connected: boolean, wrongChain: boolean, reasonNotMintable: string) {
    if (!connected) return $t('messages.account.required');
    //does this really need to be dynamic? Our mint tokens will most likely stay on Sepolia
    if (wrongChain) return $t('faucet.wrong_chain.message', { values: { network: 'Sepolia' } });
    if (reasonNotMintable) return reasonNotMintable;
    return '';
  }

  onMount(() => {
    // Only show tokens in the dropdown that are mintable
    mintableTokens = testERC20Tokens.filter((token) => token.mintable);
  });

  $: connected = isUserConnected($account);
  $: wrongChain = isWrongChain($network);

  $: updateMintButtonState(connected, selectedToken, $network);
</script>

<Card class="w-full md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.description')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('chain_selector.currently_on')} value={$network} switchWallet small />
      <TokenDropdown tokens={mintableTokens} {onlyMintable} bind:value={selectedToken} />
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
          <Icon type="up-down" fillClass="fill-white" class="rotate-90" height={24} width={24} />
          <span class="body-bold">
            {alertMessage}
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
