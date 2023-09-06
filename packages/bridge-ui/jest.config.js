/** @type {import('@ts-jest/dist/types').InitialOptionsTsJest} */
export default {
  transform: {
    '^.+\\.js$': 'babel-jest',
    '^.+\\.ts$': 'ts-jest',
    '^.+\\.svelte$': [
      'svelte-jester',
      {
        preprocess: true,
      },
    ],
  },
  globals: {
    'ts-jest': {
      diagnostics: {
        ignoreCodes: [1343],
      },
      astTransformers: {
        before: [
          {
            path: 'node_modules/ts-jest-mock-import-meta',
          },
        ],
      },
    },
  },
  transformIgnorePatterns: ['node_modules/(?!(svelte-i18n)/)'],
  moduleFileExtensions: ['ts', 'js', 'svelte', 'json'],
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: [
    'lcov',
    'text',
    'cobertura',
    'json-summary',
    'json',
    'text-summary',
    'json',
  ],
  coverageThreshold: {
    global: {
      // TODO: temporal coverage decrease due to new logic,
      //       services, utils and and error handling.
      //       Mising tests for:
      //         - relayer-api/RelayerAPIService (partial test coverage)
      //         - bridge/ERC20Bridge (partial test coverage)
      //         - bridge/ETHBridge (partial test coverage)
      statements: 93,
      branches: 90,
      functions: 97,
      lines: 93,
    },
  },
  modulePathIgnorePatterns: ['<rootDir>/public/build/'],
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  testPathIgnorePatterns: ['<rootDir>/node_modules/'],
  coveragePathIgnorePatterns: ['<rootDir>/src/components/'],
  testTimeout: 40 * 1000,
  watchPathIgnorePatterns: ['node_modules'],
};
