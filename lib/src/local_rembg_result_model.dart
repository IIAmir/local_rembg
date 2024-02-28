class LocalRembgResultModel {
  final int status;
  final List<int>? imageBytes;
  final String? errorMessage;

  LocalRembgResultModel({
    required this.status,
    required this.imageBytes,
    required this.errorMessage,
  });

  factory LocalRembgResultModel.fromMap(
      Map<dynamic,dynamic> map,
      ) =>
      LocalRembgResultModel(
        status: map['status'],
        imageBytes: (map['imageBytes'] as List<dynamic>?)?.cast<int>(),
        errorMessage: map['errorMessage'],
      );
}
