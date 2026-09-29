import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Horizontal counterpart of modules/bar/components/status/LockStatus.qml
RowLayout {
    id: root

    required property color colour
    required property int parentSpacing

    readonly property bool numLockShown: Hypr.numLock && GlobalConfig.fork.bar.showNumLock
    property real gap: Hypr.capsLock && numLockShown ? parentSpacing : 0
    property real capsWidth: Hypr.capsLock ? capslockIcon.implicitWidth : 0
    property real numWidth: numLockShown ? numlockIcon.implicitWidth : 0

    spacing: Math.round(gap)

    Behavior on gap {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on capsWidth {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on numWidth {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Item {
        implicitWidth: Math.round(root.capsWidth)
        implicitHeight: capslockIcon.implicitHeight

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
        implicitWidth: Math.round(root.numWidth)
        implicitHeight: numlockIcon.implicitHeight

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
