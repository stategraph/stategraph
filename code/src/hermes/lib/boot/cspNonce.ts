/**
 * nginx puts a per-response nonce on every inline script of the console
 * document, and style-src allows that same nonce. The <style> elements the
 * console creates at runtime need it: react-style-singleton (the Radix scroll
 * lock) reads it from get-nonce, and the Select viewport takes getNonce().
 */

import { setNonce } from "get-nonce";

/** The nonce of the first inline script that carries one. */
export function documentNonce(doc: Pick<Document, "querySelector">): string | undefined {
  const script = doc.querySelector<HTMLScriptElement>("script[nonce]");
  if (!script) return undefined;
  return script.nonce || script.getAttribute("nonce") || undefined;
}

/** Hands the document nonce to get-nonce, when the document has one. */
export function adoptDocumentNonce(
  doc: Pick<Document, "querySelector">,
  set: (nonce: string) => void = setNonce
): void {
  const nonce = documentNonce(doc);
  if (nonce) set(nonce);
}
