//
// The app's one URL handler: Meta AI app callbacks (same pattern as Meta’s CameraAccess sample)
// and Supabase password-reset links. One handler, so each URL is routed exactly once.
//

import MWDATCore
import SwiftUI

struct RegistrationView: View {
    let viewModel: WearablesViewModel
    /// Passed in: this view sits in an overlay, outside the `.environment(app)` it is attached next to.
    let app: AppModel

    var body: some View {
        // A real (invisible, untouchable) view: handlers on EmptyView aren't guaranteed to be installed.
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onOpenURL { url in
                if Backend.isPasswordResetLink(url) {
                    Task { await app.openPasswordResetLink(url) }
                    return
                }
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
                else { return }
                Task {
                    do {
                        // Finishes an approval NutraVision started. One started from inside Meta AI (the user
                        // picked NutraVision there) arrives as a request; going ahead is what they asked for.
                        _ = try await Wearables.shared.handleUrl(url) { request in
                            Task {
                                do { try await request.continueRegistration() } catch {
                                    await MainActor.run {
                                        viewModel.presentError("Couldn't finish connecting to Meta AI (\(String(describing: error))). Try Glasses setup again.")
                                    }
                                }
                            }
                        }
                    } catch {
                        viewModel.presentError("Meta AI's reply couldn't be read (\(String(describing: error))). Try Glasses setup again.")
                    }
                }
            }
    }
}
