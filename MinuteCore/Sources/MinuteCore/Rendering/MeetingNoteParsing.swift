import Foundation

public enum MeetingNoteParsing {
    public struct SpeakerHeader: Equatable, Sendable {
        public var speakerId: Int
        public var detectedName: String?
        public var suffix: String

        public init(speakerId: Int, detectedName: String?, suffix: String) {
            self.speakerId = speakerId
            self.detectedName = detectedName
            self.suffix = suffix
        }
    }

    public enum TranscriptLine: Equatable, Sendable {
        case speakerHeader(SpeakerHeader)
        case text(String)
    }

    public static func parseSpeakerIDs(fromTranscriptMarkdown markdown: String?) -> [Int] {
        guard let markdown else { return [] }

        var ids: Set<Int> = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Speaker ") else { continue }

            let afterPrefix = trimmed.dropFirst("Speaker ".count)
            let digits = afterPrefix.prefix { $0.isNumber }
            if let id = Int(digits) {
                ids.insert(id)
            }
        }

        return ids.sorted()
    }

    public static func rewriteSpeakerHeadingsForDisplay(
        transcriptMarkdown: String,
        speakerDisplayNames: [Int: String]
    ) -> String {
        let lines = transcriptMarkdown.split(separator: "\n", omittingEmptySubsequences: false)
        var out: [String] = []
        out.reserveCapacity(lines.count)

        for lineSub in lines {
            let line = String(lineSub)
            let leadingWhitespace = line.prefix { $0.isWhitespace }
            let remainder = line.dropFirst(leadingWhitespace.count)
            let trimmed = remainder.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Speaker ") {
                let afterPrefix = trimmed.dropFirst("Speaker ".count)
                let digits = afterPrefix.prefix { $0.isNumber }
                if let id = Int(digits),
                   let name = speakerDisplayNames[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !name.isEmpty,
                   let bracketRange = trimmed.range(of: " [") {
                    let suffix = String(trimmed[bracketRange.lowerBound...])
                    out.append(String(leadingWhitespace) + name + suffix)
                    continue
                }
            }
            out.append(line)
        }

        return out.joined(separator: "\n")
    }

    public static func parseTranscriptLines(_ transcript: String) -> [TranscriptLine] {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.map { sub in
            let line = String(sub)
            if let header = parseSpeakerHeader(line) {
                return .speakerHeader(header)
            }
            return .text(line)
        }
    }

    public static func splitTranscriptHeaderAndBody(_ transcript: String) -> (header: String, body: String) {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)

        var firstHeaderIndex: Int?
        for (index, lineSub) in lines.enumerated() {
            if parseSpeakerHeader(String(lineSub)) != nil {
                firstHeaderIndex = index
                break
            }
        }

        guard let firstHeaderIndex else {
            return (header: transcript, body: "")
        }

        let headerLines = lines.prefix(firstHeaderIndex)
        let bodyLines = lines.suffix(from: firstHeaderIndex)
        return (
            header: headerLines.joined(separator: "\n"),
            body: bodyLines.joined(separator: "\n")
        )
    }

    public static func containsSpeakerHeader(_ transcript: String) -> Bool {
        for lineSub in transcript.split(separator: "\n", omittingEmptySubsequences: false) {
            if parseSpeakerHeader(String(lineSub)) != nil {
                return true
            }
        }
        return false
    }

    private static func parseSpeakerHeader(_ line: String) -> SpeakerHeader? {
        let leadingWhitespace = line.prefix { $0.isWhitespace }
        let remainder = line.dropFirst(leadingWhitespace.count)
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)

        guard trimmed.hasPrefix("Speaker ") else { return nil }

        let afterPrefix = trimmed.dropFirst("Speaker ".count)
        let digits = afterPrefix.prefix { $0.isNumber }
        guard let speakerId = Int(digits) else { return nil }

        let afterDigits = afterPrefix.dropFirst(digits.count)
        var detectedName: String?

        let afterDigitsTrimmed = afterDigits.trimmingCharacters(in: .whitespaces)
        if afterDigitsTrimmed.hasPrefix("("),
           let closeIndex = afterDigitsTrimmed.firstIndex(of: ")") {
            let nameRange = afterDigitsTrimmed.index(after: afterDigitsTrimmed.startIndex)..<closeIndex
            let name = String(afterDigitsTrimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                detectedName = name
            }
        }

        guard let bracketRange = trimmed.range(of: " [") else {
            return nil
        }

        let suffix = String(trimmed[bracketRange.lowerBound...])
        return SpeakerHeader(speakerId: speakerId, detectedName: detectedName, suffix: suffix)
    }
}
