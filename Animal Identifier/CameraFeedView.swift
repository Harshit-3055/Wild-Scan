import SwiftUI
import AVFoundation
import Vision

struct CameraFeedView: UIViewControllerRepresentable {
    @Binding var prediction: String
    var onViewControllerCreated: ((CameraFeedViewController) -> Void)?

    func makeUIViewController(context: Context) -> CameraFeedViewController {
        let controller = CameraFeedViewController()
        controller.delegate = context.coordinator
        DispatchQueue.main.async {
            self.onViewControllerCreated?(controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraFeedViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraFeedViewControllerDelegate {
        var parent: CameraFeedView

        init(_ parent: CameraFeedView) {
            self.parent = parent
        }

        func didUpdatePrediction(_ prediction: String) {
            DispatchQueue.main.async {
                self.parent.prediction = prediction
            }
        }
    }
}
