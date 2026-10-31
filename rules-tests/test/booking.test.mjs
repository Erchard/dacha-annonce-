import '../environment.mjs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {Bytes,Timestamp,doc,getDoc,getDocs,collection,query,where,limit,setDoc,updateDoc,deleteDoc,serverTimestamp,writeBatch} from 'firebase/firestore';
import {environment,seed,dbFor,draft,start,ts,profile,room} from '../fixtures.mjs';
import {execute,blocks} from '../booking-client.mjs';
let env,admin,owner;
before(async()=>{env=await environment();});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await seed(env);admin=dbFor(env,'admin');owner=dbFor(env,'owner');});
const pending=(id='request')=>execute(owner,'owner',id,'createPending',{draft:draft()});
const approved=(id='event',data=draft())=>execute(admin,'admin',id,'createApproved',{draft:data});

test('gate: create approved occupies two blocks, then move across four blocks, then cancel',async()=>{
 await assertSucceeds(approved());
 const original=(await getDoc(doc(admin,'bookings/event'))).data();
 assert.equal(original.occupancyBlockIds.length,2);
 const moved=draft({roomId:'room-b',startAt:ts(start+86400000+1800000),endAt:ts(start+86400000+23400000)});
 await assertSucceeds(execute(admin,'admin','event','reschedule',{expectedVersion:1,draft:moved}));
 for(const path of blocks(original).keys()) assert.ok(Object.values((await getDoc(doc(admin,path))).data().slots).every(v=>v===''));
 const publicData=(await getDoc(doc(env.unauthenticatedContext().firestore(),'publicEvents/event'))).data();
 assert.equal(publicData.roomId,'room-b');assert.equal(publicData.organizerId,undefined);
 await assertSucceeds(execute(admin,'admin','event','cancel',{expectedVersion:2}));
 assert.equal((await getDoc(doc(admin,'publicEvents/event'))).exists(),false);
 for(const path of blocks(moved).keys()) assert.ok(Object.values((await getDoc(doc(admin,path))).data().slots).every(v=>v===''));
 assert.equal((await getDoc(doc(admin,'bookings/event/history/3'))).data().action,'cancel');
});

test('concurrent approvals: exactly one succeeds and leaves complete mirrors',async()=>{
 await pending('one');await pending('two');
 const result=await Promise.allSettled(['one','two'].map(id=>execute(admin,'admin',id,'approve',{expectedVersion:1})));
 assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
 for(const id of ['one','two']) {
  const b=(await getDoc(doc(admin,'bookings',id))).data();
  const p=await getDoc(doc(admin,'publicEvents',id));
  assert.equal(p.exists(),b.status==='approved');
  if(p.exists()) {assert.equal(b.version,2);assert.ok((await getDoc(doc(admin,`bookings/${id}/history/2`))).exists());}
 }
});

test('direct overlapping client write cannot steal slots even when conflict check is bypassed',async()=>{
 await approved('one');
 await assertFails(execute(admin,'admin','two','createApproved',{draft:draft(),checkConflicts:false}));
});

test('adjacent events and different rooms are allowed',async()=>{
 await approved('one',draft({endAt:ts(start+3600000)}));
 await approved('adjacent',draft({startAt:ts(start+3600000),endAt:ts(start+5400000)}));
 await approved('other-room',draft({roomId:'room-b'}));
});

for(const missing of ['occupancy','publicEvents','history']) test(`missing ${missing} is denied`,async()=>{
 await assertFails(execute(admin,'admin','broken','createApproved',{draft:draft(),tamper:plan=>{
  const index=plan.findIndex(p=>missing==='occupancy'?p.path.includes('/occupancy/'):missing==='history'?p.path.includes('/history/'):p.path.startsWith('publicEvents/'));
  plan.splice(index,1);
 }}));
});

test('forged public fields, audit actor and owner are denied',async()=>{
 for(const variant of ['public','actor','owner']) await assertFails(execute(admin,'admin','broken-'+variant,'createApproved',{draft:draft(),tamper:plan=>{
  if(variant==='public') plan.find(p=>p.path.startsWith('publicEvents/')).data.email='private@example.invalid';
  if(variant==='actor') plan.find(p=>p.path.includes('/history/')).data.actorRole='organizer';
  if(variant==='owner') plan.find(p=>p.path==='bookings/broken-owner').data.organizerId='other';
 }}));
});

test('partial release of old blocks denied; conflicting move preserves original booking',async()=>{
 await approved();
 await assertFails(execute(admin,'admin','event','reschedule',{expectedVersion:1,draft:draft({roomId:'room-b'}),tamper:plan=>{
  plan.splice(plan.findIndex(p=>p.path.startsWith('rooms/room-a/occupancy/')),1);
 }}));
 await approved('conflict',draft({roomId:'room-b'}));
 await assert.rejects(execute(admin,'admin','event','reschedule',{expectedVersion:1,draft:draft({roomId:'room-b'})}),/bookingConflict/);
 assert.equal((await getDoc(doc(admin,'bookings/event'))).data().roomId,'room-a');
});

test('organizer can cancel own approved event with locks, but other users/developer cannot read or approve',async()=>{
 await pending();await execute(admin,'admin','request','approve',{expectedVersion:1});
 for(const uid of ['other','developer','disabled']) {
  const db=dbFor(env,uid);
  await assertFails(getDoc(doc(db,'bookings/request')));
  await assertFails(execute(db,uid,'request','cancel',{expectedVersion:2}));
 }
 await assertSucceeds(execute(owner,'owner','request','cancel',{expectedVersion:2}));
});

test('unverified, disabled, inactive room and invalid interval submissions denied',async()=>{
 await assertFails(execute(dbFor(env,'owner',false),'owner','unverified','createPending',{draft:draft()}));
 await assertFails(execute(dbFor(env,'disabled'),'disabled','disabled','createPending',{draft:draft()}));
 for(const data of [draft({roomId:'archived'}),draft({endAt:ts(start+25200000)}),draft({startAt:ts(start+1)}),draft({title:'   '})])
  await assertFails(execute(owner,'owner','bad','createPending',{draft:data}));
});

test('unknown paths, orphan occupancy, delete locks and mutable history are denied',async()=>{
 await approved();
 const path=[...blocks(draft()).keys()][0];
 const lock=(await getDoc(doc(admin,path))).data();
 await assertFails(setDoc(doc(admin,'rooms/room-b/occupancy/'+path.split('/').at(-1)),{...lock,updatedAt:serverTimestamp()}));
 await assertFails(deleteDoc(doc(admin,path)));
 await assertFails(updateDoc(doc(admin,'bookings/event/history/1'),{actorId:'other'}));
 await assertFails(setDoc(doc(admin,'mail/job'),{to:'somewhere'}));
});

test('public reads require bounded active-room query; private reads and unbounded queries denied',async()=>{
 const visitor=env.unauthenticatedContext().firestore();
 await assertSucceeds(getDocs(query(collection(visitor,'rooms'),where('isActive','==',true),limit(25))));
 await assertFails(getDocs(query(collection(visitor,'rooms'),limit(25))));
 await assertFails(getDocs(query(collection(visitor,'rooms'),where('isActive','==',true))));
 for(const path of ['users/owner','rooms/archived','bookings/request','supportTickets/ticket']) await assertFails(getDoc(doc(visitor,path)));
 await pending();
 await assertSucceeds(getDocs(query(collection(owner,'bookings'),where('organizerId','==','owner'),limit(25))));
 await assertFails(getDocs(query(collection(owner,'bookings'),limit(25))));
});


test('forged occupancy version, extra slot and foreign owner are denied',async()=>{
 for(const variant of ['version','extra','actor'])await assertFails(execute(admin,'admin','witness-'+variant,'createApproved',{draft:draft(),tamper:plan=>{
  const lock=plan.find(p=>p.path.includes('/occupancy/')).data;
  if(variant==='version')lock.lastMutationVersion=999;
  if(variant==='extra')lock.slots.s00='witness-extra';
  if(variant==='actor')lock.lastMutationBookingId='another-booking';
 }}));
 await approved('valid-after-malicious');
});
test('standalone future-version witness cannot be prepared or replayed',async()=>{
 await approved();const path=[...blocks(draft()).keys()][0];
 const lock=(await getDoc(doc(admin,path))).data();
 await assertFails(setDoc(doc(admin,path),{...lock,lastMutationVersion:2,updatedAt:serverTimestamp()}));
 await assertFails(execute(admin,'admin','event','reschedule',{expectedVersion:1,draft:draft({roomId:'room-b'}),tamper:plan=>{
  for(const item of plan.filter(p=>p.path.includes('/occupancy/')))item.data.lastMutationVersion=1;
 }}));
 assert.equal((await getDoc(doc(admin,'bookings/event'))).data().version,1);
});
test('sub-millisecond intervals and foreign fields are rejected by full booking schema',async()=>{
 for(const patch of [{startAt:new Timestamp(Math.floor((start+1800000)/1000),1000)},{endAt:new Timestamp(Math.floor((start+23400000)/1000),1000)},{privateEmail:'x@example.invalid'},{createdAt:ts(start)}]){
  await assertFails(execute(owner,'owner','invalid-schema','createPending',{draft:draft(),tamper:plan=>Object.assign(plan.find(p=>p.path==='bookings/invalid-schema').data,patch)}));
 }
 await pending('valid-schema');
});
test('stale commands fail without overwriting the committed version',async()=>{
 await pending();await execute(admin,'admin','request','approve',{expectedVersion:1});
 await assert.rejects(execute(admin,'admin','request','cancel',{expectedVersion:1}),/staleVersion/);
 assert.equal((await getDoc(doc(admin,'bookings/request'))).data().status,'approved');
});


test('admin deletes event atomically, releases slots and preserves immutable history',async()=>{
 await approved();const before=(await getDoc(doc(admin,'bookings/event'))).data();
 await assertSucceeds(execute(admin,'admin','event','delete',{expectedVersion:1}));
 assert.equal((await getDoc(doc(admin,'bookings/event'))).data().status,'deleted');
 assert.equal((await getDoc(doc(admin,'publicEvents/event'))).exists(),false);
 for(const path of blocks(before).keys()) assert.ok(Object.values((await getDoc(doc(admin,path))).data().slots).every(v=>v===''));
 assert.equal((await getDoc(doc(admin,'bookings/event/history/2'))).data().action,'delete');
 await assertFails(execute(admin,'admin','event','edit',{expectedVersion:2,draft:draft()}));
 await approved('replacement');
});
test('deletion refuses missing witnesses and cannot mutate unrelated booking fields',async()=>{
 await approved();
 for(const variant of ['occupancy','history','public','title']) await assertFails(execute(admin,'admin','event','delete',{expectedVersion:1,tamper:plan=>{
  if(variant==='title')plan.find(p=>p.path==='bookings/event').data.title='Forged title';
  else plan.splice(plan.findIndex(p=>variant==='occupancy'?p.path.includes('/occupancy/'):variant==='history'?p.path.includes('/history/'):p.path.startsWith('publicEvents/')),1);
 }}));
 assert.equal((await getDoc(doc(admin,'bookings/event'))).data().status,'approved');
});
test('ordinary organizers cannot delete; admin may delete cancelled and pending requests',async()=>{
 await pending();await assertFails(execute(owner,'owner','request','delete',{expectedVersion:1}));
 await assertSucceeds(execute(admin,'admin','request','delete',{expectedVersion:1}));
 await approved();await execute(admin,'admin','event','cancel',{expectedVersion:1});
 await assertSucceeds(execute(admin,'admin','event','delete',{expectedVersion:2}));
});

test('trusted organizer publishes and manages own events only; revoked permission takes effect',async()=>{
 await assertFails(execute(owner,'owner','ordinary','createApproved',{draft:draft()}));
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'users/owner'),{canPublish:true}));
 await assertSucceeds(execute(owner,'owner','own','createApproved',{draft:draft()}));
 await assertSucceeds(execute(owner,'owner','own','edit',{expectedVersion:1,draft:draft({title:'Змінена подія'})}));
 await assertSucceeds(execute(owner,'owner','own','reschedule',{expectedVersion:2,draft:draft({roomId:'room-b'})}));
 await approved('admin-event');
 await assertFails(execute(owner,'owner','admin-event','delete',{expectedVersion:1}));
 await assertSucceeds(execute(owner,'owner','own','delete',{expectedVersion:3}));
 await assertSucceeds(execute(owner,'owner','second','createApproved',{draft:draft({roomId:'room-b'})}));
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'users/owner'),{canPublish:false}));
 await assertFails(execute(owner,'owner','second','edit',{expectedVersion:1,draft:draft({roomId:'room-b',title:'Не дозволено'})}));
 await assertFails(execute(owner,'owner','second','delete',{expectedVersion:1}));
});

test('admin deletes a past approved event and releases historical occupancy', async () => {
 const past = Math.floor((Date.now() - 86400000) / 1800000) * 1800000;
 await env.withSecurityRulesDisabled(async context => {
  await execute(context.firestore(), 'admin', 'past', 'createApproved', {
   draft: draft({startAt: ts(past), endAt: ts(past + 3600000)}),
  });
 });
 const before = (await getDoc(doc(admin, 'bookings/past'))).data();
 await assertFails(execute(owner, 'owner', 'past', 'delete', {expectedVersion: 1}));
 await assertSucceeds(execute(admin, 'admin', 'past', 'delete', {expectedVersion: 1}));
 assert.equal((await getDoc(doc(admin, 'publicEvents/past'))).exists(), false);
 assert.equal((await getDoc(doc(admin, 'bookings/past'))).data().status, 'deleted');
 for (const path of blocks(before).keys()) {
  assert.ok(Object.values((await getDoc(doc(admin, path))).data().slots).every(v => v === ''));
 }
 assert.equal((await getDoc(doc(admin, 'bookings/past/history/2'))).data().action, 'delete');
});

test('schedule details publish, filter and edit; forged projections and invalid fields denied', async () => {
 const cover={coverImageBytes:Bytes.fromUint8Array(Uint8Array.from([1,2,3,4])),coverImageContentType:'image/jpeg',coverImageFileName:'poster.jpg'};
 const details={contactPhone:'+380 00 000 00 00',notes:'Взяти блокнот',directions:['Культура','Для дітей'],...cover};
 await assertSucceeds(approved('details',draft(details)));
 const pub=env.unauthenticatedContext().firestore();
 assert.equal((await getDoc(doc(pub,'publicEvents/details'))).data().notes,details.notes);
 assert.equal((await getDoc(doc(pub,'publicEvents/details'))).data().coverImageFileName,'poster.jpg');
 const found=await assertSucceeds(getDocs(query(collection(pub,'publicEvents'),where('directions','array-contains-any',['Культура']),limit(100))));
 assert.equal(found.size,1);
 await assertFails(execute(admin,'admin','details','edit',{expectedVersion:1,draft:draft(details),tamper:plan=>{plan.find(p=>p.path==='publicEvents/details').data.contactPhone='12345';}}));
 await assertSucceeds(execute(admin,'admin','details','edit',{expectedVersion:1,draft:draft({...details,notes:'Оновлено'})}));
 assert.equal((await getDoc(doc(pub,'publicEvents/details'))).data().notes,'Оновлено');
 for(const patch of [{coverImageContentType:'text/html'},{coverImageFileName:''},{coverImageBytes:Bytes.fromUint8Array(new Uint8Array(700001))},{coverImageBytes:null},{directions:['Невідомий']},{directions:['Клуб','Клуб']},{directions:'Клуб'},{notes:'x'.repeat(501)},{contactPhone:'not a phone'},{contactPhone:null},{coverImageContentType:'image/gif'},{coverImageBytes:null},{coverImageFileName:''}]) {
  await assertFails(execute(admin,'admin','details','edit',{expectedVersion:2,draft:draft({...details,...patch})}));
 }
 await assertFails(execute(owner,'owner','details','edit',{expectedVersion:2,draft:draft(details)}));
 await assertSucceeds(execute(admin,'admin','details','reschedule',{expectedVersion:2,draft:draft({...details,roomId:'room-b'})}));
 assert.equal((await getDoc(doc(pub,'publicEvents/details'))).data().contactPhone,details.contactPhone);
 assert.equal((await getDoc(doc(pub,'publicEvents/details'))).data().coverImageFileName,'poster.jpg');
 await assertSucceeds(execute(admin,'admin','details','delete',{expectedVersion:3}));
});
