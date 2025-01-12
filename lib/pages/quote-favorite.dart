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
          child: Obx(
            () => Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      controller.favoriteIndex.value == 0 ? '즐겨찾기' : '즐겨찾기 수정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                        onPressed: () {
                          controller.favoriteIndex.value == 0
                              ? controller.favoriteIndex.value = 1
                              : controller.favoriteIndex.value = 0;
                        },
                        icon: Icon(Icons.grading))
                  ],
                ),
                Gap(20),
                if (controller.favoriteIndex.value == 0)
                  favoriteView()
                else if (controller.favoriteIndex.value == 1)
                  favoriteModify()
              ],
            ),
          ),
        ),
      ),
    );
  }

  favoriteView() {
    return controller.isLoading.value
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
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
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
                              maxLines: 10,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[300]),
                            ),
                          ],
                        ),
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
          ));
  }

  favoriteModify() {
    return Expanded(
      child: ListView.builder(
        itemCount: controller.favoriteList.length,
        itemBuilder: (context, index) {
          Map item = controller.favoriteList[index];
          return Container(
            margin: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
                color: Color(0xFF5D7DC5).withOpacity(0.85),
                borderRadius: BorderRadius.circular(7)),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(
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
                ),
                Obx(
                  () => IconButton(
                      onPressed: () {
                        controller.toggleSelection(item);
                      },
                      icon: Icon(
                        Icons.task_alt,
                        color: controller.isSelected(item)
                            ? Colors.lightBlue[900]
                            : Colors.grey[300],
                      )),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
