import {doc,runTransaction,serverTimestamp,Timestamp} from 'firebase/firestore';
export const keys=Array.from({length:12},(_,i)=>'s'+String(i).padStart(2,'0'));
export function blocks(booking) {
 const result=new Map();
 for(let t=booking.startAt.toMillis();t<booking.endAt.toMillis();t+=1800000) {
  const base=Math.floor(t/21600000)*21600000;
  const path=`rooms/${booking.roomId}/occupancy/${base/1000}`;
  if(!result.has(path)) result.set(path,{base,indices:[]});
  result.get(path).indices.push((t-base)/1800000);
 }
 return result;
}
export async function execute(db,actor,id,action,{expectedVersion=0,draft={},reason=null,tamper,checkConflicts=true}={}) {
 return runTransaction(db,async tx=>{
  const ref=doc(db,'bookings',id);
  const snap=await tx.get(ref); const b=snap.exists()?snap.data():null;
  if((b?.version??0)!==expectedVersion) throw new Error('staleVersion');
  const actorProfile=(await tx.get(doc(db,'users',actor))).data();
  const now=serverTimestamp();
  const n=b?{...b}:{...draft,organizerId:actor,timeZone:'Europe/Kyiv',status:'pending',roomNameSnapshot:'',locationSnapshot:'',responsibleName:draft.responsibleName??'',
   rejectionReason:null,cancellationReason:null,reviewedAt:null,reviewedBy:null,cancelledAt:null,cancelledBy:null,createdAt:now,createdBy:actor,schemaVersion:1};
  if(['edit','reschedule'].includes(action)) Object.assign(n,draft);
  if(typeof n.responsibleName!=='string') n.responsibleName='';
  if(action==='createApproved'||action==='approve') n.status='approved';
  if(action==='reject') {n.status='rejected';n.rejectionReason=reason;}
  if(action==='cancel') {n.status='cancelled';n.cancelledAt=now;n.cancelledBy=actor;n.cancellationReason=reason;}
  n.version=expectedVersion+1;n.updatedAt=now;n.updatedBy=actor;
  n.lastAction=action.startsWith('create')?'create':action;
  if(['createApproved','approve','reject'].includes(action)) {n.reviewedAt=now;n.reviewedBy=actor;}
  const occupied=blocks(n);n.occupancyBlockIds=[...occupied.values()].map(x=>String(x.base/1000));
  if(n.status==='pending'||n.status==='approved') {
   const room=(await tx.get(doc(db,'rooms',n.roomId))).data();
   if(['createApproved','approve','reschedule'].includes(action)) {n.roomNameSnapshot=room.name;n.locationSnapshot=room.locationLabel;}
  }
  const old=b?.status==='approved'?blocks(b):new Map();
  const next=n.status==='approved'?occupied:new Map();
  const paths=[...new Set([...old.keys(),...next.keys()])];
  const existing=new Map();
  for(const path of paths) existing.set(path,(await tx.get(doc(db,path))).data());
  const publicRef=doc(db,'publicEvents',id);
  const previousPublic=b?.status==='approved'?(await tx.get(publicRef)).data():null;
  const plan=[];
  for(const path of paths) {
   const metadata=old.get(path)??next.get(path);
   const slots={...(existing.get(path)?.slots??Object.fromEntries(keys.map(k=>[k,''])))};
   for(const i of old.get(path)?.indices??[]) {
    if(checkConflicts && slots[keys[i]]!==id) throw new Error('integrity');
    slots[keys[i]]='';
   }
   for(const i of next.get(path)?.indices??[]) {
    if(checkConflicts && slots[keys[i]]!=='' && slots[keys[i]]!==id) throw new Error('bookingConflict');
    slots[keys[i]]=id;
   }
   plan.push({path,data:{blockStartAt:Timestamp.fromMillis(metadata.base),slots,lastMutationBookingId:id,lastMutationVersion:n.version,updatedAt:now,updatedBy:actor,schemaVersion:1}});
  }
  plan.push({path:`bookings/${id}`,data:n});
  plan.push({path:`bookings/${id}/history/${n.version}`,data:{version:n.version,action:n.lastAction,actorId:actor,actorRole:actorProfile.role,
   at:now,fromStatus:b?.status??null,toStatus:n.status,oldRoomId:b?.roomId??null,newRoomId:n.roomId,
   oldStartAt:b?.startAt??null,oldEndAt:b?.endAt??null,newStartAt:n.startAt,newEndAt:n.endAt}});
  if(n.status==='approved') {
   const data=Object.fromEntries(['title','description','roomId','roomNameSnapshot','locationSnapshot','responsibleName','startAt','endAt','timeZone'].map(k=>[k,n[k]]));
   Object.assign(data,{bookingVersion:n.version,publishedAt:previousPublic?.publishedAt??now,updatedAt:now,schemaVersion:1});
   plan.push({path:`publicEvents/${id}`,data});
  } else if(previousPublic) plan.push({path:`publicEvents/${id}`,delete:true});
  tamper?.(plan);
  for(const item of plan) item.delete?tx.delete(doc(db,item.path)):tx.set(doc(db,item.path),item.data);
  return id;
 },{maxAttempts:5});
}
