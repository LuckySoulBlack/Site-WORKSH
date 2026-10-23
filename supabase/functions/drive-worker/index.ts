import {admin,body,handler,worker} from '../_shared/core.ts';
import {uploadJob} from '../_shared/jobs.ts';
Deno.serve(handler(async req=>{const db=admin();await worker(req,db);const {upload_job_id}=await body(req);await uploadJob(db,upload_job_id);return {ok:true};}));
