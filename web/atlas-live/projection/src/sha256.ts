/**
 * sha256 of input bytes, via WebCrypto so the same code runs in Node (the Bazel
 * CLI) and in the browser (local import).
 */
export async function sha256Hex(data: ArrayBuffer): Promise<string> {
  const digest = await globalThis.crypto.subtle.digest("SHA-256", data);
  let hex = "";
  for (const byte of new Uint8Array(digest)) {
    hex += byte.toString(16).padStart(2, "0");
  }
  return hex;
}
