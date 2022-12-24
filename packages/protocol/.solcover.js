module.exports = {
  configureYulOptimizer: true,
  skipFiles: [
    "thirdparty/LibBlockHeaderDecoder.sol", // assembly too long
    "libs/LibReceiptDecoder.sol", //integration test,
    "test/libs/TestLibReceiptDecoder.sol", //integration tests
    "test/thirdparty/TestLibBlockHeaderDecoder.sol", // assembly too long
  ],
  mocha: {
    grep: "^[^integration]",
  },
};
