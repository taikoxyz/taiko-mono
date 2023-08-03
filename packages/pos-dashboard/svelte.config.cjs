const sveltePreprocess = require('svelte-preprocess');

const svelteConfig = {
  compilerOptions: {
    enableSourcemap: true,
  },

  preprocess: sveltePreprocess({
    sourceMap: true,
  }),
};

module.exports = svelteConfig;
