import 'dart:convert';

import 'package:dio/dio.dart';

class CurlLoggerInfo {
  final RequestOptions requestOptions;
  final String? curl;
  final DateTime time;

  CurlLoggerInfo({
    required this.requestOptions,
    required this.curl,
    required this.time,
  });
}

class CurlLoggerDioInterceptor extends Interceptor {
  final bool printOnSuccess;
  final bool convertFormData;
  final List<CurlLoggerInfo> infoList = [];

  final void Function(
    List<CurlLoggerInfo> infoList,
  )? onLog;

  CurlLoggerDioInterceptor({
    this.printOnSuccess = false,
    this.convertFormData = true,
    this.onLog,
  });

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    _renderCurlRepresentation(err.requestOptions);

    /// continue
    return handler.next(err);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (printOnSuccess) {
      _renderCurlRepresentation(response.requestOptions);
    }

    /// continue
    return handler.next(response);
  }

  void _renderCurlRepresentation(RequestOptions requestOptions) {
    if (onLog == null) {
      return;
    }

    /// add a breakpoint here so all errors can break
    try {
      String curl = _cURLRepresentation(requestOptions);
      infoList.add(
        CurlLoggerInfo(
          requestOptions: requestOptions,
          curl: curl,
          time: DateTime.now(),
        ),
      );
    } catch (err) {
      infoList.add(
        CurlLoggerInfo(
          requestOptions: requestOptions,
          curl: null,
          time: DateTime.now(),
        ),
      );
    }

    /// 取 infoList 后 100 条
    if (infoList.length > 100) {
      infoList.removeRange(0, infoList.length - 100);
    }

    onLog!(infoList);
  }

  String _cURLRepresentation(RequestOptions options) {
    List<String> components = ['curl -i'];

    options.headers.forEach((k, v) {
      if (k != 'Cookie') {
        components.add('-H "$k: $v"');
      }
    });

    if (options.data != null) {
      /// FormData can't be JSON-serialized, so keep only their fields attributes
      if (options.data is FormData && convertFormData) {
        options.data = Map.fromEntries(options.data.fields);
      }

      final data = json.encode(options.data).replaceAll('"', '\\"');
      components.add('-d "$data"');
    }
    bool contains = false;
    for (var element in components) {
      if (element.contains('-X')) {
        contains = true;
      }
    }
    if (contains) {
      components.add('-X ${options.method}');
    }
    components.add('"${options.uri.toString()}"');

    return components.join(' \\\n\t');
  }
}
