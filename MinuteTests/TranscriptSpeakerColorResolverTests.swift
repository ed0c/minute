import Testing
@testable import Minute

struct TranscriptSpeakerColorResolverTests {
    @Test
    func hue_isDeterministicForSameSpeakerID() {
        let first = TranscriptSpeakerHueResolver.hue(for: 3)
        let second = TranscriptSpeakerHueResolver.hue(for: 3)

        #expect(first == second)
    }

    @Test
    func hue_isDistinctForFirstTenSpeakers() {
        let hues = (1...10).map { TranscriptSpeakerHueResolver.hue(for: $0) }

        #expect(Set(hues).count == hues.count)
    }

    @Test
    func nonPositiveSpeakerIDs_fallbackToFirstColorBucket() {
        let baseline = TranscriptSpeakerHueResolver.hue(for: 1)

        #expect(TranscriptSpeakerHueResolver.hue(for: 0) == baseline)
        #expect(TranscriptSpeakerHueResolver.hue(for: -5) == baseline)
    }
}
