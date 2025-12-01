import 'device_screenshot_platform_interface.dart';

class DeviceScreenshot {
  DeviceScreenshot._();

  static final DeviceScreenshot instance = DeviceScreenshot._();

  Future<bool> checkMediaProjectionService() {
    return DeviceScreenshotPlatform.instance.checkMediaProjectionService();
  }

  Future<Uri?> takeScreenshot({
    Duration delay = Duration.zero,
  }) {
    return DeviceScreenshotPlatform.instance.takeScreenshot(delay: delay);
  }

  void requestMediaProjection() {
    DeviceScreenshotPlatform.instance.requestMediaProjection();
  }

  void stopMediaProjectionService() {
    DeviceScreenshotPlatform.instance.stopMediaProjectionService();
  }
}
