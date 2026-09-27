import XCTest

/// Exercises the macOS keyboard input added in #23/#24 (`'t'`/`' '`),
/// using XCUITest's automation rather than a broad, whole-Mac
/// Accessibility grant (like `osascript ... keystroke` needs) — the
/// test runner gets scoped access to just the launched app.
final class CarnivalAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The coaster/ferris views change every frame just from ride
    /// motion, so a plain "screenshot before/after pressing 't'" test
    /// would pass even if 't' did nothing — pausing first removes that
    /// confound, so any difference observed is attributable to the
    /// camera-mode toggle itself.
    @MainActor
    func testSpacePausesAnimationAndTTogglesCamera() throws {
        let app = XCUIApplication()
        app.launch()

        // Let the Metal view render a real frame before interacting.
        Thread.sleep(forTimeInterval: 1)

        app.typeKey(" ", modifierFlags: [])  // pause
        Thread.sleep(forTimeInterval: 0.5)

        let pausedA = try screenshot(of: app)
        Thread.sleep(forTimeInterval: 1)
        let pausedB = try screenshot(of: app)
        XCTAssertEqual(
            pausedA, pausedB,
            "The scene shouldn't change between two screenshots while paused.")

        app.typeKey("t", modifierFlags: [])  // toggle to the ferris view
        Thread.sleep(forTimeInterval: 0.5)
        let ferris = try screenshot(of: app)
        XCTAssertNotEqual(
            pausedB, ferris,
            "Pressing 't' should change the rendered view (coaster -> ferris).")

        app.typeKey("t", modifierFlags: [])  // toggle back to the coaster view
        Thread.sleep(forTimeInterval: 0.5)
        let coasterAgain = try screenshot(of: app)
        XCTAssertEqual(
            pausedB, coasterAgain,
            "Toggling 't' twice, with nothing else changing while paused, should return to the same coaster view.")
    }

    /// Screenshots just the app's window, not the whole screen — the
    /// whole-screen `XCUIScreen.main.screenshot()` would also pick up
    /// unrelated changes elsewhere (menu bar clock, cursor, etc.).
    private func screenshot(of app: XCUIApplication) throws -> Data {
        try XCTUnwrap(app.windows.firstMatch.screenshot().pngRepresentation)
    }
}
