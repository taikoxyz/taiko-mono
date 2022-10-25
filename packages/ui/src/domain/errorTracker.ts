// temp type until we add methods to the interface
// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface ErrorTracker {
  captureError(error: unknown, context?: string);
}

export { ErrorTracker };
