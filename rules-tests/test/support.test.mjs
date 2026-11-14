import '../environment.mjs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,query,limit,where,orderBy,updateDoc,setDoc,deleteDoc} from 'firebase/firestore';
import {environment,seed,dbFor} from '../fixtures.mjs';
import {ticketCommand} from '../support-client.mjs';
let env;
before(async()=>{env=await environment();});after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await seed(env);});
const roleOf=actor=>actor==='developer'?'developer':actor==='admin'||actor==='admin2'?'admin':'organizer';
const cmd=(actor,action,options={},id='ticket')=>ticketCommand(dbFor(env,actor),actor,roleOf(actor),id,action,options);
async function created(){await cmd('admin','created');}
test('support lifecycle with required reopen comment and immutable history',async()=>{
 await created();
 await assertFails(cmd('admin','status_changed',{expectedVersion:1,status:'accepted'}));
 await cmd('developer','status_changed',{expectedVersion:1,status:'accepted'});
 await cmd('developer','status_changed',{expectedVersion:2,status:'in_progress'});
 await cmd('developer','status_changed',{expectedVersion:3,status:'done'});
 await assertFails(cmd('admin','status_changed',{expectedVersion:4,status:'new'}));
 await cmd('admin','status_changed',{expectedVersion:4,status:'new',comment:'Проблема залишилася після перевірки.'});
 await cmd('developer','status_changed',{expectedVersion:5,status:'accepted'});
 await cmd('developer','status_changed',{expectedVersion:6,status:'rejected'});
 await cmd('admin','status_changed',{expectedVersion:7,status:'closed'});
 await cmd('admin','commented',{expectedVersion:8,comment:'Дякую за пояснення.'});
 const db=dbFor(env,'developer');
 assert.equal((await getDoc(doc(db,'supportTickets/ticket'))).data().status,'closed');
 assert.equal((await getDocs(query(collection(db,'supportTickets/ticket/history'),limit(100)))).size,9);
 await assertFails(updateDoc(doc(db,'supportTickets/ticket/history/1'),{action:'commented'}));
 await assertFails(deleteDoc(doc(db,'supportTickets/ticket/comments/comment-5')));
});
test('support roles, bounded queries and creation validation',async()=>{
 for(const actor of ['owner','developer','disabled'])await assertFails(cmd(actor,'created'));
 await assertFails(cmd('admin','created',{omitHistory:true}));
 for(const tamper of [({next})=>next.priority='high',({next})=>next.createdBy='other',({next})=>next.title='x',({next})=>next.secret='extra'])await assertFails(cmd('admin','created',{tamper}));
 await created();
 for(const who of ['owner','other','disabled',null]){
  const db=who?dbFor(env,who):env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db,'supportTickets/ticket')));
  await assertFails(getDocs(query(collection(db,'supportTickets'),limit(25))));
 }
 await assertSucceeds(getDocs(query(collection(dbFor(env,'developer'),'supportTickets'),limit(25))));
 await assertFails(getDocs(collection(dbFor(env,'admin'),'supportTickets')));
});
test('organizer can create feedback, list own tickets and read comments',async()=>{
 await assertSucceeds(cmd('owner','created',{type:'feedback'},'fb-owner'));
 await assertFails(cmd('owner','created',{type:'bug'},'fb-bug'));
 await assertFails(cmd('owner','created',{type:'general'},'fb-general'));
 const owner=dbFor(env,'owner');
 await assertSucceeds(getDoc(doc(owner,'supportTickets/fb-owner')));
 await assertSucceeds(getDocs(query(collection(owner,'supportTickets'),where('createdBy','==','owner'),orderBy('lastActivityAt','desc'),limit(25))));
 await assertFails(getDocs(query(collection(owner,'supportTickets'),limit(25))));
 await assertSucceeds(getDocs(query(collection(owner,'supportTickets/fb-owner/history'),limit(25))));
 await assertSucceeds(getDocs(query(collection(owner,'supportTickets/fb-owner/comments'),limit(25))));
 const other=dbFor(env,'other');
 await assertFails(getDoc(doc(other,'supportTickets/fb-owner')));
 await assertFails(getDocs(query(collection(other,'supportTickets/fb-owner/comments'),limit(25))));
});
test('admin can create general questions type; organizer cannot',async()=>{
 await assertSucceeds(cmd('admin','created',{type:'general'},'gen-admin'));
 await assertFails(cmd('owner','created',{type:'general'},'gen-org'));
 await assertFails(cmd('developer','created',{type:'general'},'gen-dev'));
});
test('admin can edit type on new ticket; not after accept',async()=>{
 await created();
 await assertSucceeds(cmd('admin','edited',{expectedVersion:1,type:'general',title:'Оновлена тема звернення',body:'Оновлений опис звернення для тесту.'}));
 await assertFails(cmd('developer','edited',{expectedVersion:2,type:'bug',title:'Тема від розробника',body:'Опис від розробника має бути довгим.'}));
 await cmd('developer','status_changed',{expectedVersion:2,status:'accepted'});
 await assertFails(cmd('admin','edited',{expectedVersion:3,type:'feature',title:'Після прийняття',body:'Тип уже не можна змінити поза new.'}));
});
test('comments and priority require exact atomic history and correct actor',async()=>{
 await created();
 await assertFails(cmd('admin','priority_changed',{expectedVersion:1,priority:'high'}));
 await cmd('developer','priority_changed',{expectedVersion:1,priority:'high'});
 await assertFails(cmd('admin','commented',{expectedVersion:2,comment:'Коментар',omitHistory:true}));
 await assertFails(cmd('admin','commented',{expectedVersion:2,comment:'Коментар',omitComment:true}));
 for(const tamper of [({c})=>c.authorRole='developer',({history})=>history.actorId='other',({next})=>next.body='Переписаний текст звернення',({c})=>c.body=' ',({c})=>c.ticketVersion=99])await assertFails(cmd('admin','commented',{expectedVersion:2,comment:'Коментар',tamper}));
 await cmd('admin','commented',{expectedVersion:2,comment:'Коментар'});
 await assertFails(setDoc(doc(dbFor(env,'admin'),'supportTickets/ticket/comments/orphan'),{body:'Зайвий коментар'}));
});
test('concurrent comments detect stale version and never silently overwrite',async()=>{
 await created();
 const results=await Promise.allSettled([cmd('admin','commented',{expectedVersion:1,comment:'Від адміністрації'}),cmd('developer','commented',{expectedVersion:1,comment:'Від розробника'})]);
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
 const loser=results[0].status==='rejected'?'admin':'developer';
 await cmd(loser,'commented',{expectedVersion:2,comment:'Повтор після оновлення'});
 const db=dbFor(env,'admin');assert.equal((await getDocs(query(collection(db,'supportTickets/ticket/comments'),limit(25)))).size,2);
});

test('every support status edge matches the role transition table',async()=>{
 const statuses=['new','accepted','in_progress','done','rejected','closed'];
 const allowed={admin:{done:['closed','new'],rejected:['closed','new'],closed:['new']},developer:{new:['accepted','in_progress','rejected'],accepted:['in_progress','rejected'],in_progress:['done'],done:['closed','new'],rejected:['closed','new'],closed:['new']}};
 await created();const fixture=(await getDoc(doc(dbFor(env,'admin'),'supportTickets/ticket'))).data();
 for(const role of ['admin','developer'])for(const from of statuses)for(const to of statuses){
  const id=`${role}-${from}-${to}`;
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'supportTickets',id),{...fixture,status:from}));
  const operation=cmd(role,'status_changed',{expectedVersion:1,status:to,comment:'Пояснення переходу статусу'},id);
  if(allowed[role][from]?.includes(to))await assertSucceeds(operation);else await assertFails(operation);
 }
});
test('admin can hard-delete new ticket and its subdocs; not after accept',async()=>{
 await created();
 const admin=dbFor(env,'admin');
 await assertSucceeds(deleteDoc(doc(admin,'supportTickets/ticket/history/1')));
 await assertSucceeds(deleteDoc(doc(admin,'supportTickets/ticket')));
 await cmd('admin','created',{},'keep-new');
 await cmd('developer','status_changed',{expectedVersion:1,status:'accepted'},'keep-new');
 await assertFails(deleteDoc(doc(admin,'supportTickets/keep-new/history/1')));
 await assertFails(deleteDoc(doc(admin,'supportTickets/keep-new')));
 await assertFails(deleteDoc(doc(dbFor(env,'owner'),'supportTickets/keep-new')));
});
