.pragma library

// MonitorGeometry.js - Pure monitor layout & geometry helpers for Hydra Shell
// Supports both QML imports and Node.js testing.

function isQuarterTurn(transform) {
  var value = String(transform === undefined || transform === null ? "0" : transform).toLowerCase();
  if (value === "90" || value === "270" || value === "flipped-90" || value === "flipped-270") {
    return true;
  }
  var t = Number(value);
  return t === 1 || t === 3 || t === 5 || t === 7;
}

function computeLogicalSize(width, height, scale, transform) {
  var w = Number(width);
  var h = Number(height);
  var s = Number(scale === undefined || scale === null ? 1 : scale);
  if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0 || !isFinite(s) || s <= 0) {
    return { width: 0, height: 0 };
  }
  var effectiveW = isQuarterTurn(transform) ? h : w;
  var effectiveH = isQuarterTurn(transform) ? w : h;
  return {
    width: Math.round(effectiveW / s),
    height: Math.round(effectiveH / s)
  };
}

function getScaleLadder(width, height, transform) {
  var w = Number(width);
  var h = Number(height);
  if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) {
    return [1.0];
  }

  var minDim = Math.min(w, h);
  var maxScale = minDim >= 2160 ? 3.0 : minDim >= 1440 ? 2.0 : minDim >= 1080 ? 1.5 : 1.25;
  var physicalW = isQuarterTurn(transform) ? h : w;
  var physicalH = isQuarterTurn(transform) ? w : h;
  var minHundredths = 80;
  var maxHundredths = Math.round(maxScale * 100);
  var ladder = [];

  for (var hundredths = minHundredths; hundredths <= maxHundredths; hundredths++) {
    if ((physicalW * 100) % hundredths !== 0 || (physicalH * 100) % hundredths !== 0) {
      continue;
    }
    ladder.push(hundredths / 100);
  }
  if (ladder.indexOf(1.0) === -1) {
    ladder.push(1.0);
    ladder.sort(function (a, b) { return a - b; });
  }
  return ladder;
}

function coerceScale(scale, ladder) {
  var target = Number(scale || 1);
  if (!isFinite(target) || target <= 0) {
    target = 1.0;
  }
  if (!ladder || !ladder.length) {
    return Math.max(0.25, Math.min(4, Math.round(target * 100) / 100));
  }
  var best = ladder[0];
  var bestDiff = Math.abs(ladder[0] - target);
  for (var i = 1; i < ladder.length; i++) {
    var diff = Math.abs(ladder[i] - target);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = ladder[i];
    }
  }
  return best;
}

function getRect(output) {
  var size = computeLogicalSize(output.width, output.height, output.scale, output.transform);
  return {
    outputId: output.outputId || output.name || "",
    x: Number(output.x || 0),
    y: Number(output.y || 0),
    width: Math.max(1, size.width),
    height: Math.max(1, size.height)
  };
}

function computeSceneBounds(outputs) {
  var minX = Infinity;
  var minY = Infinity;
  var maxX = -Infinity;
  var maxY = -Infinity;
  for (var i = 0; i < outputs.length; i++) {
    var output = outputs[i];
    if (output.active === false || output.disabled)
      continue;
    var rect = getRect(output);
    minX = Math.min(minX, rect.x);
    minY = Math.min(minY, rect.y);
    maxX = Math.max(maxX, rect.x + rect.width);
    maxY = Math.max(maxY, rect.y + rect.height);
  }
  if (minX === Infinity)
    return { minX: 0, minY: 0, maxX: 1920, maxY: 1080, width: 1920, height: 1080 };
  return { minX: minX, minY: minY, maxX: maxX, maxY: maxY,
           width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
}

function fitViewport(bounds, width, height, padding, minimumScale, maximumScale, fitFraction) {
  var availableWidth = Math.max(0, width - padding * 2) * fitFraction;
  var availableHeight = Math.max(0, height - padding * 2) * fitFraction;
  var scale = Math.max(minimumScale, Math.min(maximumScale,
                    availableWidth / bounds.width, availableHeight / bounds.height));
  return {
    scale: scale,
    offsetX: Math.max(padding, (width - bounds.width * scale) / 2),
    offsetY: Math.max(padding, (height - bounds.height * scale) / 2)
  };
}

function dragPosition(start, mouseX, mouseY) {
  return {
    x: Math.round(start.x + (mouseX - start.mouseX) / start.scale),
    y: Math.round(start.y + (mouseY - start.mouseY) / start.scale)
  };
}

// Match the painted stacking order; repeated clicks cycle even fully covered outputs.
function outputAtPoint(outputs, x, y, selectedOutputId) {
  var hits = [];
  for (var i = outputs.length - 1; i >= 0; i--) {
    var rect = getRect(outputs[i]);
    if (x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height)
      hits.push(rect.outputId);
  }
  if (hits.length === 0)
    return "";
  var selectedIndex = hits.indexOf(selectedOutputId);
  return hits[(selectedIndex + 1) % hits.length];
}

function rectanglesOverlap(r1, r2) {
  return r1.x < (r2.x + r2.width) &&
         (r1.x + r1.width) > r2.x &&
         r1.y < (r2.y + r2.height) &&
         (r1.y + r1.height) > r2.y;
}

function touches(r1, r2, tolerance) {
  var tol = (tolerance !== undefined) ? Number(tolerance) : 1;
  // Overlapping rectangles touch
  if (rectanglesOverlap(r1, r2)) {
    return true;
  }
  // Sharing vertical edge (r1 left of r2, or r2 left of r1) with vertical overlap
  var horizontalEdgeTouching = Math.abs((r1.x + r1.width) - r2.x) <= tol ||
                               Math.abs((r2.x + r2.width) - r1.x) <= tol;
  var verticalOverlap = (Math.min(r1.y + r1.height, r2.y + r2.height) - Math.max(r1.y, r2.y)) > 0;

  if (horizontalEdgeTouching && verticalOverlap) {
    return true;
  }

  // Sharing horizontal edge (r1 above r2, or r2 above r1) with horizontal overlap
  var verticalEdgeTouching = Math.abs((r1.y + r1.height) - r2.y) <= tol ||
                             Math.abs((r2.y + r2.height) - r1.y) <= tol;
  var horizontalOverlap = (Math.min(r1.x + r1.width, r2.x + r2.width) - Math.max(r1.x, r2.x)) > 0;

  if (verticalEdgeTouching && horizontalOverlap) {
    return true;
  }

  return false;
}

function touchesAny(activeOutput, others, ignoreId) {
  if (!others || others.length === 0) {
    return false;
  }
  var r1 = getRect(activeOutput);
  for (var i = 0; i < others.length; i++) {
    var r2 = getRect(others[i]);
    if (r2.outputId && (r2.outputId === r1.outputId || r2.outputId === ignoreId)) {
      continue;
    }
    if (touches(r1, r2)) {
      return true;
    }
  }
  return false;
}

function snapToNearestEdge(activeOutput, others, snapThreshold) {
  var threshold = (snapThreshold !== undefined) ? Number(snapThreshold) : 32;
  var r = getRect(activeOutput);
  var bestX = r.x;
  var bestY = r.y;
  var snapped = false;
  var minDistance = threshold + 1;

  for (var i = 0; i < others.length; i++) {
    var o = getRect(others[i]);
    if (o.outputId && o.outputId === r.outputId) {
      continue;
    }

    // Check vertical overlap for horizontal snap (left/right of o)
    var vOverlap = Math.min(r.y + r.height, o.y + o.height) - Math.max(r.y, o.y);
    if (vOverlap > 0) {
      // Snap right of active to left of o
      var diffLeft = Math.abs(r.x - (o.x - r.width));
      if (diffLeft <= threshold && diffLeft < minDistance) {
        minDistance = diffLeft;
        bestX = o.x - r.width;
        snapped = true;
      }
      // Snap left of active to right of o
      var diffRight = Math.abs(r.x - (o.x + o.width));
      if (diffRight <= threshold && diffRight < minDistance) {
        minDistance = diffRight;
        bestX = o.x + o.width;
        snapped = true;
      }
    }

    // Check horizontal overlap for vertical snap (above/below o)
    var hOverlap = Math.min(r.x + r.width, o.x + o.width) - Math.max(r.x, o.x);
    if (hOverlap > 0) {
      // Snap bottom of active to top of o
      var diffTop = Math.abs(r.y - (o.y - r.height));
      if (diffTop <= threshold && diffTop < minDistance) {
        minDistance = diffTop;
        bestY = o.y - r.height;
        snapped = true;
      }
      // Snap top of active to bottom of o
      var diffBottom = Math.abs(r.y - (o.y + o.height));
      if (diffBottom <= threshold && diffBottom < minDistance) {
        minDistance = diffBottom;
        bestY = o.y + o.height;
        snapped = true;
      }
    }

    // Corner / edge alignments when adjacent
    if (Math.abs(r.y - o.y) <= threshold) {
      var testRect = { x: bestX, y: o.y, width: r.width, height: r.height };
      if (touches(testRect, o)) {
        bestY = o.y;
        snapped = true;
      }
    }
    if (Math.abs((r.y + r.height) - (o.y + o.height)) <= threshold) {
      var testRectBottom = { x: bestX, y: o.y + o.height - r.height, width: r.width, height: r.height };
      if (touches(testRectBottom, o)) {
        bestY = o.y + o.height - r.height;
        snapped = true;
      }
    }
    if (Math.abs(r.x - o.x) <= threshold) {
      var testRectLeft = { x: o.x, y: bestY, width: r.width, height: r.height };
      if (touches(testRectLeft, o)) {
        bestX = o.x;
        snapped = true;
      }
    }
    if (Math.abs((r.x + r.width) - (o.x + o.width)) <= threshold) {
      var testRectRight = { x: o.x + o.width - r.width, y: bestY, width: r.width, height: r.height };
      if (touches(testRectRight, o)) {
        bestX = o.x + o.width - r.width;
        snapped = true;
      }
    }
  }

  return {
    x: Math.round(bestX),
    y: Math.round(bestY),
    snapped: snapped
  };
}

function attachFlush(activeOutput, others) {
  var r = getRect(activeOutput);
  var validOthers = [];
  for (var i = 0; i < others.length; i++) {
    var o = getRect(others[i]);
    if (o.outputId !== r.outputId) {
      validOthers.push(o);
    }
  }
  if (validOthers.length === 0) {
    return { x: r.x, y: r.y };
  }

  if (touchesAny(r, validOthers)) {
    return { x: r.x, y: r.y };
  }

  var bestCandidate = null;
  var minDistanceSq = Infinity;

  for (var j = 0; j < validOthers.length; j++) {
    var target = validOthers[j];

    var clampY = Math.max(target.y - r.height + Math.min(10, r.height / 2),
                          Math.min(target.y + target.height - Math.min(10, r.height / 2), r.y));
    var cRight = { x: target.x + target.width, y: clampY };
    var cLeft = { x: target.x - r.width, y: clampY };

    var clampX = Math.max(target.x - r.width + Math.min(10, r.width / 2),
                          Math.min(target.x + target.width - Math.min(10, r.width / 2), r.x));
    var cBelow = { x: clampX, y: target.y + target.height };
    var cAbove = { x: clampX, y: target.y - r.height };

    var candidates = [cRight, cLeft, cBelow, cAbove];
    for (var k = 0; k < candidates.length; k++) {
      var cand = candidates[k];
      var distSq = (cand.x - r.x) * (cand.x - r.x) + (cand.y - r.y) * (cand.y - r.y);
      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
        bestCandidate = cand;
      }
    }
  }

  return {
    x: Math.round(bestCandidate ? bestCandidate.x : r.x),
    y: Math.round(bestCandidate ? bestCandidate.y : r.y)
  };
}

function tidyGaps(outputs, maxGapThreshold) {
  var threshold = (maxGapThreshold !== undefined) ? Number(maxGapThreshold) : 24;
  if (!outputs || outputs.length <= 1) {
    return outputs;
  }
  var result = JSON.parse(JSON.stringify(outputs));

  for (var i = 0; i < result.length; i++) {
    if (!result[i] || result[i].active === false || result[i].disabled) {
      continue;
    }
    var r1 = getRect(result[i]);
    for (var j = 0; j < result.length; j++) {
      if (i === j || !result[j] || result[j].active === false || result[j].disabled) continue;
      var r2 = getRect(result[j]);

      var vOverlap = Math.min(r1.y + r1.height, r2.y + r2.height) - Math.max(r1.y, r2.y);
      if (vOverlap > 0) {
        var hGap = r2.x - (r1.x + r1.width);
        if (hGap > 0 && hGap <= threshold) {
          var shiftX = hGap;
          result[j].x = Math.round(result[j].x - shiftX);
          r2.x = result[j].x;
        }
      }

      var hOverlap = Math.min(r1.x + r1.width, r2.x + r2.width) - Math.max(r1.x, r2.x);
      if (hOverlap > 0) {
        var vGap = r2.y - (r1.y + r1.height);
        if (vGap > 0 && vGap <= threshold) {
          var shiftY = vGap;
          result[j].y = Math.round(result[j].y - shiftY);
          r2.y = result[j].y;
        }
      }
    }
  }

  return result;
}

function derivePrimary(outputs) {
  if (!outputs || outputs.length === 0) return null;
  for (var i = 0; i < outputs.length; i++) {
    if (outputs[i].isPrimary) return outputs[i];
  }
  for (var j = 0; j < outputs.length; j++) {
    if (outputs[j].x === 0 && outputs[j].y === 0) return outputs[j];
  }
  return outputs[0];
}

function rebaseToPrimary(outputs, primaryId) {
  if (!outputs || outputs.length === 0) {
    return [];
  }
  var result = JSON.parse(JSON.stringify(outputs));

  var primaryIndex = -1;
  if (primaryId) {
    for (var i = 0; i < result.length; i++) {
      if (result[i].outputId === primaryId || result[i].name === primaryId) {
        primaryIndex = i;
        break;
      }
    }
  }
  if (primaryIndex === -1) {
    var derived = derivePrimary(result);
    for (var j = 0; j < result.length; j++) {
      if (result[j].outputId === derived.outputId) {
        primaryIndex = j;
        break;
      }
    }
  }
  if (primaryIndex === -1) {
    primaryIndex = 0;
  }

  var primary = result[primaryIndex];
  var dx = Number(primary.x || 0);
  var dy = Number(primary.y || 0);

  for (var k = 0; k < result.length; k++) {
    result[k].x = Math.round(result[k].x - dx);
    result[k].y = Math.round(result[k].y - dy);
    result[k].isPrimary = (k === primaryIndex);
  }

  return result;
}
function normalizeTransform(transform) {
  var value = String(transform === undefined || transform === null ? "0" : transform).toLowerCase();
  var aliases = {
    "normal": "0",
    "90": "1",
    "180": "2",
    "270": "3",
    "flipped": "4",
    "flipped-90": "5",
    "flipped-180": "6",
    "flipped-270": "7"
  };
  if (aliases[value] !== undefined) {
    return aliases[value];
  }
  var numeric = Number(value);
  return isFinite(numeric) ? String(numeric) : value;
}

function layoutsMatch(expectedOutputs, actualOutputs) {
  var expected = (expectedOutputs || []).filter(function (output) {
    return output && output.active !== false && !output.disabled;
  });
  var actual = (actualOutputs || []).filter(function (output) {
    return output && output.active !== false && !output.disabled;
  });
  if (expected.length !== actual.length) {
    return false;
  }

  for (var i = 0; i < expected.length; i++) {
    var wanted = expected[i];
    var found = null;
    for (var j = 0; j < actual.length; j++) {
      if ((actual[j].outputId || actual[j].name) === (wanted.outputId || wanted.name)) {
        found = actual[j];
        break;
      }
    }
    if (!found) {
      return false;
    }
    if (wanted.mirror) {
      if (String(found.mirror || "") !== String(wanted.mirror)) {
        return false;
      }
      continue;
    }
    if (found.mirror) {
      return false;
    }
    var values = [
      Number(found.width),
      Number(found.height),
      Number(found.refresh),
      Number(found.scale),
      Number(found.x),
      Number(found.y),
      Number(wanted.width),
      Number(wanted.height),
      Number(wanted.refresh),
      Number(wanted.scale),
      Number(wanted.x),
      Number(wanted.y)
    ];
    for (var valueIndex = 0; valueIndex < values.length; valueIndex++) {
      if (!isFinite(values[valueIndex])) {
        return false;
      }
    }
    if (normalizeTransform(found.transform) !== normalizeTransform(wanted.transform) ||
        values[0] !== values[6] ||
        values[1] !== values[7] ||
        Math.abs(values[2] - values[8]) > 0.05 ||
        Math.abs(values[3] - values[9]) > 0.01 ||
        Math.abs(values[4] - values[10]) > 1 ||
        Math.abs(values[5] - values[11]) > 1) {
      return false;
    }
  }
  return true;
}


function canonicalizeModeId(width, height, refresh) {
  var w = Number(width);
  var h = Number(height);
  var r = Number(refresh);
  if (!isFinite(w) || !isFinite(h) || !isFinite(r) || w <= 0 || h <= 0 || r <= 0) {
    return "";
  }
  var hzStr = r.toFixed(2).replace(/\.00$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
  return w + "x" + h + "@" + hzStr;
}


if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    isQuarterTurn: isQuarterTurn,
    computeLogicalSize: computeLogicalSize,
    getScaleLadder: getScaleLadder,
    coerceScale: coerceScale,
    getRect: getRect,
    computeSceneBounds: computeSceneBounds,
    fitViewport: fitViewport,
    dragPosition: dragPosition,
    outputAtPoint: outputAtPoint,
    rectanglesOverlap: rectanglesOverlap,
    touches: touches,
    touchesAny: touchesAny,
    snapToNearestEdge: snapToNearestEdge,
    attachFlush: attachFlush,
    tidyGaps: tidyGaps,
    derivePrimary: derivePrimary,
    rebaseToPrimary: rebaseToPrimary,
    canonicalizeModeId: canonicalizeModeId,
    layoutsMatch: layoutsMatch
  };
}
