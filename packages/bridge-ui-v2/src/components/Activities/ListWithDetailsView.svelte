<script lang="ts">
  import { t } from 'svelte-i18n';

  import { EthIcon, Icon, TaikoIcon } from '$components/Icon';
  import { StatusDot } from '$components/StatusDot';
  import { Tooltip } from '$components/Tooltip';
  import { uid } from '$libs/util/uid';

  let dialogId = `dialog-${uid()}`;
  let detailsOpen = false;

  function closeDetails() {
    detailsOpen = false;
  }

  function openDetails() {
    detailsOpen = true;
  }

  function onItemKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter') {
      openDetails();
    }
  }
</script>

<div>
  <ul class="space-y-[10px]">
    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Sepolia</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Taiko</span>
        </div>
        <div class="text-primary-content">2.5 ETH</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <StatusDot type="pending" />
        <span>{$t('activities.status.initiated')}</span>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Taiko</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Sepolia</span>
        </div>
        <div class="text-primary-content">0.342 ETH</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <StatusDot type="pending" />
        <span>{$t('activities.status.pending')}</span>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Taiko</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Sepolia</span>
        </div>
        <div class="text-primary-content">7 HORSE</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <button class="status-btn w-full">
          {$t('activities.button.claim')}
        </button>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Taiko</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Sepolia</span>
        </div>
        <div class="text-primary-content">3 BLL</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <button class="status-btn w-full">
          {$t('activities.button.retry')}
        </button>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Sepolia</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Taiko</span>
        </div>
        <div class="text-primary-content">3.204 ETH</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <StatusDot type="success" />
        <span>{$t('activities.status.claimed')}</span>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Sepolia</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Taiko</span>
        </div>
        <div class="text-primary-content">2.5 BLL</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <StatusDot type="error" />
        <span>{$t('activities.status.failed')}</span>
      </div>
    </li>

    <li
      class="f-between-center pb-[10px] border-b border-b-divider-border"
      on:click={openDetails}
      on:keydown={onItemKeydown}>
      <div class="space-y-[5px]">
        <div class="body-bold f-items-center space-x-[6px] text-white">
          <span>Taiko</span>
          <i role="img" aria-label="arrow to">
            <Icon type="arrow-right" />
          </i>
          <span>Sepolia</span>
        </div>
        <div class="text-primary-content">1.203 HORSE</div>
      </div>
      <div class="f-items-center justify-end space-x-1">
        <button class="status-btn w-full">
          {$t('activities.button.release')}
        </button>
      </div>
    </li>
  </ul>

  <dialog id={dialogId} class="modal modal-bottom" class:modal-open={detailsOpen}>
    <div class="modal-box relative px-6 py-[30px] bg-neutral-background">
      <button class="absolute right-6 top-[30px]" on:click={closeDetails}>
        <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
      </button>

      <h3 class="title-body-bold mb-7 text-primary-content">{$t('processing_fee.title')}</h3>

      <ul class="space-y-[15px] body-small-regular">
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('chain.from')}</h4>
          <div class="f-items-center space-x-2">
            <i role="img" aria-label="Ethereum">
              <EthIcon size={20} />
            </i>
            <span>Sepolia</span>
          </div>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('chain.to')}</h4>
          <div class="f-items-center space-x-2">
            <i role="img" aria-label="Taiko">
              <TaikoIcon size={20} />
            </i>
            <span>Taiko</span>
          </div>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('amount_input.label')}</h4>
          <span>2.5 ETH</span>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">
            <div class="f-items-center space-x-1">
              <span>{$t('activities.header.status')}</span>
              <Tooltip position="right">TODO: add description about status here</Tooltip>
            </div>
          </h4>
          <div class="f-items-center space-x-1">
            <StatusDot type="pending" />
            <span>{$t('activities.status.initiated')}</span>
          </div>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('activities.header.explorer')}</h4>
          <a class="link" href="https://etherscan.io/" target="_blank" rel="noreferrer"
            >{$t('activities.link.explorer')}</a>
        </li>
      </ul>
    </div>

    <div class="overlay-backdrop" />
  </dialog>
</div>
