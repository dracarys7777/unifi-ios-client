import XCTest
@testable import Unifi

final class ChatRecordTests: XCTestCase {
    func testInterruptedExchangeIsNotReplayed() {
        let record = ChatRecord(messages: [
            ChatMessage(role: "user", text: "first"),
            ChatMessage(role: "model", text: "partial", complete: false),
            ChatMessage(role: "user", text: "second"),
            ChatMessage(role: "model", text: "finished")
        ])
        XCTAssertEqual(record.replayableMessages.map(\.text), ["second", "finished"])
    }
    func testEmptyReplyIsNotReplayed() {
        let record = ChatRecord(messages: [ChatMessage(role: "user", text: "hello"), ChatMessage(role: "model", text: "")])
        XCTAssertTrue(record.replayableMessages.isEmpty)
    }
    func testDiskRoundTripAndCorruption() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let disk = ChatDisk(url: folder.appendingPathComponent("chat.json"))
        XCTAssertEqual(try disk.load(), ChatRecord())
        let record = ChatRecord(messages: [ChatMessage(role: "user", text: "hello")])
        try disk.save(record)
        XCTAssertEqual(try disk.load(), record)
        try Data("invalid".utf8).write(to: disk.url)
        XCTAssertThrowsError(try disk.load())
    }
}
