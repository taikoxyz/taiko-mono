import { error } from '@sveltejs/kit';

const bannedCountries: Record<string, string> = {
  AF: 'Afghanistan',
  BY: 'Belarus',
  MM: 'Burma/Myanmar',
  CF: 'Central African Republic',
  CN: 'China',
  CU: 'Cuba',
  CD: 'Democratic Republic of the Congo',
  ET: 'Ethiopia',
  IR: 'Iran',
  IQ: 'Iraq',
  LB: 'Lebanon',
  LY: 'Libya',
  ML: 'Mali',
  NI: 'Nicaragua',
  KP: 'North Korea',
  RU: 'Russia',
  SO: 'Somalia',
  SS: 'South Sudan',
  SD: 'Sudan',
  SY: 'Syria',
  VE: 'Venezuela',
  US: 'United States',
};

const bannedCountryCodes = Object.keys(bannedCountries);
export function load(event: any) {
  const country = event.request.headers.get('x-vercel-ip-country') ?? false;
  const isDev = event.url.hostname === 'localhost';
  if (!isDev && (!country || bannedCountryCodes.includes(country))) {
    return error(400, {
      message: `The site is not available on the following countries: ${Object.values(bannedCountries).join(', ')}`,
    });
  }
  return {
    location: { country },
  };
}
