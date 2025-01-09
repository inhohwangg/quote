import 'package:carousel_slider/carousel_slider.dart';
import 'package:get/get.dart';

class QuoteTopicController extends GetxController{
  CarouselSliderController carouselController = CarouselSliderController();
  RxList topicList = [{'image':'assets/images/Disney.json', 'name': '디즈니'},{'image':'assets/images/grow.json','name':'성장'},{'image':'assets/images/life.json','name':'삶'},{'image':'assets/images/success.json','name':'성공'},].obs;
  RxBool isAutoPlay = true.obs;
  RxString topicValue = ''.obs;
  RxInt selectedIndex = (-1).obs;

  @override
  void onInit() {
    super.onInit();
    isAutoPlay.value = true;
  }

  void stopAutoPlay() {
    isAutoPlay.value = false;
    update();
  }
}