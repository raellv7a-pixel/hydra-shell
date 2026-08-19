import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System
DashboardCard {
  id: profileCard
  styleKey: "profile"
  styleRoot: true
  clip: true
  radius: panelRoot.profileCardRadius(width, height)
  readonly property bool coverIsAnimated: panelRoot.profileWallpaperPath.toLowerCase().endsWith(".gif")
  readonly property bool coverBlurActive: panelRoot.profileCoverBlurEnabled && panelRoot.profileCoverBlur > 0
  readonly property real coverRadius: panelRoot.innerProfileCardRadius(width, height)

  ReactiveRoundedImage {
    id: profileCoverImage
    anchors.fill: parent
    anchors.margins: Math.max(1, Style.borderS)
    visible: panelRoot.profileWallpaperPath !== ""
    radius: profileCard.coverRadius
    imagePath: panelRoot.profileWallpaperPath
    fallbackIcon: ""
  }

  Item {
    id: profileCoverBlurLayer
    anchors.fill: parent
    anchors.margins: Math.max(1, Style.borderS)
    visible: panelRoot.profileWallpaperPath !== "" && profileCard.coverBlurActive
    layer.enabled: visible
    layer.smooth: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: panelRoot.clamp(panelRoot.profileCoverBlur, 0, 1)
      blurMax: 48
      maskEnabled: true
      maskThresholdMin: 0.95
      maskSpreadAtMin: 0.15
      maskSource: ShaderEffectSource {
        sourceItem: Rectangle {
          width: profileCoverBlurLayer.width
          height: profileCoverBlurLayer.height
          radius: profileCard.coverRadius
          color: "white"
        }
      }
    }

    Loader {
      anchors.fill: parent
      active: profileCoverBlurLayer.visible
      sourceComponent: profileCard.coverIsAnimated ? animatedCoverSource : staticCoverSource
    }

    Component {
      id: staticCoverSource
      Image {
        source: panelRoot.profileWallpaperPath
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        asynchronous: true
        antialiasing: true
      }
    }

    Component {
      id: animatedCoverSource
      AnimatedImage {
        source: panelRoot.profileWallpaperPath
        fillMode: Image.PreserveAspectCrop
        playing: !panelRoot.dashboardPerformanceMode
        smooth: true
        mipmap: true
        asynchronous: true
        antialiasing: true
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: Math.max(1, Style.borderS)
    visible: panelRoot.profileWallpaperPath !== "" && panelRoot.profileCoverOverlayEnabled && panelRoot.profileCoverOverlay > 0
    radius: profileCard.coverRadius
    color: Qt.rgba(0, 0, 0, panelRoot.clamp(panelRoot.profileCoverOverlay, 0, 0.88))
  }

  Canvas {
    id: profileCoverBorderCanvas
    anchors.fill: parent
    visible: !panelRoot.dashboardPerformanceMode && panelRoot.profileCoverBorder && panelRoot.profileCoverBorderWidth > 0
    opacity: 0.84
    z: 20
    antialiasing: true

    readonly property var borderColors: panelRoot.profileBorderColors()
    readonly property real phase: panelRoot.profileBorderAnimationActive() ? panelRoot.sliderEffectPhase : 0

    onBorderColorsChanged: requestPaint()
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
      if (width <= 0 || height <= 0)
        return;

      const lineWidth = Math.max(1, Math.round(panelRoot.profileCoverBorderWidth * panelRoot.panelUnit));
      const inset = lineWidth / 2;
      const colors = borderColors && borderColors.length > 0 ? borderColors : [Color.mPrimary];
      const animation = panelRoot.profileCoverBorderAnimation;
      const reactive = animation.indexOf("reactive") === 0;
      const energy = reactive ? panelRoot.spectrumAverage() : 0;
      const alpha = reactive ? panelRoot.clamp(0.48 + energy * 0.46, 0.48, 0.94) : 0.86;
      const flow = animation === "flow" || animation === "flowEase" || animation === "spark" || animation === "reactiveFlow" || animation === "reactiveSpark" || animation === "scan" || animation === "profileAurora" || animation === "profileSpotlight";
      const fade = animation === "fade" || animation === "reactivePulse";
      const speed = panelRoot.clamp(panelRoot.profileCoverBorderSpeed, 0.15, 3);
      const raw = phase * (flow ? 0.035 : 0.16) * speed;
      const eased = raw + Math.sin(raw * 1.6) * 0.42;
      const p = animation === "flowEase" ? eased : raw;
      const radius = Math.max(0, panelRoot.profileCardRadius(width, height) - lineWidth / 2);
      const pulse = 0.5 + Math.sin(p * 2.4) * 0.5;
      const pathWidth = Math.max(1, (width - lineWidth) * 2 + (height - lineWidth) * 2);
      const movingDash = animation === "chase";
      const comet = animation === "comet";
      const neon = animation === "neon";
      const corners = animation === "corners";
      const orbitDots = animation === "orbitDots";
      const scan = animation === "scan";
      const aurora = animation === "profileAurora";
      const halo = animation === "profileHalo";
      const heartbeat = animation === "profileHeartbeat";
      const spotlight = animation === "profileSpotlight";

      if (neon || heartbeat) {
        ctx.shadowColor = rgba(colors[0], heartbeat ? 0.52 + pulse * 0.32 : 0.45 + pulse * 0.28);
        ctx.shadowBlur = Math.max(7, lineWidth * (heartbeat ? 4.4 + pulse * 2.4 : 2.6 + pulse * 2.2));
      }

      if ((scan || spotlight) && colors.length > 1) {
        const sweep = ((p * 0.22) % 1 + 1) % 1;
        const gradient = ctx.createLinearGradient(width * (sweep - 0.45), 0, width * (sweep + 0.45), height);
        gradient.addColorStop(0, rgba(colors[0], spotlight ? 0.04 : 0.08));
        gradient.addColorStop(0.46, rgba(colors[1 % colors.length], spotlight ? 0.82 : alpha));
        gradient.addColorStop(0.54, rgba(colors[2 % colors.length], spotlight ? 0.96 : alpha));
        gradient.addColorStop(1, rgba(colors[0], spotlight ? 0.04 : 0.08));
        ctx.strokeStyle = gradient;
      } else if (aurora && colors.length > 1) {
        const gradient = ctx.createLinearGradient(0, height * (0.18 + pulse * 0.14), width, height * (0.82 - pulse * 0.14));
        for (let i = 0; i < colors.length; i++)
          gradient.addColorStop(i / Math.max(1, colors.length - 1), rgba(colors[(i + Math.floor(Math.abs(p))) % colors.length], 0.48 + pulse * 0.28));
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
        ctx.strokeStyle = rgba(panelRoot.profileBorderColor(), alpha);
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

      if (halo) {
        const haloGradient = ctx.createRadialGradient(width / 2, height / 2, Math.min(width, height) * 0.18, width / 2, height / 2, Math.max(width, height) * 0.58);
        haloGradient.addColorStop(0, rgba(colors[0], 0));
        haloGradient.addColorStop(0.72, rgba(colors[1 % colors.length], 0.06 + pulse * 0.08));
        haloGradient.addColorStop(1, rgba(colors[2 % colors.length], 0.18 + pulse * 0.12));
        ctx.fillStyle = haloGradient;
        roundedRect(ctx, inset + lineWidth, inset + lineWidth, width - lineWidth * 3, height - lineWidth * 3, Math.max(0, radius - lineWidth));
        ctx.fill();
      }

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
        const boost = animation === "reactiveSpark" ? panelRoot.clamp(0.45 + energy * 0.9, 0.45, 1.15) : 0.85;
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

    SequentialAnimation on scale {
      running: !panelRoot.dashboardPerformanceMode && (panelRoot.profileCoverBorderAnimation === "pulse" || panelRoot.profileCoverBorderAnimation === "reactivePulse" || panelRoot.profileCoverBorderAnimation === "profileHeartbeat")
      loops: Animation.Infinite
      NumberAnimation {
        to: panelRoot.profileCoverBorderAnimation === "profileHeartbeat" ? 1.018 : 1.012
        duration: panelRoot.profileCoverBorderAnimation === "profileHeartbeat" ? 340 : 760
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        to: 1.0
        duration: panelRoot.profileCoverBorderAnimation === "profileHeartbeat" ? 620 : 820
        easing.type: Easing.InOutSine
      }
    }
  }

  Item {
    id: profileContent

    anchors.fill: parent
    anchors.margins: Style.marginL

    readonly property bool showDanceGif: panelRoot.showProfileDanceGif && panelRoot.resolvedProfileDanceGifPath !== ""
    readonly property real avatarSize: Math.round((showDanceGif ? 70 : 78) * panelRoot.panelUnit)

    RowLayout {
      anchors.fill: parent
      spacing: Style.marginM

      Item {
        id: avatarStage

        Layout.preferredWidth: profileContent.avatarSize
        Layout.preferredHeight: profileContent.avatarSize

        readonly property bool circleAvatar: panelRoot.avatarShape !== "rounded"
        readonly property real avatarRadius: circleAvatar ? width / 2 : Math.round(Style.radiusL * panelRoot.panelUnit)
        readonly property bool effectsAllowed: panelRoot.musicActive && !panelRoot.dashboardPerformanceMode
        readonly property bool ringEffect: effectsAllowed && (panelRoot.avatarMusicEffect === "ring" || panelRoot.avatarMusicEffect === "both" || panelRoot.avatarMusicEffect === "studio")
        readonly property bool morphEffect: effectsAllowed && (panelRoot.avatarMusicEffect === "morph" || panelRoot.avatarMusicEffect === "both" || panelRoot.avatarMusicEffect === "studio")
        readonly property bool glowEffect: effectsAllowed && (panelRoot.avatarMusicEffect === "glow" || panelRoot.avatarMusicEffect === "studio")
        readonly property bool orbitEffect: effectsAllowed && (panelRoot.avatarMusicEffect === "orbit" || panelRoot.avatarMusicEffect === "studio")

        Rectangle {
          anchors.centerIn: parent
          width: parent.width + Math.round(20 * panelRoot.panelUnit)
          height: parent.height + Math.round(20 * panelRoot.panelUnit)
          radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
          color: Color.mPrimary
          opacity: avatarStage.glowEffect ? 0.12 : 0

          SequentialAnimation on scale {
            running: avatarStage.glowEffect
            loops: Animation.Infinite
            NumberAnimation {
              to: 1.08
              duration: 900
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 0.96
              duration: 820
              easing.type: Easing.InOutSine
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width + Math.round(6 * panelRoot.panelUnit)
          height: parent.height + Math.round(6 * panelRoot.panelUnit)
          radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
          color: "transparent"
          border.width: Math.round(2 * panelRoot.panelUnit)
          border.color: Color.mPrimary
          opacity: avatarStage.ringEffect ? 0.55 : 0

          SequentialAnimation on scale {
            running: avatarStage.ringEffect
            loops: Animation.Infinite
            NumberAnimation {
              to: 1.08
              duration: 420
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              to: 1.0
              duration: 520
              easing.type: Easing.InOutSine
            }
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width + Math.round(12 * panelRoot.panelUnit)
          height: parent.height + Math.round(12 * panelRoot.panelUnit)
          radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
          color: "transparent"
          border.width: Math.round(1 * panelRoot.panelUnit)
          border.color: Color.mSecondary
          opacity: avatarStage.ringEffect ? 0.22 : 0

          SequentialAnimation on scale {
            running: avatarStage.ringEffect
            loops: Animation.Infinite
            NumberAnimation {
              to: 1.12
              duration: 640
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              to: 0.98
              duration: 500
              easing.type: Easing.InOutSine
            }
          }
        }

        Item {
          anchors.centerIn: parent
          width: parent.width + Math.round(18 * panelRoot.panelUnit)
          height: width
          visible: avatarStage.orbitEffect
          opacity: avatarStage.orbitEffect ? 1 : 0

          RotationAnimator on rotation {
            running: avatarStage.orbitEffect
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 4400
          }

          Rectangle {
            width: Math.round(7 * panelRoot.panelUnit)
            height: width
            radius: width / 2
            x: (parent.width - width) / 2
            y: -height / 2
            color: Color.mPrimary
          }

          Rectangle {
            width: Math.round(5 * panelRoot.panelUnit)
            height: width
            radius: width / 2
            x: (parent.width - width) / 2
            y: parent.height - height / 2
            color: Color.mSecondary
          }
        }

        Item {
          id: avatarWarp
          anchors.fill: parent

          transform: Scale {
            id: avatarWarpScale
            origin.x: avatarWarp.width / 2
            origin.y: avatarWarp.height / 2
            xScale: 1
            yScale: 1
          }

          SequentialAnimation {
            running: avatarStage.morphEffect
            loops: Animation.Infinite
            ParallelAnimation {
              NumberAnimation {
                target: avatarWarpScale
                property: "xScale"
                to: 1.05
                duration: 260
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                target: avatarWarpScale
                property: "yScale"
                to: 0.96
                duration: 260
                easing.type: Easing.InOutSine
              }
            }
            ParallelAnimation {
              NumberAnimation {
                target: avatarWarpScale
                property: "xScale"
                to: 0.98
                duration: 300
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                target: avatarWarpScale
                property: "yScale"
                to: 1.04
                duration: 300
                easing.type: Easing.InOutSine
              }
            }
            ParallelAnimation {
              NumberAnimation {
                target: avatarWarpScale
                property: "xScale"
                to: 1.0
                duration: 260
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                target: avatarWarpScale
                property: "yScale"
                to: 1.0
                duration: 260
                easing.type: Easing.InOutSine
              }
            }
          }

          NImageRounded {
            anchors.fill: parent
            radius: avatarStage.avatarRadius
            imagePath: Settings.preprocessPath(panelRoot.avatarPath)
            fallbackIcon: "user"
            fallbackIconSize: Style.fontSizeXXXL
            borderColor: panelRoot.musicActive && avatarStage.ringEffect ? Color.mSecondary : Color.mPrimary
            borderWidth: Style.borderM
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: TooltipService.show(parent, panelRoot.tr("profileTooltip"))
          onExited: TooltipService.hide()
          onClicked: avatarPicker.openFilePicker()
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginXS

        NText {
          Layout.fillWidth: true
          text: HostService.displayName
          pointSize: Style.fontSizeXXL
          font.weight: Style.fontWeightSemiBold
          color: panelRoot.profileTextColor(true)
          elide: Text.ElideRight
        }

        InfoLine {
          iconName: "device-desktop"
          labelText: HostService.osPretty || "Linux"
          coverMode: panelRoot.profileWallpaperPath !== ""
        }

        InfoLine {
          iconName: "layout-dashboard"
          labelText: panelRoot.compositorName()
          coverMode: panelRoot.profileWallpaperPath !== ""
        }

        InfoLine {
          iconName: "clock"
          labelText: Qt.formatTime(Time.now, "HH:mm")
          coverMode: panelRoot.profileWallpaperPath !== ""
        }
      }

      ReactiveRoundedImage {
        visible: profileContent.showDanceGif
        Layout.preferredWidth: Math.round(54 * panelRoot.panelUnit)
        Layout.preferredHeight: Math.round(82 * panelRoot.panelUnit)
        radius: Style.radiusS
        framed: false
        imagePath: panelRoot.resolvedProfileDanceGifPath
        animatedPlaying: panelRoot.musicActive
        fallbackIcon: ""
        opacity: panelRoot.musicActive ? 1 : 0.32
      }
    }
  }
}
