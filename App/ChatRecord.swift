import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: String
    var text: String
    var complete: Bool
    init(role: String, text: String, complete: Bool = true) {
        id = UUID()
        self.role = role
        self.text = text
        self.complete = complete
    }
}

struct ChatRecord: Codable, Equatable {
    var messages: [ChatMessage] = []
    // Only complete user/model exchanges are sent as history. Interrupted
    // answers and their unmatched prompts remain visible but are not replayed.
    var replayableMessages: [ChatMessage] {
        var result: [ChatMessage] = []
        for index in messages.indices where messages[index].role == "user" {
            let next = index + 1
            if next < messages.count, messages[next].role == "model",
               messages[next].complete, !messages[next].text.isEmpty {
                result.append(contentsOf: [messages[index], messages[next]])
            }
        }
        return result
    }
}

struct ChatDisk {
    let url: URL
    func load() throws -> ChatRecord {
        guard FileManager.default.fileExists(atPath: url.path) else { return ChatRecord() }
        return try JSONDecoder().decode(ChatRecord.self, from: Data(contentsOf: url))
    }
    func save(_ record: ChatRecord) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: url, options: [.atomic, .completeFileProtection])
        var location = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try location.setResourceValues(values)
    }
}
