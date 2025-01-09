import 'package:get/get.dart';
import 'package:quote/controllers/quote-board-ctl.dart';
import 'package:quote/controllers/quote-card-ctl.dart';
import 'package:quote/controllers/quote-topic-ctl.dart';
import 'package:quote/pages/quote-board.dart';
import 'package:quote/pages/quote-card.dart';
import 'package:quote/pages/quote-topic.dart';

class AppRouter {
  static List<GetPage> routes = [
    GetPage(
        name: '/',
        page: () => QuoteTopicPage(),
        transition: Transition.cupertino,
        transitionDuration: Duration(milliseconds: 500),
        binding: BindingsBuilder(
          () {
            Get.put(QuoteTopicController());
          },
        )),
    GetPage(
        name: '/card',
        page: () => QuoteCardPage(),
        transition: Transition.cupertino,
        transitionDuration: Duration(milliseconds: 500),
        binding: BindingsBuilder(
          () {
            Get.put(QuoteCardController());
          },
        )),
    GetPage(
        name: '/board',
        page: () => QuoteBoardPage(),
        transition: Transition.cupertino,
        transitionDuration: Duration(milliseconds: 500),
        binding: BindingsBuilder(
          () {
            Get.put(QuoteBoardController());
          },
        )),
  ];
}
