import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testReviewAndReopenProduct() throws {
    let app = XCUIApplication()
    app.launchEnvironment["REVIEW_TEST_STORE"] = UUID().uuidString
    app.launch()
    app.buttons["Add sample product"].click()
    XCTAssertTrue(app.textFields["productName"].waitForExistence(timeout: 60), app.debugDescription)
    let note = app.textFields["newNote"].exists ? app.textFields["newNote"] : app.textViews["newNote"]
    note.click(); note.typeText("Check the shade finish before production.")
    app.buttons["Add note"].click()
    let resolved = app.checkBoxes["Resolved: Check the shade finish before production."]
    XCTAssertTrue(resolved.waitForExistence(timeout: 10), app.debugDescription)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Product review"; screenshot.lifetime = .keepAlways; add(screenshot)
    app.terminate(); app.launch()
    let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "review-")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription); row.click()
    XCTAssertTrue(resolved.waitForExistence(timeout: 10), app.debugDescription)
    resolved.click()
    let marked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 1 OR value == '1'"), object: resolved)
    XCTAssertEqual(XCTWaiter.wait(for: [marked], timeout: 10), .completed)
    app.buttons["Archive product"].click()
    app.switches["Show archive"].click()
    XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription); row.click()
    XCTAssertTrue(app.buttons["Restore product"].waitForExistence(timeout: 10), app.debugDescription)
    app.buttons["Restore product"].click()
  }
}
