<script lang="ts">
  import {
    getAccount,
    type GetAccountReturnType,
    switchChain,
    waitForTransactionReceipt,
    watchAccount,
    writeContract,
  } from '@wagmi/core';
  import { onMount } from 'svelte';
  import type { Address, Hex } from 'viem';

  import { browser } from '$app/environment';
  import { erc20Abi, faucetAbi } from '$lib/abi';
  import { hoodiChain, hoodiPublicClient } from '$lib/chains';
  import { appConfig, configIssues, configWarnings } from '$lib/config';
  import { deriveFaucetViewState } from '$lib/faucetState';
  import { explorerUrl, formatDateTime, formatTokenAmount, normalizeError, shortAddress } from '$lib/format';
  import { config, reconnectionPromise, web3modal } from '$lib/wallet';

  let connected = false;
  let currentChainId: number | null = null;
  let accountAddress: Address | null = null;
  let claimAmount: bigint | null = null;
  let walletBalance: bigint | null = null;
  let nextClaimAtMs: number | null = null;
  let tokenAddress: Address | null = appConfig.tokenAddress;
  let tokenName = 'USD Coin';
  let tokenSymbol = 'USDC';
  let tokenDecimals = 6;
  let isRefreshing = true;
  let isClaiming = false;
  let errorMessage = '';
  let statusMessage = '';
  let lastClaimHash: Hex | null = null;
  let nowMs = Date.now();
  let refreshSequence = 0;

  $: claimAmountDisplay =
    claimAmount === null ? '' : `${formatTokenAmount(claimAmount, tokenDecimals, 2)} ${tokenSymbol}`;
  $: walletBalanceDisplay = formatTokenAmount(walletBalance, tokenDecimals, 2);
  $: nextWindowLabel = nextClaimAtMs && nextClaimAtMs > nowMs ? formatDateTime(nextClaimAtMs) : 'Ready now';
  $: currentNetworkLabel = !connected
    ? 'Wallet not connected'
    : currentChainId === hoodiChain.id
      ? appConfig.chainName
      : `Unsupported network (${currentChainId})`;
  $: walletExplorerUrl = explorerUrl(appConfig.explorerUrl, 'address', accountAddress ?? undefined);
  $: tokenExplorerUrl = explorerUrl(appConfig.explorerUrl, 'address', tokenAddress ?? undefined);
  $: transactionExplorerUrl = explorerUrl(appConfig.explorerUrl, 'tx', lastClaimHash ?? undefined);
  $: viewState = deriveFaucetViewState({
    claimAmountLabel: claimAmountDisplay,
    cooldownUntilMs: nextClaimAtMs,
    isClaiming,
    isConfigured: appConfig.isConfigured,
    isConnected: connected,
    isCorrectChain: currentChainId === hoodiChain.id,
    isRefreshing,
    lastClaimHash,
    nowMs,
  });

  async function openWalletModal() {
    await web3modal?.open();
  }

  async function switchToHoodi() {
    try {
      errorMessage = '';
      await switchChain(config, { chainId: hoodiChain.id });
    } catch (error) {
      errorMessage = normalizeError(error);
      await openWalletModal();
    }
  }

  async function handlePrimaryAction() {
    if (viewState.primaryAction === 'connect') {
      await openWalletModal();
      return;
    }

    if (viewState.primaryAction === 'switch') {
      await switchToHoodi();
      return;
    }

    if (
      viewState.primaryAction !== 'claim' ||
      viewState.primaryDisabled ||
      !accountAddress ||
      !appConfig.faucetAddress ||
      currentChainId !== hoodiChain.id
    ) {
      return;
    }

    try {
      isClaiming = true;
      errorMessage = '';
      statusMessage = 'Submitting claim on Ethereum Hoodi...';

      const claimHash = await writeContract(config, {
        address: appConfig.faucetAddress,
        abi: faucetAbi,
        functionName: 'claim',
        chainId: hoodiChain.id,
      });

      statusMessage = 'Waiting for Ethereum Hoodi confirmation...';
      await waitForTransactionReceipt(config, {
        chainId: hoodiChain.id,
        hash: claimHash,
      });

      lastClaimHash = claimHash;
      statusMessage = 'Claim confirmed. You can bridge the USDC to Taiko Hoodi now.';
      await refreshState(getAccount(config));
    } catch (error) {
      statusMessage = '';
      errorMessage = normalizeError(error);
    } finally {
      isClaiming = false;
    }
  }

  async function refreshState(account: GetAccountReturnType) {
    const refreshId = ++refreshSequence;

    connected = account.isConnected;
    currentChainId = account.chainId ?? null;
    accountAddress = account.address ?? null;
    walletBalance = null;
    nextClaimAtMs = null;

    if (!appConfig.isConfigured || !appConfig.faucetAddress || !appConfig.tokenAddress) {
      isRefreshing = false;
      return;
    }

    isRefreshing = true;

    try {
      errorMessage = '';

      const [resolvedTokenAddress, resolvedClaimAmount] = await Promise.all([
        hoodiPublicClient.readContract({
          address: appConfig.faucetAddress,
          abi: faucetAbi,
          functionName: 'token',
        }),
        hoodiPublicClient.readContract({
          address: appConfig.faucetAddress,
          abi: faucetAbi,
          functionName: 'claimAmount',
        }),
      ]);

      if (refreshId !== refreshSequence) return;

      tokenAddress = resolvedTokenAddress;
      claimAmount = resolvedClaimAmount;

      const [resolvedName, resolvedSymbol, resolvedDecimals] = await Promise.all([
        hoodiPublicClient.readContract({
          address: resolvedTokenAddress,
          abi: erc20Abi,
          functionName: 'name',
        }),
        hoodiPublicClient.readContract({
          address: resolvedTokenAddress,
          abi: erc20Abi,
          functionName: 'symbol',
        }),
        hoodiPublicClient.readContract({
          address: resolvedTokenAddress,
          abi: erc20Abi,
          functionName: 'decimals',
        }),
      ]);

      if (refreshId !== refreshSequence) return;

      tokenName = resolvedName;
      tokenSymbol = resolvedSymbol;
      tokenDecimals = resolvedDecimals;

      if (account.isConnected && account.address && account.chainId === hoodiChain.id) {
        const [resolvedBalance, resolvedNextClaimAt] = await Promise.all([
          hoodiPublicClient.readContract({
            address: resolvedTokenAddress,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [account.address],
          }),
          hoodiPublicClient.readContract({
            address: appConfig.faucetAddress,
            abi: faucetAbi,
            functionName: 'nextClaimAt',
            args: [account.address],
          }),
        ]);

        if (refreshId !== refreshSequence) return;

        walletBalance = resolvedBalance;
        nextClaimAtMs = Number(resolvedNextClaimAt) * 1000;
      }
    } catch (error) {
      if (refreshId !== refreshSequence) return;
      errorMessage = normalizeError(error);
    } finally {
      if (refreshId !== refreshSequence) return;
      isRefreshing = false;
    }
  }

  onMount(() => {
    if (!browser) return;

    let disposed = false;
    const timerId = window.setInterval(() => {
      nowMs = Date.now();
    }, 1000);

    const unwatchAccount = watchAccount(config, {
      onChange(nextAccount) {
        void refreshState(nextAccount);
      },
    });

    void (async () => {
      try {
        await reconnectionPromise;
      } catch (error) {
        // The first load can proceed even if reconnection is skipped.
        console.warn('Wallet reconnection skipped during initial load.', error);
      }

      if (!disposed) {
        await refreshState(getAccount(config));
      }
    })();

    return () => {
      disposed = true;
      window.clearInterval(timerId);
      unwatchAccount();
    };
  });
</script>

<svelte:head>
  <title>Hoodi USDC Faucet</title>
  <meta
    name="description"
    content="Claim Hoodi testnet USDC on Ethereum Hoodi, then continue to the Taiko Hoodi bridge." />
</svelte:head>

<div class="page-shell fade-up">
  <header class="topbar">
    <div class="brand-stack">
      <p class="eyebrow">Taiko Hoodi Ops</p>
      <h1 class="title">Claim USDC on Ethereum Hoodi.</h1>
      <p class="subtitle">
        This faucet only mints on the Hoodi L1. Once the claim lands, use the bridge CTA to move {tokenName} onto Taiko Hoodi.
      </p>
    </div>

    <button class="ghost-button wallet-chip" on:click={openWalletModal}>
      {shortAddress(accountAddress)}
    </button>
  </header>

  <main class="shell-grid">
    <section class="card intro-card">
      <div>
        <div class="hero-amount">
          <strong>{claimAmountDisplay || '--'}</strong>
          <span>per wallet / 24 hours</span>
        </div>

        <div class="pill-row">
          <div class="pill {currentChainId === hoodiChain.id ? 'ok' : ''}">
            <span class="dot"></span>
            <span>{currentNetworkLabel}</span>
          </div>
          <div class="pill info">
            <span class="dot"></span>
            <span>Faucet token: {tokenSymbol}</span>
          </div>
          <div class="pill {viewState.cooldownActive ? '' : 'ok'}">
            <span class="dot"></span>
            <span>{viewState.cooldownActive ? viewState.detail : 'Claim window is open'}</span>
          </div>
        </div>
      </div>

      <div class="steps">
        <div class="step">
          <span class="step-index">1</span>
          <div>
            <h2>Connect on Ethereum Hoodi</h2>
            <p>Wallets on Taiko Hoodi or any other network are blocked until you switch back to the Hoodi L1.</p>
          </div>
        </div>
        <div class="step">
          <span class="step-index">2</span>
          <div>
            <h2>Claim from the faucet</h2>
            <p>The faucet submits a direct `claim()` transaction against the Hoodi USDC faucet contract.</p>
          </div>
        </div>
        <div class="step">
          <span class="step-index">3</span>
          <div>
            <h2>Bridge to Taiko Hoodi</h2>
            <p>
              The bridge step is intentionally separate. After a successful claim, jump to the existing Hoodi bridge UI.
            </p>
          </div>
        </div>
      </div>

      <div class="metrics">
        <article class="metric">
          <p class="metric-label">Wallet balance</p>
          <p class="metric-value">{walletBalanceDisplay} {tokenSymbol}</p>
        </article>
        <article class="metric">
          <p class="metric-label">Next claim window</p>
          <p class="metric-value">{nextWindowLabel}</p>
        </article>
        <article class="metric">
          <p class="metric-label">Bridge destination</p>
          <p class="metric-value">Taiko Hoodi</p>
        </article>
      </div>
    </section>

    <section class="card claim-panel">
      <div>
        <h2 class="panel-title">Faucet status</h2>
        <p class="panel-copy">{viewState.detail}</p>
      </div>

      {#if !appConfig.isConfigured}
        <div class="notice error">
          The app is missing required configuration values.
          <ul class="config-list">
            {#each configIssues as issue}
              <li>{issue}</li>
            {/each}
          </ul>
        </div>
      {/if}

      {#if configWarnings.length > 0}
        <div class="notice warning">
          WalletConnect preview mode is active because the deployment is missing:
          <ul class="config-list">
            {#each configWarnings as warning}
              <li>{warning}</li>
            {/each}
          </ul>
        </div>
      {/if}

      {#if errorMessage}
        <div class="notice error">{errorMessage}</div>
      {/if}

      {#if statusMessage}
        <div class="notice success">{statusMessage}</div>
      {/if}

      <div class="detail-grid">
        <div class="detail-line">
          <span class="detail-term">Claim size</span>
          <strong class="detail-value">{claimAmountDisplay || 'Loading...'}</strong>
        </div>
        <div class="detail-line">
          <span class="detail-term">Cooldown state</span>
          <strong class="detail-value">{viewState.cooldownActive ? viewState.primaryLabel : 'Claimable now'}</strong>
        </div>
        <div class="detail-line">
          <span class="detail-term">Faucet contract</span>
          <span class="detail-value">
            {#if appConfig.faucetAddress}
              <a
                class="address-link"
                href={explorerUrl(appConfig.explorerUrl, 'address', appConfig.faucetAddress)}
                target="_blank"
                rel="noreferrer">
                {shortAddress(appConfig.faucetAddress)}
              </a>
            {:else}
              Not configured
            {/if}
          </span>
        </div>
        <div class="detail-line">
          <span class="detail-term">USDC token</span>
          <span class="detail-value">
            {#if tokenAddress && tokenExplorerUrl}
              <a class="address-link" href={tokenExplorerUrl} target="_blank" rel="noreferrer">
                {shortAddress(tokenAddress)}
              </a>
            {:else if tokenAddress}
              {shortAddress(tokenAddress)}
            {:else}
              Loading...
            {/if}
          </span>
        </div>
      </div>

      <div class="action-stack">
        <div class="button-row">
          <button class="primary-button" disabled={viewState.primaryDisabled} on:click={handlePrimaryAction}>
            {viewState.primaryLabel}
          </button>

          {#if connected && currentChainId !== hoodiChain.id}
            <button class="secondary-button" on:click={switchToHoodi}>Switch network</button>
          {/if}
        </div>

        <div class="link-row">
          {#if viewState.showBridgeCta && appConfig.bridgeUrl}
            <a class="link-chip" href={appConfig.bridgeUrl} target="_blank" rel="noreferrer">Open Hoodi bridge</a>
          {/if}

          {#if transactionExplorerUrl}
            <a class="link-chip" href={transactionExplorerUrl} target="_blank" rel="noreferrer">View claim tx</a>
          {/if}

          {#if walletExplorerUrl}
            <a class="link-chip" href={walletExplorerUrl} target="_blank" rel="noreferrer">View wallet</a>
          {/if}
        </div>
      </div>

      <p class="footer-note">
        The faucet does not execute bridge transactions. It only mints on Ethereum Hoodi and then hands you off to the
        existing bridge flow.
      </p>
    </section>
  </main>
</div>
