import Identicon from 'identicon.js';

export const getAddressAvatarFromIdenticon = (address) => {
  const data = new Identicon(address, 420).toString();
  return data;
}