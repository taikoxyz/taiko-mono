<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  import { Icon } from '../Icon';
  import type { AlertIconDetails, AlertType } from './types';

  type AlertTypeDetails = AlertIconDetails & {
    alertClass: string;
  };

  export let type: AlertType;
  export let forceColumnFlow = false;

  let typeMap: Record<AlertType, AlertTypeDetails> = {
    success: {
      alertClass: 'alert-success',
      iconType: 'check-circle',
      iconFillClass: 'fill-success-content',
    },
    warning: {
      alertClass: 'alert-warning',
      iconType: 'exclamation-circle',
      iconFillClass: 'fill-warning-content',
    },
    error: {
      alertClass: 'alert-danger',
      iconType: 'x-close-circle',
      iconFillClass: 'fill-error-content',
    },
    info: {
      alertClass: 'alert-info',
      iconType: 'info-circle',
      iconFillClass: 'fill-info-content',
    },
  };

  const { alertClass, iconType, iconFillClass } = typeMap[type];

  const classes = classNames(
    'alert flex gap-[5px] py-[12px] px-[20px] rounded-[10px]',
    type ? alertClass : null,
    forceColumnFlow ? 'grid-flow-col text-left' : null,
    $$props.class,
  );
</script>

<div class={classes}>
  <div class="self-start">
    <Icon type={iconType} fillClass={iconFillClass} size={24} />
  </div>
  <div class="callout-regular">
    <slot />
  </div>
</div>
