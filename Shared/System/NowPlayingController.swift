import MediaPlayer
import UIKit

@MainActor final class NowPlayingController {
    private var targets: [(MPRemoteCommand, Any)] = []
    private var previousItem: ProgrammeItem?
    private var previousArtwork: UIImage?
    private var previousPlaying: Bool?
    private var previousStationID: String?
    private var previousCaption: String?
    init(play: @escaping () -> Void, pause: @escaping () -> Void, toggle: @escaping () -> Void,
         next: (() -> Void)? = nil, previous: (() -> Void)? = nil) {
        let c = MPRemoteCommandCenter.shared()
        for command in [c.previousTrackCommand, c.nextTrackCommand, c.skipBackwardCommand,
                        c.skipForwardCommand, c.seekBackwardCommand, c.seekForwardCommand,
                        c.changePlaybackPositionCommand, c.changePlaybackRateCommand,
                        c.ratingCommand, c.likeCommand, c.dislikeCommand, c.bookmarkCommand] {
            command.isEnabled = false
        }
        for (command, action) in [(c.playCommand, play), (c.pauseCommand, pause), (c.togglePlayPauseCommand, toggle)] {
            command.isEnabled = true
            let target = command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
            targets.append((command, target))
        }
        for (command, action) in [(c.nextTrackCommand, next), (c.previousTrackCommand, previous)] {
            guard let action else { continue }
            command.isEnabled = true
            let target = command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
            targets.append((command, target))
        }
    }
    func update(item: ProgrammeItem?, artwork: UIImage?, playing: Bool,
                station: RadioStation = StationCatalog.defaultStation, liveCaption: String? = nil) {
        let caption = item == nil ? liveCaption : nil
        guard item != previousItem || artwork !== previousArtwork || playing != previousPlaying ||
                station.id != previousStationID || caption != previousCaption else { return }
        previousItem = item; previousArtwork = artwork; previousPlaying = playing
        previousStationID = station.id
        previousCaption = caption
        let artists = item.map { [$0.composer, $0.performers].filter { !$0.isEmpty }.joined(separator: " · ") } ?? ""
        let stationDetail = caption == nil ? (station.subtitle ?? "Live radio") : station.name
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item?.title ?? caption ?? station.name,
            MPMediaItemPropertyArtist: artists.isEmpty ? stationDetail : artists,
            MPMediaItemPropertyComposer: item?.composer ?? "",
            MPMediaItemPropertyAlbumTitle: station.name,
            MPNowPlayingInfoPropertyExternalContentIdentifier: station.id,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        // No duration/elapsed fields: live-only playback has no system scrubber.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
