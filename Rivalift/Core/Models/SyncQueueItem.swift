import Foundation
import SwiftData

/// Outgoing server work, processed by `SyncService` once accounts exist (M4).
@Model
final class SyncQueueItem {
    var id: UUID = UUID()
    /// e.g. "session_summary", "pr_event", "competition_entry".
    var kind: String = ""
    var payload: Data = Data()
    var createdAt: Date = Date()
    var attempts: Int = 0
    var isRejected: Bool = false

    init(kind: String, payload: Data) {
        self.kind = kind
        self.payload = payload
    }
}
