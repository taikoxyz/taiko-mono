/* eslint-disable no-console */
import Ajv, { type Schema } from 'ajv';

import { PluginLogger } from './PluginLogger';

const ajv = new Ajv({ strict: false });

type SchemaWithId = Schema & { $id?: string };

const logger = new PluginLogger('json-validator');

export const validateJsonAgainstSchema = (json: JSON, schema: SchemaWithId): boolean => {
  logger.info(`Validating ${schema.$id}`);
  const validate = ajv.compile(schema);

  const valid = validate(json);

  if (!valid) {
    logger.error('Validation failed.');
    console.error('Error details:', ajv.errors);
    return false;
  }
  logger.info(`Validation of ${schema.$id} succeeded.`);
  return true;
};
