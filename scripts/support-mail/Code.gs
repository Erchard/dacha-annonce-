// Private, owner-run Apps Script. No web endpoint or stored credentials.
const PROJECT = 'dacha-annonce';
const RECIPIENT = 'arsenguzhva@gmail.com';
const ROOT = 'projects/' + PROJECT + '/databases/(default)/documents';
const STATE_KEY = 'supportMailState';

function api_(path, body) {
  const response = UrlFetchApp.fetch('https://firestore.googleapis.com/v1/' + path, {
    method: body === undefined ? 'get' : 'post',
    contentType: 'application/json',
    headers: {Authorization: 'Bearer ' + ScriptApp.getOAuthToken()},
    payload: body === undefined ? undefined : JSON.stringify(body),
    muteHttpExceptions: true,
  });
  const code = response.getResponseCode();
  if (code !== 200) throw new Error('Firestore HTTP ' + code);
  return JSON.parse(response.getContentText());
}

function history_(cursor, descending) {
  const query = {
    from: [{collectionId: 'history', allDescendants: true}],
    orderBy: ['at', '__name__'].map(fieldPath => ({
      field: {fieldPath}, direction: descending ? 'DESCENDING' : 'ASCENDING',
    })),
    limit: descending ? 1 : 25,
  };
  if (cursor) query.startAt = {values: cursor, before: false};
  return api_(ROOT + ':runQuery', {structuredQuery: query});
}

function save_(state) {
  PropertiesService.getScriptProperties().setProperty(STATE_KEY, JSON.stringify(state));
}
function state_() {
  const raw = PropertiesService.getScriptProperties().getProperty(STATE_KEY);
  if (!raw) throw new Error('Run installNotifications first.');
  return JSON.parse(raw);
}
function cursor_(doc) {
  return [doc.fields.at, {referenceValue: doc.name}];
}

// Run once manually. Existing history is deliberately not emailed.
function installNotifications() {
  if (Session.getEffectiveUser().getEmail().toLowerCase() !== RECIPIENT) {
    throw new Error('Run this script as ' + RECIPIENT);
  }
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const rows = history_(null, true); // Verify actual Firestore permission/index.
    if (!PropertiesService.getScriptProperties().getProperty(STATE_KEY)) {
      const last = rows.find(row => row.document);
      save_({cursor: last ? cursor_(last.document) : null,
        since: rows[0].readTime, pending: null});
    }
    if (!ScriptApp.getProjectTriggers().some(t => t.getHandlerFunction() === 'sendNotifications')) {
      ScriptApp.newTrigger('sendNotifications').timeBased().everyMinutes(5).create();
    }
    console.log('Installed. Future MI tickets/comments will be checked every 5 minutes.');
  } finally {lock.releaseLock();}
}

function message_(doc) {
  const match = doc.name.match(/\/documents\/supportTickets\/([^/]+)\/history\/[^/]+$/);
  const h = doc.fields;
  if (!match || h.actorRole?.stringValue !== 'admin') return null;
  const action = h.action?.stringValue;
  const commentId = h.commentId?.stringValue;
  if (action !== 'created' && !commentId) return null;
  const actorId = h.actorId?.stringValue;
  if (!actorId || actorId.includes('/')) throw new Error('Invalid history actor');
  const actor = api_(ROOT + '/users/' + actorId).fields;
  if (actor.role?.stringValue !== 'admin' || actor.isDisabled?.booleanValue !== false) return null;
  const ticket = api_(ROOT + '/supportTickets/' + match[1]).fields;
  if (action === 'created') {
    if (ticket.createdBy?.stringValue !== actorId) throw new Error('Ticket author mismatch');
  } else {
    if (commentId.includes('/')) throw new Error('Invalid comment ID');
    const comment = api_(ROOT + '/supportTickets/' + match[1] + '/comments/' + commentId).fields;
    if (comment.authorId?.stringValue !== actorId || comment.authorRole?.stringValue !== 'admin' ||
        comment.ticketVersion?.integerValue !== h.version?.integerValue) {
      throw new Error('Comment author/version mismatch');
    }
  }
  const title = ticket.title?.stringValue;
  if (!title) throw new Error('Missing ticket title');
  const label = action === 'created' ? 'Нове звернення MI' : 'Новий коментар MI';
  return {to: RECIPIENT, subject: ('Дача — ' + label + ': ' + title).replace(/[\r\n]/g, ' ').slice(0, 220),
    body: label + '\n\n' + title + '\n\nhttps://dacha-annonce.web.app/support/' + encodeURIComponent(match[1]) +
      '\n\nДля перегляду увійдіть у свій обліковий запис розробника.', name: 'Дача — підтримка'};
}

function sendNotifications() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;
  try {
    const state = state_();
    if (state.pending?.status === 'sending') {
      state.pending.status = 'uncertain'; save_(state);
    }
    if (['failed', 'uncertain'].includes(state.pending?.status)) {
      throw new Error('Delivery ' + state.pending.status + '. Check notificationStatus; manual resolution required.');
    }
    if (state.pending?.nextAttemptAt > Date.now()) return;
    const rows = history_(state.cursor, false);
    for (const row of rows) {
      const doc = row.document;
      if (!doc) continue;
      if (!state.cursor && doc.fields.at.timestampValue <= state.since) continue;
      let message;
      try {message = message_(doc);} catch (error) {
        const attempts = (state.pending?.attempts || 0) + 1;
        state.pending = {event: doc.name, attempts, status: attempts >= 5 ? 'failed' : 'retry',
          nextAttemptAt: Date.now() + Math.pow(2, attempts - 1) * 300000};
        save_(state); throw error;
      }
      if (message) {
        if (MailApp.getRemainingDailyQuota() < 1) throw new Error('Daily mail quota exhausted; will resume automatically.');
        state.pending = {event: doc.name, status: 'sending'}; save_(state);
        try {MailApp.sendEmail(message);} catch (_) {
          // MailApp has no idempotency key or delivery receipt. Do not blindly resend.
          state.pending.status = 'uncertain'; save_(state);
          throw new Error('Mail delivery uncertain. Check inbox and notificationStatus before resolving.');
        }
      }
      state.cursor = cursor_(doc); state.pending = null; save_(state);
    }
  } finally {lock.releaseLock();}
}

function notificationStatus() {
  const state = state_();
  console.log(JSON.stringify(state)); // IDs/status only; no email bodies or credentials.
  return state;
}

// Only after checking the recipient inbox: skip the pending event as delivered.
function confirmPendingDelivered() {resolvePending_(true);}
// Only after checking the inbox: retry may duplicate an already delivered email.
function retryPendingDelivery() {resolvePending_(false);}
function resolvePending_(delivered) {
  const lock = LockService.getScriptLock(); lock.waitLock(10000);
  try {
    const state = state_();
    if (!['uncertain', 'failed'].includes(state.pending?.status)) throw new Error('No failed/uncertain delivery');
    if (delivered) state.cursor = cursor_(api_(state.pending.event));
    state.pending = null; save_(state);
  } finally {lock.releaseLock();}
}
function stopNotifications() {
  for (const trigger of ScriptApp.getProjectTriggers()) {
    if (trigger.getHandlerFunction() === 'sendNotifications') ScriptApp.deleteTrigger(trigger);
  }
}
