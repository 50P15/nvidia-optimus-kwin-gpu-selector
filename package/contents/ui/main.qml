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

    // Translations: English by default, Spanish if the system locale is Spanish
    readonly property bool es: Qt.locale().name.startsWith("es")
    readonly property var strings: ({
        "auto": ["Automatic (by connected display)", "Automático según monitor"],
        "nvidia": ["Prefer NVIDIA", "Priorizar NVIDIA"],
        "integrated": ["Prefer %1", "Priorizar %1"],
        "default": ["KDE default", "Predeterminado de KDE"],
        "kwinOn": ["KWin on %1", "KWin en %1"],
        "kwinUsing": ["KWin is using: %1", "KWin está usando: %1"],
        "current": ["Current session: %1", "Sesión actual: %1"],
        "next": ["Mode for next session:", "Modo para la próxima sesión:"],
        "nextTip": ["Next session: %1", "Próxima sesión: %1"],
        "modeTip": ["Mode: %1", "Modo: %1"],
        "logoutApply": ["Log out to apply the change.", "Cierra sesión para aplicar el cambio."],
        "logoutTip": ["Log out to apply", "Cierra sesión para aplicar"],
        "logout": ["Log out…", "Cerrar sesión…"],
        "noWayland": ["This only works in a Plasma Wayland session.", "Solo funciona en una sesión Plasma Wayland."],
        "noHybrid": ["No NVIDIA + Intel/AMD GPU pair found. The selected mode will have no effect.",
                     "No se ha encontrado una pareja NVIDIA + Intel/AMD. El modo elegido no tendrá efecto."],
        "unknown": ["unknown", "desconocida"],
        "other": ["other GPU", "otra GPU"]
    })
    function tr(key, arg) {
        const s = strings[key][es ? 1 : 0]
        return arg === undefined ? s : s.replace("%1", arg)
    }

    readonly property string igpuName: igpuVendor === "amd" ? "AMD" : "Intel"
    readonly property string gpuName: gpu === "unknown" || gpu === "other" ? tr(gpu) : gpu
    function modeName(m) { return m === "integrated" ? tr(m, igpuName) : tr(m) }

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
    toolTipMainText: tr("kwinOn", gpuName)
    toolTipSubText: pending
        ? tr("nextTip", modeName(mode)) + "\n" + tr("logoutTip")
        : tr("modeTip", modeName(mode))
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
            text: root.tr("kwinUsing", root.gpuName)
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.renderer
            opacity: 0.7
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: root.tr("current", root.modeName(root.applied))
            opacity: 0.7
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !root.wayland || !root.hybrid
            type: Kirigami.MessageType.Information
            text: !root.wayland ? root.tr("noWayland") : root.tr("noHybrid")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents.Label { text: root.tr("next") }

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
            text: root.tr("logoutApply")
            actions: [
                Kirigami.Action {
                    text: root.tr("logout")
                    icon.name: "system-log-out"
                    onTriggered: executable.run(root.helper + " logout")
                }
            ]
        }
    }
}
