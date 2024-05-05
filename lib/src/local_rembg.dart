import 'dart:io';

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
  /// [imagePath] Throws an error if the provided image path ['.png', '.jpg', '.jpeg', '.heic'] is invalid or unsupported.
  /// [imageUint8List] (Requires iOS platform).
  /// [cropTheImage] Specifies whether to crop the segmented image after removing the background.
  /// If set to `true`, the segmented image will be cropped to remove any transparent or empty areas.
  /// If set to `false`, the segmented image will be returned without any cropping.
  static Future<LocalRembgResultModel> removeBackground({
    String? imagePath,
    Uint8List? imageUint8List,
    bool? cropTheImage = true,
  }) async {
    if (imagePath == null && imageUint8List == null) {
      return LocalRembgResultModel(
        status: 0,
        imageBytes: null,
        errorMessage:
            "You must provide either 'imagePath' or 'imageUint8List'.",
      );
    }

    if (imagePath != null && !imagePath.typeIsImage) {
      return LocalRembgResultModel(
        status: 0,
        imageBytes: null,
        errorMessage: 'Invalid image type!',
      );
    }

    if (Platform.isAndroid && imageUint8List != null) {
      return LocalRembgResultModel(
        status: 0,
        imageBytes: null,
        errorMessage: 'imageUint8List is supported only on iOS platform.',
      );
    }

    Map<dynamic, dynamic> methodChannelResult = await _channel.invokeMethod(
      'removeBackground',
      {
        'imagePath': imagePath,
        'imageUint8List': imageUint8List,
        'cropImage': cropTheImage,
      },
    );
    if (kDebugMode) {
      print(methodChannelResult);
    }
    return LocalRembgResultModel.fromMap(
      methodChannelResult,
    );
  }
}
