import 'dart:developer';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:quote/controllers/quote-card-ctl.dart';

class QuoteCardPage extends GetView<QuoteCardController> {
  QuoteCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 30),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      controller.loadInnerData();
                    },
                    child: Text(
                      '오늘의 글',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () {
                      Get.toNamed('/favorite',
                          arguments: {'favorite': controller.favoriteQuotes});
                    },
                    child: Icon(
                      Icons.star,
                      color: Colors.yellow[700],
                    ),
                  ),
                  Gap(20),
                  GestureDetector(
                    onTap: () {
                      controller.quoteGet();
                    },
                    child: Icon(Icons.refresh),
                  ),
                ],
              ),
              Spacer(),
              Obx(
                () => controller.isLoading.value
                    ? Expanded(
                        flex: 6,
                        child: CarouselSlider.builder(
                            itemCount: controller.randomQuotes.length,
                            itemBuilder: (context, index, realIndex) {
                              Map item = controller.randomQuotes[index];
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                                image: DecorationImage(
                                                    image: AssetImage(
                                                        'assets/images/${item['image']}.png'),
                                                    fit: BoxFit.cover),
                                                color: Color(0xFFD9D9D9),
                                                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                                boxShadow: [
                                                  BoxShadow(
                                                      offset: Offset(0, 4),
                                                      blurRadius: 1,
                                                      color: Colors.grey)
                                                ]),
                                          ),
                                          Positioned(
                                            top: 15,
                                            right: 15,
                                            child: GestureDetector(
                                              onTap: () async {
                                                controller
                                                    .saveFavoriteQuote(item);
                                              },
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50)),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.star,
                                                    color: item['favorite']
                                                        ? Colors.yellow[700]
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () => Positioned(
                                              top: 55,
                                              right: 15,
                                              child: GestureDetector(
                                                onTap: () async {
                                                  await Clipboard.setData(
                                                      ClipboardData(
                                                          text: item['quote']));
                                                  controller.copyState[
                                                      item['id']] = true;

                                                  Future.delayed(
                                                      Duration(seconds: 5), () {
                                                    controller.copyState[
                                                        item['id']] = false;
                                                  });
                                                },
                                                child: Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              50)),
                                                  child: Center(
                                                    child: FaIcon(
                                                      (controller.copyState[
                                                                  controller.randomQuotes[
                                                                          index]
                                                                      ['id']] ??
                                                              false)
                                                          ? FontAwesomeIcons
                                                              .solidCopy
                                                          : FontAwesomeIcons
                                                              .copy,
                                                      size: 15,
                                                      color: (controller.copyState[
                                                                  controller.randomQuotes[
                                                                          index]
                                                                      ['id']] ??
                                                              false)
                                                          ? Colors.blue[700]
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 20),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(10),
                                                bottomRight:
                                                    Radius.circular(10)),
                                            boxShadow: [
                                              BoxShadow(
                                                  offset: Offset(0, 4),
                                                  blurRadius: 1,
                                                  color: Colors.grey)
                                            ]),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 5),
                                              decoration: BoxDecoration(
                                                  // color: Color(0xFFD9D9D9),
                                                  ),
                                              child: Text(
                                                item['author'],
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                            Gap(20),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 15, vertical: 15),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                color: Color.fromARGB(
                                                    255, 97, 206, 106),
                                              ),
                                              child: Text(
                                                item['quote'],
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                            options: CarouselOptions(
                              aspectRatio: 16 / 9,
                              height: 500,
                              viewportFraction: 1,
                              enlargeFactor: 0.3,
                              onPageChanged: (index, reason) {
                                controller.cardDotIndex.value = index;
                              },
                            )),
                      )
                    : Expanded(
                        child: Center(
                        child: CircularProgressIndicator(),
                      )),
              ),
              Gap(20),
              Obx(
                () => controller.isLoading.value
                    ? DotsIndicator(
                        dotsCount: controller.randomQuotes.length,
                        position: controller.cardDotIndex.value,
                        decorator: DotsDecorator(
                            color: Colors.grey,
                            activeColor: Colors.black87,
                            size: Size(5, 5),
                            activeSize: Size(7, 7)),
                      )
                    : SizedBox(),
              )
            ],
          ),
        ),
      ),
    );
  }
}
