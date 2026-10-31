import Foundation
import Testing

@testable import Domain

@Suite("UpdateCheck")
struct UpdateCheckTests {
    @Test func comparesBuildsByCodeNotVersion() {
        let releases = [
            Release(version: "26.11.01", code: 26_110_101),
            Release(version: "26.11.01", code: 26_110_103),
            Release(version: "26.10.01", code: 26_100_101),
        ]
        #expect(UpdateCheck.newer(than: 26_110_101, in: releases).map(\.code) == [26_110_103])
        #expect(UpdateCheck.newer(than: 26_110_102, in: releases).map(\.code) == [26_110_103])
        #expect(UpdateCheck.newer(than: 26_110_103, in: releases).isEmpty)
        #expect(UpdateCheck.newer(than: UpdateCheck.code("not a number"), in: releases).count == 3)
    }

    @Test func titlesNameLaterBuilds() {
        #expect(Release(version: "26.11.01").title == "26.11.01 - 26110101")
        #expect(Release(version: "26.11.01").code == 26_110_101)
        #expect(Release(version: "26.11.01", code: 26_110_103).title == "26.11.01 - 26110103")
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
        #expect(releases.map(\.code) == [26_110_101, 26_100_101])
        #expect(releases[0].new.isEmpty)
        #expect(releases[1].new == ["Boards"])
        #expect(releases[1].date == "2026-10-30")
    }

    @Test func dropsMalformedVersionsAndOversizedFeeds() throws {
        let json = #"""
            {"releases": [{"version": "26.11.01", "code": "26110103"}, {"version": "<script>"},
              {"version": "1.2.3.4.5"}, {"version": "26.11.02", "code": "123"}]}
            """#
        #expect(try UpdateCheck.decode(Data(json.utf8)).map(\.code) == [26_110_103])
        let huge = Data(repeating: 0x20, count: UpdateCheck.maximumFeedBytes + 1)
        #expect(throws: (any Error).self) { try UpdateCheck.decode(huge) }
    }
}
