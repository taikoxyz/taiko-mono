<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  import { Icon } from '../Icon';
  import type { AlertIconDetails, AlertType } from './types';

  type AlertTypeDetails = AlertIconDetails & {
    textClass: string;
  };

  export let type: AlertType;
  export let message: string;

  let typeMap: Record<AlertType, AlertTypeDetails> = {
    success: {
      textClass: 'text-positive-sentiment',
      iconType: 'check-circle',
      iconFillClass: 'fill-success-content',
    },
    warning: {
      textClass: 'text-warning-sentiment',
      iconType: 'exclamation-circle',
      iconFillClass: 'fill-warning-content',
    },
    error: {
      textClass: 'text-negative-sentiment',
      iconType: 'x-close-circle',
      iconFillClass: 'fill-error-content',
    },
    info: {
      textClass: 'text-secondary-content',
      iconType: 'info-circle',
      iconFillClass: 'fill-info-content',
    },
  };

  const { textClass, iconType, iconFillClass } = typeMap[type];

  const classes = classNames('f-items-center space-x-1', $$props.class);
</script>

<div class={classes}>
  <Icon type={iconType} fillClass={iconFillClass} />
  <div class="body-small-regular {textClass}">
    {message}
  </div>
</div>
