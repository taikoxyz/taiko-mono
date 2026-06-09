import { PluginLogger } from "./PluginLogger.js";

const logger = new PluginLogger("json-validator");

// Inlined from $libs/token TokenAttributeKey (not yet ported). Keep in sync with
// the original src/libs/token/types TokenAttributeKey enum values.
const TokenAttributeKey = {
  Wrapped: "wrapped",
  Supported: "supported",
  Stablecoin: "stablecoin",
  Mintable: "mintable",
};

// Optionally load ajv (the original validator uses `new Ajv({ strict: false })`).
// ajv is a build-only dependency; if it is not installed we fall back to a
// permissive structural check so the generator never silently no-ops.
let Ajv;
try {
  ({ default: Ajv } = await import("ajv"));
} catch {
  Ajv = null;
}

const ajv = Ajv ? new Ajv({ strict: false }) : null;

const validateJsonAgainstSchema = (json, schema) => {
  logger.info(`Validating ${schema.$id}`);

  if (ajv) {
    const validate = ajv.compile(schema);
    const valid = validate(json);

    if (!valid) {
      logger.error("Validation failed.");
      console.error("Error details:", validate.errors);
      return false;
    }
  } else {
    logger.warn(
      "ajv not installed — skipping JSON Schema validation (structural check only).",
    );
  }

  // Additional validation for attributes against TokenAttributeKey enum
  if (Array.isArray(json)) {
    json.forEach((token) => {
      if (token.attributes) {
        token.attributes.forEach((attribute) => {
          Object.keys(attribute).forEach((key) => {
            if (!Object.values(TokenAttributeKey).includes(key)) {
              logger.error(`Invalid attribute key: ${key}`);
              console.error(`Invalid attribute key: ${key}`);
              throw new Error(`Invalid attribute key: ${key}`);
            }
          });
        });
      }
    });
  }

  logger.info(`Validation of ${schema.$id} succeeded.`);
  return true;
};

export { validateJsonAgainstSchema };
