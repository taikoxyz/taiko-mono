<script lang="ts">
    import { ResponsiveController } from '$components/core/ResponsiveController'
    import { MintAgreementModal } from '$components/modals'
    import { CollapsibleSection, FooterSection } from '$components/sections'
    import FaqOptions from '$content/faq'
    import { Section, SectionContainer } from '$ui/Section'

    import { Mint } from '../../components/Mint'
    import { Page } from '../../components/Page'

    let windowSize: 'sm' | 'md' | 'lg' = 'md'
</script>

<svelte:head>
    <title>Taikoons | Mint</title>
</svelte:head>

<Page>
    <SectionContainer>
        <Section
            width={windowSize === 'sm' ? 'full' : 'md'}
            height={windowSize === 'sm' ? 'fit' : 'full'}
        >
            <Mint />
        </Section>
        <CollapsibleSection options={FaqOptions} />

        <FooterSection />
    </SectionContainer>
</Page>

<MintAgreementModal />

<ResponsiveController bind:windowSize />
