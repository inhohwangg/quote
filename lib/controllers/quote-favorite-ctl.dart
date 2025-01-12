import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuoteFavoriteController extends GetxController {
  RxBool isLoading = false.obs;
  RxList favoriteList = [].obs;
  RxInt favoriteIndex = 0.obs;
  RxList<Map> selectedItems = <Map>[].obs;

  void toggleSelection(Map item) {
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
    } else {
      selectedItems.add(item);
    }
  }

  Future<void> deleteSelectedItems() async {
    final prefs = await SharedPreferences.getInstance();

    // 내부 저장소 데이터 가져오기
    final List<String> encodedList =
        prefs.getStringList('favoriteQuotes') ?? [];
    List<dynamic> storedQuotes =
        encodedList.map((item) => jsonDecode(item)).toList();

    // 선택한 항목 삭제하기
    for (var selectedItem in selectedItems) {
      storedQuotes.removeWhere((item) => item['id'] == selectedItem['id']);
    }

    // 변경된 데이터를 다시 인코딩해서 저장
    List<String> newEncodedList =
        storedQuotes.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('favoriteQuotes', newEncodedList);

    // UI 업데이트
    favoriteList.removeWhere((item) => selectedItems.contains(item));
    selectedItems.clear();
    favoriteIndex.value = 0;
  }

  bool isSelected(Map item) {
    return selectedItems.contains(item);
  }

  @override
  void onInit() {
    super.onInit();
    isLoading.value = false;
    if (Get.arguments != null) favoriteList.addAll(Get.arguments['favorite']);
    inspect(favoriteList);
    isLoading.value = true;
  }
}
