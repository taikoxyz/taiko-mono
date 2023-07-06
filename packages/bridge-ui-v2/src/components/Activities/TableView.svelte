<script lang="ts">
  import { t } from 'svelte-i18n';

  import { EthIcon, TaikoIcon } from '$components/Icon';
  import { StatusDot } from '$components/StatusDot';
  import { Tooltip } from '$components/Tooltip';
</script>

<table class="table">
  <thead class="body-regular text-secondary-content h-[60px]">
    <tr class="border-b border-b-divider-border">
      <th>{$t('chain.from')}</th>
      <th>{$t('chain.to')}</th>
      <th align="center">{$t('amount_input.label')}</th>
      <th>
        <div class="f-items-center space-x-1">
          <span>{$t('activities.header.status')}</span>
          <Tooltip position="bottom">TODO: add description about status here</Tooltip>
        </div>
      </th>
      <th align="right">{$t('activities.header.explorer')}</th>
    </tr>
  </thead>

  <tbody class="body-regular text-white">
    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td align="center">2.5 ETH</td>
      <td>
        <div class="f-items-center space-x-1">
          <StatusDot type="pending" />
          <span>{$t('activities.status.initiated')}</span>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td align="center">0.342 ETH</td>
      <td>
        <div class="f-items-center space-x-1">
          <StatusDot type="pending" />
          <span>{$t('activities.status.pending')}</span>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td align="center">7 HORSE</td>
      <td>
        <div class="f-items-center space-x-1">
          <button class="status-btn w-full">
            {$t('activities.button.claim')}
          </button>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td align="center">3 BLL</td>
      <td>
        <div class="f-items-center space-x-1">
          <button class="status-btn w-full">
            {$t('activities.button.retry')}
          </button>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td align="center">3.204 ETH</td>
      <td>
        <div class="f-items-center space-x-1">
          <StatusDot type="success" />
          <span>{$t('activities.status.claimed')}</span>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td align="center">2.5 BLL</td>
      <td>
        <div class="f-items-center space-x-1">
          <StatusDot type="error" />
          <span>{$t('activities.status.failed')}</span>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/">{$t('activities.link.explorer')}</a>
      </td>
    </tr>

    <tr class="border-b border-b-divider-border h-[80px]">
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Taiko">
            <TaikoIcon size={20} />
          </i>
          <span>Taiko</span>
        </div>
      </td>
      <td>
        <div class="f-items-center space-x-2">
          <i role="img" aria-label="Ethereum">
            <EthIcon size={20} />
          </i>
          <span>Sepolia</span>
        </div>
      </td>
      <td align="center">1.203 HORSE</td>
      <td>
        <div class="f-items-center space-x-1">
          <button class="status-btn w-full">
            {$t('activities.button.release')}
          </button>
        </div>
      </td>
      <td align="right">
        <a class="link" href="https://etherscan.io/" target="_blank" rel="noreferrer"
          >{$t('activities.link.explorer')}</a>
      </td>
    </tr>
  </tbody>
</table>
