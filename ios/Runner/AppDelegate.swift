import Flutter
import UIKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.daanser.transprism/gallery_saver",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "saveImage" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
          result(FlutterError(code: "INVALID_ARG", message: "filePath is required", details: nil))
          return
        }
        self?.saveImageToGallery(filePath: filePath, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func saveImageToGallery(filePath: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: filePath) else {
      result(FlutterError(code: "READ_FAILED", message: "Failed to read image from file", details: nil))
      return
    }
    
    PHPhotoLibrary.requestAuthorization { status in
      if status == .authorized || status == .limited {
        PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
          if success {
            result(true)
          } else {
            result(FlutterError(
              code: "SAVE_FAILED",
              message: error?.localizedDescription ?? "Unknown error",
              details: nil
            ))
          }
        }
      } else {
        result(FlutterError(code: "NO_PERMISSION", message: "Photo library access denied", details: nil))
      }
    }
  }
}
