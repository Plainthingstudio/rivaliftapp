import Foundation
import Testing
@testable import Rivalift

@Suite("PlanCatalog")
struct PlanCatalogTests {
    @Test func programFollowsDaysPerWeek() throws {
        let muscle = try #require(PlanCatalog.plan(id: "build-muscle"))
        #expect(muscle.program(daysPerWeek: 3) == PlanRecommender.upperLower)
        #expect(muscle.program(daysPerWeek: 4) == PlanRecommender.upperLower)
        #expect(muscle.program(daysPerWeek: 6) == PlanRecommender.pushPullLegs)
        let shape = try #require(PlanCatalog.plan(id: "get-in-shape"))
        #expect(shape.program(daysPerWeek: 2) == PlanRecommender.fullBody)
        #expect(shape.program(daysPerWeek: 4) == PlanRecommender.upperLower)
        let lean = try #require(PlanCatalog.plan(id: "get-lean"))
        #expect(lean.program(daysPerWeek: 3) == PlanRecommender.getLean)
    }

    @Test func everyGoalHasAPlanAndIdsAreUnique() {
        for goal in TrainingGoal.allCases {
            #expect(PlanCatalog.all.contains(PlanCatalog.plan(for: goal)))
        }
        #expect(Set(PlanCatalog.all.map(\.id)).count == PlanCatalog.all.count)
    }

    @Test func everyProgramExistsInTheSeed() throws {
        let names = Set(try SeedLoader.loadPrograms(bundle: Bundle(for: BundleToken.self).appBundle).map(\.program))
        for plan in PlanCatalog.all {
            for entry in plan.programs { #expect(names.contains(entry.program)) }
        }
    }

    @Test func daysText() throws {
        #expect(try #require(PlanCatalog.plan(id: "get-stronger")).daysText == "3 days")
        #expect(try #require(PlanCatalog.plan(id: "get-lean")).daysText == "3–4 days")
    }
}
