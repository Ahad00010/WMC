import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';
test('update warning stays hidden on a fresh session and only shows for a changed deployment',async()=>{
 const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8');const dom=new JSDOM(html,{runScripts:'outside-only',url:'https://game.test/index.html'}),w=dom.window;let latest=html,visibility;w.fetch=async()=>({ok:true,text:async()=>latest});w.setInterval=()=>0;
 const notice=w.document.getElementById('updateNotice');assert.equal(w.getComputedStyle(notice).display,'none','hidden must override the inline flex style');
 const script=[...w.document.scripts].find(e=>e.textContent.includes('var originalMarkup=markup(document)')).textContent;
 w.eval(script);w.document.dispatchEvent(new w.Event('DOMContentLoaded'));await new Promise(r=>setTimeout(r,0));assert.equal(notice.hidden,true,'identical HTML must not trigger an update');
 latest=html.replace('The current session is old','A newer release');Object.defineProperty(w.document,'hidden',{get:()=>false});w.document.dispatchEvent(new w.Event('visibilitychange'));await new Promise(r=>setTimeout(r,0));assert.equal(notice.hidden,false);visibility=w.getComputedStyle(notice).display;assert.equal(visibility,'flex');dom.window.close();
});
