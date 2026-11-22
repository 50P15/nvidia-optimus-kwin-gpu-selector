import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string helper: "bash '" + Qt.resolvedUrl("../code/kwin-gpu-selector").toString().replace("file://", "") + "'"

    property string mode: "default"
    property string applied: "default"
    property string gpu: "…"
    property string renderer: ""
    property bool pending: false
    property string autoTarget: "default"
    property string igpuVendor: "intel"
    property bool hybrid: true
    property bool wayland: true
    property string iconNvidia: ""
    property string iconIgpu: ""

    readonly property string igpuName: igpuVendor === "amd" ? "AMD" : "Intel"
    readonly property string gpuName: gpu === "unknown" ? i18n("unknown") : gpu === "other" ? i18n("other GPU") : gpu
    function modeName(m) {
        switch (m) {
        case "auto": return i18n("Automatic (by connected display)")
        case "nvidia": return i18n("Prefer NVIDIA")
        case "integrated": return i18n("Prefer %1", igpuName)
        case "default": return i18n("KDE default")
        default: return m
        }
    }

    readonly property string iconKind: {
        const m = mode === "auto" ? autoTarget : mode
        return m === "nvidia" || m === "integrated" ? m : "hybrid"
    }
    readonly property url nvidiaIcon: iconNvidia || Qt.resolvedUrl("../icons/gpu-nvidia.svg")
    readonly property url igpuIcon: iconIgpu || Qt.resolvedUrl("../icons/gpu-" + igpuVendor + ".svg")

    // Mode icon: NVIDIA, integrated GPU, or half NVIDIA / half integrated
    component GpuIcon: Item {
        id: gi
        property string kind: "hybrid"
        property url nvidiaSource
        property url igpuSource
        // Papirus' NVIDIA logo only fills the middle of its tile; zoom in and crop the rest
        property real nvidiaZoom: 1
        Item {
            visible: gi.kind !== "integrated"
            width: gi.kind === "hybrid" ? Math.floor(parent.width / 2) : parent.width
            height: parent.height
            clip: true
            // Image instead of Kirigami.Icon: Icon snaps to standard sizes and can't be zoomed
            Image {
                width: Math.round(gi.width * gi.nvidiaZoom)
                height: width
                x: Math.round((gi.width - width) / 2)
                y: Math.round((gi.height - height) / 2)
                sourceSize: Qt.size(width, height)
                smooth: true
                source: gi.nvidiaSource
            }
        }
        Kirigami.Icon {
            anchors.fill: parent
            visible: gi.kind === "integrated"
            source: gi.igpuSource
        }
        Item {
            visible: gi.kind === "hybrid"
            x: Math.floor(parent.width / 2)
            width: parent.width - x
            height: parent.height
            clip: true
            Kirigami.Icon { x: -parent.x; width: gi.width; height: gi.height; source: gi.igpuSource }
        }
    }

    Plasmoid.icon: iconKind === "nvidia" ? nvidiaIcon.toString()
        : iconKind === "integrated" ? igpuIcon.toString() : "video-display"
    toolTipMainText: i18n("KWin on %1", gpuName)
    toolTipSubText: pending
        ? i18n("Next session: %1", modeName(mode)) + "\n" + i18n("Log out to apply")
        : i18n("Mode: %1", modeName(mode))
    Plasmoid.status: pending ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            const out = (data["stdout"] || "").trim()
            if (!out.startsWith("{"))
                return
            try {
                const s = JSON.parse(out)
                root.mode = s.mode
                root.applied = s.applied
                root.gpu = s.gpu
                root.renderer = s.renderer
                root.pending = s.pending
                root.autoTarget = s.autoTarget
                root.igpuVendor = s.igpuVendor
                root.hybrid = s.hybrid
                root.wayland = s.wayland
                root.iconNvidia = s.iconNvidia || ""
                root.iconIgpu = s.iconIgpu || ""
            } catch (e) {
                console.warn("kwin-gpu-selector:", data["stderr"], e)
            }
        }
        function run(cmd) { connectSource(cmd) }
    }

    function refresh() { executable.run(helper + " status") }
    function setMode(m) { executable.run(helper + " set " + m) }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onExpandedChanged: if (expanded) refresh()

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                GpuIcon {
                    anchors.fill: parent
                    kind: root.iconKind
                    nvidiaSource: root.nvidiaIcon
                    igpuSource: root.igpuIcon
                    nvidiaZoom: root.iconNvidia ? 1.4 : 1
                }
                Kirigami.Icon {
                    visible: root.pending
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Math.round(parent.width * 0.5)
                    height: width
                    source: "emblem-warning"
                }
            }
            PlasmaComponents.Label {
                text: root.gpuName
                visible: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: implicitHeight
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.Heading {
            level: 3
            text: i18n("KWin is using: %1", root.gpuName)
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.renderer
            opacity: 0.7
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: i18n("Current session: %1", root.modeName(root.applied))
            opacity: 0.7
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !root.wayland || !root.hybrid
            type: Kirigami.MessageType.Information
            text: !root.wayland ? i18n("This only works in a Plasma Wayland session.") : i18n("No NVIDIA + Intel/AMD GPU pair found. The selected mode will have no effect.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents.Label { text: i18n("Mode for next session:") }

        Repeater {
            model: ["auto", "nvidia", "integrated", "default"]
            delegate: PlasmaComponents.RadioButton {
                text: root.modeName(modelData)
                checked: root.mode === modelData
                onToggled: if (checked) root.setMode(modelData)
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.pending
            type: Kirigami.MessageType.Warning
            text: i18n("Log out to apply the change.")
            actions: [
                Kirigami.Action {
                    text: i18n("Log out…")
                    icon.name: "system-log-out"
                    onTriggered: executable.run(root.helper + " logout")
                }
            ]
        }
    }
}
