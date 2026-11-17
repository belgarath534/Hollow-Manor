import XCTest

/// Runs Apple's Accessibility Audit (the same checks as Xcode's Accessibility Inspector) on every screen:
/// missing labels, elements VoiceOver can't reach, hit areas too small, text that doesn't grow with Larger Text,
/// contrast, clipped text and more. Every problem is printed as an "AUDIT:" line, then the test fails if there were any.
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!
    private var issues: [String] = []

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-skipIntro", "YES"]
        app.launch()
    }

    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                var what = "the screen"
                if let element = issue.element {
                    let label = element.label.isEmpty ? "(no label)" : "'\(element.label)'"
                    what = "\(element.elementType) \(label)"
                }
                self.issues.append("[\(screen)] \(issue.compactDescription) — \(what)")
                return true // keep going and report everything at the end
            }
        } catch {
            issues.append("[\(screen)] the audit itself failed: \(error)")
        }
    }

    private func open(_ button: String, audit screen: String) {
        let link = app.buttons[button]
        guard link.waitForExistence(timeout: 5) else {
            issues.append("[Main menu] can't find the '\(button)' button")
            return
        }
        link.tap()
        sleep(1)
        audit(screen)
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
    }

    func testEveryScreen() throws {
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 10))
        audit("Main menu")
        open("How to Play", audit: "How to Play")
        open("Settings", audit: "Settings")
        open("Credits", audit: "Credits")

        app.buttons["Play"].tap()
        sleep(4)
        audit("Playing")

        print("AUDIT: \(issues.count) problem(s) found")
        for issue in issues { print("AUDIT: \(issue)") }
        XCTAssertTrue(issues.isEmpty, issues.joined(separator: "\n"))
    }
}
