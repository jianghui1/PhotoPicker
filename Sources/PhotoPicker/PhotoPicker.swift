import SwiftUI
import PhotosUI
import Combine
import CombineExtensions

public struct PhotoPicker: UIViewControllerRepresentable {
    
    let configuration: PHPickerConfiguration
    @Binding var isPresented: Bool
    let onImagePicked: ([UIImage]) -> Void
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final public class Coordinator: PHPickerViewControllerDelegate {
        
        private let parent: PhotoPicker
        private var cancellable: AnyCancellable? = nil
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            let loadImage: (NSItemProvider) -> Future<UIImage?, Never> = { provider in
                Future { promise in
                    if provider.canLoadObject(ofClass: UIImage.self) {
                        provider.loadObject(ofClass: UIImage.self) { image, error in
                            if let image = image as? UIImage {
                                DispatchQueue.main.async {
                                    return promise(.success(image))
                                }
                            }
                            else {
                                return promise(.success(nil))
                            }
                        }
                    }
                    else {
                        return promise(.success(nil))
                    }
                }
            }
            cancellable = results.map({ loadImage($0.itemProvider) })
                .combineLatest()
                .sink { [self] images in
                    parent.onImagePicked(images.filter { $0 != nil } as! [UIImage])
                }
        }
    }
}
