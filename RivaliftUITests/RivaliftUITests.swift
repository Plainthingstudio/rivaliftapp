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

    /// Pick exercises and ready-made workouts live in Custom mode; Home opens in My Plan.
    private func openStartScreen(_ app: XCUIApplication) {
        let menu = app.buttons["homeModeMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Custom"].tap()
        XCTAssertTrue(app.buttons["startPickExercises"].waitForExistence(timeout: 5))
    }

    /// - Parameter trainToday: picks today as the only training day, so the plan has a workout
    ///   today whatever day the tests run (Home shows a rest day otherwise).
    private func launchAndOnboard(trainToday: Bool = false) -> XCUIApplication {
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
        if trainToday {
            let calendar = Calendar.current
            app.buttons[calendar.weekdaySymbols[calendar.component(.weekday, from: Date()) - 1]].tap()
        }
        app.buttons["scheduleContinue"].tap()
        app.buttons["commitButton"].tap()
        XCTAssertTrue(app.buttons["onboardingFinish"].waitForExistence(timeout: 5))
        app.buttons["onboardingFinish"].tap()
        return app
    }

    @MainActor
    func testOnboardingPlanIsRecommendedOnStart() throws {
        let app = launchAndOnboard()

        // My Plan Home shows the plan's first workout: today's, or "Train anyway" on a rest day.
        let start = app.buttons["startPlanWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(app, "5×5 Workout A").exists)
        start.tap()

        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwapPlanExerciseAndOpenPlan() throws {
        let app = launchAndOnboard(trainToday: true)

        let swap = app.buttons["swapExercise"].firstMatch
        XCTAssertTrue(swap.waitForExistence(timeout: 5))
        swap.tap()
        let confirm = app.buttons["confirmSwap"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertFalse(confirm.waitForExistence(timeout: 2))

        // The plan card opens the plan as a preview; Edit unlocks changes.
        app.buttons["planCard"].tap()
        let edit = app.buttons["editPlanButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["changePlanButton"].exists)
        edit.tap()
        XCTAssertTrue(app.buttons["changePlanButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLibraryStartsAnotherPlanAndProfileShowsHistory() throws {
        let app = launchAndOnboard()

        app.tabBars.buttons["Library"].tap()
        let program = app.buttons["plan-overall-fitness"]
        XCTAssertTrue(program.waitForExistence(timeout: 5))
        program.tap()
        app.buttons["startThisPlan"].tap()
        // Onboarding already gave a plan, so switching asks first.
        let confirm = app.alerts.buttons["Switch plan"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["startPlanWorkout"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(app, "Full Body A").exists)

        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["profileHistory"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStreakScreenOpensFromHome() throws {
        let app = launchAndOnboard()

        let streak = app.buttons["streakButton"]
        XCTAssertTrue(streak.waitForExistence(timeout: 5))
        streak.tap()
        XCTAssertTrue(labelled(app, "Rest weeks").waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuickWorkoutFromModeMenu() throws {
        let app = launchAndOnboard()

        let menu = app.buttons["homeModeMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        // The menu item's label includes its subtitle.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Quick Workout")).firstMatch.tap()
        let start = app.buttons["startQuickWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["shuffleQuickWorkout"].tap()
        start.tap()
        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBrowseTemplateDetailThenStart() throws {
        let app = launchAndOnboard()

        openStartScreen(app)
        app.buttons["createWorkoutButton"].tap()
        app.buttons["From a ready-made workout"].tap()
        let template = app.staticTexts["5×5 Workout B"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        let start = app.buttons["startTemplateButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        // A ready-made workout is copied before editing.
        XCTAssertTrue(app.buttons["saveTemplateCopy"].exists)

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

        openStartScreen(app)
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

        openStartScreen(app)
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

