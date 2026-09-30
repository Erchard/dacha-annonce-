import './environment.mjs';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,setDoc,Timestamp} from 'firebase/firestore';
export const stamp = Timestamp.fromMillis(Date.now());
export const start = Math.ceil(Date.now()/21600000)*21600000 + 7*86400000;
export const ts = millis => Timestamp.fromMillis(millis);
export async function environment() {
 return initializeTestEnvironment({projectId:'demo-dacha',firestore:{host:'127.0.0.1',port:8080,
  rules:await readFile(new URL('./../firestore.rules',import.meta.url),'utf8')}});
}
export function profile(uid,role='organizer',isDisabled=false) {
 return {displayName:uid,role,isDisabled,createdAt:stamp,updatedAt:stamp,createdBy:uid,updatedBy:uid,
  schemaVersion:1,adminRevision:0,lastAdminAuditId:null};
}
export function room(name,isActive=true) {
 return {name,description:'',locationLabel:'Дача',capacity:20,isActive,sortOrder:0,createdAt:stamp,updatedAt:stamp,
  schemaVersion:1,revision:1,lastAuditId:'seed-room'};
}
export async function seed(env) {
 await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore();
  await Promise.all([
   ...[['admin','admin'],['admin2','admin'],['owner','organizer'],['other','organizer'],['developer','developer'],['disabled','organizer',true]].map(([uid,role,disabled])=>setDoc(doc(db,'users',uid),profile(uid,role,disabled))),
   ...[['room-a',true],['room-b',true],['archived',false]].map(([id,active])=>setDoc(doc(db,'rooms',id),room(id,active))),
  ]);
 });
}
export const draft = (overrides={})=>({roomId:'room-a',title:'Зустріч громади',description:'Публічний опис',startAt:ts(start+1800000),endAt:ts(start+23400000),...overrides});
export const dbFor = (env,uid,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();

