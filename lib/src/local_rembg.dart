import 'package:flutter/services.dart';
import 'package:local_rembg/src/local_rembg_result_model.dart';

class LocalRembg {
  static const MethodChannel _channel = MethodChannel(
    'methodChannel.localRembg',
  );

  static Future<LocalRembgResultModel> removeBackground({
    required String imagePath,
  }) async =>
      LocalRembgResultModel.fromMap(
        await _channel.invokeMethod(
          'removeBackground',
          imagePath,
        ),
      );
}
