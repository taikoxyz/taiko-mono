<script lang="ts">
	import { classNames } from '$lib/util/classNames';

	const classes = classNames('w-6 h-6', 'loading loading-spinner', $$props.class);
</script>

<span class={classes} />
