export const ethereumRequest = async (method: string, params: any) => {
  const { ethereum } = window as any;
  try {
    await ethereum.request({
      method,
      params,
    });
  } catch (ex) {
    console.error(ex);
  }
};
