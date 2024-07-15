<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Chain, ContractFunctionExecutionError, SwitchChainError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import { Card } from '$components/Card';
  import { ChainSelector, ChainSelectorDirection, ChainSelectorType } from '$components/ChainSelectors';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { web3modal } from '$libs/connect';
  import { InsufficientBalanceError, MintError, TokenMintedError } from '$libs/error';
  import { getAlternateNetwork } from '$libs/network';
  import { checkMintable, isMintable, mint, testERC20Tokens, testNFT, type Token } from '$libs/token';
  import { config } from '$libs/wagmi';
  import { account, connectedSourceChain, pendingTransactions } from '$stores';
  import { switchingNetwork } from '$stores/network';

  let minting = false;
  let checkingMintable = false;

  let selectedToken: Token;
  let mintButtonEnabled = false;
  let alertMessage = '';
  let mintableTokens: Token[] = [];

  const onlyMintable: boolean = true;

  async function mintToken() {
    // During loading state we make sure the user cannot use this function
    if (checkingMintable || minting) return;

    // Token and source chain are needed to mint
    if (!selectedToken || !$connectedSourceChain) return;

    // Let's begin the minting process
    minting = true;
    mintButtonEnabled = false;
    minted = false;

    try {
      const txHash = await mint(selectedToken, $connectedSourceChain.id);

      const explorer = chainConfig[$connectedSourceChain.id]?.blockExplorers?.default.url;

      infoToast({
        title: $t('faucet.mint.tx.title'),
        message: $t('faucet.mint.tx.message', {
          values: {
            token: selectedToken.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });

      await pendingTransactions.add(txHash, $connectedSourceChain.id);

      successToast({
        title: $t('faucet.mint.success.title'),
        message: $t('faucet.mint.success.message'),
      });
      minted = true;
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast({ title: $t('faucet.mint.rejected.title'), message: $t('faucet.mint.rejected.message') });
          break;
        case err instanceof MintError:
          // TODO: see contract for all possible errors
          errorToast({ title: $t('faucet.mint.error') });
          break;
        default:
          errorToast({ title: $t('faucet.mint.unknown_error') });
          break;
      }
    } finally {
      minting = false;
      updateMintButtonState(connected, selectedToken, $connectedSourceChain);
    }
  }

  function isUserConnected(user: Maybe<typeof $account>) {
    return Boolean(user?.isConnected);
  }

  // This function will check whether or not the button to mint should be
  // enabled. If it shouldn't it'll also set the reason why so we can inform
  // the user why they can't mint
  async function updateMintButtonState(connected: boolean, token?: Token, network?: Chain) {
    if (!token || !network) return false;
    checkingMintable = true;
    mintButtonEnabled = false;
    let reasonNotMintable = '';
    wrongChain = false;
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
        case err instanceof ContractFunctionExecutionError && err.functionName === 'minters':
          reasonNotMintable = $t('faucet.warning.not_mintable');
          wrongChain = true;
          break;

        default:
          reasonNotMintable = $t('faucet.warning.unknown');
          break;
      }
    } finally {
      checkingMintable = false;
    }

    alertMessage = getAlertMessage(connected, reasonNotMintable);
  }

  const handleTokenSelected = (event: CustomEvent<{ token: Token }>) => {
    selectedToken = event.detail.token;
    minted = false;
    updateMintButtonState(connected, selectedToken, $connectedSourceChain);
  };

  function getAlertMessage(connected: boolean, reasonNotMintable: string) {
    if (!connected) return $t('messages.account.required');
    if (reasonNotMintable) return reasonNotMintable;
    return '';
  }

  const switchChains = async () => {
    $switchingNetwork = true;
    try {
      const alternateChain = getAlternateNetwork();
      if (!alternateChain) {
        web3modal.open();
        return;
      }
      await switchChain(config, { chainId: alternateChain });
    } catch (err) {
      if (err instanceof SwitchChainError) {
        warningToast({
          title: $t('messages.network.pending.title'),
          message: $t('messages.network.pending.message'),
        });
      } else if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: $t('messages.network.rejected.title'),
          message: $t('messages.network.rejected.message'),
        });
        console.error(err);
      }
    } finally {
      $switchingNetwork = false;
      updateMintButtonState(connected, selectedToken, $connectedSourceChain);
    }
  };

  onMount(() => {
    // Only show tokens in the dropdown that are mintable
    const testERC20 = testERC20Tokens.filter((token) => isMintable(token));
    const testNFTs = testNFT.filter((token) => isMintable(token));

    mintableTokens = [...testERC20, ...testNFTs];
  });

  $: minted = false;

  $: wrongChain = false;

  $: connected = isUserConnected($account);

  $: disabled = !$account || !$account.isConnected;

  $: updateMintButtonState(connected, selectedToken, $connectedSourceChain);
</script>

<Card class="w-full md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.description')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector
        type={ChainSelectorType.SMALL}
        direction={ChainSelectorDirection.SOURCE}
        label={$t('chain_selector.currently_on')}
        switchWallet />
      <TokenDropdown
        {disabled}
        tokens={mintableTokens}
        {onlyMintable}
        bind:value={selectedToken}
        on:tokenSelected={handleTokenSelected} />
    </div>

    {#if minted}
      <Alert type="success">
        <span class="text-lg font-bold">{$t('faucet.mint.success.title')}</span>
        <br />
        <span>{$t('faucet.mint.success.message')}</span>
      </Alert>
    {:else if alertMessage}
      <Alert type="warning" forceColumnFlow>
        {alertMessage}
      </Alert>
    {/if}

    {#if wrongChain}
      <ActionButton priority="primary" disabled={$switchingNetwork} loading={$switchingNetwork} on:click={switchChains}>
        <span class="body-bold">
          {$t('common.switch_chain')}
        </span>
      </ActionButton>
    {:else}
      <ActionButton
        priority="primary"
        disabled={!mintButtonEnabled || disabled}
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
      </ActionButton>
    {/if}
  </div>
</Card>
