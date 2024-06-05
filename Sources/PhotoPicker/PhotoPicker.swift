import SwiftUI
import PhotosUI
import Combine
import CombineExtensions

public struct PhotoPicker: UIViewControllerRepresentable {
    
    let configuration: PHPickerConfiguration
    let needExif: Bool // 是否需要原始图片(包含位置等exif信息)
    @Binding var isPresented: Bool
    let onImagePicked: ([(UIImage, Data?)]) -> Void
    
    public init(configuration: PHPickerConfiguration, needOriginal: Bool = false, isPresented: Binding<Bool>, onImagePicked: @escaping ([(UIImage, Data?)]) -> Void) {
        self.configuration = configuration
        self.needExif = needOriginal
        self._isPresented = isPresented
        self.onImagePicked = onImagePicked
    }
    
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
            let loadImage: (NSItemProvider) -> Future<(UIImage?, Data?), Never> = { [weak self] provider in
                Future { promise in
                    let asyncPromise: (UIImage?, Data?) -> Void = { image, data in
                        DispatchQueue.main.async {
                            return promise(.success((image, data)))
                        }
                    }
                    if provider.canLoadObject(ofClass: UIImage.self) {
                        provider.loadObject(ofClass: UIImage.self) { image, error in
                            if let image = image as? UIImage {
                                if let self = self {
                                    if self.parent.needExif {
                                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                                            guard let data = data else {
                                                return asyncPromise(image, nil)
                                            }
                                            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                                                if let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                                                    guard let imageData = image.pngData() else {
                                                        return asyncPromise(image, nil)
                                                    }

                                                    let source = CGImageSourceCreateWithData(imageData as CFData, nil)
                                                    let dataWithMetadata = NSMutableData(data: imageData)
                                                    if let source = source, let destination = CGImageDestinationCreateWithData(dataWithMetadata, UTType.png.identifier as CFString, 1, nil) {
                                                        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
                                                        CGImageDestinationFinalize(destination)
                                                        return asyncPromise(image, dataWithMetadata as Data)
                                                    }
                                                }
                                            }
                                            return asyncPromise(image, nil)
                                        }
                                    }
                                    else {
                                        return asyncPromise(image, nil)
                                    }
                                }
                            }
                            else {
                                return asyncPromise(nil, nil)
                            }
                        }
                    }
                    else {
                        return asyncPromise(nil, nil)
                    }
                }
            }
            cancellable = results.map({ loadImage($0.itemProvider) })
                .combineLatest()
                .sink { [self] images in
                    parent.onImagePicked(images.filter { $0.0 != nil } as! [(UIImage, Data?)])
                }
        }
    }
}
