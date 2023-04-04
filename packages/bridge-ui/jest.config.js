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
    /**
     * TODO: bring this coverage back up in the next PR. Ideally 90%
     * Missing, or not yet finished, tests:
     * - relayerApi/RelayerAPIService.spec.ts
     * - storage/StorageService.spec.ts
     * - utils/claimToken.spec.ts
     * - utils/releaseToken.spec.ts
     * - utils/isTransactionProcessable.spec.ts
     */
    global: {
      statements: 86,
      branches: 70,
      functions: 88,
      lines: 87,
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
