import assert from 'node:assert/strict';

// Refuse to run against any network service outside the local demo emulators.
assert.equal(process.env.GCLOUD_PROJECT, 'demo-dacha');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
const firestore = 'http://127.0.0.1:8080/v1/projects/demo-dacha/databases/(default)/documents';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:';
async function request(url, options = {}) {
  return fetch(url, {...options, signal: AbortSignal.timeout(10000)});
}
const signup = await request(`${auth}signUp?key=demo-key`, {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({returnSecureToken: true}),
});
assert.equal(signup.status, 200, 'Auth Emulator must respond');
const {idToken} = await signup.json();
assert.ok(idToken);
try {
  for (const token of [null, idToken]) {
    const headers = {'Content-Type': 'application/json'};
    if (token) headers.Authorization = `Bearer ${token}`;
    for (const path of ['users', 'rooms', 'bookings', 'publicEvents', 'supportTickets', 'unknown']) {
      const checks = [
        [firestore + '/' + path + '/smoke', {headers}],
        [firestore + '/' + path, {headers}],
        [firestore + '/' + path + '/smoke', {method: 'PATCH', headers, body: JSON.stringify({fields: {title: {stringValue: 'Denied'}}})}],
        [firestore + '/' + path + '/smoke', {method: 'DELETE', headers}],
      ];
      for (const [url, options] of checks) {
        const response = await request(url, options);
        assert.equal(response.status, 403, `${token ? 'signed-in' : 'visitor'} ${options.method ?? 'GET'} ${path}: expected deny-all`);
      }
    }
  }
  console.log('PASS: Auth Emulator reachable; 48 anonymous/authenticated Firestore operations denied.');
} finally {
  const response = await request(`${auth}delete?key=demo-key`, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({idToken}),
  });
  assert.equal(response.status, 200, 'Temporary emulator identity cleaned up');
}
