const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function setup(position = 0, length = 125) {
  let tick, events, time = 0, state = -1;
  const messages = [];
  const api = {
    getDuration: () => length, getCurrentTime: () => time,
    getPlayerState: () => state, getVideoData: () => ({ isLive: false }),
    pauseVideo: () => { state = 2; }, playVideo: () => { state = 1; },
    seekTo: value => { time = value; }
  };
  const context = vm.createContext({
    window: { webkit: { messageHandlers: { player: { postMessage: data => messages.push(data) } } } },
    document: { createElement: () => ({}), head: { appendChild() {} } },
    setInterval: callback => { tick = callback; },
    YT: { Player: function (_, config) { events = config.events; return api; } }
  });
  const html = fs.readFileSync('Parts/Resources/player.html', 'utf8');
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1].replace('__CONFIG__', JSON.stringify({ id: 'aqz-KE-bpKQ', position, origin: 'https://com.shengy.parts' }));
  vm.runInContext(script, context);
  context.onYouTubeIframeAPIReady();
  events.onReady();
  return { context, api, tick: () => tick(), messages, setTime: value => { time = value; }, state: () => state };
}
test('pauses at a part boundary and advances only on request', () => {
  const p = setup(); p.tick(); p.api.playVideo(); p.setTime(60); p.tick();
  assert.equal(p.state(), 2);
  assert.equal(p.messages.at(-1).part, 0);
  assert.equal(p.messages.at(-1).completed, true);
  p.context.choosePart(1);
  assert.equal(p.state(), 1);
  assert.equal(p.api.getCurrentTime(), 60);
  assert.equal(p.messages.at(-1).part, 1);
});
test('restores the saved time in the correct part', () => {
  const p = setup(74); p.tick();
  assert.equal(p.api.getCurrentTime(), 74);
  assert.equal(p.messages.at(-1).part, 1);
});
test('clamps navigation and pauses the shorter final part', () => {
  const p = setup(); p.tick(); p.context.choosePart(99);
  assert.equal(p.api.getCurrentTime(), 120);
  p.setTime(124.95); p.tick();
  assert.equal(p.state(), 2);
  assert.equal(p.messages.at(-1).completed, true);
  p.context.choosePart(-2);
  assert.equal(p.api.getCurrentTime(), 0);
});
