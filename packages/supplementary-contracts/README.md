# Supplementary Contracts

## Blacklist

Used to ban addresses from interacting with implementing contracts.

### Deploy data

When deploying the Blacklist, the following fields are required in `./script/blacklist/Deploy.data.json`:

```json
{
  "admin": "0x...", // The admin of the blacklist,
  "updater": "0x..." // The address allowed to update the blacklist,
  "blacklist": [ // The initial blacklist
    "0x0...",
    "0x1...",
    ...
  ]
}
```
