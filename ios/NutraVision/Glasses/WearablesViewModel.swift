//
// DAT registration, device list, and wearable camera permission (required for devices to appear).
//

import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class WearablesViewModel {
    private(set) var devices: [DeviceIdentifier] = []
    private(set) var registrationState: RegistrationState
    /// The glasses camera permission for NutraVision; nil until checked or while no glasses are reachable.
    private(set) var cameraPermission: PermissionStatus?
    var isErrorPresented: Bool = false
    var errorMessage: String = ""

    private let wearables: WearablesInterface
    @ObservationIgnored private var registrationTask: Task<Void, Never>?
    @ObservationIgnored private var deviceStreamTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.registrationState = wearables.registrationState
        self.devices = wearables.devices

        registrationTask = Task {
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }

        deviceStreamTask = Task {
            for await list in wearables.devicesStream() {
                self.devices = list
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    func connectGlasses() {
        guard registrationState != .registering else { return }
        Task {
            do {
                try await wearables.startRegistration()  // opens Meta AI; handleUrl finishes it on the way back
            } catch let error as RegistrationError {
                // Already registered: nothing to do, the state stream reports .registered.
                if error != .alreadyRegistered { presentError(Self.message(for: error)) }
            } catch {
                presentError("Couldn't connect to Meta AI (\(error.localizedDescription)). Try again.")
            }
        }
    }

    func disconnectGlasses() {
        Task {
            do {
                try await wearables.startUnregistration()
            } catch let error as UnregistrationError {
                presentError(error.description)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    /// Meta documents that `devicesStream` may stay empty until at least one wearable permission (e.g. camera) is granted via Meta AI.
    func requestWearableCameraPermission() async {
        let permission = Permission.camera
        do {
            var status = try await wearables.checkPermissionStatus(permission)
            if status != .granted { status = try await wearables.requestPermission(permission) }  // opens Meta AI
            cameraPermission = status
        } catch {
            cameraPermission = nil
            presentError("Meta AI can't reach your glasses to ask for the camera. Unfold them, check they show as connected in Meta AI, then try again.")
        }
    }

    /// Re-reads the camera permission (for the setup checklist); quiet when the glasses aren't reachable.
    func refreshCameraPermission() async {
        guard registrationState == .registered else { cameraPermission = nil; return }
        cameraPermission = try? await wearables.checkPermissionStatus(.camera)
    }

    /// What to do about a failed approval, in the user's terms.
    static func message(for error: RegistrationError) -> String {
        switch error {
        case .metaAINotInstalled:
            return "The Meta AI app isn't installed. Install it from the App Store, pair your glasses in it, then try again."
        case .unauthorized:
            return "Meta AI didn't allow NutraVision to connect. Turn on Developer Mode in Meta AI (step 2), then tap Open Meta AI again."
        case .networkUnavailable:
            return "No internet connection. Connect to Wi-Fi or mobile data and try again."
        case .configurationInvalid:
            return "NutraVision's Meta glasses settings are invalid (MWDAT in Info.plist), so Meta AI refused it. This needs a fix in the app."
        default:
            return "Couldn't connect to Meta AI (\(error.description)). Try again."
        }
    }

    func presentError(_ message: String) {
        errorMessage = message
        isErrorPresented = true
    }

    func dismissError() {
        isErrorPresented = false
    }
}
