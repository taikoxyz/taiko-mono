<script lang="ts">
	import { Icon } from '$components/Icon';
	import { classNames } from '$lib/util/classNames';

	import type { AlertIconDetails, AlertType } from './types';

	type AlertTypeDetails = AlertIconDetails & {
		alertClass: string;
	};

	export let type: AlertType;
	export let forceColumnFlow = false;

	let typeMap: Record<AlertType, AlertTypeDetails> = {
		success: {
			alertClass:
				'alert-success border-l-8 border-r-0 border-t-0 border-b-0 border-positive-sentiment bg-green-600 text-white',
			iconType: 'check-circle',
			iconFillClass: 'fill-success-content'
		},
		warning: {
			alertClass:
				'alert-warning border-l-8 border-r-0 border-t-0 border-b-0 border-yellow-600 bg-warning-sentiment',
			iconType: 'exclamation-circle',
			iconFillClass: 'fill-warning-content'
		},
		error: {
			alertClass:
				'alert-danger border-l-8 border-r-0 border-t-0 border-b-0 border-red-700 bg-red-600 text-white',
			iconType: 'x-close-circle',
			iconFillClass: 'fill-white'
		},
		info: {
			alertClass: 'alert-info',
			iconType: 'info-circle',
			iconFillClass: 'fill-info-content'
		},
		neutral: {
			alertClass: 'alert-neutral',
			iconType: 'question-circle',
			iconFillClass: 'fill-neutral-content'
		}
	};

	const { alertClass, iconType, iconFillClass } = typeMap[type];

	const classes = classNames(
		'alert flex gap-[5px] py-[12px] px-[20px] rounded-[0px]',
		type ? alertClass : '',
		forceColumnFlow ? 'grid-flow-col text-left' : '',
		$$props.class
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
