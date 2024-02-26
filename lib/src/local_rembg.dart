import 'package:flutter/services.dart';

class LocalRembg {
  static const MethodChannel _channel = MethodChannel(
    'methodChannel.localRembg',
  );

  static Future<dynamic> removeBackground({
    required String imagePath,
  }) async =>
      await _channel.invokeMethod(
        'removeBackground',
        imagePath,
      );
}
