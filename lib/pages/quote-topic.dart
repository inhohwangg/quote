import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:quote/controllers/quote-topic-ctl.dart';
import 'package:quote/main.dart';
import 'package:quote/utils/g_print.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QuoteTopicPage extends GetView<QuoteTopicController> {
  QuoteTopicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Spacer(),
            Text(
              '주제를 선택해주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(), // 애니메이션 반복 설정
                )
                .shimmer(
                  // 반짝임 효과
                  duration: 5000.ms,
                  color: Colors.white.withOpacity(0.8),
                  size: 3,
                ),
            Gap(20),
            Obx(
              () => CarouselSlider(
                carouselController: controller.carouselController,
                options: CarouselOptions(
                  aspectRatio: 16 / 9,
                  height: 250.0,
                  autoPlay: controller.isAutoPlay.value,
                  autoPlayCurve: Curves.easeInOutQuart,
                  autoPlayAnimationDuration: Duration(seconds: 2),
                  autoPlayInterval: Duration(seconds: 5),
                  pauseAutoPlayInFiniteScroll: true,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.3,
                  onPageChanged: (index, reason) {
                    if (reason == CarouselPageChangedReason.manual) {
                      controller.isAutoPlay.value = false;
                    }
                  },
                ),
                items: controller.topicList.map((i) {
                  return Builder(
                    builder: (BuildContext context) {
                      return GestureDetector(
                        onTap: () {
                          controller.stopAutoPlay();
                          controller.selectedIndex.value =
                              controller.topicList.indexOf(i);
                          printCyan(controller.selectedIndex.value);
                          printRed(controller.topicList.indexOf(i));

                          controller.carouselController.animateToPage(
                              controller.topicList.indexOf(i),
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut);
                          getStorage.write('topic', i['name']);
                          printCyan(controller.topicValue.value);
                        },
                        child: Obx(
                          () => Container(
                            width: MediaQuery.of(context).size.width,
                            margin: EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                                border: controller.selectedIndex.value ==
                                        controller.topicList.indexOf(i)
                                    ? Border.all(
                                        color: Color(0xFF5D7DC5), width: 3)
                                    : null,
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    LottieBuilder.asset(
                                      i['image'],
                                      width: 200,
                                      height: 200,
                                    ),
                                    Gap(10),
                                    Text(
                                      i['name'],
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Gap(10)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                style: ButtonStyle(
                    padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 10)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    overlayColor: WidgetStatePropertyAll(Color(0xFF9BB1DE)),
                    backgroundColor: WidgetStatePropertyAll(Color(0xFF5D7DC5))),
                onPressed: () {
                  Get.toNamed('/card',
                      arguments: {'topic': controller.topicValue.value});
                },
                child: Center(
                  child: Text(
                    '다음',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ),
            Gap(30)
          ],
        ),
      ),
    );
  }
}
