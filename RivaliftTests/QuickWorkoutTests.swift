import Foundation
import Testing
@testable import Rivalift

@Suite("QuickWorkout")
struct QuickWorkoutTests {
    typealias O = QuickWorkout.Option
    let squat = O(id: UUID(), primary: .quads, equipment: .barbell, isCompound: true)
    let goblet = O(id: UUID(), primary: .quads, equipment: .dumbbell, isCompound: true)
    let bench = O(id: UUID(), primary: .chest, equipment: .barbell, isCompound: true)
    let dbPress = O(id: UUID(), primary: .chest, equipment: .dumbbell, isCompound: true)
    let pushUp = O(id: UUID(), primary: .chest, equipment: .bodyweight, isCompound: true)
    let row = O(id: UUID(), primary: .back, equipment: .dumbbell, isCompound: true)
    let rdl = O(id: UUID(), primary: .hamstrings, equipment: .dumbbell, isCompound: true)
    let plank = O(id: UUID(), primary: .core, equipment: .bodyweight, isDuration: true)
    let curl = O(id: UUID(), primary: .biceps, equipment: .dumbbell)
    var all: [O] { [squat, goblet, bench, dbPress, pushUp, row, rdl, plank, curl] }

    @Test func exerciseCountGrowsWithTime() {
        #expect(QuickWorkout.minutes.map(QuickWorkout.exerciseCount) == [3, 4, 5, 6])
    }

    @Test func dumbbellsKitSkipsBarbells() {
        let items = QuickWorkout.build(kit: .dumbbells, minutes: 60, focus: .fullBody, from: all)
        #expect(items.map(\.id) == [goblet.id, dbPress.id, row.id, rdl.id, plank.id, curl.id])
        #expect(items.first == .init(id: goblet.id, sets: 3, reps: 10))
        #expect(items.first { $0.id == plank.id }?.reps == 0)
        #expect(items.last == .init(id: curl.id, sets: 2, reps: 12))
    }

    @Test func timeLimitsTheCountAndNothingRepeats() {
        let items = QuickWorkout.build(kit: .gym, minutes: 15, focus: .fullBody, from: all)
        #expect(items.count == 3)
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test func noEquipmentUsesBodyweightOnly() {
        let items = QuickWorkout.build(kit: .none, minutes: 30, focus: .fullBody, from: all)
        #expect(items.map(\.id) == [pushUp.id, plank.id])
    }

    @Test func shuffleChangesPicksAndIsRepeatable() {
        let first = QuickWorkout.build(kit: .gym, minutes: 30, focus: .fullBody, from: all)
        let shuffled = QuickWorkout.build(kit: .gym, minutes: 30, focus: .fullBody, from: all, shuffle: 1)
        #expect(first != shuffled)
        #expect(shuffled == QuickWorkout.build(kit: .gym, minutes: 30, focus: .fullBody, from: all, shuffle: 1))
    }
}
