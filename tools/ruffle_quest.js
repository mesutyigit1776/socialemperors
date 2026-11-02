// Plays a troll quest island in the original client (Ruffle in headless Chromium) with a plan of
// orders, and prints the game frame of each order and of each change of the gold and experience
// counters. godot/checks/quest_compare.gd plays the same plan in the port. See docs/GODOT_BATTLES.md,
// "Comparison with the original client".
//
// The server must run, and saves/<userid>.save.json must hold a village with the tutorial done.
// Needs Node.js and Playwright (require('playwright') with its Chromium).
//
// usage: node tools/ruffle_quest.js <out dir> <userid> <landing x,y> "<x,y;x,y;...>" <chest x,y>
//   landing: the first tile of the army, as quest_compare.gd prints it
//   orders: for each order, a tile of the enemy to attack; the army attacks it after "select all"
//   chest: the tile of the treasure, which the script clicks at the end
//
// Ruffle takes the time of each step from the timestamps of requestAnimationFrame. The script gives
// it a clock that moves one frame (1/30 s) per callback, so Ruffle runs one game frame per callback
// also when drawing is slow, and the number of callbacks is the frame number of the game. The client
// runs its battle in ENTER_FRAME, so its rules count these frames, as the port does.
const { chromium } = require('playwright');
const fs = require('fs');

const [out, uid, landingArg, ordersArg, chestArg] = process.argv.slice(2);
const tile = s => s.split(',').map(Number);
const landing = tile(landingArg);
const orders = ordersArg.split(';').filter(Boolean).map(tile);
const chest = tile(chestArg);

// The client view after three steps of zoom out: 0.15 screen pixels for one pixel of the port map
// (IsoGrid.tile_to_map), with the landing tile at (380, 300) of the 760 x 600 stage.
const ZOOM = 0.15;
const LANDING_SCREEN = [380, 300];
const map = ([x, y]) => [54 * (x - y), 27 * (x + y) - 81];
const screen = t => {
  const [mx, my] = map(t), [lx, ly] = map(landing);
  return [LANDING_SCREEN[0] + ZOOM * (mx - lx), LANDING_SCREEN[1] + ZOOM * (my - ly) - 3];
};

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader'] });
  // A device pixel ratio of 0.5 makes the software rendering cheaper; the clicks stay in CSS pixels.
  const page = await browser.newPage({ viewport: { width: 1000, height: 900 }, deviceScaleFactor: 0.5 });
  await page.addInitScript(() => {
    const raf = window.requestAnimationFrame.bind(window);
    window.__frames = 0;
    window.requestAnimationFrame = cb => raf(() => { window.__frames++; cb(window.__frames * 33.34); });
  });
  await page.goto('http://127.0.0.1:5050/');
  await Promise.all([page.waitForNavigation(), page.evaluate(uid => {
    const f = document.createElement('form'); f.method = 'post'; f.action = '/';
    for (const [k, v] of Object.entries({ USERID: uid, GAMEVERSION: 'SocialEmpires1.4.07sec_fixed.swf', RUNNER: 'RUFFLE' })) {
      const i = document.createElement('input'); i.name = k; i.value = v; f.appendChild(i);
    }
    document.body.appendChild(f); f.submit();
  }, uid)]);
  const player = page.locator('ruffle-player');
  const wait = ms => page.waitForTimeout(ms);
  const frames = () => page.evaluate(() => window.__frames);
  let box;
  const click = async (x, y) => { box = box || await player.boundingBox(); await page.mouse.click(box.x + x, box.y + y); };
  const shot = name => player.screenshot({ path: `${out}/${name}.png` });
  // Records the frames at which the gold and experience counters change. Damage numbers that fly
  // over the counters also count; the saved images tell them apart.
  const watch = async (name, ms) => {
    const clip = { x: box.x, y: box.y + 35, width: 230, height: 30 };
    const until = Date.now() + ms, changes = [];
    let last = null;
    while (Date.now() < until) {
      const img = (await page.screenshot({ clip })).toString('base64');
      if (last !== null && img !== last) {
        changes.push(await frames());
        await page.screenshot({ clip, path: `${out}/${name}_${changes.length}.png` });
      }
      last = img;
      await wait(200);
    }
    return changes;
  };

  await wait(55000);
  await click(380, 563); await wait(4000);   // login bonus: Get Reward
  await click(380, 563); await wait(4000);   // its second window, if any
  await click(380, 474); await wait(4000);   // "Congratulations": Close
  await click(667, 565); await wait(3000);   // World
  await click(665, 485); await wait(8000);   // Quests
  await click(148, 160); await wait(6000);   // the first island: Enter Now
  await shot('start_window');
  // The client runs the battle while this window is open; the port starts it with the button.
  const result = { start: await frames(), orders: [] };
  await click(520, 517);                     // Start Battle (1 star)
  result.start_changes = await watch('start', 12000);
  for (let i = 0; i < 3; i++) { await click(746, 449); await wait(600); }  // zoom out
  for (const target of orders) {
    await click(695, 512); await wait(300);  // Select All
    const [x, y] = screen(target);
    const frame = await frames();
    await click(x, y);
    result.orders.push({ target, frame, changes: await watch(`order_${target.join('_')}`, 50000) });
    await shot(`after_${target.join('_')}`);
  }
  const [cx, cy] = screen(chest);
  result.chest = await frames();
  await click(cx, cy - 2); await wait(6000); await shot('result');
  await click(463, 203); await wait(2000); await shot('lost');
  await click(493, 531); await wait(3000);   // Skip: the client sends end_quest to the server
  result.end = await frames();
  fs.writeFileSync(`${out}/result.json`, JSON.stringify(result, null, 1));
  console.log(JSON.stringify(result));
  await browser.close();
})();
