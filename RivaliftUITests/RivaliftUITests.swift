import XCTest

/// Main flow in the simulator: onboarding → empty workout → add exercise → log a set → finish.
final class RivaliftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingReachesWorkoutInFourTaps() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["onboardingGetStarted"].tap()
        app.buttons["unit-kg"].tap()
        app.buttons["target-3"].tap()
        app.buttons["startEmpty"].tap()

        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogAndFinishWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["onboardingGetStarted"].tap()
        app.buttons["unit-kg"].tap()
        app.buttons["target-3"].tap()
        app.buttons["startEmpty"].tap()

        app.buttons["addExerciseButton"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Bench Press")
        app.staticTexts["Barbell Bench Press"].firstMatch.tap()
        app.buttons["addSelectedExercisesButton"].tap()

        let weight = app.textFields.element(boundBy: 0)
        weight.tap()
        weight.typeText("60")
        let reps = app.textFields.element(boundBy: 1)
        reps.tap()
        reps.typeText("8")
        app.buttons["completeSetButton"].firstMatch.tap()

        app.buttons["finishWorkoutButton"].tap()
        XCTAssertTrue(app.buttons["summaryDoneButton"].waitForExistence(timeout: 5))
        app.buttons["summaryDoneButton"].tap()
    }
}
