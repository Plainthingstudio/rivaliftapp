import XCTest

/// Main flows in the simulator: onboarding → plan → start sheet → log a set → finish.
final class RivaliftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAndOnboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["onboardingGetStarted"].tap()
        let name = app.textFields["nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Sam")
        app.buttons["nameContinue"].tap()
        app.buttons["goal-strength"].tap()
        app.buttons["level-beginner"].tap()
        app.buttons["unit-kg"].tap()
        app.buttons["target-3"].tap()
        app.buttons["scheduleContinue"].tap()
        app.buttons["commitButton"].tap()
        XCTAssertTrue(app.buttons["onboardingFinish"].waitForExistence(timeout: 5))
        app.buttons["onboardingFinish"].tap()
        return app
    }

    @MainActor
    func testOnboardingPlanIsRecommendedOnStart() throws {
        let app = launchAndOnboard()

        XCTAssertTrue(app.staticTexts["Hi, Sam"].waitForExistence(timeout: 5))
        app.buttons["startWorkoutButton"].tap()
        let recommended = app.buttons["startRecommended"]
        XCTAssertTrue(recommended.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5×5 Workout A"].exists)
        recommended.tap()

        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBrowseTemplateDetailThenStart() throws {
        let app = launchAndOnboard()

        app.buttons["startWorkoutButton"].tap()
        app.buttons["browseTemplates"].tap()
        let template = app.staticTexts["5×5 Workout B"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        let start = app.buttons["startTemplateButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogAndFinishWorkout() throws {
        let app = launchAndOnboard()

        app.buttons["startWorkoutButton"].tap()
        app.buttons["startPickExercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Bench Press")
        app.staticTexts["Barbell Bench Press"].firstMatch.tap()
        app.buttons["addSelectedExercisesButton"].tap()

        let weight = app.textFields.element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
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
