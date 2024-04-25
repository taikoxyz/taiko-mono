import { Icons } from '$ui/Icons'
const { DiscordLogo, MirrorLogo, TaikoLogo, YoutubeLogo, TwitterLogo } = Icons

export const FooterButtonLinks = [
    {
        icon: DiscordLogo,
        label: 'discord',
        href: 'https://discord.com/invite/taikoxyz',
    },
    {
        icon: TwitterLogo,
        label: 'twitter',
        href: 'https://twitter.com/taikoxyz',
    },
    {
        icon: MirrorLogo,
        label: 'mirror',
        href: 'https://taiko.mirror.xyz/',
    },
    {
        icon: TaikoLogo,
        label: 'forum',
        href: 'https://community.taiko.xyz/',
    },
    {
        icon: YoutubeLogo,
        label: 'youtube',
        href: 'https://www.youtube.com/@taikoxyz',
    },
]

export const FooterTextLinks: Record<string, Record<string, string>> = {
    About: {
        Blog: 'https://taiko.xyz/blog',
        Careers: 'https://taiko.xyz/careers',
        'Brand Kit': 'https://taiko.xyz/brand-assets',
    },
    Developers: {
        'Get Started': 'https://taiko.xyz/docs',
        Github: '',
        'Integration manual': 'https://taiko.xyz/docs/integration-manual',
    },
    Solutions: {
        Bridge: 'https://taiko.xyz/bridge',
        Swap: 'https://taiko.xyz/swap',
        Documentation: 'https://taiko.xyz/docs',
        Explorer: 'https://taiko.xyz/explorer',
    },
}
