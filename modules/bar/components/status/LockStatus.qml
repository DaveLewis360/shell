import QtQuick
import QtQuick.Layouts
import Caelestia.Config // [fork]
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property color colour
    required property int parentSpacing

    readonly property bool numLockShown: Hypr.numLock && GlobalConfig.fork.bar.showNumLock // [fork]
    property real gap: Hypr.capsLock && numLockShown ? parentSpacing : 0
    property real capsHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0
    property real numHeight: numLockShown ? numlockIcon.implicitHeight : 0

    spacing: Math.round(gap)

    Behavior on gap {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on capsHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on numHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Item {
        implicitWidth: capslockIcon.implicitWidth
        implicitHeight: Math.round(root.capsHeight)

        MaterialIcon {
            id: capslockIcon

            anchors.centerIn: parent

            scale: Hypr.capsLock ? 1 : 0.5
            opacity: Hypr.capsLock ? 1 : 0

            text: "keyboard_capslock_badge"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Item {
        implicitWidth: numlockIcon.implicitWidth
        implicitHeight: Math.round(root.numHeight)

        MaterialIcon {
            id: numlockIcon

            anchors.centerIn: parent

            scale: root.numLockShown ? 1 : 0.5
            opacity: root.numLockShown ? 1 : 0

            text: "looks_one"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }
}
