pragma ComponentBehavior: Bound

import qs.components
import qs.services
import Caelestia.Config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Item wrapper

    readonly property real rounding: Tokens.rounding.normal

    readonly property real activeAlpha: wrapper.hasCurrent || wrapper.isDetached ? 1.0 : 0.0

    strokeWidth: -1
    fillColor: Qt.rgba(Colours.tPalette.m3surface.r, Colours.tPalette.m3surface.g, Colours.tPalette.m3surface.b, Colours.tPalette.m3surface.a * activeAlpha)

    readonly property real w: Math.max(root.rounding * 2, wrapper.width)
    readonly property real h: Math.max(root.rounding * 2, wrapper.height)

    PathArc {
        relativeX: root.rounding
        relativeY: -root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    PathLine {
        relativeX: root.w - root.rounding * 2
        relativeY: 0
    }

    PathArc {
        relativeX: root.rounding
        relativeY: root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    PathLine {
        relativeX: 0
        relativeY: root.h - root.rounding * 2
    }

    PathArc {
        relativeX: -root.rounding
        relativeY: root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    PathLine {
        relativeX: -(root.w - root.rounding * 2)
        relativeY: 0
    }

    PathArc {
        relativeX: -root.rounding
        relativeY: -root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    PathLine {
        relativeX: 0
        relativeY: -(root.h - root.rounding * 2)
    }

    Behavior on fillColor {
        CAnim {}
    }
}
