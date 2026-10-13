import 'package:get/get.dart';
import '../controllers/prayer_controller.dart';

class PrayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PrayerController());
  }
}
