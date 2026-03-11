# ABOUT THIRDPARTY CODE

- `/circle`: code copied from [circlefin/stablecoin-evm](https://github.com/circlefin/stablecoin-evm) at commit `f2f8b3bb1659e3f1cf23ead72d5cdf58a2f4ebfe`.
  Minimal OpenZeppelin 3.4.2 dependencies are vendored under `/circle/vendor/@openzeppelin` so the Circle contracts can be compiled in an isolated `circle` Foundry profile without depending on the repo's OpenZeppelin 4.x tree.
