module.exports = {
    env: {
        node: true,
        browser: true,
        es2021: true,
        webextensions: true,
    },
    extends: ["eslint:recommended"],
    parser: "@typescript-eslint/parser",
    parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        extraFileExtensions: [".svelte"],
    },
    plugins: ["svelte3", "@typescript-eslint"],
    rules: {
        "linebreak-style": ["error", "unix"],
        quotes: ["error", "double"],
        semi: ["error", "always"],
    },
    ignorePatterns: ["node_modules"], // todo: lets lint that separately, or move it to its own package
    settings: {
        "svelte3/typescript": require("typescript"),
    },
    overrides: [
        {
            files: ["*.ts", "*.svelte"],
            extends: [
                "plugin:@typescript-eslint/recommended",
                "plugin:@typescript-eslint/recommended-requiring-type-checking",
            ],
            parserOptions: {
                project: ["./tsconfig.json"],
                tsconfigRootDir: __dirname,
            },
            rules: {
                "@typescript-eslint/no-inferrable-types": 0,
                "@typescript-eslint/unbound-method": "off",
                "@typescript-eslint/no-empty-interface": "off",
            },
        },
        {
            files: ["*.svelte"],
            processor: "svelte3/svelte3",
            // typescript and svelte dont work with template handlers yet.
            // https://stackoverflow.com/questions/63337868/svelte-typescript-unexpected-tokensvelteparse-error-when-adding-type-to-an-ev
            // we need these 3 rules to be able to do:
            // on:change=(e) => anyFunctionHere().
            // when svelte is updated, we can remove these 5 rules for svelte files.
            rules: {
                "@typescript-eslint/no-explicit-any": "off",
                "@typescript-eslint/no-implicit-any": "off",
                "@typescript-eslint/no-unsafe-assignment": "off",
                "@typescript-eslint/no-unsafe-member-access": "off",
                "@typescript-eslint/no-unsafe-argument": "off",
                "@typescript-eslint/no-unsafe-call": "off",
                "@typescript-eslint/restrict-template-expressions": [
                    "warn",
                    {
                        allowNumber: true,
                        allowBoolean: true,
                        allowNullish: true,
                        allowAny: true,
                    },
                ],
            },
        },
        {
            files: ["*.spec.ts"],
            plugins: ["jest"],
            rules: {
                "@typescript-eslint/no-explicit-any": "off",
                "@typescript-eslint/no-empty-function": "off",
                "@typescript-eslint/no-unused-vars": "off",
                "@typescript-eslint/no-unsafe-assignment": "off",
                "@typescript-eslint/unbound-method": "off",
                "jest/unbound-method": "error",
            },
        },
    ],
};
