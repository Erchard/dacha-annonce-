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
   if(path.endsWith('/users/mi'))return {fields:{role:sv('admin'),isDisabled:{booleanValue:false}}};
   if(path.endsWith('/supportTickets/t'))return {fields:{title:sv('Назва'),body:sv('PRIVATE'),createdBy:sv('mi')}};
   if(path.endsWith('/comments/comment'))return {fields:{authorId:sv('mi'),authorRole:sv(role),ticketVersion:{integerValue:'1'}}};
   if(path===doc.name)return doc;
   throw Error('Unexpected path '+path);
 };
 return {context,doc,sent,state:()=>JSON.parse(saved),failMail:()=>failMail=true,failRead:()=>failRead=true,quotaZero:()=>quota=0,lock:()=>locked=true,
 setState:s=>saved=JSON.stringify(s)};
}
test('MI ticket sends fixed recipient/link without body; second poll does not duplicate',()=>{
 const f=fixture();f.context.sendNotifications();f.context.sendNotifications();assert.equal(f.sent.length,1);assert.equal(f.sent[0].to,'arsenguzhva@gmail.com');assert.match(f.sent[0].body,/support\/t/);assert.ok(!f.sent[0].body.includes('PRIVATE'));assert.ok(f.state().cursor);
});
test('MI comment sends one notification, including comment attached to status change',()=>{
 for(const action of ['commented','status_changed']){const f=fixture('admin',action);f.context.sendNotifications();assert.equal(f.sent.length,1);assert.match(f.sent[0].subject,/коментар/);}
});
test('developer comments and unrelated history do not send mail',()=>{
 for(const role of ['developer','organizer']){const f=fixture(role,'commented');f.context.sendNotifications();assert.equal(f.sent.length,0);}
 const f=fixture();f.doc.name=root+'/bookings/t/history/1';f.context.sendNotifications();assert.equal(f.sent.length,0);
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
