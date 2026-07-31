pragma ComponentBehavior: Bound

import qs.custom
import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    // [fork] A popout a bar melletti élhez tapad, és a bar HOSSZTENGELYE mentén
    // követi az épp hoverelt elemet. Vertikálisnál ez a bal él + y-tengely,
    // vízszintesnél a felső él + x-tengely.
    //
    // A `content.currentCenter` mindkét esetben "pozíció a bar hossztengelye
    // mentén" — a Bar.qml y-ból, a custom/bar/HBar.qml x-ből állítja be.
    readonly property bool horizontal: ExtrasConfig.horizontalBar

    readonly property alias content: content

    // A becsúszás iránya is tengelyfüggő: az offsetScale azt méri, hogy a
    // popout mennyire van "kint" a bar mögött.
    property real offsetScale: (horizontal ? y > 0 : x > 0) || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    // A clip a rövidebb tengelyen zsugorodik — ez adja a felfedés-effektet.
    implicitWidth: horizontal ? content.implicitWidth : content.implicitWidth * (1 - offsetScale)
    implicitHeight: horizontal ? content.implicitHeight * (1 - offsetScale) : content.implicitHeight

    // Segéd: a hossztengely menti pozíció, a képernyő szélére szorítva.
    function alongAxis(available: real, size: real): real {
        const off = content.currentCenter - borderThickness - size / 2;
        const diff = available - Math.floor(off + size);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (!horizontal)
            return 0; // a bal élhez tapad
        return alongAxis(parent.width, content.nonAnimWidth);
    }

    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (horizontal)
            return 0; // a felső élhez tapad
        return alongAxis(parent.height, content.nonAnimHeight);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        // FONTOS: itt NEM anchor van. A QML-ben az
        // `anchors.verticalCenter: cond ? parent.verticalCenter : undefined`
        // NEM törli az anchort, ezért a wrapper mindkét élre felfeszülne.
        //
        // Anchorra egyébként nincs is szükség: a root implicit mérete a
        // hossztengelyen megegyezik a contentével, így a "középre igazítás"
        // amúgy is 0-t adna. Csak a becsúszás eltolása marad.
        x: root.horizontal ? 0 : (-implicitWidth - 5) * root.offsetScale
        y: root.horizontal ? (-implicitHeight - Tokens.sizes.bar.innerWidth - 10) * root.offsetScale : 0
    }
}
