<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Chain, ContractFunctionExecutionError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import { Card } from '$components/Card';
  import { ChainSelector, ChainSelectorDirection, ChainSelectorType } from '$components/ChainSelectors';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { InsufficientBalanceError, MintError, TokenMintedError } from '$libs/error';
  import { checkMintable, mint, testERC20Tokens, testNFT, type Token } from '$libs/token';
  import { account, connectedSourceChain, pendingTransactions } from '$stores';

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

    alertMessage = getAlertMessage(connected, reasonNotMintable);
  }

  function getAlertMessage(connected: boolean, reasonNotMintable: string) {
    if (!connected) return $t('messages.account.required');
    if (reasonNotMintable) return reasonNotMintable;
    return '';
  }

  onMount(() => {
    // Only show tokens in the dropdown that are mintable
    const testERC20 = testERC20Tokens.filter((token) => token.mintable);
    const testNFTs = testNFT.filter((token) => token.mintable);

    mintableTokens = [...testERC20, ...testNFTs];
  });

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
      <TokenDropdown {disabled} tokens={mintableTokens} {onlyMintable} bind:value={selectedToken} />
    </div>

    {#if alertMessage}
      <Alert type="warning" forceColumnFlow>
        {alertMessage}
      </Alert>
    {/if}

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
  </div>
</Card>
