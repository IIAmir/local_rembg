import Flutter
import UIKit
import Vision

@available(iOS 15.0, *)
public class LocalRembgPlugin: NSObject, FlutterPlugin {
    
    private var segmentationRequest: VNGeneratePersonSegmentationRequest?
    let model = DeepLabV3()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "methodChannel.localRembg", binaryMessenger: registrar.messenger())
        let instance = LocalRembgPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest?.qualityLevel = .accurate
        segmentationRequest?.outputPixelFormat = kCVPixelFormatType_OneComponent8
        switch call.method {
        case "removeBackground":
            if(isRunningOnSimulator()){
                result(["status": 0, "message": "Please use a real device"])
                return
            }
            guard let arguments = call.arguments as? [String: Any],
                  let shouldCropImage = arguments["cropImage"] as? Bool else {
                result(["status": 0, "message": "Invalid arguments"])
                return
            }
            
            var image: UIImage?
            
            if let imagePath = arguments["imagePath"] as? String {
                image = UIImage(contentsOfFile: imagePath)
            } else if let defaultImageUint8List = arguments["imageUint8List"] as? FlutterStandardTypedData {
                image = UIImage(data: defaultImageUint8List.data)
            }
            
            guard let loadedImage = image else {
                result(["status": 0, "message": "Unable to load image"])
                return
            }
            
            applyFilter(image: loadedImage, shouldCropImage: shouldCropImage) { [self] resultImage, numFaces in
                guard let resultImage = resultImage else {
                    result(["status": 0, "message": "Unable to process image"])
                    return
                }
                if let imageData = resultImage.pngData() {
                    if numFaces >= 1 {
                        result(["status": 1, "message": "Success", "imageBytes": FlutterStandardTypedData(bytes: imageData)])
                    } else {
                        if let removedBackgroundImage = removeBackground(image: loadedImage) {
                            if let remBgImageData = removedBackgroundImage.pngData() {
                                result(["status": 1, "message": "Success", "imageBytes": remBgImageData])
                            }else{
                                result(["status": 0, "message": "Unable to convert image to bytes"])
                            }
                            
                        } else {
                            result(["status": 0, "message": "Unable to remove background"])
                        }
                    }
                } else {
                    result(["status": 0, "message": "Unable to convert image to bytes"])
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // This function applies a background mask to the given image using Core Image filters.
    // It composites the original image with the mask to produce an image with the background removed.
    private func applyBackgroundMask(_ maskImage: CGImage?, image: UIImage, shouldCropImage: Bool, completion: @escaping (UIImage?, Int) -> Void) {
        guard let maskImage = maskImage, let segmentationRequest = self.segmentationRequest else {
            completion(nil, 0)
            return
        }
        
        let mainImage = CIImage(cgImage: image.cgImage!)
        let originalSize = mainImage.extent.size
        
        var maskCI = CIImage(cgImage: maskImage)
        let scaleX = originalSize.width / maskCI.extent.width
        let scaleY = originalSize.height / maskCI.extent.height
        maskCI = maskCI.transformed(by: .init(scaleX: scaleX, y: scaleY))
        
        DispatchQueue.main.async {
            let filter = CIFilter(name: "CIBlendWithMask")
            filter?.setValue(mainImage, forKey: kCIInputImageKey)
            filter?.setValue(maskCI, forKey: kCIInputMaskImageKey)
            
            if let outputImage = filter?.outputImage {
                let context = CIContext()
                if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    let numFaces = self.countFaces(image: mainImage)
                    let trimmedImage = shouldCropImage ? UIImage(cgImage: cgImage).trimmed() : UIImage(cgImage: cgImage)
                    completion(trimmedImage, numFaces)
                } else {
                    completion(nil, 0)
                }
            }
        }
    }
    
    private func applyFilter(image: UIImage ,shouldCropImage: Bool, completion: @escaping (UIImage?, Int) -> Void) {
        guard let originalCG = image.cgImage, let segmentationRequest = self.segmentationRequest else {
            return completion(nil, 0)
        }
        let fixedImage = fixImageOrientation(image)
        
        let handler = VNImageRequestHandler(cgImage: fixedImage.cgImage!)
        
        do {
            try handler.perform([segmentationRequest])
            
            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return completion(nil, 0)
            }
            
            let maskImage = CGImage.create(pixelBuffer: maskPixelBuffer)
            
            return applyBackgroundMask(maskImage, image: fixedImage,shouldCropImage: shouldCropImage, completion: completion)
        } catch {
            return completion(nil, 0)
        }
    }
    
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let fixedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return fixedImage ?? image
    }
    
    private func countFaces(image: CIImage) -> Int {
        let request = VNDetectFaceRectanglesRequest()
        let requestHandler = VNImageRequestHandler(ciImage: image)
        do {
            try requestHandler.perform([request])
            if let results = request.results {
                return results.count
            }
        } catch {
            print("Unable to perform face detection: \(error).")
        }
        return 0
    }
    
    private func isRunningOnSimulator() -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }
    
    private func removeBackground(image: UIImage) -> UIImage? {
        let resizedImage = image.resized(to: CGSize(width: 513, height: 513))
        if let pixelBuffer = resizedImage.pixelBuffer(width: Int(resizedImage.size.width), height: Int(resizedImage.size.height)){
            if let outputImage = (try? model.prediction(image: pixelBuffer))?.semanticPredictions.image(min: 0, max: 1, axes: (0,0,1)), let outputCIImage = CIImage(image: outputImage){
                if let maskImage = removeWhitePixels(image: outputCIImage), let resizedCIImage = CIImage(image: resizedImage), let compositedImage = composite(image: resizedCIImage, mask: maskImage){
                    let finalImage = UIImage(ciImage: compositedImage).resized(to: CGSize(width: image.size.width, height: image.size.height))
                    
                    return finalImage
                }
            }
        }
        return nil
    }
    private func removeWhitePixels(image: CIImage) -> CIImage? {
        let chromaCIFilter = chromaKeyFilter()
        chromaCIFilter?.setValue(image, forKey: kCIInputImageKey)
        return chromaCIFilter?.outputImage
    }
    
    private func composite(image: CIImage, mask: CIImage) -> CIImage? {
        return CIFilter(name:"CISourceOutCompositing", parameters:
                            [kCIInputImageKey: image,kCIInputBackgroundImageKey: mask])?.outputImage
    }
    
    private func chromaKeyFilter() -> CIFilter? {
        let size = 64
        var cubeRGB = [Float]()
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size-1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size-1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size-1)
                    let brightness = getBrightness(red: red, green: green, blue: blue)
                    let alpha: CGFloat = brightness == 1 ? 0 : 1
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }
        let data = Data(buffer: UnsafeBufferPointer(start: &cubeRGB, count: cubeRGB.count))
        let colorCubeFilter = CIFilter(name: "CIColorCube", parameters: ["inputCubeDimension": size, "inputCubeData": data])
        return colorCubeFilter
    }
    
    private func getBrightness(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var brightness: CGFloat = 0
        color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }
}

extension UIImage {
    
    func trimmed() -> UIImage {
        let newRect = cropRect()
        if let imageRef = cgImage?.cropping(to: newRect) {
            return UIImage(cgImage: imageRef)
        }
        return self
    }
    
    private func cropRect() -> CGRect {
        let cgImage = self.cgImage!
        
        let bitmapBytesPerRow = cgImage.width * 4
        let bitmapByteCount = bitmapBytesPerRow * cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapData = malloc(bitmapByteCount)
        
        if bitmapData == nil {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        guard let context = CGContext(
            data: bitmapData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bitmapBytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        let height = cgImage.height
        let width = cgImage.width
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(rect)
        context.draw(cgImage, in: rect)
        
        guard let data = context.data else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        var lowX = width
        var lowY = height
        var highX: Int = 0
        var highY: Int = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (width * y + x) * 4
                let color = data.load(fromByteOffset: pixelIndex, as: UInt32.self)
                
                if color != 0 {
                    if x < lowX {
                        lowX = x
                    }
                    if x > highX {
                        highX = x
                    }
                    if y < lowY {
                        lowY = y
                    }
                    if y > highY {
                        highY = y
                    }
                }
            }
        }
        
        return CGRect(x: lowX, y: lowY, width: highX - lowX, height: highY - lowY)
    }
}
