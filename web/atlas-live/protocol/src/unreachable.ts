/**
 * Closes an exhaustive `switch` over a union: TypeScript rejects the call when a
 * case is missing, and `typescript/switch-exhaustiveness-check` still names it.
 */
export function unreachable(value: never): never {
  throw new Error(`unreachable: ${String(value)}`);
}
