import { error } from '@sveltejs/kit';

const bannedCountries: Record<string, string> = {
  AF: 'Afghanistan',
  AS: 'American Samoa', // United States Territory
  BI: 'Burundi',
  BS: 'Bahamas',
  BW: 'Botswana',
  BY: 'Belarus',
  CA: 'Canada',
  CD: 'The Democratic Republic of the Congo',
  CF: 'Central African Republic',
  CI: 'Côte d’Ivoire',
  CN: 'People’s Republic of China',
  CU: 'Cuba',
  ET: 'Ethiopia',
  GH: 'Ghana',
  GU: 'Guam', // United States Territory
  ID: 'Indonesia',
  IQ: 'Iraq',
  IR: 'Islamic Republic of Iran',
  KH: 'Cambodia',
  KP: 'Democratic People’s Republic of Korea (North Korea)',
  LB: 'Lebanon',
  LK: 'Sri Lanka',
  LY: 'Libya',
  ML: 'Mali',
  MM: 'Myanmar',
  MP: 'Northern Mariana Islands', // United States Territory
  NI: 'Nicaragua',
  PA: 'Panama',
  PK: 'Pakistan',
  PR: 'Puerto Rico', // United States Territory
  RU: 'Russia',
  SD: 'Sudan',
  SO: 'Somalia',
  SS: 'South Sudan',
  SY: 'Syrian Arab Republic',
  TN: 'Tunisia',
  TT: 'Trinidad and Tobago',
  UA: 'Ukraine', // Some regions are internationally recognized as part of Ukraine but have areas under Russian control
  US: 'United States',
  VE: 'Bolivarian Republic of Venezuela',
  VI: 'U.S. Virgin Islands', // United States Territory
  YE: 'Yemen',
  ZW: 'Zimbabwe',
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
