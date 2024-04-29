<script lang="ts">
  import { json, t } from 'svelte-i18n';

  import Copyright from '$components/core/Copyright/Copyright.svelte';
  import { Icons } from '$components/core/Icons';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  import type { IconType } from '../../types';
  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  $: socialLinks = $json('content.sections.footer.socials') as {
    name: string;
    url: string;
    icon: IconType;
  }[];

  $: textLinks = $json('content.sections.footer.nav') as {
    title: string;
    list: {
      name: string;
      url: string;
    }[];
  }[];
  const sectionClasses = classNames('justify-end align-end', 'mb-5');
  const sectionWrapperClasses = classNames(
    'w-full',
    'flex flex-col',
    'items-center',
    'justify-center',
    'bg-background-elevated',
    'mt-5',
    'p-5',
    'rounded-2xl',
    'md:gap-5',
    'gap-10',
  );

  const joinTaikoClasses = classNames(
    'w-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-center',
    'gap-5',
    'text-xs',
    'font-bold',
    'font-sans',
    'text-content-primary',
  );
  const socialLinksWrapperClasses = classNames('w-full', 'flex', 'flex-row', 'items-center', 'justify-center', 'gap-5');

  const socialLinkClasses = classNames(
    'w-1/5',
    'flex flex-row',
    'items-center',
    'justify-center',
    'bg-background-neutral',
    'lg:p-5',
    'p-3',
    'gap-3',
    'rounded-xl',
    'text-content-primary',
    'font-medium',
    'lg:text-2xl',
    'md:text-base',

    'font-clash-grotesk',
    'border',
    'transition-all',
    'border-transparent',
    'hover:border-primary',
  );

  const bottomRowClasses = classNames(
    'w-full',
    'flex',
    'md:flex-row',
    'flex-col-reverse',
    'items-center',
    'justify-center',
    'gap-5',
  );

  const bottomLeftColClasses = classNames(
    'md:w-1/5',
    'h-full',
    'flex flex-col',
    'items-start',
    'justify-center',
    'gap-5',
    'my-5',
    'md:my-0',
    'w-full',
  );

  const bottomTitleClasses = classNames(
    'text-4xl',
    'font-clash-grotesk',
    'font-medium',
    'text-content-primary',
    'md:text-left',
    'text-center',
    'w-full',
  );

  const bottomContentClasses = classNames(
    'text-content-secondary',
    'font-sans',
    'text-base',
    'font-normal',
    'md:text-left',
    'w-full',
    'text-center',
  );

  const copyrightSmClasses = classNames(
    'w-full',
    'flex flex-row',
    'items-center',
    'justify-center',
    'gap-5',
    'px-5',
    'pt-6',
    'font-sans',
    'text-base',
    'text-content-secondary',
    'font-normal',
  );

  const textLinksWrapperClasses = classNames(
    'w-full',
    'flex flex-col',
    'items-center',
    'justify-center',
    'bg-background-neutral',
    'rounded-3xl',
    'p-7',
  );

  const textLinksRowClasses = classNames(
    'w-full',
    'h-full',
    'flex',
    'md:flex-row',
    'flex-col',
    'items-start',
    'justify-start',
    'gap-7',
    'px-5',
    'py-3',
  );

  const textLinksUlClasses = classNames(
    'w-1/5',
    'flex flex-col',
    'items-start',
    'justify-start',
    'md:gap-6',
    'gap-4',
    'text-base',
    'w-full',
  );

  const textLinkTitleClasses = classNames('font-bold', 'text-content-primary', 'text-base', 'uppercase');

  const textLinkContentClasses = classNames(
    'hover:text-primary',
    'text-content-secondary',
    'text-base',
    'cursor-pointer',
  );

  const copyrightMdClasses = classNames(
    'w-full',
    'flex flex-row',
    'items-center',
    'justify-end',
    'gap-5',
    'px-5',
    'py-3',
    'font-sans',
    'text-base',
    'text-content-secondary',
    'font-normal',
  );
</script>

<Section height={windowSize === 'sm' ? 'fit' : 'min'} background="footer" class={sectionClasses} width="xl">
  <div class={sectionWrapperClasses}>
    <div class={joinTaikoClasses}>
      {$t('content.sections.footer.joinTaiko')}
    </div>
    <div class={socialLinksWrapperClasses}>
      {#each socialLinks as link}
        {@const Icon = Icons[link.icon]}
        <a href={link.url} target="_blank" class={socialLinkClasses}>
          <Icon size={windowSize === 'md' ? '16' : '24'} class="text-content-secondary" />
          {#if windowSize !== 'sm'}
            {link.name}
          {/if}
        </a>
      {/each}
    </div>

    <div class={bottomRowClasses}>
      <div class={bottomLeftColClasses}>
        <div class={bottomTitleClasses}>
          {$t('content.sections.footer.content.title')}
        </div>
        <div class={bottomContentClasses}>
          {$t('content.sections.footer.content.text')}
        </div>

        {#if windowSize === 'sm'}
          <Copyright class={copyrightSmClasses} />{/if}
      </div>

      <div class={textLinksWrapperClasses}>
        <div class={textLinksRowClasses}>
          {#each textLinks as textLink}
            <ul class={textLinksUlClasses}>
              <li class={textLinkTitleClasses}>
                {textLink.title}
              </li>
              {#each textLink.list as link}
                <li class={textLinkContentClasses}>
                  <a href={link.url}>{link.name}</a>
                </li>
              {/each}
            </ul>
          {/each}
        </div>
        {#if windowSize !== 'sm'}
          <Copyright class={copyrightMdClasses} />
        {/if}
      </div>
    </div>
  </div>
</Section>

<ResponsiveController bind:windowSize />
