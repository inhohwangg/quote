import 'dart:developer';

import 'package:get/get.dart';

class QuoteFavoriteController extends GetxController {
  RxBool isLoading = false.obs;
  RxList favoriteList = [].obs;

  @override
  void onInit() {
    super.onInit();
    isLoading.value = false;
    if (Get.arguments != null) favoriteList.addAll(Get.arguments['favorite']);
    inspect(favoriteList);
    isLoading.value = true;
  }
}
