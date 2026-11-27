import MWDATCore
import SwiftUI

/// Step-by-step setup for Meta glasses: pairing the glasses with the phone isn't enough, NutraVision itself must be
/// approved in Meta AI (Developer Mode, then approve, then the camera). Each step shows its live state.
/// Used before Glasses Mode starts, from its "Glasses setup" button, and in More › Glasses.
struct GlassesSetupView: View {
    /// The main button once NutraVision is approved ("Start Glasses Mode"); nil hides it.
    var finishTitle: String? = nil
    var onFinish: (() -> Void)? = nil
    /// More › Glasses offers disconnecting too.
    var showsDisconnect = false

    @Environment(WearablesViewModel.self) private var wearables
    @Environment(\.scenePhase) private var scenePhase

    private var approved: Bool { wearables.registrationState == .registered }
    private var cameraAllowed: Bool { wearables.cameraPermission == .granted }

    var body: some View {
        @Bindable var wearables = wearables
        List {
            Section {
                Text("Pairing your glasses with Bluetooth and the Meta AI app isn't enough: NutraVision also needs Meta AI's approval to use their camera. You only do this once.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if wearables.registrationState == .unavailable {
                    Label("Meta glasses aren't available right now. Make sure the Meta AI app is installed, then reopen NutraVision.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.moderation)
                }
            }

            step(1, "Glasses connected in Meta AI", done: !wearables.devices.isEmpty) {
                Text("Open the **Meta AI** app and check your glasses show as **Connected**. Take them out of the case, unfold them, and keep them charged above 10%.")
            }

            step(2, "Developer Mode on in Meta AI", done: approved) {
                Text("In **Meta AI**: **Settings › App Info**, tap the **App version** number **5 times**, turn on **Developer Mode**, then tap **Enable**.")
                Text("NutraVision is a test app, so Meta AI only lets it connect in Developer Mode.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            step(3, "Approve NutraVision", done: approved) {
                Text("Meta AI opens: approve NutraVision there and you'll come straight back here.")
                if approved {
                    Label("Approved", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                } else {
                    Button {
                        wearables.connectGlasses()
                    } label: {
                        if wearables.registrationState == .registering {
                            HStack { ProgressView(); Text("Waiting for Meta AI\u{2026}") }
                        } else {
                            Label("Open Meta AI to approve", systemImage: "arrow.up.forward.app")
                        }
                    }
                    .disabled(wearables.registrationState == .registering || wearables.registrationState == .unavailable)
                }
                Text("Only one Developer Mode app can be connected at a time; approving NutraVision replaces any other.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            step(4, "Allow the glasses camera", done: cameraAllowed) {
                Text("Meta AI asks once: choose **Allow always**.")
                if cameraAllowed {
                    Label("Camera allowed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                } else {
                    Button {
                        Task { await wearables.requestWearableCameraPermission() }
                    } label: {
                        Label("Allow camera in Meta AI", systemImage: "camera")
                    }
                    .disabled(!approved)
                }
            }

            if !wearables.devices.isEmpty {
                Section("Your glasses") {
                    ForEach(wearables.devices, id: \.self) { id in
                        Label(Wearables.shared.deviceForIdentifier(id)?.nameOrId() ?? id, systemImage: "eyeglasses")
                    }
                }
            }

            if let finishTitle, let onFinish {
                Section {
                    Button { onFinish() } label: {
                        Text(finishTitle).font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!approved)
                } footer: {
                    if !approved { Text("Available once NutraVision is approved (step 3).") }
                }
            }
            if showsDisconnect && approved {
                Section {
                    Button("Disconnect NutraVision from Meta AI", role: .destructive) { wearables.disconnectGlasses() }
                } footer: {
                    Text("You can also remove it in Meta AI › Settings › App connections › Developer mode apps.")
                }
            }
        }
        .navigationTitle("Glasses setup")
        .alert("Glasses", isPresented: $wearables.isErrorPresented) {
            Button("OK") { wearables.dismissError() }
        } message: {
            Text(wearables.errorMessage)
        }
        .task { await wearables.refreshCameraPermission() }
        // Coming back from Meta AI: re-read what changed there.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await wearables.refreshCameraPermission() } }
        }
        .onChange(of: wearables.registrationState) { _, _ in
            Task { await wearables.refreshCameraPermission() }
        }
    }

    private func step<Content: View>(_ number: Int, _ title: String, done: Bool,
                                     @ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        } header: {
            HStack(spacing: 6) {
                Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                    .foregroundStyle(done ? Theme.accent : .secondary)
                Text(title)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(number): \(title)\(done ? ", done" : "")")
        }
    }
}
