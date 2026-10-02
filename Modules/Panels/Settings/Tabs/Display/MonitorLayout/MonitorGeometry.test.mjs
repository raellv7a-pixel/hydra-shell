import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Load pure MonitorGeometry source stripping QML .pragma library directive
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const sourcePath = path.join(__dirname, 'MonitorGeometry.js');
const source = fs.readFileSync(sourcePath, 'utf8').replace(/^\.pragma\s+library\s*;?/m, '');

const sandbox = {
  module: { exports: {} },
  exports: {},
  console,
  Math,
  Number,
  parseInt,
  parseFloat,
  Array,
  Object,
  String,
  Boolean
};
vm.createContext(sandbox);
vm.runInContext(source, sandbox);
const mg = sandbox.module.exports;
const toPlain = value => JSON.parse(JSON.stringify(value));
const backendSource = fs.readFileSync(
  path.join(__dirname, 'backends', 'UmbrielBackend.js'),
  'utf8'
).replace(/^\.pragma\s+library\s*;?/m, '').replace(/^\.import\s+.*$/m, '');
const backendSandbox = { MonitorGeometry: mg };
vm.createContext(backendSandbox);
vm.runInContext(backendSource, backendSandbox);

describe('MonitorGeometry - Logical Footprint & Transforms', () => {
  it('detects quarter-turn transforms (1, 3, 5, 7)', () => {
    assert.strictEqual(mg.isQuarterTurn(0), false);
    assert.strictEqual(mg.isQuarterTurn(1), true);
    assert.strictEqual(mg.isQuarterTurn(2), false);
    assert.strictEqual(mg.isQuarterTurn(3), true);
    assert.strictEqual(mg.isQuarterTurn(4), false);
    assert.strictEqual(mg.isQuarterTurn(5), true);
    assert.strictEqual(mg.isQuarterTurn(6), false);
    assert.strictEqual(mg.isQuarterTurn(7), true);
    assert.strictEqual(mg.isQuarterTurn('90'), true);
    assert.strictEqual(mg.isQuarterTurn('flipped-90'), true);
    assert.strictEqual(mg.isQuarterTurn('normal'), false);
  });

  it('computes logical footprint with standard orientation and scaling', () => {
    const s1 = mg.computeLogicalSize(1920, 1080, 1.0, 0);
    assert.deepStrictEqual(toPlain(s1), { width: 1920, height: 1080 });

    const s2 = mg.computeLogicalSize(1920, 1080, 1.25, 0);
    assert.deepStrictEqual(toPlain(s2), { width: 1536, height: 864 });

    const s3 = mg.computeLogicalSize(3840, 2160, 2.0, 0);
    assert.deepStrictEqual(toPlain(s3), { width: 1920, height: 1080 });
  });

  it('does not invent a logical footprint when physical geometry is invalid', () => {
    assert.deepStrictEqual(toPlain(mg.computeLogicalSize(0, 1080, 1, 0)), { width: 0, height: 0 });
    assert.deepStrictEqual(toPlain(mg.computeLogicalSize(undefined, undefined, 1, 0)), { width: 0, height: 0 });
  });

  it('swaps width and height on quarter-turn transforms (90 and 270 degrees)', () => {
    const turned90 = mg.computeLogicalSize(1920, 1080, 1.0, 1);
    assert.deepStrictEqual(toPlain(turned90), { width: 1080, height: 1920 });

    const turned270Scaled = mg.computeLogicalSize(1920, 1080, 1.5, 3);
    assert.deepStrictEqual(toPlain(turned270Scaled), { width: 720, height: 1280 });

    const flipped90 = mg.computeLogicalSize(2560, 1440, 1.0, 5);
    assert.deepStrictEqual(toPlain(flipped90), { width: 1440, height: 2560 });
  });
});

describe('MonitorGeometry - Resolution-Aware Scale Ladder', () => {
  it('offers only decimal scales with exact logical-pixel dimensions', () => {
    const cases = [
      { width: 3840, height: 2160, transform: 0, required: [1.0, 1.25, 1.5, 2.0, 2.5, 3.0], max: 3.0 },
      { width: 2560, height: 1440, transform: 0, required: [1.0, 1.25, 1.6, 2.0], max: 2.0 },
      { width: 1920, height: 1080, transform: 0, required: [0.8, 1.0, 1.25, 1.5], max: 1.5 },
      { width: 1280, height: 720, transform: 0, required: [0.8, 1.0, 1.25], max: 1.25 }
    ];

    for (const item of cases) {
      const ladder = mg.getScaleLadder(item.width, item.height, item.transform);
      for (const scale of item.required) assert.ok(ladder.includes(scale), `${item.width}x${item.height} includes ${scale}`);
      for (const scale of ladder) {
        assert.ok(scale <= item.max);
        assert.ok(Number.isInteger(item.width / scale), `${item.width}/${scale} is integral`);
        assert.ok(Number.isInteger(item.height / scale), `${item.height}/${scale} is integral`);
      }
    }

    assert.ok(!mg.getScaleLadder(1920, 1080, 0).includes(0.9));
    assert.deepStrictEqual(mg.getScaleLadder(1920, 1080, 1), mg.getScaleLadder(1920, 1080, 0));
    assert.deepStrictEqual(toPlain(mg.getScaleLadder(0, 1080, 0)), [1.0]);
  });

  it('coerces scales to the nearest available discrete step', () => {
    const ladder = mg.getScaleLadder(1920, 1080, 0);
    assert.strictEqual(mg.coerceScale(1.21, ladder), 1.2);
    assert.strictEqual(mg.coerceScale(1.48, ladder), 1.5);
    assert.strictEqual(mg.coerceScale(0.9, ladder), 0.96);
  });
});

describe('MonitorGeometry - Snapping & Overlap', () => {
  const monA = { outputId: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 };

  it('snaps right edge of active to left edge of target when overlapping vertically', () => {
    // monB is placed near left edge of monA (x: -1910, y: 100) -> should snap to x: -1920, y: 100
    const monB = { outputId: 'DP-2', x: -1910, y: 100, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.snapToNearestEdge(monB, [monA], 32);
    assert.strictEqual(res.snapped, true);
    assert.strictEqual(res.x, -1920);
  });

  it('snaps left edge of active to right edge of target when overlapping vertically', () => {
    // monB placed near right edge of monA (x: 1930, y: 200) -> should snap to x: 1920
    const monB = { outputId: 'DP-2', x: 1930, y: 200, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.snapToNearestEdge(monB, [monA], 32);
    assert.strictEqual(res.snapped, true);
    assert.strictEqual(res.x, 1920);
  });

  it('does NOT snap horizontally when there is no vertical overlap', () => {
    // monB is below monA vertically (y: 1200 > 1080), so no vertical overlap
    const monB = { outputId: 'DP-2', x: 1930, y: 1200, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.snapToNearestEdge(monB, [monA], 32);
    assert.strictEqual(res.snapped, false);
    assert.strictEqual(res.x, 1930);
  });

  it('snaps top edge of active to bottom edge of target when overlapping horizontally', () => {
    // monB placed below monA near y: 1090 with horizontal overlap at x: 200
    const monB = { outputId: 'DP-2', x: 200, y: 1090, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.snapToNearestEdge(monB, [monA], 32);
    assert.strictEqual(res.snapped, true);
    assert.strictEqual(res.y, 1080);
  });

  it('aligns tops when adjacent and near equal Y', () => {
    // monB placed at x: 1920, y: 10 (within 32px of y: 0)
    const monB = { outputId: 'DP-2', x: 1925, y: 10, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.snapToNearestEdge(monB, [monA], 32);
    assert.strictEqual(res.snapped, true);
    assert.strictEqual(res.x, 1920);
    assert.strictEqual(res.y, 0);
  });
});

describe('MonitorGeometry - Touches & Flush Attachment', () => {
  const monA = { outputId: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 };

  it('correctly identifies touching vs separated monitors', () => {
    const touching = { outputId: 'DP-2', x: 1920, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 };
    assert.strictEqual(mg.touches(mg.getRect(monA), mg.getRect(touching)), true);
    assert.strictEqual(mg.touchesAny(touching, [monA]), true);

    const separated = { outputId: 'DP-2', x: 1930, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 };
    assert.strictEqual(mg.touches(mg.getRect(monA), mg.getRect(separated)), false);
    assert.strictEqual(mg.touchesAny(separated, [monA]), false);
  });

  it('attaches a far-dropped monitor flush to the nearest edge', () => {
    const far = { outputId: 'DP-2', x: 5000, y: 200, width: 1920, height: 1080, scale: 1, transform: 0 };
    const attached = mg.attachFlush(far, [monA]);
    // Nearest edge for (5000, 200) is the right edge of monA (x: 1920)
    assert.strictEqual(attached.x, 1920);
    assert.strictEqual(mg.touches(mg.getRect(monA), { ...far, x: attached.x, y: attached.y }), true);
  });

  it('preserves position if monitor is already touching', () => {
    const touching = { outputId: 'DP-2', x: 1920, y: 100, width: 1920, height: 1080, scale: 1, transform: 0 };
    const res = mg.attachFlush(touching, [monA]);
    assert.strictEqual(res.x, 1920);
    assert.strictEqual(res.y, 100);
  });
});

describe('MonitorGeometry - Tidy Gaps', () => {
  it('closes small unintentional gaps between monitors', () => {
    const list = [
      { outputId: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 },
      { outputId: 'DP-2', x: 1930, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 } // 10px gap
    ];
    const tidied = mg.tidyGaps(list, 20);
    assert.strictEqual(tidied[1].x, 1920);
  });
  it('does not move disabled outputs while closing active-monitor gaps', () => {
    const list = [
      { outputId: 'DP-1', active: true, x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 },
      { outputId: 'DP-2', active: true, x: 1930, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 },
      { outputId: 'DP-3', active: false, x: 5000, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 }
    ];
    const tidied = mg.tidyGaps(list, 20);
    assert.strictEqual(tidied[1].x, 1920);
    assert.strictEqual(tidied[2].x, 5000);
  });

  it('does not alter monitors separated by intentional large gaps', () => {
    const list = [
      { outputId: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 },
      { outputId: 'DP-2', x: 2200, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 } // 280px gap
    ];
    const tidied = mg.tidyGaps(list, 20);
    assert.strictEqual(tidied[1].x, 2200);
  });
});

describe('MonitorGeometry - Primary Derivation & Rebase', () => {
  it('rebases layout so chosen primary is at (0, 0) preserving relative offsets', () => {
    const outputs = [
      { outputId: 'DP-1', name: 'DP-1', x: 0, y: 0, logicalWidth: 1920, logicalHeight: 1080 },
      { outputId: 'DP-2', name: 'DP-2', x: 1920, y: 0, logicalWidth: 1920, logicalHeight: 1080 }
    ];

    // Designate DP-2 as primary
    const rebased = mg.rebaseToPrimary(outputs, 'DP-2');
    assert.strictEqual(rebased[1].x, 0);
    assert.strictEqual(rebased[1].y, 0);
    assert.strictEqual(rebased[1].isPrimary, true);

    // DP-1 should be shifted to -1920, relative distance is exactly 1920
    assert.strictEqual(rebased[0].x, -1920);
    assert.strictEqual(rebased[0].y, 0);
    assert.strictEqual(rebased[0].isPrimary, false);
  });
});

describe('MonitorGeometry - Live Geometry & Apply Readback', () => {
  it('derives rectangles from physical mode data instead of stale cached logical sizes', () => {
    const rect = mg.getRect({
      outputId: 'DP-1',
      x: 0,
      y: 0,
      width: 1920,
      height: 1080,
      scale: 2,
      transform: 1,
      logicalWidth: 9999,
      logicalHeight: 9999
    });
    assert.strictEqual(rect.width, 540);
    assert.strictEqual(rect.height, 960);
  });

  it('accepts readback only when every active output matches the requested mode and placement', () => {
    const wanted = {
      outputId: 'DP-1',
      active: true,
      width: 1920,
      height: 1080,
      refresh: 144,
      scale: 1.25,
      transform: 0,
      x: 0,
      y: 0
    };
    const actual = { ...wanted, transform: '0', logicalWidth: 1536, logicalHeight: 864 };

    assert.strictEqual(mg.layoutsMatch([wanted], [actual]), true);
    assert.strictEqual(mg.layoutsMatch([{ ...wanted, transform: 'normal' }], [actual]), true);
    assert.strictEqual(mg.layoutsMatch([{ ...wanted, transform: '90' }], [actual]), false);
    assert.strictEqual(mg.layoutsMatch([wanted], [{ ...actual, width: 2560 }]), false);
    assert.strictEqual(mg.layoutsMatch([wanted], [{ ...actual, refresh: 60 }]), false);
    assert.strictEqual(mg.layoutsMatch([wanted], [{ ...actual, x: 24 }]), false);
    assert.strictEqual(mg.layoutsMatch([wanted], []), false);
    assert.strictEqual(mg.layoutsMatch([wanted, { outputId: 'DP-2', active: false }], [actual]), true);
    assert.strictEqual(mg.layoutsMatch([wanted], [{ ...actual, mirror: 'DP-2' }]), false);
    const mirrorWanted = { outputId: 'DP-2', active: true, mirror: 'DP-1' };
    assert.strictEqual(mg.layoutsMatch([mirrorWanted], [{ outputId: 'DP-2', mirror: 'DP-1' }]), true);
    assert.strictEqual(mg.layoutsMatch([mirrorWanted], [{ outputId: 'DP-2', mirror: 'DP-3' }]), false);
  });

});
describe('Umbriel monitor normalization', () => {
  it('preserves native scales, refresh and transformed geometry across monitors', () => {
    const parsed = backendSandbox.parseOutputs(JSON.stringify([{
      name: 'DP-1', enabled: true, position: { x: -864, y: 0 },
      scale: 1.25, transform: '90',
      modes: [{ width: 1920, height: 1080, refresh_mhz: 59940, current: true, preferred: true }]
    }, {
      name: 'DP-2', enabled: true, position: { x: 0, y: 0 },
      scale: 1.5, transform: 'normal',
      modes: [{ width: 1920, height: 1080, refresh_mhz: 60000, current: true }]
    }]));
    assert.strictEqual(parsed.error, undefined);
    assert.strictEqual(parsed.outputs[0].logicalWidth, 864);
    assert.strictEqual(parsed.outputs[0].logicalHeight, 1536);
    assert.strictEqual(parsed.outputs[0].modeId, '1920x1080@59.94');
    assert.strictEqual(parsed.outputs[1].logicalWidth, 1280);
    assert.strictEqual(parsed.outputs[1].scale, 1.5);
    assert.strictEqual(parsed.outputs[1].isPrimary, true);
  });

  it('rejects incomplete monitor geometry rather than inventing a mode or scale', () => {
    const parsed = backendSandbox.parseOutputs(JSON.stringify([{
      name: 'DP-1', enabled: true, position: { x: 0, y: 0 },
      transform: 'normal', modes: []
    }]));
    assert.ok(parsed.error);
    assert.strictEqual(parsed.outputs, undefined);
  });
});
