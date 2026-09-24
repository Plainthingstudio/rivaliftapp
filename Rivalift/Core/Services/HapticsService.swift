import AudioToolbox
import UIKit

@MainActor
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }

    /// Rest timer finished in the foreground. The system sound is silenced by the mute switch,
    /// so in silent mode only the vibration is felt (section 14.1).
    static func restFinished(sound: Bool, vibrate: Bool) {
        if vibrate { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        if sound { AudioServicesPlaySystemSound(1005) }
    }
}
