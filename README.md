# Local Background Remover (Android/IOS)

<img src="https://file.io/42mdIzLQYQhG"/>

## Overview

The Background Removal Library is a powerful tool designed to seamlessly remove backgrounds from
images in both Android and iOS platforms.This library provides developers with an easy-to-use
interface to integrate background removal functionality into their mobile applications, enhancing
user experience and enabling a wide range of creative possibilities.

## System requirements

- iOS: 15
- Android: 4.4 (SDK 19)

## Features

- Offline Support: Perform background removal tasks without internet, ensuring fast performance in
  offline mode.
- Cross-Platform: Remove backgrounds from images on both Android and iOS platforms.

## Getting started

Add the plugin package to the `pubspec.yaml` file in your project:

```yaml
dependencies:
  local_rembg: ^0.0.2
```

Install the new dependency:

```sh
flutter pub get
```

Call the `removeBackground` function in your code:

```dart
Future<LocalRembgResultModel> removeBackground() async {
  LocalRembgResultModel localRembgResultModel = await LocalRembg.removeBackground(
      imagePath: // Your Image Path,
  );
}
```

## Example

Explore our [example project](./example) to see how the Local Rembg SDK can be used in a Flutter
application.

## License Terms
This library is provided under the [Apache License](LICENSE).