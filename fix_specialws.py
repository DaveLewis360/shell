import re

with open("modules/bar/components/workspaces/SpecialWorkspaces.qml", "r") as f:
    text = f.read()

# Make it horizontal
text = text.replace("orientation: Gradient.Vertical", "orientation: Gradient.Horizontal")
text = text.replace("anchors.top: parent.top\n            anchors.left: parent.left\n            anchors.right: parent.right", "anchors.top: parent.top\n            anchors.bottom: parent.bottom\n            anchors.left: parent.left")
text = text.replace("implicitHeight: parent.height / 2", "implicitWidth: parent.width / 2")
text = text.replace("view.contentY > 0", "view.contentX > 0")

text = text.replace("anchors.bottom: parent.bottom\n            anchors.left: parent.left\n            anchors.right: parent.right", "anchors.top: parent.top\n            anchors.bottom: parent.bottom\n            anchors.right: parent.right")
text = text.replace("view.contentY < view.contentHeight - parent.height", "view.contentX < view.contentWidth - parent.width")

text = text.replace("ListView {", "ListView {\n        orientation: ListView.Horizontal", 1)
text = text.replace("preferredHighlightEnd: height", "preferredHighlightEnd: width")
text = text.replace("y: view.currentItem?.y ?? 0", "x: view.currentItem?.x ?? 0")
text = text.replace("Behavior on y {", "Behavior on x {")

text = text.replace("anchors.left: parent.left\n                anchors.right: parent.right", "anchors.top: parent.top\n                anchors.bottom: parent.bottom")
text = text.replace("y: (view.currentItem?.y ?? 0) - view.contentY", "x: (view.currentItem?.x ?? 0) - view.contentX")
text = text.replace("anchors.horizontalCenter: parent.horizontalCenter", "anchors.verticalCenter: parent.verticalCenter")
text = text.replace("y: -indicator.y", "y: 0\n                    x: -indicator.x")
text = text.replace("Behavior on implicitHeight {", "Behavior on implicitWidth {")

text = text.replace("property real startY", "property real startX")
text = text.replace("drag.axis: Drag.YAxis", "drag.axis: Drag.XAxis")
text = text.replace("drag.maximumY: 0", "drag.maximumX: 0")
text = text.replace("drag.minimumY: Math.min(0, view.height - view.contentHeight - Tokens.padding.extraSmall)", "drag.minimumX: Math.min(0, view.width - view.contentWidth - Tokens.padding.extraSmall)")
text = text.replace("startY = event.y", "startX = event.x")
text = text.replace("Math.abs(event.y - startY)", "Math.abs(event.x - startX)")

text = text.replace("component SpecialWsDelegate: ColumnLayout {", "component SpecialWsDelegate: RowLayout {")
text = text.replace("readonly property int size: label.Layout.preferredHeight + (hasWindows ? windows.implicitHeight + Tokens.padding.extraSmall : 0)", "readonly property int size: label.Layout.preferredWidth + (hasWindows ? windows.implicitWidth + Tokens.padding.extraSmall : 0)")
text = text.replace("anchors.left: view.contentItem.left\n        anchors.right: view.contentItem.right", "anchors.top: view.contentItem.top\n        anchors.bottom: view.contentItem.bottom")

text = text.replace("Layout.alignment: Qt.AlignHCenter | Qt.AlignTop", "Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft")
text = text.replace("Layout.preferredHeight: Tokens.sizes.bar.innerWidth", "Layout.preferredWidth: Tokens.sizes.bar.innerHeight")
text = text.replace("verticalAlignment: Qt.AlignVCenter", "horizontalAlignment: Qt.AlignHCenter")

text = text.replace("Layout.alignment: Qt.AlignHCenter\n            Layout.fillHeight: true\n            Layout.preferredHeight: implicitHeight", "Layout.alignment: Qt.AlignVCenter\n            Layout.fillWidth: true\n            Layout.preferredWidth: implicitWidth")
text = text.replace("sourceComponent: Column {", "sourceComponent: Row {")
text = text.replace("Behavior on Layout.preferredHeight {", "Behavior on Layout.preferredWidth {")

with open("modules/bar/components/workspaces/SpecialWorkspaces.qml", "w") as f:
    f.write(text)
