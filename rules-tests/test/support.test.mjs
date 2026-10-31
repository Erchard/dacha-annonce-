import '../environment.mjs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,query,limit,updateDoc,setDoc,deleteDoc} from 'firebase/firestore';
import {environment,seed,dbFor} from '../fixtures.mjs';
import {ticketCommand} from '../support-client.mjs';
let env;
before(async()=>{env=await environment();});after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await seed(env);});
const cmd=(actor,action,options={},id='ticket')=>ticketCommand(dbFor(env,actor),actor,actor==='developer'?'developer':'admin',id,action,options);
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
 const allowed={admin:{new:['closed'],done:['closed','new'],rejected:['closed','new'],closed:['new']},developer:{new:['accepted','in_progress','rejected'],accepted:['in_progress','rejected'],in_progress:['done'],done:['closed','new'],rejected:['closed','new'],closed:['new']}};
 await created();const fixture=(await getDoc(doc(dbFor(env,'admin'),'supportTickets/ticket'))).data();
 for(const role of ['admin','developer'])for(const from of statuses)for(const to of statuses){
  const id=`${role}-${from}-${to}`;
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'supportTickets',id),{...fixture,status:from}));
  const operation=cmd(role,'status_changed',{expectedVersion:1,status:to,comment:'Пояснення переходу статусу'},id);
  if(allowed[role][from]?.includes(to))await assertSucceeds(operation);else await assertFails(operation);
 }
});
