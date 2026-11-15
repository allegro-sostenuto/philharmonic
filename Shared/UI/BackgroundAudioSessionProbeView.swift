#if DEBUG
import SwiftUI
import AVFoundation
import UIKit

/// Explicit CI launch only. Unlike layout fixtures, this exercises real Apple
/// session APIs and silent standby across an actual Home/background transition.
/// It performs no station networking or system-volume writes.
@MainActor struct BackgroundAudioSessionProbeView: View {
    @State private var rows: [String] = []
    @State private var phase = "idle"
    @State private var standby = SilentStandby()
    @State private var probeTask: Task<Void, Never>?
    @State private var backgroundedAt: TimeInterval?
    private let audio = AVAudioSession.sharedInstance()

    var body: some View {
        ScrollView {
            VStack {
                Button("Prepare native probe", action: prepare).accessibilityIdentifier("audio-probe-prepare")
                Text(phase).accessibilityIdentifier("audio-probe-phase")
                Text(rows.joined(separator: "\n")).font(.caption).accessibilityIdentifier("audio-probe-report")
            }.padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            guard phase == "prepared" else { return }
            backgroundedAt = ProcessInfo.processInfo.systemUptime
            phase = "waiting"
            probeTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 30_000_000_000) }
                catch { return }
                guard phase == "waiting" else { return }
                runBackgroundProbe()
            }
        }
        .onDisappear { probeTask?.cancel(); phase = "cancelled"; cleanup() }
    }
    private func runBackgroundProbe() {
        let speakerOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .mixWithOthers]
        configure("background_play_and_record", category: .playAndRecord, options: speakerOptions)
        configure("background_playback_restore", category: .playback, options: [.mixWithOthers])
        let handoffTask = UIApplication.shared.beginBackgroundTask(withName: "Probe scheduled speaker audio")
        defer {
            if handoffTask != .invalid { UIApplication.shared.endBackgroundTask(handoffTask) }
        }
        standby.stop()
        configure("background_play_and_record_standby_stopped", category: .playAndRecord, options: speakerOptions,
                  deactivateFirst: true)
        cleanup(); phase = "complete"
    }
    private func prepare() {
        configure("foreground_prepare", category: .playback, options: [.mixWithOthers], startStandby: true)
        phase = standby.running ? "prepared" : "failed"
    }
    private func configure(_ name: String, category: AVAudioSession.Category,
                           options: AVAudioSession.CategoryOptions, startStandby: Bool = false, deactivateFirst: Bool = false) {
        var entry: [String: Any] = ["name": name, "ios": UIDevice.current.systemVersion,
                                  "app_state": UIApplication.shared.applicationState == .background ? "background" : "foreground",
                                  "previous_category": audio.category.rawValue, "previous_options": audio.categoryOptions.rawValue,
                                  "previous_outputs": audio.currentRoute.outputs.map { $0.portType.rawValue },
                                  "standby_before_attempt": standby.running]
        var step = "set_category"
        do {
            if deactivateFirst {
                step = "deactivate"
                try audio.setActive(false)
                entry["session_deactivated"] = true
            }
            step = "set_category"
            try audio.setCategory(category, mode: .default, policy: .default, options: options)
            step = "set_active"
            try audio.setActive(true)
            if startStandby { step = "start_standby"; try standby.start() }
            entry["result"] = "success"
        } catch {
            let error = error as NSError
            entry["result"] = "failure"; entry["failed_step"] = step
            entry["error_code"] = error.code; entry["error_domain"] = error.domain
        }
        entry["category"] = audio.category.rawValue
        entry["options"] = audio.categoryOptions.rawValue
        entry["outputs"] = audio.currentRoute.outputs.map { $0.portType.rawValue }
        entry["volume"] = audio.outputVolume
        entry["standby_running"] = standby.running
        if let backgroundedAt { entry["background_elapsed_seconds"] = ProcessInfo.processInfo.systemUptime - backgroundedAt }
        let line = String(data: try! JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]), encoding: .utf8)!
        rows.append(line); print("NATIVE_SPEAKER_PROBE " + line)
    }
    private func cleanup() {
        standby.stop()
        try? audio.setCategory(.playback, mode: .default, policy: .default, options: [.mixWithOthers])
        try? audio.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
