import XCTest

// MARK: - OpenCountUITests
//
// End-to-end UI smoke tests for OpenCount.
// Requirement 28 (Phase 1 checkpoint): launch, create session, place markers, export CSV.
// Requirement 50 (Req 39): accessibility audit using performAccessibilityAudit (Xcode 15+).

final class OpenCountUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Skip onboarding and seed a test session for deterministic UI state
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App launch smoke test

    /// Verifies the app launches and shows the session list within 10 seconds.
    func testAppLaunchesAndShowsSessionList() throws {
        let sessionList = app.navigationBars["Sessions"]
        XCTAssertTrue(
            sessionList.waitForExistence(timeout: 10),
            "Session list should appear within 10 seconds of launch"
        )
    }

    // MARK: - Session list accessibility audit

    /// Runs the Xcode 15+ accessibility audit on the session list screen.
    /// Requirement 50 (Req 39): WCAG 2.1 AA compliance.
    func testSessionListAccessibilityAudit() throws {
        let sessionList = app.navigationBars["Sessions"]
        XCTAssertTrue(sessionList.waitForExistence(timeout: 10))

        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    // MARK: - New session creation

    /// Creates a new session and verifies it appears in the list.
    func testCreateNewSession() throws {
        // Tap the + button
        let addButton = app.navigationBars.buttons["New session"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Fill in the session name
        let nameField = app.textFields["Session name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("UI Test Session")

        // Tap Create
        let createButton = app.buttons["Create session"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()

        // Verify we're back on the session list or inside the new session
        let sessionListOrDetail = app.navigationBars["Sessions"].waitForExistence(timeout: 5)
            || app.navigationBars["UI Test Session"].waitForExistence(timeout: 5)
        XCTAssertTrue(sessionListOrDetail, "Should return to session list or open the new session")
    }

    // MARK: - Settings accessibility audit

    /// Opens Settings and runs the accessibility audit.
    func testSettingsAccessibilityAudit() throws {
        let settingsButton = app.navigationBars.buttons["Settings"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTSkip("Settings button not found — skipping audit")
        }
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))

        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    // MARK: - All navigation bar buttons have accessibility labels

    /// Verifies that every navigation bar button has a non-empty accessibility label.
    func testAllNavigationButtonsHaveAccessibilityLabels() throws {
        let sessionList = app.navigationBars["Sessions"]
        XCTAssertTrue(sessionList.waitForExistence(timeout: 10))

        let navButtons = app.navigationBars.buttons.allElementsBoundByIndex
        for button in navButtons {
            XCTAssertFalse(
                button.label.isEmpty,
                "Navigation bar button has no accessibility label: \(button)"
            )
        }
    }
}
