const TS_EXPRESSION = Symbol('tsExpression');

type TsExpression = {
  [TS_EXPRESSION]: string;
};

export function tsExpression(expression: string): TsExpression {
  return { [TS_EXPRESSION]: expression };
}

function isTsExpression(value: unknown): value is TsExpression {
  return (
    typeof value === 'object' &&
    value !== null &&
    Object.prototype.hasOwnProperty.call(value, TS_EXPRESSION) &&
    typeof (value as Partial<TsExpression>)[TS_EXPRESSION] === 'string'
  );
}

export function toTsLiteral(value: unknown): string {
  if (isTsExpression(value)) {
    return value[TS_EXPRESSION];
  }

  if (typeof value === 'string') {
    return JSON.stringify(value);
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`Cannot serialize non-finite number: ${value}`);
    }
    return String(value);
  }

  if (typeof value === 'bigint') {
    return `${value.toString()}n`;
  }

  if (typeof value === 'boolean') {
    return String(value);
  }

  if (value === null) {
    return 'null';
  }

  if (value === undefined) {
    return 'undefined';
  }

  if (Array.isArray(value)) {
    return `[${value.map(toTsLiteral).join(', ')}]`;
  }

  if (typeof value === 'object') {
    const entries = Object.entries(value).map(([key, nestedValue]) => {
      return `${JSON.stringify(key)}: ${toTsLiteral(nestedValue)}`;
    });
    return `{${entries.join(', ')}}`;
  }

  throw new Error(`Cannot serialize value of type ${typeof value}`);
}
