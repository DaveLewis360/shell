import QtQuick

Item {
    property font f: Qt.font({ pointSize: 18 })
    Component.onCompleted: {
        console.log(f.pointSize);
        console.log(f.variableAxes);
        Qt.quit();
    }
}
