import QtQuick
import qs.Commons
import qs.Services.Media

// Canvas-drawn audio spectrum effect shared by MediaCard (compact bar
// player) and MediaDetailsCard (expanded view). `effect` picks one of 10
// styles; `values` feeds live spectrum data from SpectrumService.
Item {
  id: visualizer

  required property var panelRoot

  property string effect: "bars"
  property bool active: false
  property var values: SpectrumService.values
  property real phase: 0
  property real clipRadius: 0

  visible: effect !== "none"
  opacity: active ? 1 : 0.24

  Behavior on opacity {
    NumberAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  onValuesChanged: {
    visualizer.phase += 0.18;
    visualCanvas.requestPaint();
  }

  onEffectChanged: visualCanvas.requestPaint()
  onActiveChanged: visualCanvas.requestPaint()

  function sample(index, fallback) {
    if (!values)
      return fallback;
    const len = values.length;
    if (len === undefined || len === 0)
      return fallback;
    const safeIndex = Math.max(0, Math.min(len - 1, Math.round(index)));
    const value = Number(values[safeIndex] || 0);
    return panelRoot.clamp(value, 0, 1);
  }

  function average() {
    if (!values)
      return 0;
    const len = values.length;
    if (len === undefined || len === 0)
      return 0;
    let total = 0;
    for (let i = 0; i < len; i++)
      total += Number(values[i] || 0);
    return panelRoot.clamp(total / len, 0, 1);
  }

  function colorToRgba(c, alpha) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + alpha + ")";
  }

  function roundedRect(ctx, x, y, w, h, r) {
    const radius = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
    ctx.lineTo(x + radius, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
  }

  Canvas {
    id: visualCanvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      if (visualizer.effect === "none" || width <= 0 || height <= 0)
        return;

      ctx.save();
      try {
        if (visualizer.clipRadius > 0) {
          ctx.beginPath();
          visualizer.roundedRect(ctx, 0, 0, width, height, visualizer.clipRadius);
          ctx.clip();
        }

        const t = visualizer.phase;
        const avg = visualizer.average();
        const beat = visualizer.active ? panelRoot.clamp(0.25 + avg * 1.8, 0.25, 1.35) : 0.16;

        const primary = Color.mPrimary;
        const secondary = Color.mSecondary;
        const tertiary = Color.mTertiary;

        if (visualizer.effect === "bars") {
          const bars = 24;
          const gap = 4;
          const barWidth = Math.max(2, (width - gap * (bars - 1)) / bars);
          for (let i = 0; i < bars; i++) {
            const sampleIndex = (i / Math.max(1, bars - 1)) * ((visualizer.values?.length ?? 1) - 1);
            const level = panelRoot.clamp(0.08 + visualizer.sample(sampleIndex, 0) * beat, 0.06, 0.92);
            const h = height * level;
            const x = i * (barWidth + gap);
            const y = height - h;

            const grad = ctx.createLinearGradient(x, y, x, height);
            grad.addColorStop(0, visualizer.colorToRgba(primary, 0.08 + level * 0.4));
            grad.addColorStop(1, visualizer.colorToRgba(secondary, 0.08 + level * 0.2));
            ctx.fillStyle = grad;

            ctx.beginPath();
            visualizer.roundedRect(ctx, x, y, barWidth, h, barWidth / 2);
            ctx.fill();

            ctx.fillStyle = visualizer.colorToRgba(primary, 0.2 + level * 0.5);
            ctx.beginPath();
            ctx.arc(x + barWidth / 2, y + barWidth / 2, barWidth / 2, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "wave") {
          ctx.lineWidth = Math.max(1.5, 2.5 * panelRoot.panelUnit);

          ctx.strokeStyle = visualizer.colorToRgba(secondary, visualizer.active ? 0.2 : 0.1);
          ctx.beginPath();
          for (let x = 0; x <= width; x += 4) {
            const p = x / width;
            const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
            const amp = height * (0.03 + visualizer.sample(sampleIndex, 0) * 0.25 * beat);
            const y = height * 0.5 + Math.sin(p * Math.PI * 3 + t * 0.8) * amp;
            if (x === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();

          ctx.strokeStyle = visualizer.colorToRgba(primary, visualizer.active ? 0.45 : 0.2);
          ctx.beginPath();
          for (let x = 0; x <= width; x += 4) {
            const p = x / width;
            const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
            const amp = height * (0.05 + visualizer.sample(sampleIndex, 0) * 0.36 * beat);
            const y = height * 0.5 + Math.sin(p * Math.PI * 4 + t) * amp;
            if (x === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();

          ctx.lineTo(width, height);
          ctx.lineTo(0, height);
          ctx.closePath();
          const grad = ctx.createLinearGradient(0, height * 0.5, 0, height);
          grad.addColorStop(0, visualizer.colorToRgba(primary, 0.1));
          grad.addColorStop(1, visualizer.colorToRgba(primary, 0.0));
          ctx.fillStyle = grad;
          ctx.fill();

          return;
        }

        if (visualizer.effect === "shock") {
          const cx = width * 0.5;
          const cy = height * 0.5;
          const maxR = Math.max(width, height) * 0.9;

          for (let i = 0; i < 5; i++) {
            const progress = (t * (0.06 + avg * 0.16) + i * 0.2) % 1;
            const radius = 16 + progress * maxR;
            const colors = [primary, secondary, tertiary];
            const color = colors[i % 3];

            ctx.lineWidth = Math.max(1, (1.4 + beat * 2 * (1 - progress)) * panelRoot.panelUnit);

            ctx.strokeStyle = visualizer.colorToRgba(color, (1 - progress) * (visualizer.active ? 0.42 : 0.12));
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();
          }
          return;
        }

        if (visualizer.effect === "pulse") {
          for (let i = 0; i < 38; i++) {
            const sampleIndex = (i / 37) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0);
            const p = (i * 0.618 + t * 0.03) % 1;
            const x = width * ((i * 37 % 101) / 100);
            const y = height * ((Math.sin(i * 7.3 + t) + 1) / 2);
            const r = 1.2 + 7 * amp * beat;

            const colors = [primary, secondary, tertiary];
            const color = colors[i % 3];

            if (amp > 0.4 && visualizer.active) {
              for (let j = 0; j < 5; j++) {
                const jx = width * (((i + j) * 37 % 101) / 100);
                const jy = height * ((Math.sin((i + j) * 7.3 + t) + 1) / 2);
                const dist = Math.sqrt(Math.pow(x - jx, 2) + Math.pow(y - jy, 2));
                if (dist < 50) {
                  ctx.strokeStyle = visualizer.colorToRgba(color, 0.05 + amp * 0.1);
                  ctx.lineWidth = 1;
                  ctx.beginPath();
                  ctx.moveTo(x, y);
                  ctx.lineTo(jx, jy);
                  ctx.stroke();
                }
              }
            }

            ctx.fillStyle = visualizer.colorToRgba(color, 0.04 + p * 0.1);
            ctx.beginPath();
            ctx.arc(x, y, r * 2.5, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = visualizer.colorToRgba(color, 0.2 + p * 0.3);
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "nebula") {
          for (let i = 0; i < 6; i++) {
            const sampleIndex = (i / 5) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0.2);
            const x = width * (0.2 + 0.6 * ((i * 1.618 + t * 0.02) % 1));
            const y = height * (0.2 + 0.6 * ((i * 2.718 + Math.sin(t * 0.05)) % 1));
            const r = Math.max(width, height) * 0.3 * (1 + amp * beat * 0.5);

            const colors = [primary, secondary, tertiary];
            const color = colors[i % 3];

            const grad = ctx.createRadialGradient(x, y, 0, x, y, r);
            grad.addColorStop(0, visualizer.colorToRgba(color, 0.15 + amp * 0.15));
            grad.addColorStop(1, visualizer.colorToRgba(color, 0));

            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "aurora") {
          const bands = 3;
          for (let b = 0; b < bands; b++) {
            const colors = [primary, secondary, tertiary];
            const color = colors[b % 3];

            ctx.beginPath();
            ctx.moveTo(0, height);

            for (let x = 0; x <= width; x += 10) {
              const p = x / width;
              const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
              const amp = visualizer.sample(sampleIndex, 0);

              const wave1 = Math.sin(p * Math.PI * 2 + t * 0.5 + b * 2);
              const wave2 = Math.sin(p * Math.PI * 4 - t * 0.3 + b);
              const y = height * 0.5 + (wave1 * 0.3 + wave2 * 0.2) * height * (1 + amp * beat);

              ctx.lineTo(x, y);
            }

            ctx.lineTo(width, height);
            ctx.closePath();

            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, visualizer.colorToRgba(color, 0));
            grad.addColorStop(0.5, visualizer.colorToRgba(color, 0.1 + b * 0.05 + beat * 0.05));
            grad.addColorStop(1, visualizer.colorToRgba(color, 0.02));

            ctx.fillStyle = grad;
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "constellation") {
          const nodes = 30;
          const points = [];
          for (let i = 0; i < nodes; i++) {
            const px = ((i * 137.5) % 100) / 100 * width;
            const py = ((i * 93.1) % 100) / 100 * height;
            points.push({
                          x: px,
                          y: py,
                          i: i
                        });
          }

          ctx.lineWidth = 1;
          for (let i = 0; i < nodes; i++) {
            const p1 = points[i];
            for (let j = i + 1; j < nodes; j++) {
              const p2 = points[j];
              const dist = Math.sqrt(Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2));
              if (dist < width * 0.3) {
                const sampleIndex = ((i + j) / (nodes * 2)) * ((visualizer.values?.length ?? 1) - 1);
                const amp = visualizer.sample(sampleIndex, 0);

                if (amp > 0.3) {
                  ctx.strokeStyle = visualizer.colorToRgba(secondary, (1 - dist / (width * 0.3)) * amp * beat * 0.5);
                  ctx.beginPath();
                  ctx.moveTo(p1.x, p1.y);
                  ctx.lineTo(p2.x, p2.y);
                  ctx.stroke();
                }
              }
            }
          }

          for (let i = 0; i < nodes; i++) {
            const p = points[i];
            const sampleIndex = (i / nodes) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0);

            const r = 1 + amp * 4 * beat;
            ctx.fillStyle = visualizer.colorToRgba(primary, 0.3 + amp * 0.7);
            ctx.beginPath();
            ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "radar") {
          const cx = width / 2;
          const cy = height + 10;
          const r = Math.max(width, height);

          const sweepAngle = Math.PI + (t * 0.8) % Math.PI;

          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.arc(cx, cy, r, sweepAngle - 0.5, sweepAngle);
          ctx.closePath();

          ctx.fillStyle = visualizer.colorToRgba(primary, 0.15);
          ctx.fill();

          for (let i = 0; i < 30; i++) {
            const sampleIndex = (i / 30) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0);

            if (amp > 0.4) {
              const blipAngle = Math.PI + (i / 30) * Math.PI;
              const blipDist = amp * r * 0.9;
              const bx = cx + Math.cos(blipAngle) * blipDist;
              const by = cy + Math.sin(blipAngle) * blipDist;

              const age = (sweepAngle - blipAngle + Math.PI * 2) % (Math.PI * 2);
              if (age < Math.PI) {
                const alpha = Math.max(0, 1 - age / Math.PI);
                ctx.fillStyle = visualizer.colorToRgba(tertiary, alpha * beat);
                ctx.beginPath();
                ctx.arc(bx, by, 3 + amp * 3, 0, Math.PI * 2);
                ctx.fill();
              }
            }
          }

          ctx.strokeStyle = visualizer.colorToRgba(primary, 0.1);
          ctx.lineWidth = 1;
          for (let i = 1; i <= 3; i++) {
            ctx.beginPath();
            ctx.arc(cx, cy, r * (i / 3), Math.PI, Math.PI * 2);
            ctx.stroke();
          }
          return;
        }

        if (visualizer.effect === "mirror") {
          const bars = 28;
          const gap = Math.max(2, width / 140);
          const barWidth = Math.max(2, (width - gap * (bars - 1)) / bars);
          const half = height / 2;
          for (let i = 0; i < bars; i++) {
            const sampleIndex = (i / Math.max(1, bars - 1)) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0);
            const level = panelRoot.clamp(0.08 + amp * beat, 0.05, 1);
            const barH = half * level;
            const x = i * (barWidth + gap);
            const color = level > 0.75 ? tertiary : (level > 0.45 ? secondary : primary);

            ctx.fillStyle = visualizer.colorToRgba(color, 0.12 + level * 0.4);
            ctx.beginPath();
            visualizer.roundedRect(ctx, x, half - barH, barWidth, barH, barWidth / 2);
            ctx.fill();

            ctx.fillStyle = visualizer.colorToRgba(color, 0.08 + level * 0.28);
            ctx.beginPath();
            visualizer.roundedRect(ctx, x, half, barWidth, barH, barWidth / 2);
            ctx.fill();
          }

          ctx.strokeStyle = visualizer.colorToRgba(primary, 0.12);
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(0, half);
          ctx.lineTo(width, half);
          ctx.stroke();
          return;
        }

        if (visualizer.effect === "ribbon") {
          const centerY = height * 0.55;

          function traceRibbon(colorC, freq, speedMul, ampMul, alpha, lw) {
            ctx.lineWidth = Math.max(1, lw * panelRoot.panelUnit);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.strokeStyle = visualizer.colorToRgba(colorC, alpha);
            ctx.beginPath();
            const step = Math.max(3, width / 48);
            let prevX = 0, prevY = centerY;
            for (let x = 0; x <= width; x += step) {
              const p = x / width;
              const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
              const amp = visualizer.sample(sampleIndex, 0);
              const carrier = Math.sin(p * Math.PI * freq + t * speedMul);
              const y = centerY - height * (0.05 + amp * ampMul * beat) * carrier;
              if (x === 0) {
                ctx.moveTo(x, y);
              } else {
                const midX = (prevX + x) / 2, midY = (prevY + y) / 2;
                ctx.quadraticCurveTo(prevX, prevY, midX, midY);
              }
              prevX = x;
              prevY = y;
            }
            ctx.lineTo(width, prevY);
            ctx.stroke();
          }

          ctx.shadowBlur = visualizer.active ? 10 : 0;
          ctx.shadowColor = visualizer.colorToRgba(secondary, 0.5);
          traceRibbon(secondary, 2.6, 0.5, 0.42, visualizer.active ? 0.22 : 0.08, 5);
          ctx.shadowBlur = 0;
          traceRibbon(primary, 3.4, 0.9, 0.5, visualizer.active ? 0.55 : 0.18, 2);
          return;
        }
      } finally {
        ctx.restore();
      }
    }
  }
}
