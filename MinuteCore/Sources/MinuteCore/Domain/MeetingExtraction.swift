import Foundation

public struct MeetingSummarySectionVisibility: Equatable, Sendable {
    public var decisions: Bool
    public var actionItems: Bool
    public var openQuestions: Bool
    public var keyPoints: Bool

    public init(
        decisions: Bool = true,
        actionItems: Bool = true,
        openQuestions: Bool = true,
        keyPoints: Bool = true
    ) {
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
    }

    public static let allEnabled = MeetingSummarySectionVisibility()
}

/// Fixed v1 schema produced by the summarization model.
///
/// The model must output JSON only, matching this structure exactly.
public struct MeetingExtraction: Codable, Equatable, Sendable {
    public var title: String
    /// `YYYY-MM-DD`
    public var date: String
    public var summary: String
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]
    public var meetingType: MeetingType?

    public init(
        title: String,
        date: String,
        summary: String,
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = [],
        meetingType: MeetingType? = nil
    ) {
        self.title = title
        self.date = date
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
        self.meetingType = meetingType
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summary
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case keyPoints = "key_points"
        case meetingType = "meeting_type"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(String.self, forKey: .date)
        summary = try container.decode(String.self, forKey: .summary)
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        meetingType = try container.decodeIfPresent(MeetingType.self, forKey: .meetingType)
    }
}

public struct ActionItem: Codable, Equatable, Sendable {
    public var owner: String
    public var task: String

    public init(owner: String, task: String) {
        self.owner = owner
        self.task = task
    }
}

public struct SummarizationPassDelta: Codable, Equatable, Sendable {
    public var title: String
    public var date: String
    public var summaryPoints: [String]
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]

    public init(
        title: String = "",
        date: String = "",
        summaryPoints: [String] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = []
    ) {
        self.title = title
        self.date = date
        self.summaryPoints = summaryPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summary
        case summaryPoints = "summary_points"
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case keyPoints = "key_points"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        let explicitSummaryPoints = try container.decodeIfPresent([String].self, forKey: .summaryPoints) ?? []
        let legacySummary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        summaryPoints = explicitSummaryPoints.isEmpty ? Self.summaryPoints(from: legacySummary) : explicitSummaryPoints
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(summaryPoints, forKey: .summaryPoints)
        try container.encode(decisions, forKey: .decisions)
        try container.encode(actionItems, forKey: .actionItems)
        try container.encode(openQuestions, forKey: .openQuestions)
        try container.encode(keyPoints, forKey: .keyPoints)
    }

    public static func summaryPoints(from summary: String) -> [String] {
        let normalized = StringNormalizer.normalizeParagraph(summary)
        guard !normalized.isEmpty else { return [] }
        return [normalized]
    }
}

public struct SummarizationMergeState: Codable, Equatable, Sendable {
    public var title: String
    public var date: String
    public var summaryPoints: [String]
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]
    public var meetingType: MeetingType?

    public init(
        title: String = "",
        date: String = "",
        summaryPoints: [String] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = [],
        meetingType: MeetingType? = nil
    ) {
        self.title = title
        self.date = date
        self.summaryPoints = summaryPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
        self.meetingType = meetingType
    }

    public init(extraction: MeetingExtraction) {
        self.init(
            title: extraction.title,
            date: extraction.date,
            summaryPoints: SummarizationPassDelta.summaryPoints(from: extraction.summary),
            decisions: extraction.decisions,
            actionItems: extraction.actionItems,
            openQuestions: extraction.openQuestions,
            keyPoints: extraction.keyPoints,
            meetingType: extraction.meetingType
        )
    }
}
