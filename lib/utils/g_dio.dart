import 'package:dio/dio.dart';

Dio dio = Dio(
  BaseOptions(
    contentType: Headers.formUrlEncodedContentType,
    validateStatus: (status) => true,
    baseUrl: 'https://pb.inhodev.shop',
  ),
);