import Flutter
import UIKit
import Vision

@available(iOS 15.0, *)
public class LocalRembgPlugin: NSObject, FlutterPlugin {

    private var segmentationRequest: VNGeneratePersonSegmentationRequest?

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
                  let imagePath = arguments["imagePath"] as? String,
                  let shouldCropImage = arguments["cropImage"] as? Bool,
                  let image = UIImage(contentsOfFile: imagePath) else {
                result(["status": 0, "message": "Invalid arguments or unable to load image"])
                return
            }
            applyFilter(image: image, shouldCropImage: shouldCropImage) { resultImage, numFaces in
                guard let resultImage = resultImage else {
                    result(["status": 0, "message": "Unable to process image"])
                    return
                }
                if let imageData = resultImage.pngData() {
                    if numFaces >= 1 {
                        result(["status": 1, "message": "Success", "imageBytes": FlutterStandardTypedData(bytes: imageData)])
                    }else{
                        result(["status": 0, "message": "No person detected in the provided image. Please try with a different image."])
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

        let requiredSize: CGFloat = 600.0

        if image.size.width < requiredSize || image.size.height < requiredSize {
            completion(nil, 0)
            return
        }

        let newWidth: CGFloat = 600.0
        let newHeight: CGFloat = 600.0

        let resizedImage = resizeImage(image: image, targetSize: CGSize(width: newWidth, height: newHeight))

        let handler = VNImageRequestHandler(cgImage: resizedImage.cgImage!)

        do {
            try handler.perform([segmentationRequest])

            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return completion(nil, 0)
            }

            let maskImage = CGImage.create(pixelBuffer: maskPixelBuffer)

            return applyBackgroundMask(maskImage, image: resizedImage,shouldCropImage: shouldCropImage, completion: completion)
        } catch {
            return completion(nil, 0)
        }
    }

    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let scaleFactor = min(widthRatio, heightRatio)

        let scaledWidth  = size.width * scaleFactor
        let scaledHeight = size.height * scaleFactor

        UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? UIImage()
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
