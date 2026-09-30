import './environment.mjs';
import {doc,setDoc} from 'firebase/firestore';
import {environment,profile,room,dbFor,ts} from './fixtures.mjs';
import {execute} from './booking-client.mjs';
export const demoPassword='LocalDemo123!';
export async function seedDemo(){
 const base='http://127.0.0.1:9099';
 async function auth(method,data){const response=await fetch(`${base}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=demo-dacha-local-key`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});const result=await response.json();if(!response.ok)throw new Error(`Emulator Auth ${method}: ${result.error?.message}`);return result;}
 const response=await fetch(`${base}/emulator/v1/projects/demo-dacha/accounts`,{method:'DELETE'});if(!response.ok)throw new Error('Local Auth reset failed');
 const env=await environment();
 try{
  await env.clearFirestore();
  const accounts={};
  for(const [name,role,disabled] of [['admin','admin',false],['organizer','organizer',false],['developer','developer',false],['disabled','organizer',true]]){
   const email=`${name}@example.test`,account=await auth('signUp',{email,password:demoPassword,returnSecureToken:true});
   await auth('sendOobCode',{requestType:'VERIFY_EMAIL',idToken:account.idToken});
   const codes=await (await fetch(`${base}/emulator/v1/projects/demo-dacha/oobCodes`)).json();
   const code=codes.oobCodes.find(c=>c.email===email&&c.requestType==='VERIFY_EMAIL');if(!code)throw new Error('Verification code absent');
   await auth('update',{oobCode:code.oobCode});
   accounts[name]={uid:account.localId,email};
   await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users',account.localId),profile(account.localId,role,disabled)));
  }
  await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'rooms/room-a'),room('Велика кімната'));await setDoc(doc(c.firestore(),'rooms/room-b'),room('Мала кімната'));});
  const start=Math.ceil((Date.now()+86400000)/1800000)*1800000;
  await execute(dbFor(env,accounts.admin.uid),accounts.admin.uid,'demo-event','createApproved',{draft:{roomId:'room-a',title:'Зустріч на Дачі',description:'Відкрита зустріч для спільних справ.',startAt:ts(start),endAt:ts(start+3600000)}});
  console.log('Local demo ready: admin / organizer / developer / disabled @example.test. Password: LocalDemo123!');
 }finally{await env.cleanup();}
}
if(process.argv[1]?.endsWith('seed.mjs'))await seedDemo();
