/** @type {import('@ts-jest/dist/types').InitialOptionsTsJest} */
export default {
    transform: {
        "^.+\\.js$": "babel-jest",
        "^.+\\.ts$": "ts-jest",
        "^.+\\.svelte$": [
            "svelte-jester",
            {
                preprocess: true,
            },
        ],
    },
    globals: {
        'ts-jest': {
            diagnostics: {
              ignoreCodes: [1343]
            },
            astTransformers: {
              before: [
                {
                    path: 'node_modules/ts-jest-mock-import-meta',
                }
              ],
            }
          }
      }, 
    transformIgnorePatterns: ["node_modules/(?!(svelte-i18n)/)"],
    moduleFileExtensions: ["ts", "js", "svelte", "json"],
    collectCoverage: true,
    coverageDirectory: "coverage",
    coverageReporters: [
        "lcov",
        "text",
        "cobertura",
        "json-summary",
        "json",
        "text-summary",
        "json",
    ],
    coverageThreshold: {
        global: {
            statements: 96,
            branches: 79,
            functions: 91,
            lines: 97,
        },
    },
    modulePathIgnorePatterns: ["<rootDir>/public/build/"],
    preset: "ts-jest",
    testEnvironment: "jsdom",
    testPathIgnorePatterns: ["<rootDir>/node_modules/"],
    coveragePathIgnorePatterns: ["<rootDir>/src/components/"],
    testTimeout: 40 * 1000,
    watchPathIgnorePatterns: ["node_modules"],
};
