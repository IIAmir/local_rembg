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
            guard let imagePath = call.arguments as? String,
                  let image = UIImage(contentsOfFile: imagePath) else {
                result(["status": 0, "message": "Invalid arguments or unable to load image"])
                return
            }
            applyFilter(image: image) { resultImage in
                guard let resultImage = resultImage else {
                    result(["status": 0, "message": "Unable to process image"])
                    return
                }
                if let imageData = resultImage.pngData() {
                    result(["status": 1, "message":"Success","imageBytes": FlutterStandardTypedData(bytes: imageData)])
                } else {
                    result(["status": 0, "message": "Unable to convert image to bytes"])
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func applyFilter(image: UIImage ,completion: @escaping (UIImage?) -> Void) {
        guard let originalCG = image.cgImage, let segmentationRequest = self.segmentationRequest else {
            return completion(nil)
        }

        let requiredSize: CGFloat = 600.0

        if image.size.width < requiredSize || image.size.height < requiredSize {
            completion(nil)
            return
        }

        let newWidth: CGFloat = 600.0
        let newHeight: CGFloat = 600.0

        let resizedImage = resizeImage(image: image, targetSize: CGSize(width: newWidth, height: newHeight))

        let handler = VNImageRequestHandler(cgImage: resizedImage.cgImage!)

        do {
            try handler.perform([segmentationRequest])

            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return completion(nil)
            }

            let maskImage = CGImage.create(pixelBuffer: maskPixelBuffer)

            return applyBackgroundMask(maskImage, image: resizedImage, completion: completion)
        } catch {
            return completion(nil)
        }
    }

    // This function applies a background mask to the given image using Core Image filters.
    // It composites the original image with the mask to produce an image with the background removed.
    private func applyBackgroundMask(_ maskImage: CGImage?, image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let maskImage = maskImage, let segmentationRequest = self.segmentationRequest else {
            completion(nil)
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
                let blendedImage = UIImage(ciImage: outputImage)
                completion(blendedImage)
            } else {
                completion(nil)
            }
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
}
