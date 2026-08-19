import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property date sampleDate: new Date() // Dec 25, 2023, 2:30:45.123 PM

  signal tokenClicked(string token)

  Layout.margins: Style.borderS
  color: Color.mSurfaceContainerLow
  border.color: Color.mOutline
  border.width: Style.borderS
  radius: Style.radiusControl

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentHeight: tokensColumn.implicitHeight
      clip: true

      Column {
        id: tokensColumn
        width: parent.width

        Repeater {
          model: [
            // Common format combinations
            {
              "category": "Common",
              "token": "h:mm AP",
              "description": I18n.tr("widgets.datetime-tokens.common-12hour-time-minutes"),
              "example": "2:30 PM"
            },
            {
              "category": "Common",
              "token": "HH:mm",
              "description": I18n.tr("widgets.datetime-tokens.common-24hour-time-minutes"),
              "example": "14:30"
            },
            {
              "category": "Common",
              "token": "HH:mm:ss",
              "description": I18n.tr("widgets.datetime-tokens.common-24hour-time-seconds"),
              "example": "14:30:45"
            },
            {
              "category": "Common",
              "token": "ddd MMM d",
              "description": I18n.tr("widgets.datetime-tokens.common-weekday-month-day"),
              "example": "Mon Dec 25"
            },
            {
              "category": "Common",
              "token": "yyyy-MM-dd",
              "description": I18n.tr("widgets.datetime-tokens.common-iso-date"),
              "example": "2023-12-25"
            },
            {
              "category": "Common",
              "token": "MM/dd/yyyy",
              "description": I18n.tr("widgets.datetime-tokens.common-us-date"),
              "example": "12/25/2023"
            },
            {
              "category": "Common",
              "token": "dd.MM.yyyy",
              "description": I18n.tr("widgets.datetime-tokens.common-european-date"),
              "example": "25.12.2023"
            },
            {
              "category": "Common",
              "token": "ddd, MMM dd",
              "description": I18n.tr("widgets.datetime-tokens.common-weekday-date"),
              "example": "Fri, Dec 12"
            } // Hour tokens
            ,
            {
              "category": "Hour",
              "token": "H",
              "description": I18n.tr("widgets.datetime-tokens.hour-no-leading-zero"),
              "example": "14"
            },
            {
              "category": "Hour",
              "token": "HH",
              "description": I18n.tr("widgets.datetime-tokens.hour-leading-zero"),
              "example": "14"
            } // Minute tokens
            ,
            {
              "category": "Minute",
              "token": "m",
              "description": I18n.tr("widgets.datetime-tokens.minute-no-leading-zero"),
              "example": "30"
            },
            {
              "category": "Minute",
              "token": "mm",
              "description": I18n.tr("widgets.datetime-tokens.minute-leading-zero"),
              "example": "30"
            } // Second tokens
            ,
            {
              "category": "Second",
              "token": "s",
              "description": I18n.tr("widgets.datetime-tokens.second-no-leading-zero"),
              "example": "45"
            },
            {
              "category": "Second",
              "token": "ss",
              "description": I18n.tr("widgets.datetime-tokens.second-leading-zero"),
              "example": "45"
            } // AM/PM tokens
            ,
            {
              "category": "AM/PM",
              "token": "AP",
              "description": I18n.tr("widgets.datetime-tokens.ampm-uppercase"),
              "example": "PM"
            },
            {
              "category": "AM/PM",
              "token": "ap",
              "description": I18n.tr("widgets.datetime-tokens.ampm-lowercase"),
              "example": "pm"
            } // Timezone tokens
            ,
            {
              "category": "Timezone",
              "token": "t",
              "description": I18n.tr("widgets.datetime-tokens.timezone-abbreviation"),
              "example": "UTC"
            } // Year tokens
            ,
            {
              "category": "Year",
              "token": "yy",
              "description": I18n.tr("widgets.datetime-tokens.year-two-digit"),
              "example": "23"
            },
            {
              "category": "Year",
              "token": "yyyy",
              "description": I18n.tr("widgets.datetime-tokens.year-four-digit"),
              "example": "2023"
            } // Month tokens
            ,
            {
              "category": "Month",
              "token": "M",
              "description": I18n.tr("widgets.datetime-tokens.month-number-no-zero"),
              "example": "12"
            },
            {
              "category": "Month",
              "token": "MM",
              "description": I18n.tr("widgets.datetime-tokens.month-number-leading-zero"),
              "example": "12"
            },
            {
              "category": "Month",
              "token": "MMM",
              "description": I18n.tr("widgets.datetime-tokens.month-abbreviated"),
              "example": "Dec"
            },
            {
              "category": "Month",
              "token": "MMMM",
              "description": I18n.tr("widgets.datetime-tokens.month-full"),
              "example": "December"
            } // Day tokens
            ,
            {
              "category": "Day",
              "token": "d",
              "description": I18n.tr("widgets.datetime-tokens.day-no-leading-zero"),
              "example": "25"
            },
            {
              "category": "Day",
              "token": "dd",
              "description": I18n.tr("widgets.datetime-tokens.day-leading-zero"),
              "example": "25"
            },
            {
              "category": "Day",
              "token": "ddd",
              "description": I18n.tr("widgets.datetime-tokens.day-abbreviated"),
              "example": "Mon"
            },
            {
              "category": "Day",
              "token": "dddd",
              "description": I18n.tr("widgets.datetime-tokens.day-full"),
              "example": "Monday"
            }
          ]

          delegate: Rectangle {
            id: tokenDelegate

            width: tokensColumn.width
            height: layout.implicitHeight + Style.marginS
            radius: tokenMorph.radius
            scale: tokenMorph.scale
            color: index % 2 === 0 ? Color.mSurfaceContainer : Color.mSurfaceContainerLow
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.token
            Accessible.description: modelData.description

            NShapeMorph {
              id: tokenMorph

              hovered: tokenMouseArea.containsMouse
              pressed: tokenMouseArea.pressed
              focused: tokenDelegate.activeFocus
              restingRadius: Style.radiusControl
              hoverRadius: Style.radiusControlChecked
              pressedRadius: Style.radiusControlPressed
            }

            NStateLayer {
              id: tokenStateLayer

              anchors.fill: parent
              radius: parent.radius
              hovered: tokenMouseArea.containsMouse
              pressed: tokenMouseArea.pressed
              focused: tokenDelegate.activeFocus
              stateColor: Color.mPrimary
            }

            MouseArea {
              id: tokenMouseArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPressed: mouse => {
                           tokenDelegate.forceActiveFocus();
                           tokenStateLayer.rippleAt(mouse.x, mouse.y);
                         }
              onClicked: root.tokenClicked(modelData.token)
            }

            RowLayout {
              id: layout

              anchors.fill: parent
              anchors.margins: Style.marginXS
              spacing: Style.marginM

              Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 70
                height: 22
                color: getCategoryColor(modelData.category)[0]
                radius: Style.radiusControl

                NText {
                  anchors.centerIn: parent
                  text: modelData.category
                  color: getCategoryColor(modelData.category)[1]
                  pointSize: Style.fontSizeXS
                }
              }

              Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 100
                height: 22
                color: Color.mSecondaryContainer
                radius: Style.radiusControl

                NText {
                  anchors.centerIn: parent
                  text: modelData.token
                  color: Color.mOnSecondaryContainer
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                }
              }

              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: modelData.description
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
              }

              Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 90
                height: 22
                color: Color.mSurfaceContainerHighest
                radius: Style.radiusControl
                border.color: Color.mOutline
                border.width: Style.borderS

                NText {
                  anchors.centerIn: parent
                  text: I18n.locale.toString(root.sampleDate, modelData.token)
                  color: Color.mOnSurface
                  pointSize: Style.fontSizeS
                }
              }
            }

            NFocusRing {
              focusVisible: tokenDelegate.activeFocus
              targetRadius: tokenDelegate.radius
            }

            Keys.onReturnPressed: event => {
                                    root.tokenClicked(modelData.token);
                                    event.accepted = true;
                                  }
            Keys.onSpacePressed: event => {
                                   root.tokenClicked(modelData.token);
                                   event.accepted = true;
                                 }
          }
        }
      }
    }
  }

  function getCategoryColor(category) {
    switch (category) {
    case "Year":
      return [Color.mPrimary, Color.mOnPrimary];
    case "Month":
      return [Color.mSecondary, Color.mOnSecondary];
    case "Day":
      return [Color.mTertiary, Color.mOnTertiary];
    case "Hour":
      return [Color.mPrimary, Color.mOnPrimary];
    case "Minute":
      return [Color.mSecondary, Color.mOnSecondary];
    case "Second":
      return [Color.mTertiary, Color.mOnTertiary];
    case "AM/PM":
      return [Color.mError, Color.mOnError];
    case "Timezone":
      return [Color.mOnSurface, Color.mSurface];
    case "Common":
      return [Color.mError, Color.mOnError];
    default:
      return [Color.mOnSurfaceVariant, Color.mSurfaceVariant];
    }
  }
}
