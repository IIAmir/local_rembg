import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_rembg/src/image_type_extension.dart';
import 'package:local_rembg/src/local_rembg_result_model.dart';

class LocalRembg {
  static const MethodChannel _channel = MethodChannel(
    'methodChannel.localRembg',
  );

  /// Removes the background from the specified image file.
  /// Returns a [LocalRembgResultModel] representing the result of the operation.
  /// Throws an error if the provided image path ['.png', '.jpg', '.jpeg', '.heic'] is invalid or unsupported.
  static Future<LocalRembgResultModel> removeBackground({
    required String imagePath,
    bool? cropTheImage = true,
  }) async {
    if (imagePath.typeIsImage) {
      Map<dynamic, dynamic> methodChannelResult = await _channel.invokeMethod(
        'removeBackground',
        {
          'imagePath': imagePath,
          'cropImage': cropTheImage,
        },
      );
      if (kDebugMode) {
        print(methodChannelResult);
      }
      return LocalRembgResultModel.fromMap(
        methodChannelResult,
      );
    } else {
      return LocalRembgResultModel(
        status: 0,
        imageBytes: null,
        errorMessage: 'Invalid image type!',
      );
    }
  }
}
