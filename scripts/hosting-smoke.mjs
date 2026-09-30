import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';
import {chromium} from 'playwright';

const target = new URL(process.argv[2] ?? 'http://127.0.0.1:5000');
assert.ok(['http://127.0.0.1:5000', 'https://dacha-annonce.web.app'].includes(target.origin));
await mkdir('.tools/qa/screenshots', {recursive:true});
const browser = await chromium.launch({channel:'chrome', headless:true});
const page = await browser.newPage({viewport:{width:1280,height:800}});
const errors = [];
const emulatorRequests = [];
page.on('pageerror', e => errors.push(e.message));
page.on('request', r => {if (/^https?:\/\/(localhost|127\.0\.0\.1):(8080|9099)/.test(r.url())) emulatorRequests.push(r.url());});
async function open(path) {
 const response = await page.goto(new URL(path, target).href);
 assert.equal(response.status(),200);
 await page.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:45000});
 await page.locator('flt-semantics-placeholder').evaluate(element=>element.click());
}
try {
 await open('/');
 await page.getByText('Розклад',{exact:true}).waitFor();
 assert.equal(await page.getByText('Running in emulator mode.',{exact:false}).count(),0);
 await page.getByText('Цього місяця подій ще немає.',{exact:true}).waitFor();
 await page.screenshot({path:'.tools/qa/screenshots/hosting-home.png'});
 await open('/missing');
 await page.getByText('Сторінку не знайдено',{exact:true}).waitFor();
 await page.getByRole('button',{name:'На головну',exact:true}).click();
 await page.getByText('Розклад',{exact:true}).waitFor();
 await page.setViewportSize({width:320,height:640});
 await open('/missing');
 await page.getByText('Сторінку не знайдено',{exact:true}).waitFor();
 await page.screenshot({path:'.tools/qa/screenshots/hosting-mobile.png'});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await open('/reset-password');
 await page.getByRole('textbox',{name:'Електронна адреса',exact:true}).waitFor();
 await page.getByRole('button',{name:'Відновити пароль',exact:true}).waitFor();
 assert.deepEqual(errors,[]);
 assert.deepEqual(emulatorRequests,[]);
 console.log('PASS: '+target.origin+' home, deep-link 404, return home, 320px, no JS errors or emulator requests.');
} catch(error) {
 console.error('Page text:',await page.locator('body').innerText());
 console.error('Runtime errors:',errors);
 throw error;
} finally {await browser.close();}

