import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

// Waveform-reactive slider used by every volume/microphone control across
// the dashboard. `effect` selects one of ~14 canvas-drawn visual styles;
// `effectActive`/`effectLevel`/`effectValues` feed live audio data in.
Slider {
  id: reactiveSlider

  required property var panelRoot

  property string effect: "none"
  property bool effectActive: false
  property real effectLevel: 0
  property var effectValues: []
  property bool overflowEffects: false

  readonly property real handleWidth: Math.max(2, Math.round((pressed ? 2 : 4) * panelRoot.panelUnit))
  readonly property real handleHeight: Math.round(28 * panelRoot.panelUnit)
  readonly property real baseTrackHeight: Math.max(6, Math.round(7 * panelRoot.panelUnit))
  readonly property real activeTrackHeight: Math.max(baseTrackHeight, Math.round((8 + panelRoot.clamp(effectLevel, 0, 1) * 8) * panelRoot.panelUnit))
  readonly property real visualTrackHeight: effectActive && effect !== "none" ? activeTrackHeight : baseTrackHeight
  readonly property real trackCanvasHeight: Math.max(handleHeight, Math.round(28 * panelRoot.panelUnit))
  readonly property real effectCanvasHeight: overflowEffects ? Math.max(trackCanvasHeight, Math.round(42 * panelRoot.panelUnit)) : trackCanvasHeight
  readonly property real fillRatio: panelRoot.clamp(visualPosition, 0, 1)

  Layout.preferredHeight: trackCanvasHeight
  padding: Math.round(3 * panelRoot.panelUnit)
  snapMode: Slider.SnapAlways
  implicitHeight: trackCanvasHeight

  onValueChanged: trackCanvas.requestPaint()
  onVisualPositionChanged: trackCanvas.requestPaint()
  onEffectChanged: trackCanvas.requestPaint()
  onEffectActiveChanged: trackCanvas.requestPaint()
  onEffectLevelChanged: trackCanvas.requestPaint()
  onEffectValuesChanged: trackCanvas.requestPaint()
  onOverflowEffectsChanged: trackCanvas.requestPaint()
  onEnabledChanged: trackCanvas.requestPaint()
  onWidthChanged: trackCanvas.requestPaint()
  onHeightChanged: trackCanvas.requestPaint()

  Connections {
    target: panelRoot
    function onSliderEffectPhaseChanged() {
      trackCanvas.requestPaint();
    }
  }

  background: Canvas {
    id: trackCanvas

    x: reactiveSlider.leftPadding
    y: reactiveSlider.topPadding + Style.pixelAlignCenter(reactiveSlider.availableHeight, reactiveSlider.effectCanvasHeight)
    width: reactiveSlider.availableWidth
    height: reactiveSlider.effectCanvasHeight
    antialiasing: true

    // Decaying peak-hold state for the "spectrum" effect (classic VU-meter caps)
    property var spectrumPeaks: []

    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      if (width <= 0 || height <= 0)
        return;

      const centerY = height / 2;
      const inactiveAlpha = reactiveSlider.enabled ? 1 : 0.55;
      const active = reactiveSlider.effectActive && reactiveSlider.effect !== "none" && reactiveSlider.enabled;
      const activeW = width * reactiveSlider.fillRatio;
      const baseH = reactiveSlider.baseTrackHeight;
      const effectH = reactiveSlider.visualTrackHeight;
      const level = panelRoot.clamp(Number(reactiveSlider.effectLevel || 0), 0, 1);
      const values = reactiveSlider.effectValues || [];
      const valuesLen = values.length || 0;
      const phase = panelRoot.sliderEffectPhase;

      function rgba(c, alpha) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + alpha + ")";
      }

      function sample(position) {
        if (valuesLen <= 0)
          return 0;
        const index = Math.max(0, Math.min(valuesLen - 1, Math.round(position * (valuesLen - 1))));
        return panelRoot.clamp(Number(values[index] || 0), 0, 1);
      }

      function roundedRect(x, y, w, h, r) {
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

      function fillRoundedTrack(x, y, w, h, color) {
        ctx.fillStyle = color;
        ctx.beginPath();
        roundedRect(x, y, w, h, h / 2);
        ctx.fill();
      }

      fillRoundedTrack(0, centerY - baseH / 2, width, baseH, rgba(panelRoot.m3SurfaceContainerHighest, inactiveAlpha));

      const grad = ctx.createLinearGradient(0, 0, width, 0);
      grad.addColorStop(0, rgba(Color.mPrimary, active ? 0.84 : 0.9));
      grad.addColorStop(0.62, rgba(Color.mSecondary, active ? 0.78 : 0.86));
      grad.addColorStop(1, rgba(Color.mPrimary, active ? 0.92 : 1));

      if (activeW <= 0)
        return;

      if (!active) {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(Color.mPrimary, inactiveAlpha));
        return;
      }

      ctx.save();
      ctx.beginPath();
      if (reactiveSlider.overflowEffects && reactiveSlider.effect === "ripple")
        ctx.rect(0, 0, width, height);
      else if (reactiveSlider.overflowEffects)
        ctx.rect(0, 0, activeW, height);
      else
        roundedRect(0, centerY - effectH / 2, activeW, effectH, effectH / 2);
      ctx.clip();

      if (reactiveSlider.effect === "spectrum") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(Color.mPrimary, 0.2 + level * 0.12));
        const bands = Math.max(12, Math.min(36, Math.round(activeW / Math.max(4, 6 * panelRoot.panelUnit))));
        if (trackCanvas.spectrumPeaks.length !== bands)
          trackCanvas.spectrumPeaks = new Array(bands).fill(0);
        const slot = activeW / bands;
        const maxBandH = Math.max(baseH, height - Math.round(3 * panelRoot.panelUnit));
        for (let i = 0; i < bands; i++) {
          const p = i / Math.max(1, bands - 1);
          const amp = sample(p);
          const bandH = panelRoot.clamp(baseH + amp * maxBandH * (0.5 + level * 0.38), baseH, maxBandH);
          const bandW = Math.max(1.5, slot * 0.42);
          const x = i * slot + (slot - bandW) / 2;
          const bandColor = i % 3 === 0 ? Color.mSecondary : Color.mPrimary;
          ctx.fillStyle = rgba(bandColor, 0.42 + amp * 0.5);
          ctx.beginPath();
          roundedRect(x, centerY - bandH / 2, bandW, bandH, bandW / 2);
          ctx.fill();

          // Decaying peak-hold cap: snaps up instantly, falls back slowly (classic VU meter)
          const peak = Math.max(amp, trackCanvas.spectrumPeaks[i] - 0.05);
          trackCanvas.spectrumPeaks[i] = peak;
          if (peak > 0.04) {
            const peakH = panelRoot.clamp(baseH + peak * maxBandH * (0.5 + level * 0.38), baseH, maxBandH);
            const capH = Math.max(1.5, 2 * panelRoot.panelUnit);
            ctx.fillStyle = rgba(peak > 0.7 ? Color.mTertiary : Color.mSecondary, 0.5 + peak * 0.4);
            ctx.beginPath();
            roundedRect(x, centerY - peakH / 2 - capH, bandW, capH, capH / 2);
            ctx.fill();
          }
        }
      } else if (reactiveSlider.effect === "filament") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(panelRoot.m3SurfaceContainerHighest, 0.7));
        const filamentStep = Math.max(2, activeW / 64);
        function traceFilament(lineWidth, alpha, blur) {
          ctx.lineCap = "round";
          ctx.lineJoin = "round";
          ctx.lineWidth = lineWidth;
          ctx.strokeStyle = rgba(Color.mPrimary, alpha);
          ctx.shadowBlur = blur;
          ctx.shadowColor = rgba(Color.mSecondary, alpha * 0.9);
          ctx.beginPath();
          for (let x = 0; x <= activeW + filamentStep; x += filamentStep) {
            const p = x / Math.max(1, activeW);
            const amp = sample(p);
            const carrier = Math.sin(p * Math.PI * 7 + phase * 1.8);
            const detail = Math.sin(p * Math.PI * 17 - phase * 1.15) * 0.34;
            const y = centerY + (carrier + detail) * (2 + amp * height * 0.3 + level * 2);
            if (x === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();
        }
        traceFilament(Math.max(5, 7 * panelRoot.panelUnit), 0.16 + level * 0.08, 7 + level * 5);
        ctx.shadowBlur = 0;
        traceFilament(Math.max(1.5, 2 * panelRoot.panelUnit), 0.78 + level * 0.2, 0);
        ctx.shadowColor = "transparent";
      } else if (reactiveSlider.effect === "ripple") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, grad);
        const pulseOriginX = Math.max(1, Math.min(width - 1, activeW));
        for (let i = 0; i < 4; i++) {
          const progress = (phase * 0.24 + i * 0.25) % 1;
          const radius = (3 + progress * (14 + level * 7)) * panelRoot.panelUnit;
          ctx.lineWidth = Math.max(1, (2.2 - progress * 1.2) * panelRoot.panelUnit);
          ctx.strokeStyle = rgba(i % 2 === 0 ? Color.mPrimary : Color.mSecondary, (1 - progress) * (0.22 + level * 0.42));
          ctx.beginPath();
          ctx.arc(pulseOriginX, centerY, radius, 0, Math.PI * 2);
          ctx.stroke();
        }
      } else if (reactiveSlider.effect === "bars") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(Color.mPrimary, 0.24 + level * 0.16));
        const bars = 30;
        const slot = width / bars;
        for (let i = 0; i < bars; i++) {
          const p = i / Math.max(1, bars - 1);
          const amp = sample(p);
          const h = Math.max(baseH, baseH + amp * effectH * 1.25);
          const barW = Math.max(2, slot * 0.46);
          const x = i * slot + slot * 0.27;
          ctx.fillStyle = rgba(i % 2 === 0 ? Color.mPrimary : Color.mSecondary, 0.28 + amp * 0.56);
          ctx.beginPath();
          roundedRect(x, centerY - h / 2, barW, h, barW / 2);
          ctx.fill();
        }
      } else if (reactiveSlider.effect === "blocks") {
        const blocks = 40;
        const slot = activeW / blocks;
        for (let i = 0; i < blocks; i++) {
          const p = i / Math.max(1, blocks - 1);
          const amp = sample(p);
          const blockW = Math.max(2, slot * 0.75);
          const x = i * slot + slot * 0.125;
          const op = 0.3 + (amp * 0.7) + (level * 0.2);
          ctx.fillStyle = rgba(Color.mPrimary, Math.min(1, op));
          ctx.beginPath();
          roundedRect(x, centerY - baseH / 2, blockW, baseH, baseH / 2);
          ctx.fill();
        }
      } else if (reactiveSlider.effect === "dots") {
        const numDots = 24;
        const slot = activeW / numDots;
        for (let i = 0; i < numDots; i++) {
          const p = i / Math.max(1, numDots - 1);
          const amp = sample(p);
          const radius = (baseH * 0.3) + (amp * effectH * 0.35);
          const x = i * slot + slot * 0.5;
          ctx.fillStyle = rgba(i % 2 === 0 ? Color.mPrimary : Color.mSecondary, 0.5 + amp * 0.5);
          ctx.beginPath();
          ctx.arc(x, centerY, radius, 0, Math.PI * 2);
          ctx.fill();
        }
      } else if (reactiveSlider.effect === "zigzag") {
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = Math.max(baseH, effectH * 0.62);
        ctx.strokeStyle = grad;
        ctx.beginPath();
        const steps = 24;
        const amp = Math.max(2, effectH * (0.28 + level * 0.5));
        for (let i = 0; i <= steps; i++) {
          const x = (i / steps) * width;
          const shift = Math.sin(phase * 2 + i * 0.5) * amp;
          const y = centerY + shift;
          if (i === 0)
            ctx.moveTo(x, y);
          else
            ctx.lineTo(x, y);
        }
        ctx.stroke();
      } else if (reactiveSlider.effect === "pulse") {
        const pulse = 0.5 + Math.sin(phase * 2.1) * 0.5;
        const h = panelRoot.clamp(baseH + effectH * (0.18 + level * 0.66 + pulse * 0.18), baseH, effectH * 1.22);
        fillRoundedTrack(0, centerY - h / 2, activeW, h, grad);
        ctx.fillStyle = rgba(Color.mSecondary, 0.1 + pulse * 0.16 + level * 0.14);
        ctx.beginPath();
        roundedRect(0, centerY - h / 2, activeW, h * 0.48, h * 0.24);
        ctx.fill();
      } else if (reactiveSlider.effect === "glow") {
        ctx.shadowBlur = 12 + level * 8;
        ctx.shadowColor = rgba(Color.mPrimary, 0.6 + level * 0.4);
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, grad);
        ctx.shadowBlur = 0;
        ctx.shadowColor = "transparent";
      } else if (reactiveSlider.effect === "wavy_fill") {
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.moveTo(0, centerY + baseH / 2);
        const step = Math.max(2, activeW / 40);
        for (let x = 0; x <= activeW; x += step) {
          const p = x / Math.max(1, activeW);
          const amp = sample(p);
          const y = centerY - baseH / 2 - Math.sin(p * Math.PI * 6 + phase * 2.5) * (effectH * (0.2 + amp * 0.5 + level * 0.3));
          ctx.lineTo(x, y);
        }
        ctx.lineTo(activeW, centerY + baseH / 2);
        ctx.closePath();
        ctx.fill();
      } else if (reactiveSlider.effect === "comet") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(panelRoot.m3SurfaceContainerHighest, 0.55));
        const travel = Math.max(8, activeW);
        const speed = 0.32 + level * 0.68;
        const cometX = ((phase * speed) % 1) * travel;
        const cometR = Math.max(3, effectH * 0.32);
        const tailLen = Math.max(18, travel * 0.3);
        const tailStart = Math.max(0, cometX - tailLen);
        const tailGrad = ctx.createLinearGradient(tailStart, 0, cometX, 0);
        tailGrad.addColorStop(0, rgba(Color.mSecondary, 0));
        tailGrad.addColorStop(1, rgba(Color.mSecondary, 0.55 + level * 0.35));
        ctx.fillStyle = tailGrad;
        ctx.beginPath();
        roundedRect(tailStart, centerY - baseH / 2, cometX - tailStart, baseH, baseH / 2);
        ctx.fill();

        ctx.shadowBlur = 10 + level * 10;
        ctx.shadowColor = rgba(Color.mPrimary, 0.7);
        ctx.fillStyle = rgba(Color.mPrimary, 0.95);
        ctx.beginPath();
        ctx.arc(cometX, centerY, cometR, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0;
        ctx.shadowColor = "transparent";
      } else if (reactiveSlider.effect === "aurora") {
        fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(panelRoot.m3SurfaceContainerHighest, 0.55));
        function auroraBand(colorC, freq, speedMul, ampScale, alpha) {
          ctx.beginPath();
          ctx.moveTo(0, centerY + baseH / 2);
          const bandStep = Math.max(2, activeW / 48);
          for (let x = 0; x <= activeW; x += bandStep) {
            const p = x / Math.max(1, activeW);
            const amp = sample(p);
            const wobble = 0.5 + 0.5 * Math.sin(p * Math.PI * freq + phase * speedMul);
            const y = centerY + baseH / 2 - effectH * (0.15 + amp * 0.5 + level * 0.25) * ampScale * wobble;
            ctx.lineTo(x, y);
          }
          ctx.lineTo(activeW, centerY + baseH / 2);
          ctx.closePath();
          const bandGrad = ctx.createLinearGradient(0, centerY - effectH / 2, 0, centerY + baseH / 2);
          bandGrad.addColorStop(0, rgba(colorC, 0));
          bandGrad.addColorStop(1, rgba(colorC, alpha));
          ctx.fillStyle = bandGrad;
          ctx.fill();
        }
        auroraBand(Color.mTertiary, 2.4, 0.6, 1.0, 0.26 + level * 0.2);
        auroraBand(Color.mSecondary, 3.1, -0.9, 0.75, 0.3 + level * 0.22);
        auroraBand(Color.mPrimary, 4.0, 1.3, 0.5, 0.38 + level * 0.25);
      } else {
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = Math.max(baseH, effectH * 0.7);
        ctx.strokeStyle = grad;
        ctx.beginPath();
        const step = Math.max(3, width / 64);
        for (let x = 0; x <= width + step; x += step) {
          const p = x / Math.max(1, width);
          const amp = sample(p);
          const y = centerY + Math.sin(p * Math.PI * 4 + phase * 1.2) * (effectH * (0.12 + amp * 0.42 + level * 0.18));
          if (x === 0)
            ctx.moveTo(x, y);
          else
            ctx.lineTo(x, y);
        }
        ctx.stroke();
      }

      ctx.restore();

      ctx.fillStyle = rgba(Color.mPrimary, 0.1 + level * 0.12);
      ctx.beginPath();
      const overlayH = reactiveSlider.overflowEffects ? baseH : effectH;
      roundedRect(0, centerY - overlayH / 2, activeW, overlayH, overlayH / 2);
      ctx.fill();
    }
  }

  handle: Item {
    implicitWidth: reactiveSlider.handleWidth
    implicitHeight: reactiveSlider.handleHeight
    x: reactiveSlider.leftPadding + reactiveSlider.visualPosition * (reactiveSlider.availableWidth - width)
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: parent.height
      radius: width / 2
      color: reactiveSlider.enabled ? Color.mPrimary : Color.mOutline

      Behavior on color {
        ColorAnimation {
          duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
        }
      }
    }
  }
}
