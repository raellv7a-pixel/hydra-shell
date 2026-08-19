import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Services.Power
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

Item {
  id: root

  property var pluginApi: ControlCenterService.provider
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real borderPhase: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property string dashboardIcon: cfg.iconName ?? defaults.iconName ?? "layout-dashboard"
  readonly property bool hasPlayer: MediaService.currentPlayer !== null
  readonly property bool musicPlaying: hasPlayer && MediaService.isPlaying
  readonly property bool showBarMediaInfo: cfg.showBarMediaInfo ?? defaults.showBarMediaInfo ?? true
  readonly property bool barMediaShowWhenPaused: cfg.barMediaShowWhenPaused ?? defaults.barMediaShowWhenPaused ?? false
  readonly property bool showMediaMode: showBarMediaInfo && hasPlayer && (musicPlaying || barMediaShowWhenPaused)
  readonly property bool showAlbumArt: cfg.barMediaShowAlbumArt ?? defaults.barMediaShowAlbumArt ?? true
  readonly property bool showVisualizer: cfg.barMediaShowVisualizer ?? defaults.barMediaShowVisualizer ?? true
  readonly property string visualizerType: cfg.barMediaVisualizerType ?? defaults.barMediaVisualizerType ?? "linear"
  readonly property bool showProgressRing: cfg.barMediaShowProgressRing ?? defaults.barMediaShowProgressRing ?? true
  readonly property bool showArtistFirst: cfg.barMediaShowArtistFirst ?? defaults.barMediaShowArtistFirst ?? true
  readonly property bool useFixedWidth: cfg.barMediaUseFixedWidth ?? defaults.barMediaUseFixedWidth ?? false
  readonly property real maxWidth: cfg.barMediaMaxWidth ?? defaults.barMediaMaxWidth ?? 170
  readonly property string mediaLayout: cfg.barMediaLayout ?? defaults.barMediaLayout ?? "auto"
  readonly property bool mediaBeforeIcon: mediaLayout === "media-left" || (mediaLayout === "auto" && section === "right")
  readonly property bool mediaControlsOnLeft: section === "right" || mediaBeforeIcon
  readonly property string scrollingMode: cfg.barMediaScrollingMode ?? defaults.barMediaScrollingMode ?? "hover"
  readonly property string textColorKey: cfg.barMediaTextColor ?? defaults.barMediaTextColor ?? "none"
  readonly property color textColor: Color.resolveColorKey(textColorKey)
  readonly property bool followNoctaliaPerformanceMode: cfg.followNoctaliaPerformanceMode ?? defaults.followNoctaliaPerformanceMode ?? true
  readonly property bool powerSaverPerformanceMode: cfg.powerSaverPerformanceMode ?? defaults.powerSaverPerformanceMode ?? true
  readonly property bool dashboardPerformanceMode: (followNoctaliaPerformanceMode && PowerProfileService.noctaliaPerformanceMode) || (powerSaverPerformanceMode && PowerProfileService.available && PowerProfileService.profile === 0)
  readonly property var componentStyles: cfg.componentStyles ?? ({})
  readonly property string styleKey: "barWidget"
  readonly property color effectiveTextColor: componentColor("text", textColorKey === "none" ? Color.mOnSurface : textColor)
  readonly property color effectiveSubtextColor: componentColor("subtext", Color.mOnSurfaceVariant)
  readonly property color effectiveAccentColor: componentColor("accent", Color.mPrimary)
  readonly property color effectiveButtonBg: componentColor("buttonBackground", Color.mPrimary)
  readonly property color effectiveButtonFg: componentColor("buttonText", Color.mOnPrimary)
  readonly property int dashboardIconSize: Style.toOdd(capsuleHeight * 0.72)
  readonly property int artSize: Style.toOdd(capsuleHeight * 0.75)
  readonly property int hoverControlSize: Style.toOdd(capsuleHeight * 0.72)
  readonly property int progressWidth: 2
  readonly property bool mediaHoverExpanded: showMediaMode && !isVertical && (mainMouseArea.containsMouse || mediaControlsHover.hovered)
  readonly property real mediaControlsWidth: mediaHoverExpanded ? (hoverControlSize * 3 + Style.margin2XS) : 0
  readonly property string title: {
    if (!hasPlayer)
      return pluginApi?.tr("bar.tooltip") || "Dashboard Raell";
    const artist = MediaService.trackArtist;
    const track = MediaService.trackTitle || pluginApi?.tr("bar.noMedia") || "Sem mídia";
    return showArtistFirst ? (artist ? `${artist} - ${track}` : track) : (artist ? `${track} - ${artist}` : track);
  }
  readonly property string spectrumComponentId: "plugin:raell-dashboard:bar:" + screenName + ":" + section + ":" + sectionWidgetIndex
  readonly property bool needsSpectrum: !dashboardPerformanceMode && showMediaMode && showVisualizer && visualizerType !== "" && visualizerType !== "none"
  readonly property var spectrumValues: SpectrumService.values
  readonly property real spectrumEnergy: averageSpectrum()
  readonly property real titleMeasuredWidth: Math.max(0, titleMetrics.advanceWidth)

  function componentStyle() {
    const styles = root.componentStyles || {};
    const globalStyle = styles.__global || {};
    const localStyle = styles[root.styleKey] || {};
    const merged = {};
    root.mergeComponentStyle(merged, globalStyle);
    root.mergeComponentStyle(merged, localStyle);

    return merged;
  }

  function mergeComponentStyle(target, source) {
    if (!source)
      return;

    const colorFields = ["background", "text", "subtext", "accent", "buttonBackground", "buttonText"];
    if (source.enabled === true) {
      target.enabled = true;
      for (let i = 0; i < colorFields.length; i++) {
        const field = colorFields[i];
        if (source[field] !== undefined)
          target[field] = source[field];
      }
    }

    const borderFields = ["borderWidth", "borderScope", "borderColorMode", "borderColorCount", "borderColor1", "borderColor2", "borderColor3", "borderColor4", "borderColor5", "borderAnimation", "borderSpeed"];
    if (source.borderEnabled === true) {
      target.borderEnabled = true;
      for (let i = 0; i < borderFields.length; i++) {
        const field = borderFields[i];
        if (source[field] !== undefined)
          target[field] = source[field];
      }
    }
  }

  function componentColor(field, fallback) {
    const style = root.componentStyle();
    if (!style || style.enabled !== true)
      return fallback;
    const value = String(style[field] || "").trim();
    return value !== "" ? value : fallback;
  }

  function componentBorderEnabled() {
    const style = root.componentStyle();
    return style && style.borderEnabled === true;
  }

  function componentBorderScope() {
    const style = root.componentStyle();
    const value = String(style.borderScope || "all");
    return value === "container" || value === "children" ? value : "all";
  }

  function componentBorderVisible() {
    if (root.dashboardPerformanceMode)
      return false;
    if (!root.componentBorderEnabled())
      return false;
    return root.componentBorderScope() !== "children";
  }

  function componentBorderColors() {
    const style = root.componentStyle();
    if (!style || String(style.borderColorMode || "auto") !== "custom")
      return [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError];

    const source = [style.borderColor1, style.borderColor2, style.borderColor3, style.borderColor4, style.borderColor5];
    const count = Math.max(3, Math.min(5, Number(style.borderColorCount || 3)));
    const colors = [];
    for (let i = 0; i < count; i++) {
      const value = String(source[i] || "").trim();
      colors.push(value !== "" ? value : root.componentColor("accent", Color.mPrimary));
    }
    return colors;
  }

  function averageSpectrum() {
    const values = root.spectrumValues;
    if (!values || values.length === undefined || values.length === 0)
      return 0;
    let total = 0;
    for (let i = 0; i < values.length; i++)
      total += Number(values[i] || 0);
    return Math.max(0, Math.min(1, total / values.length));
  }

  property real mainContentWidth: 0
  readonly property real mediaInfoWidth: {
    if (!showMediaMode)
      return 0;
    if (useFixedWidth)
      return maxWidth;

    let iconWidth = showAlbumArt || showProgressRing ? artSize : 0;
    let margins = Style.margin2S;
    if (iconWidth > 0)
      margins += Style.marginS;
    let textWidth = titleMeasuredWidth > 0 ? titleMeasuredWidth + Style.margin2XXS : 0;
    let total = iconWidth + textWidth + margins;
    mainContentWidth = total - textWidth;
    return Math.min(Math.max(total, capsuleHeight), maxWidth);
  }
  readonly property real contentWidth: {
    if (!showMediaMode)
      return capsuleHeight;
    return dashboardIconSize + Style.marginS + mediaInfoWidth + mediaControlsWidth + Style.margin2S + (mediaHoverExpanded ? Style.marginS : 0);
  }

  Layout.preferredHeight: isVertical ? -1 : Style.getBarHeightForScreen(screenName)
  Layout.preferredWidth: isVertical ? Style.getBarHeightForScreen(screenName) : -1
  Layout.fillHeight: false
  Layout.fillWidth: false

  implicitWidth: isVertical ? capsuleHeight : contentWidth
  implicitHeight: isVertical ? capsuleHeight : capsuleHeight
  visible: true

  TextMetrics {
    id: titleMetrics
    text: root.title
    font.pointSize: root.barFontSize
  }

  onNeedsSpectrumChanged: {
    if (root.needsSpectrum)
      SpectrumService.registerComponent(root.spectrumComponentId);
    else
      SpectrumService.unregisterComponent(root.spectrumComponentId);
  }

  Component.onCompleted: {
    if (root.needsSpectrum)
      SpectrumService.registerComponent(root.spectrumComponentId);
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent(root.spectrumComponentId);
  }

  Behavior on implicitWidth {
    NAnim {
      motionType: NAnim.StandardSpatial
      duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
    }
  }

  NumberAnimation on borderPhase {
    running: !root.dashboardPerformanceMode && Style.motionEnabled && root.componentBorderVisible() && root.componentStyle().borderAnimation !== "static"
    from: 0
    to: 1000
    duration: 60000
    loops: Animation.Infinite
  }

  Rectangle {
    id: container

    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: Style.toOdd(root.isVertical ? root.capsuleHeight : root.contentWidth)
    height: Style.toOdd(root.capsuleHeight)
    radius: Style.radiusL
    color: root.componentColor("background", root.needsSpectrum ? Qt.alpha(Color.mSurfaceVariant, 0.52 + root.spectrumEnergy * 0.18) : Style.capsuleColor)
    border.color: root.componentBorderVisible() ? Qt.alpha(root.effectiveAccentColor, 0.42) : root.componentColor("accent", root.needsSpectrum ? Qt.alpha(root.effectiveAccentColor, 0.22 + root.spectrumEnergy * 0.46) : Style.capsuleBorderColor)
    border.width: root.componentBorderVisible() ? Math.max(1, Style.capsuleBorderWidth) : Style.capsuleBorderWidth
    clip: true

    Behavior on width {
      NAnim {
        motionType: NAnim.StandardSpatial
        duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
      }
    }

    Loader {
      anchors.centerIn: parent
      width: Style.toOdd(parent.width - Style.marginS)
      height: Style.toOdd(parent.height - Style.marginS)
      active: root.needsSpectrum
      z: 0
      sourceComponent: {
        if (!root.needsSpectrum)
          return null;
        if (root.visualizerType === "linear" || root.visualizerType === "bars")
          return linearSpectrum;
        if (root.visualizerType === "mirrored")
          return mirroredSpectrum;
        if (root.visualizerType === "wave" || root.visualizerType === "aurora")
          return waveSpectrum;
        return reactiveSpectrum;
      }
    }

    Rectangle {
      anchors.fill: parent
      visible: root.needsSpectrum && root.musicPlaying
      radius: parent.radius
      color: "transparent"
      border.width: Math.max(1, Math.round(1 + root.spectrumEnergy * 2))
      border.color: Qt.alpha(root.effectiveAccentColor, 0.14 + root.spectrumEnergy * 0.34)
      opacity: 0.9
      z: 1
    }

    Canvas {
      id: componentBorderCanvas

      anchors.fill: parent
      visible: root.componentBorderVisible()
      opacity: 0.86
      antialiasing: true
      z: 3

      readonly property string animation: String(root.componentStyle().borderAnimation || "static")
      readonly property real animationSpeed: Math.max(0.15, Math.min(3, Number(root.componentStyle().borderSpeed || 1)))
      readonly property real borderWidth: Math.max(1, Math.round(Number(root.componentStyle().borderWidth || 2)))
      readonly property var borderColors: root.componentBorderColors()
      readonly property bool flow: animation === "flow" || animation === "flowEase" || animation === "spark" || animation === "reactiveFlow" || animation === "reactiveSpark"
      readonly property bool reactive: animation.indexOf("reactive") === 0
      readonly property real phase: root.borderPhase

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

        const colors = borderColors && borderColors.length > 0 ? borderColors : [Color.mPrimary];
        const lineWidth = borderWidth;
        const inset = lineWidth / 2;
        const energy = reactive ? root.spectrumEnergy : 0;
        const alpha = reactive ? Math.max(0.48, Math.min(0.94, 0.48 + energy * 0.46)) : 0.86;
        const raw = phase * (flow || animation === "scan" ? 0.035 : 0.16) * animationSpeed;
        const eased = raw + Math.sin(raw * 1.6) * 0.42;
        const p = animation === "flowEase" ? eased : raw;
        const radius = Math.max(0, Style.radiusL - lineWidth / 2);
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
        } else if ((animation === "fade" || animation === "reactivePulse") && colors.length > 1) {
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
          const boost = animation === "reactiveSpark" ? Math.max(0.45, Math.min(1.15, 0.45 + energy * 0.9)) : 0.85;
          for (let i = 0; i < sparkCount; i++) {
            const local = (p * 0.16 + i / sparkCount) % 1;
            const flicker = 0.45 + 0.55 * Math.abs(Math.sin((p + i * 1.71) * 2.4));
            const color = colors[i % colors.length];
            if (orbitDots) {
              const point = borderPoint(local, inset + lineWidth * 0.35, radius);
              ctx.fillStyle = rgba(color, 0.26 + flicker * 0.5);
              ctx.beginPath();
              ctx.arc(point.x, point.y, Math.max(2, lineWidth * (0.75 + flicker * 0.6)), 0, Math.PI * 2);
              ctx.fill();
            } else {
              drawSpark(ctx, local, Math.max(3, lineWidth * (1.4 + flicker)) * boost, color, 0.18 + flicker * 0.42, inset + lineWidth * 0.4, radius);
            }
          }
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.isVertical ? 0 : (Style.marginS + (root.mediaControlsOnLeft ? root.mediaControlsWidth + (root.mediaHoverExpanded ? Style.marginS : 0) : 0))
      anchors.rightMargin: root.isVertical ? 0 : (Style.marginS + (!root.mediaControlsOnLeft ? root.mediaControlsWidth + (root.mediaHoverExpanded ? Style.marginS : 0) : 0))
      spacing: Style.marginS
      visible: !root.isVertical && root.showMediaMode
      layoutDirection: root.mediaBeforeIcon ? Qt.RightToLeft : Qt.LeftToRight
      z: 2

      Item {
        Layout.preferredWidth: root.dashboardIconSize
        Layout.preferredHeight: root.dashboardIconSize
        Layout.alignment: Qt.AlignVCenter

        NIcon {
          anchors.centerIn: parent
          icon: root.dashboardIcon
          pointSize: Style.fontSizeL
          color: root.effectiveTextColor
        }
      }

      RowLayout {
        Layout.preferredWidth: root.mediaInfoWidth
        Layout.preferredHeight: root.capsuleHeight
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginS
        layoutDirection: Qt.LeftToRight

        Item {
          readonly property bool hasArt: root.showAlbumArt && MediaService.trackArtUrl !== ""
          visible: root.showAlbumArt || root.showProgressRing
          Layout.preferredWidth: visible ? root.artSize : 0
          Layout.preferredHeight: visible ? root.artSize : 0
          Layout.alignment: Qt.AlignVCenter

          ProgressRing {
            anchors.fill: parent
            visible: root.showProgressRing && parent.hasArt
            progress: MediaService.trackLength > 0 ? MediaService.currentPosition / MediaService.trackLength : 0
            lineWidth: root.progressWidth
          }

          NImageRounded {
            visible: parent.hasArt
            anchors.fill: parent
            anchors.margins: root.showProgressRing ? root.progressWidth * 2 : 0
            radius: width / 2
            imagePath: MediaService.trackArtUrl
            imageFillMode: Image.PreserveAspectCrop
          }

          NIcon {
            visible: !parent.hasArt
            anchors.centerIn: parent
            icon: "music"
            pointSize: Style.fontSizeL
            color: root.effectiveTextColor
          }
        }

        NScrollText {
          id: titleContainer

          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredHeight: root.capsuleHeight
          fadeRoundLeftCorners: !(root.showAlbumArt || root.showProgressRing)
          text: root.title
          cursorShape: Qt.PointingHandCursor
          maxWidth: Math.max(0, root.mediaInfoWidth - root.mainContentWidth)
          forcedHover: mainMouseArea.containsMouse
          fadeExtent: 0.1
          fadeCornerRadius: Style.radiusM
          scrollMode: {
            if (root.scrollingMode === "always")
              return NScrollText.ScrollMode.Always;
            if (root.scrollingMode === "hover")
              return NScrollText.ScrollMode.Hover;
            return NScrollText.ScrollMode.Never;
          }

          NText {
            color: root.effectiveTextColor
            pointSize: root.barFontSize
            elide: Text.ElideNone
          }
        }
      }
    }

    Item {
      readonly property bool hasArt: root.showAlbumArt && MediaService.trackArtUrl !== ""
      visible: root.isVertical && root.showMediaMode
      width: root.artSize
      height: root.artSize
      anchors.centerIn: parent
      z: 2

      ProgressRing {
        anchors.fill: parent
        visible: root.showProgressRing && parent.hasArt
        progress: MediaService.trackLength > 0 ? MediaService.currentPosition / MediaService.trackLength : 0
        lineWidth: root.progressWidth
      }

      NImageRounded {
        visible: parent.hasArt
        anchors.fill: parent
        anchors.margins: root.showProgressRing ? root.progressWidth * 2 : 0
        radius: width / 2
        imagePath: MediaService.trackArtUrl
        imageFillMode: Image.PreserveAspectCrop
      }

      NIcon {
        visible: !parent.hasArt
        anchors.centerIn: parent
        icon: "music"
        pointSize: Style.fontSizeL
        color: root.effectiveTextColor
      }
    }

    NIcon {
      visible: !root.showMediaMode
      anchors.centerIn: parent
      icon: root.dashboardIcon
      pointSize: Style.fontSizeXL
      color: root.effectiveTextColor
      z: 2
    }
  }

  MouseArea {
    id: mainMouseArea

    anchors.fill: parent
    anchors.leftMargin: (!root.isVertical && section === "left" && sectionWidgetIndex === 0) ? -Style.marginS : 0
    anchors.rightMargin: (!root.isVertical && section === "right" && sectionWidgetIndex === sectionWidgetsCount - 1) ? -Style.marginS : 0
    anchors.topMargin: (root.isVertical && section === "left" && sectionWidgetIndex === 0) ? -Style.marginM : 0
    anchors.bottomMargin: (root.isVertical && section === "right" && sectionWidgetIndex === sectionWidgetsCount - 1) ? -Style.marginM : 0
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton

    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.LeftButton) {
                   pluginApi?.togglePanel(screen);
                 } else if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, container, screen);
                 } else if (mouse.button === Qt.MiddleButton && root.hasPlayer) {
                   MediaService.playPause();
                 } else if (mouse.button === Qt.ForwardButton && root.hasPlayer) {
                   MediaService.next();
                 } else if (mouse.button === Qt.BackButton && root.hasPlayer) {
                   MediaService.previous();
                 }
               }

    onEntered: TooltipService.show(root, root.showMediaMode ? root.title : pluginApi?.tr("bar.tooltip"), BarService.getTooltipDirection(root.screen?.name))
    onExited: TooltipService.hide()
  }

  RowLayout {
    id: mediaControls

    anchors.left: root.mediaControlsOnLeft ? container.left : undefined
    anchors.right: root.mediaControlsOnLeft ? undefined : container.right
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    anchors.verticalCenter: container.verticalCenter
    spacing: Style.marginXXS
    visible: root.mediaHoverExpanded
    opacity: visible ? 1 : 0
    z: 30

    Behavior on opacity {
      NAnim {
        motionType: NAnim.StandardEffects
        duration: root.dashboardPerformanceMode ? 0 : Style.animationFast
      }
    }

    HoverHandler {
      id: mediaControlsHover
    }

    NIconButton {
      icon: "player-track-prev"
      baseSize: root.hoverControlSize
      enabled: MediaService.canGoPrevious
      tooltipText: pluginApi?.tr("bar.previous")
      colorBg: Qt.alpha(Color.mSurface, 0.42)
      colorBgHover: root.effectiveButtonBg
      colorFg: Color.mOnSurface
      colorFgHover: root.effectiveButtonFg
      colorBorder: Qt.alpha(Color.mOutline, 0.16)
      colorBorderHover: root.effectiveButtonBg
      onClicked: MediaService.previous()
    }

    NIconButton {
      icon: MediaService.isPlaying ? "player-pause" : "player-play"
      baseSize: root.hoverControlSize
      enabled: root.hasPlayer
      tooltipText: MediaService.isPlaying ? pluginApi?.tr("bar.pause") : pluginApi?.tr("bar.play")
      colorBg: Qt.alpha(root.effectiveButtonBg, 0.22)
      colorBgHover: root.effectiveButtonBg
      colorFg: Color.mOnSurface
      colorFgHover: root.effectiveButtonFg
      colorBorder: Qt.alpha(root.effectiveButtonBg, 0.42)
      colorBorderHover: root.effectiveButtonBg
      onClicked: MediaService.playPause()
    }

    NIconButton {
      icon: "player-track-next"
      baseSize: root.hoverControlSize
      enabled: MediaService.canGoNext
      tooltipText: pluginApi?.tr("bar.next")
      colorBg: Qt.alpha(Color.mSurface, 0.42)
      colorBgHover: root.effectiveButtonBg
      colorFg: Color.mOnSurface
      colorFgHover: root.effectiveButtonFg
      colorBorder: Qt.alpha(Color.mOutline, 0.16)
      colorBorderHover: root.effectiveButtonBg
      onClicked: MediaService.next()
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: {
      const items = [];
      items.push({
                   "label": pluginApi?.tr("context.toggle"),
                   "action": "toggle-dashboard",
                   "icon": root.dashboardIcon
                 });
      if (root.hasPlayer && MediaService.canPlay) {
        items.push({
                     "label": MediaService.isPlaying ? pluginApi?.tr("bar.pause") : pluginApi?.tr("bar.play"),
                     "action": "play-pause",
                     "icon": MediaService.isPlaying ? "media-pause" : "media-play"
                   });
      }
      if (root.hasPlayer && MediaService.canGoPrevious) {
        items.push({
                     "label": pluginApi?.tr("bar.previous"),
                     "action": "previous",
                     "icon": "media-prev"
                   });
      }
      if (root.hasPlayer && MediaService.canGoNext) {
        items.push({
                     "label": pluginApi?.tr("bar.next"),
                     "action": "next",
                     "icon": "media-next"
                   });
      }
      items.push({
                   "label": pluginApi?.tr("context.settings"),
                   "action": "settings",
                   "icon": "settings"
                 });
      return items;
    }

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "toggle-dashboard") {
                     pluginApi?.togglePanel(screen);
                   } else if (action === "play-pause") {
                     MediaService.playPause();
                   } else if (action === "previous") {
                     MediaService.previous();
                   } else if (action === "next") {
                     MediaService.next();
                   } else if (action === "settings" && pluginApi?.manifest) {
                     BarService.openPluginSettings(screen, pluginApi.manifest);
                   }
                 }
  }

  Component {
    id: linearSpectrum

    NLinearSpectrum {
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.56 + root.spectrumEnergy * 0.24
      barPosition: root.barPosition
      mirrored: Settings.data.audio.spectrumMirrored
      showMinimumSignal: true
      minimumSignalValue: root.musicPlaying ? 0.035 : 0.015
    }
  }

  Component {
    id: mirroredSpectrum

    NMirroredSpectrum {
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.56 + root.spectrumEnergy * 0.24
      mirrored: Settings.data.audio.spectrumMirrored
      showMinimumSignal: true
      minimumSignalValue: root.musicPlaying ? 0.035 : 0.015
    }
  }

  Component {
    id: waveSpectrum

    NWaveSpectrum {
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.58 + root.spectrumEnergy * 0.24
      mirrored: Settings.data.audio.spectrumMirrored
      showMinimumSignal: true
      minimumSignalValue: root.musicPlaying ? 0.035 : 0.015
    }
  }

  Component {
    id: reactiveSpectrum

    BarReactiveVisualizer {
      values: SpectrumService.values
      effect: root.visualizerType
      active: root.musicPlaying
      energy: root.spectrumEnergy
    }
  }

  component BarReactiveVisualizer: Item {
    id: reactive

    property var values: []
    property string effect: "pulse"
    property bool active: false
    property real energy: 0
    property real phase: 0

    opacity: active ? 0.78 : 0.34

    NumberAnimation on phase {
      running: reactive.visible && reactive.active && !root.dashboardPerformanceMode && Style.motionEnabled
      from: 0
      to: 1000
      duration: 180000
      loops: Animation.Infinite
    }

    onValuesChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onEffectChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()

    function sample(index, fallback) {
      if (!values || values.length === undefined || values.length === 0)
        return fallback;
      const safeIndex = Math.max(0, Math.min(values.length - 1, Math.round(index)));
      return Math.max(0, Math.min(1, Number(values[safeIndex] || 0)));
    }

    function rgba(color, alpha) {
      return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      antialiasing: true

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (width <= 0 || height <= 0)
          return;

        const t = reactive.phase;
        const beat = reactive.active ? Math.max(0.22, Math.min(1.35, 0.35 + reactive.energy * 2.0)) : 0.18;
        const primary = Color.mPrimary;
        const secondary = Color.mSecondary;
        const tertiary = Color.mTertiary;

        if (reactive.effect === "nebula") {
          for (let i = 0; i < 5; i++) {
            const amp = reactive.sample((i / 4) * ((reactive.values?.length ?? 1) - 1), 0.1);
            const x = width * ((i * 0.31 + t * 0.003) % 1);
            const y = height * (0.25 + 0.55 * ((i * 0.47 + Math.sin(t * 0.015)) % 1));
            const r = Math.max(width, height) * (0.2 + amp * beat * 0.32);
            const color = [primary, secondary, tertiary][i % 3];
            const grad = ctx.createRadialGradient(x, y, 0, x, y, r);
            grad.addColorStop(0, reactive.rgba(color, 0.22 + amp * 0.22));
            grad.addColorStop(1, reactive.rgba(color, 0));
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (reactive.effect === "constellation" || reactive.effect === "radar") {
          const nodes = 18;
          const points = [];
          for (let i = 0; i < nodes; i++) {
            const amp = reactive.sample((i / nodes) * ((reactive.values?.length ?? 1) - 1), 0);
            points.push({
                          x: width * (((i * 37) % 97) / 97),
                          y: height * (0.15 + (((i * 53) % 89) / 89) * 0.7),
                          amp: amp
                        });
          }
          ctx.lineWidth = 1;
          for (let i = 0; i < nodes; i++) {
            for (let j = i + 1; j < nodes; j++) {
              const dx = points[i].x - points[j].x;
              const dy = points[i].y - points[j].y;
              const dist = Math.sqrt(dx * dx + dy * dy);
              if (dist < width * 0.28) {
                const strength = Math.max(points[i].amp, points[j].amp) * beat;
                ctx.strokeStyle = reactive.rgba(secondary, Math.max(0, (1 - dist / (width * 0.28)) * strength * 0.42));
                ctx.beginPath();
                ctx.moveTo(points[i].x, points[i].y);
                ctx.lineTo(points[j].x, points[j].y);
                ctx.stroke();
              }
            }
          }
          for (let i = 0; i < nodes; i++) {
            ctx.fillStyle = reactive.rgba(primary, 0.18 + points[i].amp * 0.62);
            ctx.beginPath();
            ctx.arc(points[i].x, points[i].y, 1.2 + points[i].amp * 3.4 * beat, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        const bars = 20;
        const gap = 2;
        const barW = Math.max(2, (width - gap * (bars - 1)) / bars);
        for (let i = 0; i < bars; i++) {
          const amp = reactive.sample((i / Math.max(1, bars - 1)) * ((reactive.values?.length ?? 1) - 1), 0.03);
          const h = Math.max(2, height * Math.min(1, 0.12 + amp * beat));
          const x = i * (barW + gap);
          const y = (height - h) / 2;
          const grad = ctx.createLinearGradient(x, y, x, y + h);
          grad.addColorStop(0, reactive.rgba(primary, 0.24 + amp * 0.42));
          grad.addColorStop(1, reactive.rgba(tertiary, 0.12 + amp * 0.24));
          ctx.fillStyle = grad;
          ctx.beginPath();
          ctx.moveTo(x + barW / 2, y);
          ctx.lineTo(x + barW, y + barW / 2);
          ctx.lineTo(x + barW, y + h - barW / 2);
          ctx.lineTo(x + barW / 2, y + h);
          ctx.lineTo(x, y + h - barW / 2);
          ctx.lineTo(x, y + barW / 2);
          ctx.closePath();
          ctx.fill();
        }
      }
    }
  }

  component ProgressRing: Canvas {
    property real progress: 0
    property real lineWidth: 2

    function repaint() {
      if (visible && opacity > 0)
        requestPaint();
    }

    onProgressChanged: repaint()
    Component.onCompleted: repaint()

    Connections {
      target: Color
      function onMPrimaryChanged() {
        repaint();
      }
    }

    onPaint: {
      if (width <= 0 || height <= 0)
        return;

      const ctx = getContext("2d");
      const centerX = width / 2;
      const centerY = height / 2;
      const radius = Math.min(width, height) / 2 - lineWidth;
      ctx.reset();
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
      ctx.lineWidth = lineWidth;
      ctx.strokeStyle = Qt.alpha(Color.mOnSurface, 0.34);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + progress * 2 * Math.PI);
      ctx.lineWidth = lineWidth;
      ctx.strokeStyle = Color.mPrimary;
      ctx.lineCap = "round";
      ctx.stroke();
    }
  }
}
