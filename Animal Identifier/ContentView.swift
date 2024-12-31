import SwiftUI

struct ContentView: View {
    @State private var prediction: String = "Analyzing..."
    @State private var cameraViewController: CameraFeedViewController?
    @State private var isShowingImagePicker = false
    @State private var isShowingAnalysis = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        ZStack {
            CameraFeedView(prediction: $prediction, onViewControllerCreated: { controller in
                DispatchQueue.main.async {
                    self.cameraViewController = controller
                }
            })
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("DETECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(prediction)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                
                HStack(spacing: 30) {
                    Button(action: {
                        isShowingImagePicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Button(action: {
                        if let controller = cameraViewController {
                            controller.switchCamera()
                        }
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage) { image in
                selectedImage = image
                isShowingImagePicker = false
                isShowingAnalysis = true
            }
        }
        .sheet(isPresented: $isShowingAnalysis) {
            if let image = selectedImage {
                ImageAnalysisView(image: image)
            }
        }
    }
}

struct ImageAnalysisView: View {
    let image: UIImage
    @State private var prediction: String = "Analyzing..."
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                    .cornerRadius(12)
                    .padding()
                
                VStack(spacing: 8) {
                    Text("DETECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(prediction)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            analyzeImage(image)
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        guard let buffer = image.toCVPixelBuffer() else { return }
        
        guard let model = try? Animal(configuration: .init()),
              let input = try? AnimalInput(image: buffer),
              let prediction = try? model.prediction(input: input) else { return }
        
        self.prediction = prediction.target
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = 299
        let height = 299
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       width,
                                       height,
                                       kCVPixelFormatType_32ARGB,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}
