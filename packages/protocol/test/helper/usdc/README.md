## Why cannot bring the USDC contracts (from taiko/USDC) to this repo's contract folder, and why I use a test/helper/usdc folder ?

The reason is the compiler settings (solc version and optimization). Here (in the tests) i can change the pragma version but 'in real life' we have to stick to the old USDC contract comopiler versions.

There are some things deprecated with higher version of the compiler, which is still relevant in circle’s USDC code (lack of receive does not trigger a warning, constructor visibilty,.now, .add -> Which i modified here in these files to be working with .8.20) but the Circle’s Bridged USDC Standard is clear on that, we shall NOT modify the code and have the exact same byte code.
https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md

So this is why, during testing, I used these modified USDC contracts - to have an E2E tests with our ERC20Vault - but real life we cannot use them.
