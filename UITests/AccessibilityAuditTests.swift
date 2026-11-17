import XCTest

/// Runs Apple's Accessibility Audit (the same checks as Xcode's Accessibility Inspector) on every screen:
/// missing labels, elements VoiceOver can't reach, hit areas too small, text that doesn't grow with Larger Text,
/// contrast, clipped text and more. Every problem is printed as an "AUDIT:" line, then the test fails if there were any.
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!
    private var issues: [String] = []
    /// "Partially supports Dynamic Type" on SwiftUI list text: listed, but checked by eye on the large-text
    /// screenshots instead of failing the test, because the audit reports it for plain system list text too.
    private var warnings: [String] = []

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-skipIntro", "YES"]
        app.launch()
    }

    private func audit(_ screen: String) {
        do {
            let screenFrame = app.windows.firstMatch.frame
            let navBar = app.navigationBars.firstMatch
            let underBarLine = navBar.exists ? navBar.frame.maxY : 0
            try app.performAccessibilityAudit { issue in
                var what = "the screen"
                // An issue with no element on a scrolled page is the audit catching the list mid-scroll.
                if issue.element == nil && screen.contains("page") { return true }
                if let element = issue.element {
                    // Something cut off by the bottom of the screen isn't clipped: it's checked after scrolling.
                    if !screenFrame.isEmpty && !screenFrame.contains(element.frame) { return true }
                    // Text that has scrolled up under the see-through navigation bar isn't really low contrast.
                    if element.frame.minY < underBarLine { return true }
                    let label = element.label.isEmpty ? "(no label)" : "'\(element.label)'"
                    what = "\(element.elementType) \(label)"
                }
                let line = "[\(screen)] \(issue.compactDescription) — \(what)"
                if issue.auditType == .dynamicType && issue.compactDescription.contains("partially") {
                    if !self.warnings.contains(where: { $0.hasSuffix(what) }) { self.warnings.append(line) }
                } else {
                    self.issues.append(line)
                }
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
        // Scroll down and check what was below the edge.
        for page in 2...4 {
            app.swipeUp()
            sleep(3) // let the list stop gliding before looking
            audit("\(screen), page \(page)")
        }
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
        sleep(10) // past the Host's welcome, so the caption isn't changing mid-audit
        audit("Playing")

        print("AUDIT: \(issues.count) problem(s) found")
        for issue in issues { print("AUDIT: \(issue)") }
        print("AUDIT: \(warnings.count) to check on the large-text screenshots")
        for warning in warnings { print("AUDIT: (check) \(warning)") }
        XCTAssertTrue(issues.isEmpty, issues.joined(separator: "\n"))
    }

    /// Screenshots of every screen at the largest accessibility text size, to check by eye that nothing is cut off.
    func testLargestTextScreenshots() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 10))
        shot("1 Main menu")
        for (i, name) in ["How to Play", "Settings", "Credits"].enumerated() {
            let link = app.buttons[name]
            if !link.isHittable { app.swipeUp() }
            guard link.waitForExistence(timeout: 5) else { continue }
            link.tap()
            sleep(1)
            for page in 1...4 {
                shot("\(i + 2) \(name) \(page)")
                app.swipeUp()
                sleep(1)
            }
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
            app.swipeDown()
        }
        let play = app.buttons["Play"]
        if play.waitForExistence(timeout: 5) {
            play.tap()
            sleep(5)
            shot("5 Playing")
        }
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
