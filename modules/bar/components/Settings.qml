import qs.components
import qs.modules.controlcenter
import qs.services
import Caelestia.Config
import QtQuick

Item {
    id: root

    implicitWidth: icon.implicitHeight + Tokens.padding.small * 2
    implicitHeight: icon.implicitHeight

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small * 2

        radius: Tokens.rounding.full

        function onClicked(): void {
            WindowFactory.create(null, {
                active: "network"
            });
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        text: "settings"
        color: Colours.palette.m3onSurface
        font.bold: true
        font.pointSize: Tokens.font.size.normal
    }
}
