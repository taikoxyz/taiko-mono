export const isProduction = () => {
  return import.meta.env.VITE_NODE_ENV === "production";
};

export const isTest = () => {
  return import.meta.env.VITE_NODE_ENV === "test";
};
