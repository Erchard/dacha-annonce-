import './environment.mjs';
import {environment,seed,dbFor,draft} from './fixtures.mjs';
import {execute} from './booking-client.mjs';
import {writeFile} from 'node:fs/promises';
const env=await environment();
try {await seed(env);await execute(dbFor(env,'admin'),'admin','event','createApproved',{draft:draft()});console.log('CREATE PASS');}
catch(e){console.error(e.message);process.exitCode=1;}
finally {const r=await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-dacha:ruleCoverage');await writeFile('.tools/rules-coverage.json',await r.text());await env.cleanup();}
