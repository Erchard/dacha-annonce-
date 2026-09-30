import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {chromium} from 'playwright';
import {serve} from './local-server.mjs';
import {seedDemo} from '../rules-tests/seed.mjs';
await mkdir('.tools/qa/screenshots',{recursive:true});
await seedDemo();
const probe=await serve('.tools/booking-smoke');
const app=await serve('build/web');
let browser,page;
try{
 browser=await chromium.launch({channel:'chrome',headless:true});
 page=await browser.newPage({viewport:{width:1280,height:900}});
 async function enter(field,value){await field.click();await field.press('ControlOrMeta+A');await field.pressSequentially(value,{delay:15});await field.press('Tab');}
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 async function open(url){await page.goto(url);const p=page.locator('flt-semantics-placeholder');await p.waitFor({state:'attached',timeout:60000});await p.evaluate(e=>e.click());}
 await open(probe.url);
 await page.getByText(/^(PASS|FAIL).*Flutter|^FAIL at/).waitFor({timeout:90000});
 const result=await page.locator('flt-semantics').allTextContents();assert.ok(result.some(x=>x.includes('PASS: Flutter booking')),result.join('\n'));
 console.log('PASS: real Flutter transactional engine');
 if(!process.argv.includes('--probe-only')){
 await seedDemo();
 await open(app.url);await page.getByText('Розклад',{exact:true}).waitFor();
 await page.getByRole('button',{name:/Зустріч на Дачі/}).first().waitFor({timeout:30000});
 await page.screenshot({path:'.tools/qa/screenshots/calendar-desktop.png'});
 await open(app.url+'/events/demo-event');await page.getByText('Зустріч на Дачі',{exact:true}).waitFor();
 await page.setViewportSize({width:320,height:800});await open(app.url);await page.getByText('Розклад',{exact:true}).waitFor();await page.screenshot({path:'.tools/qa/screenshots/calendar-mobile.png'});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await page.setViewportSize({width:1280,height:900});
 await open(app.url+'/login?returnTo=/admin');
 await enter(page.getByRole('textbox',{name:'Електронна адреса',exact:true}),'admin@example.test');
 await enter(page.getByRole('textbox',{name:'Пароль',exact:true}),'LocalDemo123!');
 await page.getByRole('button',{name:'Увійти',exact:true}).click();
 await page.getByText('Заявок із цим статусом немає.',{exact:true}).waitFor({timeout:30000});
 await page.getByRole('button',{name:'Локації',exact:true}).click();
 await page.getByRole('heading',{name:'Локації',exact:true}).waitFor();
 await page.getByRole('button',{name:'Меню',exact:true}).click();
 await page.getByRole('menuitem',{name:'Написати розробнику',exact:true}).click();
 await page.getByRole('button',{name:'Нове звернення',exact:true}).click();
 await enter(page.getByRole('textbox',{name:/Тема/}),'Перевірка браузера');
 await enter(page.getByRole('textbox',{name:/Опис/}),'Звернення створено через видиму форму у браузері.');
 await page.getByRole('button',{name:'Створити звернення',exact:true}).click();
 await page.getByRole('heading',{name:'Перевірка браузера',exact:true}).waitFor();
 await page.screenshot({path:'.tools/qa/screenshots/support.png'});
 async function menu(name){await page.getByRole('button',{name:'Меню',exact:true}).click();await page.getByRole('menuitem',{name,exact:true}).click();}
 async function login(name){await enter(page.getByRole('textbox',{name:'Електронна адреса',exact:true}),name+'@example.test');await enter(page.getByRole('textbox',{name:'Пароль',exact:true}),'LocalDemo123!');await page.getByRole('button',{name:'Увійти',exact:true}).click();await page.getByRole('heading',{name:'Розклад',exact:true}).waitFor();}
 await menu('Вийти');await page.getByRole('heading',{name:'Розклад',exact:true}).waitFor();await menu('Увійти');await login('organizer');
 await page.getByRole('button',{name:'Забронювати',exact:true}).click();
 await enter(page.getByRole('textbox',{name:/Назва події/}),'Заявка з браузера');
 const date=new Date(Date.now()+6*86400000).toISOString().slice(0,10);
 await enter(page.getByRole('textbox',{name:'Дата (РРРР-ММ-ДД)',exact:true}),date);
 await page.getByRole('button',{name:'Надіслати',exact:true}).click();
 await page.getByRole('checkbox',{name:'Очікує рішення',exact:true}).waitFor();
 const bookingId=new URL(page.url()).pathname.split('/').at(-1);
 await menu('Вийти');await page.getByRole('heading',{name:'Розклад',exact:true}).waitFor();await menu('Увійти');await login('admin');await menu('Керування');
 await page.getByRole('button',{name:/Заявка з браузера/}).click();
 await page.getByRole('button',{name:'Схвалити',exact:true}).click();await page.getByRole('checkbox',{name:'Схвалено',exact:true}).waitFor();
 await page.getByRole('button',{name:'Публічна подія',exact:true}).click();await page.getByText('Заявка з браузера',{exact:true}).waitFor();
 await page.screenshot({path:'.tools/qa/screenshots/approved-event.png'});
 await menu('Вийти');await page.getByRole('heading',{name:'Розклад',exact:true}).waitFor();
 await open(app.url+'/bookings/'+bookingId);await page.getByRole('heading',{name:'Потрібен вхід',exact:true}).waitFor();
 console.log('PASS: organizer form → admin approval → public event → logout/private guard');
 assert.deepEqual(errors,[]);
 console.log('PASS: release calendar, event, 320px, admin login, rooms, support form');
 }
}catch(e){if(page){await writeFile('.tools/qa/browser-dom.txt',await page.locator('body').ariaSnapshot());await page.screenshot({path:'.tools/qa/screenshots/failure.png'});}throw e;}
finally{await browser?.close();await Promise.all([probe,app].map(({server})=>new Promise(r=>server.close(r))));}


