import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Small summary of how many theme color roles would change if the candidate
// palette were applied — e.g. "5 de 16 cores vão mudar". Both palettes are
// dicts keyed by the "m*" role names (see TemplateProcessor.mapToColorKeys()).
Item {
  id: root

  property var currentPalette: null
  property var candidatePalette: null

  readonly property var _diff: {
    if (!currentPalette || !candidatePalette) {
      return {
        "changed": 0,
        "total": 0
      };
    }
    var keys = Object.keys(currentPalette);
    var changed = 0;
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var before = String(currentPalette[key] || "").toLowerCase();
      var after = String(candidatePalette[key] || "").toLowerCase();
      if (before !== after) {
        changed++;
      }
    }
    return {
      "changed": changed,
      "total": keys.length
    };
  }

  visible: currentPalette !== null && candidatePalette !== null && _diff.total > 0
  implicitWidth: contentRow.implicitWidth
  implicitHeight: contentRow.implicitHeight

  // Fills the width given by the parent layout so the label elides instead of
  // overflowing on top of its neighbours in a narrow column.
  RowLayout {
    id: contentRow
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.marginXS

    NIcon {
      icon: "color-swatch"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    NText {
      text: I18n.tr("wallpaper.panel.theme-diff-summary", {
                      "changed": root._diff.changed,
                      "total": root._diff.total
                    })
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
      elide: Text.ElideRight
      Layout.fillWidth: true
    }
  }
}
