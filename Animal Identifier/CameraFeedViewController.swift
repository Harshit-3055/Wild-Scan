import UIKit
import AVFoundation
import Vision

protocol CameraFeedViewControllerDelegate: AnyObject {
    func didUpdatePrediction(_ prediction: String)
}

class CameraFeedViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: CameraFeedViewControllerDelegate?
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentPosition: AVCaptureDevice.Position = .back
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        captureSession.addOutput(output)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        previewLayer.frame = view.frame
        captureSession.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        guard let model = try? Animal(configuration: .init()),
              let input = try? AnimalInput(image: pixelBuffer),
              let prediction = try? model.prediction(input: input) else { return }

        delegate?.didUpdatePrediction(prediction.target)
    }
    
    /// <#Description#>
    func switchCamera() {
        captureSession.stopRunning()
        captureSession.beginConfiguration()
        
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
            captureSession.addInput(currentInput)
            captureSession.commitConfiguration()
            captureSession.startRunning()
            return
        }
        
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
        
        currentPosition = newPosition
    }
}
