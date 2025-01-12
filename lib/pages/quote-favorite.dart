import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:quote/controllers/quote-favorite-ctl.dart';

class QuoteFavoritePage extends GetView<QuoteFavoriteController> {
  QuoteFavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text('즐겨찾기'),
                  Spacer(),
                ],
              ),
              Gap(20),
              controller.isLoading.value
                  ? Expanded(
                      child: ListView.builder(
                        itemCount: controller.favoriteList.length,
                        itemBuilder: (context, index) {
                          Map item = controller.favoriteList[index];
                          return Container(
                            margin: EdgeInsets.only(top: 20),
                            decoration: BoxDecoration(
                                color: Color(0xFF5D7DC5).withOpacity(0.85),
                                borderRadius: BorderRadius.circular(7)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item['author'],
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[200]),
                                    ),
                                    Gap(10),
                                    Text(
                                      item['category'],
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey[300]),
                                    ),
                                  ],
                                ),
                                Gap(10),
                                Text(
                                  item['quote'],
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : Expanded(
                      child: Center(
                      child: CircularProgressIndicator(),
                    ))
            ],
          ),
        ),
      ),
    );
  }
}
