import { error } from '@sveltejs/kit';

const blacklistedCountries = [
  'AF', // Afghanistan (AF)
  'BY', // Belarus (BY)
  'MM', // Burma/Myanmar (MM)
  'CF', // Central African Republic (CF)
  'CN', // China (CN)
  'CU', // Cuba (CU)
  'CD', // Democratic Republic of the Congo (CD)
  'ET', // Ethiopia (ET)
  'IR', // Iran (IR)
  'IQ', // Iraq (IQ)
  'LB', // Lebanon (LB)
  'LY', // Libya (LY)
  'ML', // Mali (ML)
  'NI', // Nicaragua (NI)
  'KP', // North Korea (KP)
  'RU', // Russia (RU)
  'SO', // Somalia (SO)
  'SS', // South Sudan (SS)
  'SD', // Sudan (SD)
  'SY', // Syria (SY)
  'VE', // Venezuela (VE)
  'US', // United States (US)
];

export function load(event: any) {
  const country = event.request.headers.get('x-vercel-ip-country') ?? false;
  const isDev = event.url.hostname === 'localhost';
  if (!isDev && (!country || blacklistedCountries.includes(country))) {
    return error(400, { message: 'This site is not available in your country.' });
  }
  return {
    location: { country },
  };
}
