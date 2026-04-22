/* eslint-disable no-console */
import Ajv, { type Schema } from 'ajv';

import { type NFT, type Token, TokenAttributeKey } from '../../src/libs/token/types';
import { PluginLogger } from './PluginLogger';

const ajv = new Ajv({ strict: false });

type SchemaWithId = Schema & { $id?: string };

const logger = new PluginLogger('json-validator');

const validateJsonAgainstSchema = (json: JSON, schema: SchemaWithId): boolean => {
  logger.info(`Validating ${schema.$id}`);
  const validate = ajv.compile(schema);

  const valid = validate(json);

  if (!valid) {
    logger.error('Validation failed.');
    console.error('Error details:', validate.errors);
    return false;
  }

  // Additional validation for attributes against TokenAttributeKey enum
  if (Array.isArray(json)) {
    json.forEach((token: Token | NFT) => {
      if (token.attributes) {
        token.attributes.forEach((attribute: Record<string, unknown>) => {
          Object.keys(attribute).forEach((key) => {
            if (!Object.values(TokenAttributeKey).includes(key as TokenAttributeKey)) {
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
