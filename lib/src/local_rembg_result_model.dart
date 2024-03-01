class LocalRembgResultModel {
  /// The [status] property indicates the outcome of the operation:
  /// - 1 for success
  /// - 0 for failure
  /// The [imageBytes] property contains the bytes of the resulting image after background removal.
  /// The [errorMessage] property holds an error message in case the operation failed.
  final int status;
  final List<int>? imageBytes;
  final String? errorMessage;

  LocalRembgResultModel({
    required this.status,
    required this.imageBytes,
    required this.errorMessage,
  });

  factory LocalRembgResultModel.fromMap(
    Map<dynamic, dynamic> result,
  ) =>
      LocalRembgResultModel(
        status: result['status'],
        imageBytes: (result['imageBytes'] as List<dynamic>?)?.cast<int>(),
        errorMessage: result['message'],
      );
}
