import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainersModelFilters 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property var containersDropDownRef: null

    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive) {
                if (drawer.isOpened) {
                    drawer.closeTriggered()
                }
                if (homeSplitTunnelingDrawer.isOpened) {
                    homeSplitTunnelingDrawer.closeTriggered()
                }
            }
        }
    }

    Connections {
        objectName: "pageControllerConnections"

        target: PageController

        function onRestorePageHomeState(isContainerInstalled) {
            drawer.openTriggered()
            if (isContainerInstalled && root.containersDropDownRef) {
                root.containersDropDownRef.rootButtonClickedFunction()
            }
        }
    }

    // وقتی بهترین سرور مشخص شد، اگر auto-connect فعال بود، وصل می‌شیم
    Connections {
        target: PingController

        function onPingAllFinished(bestServerId) {
            if (root.autoBestPending && bestServerId !== "") {
                root.autoBestPending = false
                if (!ConnectionController.isConnected) {
                    ServersUiController.setDefaultServer(bestServerId)
                    connectionUiController.connectToVpn()
                }
            }
            autoBestButton.enabled = true
            autoBestButton.text = qsTr("Auto-connect to Best Server")
        }
    }

    // فلگ برای auto-connect بعد از ping
    property bool autoBestPending: false

    Item {
        objectName: "homeColumnItem"

        anchors.fill: parent
        anchors.bottomMargin: drawer.collapsedHeight

        ColumnLayout {
            objectName: "homeColumnLayout"

            anchors.fill: parent
            anchors.topMargin: 12 + PageController.safeAreaTopMargin
            anchors.bottomMargin: 16

            BasicButtonType {
                id: loggingButton
                objectName: "loggingButton"

                property bool isLoggingEnabled: SettingsController.isLoggingEnabled

                Layout.alignment: Qt.AlignHCenter

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                visible: isLoggingEnabled ? true : false
                text: qsTr("Logging enabled")

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    PageController.goToPage(PageEnum.PageSettingsLogging)
                }
            }

            BasicButtonType {
                id: devGatewayButton
                objectName: "devGatewayButton"

                property bool isDevGatewayEnabled: SettingsController.isDevGatewayEnv

                Layout.alignment: Qt.AlignHCenter

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                visible: SettingsController.isDevModeEnabled && isDevGatewayEnabled
                text: qsTr("Dev gateway enabled")

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    PageController.goToPage(PageEnum.PageDevMenu)
                }
            }

            ConnectButton {
                id: connectButton
                objectName: "connectButton"

                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter
            }

            // ===== دکمه Auto-connect به بهترین سرور =====
            BasicButtonType {
                id: autoBestButton
                objectName: "autoBestButton"

                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
                leftPadding: 20
                rightPadding: 20

                implicitHeight: 40

                defaultColor: AmneziaStyle.color.translucentWhite
                hoveredColor: AmneziaStyle.color.sheerWhite
                pressedColor: AmneziaStyle.color.mutedGray
                disabledColor: AmneziaStyle.color.transparent
                textColor: AmneziaStyle.color.paleGray
                borderWidth: 0

                buttonTextLabel.font.pixelSize: 13
                buttonTextLabel.font.weight: 500

                // نمایش فقط وقتی بیش از یک سرور وجود دارد
                visible: ServersModel.count > 1 && !ConnectionController.isConnected

                text: qsTr("Auto-connect to Best Server")

                leftImageSource: "qrc:/images/controls/globe.svg"
                leftImageColor: AmneziaStyle.color.paleGray

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    autoBestButton.enabled = false
                    autoBestButton.text = qsTr("Checking servers...")
                    root.autoBestPending = true
                    PingController.pingAll()
                }
            }
            // ===== پایان دکمه Auto-connect =====

            BasicButtonType {
                id: splitTunnelingButton
                objectName: "splitTunnelingButton"

                Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                leftPadding: 16
                rightPadding: 16

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                buttonTextLabel.lineHeight: 20
                buttonTextLabel.font.pixelSize: 14
                buttonTextLabel.font.weight: 500

                property bool isSplitTunnelingEnabled: IpSplitTunnelingController.isSplitTunnelingEnabled || AppSplitTunnelingController.isSplitTunnelingEnabled ||
                                                       ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

                text: isSplitTunnelingEnabled ? qsTr("Split tunneling enabled") : qsTr("Split tunneling disabled")

                leftImageSource: isSplitTunnelingEnabled ? "qrc:/images/controls/split-tunneling.svg" : ""
                leftImageColor: ""
                rightImageSource: "qrc:/images/controls/chevron-down.svg"

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    homeSplitTunnelingDrawer.openTriggered()
                }

                HomeSplitTunnelingDrawer {
                    id: homeSplitTunnelingDrawer
                    objectName: "homeSplitTunnelingDrawer"

                    parent: root
                }
            }

            AdLabel {
                id: adLabel

                Layout.fillWidth: true
                Layout.preferredHeight: adLabel.contentHeight
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 22
            }
        }
    }

    DrawerType2 {
        id: drawer
        objectName: "drawerProtocol"

        anchors.fill: parent

        collapsedStateContent: Item {
            objectName: "ProtocolDrawerCollapsedContent"

            implicitHeight: Qt.platform.os !== "ios" ? root.height * 0.9 : screen.height * 0.77
            Component.onCompleted: {
                drawer.expandedHeight = implicitHeight
            }

            ColumnLayout {
                id: collapsed
                objectName: "collapsedColumnLayout"

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Component.onCompleted: {
                    drawer.collapsedHeight = collapsed.implicitHeight
                }

                DividerType {
                    Layout.topMargin: 10
                    Layout.fillWidth: false
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 2
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                }

                RowLayout {
                    objectName: "rowLayout"

                    Layout.topMargin: 14
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                    spacing: 0

                    Connections {
                        objectName: "drawerConnections"

                        target: drawer
                        function onCursorEntered() {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = collapsedButtonChevron.hoveredColor
                                collapsedButtonHeader.opacity = 0.8
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }

                        function onCursorExited() {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = collapsedButtonChevron.defaultColor
                                collapsedButtonHeader.opacity = 1
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }

                        function onPressed(pressed, entered) {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = pressed ? collapsedButtonChevron.pressedColor : entered ? collapsedButtonChevron.hoveredColor : collapsedButtonChevron.defaultColor
                                collapsedButtonHeader.opacity = 0.7
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }
                    }

                    Header1TextType {
                        id: collapsedButtonHeader
                        objectName: "collapsedButtonHeader"

                        Layout.maximumWidth: drawer.width - 48 - 18 - 12

                        maximumLineCount: 2
                        elide: Qt.ElideRight

                        text: ServersUiController.defaultServerName
                        horizontalAlignment: Qt.AlignHCenter

                        Behavior on opacity {
                            PropertyAnimation { duration: 200 }
                        }
                    }

                    ImageButtonType {
                        id: collapsedButtonChevron
                        objectName: "collapsedButtonChevron"

                        Layout.leftMargin: 8

                        visible: drawer.isCollapsedStateActive()

                        hoverEnabled: false
                        image: "qrc:/images/controls/chevron-down.svg"
                        imageColor: AmneziaStyle.color.paleGray

                        icon.width: 18
                        icon.height: 18
                        backgroundRadius: 16
                        horizontalPadding: 4
                        topPadding: 4
                        bottomPadding: 3

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        onClicked: {
                            if (drawer.isCollapsedStateActive()) {
                                drawer.openTriggered()
                            }
                        }
                    }
                }

                RowLayout {
                    objectName: "rowLayoutLabel"
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: drawer.isCollapsedStateActive ? 44 : ServersUiController.isDefaultServerFromApi ? 61 : 16
                    spacing: 0

                    BasicButtonType {
                        enabled: (ServersUiController.defaultServerImagePathCollapsed !== "") && drawer.isCollapsedStateActive
                        hoverEnabled: enabled

                        implicitHeight: 36

                        leftPadding: 16
                        rightPadding: 16

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite
                        disabledColor: AmneziaStyle.color.transparent
                        textColor: AmneziaStyle.color.mutedGray

                        buttonTextLabel.lineHeight: 16
                        buttonTextLabel.font.pixelSize: 13
                        buttonTextLabel.font.weight: 400

                        text: drawer.isCollapsedStateActive ? ServersUiController.defaultServerDescriptionCollapsed : ServersUiController.defaultServerDescriptionExpanded
                        leftImageSource: ServersUiController.defaultServerImagePathCollapsed
                        leftImageColor: ""
                        changeLeftImageSize: false

                        rightImageSource: hoverEnabled ? "qrc:/images/controls/chevron-down.svg" : ""

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        onClicked: {
                            ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)

                            if (ServersUiController.isServerFromApi(ServersUiController.processedServerId)) {
                                if (ServersUiController.isServerCountrySelectionAvailable(ServersUiController.processedServerId)) {
                                    PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
                                } else {
                                    PageController.showBusyIndicator(true)
                                    let result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                                    PageController.showBusyIndicator(false)
                                    if (!result) {
                                        return
                                    }

                                    PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
                                }
                            } else {
                                PageController.goToPage(PageEnum.PageSettingsServerInfo)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: serversMenuHeader
                objectName: "serversMenuHeader"

                anchors.top: collapsed.bottom
                anchors.right: parent.right
                anchors.left: parent.left

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: 8

                    visible: !ServersUiController.isDefaultServerFromApi

                    DropDownType {
                        id: containersDropDown
                        objectName: "containersDropDown"

                        Component.onCompleted: root.containersDropDownRef = containersDropDown

                        Layout.fillWidth: true
                        Layout.leftMargin: 16

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite

                        textColor: AmneziaStyle.color.paleGray
                        borderWidth: 0

                        headerText: qsTr("Protocol")

                        listView: HomeContainersListView {
                            rootWidth: containersDropDown.popupContent.width
                            selectedText: containersDropDown.text
                        }

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()
                    }

                    // ===== دکمه Refresh Ping در drawer =====
                    ImageButtonType {
                        id: refreshPingButton
                        objectName: "refreshPingButton"

                        Layout.rightMargin: 16
                        implicitWidth: 40
                        implicitHeight: 40

                        image: "qrc:/images/controls/refresh.svg"
                        imageColor: AmneziaStyle.color.paleGray

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Refresh ping for all servers")
                        ToolTip.delay: 500

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        // انیمیشن چرخش هنگام در حال ping
                        RotationAnimation on rotation {
                            id: refreshAnimation
                            running: false
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 1000
                        }

                        onClicked: {
                            refreshAnimation.running = true
                            PingController.pingAll()
                        }

                        Connections {
                            target: PingController
                            function onPingAllFinished(bestServerId) {
                                refreshAnimation.running = false
                                refreshPingButton.rotation = 0
                            }
                        }
                    }
                    // ===== پایان دکمه Refresh Ping =====
                }

                ButtonGroup {
                    id: serversRadioButtonGroup
                }

                ServersListView {
                    id: serversListView
                    objectName: "serversListView"
                }
            }
        }
    }
}
