import AVFoundation
import SwiftUI
import UIKit
import Vision
import VisionKit

/// Live barcode scanner; calls `onCode` once with the first payload.
struct BarcodeScanSheet: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    /// `DataScannerViewController.isAvailable` stays false until camera access is granted, and nothing else
    /// on this path asks for it, so the sheet asks itself.
    @State private var cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                if !DataScannerViewController.isSupported {
                    message("Barcode scanning isn't supported on this device")
                } else if cameraAccess == .notDetermined {
                    ProgressView()
                        .task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
                        }
                } else if cameraAccess != .authorized || !DataScannerViewController.isAvailable {
                    VStack(spacing: 12) {
                        message("Camera access is needed to scan barcodes.")
                        if cameraAccess == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                            Button("Open Settings") { UIApplication.shared.open(url) }.buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    ScannerView { code in
                        onCode(code)
                        dismiss()
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary).padding()
    }
}

private struct ScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])],
            qualityLevel: .balanced, recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true,
            isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !done else { return }
            for case .barcode(let barcode) in addedItems {
                if let payload = barcode.payloadStringValue {
                    done = true
                    dataScanner.stopScanning()
                    onCode(payload)
                    return
                }
            }
        }
    }
}
