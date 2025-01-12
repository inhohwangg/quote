import 'dart:convert';
import 'dart:developer';
import 'dart:math';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:get/get.dart';
import 'package:quote/utils/g_dio.dart';
import 'package:quote/utils/g_print.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuoteCardController extends GetxController {
  CarouselSliderController carouselController = CarouselSliderController();
  RxList quoteList = [].obs;
  RxList randomQuotes = [].obs;
  RxList imageList =
      ['bridge', 'cloud', 'door', 'mountain', 'sun', 'tree', 'up'].obs;
  RxBool isLoading = false.obs;
  RxInt cardDotIndex = 0.obs;
  RxMap copyState = {}.obs;
  RxList favoriteQuotes = [].obs;

  @override
  void onInit() {
    super.onInit();
    quoteGet();
    loadInnerData();
  }

  // 즐겨찾기 저장
  Future<void> saveFavoriteQuote(Map item) async {
    final prefs = await SharedPreferences.getInstance();

    favoriteQuotes.add(item);

    List<String> encodedList =
        favoriteQuotes.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('favoriteQuotes', encodedList);
  }

  // 내부 저장소 불러오기
  loadInnerData() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> encodedList =
        prefs.getStringList('favoriteQuotes') ?? [];

    favoriteQuotes.value = encodedList.map((item) => jsonDecode(item)).toList();
    inspect(favoriteQuotes);
  }

  getRandomQuotes() {
    if (quoteList.isEmpty) return;

    final random = Random();

    final Set<int> selectedIndexes = {};

    while (selectedIndexes.length < 5 &&
        selectedIndexes.length < quoteList.length) {
      selectedIndexes.add(random.nextInt(quoteList.length));
    }

    randomQuotes.value = selectedIndexes.map((index) {
      Map<String, dynamic> quote = Map<String, dynamic>.from(quoteList[index]);
      quote['image'] = imageList[random.nextInt(imageList.length)];

      quote['favorite'] = false;

      for (var favoriteQuote in favoriteQuotes) {
        if (quote['id'] == favoriteQuote['id']) {
          quote['favorite'] = true;
          break;
        }
      }

      return quote;
    }).toList();
    inspect(randomQuotes);
  }

  quoteGet() async {
    try {
      quoteList.clear();
      isLoading.value = false;
      var res = await dio.get('/api/collections/quote/records',
          queryParameters: {'page': 1, 'perPage': 300});
      quoteList.addAll(res.data['items']);
      getRandomQuotes();
      isLoading.value = true;
    } catch (e, s) {
      printRed('quoteGet Error Message : $e');
      printRed('quoteGet Error Code Line : $s');
    }
  }
}
