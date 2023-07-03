<script>
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { Tooltip } from '$components/Tooltip';
  import { EthIcon, Icon, TaikoIcon } from '$components/Icon';
  import { StatusDot } from '$components/StatusDot';
</script>

<Card class="md:min-w-[524px]" title={$t('activities.title')} text={$t('activities.subtitle')}>
  <div class="space-y-[35px]">
    <ChainSelector label={$t('chain_selector.currently_on')} />
    <!-- Small size view  -->
    <ul class="md:hidden space-y-[10px]">
      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

      <li class="f-between-center pb-[10px] border-b border-b-divider-border">
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

    <!-- Medium size view: desktop and larger -->
    <table class="hidden md:table">
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
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
            <a class="link" href="#">View details</a>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</Card>
