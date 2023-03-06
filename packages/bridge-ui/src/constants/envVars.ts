// Work around: Vite needs to find this string to replace it
// with the object containing the public env vars. When using
// optional chaining, import.meta.env?, Vite parser cannot
// find a match, getting undefined on import.meta.env
import.meta.env;

export const VITE_TEST_ERC20 = import.meta.env?.VITE_TEST_ERC20 ?? `[{
  "address": "0x3435A6180fBB1BAEc87bDC49915282BfBC328C70",
  "symbol": "BLL",
  "name": "Bull Token"
}]`

// TODO: add rest of env vars in another PR
