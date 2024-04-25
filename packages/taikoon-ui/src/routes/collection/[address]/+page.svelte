<script lang="ts">
    import { onMount } from 'svelte'

    import { Collection } from '$components/Collection'
    import { Page } from '$components/Page'
    import Token from '$lib/token'
    import { Section } from '$ui/Section'

    export let data: any

    $: tokenIds = [0]
    $: isLoading = false

    onMount(async () => {
        isLoading = true
        const { address } = data
        tokenIds = await Token.tokenOfOwner(address.toLowerCase())
        isLoading = false
    })
</script>

<svelte:head>
    <title>Taikoons | Collection</title>
</svelte:head>

<Page class="z-0">
    <Section animated>
        <Collection bind:isLoading {tokenIds} />
    </Section>
</Page>
