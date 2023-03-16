type EnvName = keyof ImportMetaEnv;

export function getEnv(name: EnvName, defaultValue?: string): string {
  const envVar = import.meta.env?.[name];
  if (typeof defaultValue === 'undefined') {
    throw Error(`Error: missing environment variable "${name}"`);
  }

  return envVar;
}
