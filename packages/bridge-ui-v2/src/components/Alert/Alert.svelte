<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  import { Icon, type IconType } from '../Icon';

  type AlertType = 'success' | 'warning' | 'error' | 'info';
  type AlertTypeDetails = {
    class: string;
    iconType: IconType;
    iconFillClass: string;
  };

  export let type: AlertType;
  export let forceColumnFlow = false;

  let typeMap: Record<AlertType, AlertTypeDetails> = {
    success: {
      class: 'alert-success',
      iconType: 'check-circle',
      iconFillClass: 'fill-success-content',
    },
    warning: {
      class: 'alert-warning',
      iconType: 'exclamation-circle',
      iconFillClass: 'fill-warning-content',
    },
    error: {
      class: 'alert-danger',
      iconType: 'x-close-circle',
      iconFillClass: 'fill-error-content',
    },
    info: {
      class: 'alert-info',
      iconType: 'info-circle',
      iconFillClass: 'fill-info-content',
    },
  };

  const classes = classNames(
    'alert flex gap-[5px] py-[12px] px-[20px] rounded-[10px]',
    type ? typeMap[type].class : null,
    forceColumnFlow ? 'grid-flow-col text-left' : null,
    $$props.class,
  );
  const iconType = typeMap[type].iconType;
  const iconFillClass = typeMap[type].iconFillClass;
</script>

<div class={classes}>
  <div class="self-start">
    <Icon type={iconType} fillClass={iconFillClass} size={24} />
  </div>
  <div class="callout-regular">
    <slot />
  </div>
</div>
