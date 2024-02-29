extension ImageTypeExtension on String {
  bool get typeIsImage => ['.png', '.jpg', '.jpeg', '.heic'].any(
        (ext) => toLowerCase().endsWith(ext),
      );
}
