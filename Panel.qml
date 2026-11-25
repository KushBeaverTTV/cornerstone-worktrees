import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Worktrees.js" as Worktrees

// Compact git-branch & worktree dashboard in the bar.
// Left click: open panel. Right click: rescan ~/Projects.
Panel {
  id: root
  moduleName: "cornerstone.worktrees"
  ipcTarget: "cornerstone-worktrees"
  manageIpc: false

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("cornerstone.worktrees") : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.55)
  readonly property color hairline: Qt.darker(foreground, 2.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var palette: ({})
  readonly property color okColor: palette.color2 || Color.accent
  readonly property color warnColor: palette.color3 || "#FFB020"

  FileView {
    id: paletteFile
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: {
      var found = {}
      var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm
      var m
      while ((m = re.exec(String(text()))) !== null) found[m[1]] = m[2]
      root.palette = found
    }
  }
  Connections {
    target: Color
    function onBackgroundChanged() { paletteFile.reload() }
    function onAccentChanged() { paletteFile.reload() }
  }

  property string filterMode: "active"   // "active" | "all"
  property bool watching: false

  readonly property var repos: service ? service.repos : []
  readonly property var counts: service ? service.counts : ({ total: 0, dirty: 0, active: 0 })
  readonly property var shown: Worktrees.filterRepos(repos, filterMode)
  readonly property real nowSec: service ? service.nowSec : Date.now() / 1000
  readonly property bool scanning: service ? service.scanning : false

  readonly property int badgeCount: counts.active > 0 ? counts.active : counts.dirty
  readonly property string barTooltip: "Worktrees · " + counts.total + " repos"
    + (counts.active > 0 ? " · " + counts.active + " active" : "")
    + (counts.dirty > 0 ? " · " + counts.dirty + " dirty" : "")

  onOpenedChanged: {
    if (service) {
      if (opened && !watching) { watching = true; service.watchers++; service.refresh() }
      else if (!opened && watching) { watching = false; service.watchers = Math.max(0, service.watchers - 1) }
    }
  }
  Component.onDestruction: {
    if (watching && service) service.watchers = Math.max(0, service.watchers - 1)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 5
    fixedWidth: vertical ? -1 : (root.badgeCount > 0 ? Math.max(Style.bar.iconSlot, pill.implicitWidth + scaledHorizontalMargin * 2) : Style.bar.iconSlot)
    fixedHeight: vertical ? Math.max(Style.bar.iconSlot, pill.implicitHeight + Style.space(6)) : -1
    tooltipText: root.opened ? "" : root.barTooltip
    onPressed: function(code) {
      if (code === Qt.RightButton && root.service) root.service.refresh()
      else root.toggle()
    }

    Row {
      id: pill
      anchors.centerIn: parent
      scale: button.pressScale
      spacing: Style.space(4)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󰘬"
        color: root.counts.active > 0 ? root.okColor : (root.counts.dirty > 0 ? root.warnColor : root.foreground)
        font.family: root.fontFamily
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
      }
      Text {
        visible: root.badgeCount > 0
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: String(root.badgeCount)
        color: root.counts.active > 0 ? root.okColor : root.warnColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(580))

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") { if (root.service) root.service.refresh() }
        else if (t === "a" || t === "A") root.filterMode = root.filterMode === "all" ? "active" : "all"
      }
      clip: true

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(10)

        // Header + filter pills
        Item {
          width: parent.width
          height: Math.max(hCol.implicitHeight, pills.implicitHeight)

          Column {
            id: hCol
            anchors.left: parent.left
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: "Worktrees & Repos"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.scanning ? "Scanning ~/Projects…"
                    : (root.counts.total + " repos · " + root.counts.dirty + " dirty · " + root.counts.active + " active")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            id: pills
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Repeater {
              model: [{ id: "active", label: "Active" }, { id: "all", label: "All (" + root.counts.total + ")" }]
              Rectangle {
                required property var modelData
                readonly property bool selected: root.filterMode === modelData.id
                height: Style.space(24)
                width: pLbl.implicitWidth + Style.space(14)
                radius: height / 2
                color: selected ? Util.alpha(Color.accent, 0.25) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                Text {
                  id: pLbl
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: selected ? Color.accent : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: selected
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.filterMode = modelData.id
                }
              }
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.hairline }

        Text {
          visible: root.shown.length === 0
          textFormat: Text.PlainText
          text: root.filterMode === "active"
            ? "All repos clean & idle — switch to All to browse ~/Projects"
            : "No git repositories found in ~/Projects"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        ListView {
          visible: root.shown.length > 0
          width: parent.width
          height: Math.min(Style.space(390), root.shown.length * Style.space(46) + Math.max(0, root.shown.length - 1) * Style.space(5))
          clip: true
          spacing: Style.space(5)
          boundsBehavior: Flickable.StopAtBounds
          model: root.shown

          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(46)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                           rowMouse.containsMouse ? 0.13 : 0.05)
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { if (root.service) root.service.openTerminal(modelData.path); root.close() }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.right: rowBtns.left
              anchors.rightMargin: Style.space(6)
              spacing: 2

              Row {
                width: parent.width
                spacing: Style.space(6)
                Text {
                  textFormat: Text.PlainText
                  text: modelData.name
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, parent.width - (liveTag.visible ? liveTag.width + Style.space(6) : 0))
                }
                Rectangle {
                  id: liveTag
                  visible: modelData.active.length > 0
                  height: Style.space(15)
                  width: liveLbl.implicitWidth + Style.space(8)
                  radius: height / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: Util.alpha(root.okColor, 0.24)
                  Text {
                    id: liveLbl
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.active.join(" · ")
                    color: root.okColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(9, Style.font.caption - 2)
                    font.bold: true
                  }
                }
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "󰘬 " + modelData.branch
                      + (modelData.dirty > 0 ? "  ·  " + modelData.dirty + " modified" : "  ·  clean")
                      + (modelData.ahead > 0 ? "  ↑" + modelData.ahead : "")
                      + (modelData.behind > 0 ? "  ↓" + modelData.behind : "")
                      + (modelData.lastCommit > 0 ? "  ·  " + Worktrees.ago(modelData.lastCommit, root.nowSec) : "")
                color: modelData.dirty > 0 ? root.warnColor : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Row {
              id: rowBtns
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Rectangle {
                width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                color: lgA.containsMouse ? Util.alpha(Color.accent, 0.25) : "transparent"
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "󰊢"
                  color: lgA.containsMouse ? Color.accent : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                MouseArea {
                  id: lgA
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { if (root.service) root.service.openLazygit(modelData.path); root.close() }
                }
              }

              Rectangle {
                width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                color: cpA.containsMouse ? Util.alpha(Color.accent, 0.25) : "transparent"
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "󰆏"
                  color: cpA.containsMouse ? Color.accent : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: cpA
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.service) root.service.copyPath(modelData.path)
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Click row = open terminal · 󰊢 lazygit · a toggle Active/All · r refresh"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
