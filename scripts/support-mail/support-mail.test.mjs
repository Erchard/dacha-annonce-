import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const code=readFileSync(new URL('./Code.gs',import.meta.url),'utf8');
const root='projects/dacha-annonce/databases/(default)/documents';
const sv=stringValue=>({stringValue});
function fixture(role='admin',action='created') {
 const h={actorRole:sv(role),actorId:sv('mi'),action:sv(action),at:{timestampValue:'2026-09-29T12:00:00.000Z'},version:{integerValue:'1'},commentId:action==='created'?{nullValue:null}:sv('comment')};
 const doc={name:root+'/supportTickets/t/history/1',fields:h};
 let saved=JSON.stringify({cursor:null,since:'2026-09-29T11:00:00.000Z',pending:null});
 const sent=[];let failMail=false,failRead=false,quota=100,locked=false;
 const context=vm.createContext({console:{log(){}},PropertiesService:{getScriptProperties:()=>({getProperty:()=>saved,setProperty:(k,v)=>{saved=v;}})},
 LockService:{getScriptLock:()=>({tryLock:()=>!locked,waitLock(){},releaseLock(){}})},
 MailApp:{getRemainingDailyQuota:()=>quota,sendEmail:m=>{sent.push(m);if(failMail)throw Error('uncertain');}}});
 vm.runInContext(code,context);
 context.api_=(path,body)=>{
   if(failRead)throw Error('Firestore HTTP 503');
   if(path.endsWith(':runQuery'))return body.structuredQuery.startAt?[]:[{document:doc}];
   if(path.endsWith('/users/mi'))return {fields:{role:sv(role),isDisabled:{booleanValue:false}}};
   if(path.endsWith('/users/dev'))return {fields:{role:sv('developer'),isDisabled:{booleanValue:false}}};
   if(path.endsWith('/supportTickets/t'))return {fields:{title:sv('Назва'),body:sv('PRIVATE'),createdBy:sv('mi')}};
   if(path.endsWith('/comments/comment'))return {fields:{authorId:sv(h.actorId.stringValue),authorRole:sv(role),ticketVersion:{integerValue:'1'},body:sv('Текст коментаря SECRET')}};
   if(path===doc.name)return doc;
   throw Error('Unexpected path '+path);
 };
 return {context,doc,sent,state:()=>JSON.parse(saved),failMail:()=>failMail=true,failRead:()=>failRead=true,quotaZero:()=>quota=0,lock:()=>locked=true,
 setState:s=>saved=JSON.stringify(s),h};
}
test('MI ticket duplicates full text to developer; second poll does not resend',()=>{
 const f=fixture();f.context.sendNotifications();f.context.sendNotifications();assert.equal(f.sent.length,1);assert.equal(f.sent[0].to,'arsenguzhva@gmail.com');assert.match(f.sent[0].body,/support\/t/);assert.match(f.sent[0].body,/PRIVATE/);assert.match(f.sent[0].subject,/нове звернення/);assert.ok(f.state().cursor);
});
test('MI comment emails developer and duplicates comment text to admin',()=>{
 for(const action of ['commented','status_changed']){
  const f=fixture('admin',action);f.context.sendNotifications();
  assert.equal(f.sent.length,2);
  assert.equal(f.sent[0].to,'arsenguzhva@gmail.com');
  assert.match(f.sent[0].subject,/коментар/);
  assert.equal(f.sent[1].to,'mkyrylenko@ukr.net');
  assert.match(f.sent[1].body,/Текст коментаря SECRET/);
  assert.ok(!f.sent[0].body.includes('SECRET'));
 }
});
test('developer comment duplicates text to admin only',()=>{
 const f=fixture('developer','commented');
 f.h.actorId=sv('dev');
 f.doc.fields.actorId=sv('dev');
 f.context.sendNotifications();
 assert.equal(f.sent.length,1);
 assert.equal(f.sent[0].to,'mkyrylenko@ukr.net');
 assert.match(f.sent[0].body,/Текст коментаря SECRET/);
 assert.match(f.sent[0].subject,/коментар/);
});
test('unrelated history and organizer do not send mail',()=>{
 const f=fixture('organizer','commented');f.context.sendNotifications();assert.equal(f.sent.length,0);
 const g=fixture();g.doc.name=root+'/bookings/t/history/1';g.context.sendNotifications();assert.equal(g.sent.length,0);
});
test('mismatched comment author is rejected before sending',()=>{
 const f=fixture('admin','commented');f.doc.fields.actorId=sv('other');assert.throws(()=>f.context.sendNotifications());assert.equal(f.sent.length,0);assert.equal(f.state().pending.status,'retry');
});
test('ambiguous mail failure is held for manual review, no automatic duplicates',()=>{
 const f=fixture();f.failMail();assert.throws(()=>f.context.sendNotifications());assert.throws(()=>f.context.sendNotifications());assert.equal(f.sent.length,1);assert.equal(f.state().pending.status,'uncertain');assert.equal(f.state().cursor,null);
});
test('crash in sending state stops instead of silently retrying',()=>{
 const f=fixture();f.setState({...f.state(),pending:{event:f.doc.name,status:'sending'}});assert.throws(()=>f.context.sendNotifications());assert.equal(f.sent.length,0);assert.equal(f.state().pending.status,'uncertain');
});
test('quota exhaustion and concurrent execution preserve cursor',()=>{
 const f=fixture();f.quotaZero();assert.throws(()=>f.context.sendNotifications());assert.equal(f.sent.length,0);assert.equal(f.state().cursor,null);
 const g=fixture();g.lock();g.context.sendNotifications();assert.equal(g.sent.length,0);
});
test('explicitly confirmed delivery advances cursor without resending',()=>{
 const f=fixture();f.setState({...f.state(),pending:{event:f.doc.name,status:'uncertain'}});f.context.confirmPendingDelivered();f.context.sendNotifications();assert.equal(f.sent.length,0);assert.ok(f.state().cursor);assert.equal(f.state().pending,null);
});
test('retry after manual inbox check re-enables pending event',()=>{
 const f=fixture();f.setState({...f.state(),pending:{event:f.doc.name,status:'uncertain'}});f.context.retryPendingDelivery();f.context.sendNotifications();assert.equal(f.sent.length,1);
});
