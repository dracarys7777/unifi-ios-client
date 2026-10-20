import XCTest
@testable import Unifi

final class RequestFailureTests: XCTestCase {
    func testStatusIsUsefulWithoutLeakingBackendText() {
        let result = RequestFailure.message(forDiagnosticText:
            "PERMISSION_DENIED private-prompt secret-token project/private")
        XCTAssertTrue(result.contains("[PERMISSION_DENIED]"))
        for sensitive in ["private-prompt", "secret-token", "project/private"] {
            XCTAssertFalse(result.contains(sensitive))
        }
    }
    func testSpecificCauseTakesPriorityOverGeneralStatus() {
        let result = RequestFailure.message(forDiagnosticText: "PERMISSION_DENIED SERVICE_DISABLED")
        XCTAssertTrue(result.contains("[SERVICE_DISABLED]"))
    }
    func testUnknownPayloadIsNeverEchoed() {
        XCTAssertTrue(RequestFailure.message(forDiagnosticText: "private-secret").contains("[UNCLASSIFIED]"))
        XCTAssertFalse(RequestFailure.message(forDiagnosticText: "private-secret").contains("private-secret"))
    }
    func testStatusMustBeACompleteToken() {
        XCTAssertTrue(RequestFailure.message(forDiagnosticText: "NOT_FOUND_IN_PROMPT").contains("[UNCLASSIFIED]"))
    }
    func testOfflineFailureIsClassified() {
        let result = RequestFailure.message(for: URLError(.notConnectedToInternet))
        XCTAssertTrue(result.contains("[NETWORK]"))
    }
}
