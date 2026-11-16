import Foundation
import XCTest
#if canImport(PhilharmonicCore)
@testable import PhilharmonicCore
#else
@testable import Philharmonic_SE
#endif

final class BroadcastMetadataTests: XCTestCase {
    func testP2FeedHasExplicitUTCWorkBoundsAndNoInventedArtwork() throws {
        let items = try BroadcastMetadataParser.srP2(fixture("sr-p2-now", extension: "json"))
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { $0.end != nil && $0.timingReliable && $0.artworkURL == nil })
        XCTAssertTrue(items.allSatisfy { !$0.work.isEmpty && !$0.composer.isEmpty })
        XCTAssertEqual(BroadcastMetadataParser.srDate("/Date(1793618054000)/"), Date(timeIntervalSince1970: 1793618054))
        XCTAssertNil(BroadcastMetadataParser.srDate("missing"))
    }

    func testP2RejectsAnotherChannelAndMissingTimestamps() throws {
        let data = Data(#"{"playlist":{"channel":{"id":163},"song":{"title":"Other channel","starttimeutc":"/Date(1000)/"}}}"#.utf8)
        XCTAssertTrue(try BroadcastMetadataParser.srP2(data).isEmpty)
        let missing = Data(#"{"playlist":{"channel":{"id":2562},"song":{"title":"Untimed work"}}}"#.utf8)
        XCTAssertTrue(try BroadcastMetadataParser.srP2(missing).isEmpty)
    }

    func testHRTFiltersStationIDsButTheyStillClosePreviousWork() throws {
        let items = try BroadcastMetadataParser.hrt(fixture("hr-klasik-now", extension: "xml"))
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.work.uppercased() != "HRVATSKI RADIO" && $0.performers.uppercased() != "HR KLASIK" })
        XCTAssertTrue(items.allSatisfy { !$0.timingReliable && $0.artworkURL == nil })
        XCTAssertEqual(items.last?.composer, "PETAR ILJIČ ČAJKOVSKI")
        XCTAssertNil(items.last?.end, "No broadcast end is fabricated for the last item")
        let earlier = try XCTUnwrap(items.first(where: { $0.start.timeIntervalSince1970 == 1793617292.265 }))
        XCTAssertEqual(try XCTUnwrap(earlier.end).timeIntervalSince1970, 1793617630.087, accuracy: 0.001)
    }

    func testMalformedFeedsFailWithoutProducingPlaceholderMusic() {
        XCTAssertThrowsError(try BroadcastMetadataParser.hrt(Data("<broken".utf8)))
        XCTAssertThrowsError(try BroadcastMetadataParser.srP2(Data("{}".utf8)))
    }

    func testSwissClassicStreamTitleSeparatesComposerAndWork() throws {
        let at = Date(timeIntervalSince1970: 100)
        let item = try XCTUnwrap(BroadcastMetadataParser.streamTitle(
            "Carl Reinecke - Allegro molto moderato aus dem Flötenkonzert D-Dur op. 283", capability: .swissClassic, receivedAt: at))
        XCTAssertEqual(item.composer, "Carl Reinecke")
        XCTAssertEqual(item.work, "Allegro molto moderato aus dem Flötenkonzert D-Dur op. 283")
        XCTAssertEqual(item.start, at)
        XCTAssertNil(item.end)
        XCTAssertFalse(item.timingReliable)
        let movement = BroadcastMetadataParser.streamTitle("Composer - Work - Movement", capability: .swissClassic, receivedAt: at)
        XCTAssertEqual(movement?.work, "Work - Movement")
    }

    func testWFMTStreamTitleUsesComposerAndWorkFields() throws {
        let item = try XCTUnwrap(BroadcastMetadataParser.streamTitle(
            "Bon, Anna - Clavier Sonata #4 in C - Barbara Harbach, hc - Anna Bon - MSR Classics",
            capability: .wfmt, receivedAt: Date(timeIntervalSince1970: 100)))
        XCTAssertEqual(item.composer, "Bon, Anna")
        XCTAssertEqual(item.work, "Clavier Sonata #4 in C")
        XCTAssertEqual(item.performers, "Barbara Harbach, hc")
        XCTAssertNil(item.artworkURL)
    }

    func testMissingFieldsAndStationAnnouncementsDoNotProduceMusic() {
        let at = Date(timeIntervalSince1970: 100)
        XCTAssertNil(BroadcastMetadataParser.streamTitle(nil, capability: .swissClassic, receivedAt: at))
        XCTAssertNil(BroadcastMetadataParser.streamTitle("Composer - ", capability: .swissClassic, receivedAt: at))
        XCTAssertNil(BroadcastMetadataParser.streamTitle("Radio Swiss Classic - Live", capability: .swissClassic, receivedAt: at))
        XCTAssertNil(BroadcastMetadataParser.streamTitle("WFMT - Midday Music", capability: .wfmt, receivedAt: at))
        XCTAssertNil(BroadcastMetadataParser.streamTitle(" - Work - Performer - Album - Label", capability: .wfmt, receivedAt: at))
    }

    func testSacredTrackCreditsKeepPerformersAndReportedTitleDistinct() throws {
        let at = Date(timeIntervalSince1970: 100)
        let sacred = try XCTUnwrap(BroadcastMetadataParser.streamTitle(
            "Schola Polyphonica - Ego sum pastor bonus", capability: .sacredMusic, receivedAt: at))
        XCTAssertEqual(sacred.work, "Ego sum pastor bonus")
        XCTAssertEqual(sacred.performers, "Schola Polyphonica")
        XCTAssertTrue(sacred.composer.isEmpty)
        let radio6 = try XCTUnwrap(BroadcastMetadataParser.streamTitle(
            "Out in the windy West (C.V. Stanford)  -  Spiritus Chamber Choir directed by Aidan Oliver",
            capability: .reformatorischeRadio6, receivedAt: at))
        XCTAssertEqual(radio6.work, "Out in the windy West (C.V. Stanford)")
        XCTAssertTrue(radio6.composer.isEmpty)
        XCTAssertEqual(radio6.performers, "Spiritus Chamber Choir directed by Aidan Oliver")
        XCTAssertNil(BroadcastMetadataParser.streamTitle("RO-6", capability: .reformatorischeRadio6, receivedAt: at))
        XCTAssertNil(BroadcastMetadataParser.streamTitle("Announcer - Show - Station", capability: .sacredMusic, receivedAt: at))
    }

    func testProgrammeStreamTitlesAreSeparateFromPieces() {
        let wdr = "WDR 3 Mosaik mit Daniel Finkernagel"
        let oudeMuziek = "Zwerven door de Middeleeuwen (za 1 aug 2020 10:00)"
        XCTAssertEqual(BroadcastMetadataParser.streamProgramme(wdr, capability: .wdr3), wdr)
        XCTAssertEqual(BroadcastMetadataParser.streamProgramme(oudeMuziek, capability: .concertzender), oudeMuziek)
        XCTAssertNil(BroadcastMetadataParser.streamProgramme("WDR 3", capability: .wdr3))
        XCTAssertNil(BroadcastMetadataParser.streamProgramme("Concertzender Oude Muziek", capability: .concertzender))
        XCTAssertNil(BroadcastMetadataParser.streamTitle(wdr, capability: .wdr3, receivedAt: Date()))
    }

    func testRadioFranceUsesItsOwnTimedSongAndExplicitComposerFields() throws {
        let response = Data(#"""
        {"stationId":401,"steps":{
          "work":{"stationId":401,"embedType":"song","start":100,"end":208,"title":"Mazurka","composers":"Pauline Viardot","authors":"A pianist"},
          "next":{"stationId":401,"embedType":"song","start":203,"end":300,"title":"Sonate","authors":"A second pianist"},
          "wrong":{"stationId":408,"embedType":"song","start":100,"end":300,"title":"Different channel","composers":"Wrong"},
          "show":{"stationId":401,"embedType":"diffusion","start":301,"end":350,"title":"A programme"},
          "bad":{"stationId":401,"embedType":"song","start":390,"end":380,"title":"Bad time"}
        }}
        """#.utf8)
        let items = try BroadcastMetadataParser.radioFrance(response, stationID: 401)
        XCTAssertThrowsError(try BroadcastMetadataParser.radioFrance(response, stationID: 408))
        XCTAssertEqual(items.count, 2)
        let inside = BroadcastMetadataParser.radioFrancePiece(at: Date(timeIntervalSince1970: 130), in: items)
        XCTAssertEqual(inside?.work, "Mazurka")
        XCTAssertEqual(inside?.composer, "Pauline Viardot")
        let next = BroadcastMetadataParser.radioFrancePiece(at: Date(timeIntervalSince1970: 240), in: items)
        XCTAssertEqual(next?.work, "Sonate")
        XCTAssertEqual(next?.composer, "")
        let unavailableTimes: [TimeInterval] = [104, 205, 208, 299, 325]
        for time in unavailableTimes {
            XCTAssertNil(BroadcastMetadataParser.radioFrancePiece(at: Date(timeIntervalSince1970: time), in: items))
        }
    }

    func testScheduledStationMigratesAndSurvivesRoundTrip() throws {
        let request = ScheduledStartRequest(date: Date(timeIntervalSince1970: 1234), stationID: "hr-klasik")
        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(ScheduledStartRequest.self, from: data).stationID, "hr-klasik")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "stationID")
        XCTAssertEqual(try JSONDecoder().decode(ScheduledStartRequest.self,
            from: JSONSerialization.data(withJSONObject: legacy)).stationID, "kusc")
        legacy["stationID"] = "retired-station"
        XCTAssertEqual(try JSONDecoder().decode(ScheduledStartRequest.self,
            from: JSONSerialization.data(withJSONObject: legacy)).stationID, "kusc")
    }

    private func fixture(_ name: String, extension suffix: String) throws -> Data {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: name, withExtension: suffix, subdirectory: "Fixtures")
        #else
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: suffix)
        #endif
        return try Data(contentsOf: XCTUnwrap(url))
    }
}
