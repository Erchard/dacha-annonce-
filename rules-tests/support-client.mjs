import {doc,runTransaction,serverTimestamp} from 'firebase/firestore';
export async function ticketCommand(db,actor,role,id,action,{expectedVersion=0,status,priority,comment,type='bug',omitHistory=false,omitComment=false,tamper}={}) {
 const ref=doc(db,'supportTickets',id),commentRef=doc(ref,'comments',`comment-${expectedVersion+1}`);
 return runTransaction(db,async tx=>{
  const old=(await tx.get(ref)).data();
  if((old?.version??0)!==expectedVersion)throw new Error('staleVersion');
  const now=serverTimestamp();
  const next={...(old??{type,title:'Тестове звернення',body:'Достатньо довгий опис проблеми.',status:'new',priority:'normal',createdBy:actor,createdAt:now,schemaVersion:1,lastCommentId:null}),
   ...(status?{status}:{}),...(priority?{priority}:{}),updatedBy:actor,updatedAt:now,lastActivityAt:now,version:expectedVersion+1,lastAction:action,lastHistoryId:String(expectedVersion+1),...(comment?{lastCommentId:commentRef.id}:{})};
  const history={version:next.version,action,actorId:actor,actorRole:role,at:now,fromStatus:old?.status??null,toStatus:next.status,commentId:comment?commentRef.id:null,fromPriority:old?.priority??null,toPriority:next.priority};
  const c=comment?{body:comment,authorId:actor,authorRole:role,createdAt:now,ticketVersion:next.version,schemaVersion:1}:null;
  tamper?.({next,history,c});
  tx.set(ref,next);
  if(!omitHistory)tx.set(doc(ref,'history',String(next.version)),history);
  if(c&&!omitComment)tx.set(commentRef,c);
 });
}
