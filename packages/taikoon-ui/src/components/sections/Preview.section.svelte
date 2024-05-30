<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';

  import { AnimatedArrow } from '$components/AnimatedArrow';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  const titleClasses = classNames(
    'w-full',
    'text-left',
    'text-primary',
    'mb-4',
    'uppercase',
    'tracking-normal',
    'text-[16px]/[24px]',
    'font-bold',
    'font-sans',
    'leading-relaxed',
  );

  const titleRowClasses = classNames('flex', 'flex-row', 'justify-between', 'items-center', 'mb-12');

  const bottomRowClasses = classNames(
    'h-[10vh]',
    'py-6',
    'w-full',
    'flex',
    'flex-row',
    'justify-center',
    'items-center',
  );

  const exploreMoreButtonClasses = classNames(
    'bg-[#E81899]',
    'font-sans',
    'w-max',
    'text-[#F3F3F3]',
    'px-3',
    'py-2',
    'rounded-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-center',
    'text-base',
    'font-bold',
    'gap-2.5',
    'hover:bg-[#C8047D]',
  );

  const viewMoreButtonClasses = classNames(
    'border',
    'border-primary',
    'font-sans',
    'w-max',
    'text-[#F3F3F3]',
    'px-3',
    'py-2',
    'rounded-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-center',
    'text-base',
    'font-bold',
    'gap-2.5',
    'hover:bg-[#C8047D]',
  );

  $: isHovered = false;

  const collectionWrapperClasses = classNames('w-full', 'pt-16', 'px-10', 'h-full');

  function shuffleArray(array: string[]) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }

    return array;
  }

  const taikoonImageUrls = shuffleArray([
    'https://taikonfts.4everland.link/ipfs/bafkreigxiubmo4rdjkz4u6qytmvp6k3eoyl6xm4hldgttgnxlcnlonbicq',
    'https://taikonfts.4everland.link/ipfs/bafkreiats7udq5cmpxlrpv2eyffuaz7gcaeetzobwxke767xzh5xk4zagu',
    'https://taikonfts.4everland.link/ipfs/bafkreiao4auahrmqoykjjf47jgoavysdvwkbetzg7clbel5mksubcdnwxu',
    'https://taikonfts.4everland.link/ipfs/bafkreictd2tnpz7o4lfsud3e63ilzxosmyx7y4cm2gugyal24vf66433zu',
    'https://taikonfts.4everland.link/ipfs/bafkreiay6auyact63wbyedql36dvvwcgunzpf7kecejvjqr2gqi7kmjtom',
    'https://taikonfts.4everland.link/ipfs/bafkreifzx7nl46vnvdzwwmibo4z7pyqqiewepdyfzpti47q2lnpozqg5g4',
    'https://taikonfts.4everland.link/ipfs/bafkreiceuf2zs5bppikkltcsrmgxxlwgemzlz3g3ll47k3sgk2a2fiofvu',
    'https://taikonfts.4everland.link/ipfs/bafkreieqwcnsac76ound2qqoxfcjzm2so4ypksrsgj7tdtqfnmchix5uh4',
    'https://taikonfts.4everland.link/ipfs/bafkreigdn34ypqd5ljdkmmgmv3spr5wvxogfbl2yr6mhrylx3ltkchhwsi',
    'https://taikonfts.4everland.link/ipfs/bafkreiccshp465c2metv3o45cqbsgsiqtrt5c7a6hzs74rg6d7k4cypzlq',
    'https://taikonfts.4everland.link/ipfs/bafkreig5u5ydiypmf2gvw7nmtluphx7vvzn5vepmgxh3rvmy2kv3mx2dtu',
    'https://taikonfts.4everland.link/ipfs/bafkreigb5zu3z2lb76qqnnnc3gzkx4bfdgcxvluxrn7nc4x4xn3pazqike',
    'https://taikonfts.4everland.link/ipfs/bafkreigusgjq3xfkqbfx6cwb4y4tfpoj3yxu3gz52xkbmb4a2jcb65g7vq',
    'https://taikonfts.4everland.link/ipfs/bafkreignw6souqrz4ttb6335shiw3hs6fcyn7fap7vbomqx4b5cetrrv7i',
    'https://taikonfts.4everland.link/ipfs/bafkreidpmawexid4nmkyqm6zkb432gtibj7i3iw5e6eery2suyjosquht4',
    'https://taikonfts.4everland.link/ipfs/bafkreibitzcm5vuf42zd7esxmvuyoexnarkhxdst7inw7beksifxtmgda4',
    'https://taikonfts.4everland.link/ipfs/bafkreidtauowxo5ikhjniqffsgzubvqyukene3trbs5o2w2pgddlpcywem',
    'https://taikonfts.4everland.link/ipfs/bafkreidexnjuteuabbdievsaf3t7zuyylrxr4vadj6cwckuuupva42ua4m',
    'https://taikonfts.4everland.link/ipfs/bafkreifu4ykma2t6fiu45hu6wlkvulh35yba4xckow5q7qtyulnmcf466i',
    'https://taikonfts.4everland.link/ipfs/bafkreigofizkk33u6cjrljxkh2y57tapbkzgbjvl7lejluegxd43jaqw7y',
    'https://taikonfts.4everland.link/ipfs/bafkreidoqrqsvfnya3cn2mxhf52hn3ms3nh4gdoka2moei4ncrzvaqde3m',
    'https://taikonfts.4everland.link/ipfs/bafkreid46bxjpexi4lenluzlm6izppww2ogm4beo757djubso54cb6jdhu',
    'https://taikonfts.4everland.link/ipfs/bafkreif3wuzvipfxwl7abn2ljcpdq7zjdhsyymr6pe56s5c2to5g3sax3i',
    'https://taikonfts.4everland.link/ipfs/bafkreicv2ufktzy5upfrub23xudgb7bvgbblpxd6c6oupgr6a2judnljdy',
    'https://taikonfts.4everland.link/ipfs/bafkreiasm7yzeuprwpippenzugzvqdbsorjbmf3hxqdiqzwzn26qa4vq74',
    'https://taikonfts.4everland.link/ipfs/bafkreiby66n5mlzvn2yeiclg7ni5hs5qj63ikbugnfetmtyjhi64i5whri',
    'https://taikonfts.4everland.link/ipfs/bafkreihstlha3etd6ndpsh2hhj4ob2ugg5f3pcvle5i5tmzbm3gjovawha',
    'https://taikonfts.4everland.link/ipfs/bafkreibovk63csxtwkccox7bfywgc67piejvi4hzswy7y6sokebrugr7g4',
    'https://taikonfts.4everland.link/ipfs/bafkreidih4f7r44qepjq2de5rjwizcu55jrgpgihutao7734fbq4x3ckwu',
    'https://taikonfts.4everland.link/ipfs/bafkreiam3tnzxjg5hvydi7vfjpqsnbyy52w7ba4qkitj5h5zx5fhp7qxoe',
    'https://taikonfts.4everland.link/ipfs/bafkreialrcybmzil6sr6pf6hijjgbji3lqfr3q5v3boyi7izrnipflc5ge',
    'https://taikonfts.4everland.link/ipfs/bafkreicmntfu7los3263bxxo3miclnv2uorxlueqgqtvyacp2ahtq74foq',
    'https://taikonfts.4everland.link/ipfs/bafkreihx7yxukpncy6oiwga3iyhsxjvpekh2wyxodnvkczmrbwgsnacxr4',
    'https://taikonfts.4everland.link/ipfs/bafkreicql5ridpluksbsl5md4a7d6p6mzv2iosnyafuppt5jahqnnf4og4',
    'https://taikonfts.4everland.link/ipfs/bafkreibygjsjcbvz7mqnhqf57is2rh62d6gqx3xfmu3lcaqq22agi657pi',
    'https://taikonfts.4everland.link/ipfs/bafkreiex66zwiab64s5gjtwqy42zfdvrd5esg2gc3drengk7ocjir7ihr4',
    'https://taikonfts.4everland.link/ipfs/bafkreibhonbd5kla7yynjcgzxkal3lh5viakvq2ye5hp4p3kvhcindimei',
    'https://taikonfts.4everland.link/ipfs/bafkreic57j6hw672ocxnujse6nmjd7nfviay6baixdvdlzs2c66mqzrpcu',
    'https://taikonfts.4everland.link/ipfs/bafkreibzyalmhdxykolzosb2jnjeiwwqtbweyavbrnedpchskt2fx7vjmm',
    'https://taikonfts.4everland.link/ipfs/bafkreiabwerlje2drmpp6ozrg57bu7f4o3choi2dty5bnphp4cpsuvi73e',
    'https://taikonfts.4everland.link/ipfs/bafkreihnpzxhwyspdcrpmyvrub7mevf2mqhyou26xmd2qu47zozimnq2om',
    'https://taikonfts.4everland.link/ipfs/bafkreiauwvidr3jl3oituk4ax5syafgdb6zu5zdybot3ryojaamgnz4p5q',
    'https://taikonfts.4everland.link/ipfs/bafkreiffhxdrab2byvpag4osnv6mhnjeuyyjju3n4vadbyifprctc6wn34',
    'https://taikonfts.4everland.link/ipfs/bafkreigdgzpicaango43pcvi7xmseizqlkb4jhejkdfjjrg6sbllpfntsu',
    'https://taikonfts.4everland.link/ipfs/bafkreidk3zxglle4xkwtlveiwmobhwxrsu74awh67cth3q2va36o5fuwqu',
    'https://taikonfts.4everland.link/ipfs/bafkreibtisqotsad6agwdummdujomnsujnka422s4hu4u4dsjxzif2sjge',
    'https://taikonfts.4everland.link/ipfs/bafkreidfvxj4qi4nij3hlvekbbc72mbf2wqgrxtviclkrvnbaoqakhw7ka',
    'https://taikonfts.4everland.link/ipfs/bafkreihp5k63lbilbg3floanu23g4i24jvmhx654gfavyrmqenzgs4qo3q',
    'https://taikonfts.4everland.link/ipfs/bafkreibxu6jplugug2w5xok5sq4hxgcblad3i6zybtsb5w43uwykx2kxoq',
    'https://taikonfts.4everland.link/ipfs/bafkreicpv5tkai6snbknyfekgm5t2bxwyugquxouarvmcxtyyoaincgsam',
  ]);

  const imageGridClasses = classNames(
    'grid',
    'md:grid-cols-6',
    'grid-cols-3',
    'lg:grid-cols-8',
    'w-full',
    'h-max',
    'gap-4',
  );

  const taikoonPreviewClasses = classNames('w-full', 'rendering-pixelated', 'rounded-lg');

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<Section class="relative" height="fit" width="xl">
  <div class={collectionWrapperClasses}>
    <div class={classNames('w-full')}>
      <p class={titleClasses}>Explore Taikoons</p>

      <div class={titleRowClasses}>
        <div class={classNames('font-clash-grotesk', 'text-[57px]/[64px]', 'text-content-primary', 'font-semibold')}>
          The 888 Collection
        </div>

        {#if windowSize !== 'sm'}
          <a
            href="/collection"
            on:mouseenter={() => (isHovered = true)}
            on:mouseleave={() => (isHovered = false)}
            class={exploreMoreButtonClasses}>
            Explore More
            <AnimatedArrow {isHovered} />
          </a>
        {/if}
      </div>
    </div>

    <div class={imageGridClasses}>
      {#each taikoonImageUrls as imageUrl}
        <img src={imageUrl} alt="Taikoon" class={taikoonPreviewClasses} />
      {/each}
    </div>
  </div>

  <div class={bottomRowClasses}>
    <a
      href="/collection"
      on:mouseenter={() => (isHovered = true)}
      on:mouseleave={() => (isHovered = false)}
      class={viewMoreButtonClasses}>
      View More
      <AnimatedArrow {isHovered} />
    </a>
  </div>
</Section>

<ResponsiveController bind:windowSize />
