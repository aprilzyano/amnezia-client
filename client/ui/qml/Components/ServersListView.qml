import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainersModelFilters 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

ListViewType {
    id: root

    property int selectedIndex: ServersUiController.getServerIndexById(ServersUiController.defaultServerId)

    anchors.top: serversMenuHeader.bottom
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.topMargin: 16

    model: ServersModel

    Connections {
        target: ServersUiController
        function onDefaultServerIdChanged() {
            root.selectedIndex = ServersUiController.getServerIndexById(ServersUiController.defaultServerId)
        }
    }

    // هنگامی که ping همه سرورها تمام شد، لیست را refresh کن
    Connections {
        target: PingController
        function onPingResultUpdated(serverId, pingMs) {
            root.model = null
            root.model = ServersModel
        }
        function onPingAllFinished(bestServerId) {
            root.model = null
            root.model = ServersModel
        }
    }

    delegate: Item {
        id: menuContentDelegate
        objectName: "menuContentDelegate"

        property variant delegateData: model
        property VerticalRadioButton serverRadioButtonProperty: serverRadioButton

        implicitWidth: root.width
        implicitHeight: serverRadioButtonContent.implicitHeight

        ColumnLayout {
            id: serverRadioButtonContent
            objectName: "serverRadioButtonContent"

            anchors.fill: parent
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            spacing: 0

            RowLayout {
                objectName: "serverRadioButtonRowLayout"

                Layout.fillWidth: true

                VerticalRadioButton {
                    id: serverRadioButton
                    objectName: "serverRadioButton"

                    Layout.fillWidth: true

                    text: name
                    descriptionText: isServerFromGatewayApi && (isSubscriptionExpired || isSubscriptionExpiringSoon)
                        ? (isSubscriptionExpired ? qsTr("Subscription expired. Please renew") : qsTr("Subscription expiring soon"))
                        : serverDescription
                    descriptionColor: isServerFromGatewayApi && (isSubscriptionExpired || isSubscriptionExpiringSoon)
                        ? (isSubscriptionExpired ? AmneziaStyle.color.vibrantRed : AmneziaStyle.color.goldenApricot)
                        : AmneziaStyle.color.mutedGray

                    checked: index === root.selectedIndex
                    checkable: !ConnectionController.isConnected

                    ButtonGroup.group: serversRadioButtonGroup

                    onClicked: {
                        if (ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Unable change server while there is an active connection"))
                            return
                        }

                        root.selectedIndex = index
                        ServersUiController.setDefaultServerAtIndex(index)
                    }

                    Keys.onEnterPressed: serverRadioButton.clicked()
                    Keys.onReturnPressed: serverRadioButton.clicked()
                }

                // ---- نمایش Ping ----
                Item {
                    id: pingBadge
                    implicitWidth: pingLabel.implicitWidth + 16
                    implicitHeight: 28

                    property int pingMs: PingController.getLastPing(serverId)

                    // رنگ بر اساس latency
                    property color badgeColor: {
                        if (pingMs < 0)   return AmneziaStyle.color.mutedGray
                        if (pingMs < 100) return "#3ecf5c"   // سبز — عالی
                        if (pingMs < 300) return "#f5a623"   // زرد — متوسط
                        return "#e74c3c"                      // قرمز — ضعیف
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: parent.badgeColor
                        opacity: 0.18
                    }

                    Text {
                        id: pingLabel
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: pingBadge.badgeColor

                        text: {
                            const ms = pingBadge.pingMs
                            if (ms < 0) return qsTr("--")
                            return ms + " ms"
                        }
                    }

                    // رو‌به‌روز‌آوری خودکار وقتی ping آپدیت می‌شه
                    Connections {
                        target: PingController
                        function onPingResultUpdated(updatedServerId, pingMs) {
                            if (updatedServerId === serverId) {
                                pingBadge.pingMs = pingMs
                            }
                        }
                    }
                }
                // ---- پایان Ping ----

                ImageButtonType {
                    id: serverInfoButton
                    objectName: "serverInfoButton"

                    image: "qrc:/images/controls/settings.svg"
                    imageColor: AmneziaStyle.color.paleGray

                    implicitWidth: 56
                    implicitHeight: 56

                    z: 1

                    onClicked: function() {
                        ServersUiController.setProcessedServerId(serverId)

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

                        drawer.closeTriggered()
                    }
                }
            }

            DividerType {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
            }
        }
    }
}
