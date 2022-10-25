const defaultHttpConfig = {
  headers: {
    "X-PROVIDER-ACCESS": `${
      import.meta.env.VITE_CHROME_EXTENSION_PRODUCTION_ID
    }`,
  },
};

export default defaultHttpConfig;
