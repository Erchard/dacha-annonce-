import assert from 'node:assert/strict';
export function requireEmulators() {
  assert.equal(process.env.GCLOUD_PROJECT,'demo-dacha','Only demo-dacha is allowed');
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8080','Local Firestore Emulator required');
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST,'127.0.0.1:9099','Local Auth Emulator required');
}
requireEmulators();
