/** @type {import('@ts-jest/dist/types').InitialOptionsTsJest} */
module.exports = {
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
    transformIgnorePatterns: ["node_modules/(?!(svelte-i18n)/)"],
    moduleFileExtensions: ["ts", "js", "svelte", "json"],
    setupFiles: ["dotenv/config"],
    setupFilesAfterEnv: ["@testing-library/jest-dom/extend-expect"],
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
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
        },
    },
    modulePathIgnorePatterns: ["<rootDir>/public/build/"],
    preset: "ts-jest",
    testEnvironment: "jsdom",
    testPathIgnorePatterns: ["<rootDir>/node_modules/"],
    testTimeout: 40 * 1000,
    watchPathIgnorePatterns: ["node_modules"],
};
