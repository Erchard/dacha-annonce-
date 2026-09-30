import '../environment.mjs';
import {before,after,beforeEach,test} from 'node:test';
import {assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
import {environment,seed,dbFor,profile,room} from '../fixtures.mjs';
let env,admin;
before(async()=>{env=await environment();});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await seed(env);admin=dbFor(env,'admin');});
const view=r=>Object.fromEntries(['name','description','locationLabel','capacity','isActive','sortOrder'].map(k=>[k,r[k]]));
function roomBatch({omitAudit=false,forged=false}={}) {
 const batch=writeBatch(admin);const r={...room('Нова кімната'),createdAt:serverTimestamp(),updatedAt:serverTimestamp(),lastAuditId:'room-created'};
 batch.set(doc(admin,'rooms/new-room'),r);
 if(!omitAudit)batch.set(doc(admin,'adminAudit/room-created'),{entityType:'room',entityId:'new-room',action:'create',actorId:forged?'other':'admin',at:serverTimestamp(),revision:1,before:{},after:view(r),changedFields:Object.keys(view(r))});
 return batch.commit();
}
test('room creation requires exact atomic audit',async()=>{
 await assertFails(roomBatch({omitAudit:true}));await assertFails(roomBatch({forged:true}));await assertSucceeds(roomBatch());
 await assertFails(updateDoc(doc(admin,'rooms/new-room'),{name:'Без аудиту',updatedAt:serverTimestamp(),revision:2}));
 await assertFails(updateDoc(doc(admin,'adminAudit/room-created'),{actorId:'other'}));
});
test('organizer blocking requires audit and cannot change role',async()=>{
 const ref=doc(admin,'users/owner');
 await assertFails(updateDoc(ref,{isDisabled:true,updatedAt:serverTimestamp(),updatedBy:'admin',adminRevision:1,lastAdminAuditId:'disabled-owner'}));
 const batch=writeBatch(admin);
 batch.update(ref,{isDisabled:true,updatedAt:serverTimestamp(),updatedBy:'admin',adminRevision:1,lastAdminAuditId:'disabled-owner'});
 batch.set(doc(admin,'adminAudit/disabled-owner'),{entityType:'user',entityId:'owner',action:'set_disabled',actorId:'admin',at:serverTimestamp(),revision:1,before:{isDisabled:false},after:{isDisabled:true},changedFields:['isDisabled']});
 await assertSucceeds(batch.commit());
 await assertFails(updateDoc(ref,{role:'admin',updatedAt:serverTimestamp(),updatedBy:'admin'}));
 await assertSucceeds(getDoc(doc(dbFor(env,'owner'),'users/owner')));
 await assertFails(updateDoc(doc(dbFor(env,'owner'),'users/owner'),{displayName:'Зміна імені',updatedAt:serverTimestamp(),updatedBy:'owner'}));
});
test('profile registration cannot forge role, owner or additional fields',async()=>{
 const db=dbFor(env,'new-user');const data={...profile('new-user'),createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
 for(const patch of [{role:'admin'},{createdBy:'admin'},{isDisabled:true},{email:'private@example.invalid'},{schemaVersion:2}])await assertFails(setDoc(doc(db,'users/new-user'),{...data,...patch}));
 await assertSucceeds(setDoc(doc(db,'users/new-user'),data));
 await assertFails(updateDoc(doc(db,'users/new-user'),{role:'developer',updatedAt:serverTimestamp()}));
 await assertFails(getDoc(doc(dbFor(env,'developer'),'adminAudit/anything')));
});
