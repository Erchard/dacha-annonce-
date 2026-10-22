// Private, owner-run Apps Script. No web endpoint or stored credentials.
const PROJECT = 'dacha-annonce';
const DEVELOPER_RECIPIENT = 'arsenguzhva@gmail.com';
const ADMIN_RECIPIENT = 'mkyrylenko@ukr.net';
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

function plain_(value, max) {
  return String(value || '').replace(/[\r\n]+/g, '\n').replace(/[^\S\n]+/g, ' ')
    .trim().slice(0, max);
}

// Run once manually. Existing history is deliberately not emailed.
function installNotifications() {
  if (Session.getEffectiveUser().getEmail().toLowerCase() !== DEVELOPER_RECIPIENT) {
    throw new Error('Run this script as ' + DEVELOPER_RECIPIENT);
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
    console.log('Installed. Future tickets/comments will be checked every 5 minutes.');
  } finally {lock.releaseLock();}
}

// Returns 0..n MailApp payloads for one history document.
function messages_(doc) {
  const match = doc.name.match(/\/documents\/supportTickets\/([^/]+)\/history\/[^/]+$/);
  const h = doc.fields;
  if (!match) return [];
  const actorRole = h.actorRole?.stringValue;
  if (actorRole !== 'admin' && actorRole !== 'developer') return [];
  const action = h.action?.stringValue;
  const commentId = h.commentId?.stringValue;
  if (action !== 'created' && !commentId) return [];
  const actorId = h.actorId?.stringValue;
  if (!actorId || actorId.includes('/')) throw new Error('Invalid history actor');
  const actor = api_(ROOT + '/users/' + actorId).fields;
  if (actor.role?.stringValue !== actorRole || actor.isDisabled?.booleanValue !== false) {
    throw new Error('Actor role mismatch or disabled');
  }
  const ticketId = match[1];
  const ticket = api_(ROOT + '/supportTickets/' + ticketId).fields;
  const title = plain_(ticket.title?.stringValue, 160);
  if (!title) throw new Error('Missing ticket title');
  const link = 'https://dacha-annonce.web.app/support/' + encodeURIComponent(ticketId);
  let commentBody = null;
  let ticketBody = null;
  if (commentId) {
    if (commentId.includes('/')) throw new Error('Invalid comment ID');
    const comment = api_(ROOT + '/supportTickets/' + ticketId + '/comments/' + commentId).fields;
    if (comment.authorId?.stringValue !== actorId ||
        comment.authorRole?.stringValue !== actorRole ||
        comment.ticketVersion?.integerValue !== h.version?.integerValue) {
      throw new Error('Comment author/version mismatch');
    }
    commentBody = plain_(comment.body?.stringValue, 5000);
    if (!commentBody) throw new Error('Missing comment body');
  } else if (action === 'created') {
    if (ticket.createdBy?.stringValue !== actorId) throw new Error('Ticket author mismatch');
    ticketBody = plain_(ticket.body?.stringValue, 10000);
    if (!ticketBody) throw new Error('Missing ticket body');
  }

  const out = [];
  // New MI ticket → developer with full text duplicate.
  if (actorRole === 'admin' && action === 'created' && ticketBody) {
    out.push({
      to: DEVELOPER_RECIPIENT,
      subject: ('Дача — нове звернення: ' + title).replace(/[\r\n]/g, ' ').slice(0, 220),
      body: 'Нове звернення MI:\n\n' + title + '\n\n' + ticketBody + '\n\n' + link +
        '\n\nУвійдіть у застосунок, щоб відповісти в тікеті.',
      name: 'Дача — підтримка',
    });
  }
  // MI comment → developer (link; comment text goes to admin below).
  if (actorRole === 'admin' && commentId) {
    out.push({
      to: DEVELOPER_RECIPIENT,
      subject: ('Дача — новий коментар MI: ' + title).replace(/[\r\n]/g, ' ').slice(0, 220),
      body: 'Новий коментар MI\n\n' + title + '\n\n' + link +
        '\n\nДля перегляду увійдіть у свій обліковий запис розробника.',
      name: 'Дача — підтримка',
    });
  }
  // Any comment text → administrator inbox (full duplicate of the comment).
  if (commentBody) {
    const who = actorRole === 'admin' ? 'адміністрації' : 'розробника';
    out.push({
      to: ADMIN_RECIPIENT,
      subject: ('Дача — коментар до звернення: ' + title).replace(/[\r\n]/g, ' ').slice(0, 220),
      body: 'Коментар ' + who + ' до звернення «' + title + '»:\n\n' +
        commentBody + '\n\n' + link +
        '\n\nУвійдіть у застосунок, щоб відповісти в тікеті.',
      name: 'Дача — підтримка',
    });
  }
  return out;
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
      let messages;
      try {messages = messages_(doc);} catch (error) {
        const attempts = (state.pending?.attempts || 0) + 1;
        state.pending = {event: doc.name, attempts, status: attempts >= 5 ? 'failed' : 'retry',
          nextAttemptAt: Date.now() + Math.pow(2, attempts - 1) * 300000};
        save_(state); throw error;
      }
      if (messages.length) {
        if (MailApp.getRemainingDailyQuota() < messages.length) {
          throw new Error('Daily mail quota exhausted; will resume automatically.');
        }
        state.pending = {event: doc.name, status: 'sending'}; save_(state);
        try {
          for (const message of messages) MailApp.sendEmail(message);
        } catch (_) {
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
