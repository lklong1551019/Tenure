import Foundation
import Testing

@testable import Domain

@Suite("UpdateCheck")
struct UpdateCheckTests {
    @Test func comparesVersionsAsNumbers() {
        #expect(UpdateCheck.isNewer("26.11.01", than: "26.10.12"))
        #expect(UpdateCheck.isNewer("26.10.10", than: "26.10.9"))
        #expect(!UpdateCheck.isNewer("26.10.01", than: "26.10.01"))
        #expect(!UpdateCheck.isNewer("26.10", than: "26.10.00"))
        #expect(UpdateCheck.isNewer("27.01.01", than: "26.12.03"))
    }

    @Test func keepsOnlyNewerReleasesNewestFirst() {
        let releases = [Release(version: "26.10.01"), Release(version: "26.12.01"), Release(version: "26.11.02")]
        let newer = UpdateCheck.newer(than: "26.10.01", in: releases)
        #expect(newer.map(\.version) == ["26.12.01", "26.11.02"])
        #expect(UpdateCheck.newer(than: "26.12.01", in: releases).isEmpty)
    }

    @Test func decodesTheChangelogTolerantly() throws {
        let json = """
            {"releases": [
              {"version": "26.10.01", "code": "26100101", "date": "2026-10-30", "new": ["Boards"], "fixed": []},
              {"version": "26.11.01", "new": "not a list", "extra": true},
              {"code": "no version"}
            ]}
            """
        #expect(throws: (any Error).self) { try UpdateCheck.decode(Data(json.utf8)) }

        let valid = """
            {"releases": [
              {"version": "26.10.01", "code": "26100101", "date": "2026-10-30", "new": ["Boards"], "fixed": []},
              {"version": "26.11.01", "new": "not a list", "extra": true}
            ]}
            """
        let releases = try UpdateCheck.decode(Data(valid.utf8))
        #expect(releases.map(\.version) == ["26.11.01", "26.10.01"])
        #expect(releases[0].new.isEmpty)
        #expect(releases[1].new == ["Boards"])
        #expect(releases[1].date == "2026-10-30")
    }
}
