<script lang="ts">
  import { getContext } from 'svelte';
  import { copy } from 'svelte-copy';

  import { Button } from '$components/core/Button';
  import { Spinner } from '$components/core/Spinner';
  import { NftRenderer } from '$components/NftRenderer';
  import { classNames } from '$lib/util/classNames';
  import { Icons } from '$ui/Icons';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';
  import { Link } from '$ui/Text';
  import { successToast } from '$ui/Toast';

  const { UpRightArrow } = Icons;

  // used to horizontally scroll the minted nfts with the mouse wheel
  let scrollContainer: HTMLElement;

  function copyShareUrl(element?: EventTarget | null) {
    if (!element) return;
    copy(element as HTMLElement, `${window.location.origin}/collection/${$mintState.address}`);
    successToast({
      title: 'Link copied to clipboard',
    });
  }

  const mintState = getContext('mint');
</script>

<Modal bind:open={$mintState.isModalOpen}>
  {#if $mintState.isMinting}
    <ModalTitle>
      {$mintState.isMinting
        ? `Minting ${$mintState.totalMintCount} NFT${$mintState.totalMintCount === 1 ? '' : 's'}...`
        : ''}
    </ModalTitle>
    <ModalBody>
      <div class="text-content-secondary">
        {#if $mintState.txHash}
          This can take up to a couple of minutes. Feel free to close this message.
        {:else}
          Please confirm the transaction in your wallet.
        {/if}
      </div>
    </ModalBody>
    <ModalFooter>
      <div class="w-full flex flex-row items-center gap-4">
        {#if $mintState.txHash}
          <div class="bg-interactive-tertiary rounded-md w-[30px] h-[30px] flex items-center justify-center">
            <Spinner size="sm" />
          </div>
          <div>
            <div class="font-sans font-bold text-sm text-content-primary">Waiting for confirmation</div>
            <a
              href={`https://etherscan.io/tx/${$mintState.txHash}`}
              target="_blank"
              class="flex flex-row items-center gap-2"
              >View on Etherscan
              <UpRightArrow size="10" />
            </a>
          </div>
        {:else}
          <div class="w-full flex justify-center items-center">
            <Spinner size="md" />
          </div>
        {/if}
      </div>
    </ModalFooter>
  {:else}
    <ModalBody class="justify-start gap-6 py-6 items-center">
      <div
        bind:this={scrollContainer}
        on:wheel={(e) => {
          scrollContainer.scrollLeft += e.deltaY;
        }}
        class={classNames(
          'max-w-[50vw]',
          'p-5',
          'rounded-3xl',
          'my-5',
          'bg-background-elevated',
          'flex',
          'overflow-x-scroll',
          $mintState.tokenIds.length === 1 ? 'items-center justify-center' : null,
        )}>
        <div class={classNames('flex', 'flex-row', 'justify-start', 'items-start', 'gap-5', 'w-max')}>
          {#each $mintState.tokenIds as tokenId}
            <NftRenderer size="md" {tokenId} />
          {/each}
        </div>
      </div>

      <div class={classNames('text-content-primary', 'text-4xl', 'font-clash-grotesk', 'font-semibold', 'text-center')}>
        You got it!
      </div>
      <div
        class={classNames(
          'font-sans',
          'text-center',
          'text-content-secondary',
          'font-normal',
          'text-base',
          'md:w-min',
          'md:min-w-[300px]',
          'w-full',
        )}>
        Your NFTs were minted! They are now in your Ethereum wallet and displayed on <Link
          class={classNames('hover:text-content-link-hover', 'text-content-link-primary', 'font-sans', 'font-normal')}
          href={`/collection/${$mintState.address}`}>Your Taikoons.</Link>
      </div>
    </ModalBody>
    <ModalFooter>
      <div
        class={classNames(
          'flex',
          'md:flex-row',
          'flex-col',
          'w-full',
          'gap-4',
          'items-center',
          'justify-between',
          'min-w-[500px]',
        )}>
        <div class="md:w-1/2 w-full px-2" use:copy={`${window.location.origin}/collection/${$mintState.address}`}>
          <Button on:click={(event) => copyShareUrl(event.currentTarget)} wide block type="primary">Share</Button>
        </div>
        <div class="md:w-1/2 w-full px-2">
          <Button
            on:click={() => ($mintState.isModalOpen = false)}
            href={`/collection/${$mintState.address}`}
            wide
            block
            type="negative">Your Taikoons</Button>
        </div>
      </div>
    </ModalFooter>
  {/if}
</Modal>
