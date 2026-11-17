import XCTest

/// Main flows in the simulator: onboarding → plan → start sheet → log a set → finish.
final class RivaliftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    /// Group cards and other combined rows: the first element whose label mentions the text.
    private func labelled(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Exercise pickers show a card whose label starts with the exercise name.
    private func exerciseCard(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func launchAndOnboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["onboardingGetStarted"].tap()
        let name = app.textFields["nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        // Return submits the name; the AutoFill bar can shift the Continue button mid-tap.
        name.typeText("Sam\n")
        let goal = app.buttons["goal-strength"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
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

        // Each exercise opens its detail with how-to steps.
        let exercise = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Overhead Press'")).firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        XCTAssertTrue(app.staticTexts["How to do it"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreateAndJoinLeagueGroups() throws {
        let app = launchAndOnboard()

        app.tabBars.buttons["Leagues"].tap()
        app.buttons["createGroupButton"].tap()
        let name = app.textFields["groupNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Gym Buddies\n") // close the keyboard so the bottom Create button takes the tap
        app.buttons["createGroupConfirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inviteCode"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(labelled(app, "Gym Buddies").waitForExistence(timeout: 5))

        app.buttons["joinGroupButton"].tap()
        let code = app.textFields["joinCodeField"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.typeText("ab3k7q")
        let join = app.buttons["joinGroupConfirm"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        join.tap()
        XCTAssertTrue(labelled(app, "Iron Squad").waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreateCustomLeagueShowsCategoryTabs() throws {
        let app = launchAndOnboard()

        app.tabBars.buttons["Leagues"].tap()
        app.buttons["createGroupButton"].tap()
        let name = app.textFields["groupNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Rep Kings\n") // close the keyboard so the bottom Create button takes the tap
        app.buttons["Custom"].firstMatch.tap()
        app.buttons["createGroupConfirm"].tap()
        app.buttons["Done"].tap()

        let group = labelled(app, "Rep Kings")
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        XCTAssertTrue(app.buttons["Overall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pull-Up · Max reps"].exists)
    }

    @MainActor
    func testAddCustomCategoryWhileCreatingGroup() throws {
        let app = launchAndOnboard()

        app.tabBars.buttons["Leagues"].tap()
        app.buttons["createGroupButton"].tap()
        let name = app.textFields["groupNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Core Crew\n") // close the keyboard so the bottom Create button takes the tap
        app.buttons["Custom"].firstMatch.tap()

        let newCategory = app.buttons["newCategoryButton"]
        for _ in 0..<5 where !newCategory.isHittable { app.swipeUp() }
        newCategory.tap()
        app.buttons["categoryExerciseRow"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Side Plank")
        exerciseCard(app, "Side Plank").tap()
        app.buttons["saveCategoryButton"].tap()

        XCTAssertTrue(app.staticTexts["Side Plank"].waitForExistence(timeout: 5), "Category added and still in the New group form")
        app.buttons["createGroupConfirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inviteCode"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let group = labelled(app, "Core Crew")
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        XCTAssertTrue(app.buttons["Side Plank · Longest hold"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddLiftThenMixIntoCustom() throws {
        let app = launchAndOnboard()

        app.tabBars.buttons["Leagues"].tap()
        app.buttons["createGroupButton"].tap()
        XCTAssertTrue(app.textFields["groupNameField"].waitForExistence(timeout: 5))
        app.textFields["groupNameField"].typeText("\n") // keyboard would cover the taller lift rows
        app.buttons["Strength"].firstMatch.tap()

        let addLift = app.buttons["addLiftButton"]
        for _ in 0..<5 where !addLift.isHittable { app.swipeUp() }
        addLift.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Overhead Press")
        exerciseCard(app, "Overhead Press").tap()
        XCTAssertTrue(app.staticTexts["Overhead Press"].waitForExistence(timeout: 5), "Fourth lift added")

        let mix = app.buttons["mixIntoCustomButton"]
        for _ in 0..<5 where !mix.isHittable { app.swipeUp() }
        mix.tap()
        XCTAssertTrue(app.staticTexts["Estimated 1RM · Improvement"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Overhead Press"].exists)
    }

    @MainActor
    func testCompetedExerciseShowsLeagueHint() throws {
        let app = launchAndOnboard()

        app.buttons["startWorkoutButton"].tap()
        app.buttons["startPickExercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Pull-Up")
        exerciseCard(app, "Pull-Up").tap()
        app.buttons["addSelectedExercisesButton"].tap()

        let hint = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Pull-up Club")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
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
        exerciseCard(app, "Barbell Bench Press").tap()
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
