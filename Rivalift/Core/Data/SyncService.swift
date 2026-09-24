import Foundation
import SwiftData

/// Sends session summaries, PR events and competition entries to Supabase (M4).
///
/// Until accounts exist (AUTH-01…03) nothing is enqueued: the app is fully usable offline
/// and without login. The queue model (`SyncQueueItem`) and client-generated UUIDs are in
/// place so the M4 implementation can upsert idempotently.
@MainActor
final class SyncService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    var isSignedIn: Bool { false }

    func enqueueSessionSummary(_ session: WorkoutSession) {
        guard isSignedIn else { return }
        // M4: encode the summary, insert a SyncQueueItem, then call processQueue().
    }

    func processQueue() async {
        guard isSignedIn else { return }
        // M4: send pending items with exponential backoff; mark rejected items (section 14.3).
    }
}
