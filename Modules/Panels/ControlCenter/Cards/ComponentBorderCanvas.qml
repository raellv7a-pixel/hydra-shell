import QtQuick
import qs.Commons

Canvas {
  id: componentBorderCanvas

  required property var panelRoot
  readonly property var root: panelRoot

  property string styleKey: ""
  property bool styleRoot: false

  visible: root.componentBorderVisible(styleKey, styleRoot) && width > 0 && height > 0
  opacity: 0.86
  antialiasing: true

  readonly property string animation: root.componentBorderAnimation(styleKey)
  readonly property var borderColors: root.componentBorderColors(styleKey)
  readonly property real animationSpeed: root.clamp(root.componentBorderSpeed(styleKey), 0.15, 3)
  readonly property real borderWidth: Math.max(1, Math.round(root.componentBorderWidth(styleKey) * root.panelUnit))
  readonly property bool reactive: animation.indexOf("reactive") === 0
  readonly property bool animationActive: reactive ? root.musicActive : animation !== "static"
  readonly property real phase: animationActive ? root.sliderEffectPhase : 0

  onAnimationChanged: requestPaint()
  onAnimationSpeedChanged: requestPaint()
  onBorderColorsChanged: requestPaint()
  onBorderWidthChanged: requestPaint()
  onPhaseChanged: requestPaint()
  onVisibleChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function rgba(c, alpha) {
    const color = typeof c === "string" ? Qt.color(c) : c;
    return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
  }

  function roundedRect(ctx, x, y, w, h, r) {
    const rr = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + rr, y);
    ctx.lineTo(x + w - rr, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
    ctx.lineTo(x + w, y + h - rr);
    ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
    ctx.lineTo(x + rr, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
    ctx.lineTo(x, y + rr);
    ctx.quadraticCurveTo(x, y, x + rr, y);
  }

  function borderPoint(t, inset, radius) {
    const x = inset;
    const y = inset;
    const w = width - inset * 2;
    const h = height - inset * 2;
    const r = Math.min(radius, w / 2, h / 2);
    const top = Math.max(1, w - r * 2);
    const side = Math.max(1, h - r * 2);
    const arc = Math.PI * r / 2;
    const perimeter = top * 2 + side * 2 + arc * 4;
    let d = ((t % 1) + 1) % 1 * perimeter;

    if (d < top)
      return {
        x: x + r + d,
        y: y,
        angle: 0
      };
    d -= top;
    if (d < arc) {
      const a = -Math.PI / 2 + d / arc * Math.PI / 2;
      return {
        x: x + w - r + Math.cos(a) * r,
        y: y + r + Math.sin(a) * r,
        angle: a + Math.PI / 2
      };
    }
    d -= arc;
    if (d < side)
      return {
        x: x + w,
        y: y + r + d,
        angle: Math.PI / 2
      };
    d -= side;
    if (d < arc) {
      const a = d / arc * Math.PI / 2;
      return {
        x: x + w - r + Math.cos(a) * r,
        y: y + h - r + Math.sin(a) * r,
        angle: a + Math.PI / 2
      };
    }
    d -= arc;
    if (d < top)
      return {
        x: x + w - r - d,
        y: y + h,
        angle: Math.PI
      };
    d -= top;
    if (d < arc) {
      const a = Math.PI / 2 + d / arc * Math.PI / 2;
      return {
        x: x + r + Math.cos(a) * r,
        y: y + h - r + Math.sin(a) * r,
        angle: a + Math.PI / 2
      };
    }
    d -= arc;
    if (d < side)
      return {
        x: x,
        y: y + h - r - d,
        angle: -Math.PI / 2
      };

    d -= side;
    const a = Math.PI + d / arc * Math.PI / 2;
    return {
      x: x + r + Math.cos(a) * r,
      y: y + r + Math.sin(a) * r,
      angle: a + Math.PI / 2
    };
  }

  function drawSpark(ctx, t, size, color, alpha, inset, radius) {
    const p = borderPoint(t, inset, radius);
    const nx = Math.cos(p.angle + Math.PI / 2);
    const ny = Math.sin(p.angle + Math.PI / 2);
    const tx = Math.cos(p.angle);
    const ty = Math.sin(p.angle);
    ctx.fillStyle = rgba(color, alpha);
    ctx.beginPath();
    ctx.moveTo(p.x + nx * size * 0.25, p.y + ny * size * 0.25);
    ctx.lineTo(p.x - tx * size * 0.55 - nx * size * 0.8, p.y - ty * size * 0.55 - ny * size * 0.8);
    ctx.lineTo(p.x + tx * size * 1.25 - nx * size * 0.25, p.y + ty * size * 1.25 - ny * size * 0.25);
    ctx.closePath();
    ctx.fill();
  }

  function applyDash(ctx, pattern, offset) {
    if (typeof ctx.setLineDash !== "function")
      return;
    ctx.setLineDash(pattern);
    ctx.lineDashOffset = offset || 0;
  }

  onPaint: {
    const ctx = getContext("2d");
    ctx.clearRect(0, 0, width, height);
    if (!visible || width <= 0 || height <= 0)
      return;

    const lineWidth = borderWidth;
    const inset = lineWidth / 2;
    const colors = borderColors && borderColors.length > 0 ? borderColors : [Color.mPrimary];
    const energy = reactive ? root.spectrumAverage() : 0;
    const alpha = reactive ? root.clamp(0.48 + energy * 0.46, 0.48, 0.94) : 0.86;
    const flow = animation === "flow" || animation === "flowEase" || animation === "spark" || animation === "reactiveFlow" || animation === "reactiveSpark" || animation === "scan" || animation === "profileAurora" || animation === "profileSpotlight";
    const fade = animation === "fade" || animation === "reactivePulse";
    const raw = phase * (flow ? 0.035 : 0.16) * animationSpeed;
    const eased = raw + Math.sin(raw * 1.6) * 0.42;
    const p = animation === "flowEase" ? eased : raw;
    const radius = Math.max(0, Number(parent?.radius || Style.radiusM) - lineWidth / 2);
    const pulse = 0.5 + Math.sin(p * 2.4) * 0.5;
    const pathWidth = Math.max(1, (width - lineWidth) * 2 + (height - lineWidth) * 2);
    const movingDash = animation === "chase";
    const comet = animation === "comet";
    const neon = animation === "neon";
    const corners = animation === "corners";
    const orbitDots = animation === "orbitDots";
    const scan = animation === "scan";

    if (neon) {
      ctx.shadowColor = rgba(colors[0], 0.45 + pulse * 0.28);
      ctx.shadowBlur = Math.max(6, lineWidth * (2.6 + pulse * 2.2));
    }

    if (scan && colors.length > 1) {
      const sweep = ((p * 0.22) % 1 + 1) % 1;
      const gradient = ctx.createLinearGradient(width * (sweep - 0.45), 0, width * (sweep + 0.45), height);
      gradient.addColorStop(0, rgba(colors[0], 0.08));
      gradient.addColorStop(0.46, rgba(colors[1 % colors.length], alpha));
      gradient.addColorStop(0.54, rgba(colors[2 % colors.length], alpha));
      gradient.addColorStop(1, rgba(colors[0], 0.08));
      ctx.strokeStyle = gradient;
    } else if (flow && colors.length > 1) {
      const angle = p % (Math.PI * 2);
      const cx = width / 2;
      const cy = height / 2;
      const dx = Math.cos(angle) * width / 2;
      const dy = Math.sin(angle) * height / 2;
      const gradient = ctx.createLinearGradient(cx - dx, cy - dy, cx + dx, cy + dy);
      for (let i = 0; i < colors.length; i++)
        gradient.addColorStop(i / Math.max(1, colors.length - 1), rgba(colors[i], alpha));
      ctx.strokeStyle = gradient;
    } else if (fade && colors.length > 1) {
      const index = Math.floor(Math.abs(p)) % colors.length;
      ctx.strokeStyle = rgba(colors[index], alpha);
    } else {
      ctx.strokeStyle = rgba(colors[0], alpha);
    }

    ctx.lineWidth = lineWidth;
    if (animation === "reactivePulse")
      applyDash(ctx, [Math.max(8, lineWidth * 4), Math.max(5, lineWidth * 2)], -(p * 52));
    else if (movingDash)
      applyDash(ctx, [Math.max(10, lineWidth * 5), Math.max(8, lineWidth * 4)], -(p * 52));
    else if (comet)
      applyDash(ctx, [Math.max(24, pathWidth * 0.12), Math.max(36, pathWidth * 0.68)], -(p * 52));
    else
      applyDash(ctx, [], 0);
    roundedRect(ctx, inset, inset, width - lineWidth, height - lineWidth, radius);
    ctx.stroke();
    ctx.shadowBlur = 0;
    applyDash(ctx, [], 0);

    if (corners) {
      const corner = Math.min(width, height) * 0.22;
      ctx.strokeStyle = rgba(colors[1 % colors.length], 0.48 + pulse * 0.32);
      ctx.lineWidth = lineWidth + 1;
      ctx.lineCap = "round";
      for (let i = 0; i < 4; i++) {
        const left = i === 0 || i === 3;
        const topSide = i < 2;
        const sx = left ? inset + radius * 0.55 : width - inset - radius * 0.55;
        const sy = topSide ? inset : height - inset;
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(left ? Math.min(sx + corner, width - inset) : Math.max(sx - corner, inset), sy);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(left ? inset : width - inset, topSide ? inset + radius * 0.55 : height - inset - radius * 0.55);
        ctx.lineTo(left ? inset : width - inset, topSide ? Math.min(inset + radius * 0.55 + corner, height - inset) : Math.max(height - inset - radius * 0.55 - corner, inset));
        ctx.stroke();
      }
    }

    if (animation === "spark" || animation === "reactiveSpark" || orbitDots) {
      const sparkCount = animation === "reactiveSpark" ? 5 : 7;
      const boost = animation === "reactiveSpark" ? root.clamp(0.45 + energy * 0.9, 0.45, 1.15) : 0.85;
      for (let i = 0; i < sparkCount; i++) {
        const local = (p * 0.16 + i / sparkCount) % 1;
        const flicker = 0.45 + 0.55 * Math.abs(Math.sin((p + i * 1.71) * 2.4));
        if (orbitDots) {
          const point = borderPoint(local, inset + lineWidth * 0.35, radius);
          ctx.fillStyle = rgba(colors[i % colors.length], 0.26 + flicker * 0.5);
          ctx.beginPath();
          ctx.arc(point.x, point.y, Math.max(2, lineWidth * (0.75 + flicker * 0.6)), 0, Math.PI * 2);
          ctx.fill();
        } else {
          drawSpark(ctx, local, Math.max(3, lineWidth * (1.4 + flicker)) * boost, colors[i % colors.length], 0.18 + flicker * 0.42, inset + lineWidth * 0.4, radius);
        }
      }
    }
  }
}
