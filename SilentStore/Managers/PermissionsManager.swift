import Foundation
import Combine
import Photos
import AVFoundation
import UserNotifications

@MainActor
final class PermissionsManager: ObservableObject {
    private let didShowKey = "didShowPermissionsSheet"

    var shouldShowPermissionsSheet: Bool {
        !UserDefaults.standard.bool(forKey: didShowKey)
    }

    func markShown() {
        UserDefaults.standard.set(true, forKey: didShowKey)
    }

    func requestAllPermissions() async {
        _ = await requestPhotoLibrary()
        _ = await requestCamera()
        _ = await requestNotifications()
    }

    func requestPhotoLibrary() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func requestCamera() async -> AVAuthorizationStatus {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                continuation.resume(returning: status)
            }
        }
    }

    func requestNotifications() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
