module.exports = {
  root: true,
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended', 'plugin:svelte/recommended', 'prettier'],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'simple-import-sort'],
  rules: {
    'linebreak-style': ['error', 'unix'],
    'simple-import-sort/imports': 'error',
    'simple-import-sort/exports': 'error',
    'no-console': ['error', { allow: ['warn', 'error'] }],
  },
  parserOptions: {
    sourceType: 'module',
    ecmaVersion: 2020,
    extraFileExtensions: ['.svelte'],
  },
  env: {
    browser: true,
    es2017: true,
    node: true,
  },
  overrides: [
    {
      files: ['*.svelte'],
      rules: {
        'no-undef': 'off', // TS will take care of this
      },
      parser: 'svelte-eslint-parser',
      parserOptions: {
        parser: '@typescript-eslint/parser',
      },
    },
  ],
};
