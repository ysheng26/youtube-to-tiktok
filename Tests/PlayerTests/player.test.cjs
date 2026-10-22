const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function setup(position = 0, length = 125) {
  let tick, events, options, time = 0, state = -1, videoID = 'aqz-KE-bpKQ';
  const messages = [];
  const api = {
    getVideoUrl: () => `https://www.youtube.com/watch?v=${videoID}`,
    loadVideoById: options => { videoID = options.videoId; time = options.startSeconds; state = 1; },
    getDuration: () => length, getCurrentTime: () => time,
    getPlayerState: () => state, getVideoData: () => ({ isLive: false }),
    pauseVideo: () => { state = 2; }, playVideo: () => { state = 1; },
    seekTo: value => { time = value; }
  };
  const context = vm.createContext({
    URL,
    window: { webkit: { messageHandlers: { player: { postMessage: data => messages.push(data) } } } },
    document: { createElement: () => ({}), head: { appendChild() {} } },
    setInterval: callback => { tick = callback; },
    YT: { Player: function (_, config) { events = config.events; options = config; return api; } }
  });
  const html = fs.readFileSync('Parts/Resources/player.html', 'utf8');
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1].replace('__CONFIG__', JSON.stringify({ id: 'aqz-KE-bpKQ', position, origin: 'https://com.shengy.parts' }));
  vm.runInContext(script, context);
  context.onYouTubeIframeAPIReady();
  events.onReady();
  return { context, api, options, setVideo: id => { videoID = id; }, ended: () => { state = 0; events.onStateChange({data: 0}); }, tick: () => tick(), messages, setTime: value => { time = value; }, state: () => state };
}
test('loops the current part and advances only on request', () => {
  const p = setup(); p.tick(); p.api.playVideo(); p.setTime(60); p.tick();
  assert.equal(p.state(), 1);
  assert.equal(p.api.getCurrentTime(), 0);
  assert.equal(p.messages.at(-1).part, 0);
  assert.equal(p.messages.at(-1).playing, true);
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
test('clamps navigation and loops the shorter final part', () => {
  const p = setup(); p.tick(); p.context.choosePart(99);
  assert.equal(p.api.getCurrentTime(), 120);
  p.setTime(124.95); p.tick();
  assert.equal(p.state(), 1);
  assert.equal(p.api.getCurrentTime(), 120);
  assert.equal(p.messages.at(-1).part, 2);
  p.context.choosePart(-2);
  assert.equal(p.api.getCurrentTime(), 0);
});

test('restarts the final part when YouTube reports the actual video end', () => {
  const p = setup(122); p.tick(); p.setTime(125); p.ended();
  assert.equal(p.state(), 1);
  assert.equal(p.api.getCurrentTime(), 120);
  assert.equal(p.messages.at(-1).part, 2);
});
test('a video shorter than a minute loops back to zero', () => {
  const p = setup(0, 20); p.tick(); p.api.playVideo(); p.setTime(20); p.ended();
  assert.equal(p.api.getCurrentTime(), 0);
  assert.equal(p.state(), 1);
  assert.equal(p.messages.at(-1).part, 0);
});
test('repeated loops stay within the selected minute', () => {
  const p = setup(74); p.tick(); p.api.playVideo();
  for (let i = 0; i < 3; i++) {
    p.setTime(120); p.tick();
    assert.equal(p.api.getCurrentTime(), 60);
    assert.equal(p.messages.at(-1).part, 1);
    assert.equal(p.state(), 1);
  }
});
test('paused playback stays paused at a part boundary', () => {
  const p = setup(); p.tick(); p.api.pauseVideo(); p.setTime(60); p.tick();
  assert.equal(p.state(), 2);
  assert.equal(p.api.getCurrentTime(), 60);
});
test('seek offsets are relative to this part and stay inside its bounds', () => {
  const p = setup(74); p.tick();
  p.context.seekWithinPart(10);
  assert.equal(p.api.getCurrentTime(), 70);
  p.context.seekWithinPart(-20);
  assert.equal(p.api.getCurrentTime(), 60);
  p.context.seekWithinPart(500);
  assert.equal(p.api.getCurrentTime(), 119.9);
  p.context.choosePart(2);
  p.context.seekWithinPart(60);
  assert.equal(p.api.getCurrentTime(), 124.9);
});
test('custom play/pause toggles playback', () => {
  const p = setup(); p.tick();
  p.context.togglePlayback(); assert.equal(p.state(), 1);
  p.context.togglePlayback(); assert.equal(p.state(), 2);
});
test('YouTube timeline and keyboard seeking are disabled', () => {
  const p = setup();
  assert.equal(p.options.playerVars.controls, 0);
  assert.equal(p.options.playerVars.disablekb, 1);
});

test('a suggested video cannot replace the selected video or its current part', () => {
  const p = setup(74); p.tick();
  p.setVideo('jfKfPfyJRdk'); p.tick();
  assert.equal(p.api.getVideoUrl(), 'https://www.youtube.com/watch?v=aqz-KE-bpKQ');
  assert.equal(p.api.getCurrentTime(), 60);
  p.tick();
  assert.equal(p.messages.at(-1).part, 1);
  assert.equal(p.state(), 1);
});
