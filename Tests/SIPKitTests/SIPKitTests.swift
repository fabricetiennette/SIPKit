import XCTest
@testable import SIPKit

final class SIPKitTests: XCTestCase {
    func testInitSipKit() throws {
        let sipManager = SipManager()
        XCTAssertNotNil(sipManager)
    }
}
