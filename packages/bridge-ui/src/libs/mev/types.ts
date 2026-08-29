export type PrivateRpc = {
  /** Name of the relay, shown to the user before they add it to their wallet. */
  name: string;
  /** Endpoint that forwards transactions straight to block builders instead of the public mempool. */
  url: string;
  /** Where the user can read what they are opting into. */
  docsUrl: string;
};
