import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/ugrs_spider.dart';
import 'package:celechron/http/zjuServices/eta.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> etaPayload(List<Map<String, dynamic>> entries) => {
      'msg': 'success',
      'code': 0,
      'data': {
        'kbList': {
          for (var i = 0; i < entries.length; i++) '${i + 1}': [entries[i]],
        },
        'sjkc': [
          {'SJKCMC': '军训(虚构)-秋'},
        ],
      },
    };

Map<String, dynamic> entry({
  Object? xqj = 1,
  Object? xxq = '秋冬',
  Object? ksj = 6,
  Object? ks = 1,
  Object? sfqd = 1,
  Object? dsz = 'all',
  Object? name = '普通化学（H）',
  Object? teacher = '王勇',
  Object? location = '紫金港东1B-302',
  Object? code = '(2026-2027-1)-CHEM1002GH-0094016-1',
}) =>
    {
      'xqj': xqj,
      'xxq': xxq,
      'ksj': ksj,
      'ks': ks,
      'sfqd': sfqd,
      'dsz': dsz,
      'ke': [
        {
          'kcmc': name,
          'sksj': '秋冬{第1-8周|1节/周}',
          'rkjs': teacher,
          'jsmc': location,
          'kcdm': code,
        }
      ],
    };

typedef _ResponseFactory = FutureOr<HttpClientResponse> Function(
  _ScriptedRequest request,
);

class _ExpectedExchange {
  final String method;
  final Uri uri;
  final _ResponseFactory responseFactory;

  _ExpectedExchange(this.method, this.uri, this.responseFactory);

  String get description => '$method $uri';
}

class _ScriptedHttpClient implements HttpClient {
  final Queue<_ExpectedExchange> _pending = Queue<_ExpectedExchange>();
  final List<_ScriptedRequest> requests = <_ScriptedRequest>[];

  void expectGet(Uri uri, HttpClientResponse response) {
    _pending.add(_ExpectedExchange('GET', uri, (_) => response));
  }

  Future<HttpClientRequest> _open(String method, Uri uri) async {
    if (_pending.isEmpty) {
      throw StateError('Unexpected HTTP request: $method $uri');
    }
    final expected = _pending.removeFirst();
    if (expected.method != method || expected.uri != uri) {
      throw StateError(
        'Unexpected HTTP request: $method $uri; expected ${expected.description}',
      );
    }
    final request = _ScriptedRequest(method, uri, expected.responseFactory);
    requests.add(request);
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClient call: $invocation');
}

class _ScriptedRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final _ResponseFactory _responseFactory;
  @override
  final List<Cookie> cookies = <Cookie>[];
  @override
  final _TestHttpHeaders headers = _TestHttpHeaders();
  final List<int> body = <int>[];

  bool _followRedirects = true;
  bool _closed = false;

  _ScriptedRequest(this.method, this.uri, this._responseFactory);

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) => _followRedirects = value;

  @override
  void add(List<int> data) => body.addAll(data);

  @override
  Future<HttpClientResponse> close() async {
    if (_closed) throw StateError('HTTP request closed twice: $method $uri');
    _closed = true;
    return await _responseFactory(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientRequest call: $invocation');
}

class _ScriptedResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  @override
  final List<Cookie> cookies;
  final int _bodyLength;

  _ScriptedResponse({
    required this.statusCode,
    Map<String, String> headers = const {},
    List<Cookie> cookies = const [],
    String body = '',
  })  : headers = _TestHttpHeaders(headers),
        cookies = List<Cookie>.from(cookies),
        _bodyLength = utf8.encode(body).length,
        super(Stream<List<int>>.fromIterable([utf8.encode(body)]));

  @override
  int get contentLength => _bodyLength;

  @override
  bool get isRedirect =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  @override
  String get reasonPhrase => '';

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientResponse call: $invocation');
}

class _TestHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};
  ContentType? _contentType;

  _TestHttpHeaders([Map<String, String> initial = const {}]) {
    for (final entry in initial.entries) {
      set(entry.key, entry.value);
    }
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    _values.putIfAbsent(key, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    _values[key] = <String>[value.toString()];
    if (key == HttpHeaders.contentTypeHeader) {
      _contentType = ContentType.parse(value.toString());
    }
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value != null) {
      set(HttpHeaders.contentTypeHeader, value.toString());
    } else {
      _values.remove(HttpHeaders.contentTypeHeader);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpHeaders call: $invocation');
}

void main() {
  group('1. parseEtaTimetable 与 sessionFromEtaEntry 纯函数测试', () {
    test('把一条 eta 记录映射成课次（周几、节次、教师、教室、确认状态）', () {
      final sessions = parseEtaTimetable(etaPayload([entry()]));

      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.name, '普通化学（H）');
      expect(session.teacher, '王勇');
      expect(session.location, '紫金港东1B-302');
      expect(session.dayOfWeek, 1);
      expect(session.time, [6]);
      expect(session.confirmed, isTrue);
    });

    test('节数决定占用哪几节，非正数回退为 1 节', () {
      final sessions = parseEtaTimetable(etaPayload([entry(ksj: 3, ks: 3)]));
      expect(sessions.single.time, [3, 4, 5]);

      final fallbackZero =
          parseEtaTimetable(etaPayload([entry(ksj: 2, ks: 0)]));
      expect(fallbackZero.single.time, [2]);

      final fallbackNegative =
          parseEtaTimetable(etaPayload([entry(ksj: 4, ks: -2)]));
      expect(fallbackNegative.single.time, [4]);
    });

    test('半学期：秋冬两边都上，只写秋/冬/春/夏时按各自的半边归类', () {
      final all = parseEtaTimetable(etaPayload([entry(xxq: '秋冬')])).single;
      expect(all.firstHalf, isTrue);
      expect(all.secondHalf, isTrue);

      final autumn = parseEtaTimetable(etaPayload([entry(xxq: '秋')])).single;
      expect(autumn.firstHalf, isTrue);
      expect(autumn.secondHalf, isFalse);

      final winter = parseEtaTimetable(etaPayload([entry(xxq: '冬')])).single;
      expect(winter.firstHalf, isFalse);
      expect(winter.secondHalf, isTrue);

      final springSummer =
          parseEtaTimetable(etaPayload([entry(xxq: '春夏')])).single;
      expect(springSummer.firstHalf, isTrue);
      expect(springSummer.secondHalf, isTrue);

      final spring = parseEtaTimetable(etaPayload([entry(xxq: '春')])).single;
      expect(spring.firstHalf, isTrue);
      expect(spring.secondHalf, isFalse);

      final summer = parseEtaTimetable(etaPayload([entry(xxq: '夏')])).single;
      expect(summer.firstHalf, isFalse);
      expect(summer.secondHalf, isTrue);
    });

    test('半学期字段缺失时两边都算 —— 宁可显示，也不静默消失', () {
      final session = parseEtaTimetable(etaPayload([entry(xxq: null)])).single;
      expect(session.firstHalf, isTrue);
      expect(session.secondHalf, isTrue);
    });

    test('单双周：all 全上、single/1/单 只单周、double/2/双 只双周', () {
      final all = parseEtaTimetable(etaPayload([entry(dsz: 'all')])).single;
      expect(all.oddWeek, isTrue);
      expect(all.evenWeek, isTrue);

      final single =
          parseEtaTimetable(etaPayload([entry(dsz: 'single')])).single;
      expect(single.oddWeek, isTrue);
      expect(single.evenWeek, isFalse);

      final singleDigit =
          parseEtaTimetable(etaPayload([entry(dsz: '1')])).single;
      expect(singleDigit.oddWeek, isTrue);
      expect(singleDigit.evenWeek, isFalse);

      final singleCn = parseEtaTimetable(etaPayload([entry(dsz: '单')])).single;
      expect(singleCn.oddWeek, isTrue);
      expect(singleCn.evenWeek, isFalse);

      final double =
          parseEtaTimetable(etaPayload([entry(dsz: 'double')])).single;
      expect(double.oddWeek, isFalse);
      expect(double.evenWeek, isTrue);

      final doubleDigit =
          parseEtaTimetable(etaPayload([entry(dsz: '2')])).single;
      expect(doubleDigit.oddWeek, isFalse);
      expect(doubleDigit.evenWeek, isTrue);

      final doubleCn = parseEtaTimetable(etaPayload([entry(dsz: '双')])).single;
      expect(doubleCn.oddWeek, isFalse);
      expect(doubleCn.evenWeek, isTrue);
    });

    test('缺关键字段的记录被跳过，不会抛异常', () {
      final payload = etaPayload([
        entry(),
        entry(name: '  '), // 没有课名
        entry(name: null), // 课名为 null
        entry(xqj: null), // 没有星期
        entry(ksj: null), // 没有起始节次
        entry(ksj: 0), // 非法起始节次
      ]);
      expect(parseEtaTimetable(payload), hasLength(1));
    });

    test('空课表与异常响应都返回空列表', () {
      expect(
          parseEtaTimetable({
            'code': 0,
            'data': {'kbList': {}}
          }),
          isEmpty);
      expect(parseEtaTimetable({'code': 0, 'data': null}), isEmpty);
      expect(parseEtaTimetable({'code': 1, 'msg': 'error'}), isEmpty);
      expect(parseEtaTimetable({}), isEmpty);
    });

    test('课程名的英文括号统一成中文括号', () {
      final session =
          parseEtaTimetable(etaPayload([entry(name: '高等数学(H)')])).single;
      expect(session.name, '高等数学（H）');
    });

    test('星期越界时安全 clamp 到 1..7', () {
      final sessionLow = parseEtaTimetable(etaPayload([entry(xqj: 0)])).single;
      expect(sessionLow.dayOfWeek, 1);

      final sessionHigh = parseEtaTimetable(etaPayload([entry(xqj: 8)])).single;
      expect(sessionHigh.dayOfWeek, 7);
    });

    test('落进学期对象后能真的显示在课表上', () {
      final semester = Semester('2026-2027秋冬');
      final sessions =
          parseEtaTimetable(etaPayload([entry(xqj: 2), entry(xqj: 3, ksj: 1)]));
      for (final session in sessions) {
        semester.addSession(session, '2026-2027-1');
      }

      expect(semester.sessions, hasLength(2));
      expect(semester.firstHalfTimetable[2], hasLength(1));
      expect(semester.firstHalfTimetable[3], hasLength(1));
      expect(semester.firstHalfSessionCount, greaterThan(0));
    });
  });

  group('2. Eta 业务服务与鉴权流程测试', () {
    late Eta eta;
    late _ScriptedHttpClient client;

    setUp(() {
      eta = Eta();
      client = _ScriptedHttpClient();
    });

    test('login 正常流程：SSO 重定向后跟随跳转并签发会话 Cookie', () async {
      final ssoUri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Feta.zju.edu.cn%2Fzftal-xgxt-web%2Fteacher%2Fxtgl%2Findex%2Fcheck.zf',
      );
      final serviceRedirect = Uri.parse(
        'http://eta.zju.edu.cn/zftal-xgxt-web/teacher/xtgl/index/check.zf?ticket=ST-eta-12345',
      );
      final httpsServiceUri = Uri.parse(
        'https://eta.zju.edu.cn/zftal-xgxt-web/teacher/xtgl/index/check.zf?ticket=ST-eta-12345',
      );

      client.expectGet(
        ssoUri,
        _ScriptedResponse(
          statusCode: HttpStatus.found,
          headers: {'location': serviceRedirect.toString()},
          body: 'cas redirect',
        ),
      );
      client.expectGet(
        httpsServiceUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          cookies: [
            Cookie('JSESSIONID', 'mock-eta-session'),
            Cookie('route', 'mock-route'),
          ],
          body: '<html>ok</html>',
        ),
      );

      await eta.login(client, Cookie('iPlanetDirectoryPro', 'mock-sso-token'));

      expect(eta.isLoggedIn, isTrue);
      expect(eta.sessionCookies, hasLength(2));
      expect(eta.sessionCookies.first.name, 'JSESSIONID');
      expect(eta.sessionCookies.first.value, 'mock-eta-session');
    });

    test('login 异常：统一认证失效（未 302 重定向）抛 AuthenticationExpiredException',
        () async {
      final ssoUri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Feta.zju.edu.cn%2Fzftal-xgxt-web%2Fteacher%2Fxtgl%2Findex%2Fcheck.zf',
      );
      client.expectGet(
        ssoUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          body: '<html>login page</html>',
        ),
      );

      expect(
        () => eta.login(client, Cookie('iPlanetDirectoryPro', 'invalid-token')),
        throwsA(isA<AuthenticationExpiredException>()),
      );
      expect(eta.isLoggedIn, isFalse);
    });

    test('login 异常：未签发 Cookie 时抛 ExceptionWithMessage', () async {
      final ssoUri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Feta.zju.edu.cn%2Fzftal-xgxt-web%2Fteacher%2Fxtgl%2Findex%2Fcheck.zf',
      );
      final serviceRedirect = Uri.parse(
        'http://eta.zju.edu.cn/zftal-xgxt-web/teacher/xtgl/index/check.zf?ticket=ST-eta-12345',
      );
      final httpsServiceUri = Uri.parse(
        'https://eta.zju.edu.cn/zftal-xgxt-web/teacher/xtgl/index/check.zf?ticket=ST-eta-12345',
      );

      client.expectGet(
        ssoUri,
        _ScriptedResponse(
          statusCode: HttpStatus.found,
          headers: {'location': serviceRedirect.toString()},
        ),
      );
      client.expectGet(
        httpsServiceUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          cookies: [], // 没有会话 Cookie
          body: 'no cookies',
        ),
      );

      expect(
        () => eta.login(client, Cookie('iPlanetDirectoryPro', 'mock-token')),
        throwsA(isA<ExceptionWithMessage>()),
      );
      expect(eta.isLoggedIn, isFalse);
    });

    test('getTimetable 未登录时安全返回异常元组，不抛未捕获异常', () async {
      final result = await eta.getTimetable(client, '2025-2026-1');
      expect(result.item1, isA<AuthenticationExpiredException>());
      expect(result.item2, isEmpty);
    });

    test('getTimetable 正常拉取课表并解析', () async {
      eta.sessionCookies = [Cookie('JSESSIONID', 'valid-session')];
      final timetableUri = Uri.parse(
        'https://eta.zju.edu.cn/zftal-xgxt-web/student/xtgl/index/getTableKcb.zf?xnxq=2025-2026-1',
      );

      client.expectGet(
        timetableUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          body: jsonEncode(etaPayload([
            entry(name: '操作系统', xqj: 2, ksj: 3, ks: 2),
          ])),
        ),
      );

      final result = await eta.getTimetable(client, '2025-2026-1');
      expect(result.item1, isNull);
      expect(result.item2, hasLength(1));
      expect(result.item2.first.name, '操作系统');
      expect(result.item2.first.dayOfWeek, 2);
      expect(result.item2.first.time, [3, 4]);
    });

    test('getTimetable 遇到 401 登录失效时安全返回错误元组且不崩溃', () async {
      eta.sessionCookies = [Cookie('JSESSIONID', 'expired-session')];
      final timetableUri = Uri.parse(
        'https://eta.zju.edu.cn/zftal-xgxt-web/student/xtgl/index/getTableKcb.zf?xnxq=2025-2026-1',
      );

      client.expectGet(
        timetableUri,
        _ScriptedResponse(
          statusCode: HttpStatus.unauthorized,
          body: 'unauthorized',
        ),
      );

      final result = await eta.getTimetable(client, '2025-2026-1');
      expect(result.item1, isNotNull);
      expect(result.item2, isEmpty);
    });
  });

  group('3. 兜底触发逻辑切片测试 (resolveTimetableSessionsWithFallback)', () {
    test('zdbk 返回空且非探测学年：触发 eta 兜底并应用', () async {
      var fallbackCalled = false;
      var onFallbackCount = 0;

      final etaSession = Session.empty()
        ..name = '兜底课程'
        ..teacher = '李老师'
        ..dayOfWeek = 1
        ..time = [1, 2];

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [],
        isProbeYear: false,
        semKey: '2025-2026-1',
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [etaSession];
        },
        onFallbackApplied: (count) {
          onFallbackCount = count;
        },
      );

      expect(fallbackCalled, isTrue);
      expect(onFallbackCount, 1);
      expect(result, hasLength(1));
      expect(result.first.name, '兜底课程');
    });

    test('zdbk 返回非空课程：不调用 eta 兜底', () async {
      var fallbackCalled = false;
      final existingSession = Session.empty()
        ..name = '正常教务课'
        ..teacher = '张老师'
        ..dayOfWeek = 2
        ..time = [3];

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [existingSession],
        isProbeYear: false,
        semKey: '2025-2026-1',
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [];
        },
      );

      expect(fallbackCalled, isFalse);
      expect(result, hasLength(1));
      expect(result.first.name, '正常教务课');
    });

    test('未来探测学年 (isProbeYear: true)：即使 zdbk 为空也不调用 eta 兜底', () async {
      var fallbackCalled = false;

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [],
        isProbeYear: true,
        semKey: '2026-2027-1',
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [];
        },
      );

      expect(fallbackCalled, isFalse);
      expect(result, isEmpty);
    });

    test('zdbk 为空但 eta 也返回空时：保持空且不触发 onFallbackApplied', () async {
      var fallbackCalled = false;
      var onFallbackCount = 0;

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [],
        isProbeYear: false,
        semKey: '2025-2026-1',
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [];
        },
        onFallbackApplied: (count) {
          onFallbackCount = count;
        },
      );

      expect(fallbackCalled, isTrue);
      expect(onFallbackCount, 0);
      expect(result, isEmpty);
    });

    test('已回填过的学期 (alreadyApplied: true)：即使 zdbk 为空也不再重复调用 eta 兜底', () async {
      var fallbackCalled = false;
      var onFallbackCount = 0;

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [],
        isProbeYear: false,
        semKey: '2025-2026-1',
        alreadyApplied: true,
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [Session.empty()..name = '重复课'];
        },
        onFallbackApplied: (count) {
          onFallbackCount = count;
        },
      );

      expect(fallbackCalled, isFalse);
      expect(onFallbackCount, 0);
      expect(result, isEmpty);
    });

    test('非当前学年 (isCurrentAcademicYear: false)：即使 zdbk 为空也不调用 eta 兜底',
        () async {
      var fallbackCalled = false;
      var onFallbackCount = 0;

      final result = await resolveTimetableSessionsWithFallback(
        zdbkSessions: [],
        isProbeYear: false,
        semKey: '2022-2023-1',
        isCurrentAcademicYear: false,
        etaFallbackLoader: (semKey) async {
          fallbackCalled = true;
          return [Session.empty()..name = '历史课'];
        },
        onFallbackApplied: (count) {
          onFallbackCount = count;
        },
      );

      expect(fallbackCalled, isFalse);
      expect(onFallbackCount, 0);
      expect(result, isEmpty);
    });
  });

  group('4. UgrsSpider 智慧研工缓存与登录隔离', () {
    test('timetableFromEta: 相同学年学期复用缓存', () async {
      final spider = UgrsSpider('3200100000', 'password');
      final fakeEta = Eta()
        ..sessionCookies = [Cookie('JSESSIONID', 'mock-session')];
      spider.eta = fakeEta;

      final session = Session.empty()
        ..name = '测试课'
        ..dayOfWeek = 1
        ..time = [1];
      spider.etaTimetableCache['2025-2026-1'] = [session];

      // 再次获取相同学期，直接命中缓存
      final cached = await spider.timetableFromEta('2025-2026-1');
      expect(
          identical(cached, spider.etaTimetableCache['2025-2026-1']), isTrue);
      expect(cached, hasLength(1));
      expect(cached.first.name, '测试课');
    });

    test('timetableFromEta: 未登录时直接返回空并记录空缓存', () async {
      final spider = UgrsSpider('3200100000', 'password');
      // 默认未登录
      expect(spider.eta.isLoggedIn, isFalse);

      final result = await spider.timetableFromEta('2025-2026-1');
      expect(result, isEmpty);
      expect(spider.etaTimetableCache['2025-2026-1'], isEmpty);
    });

    test('智慧研工登录失败被隔离：记录 warning 日志且不向外抛出未捕获错误', () async {
      final failingEta = Eta();
      final client = _ScriptedHttpClient();
      // 请求 SSO 失败
      final ssoUri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Feta.zju.edu.cn%2Fzftal-xgxt-web%2Fteacher%2Fxtgl%2Findex%2Fcheck.zf',
      );
      client.expectGet(
        ssoUri,
        _ScriptedResponse(
          statusCode: HttpStatus.internalServerError,
          body: 'server error',
        ),
      );

      // 真实调用 UgrsSpider.captureLogin，断言登录失败被安全隔离且记录警告日志
      final result = await UgrsSpider.captureLogin(
        failingEta.login(client, Cookie('iPlanetDirectoryPro', 'token')),
        '智慧研工',
        ignoreError: true,
      );

      expect(result, isNull);
      expect(failingEta.isLoggedIn, isFalse);
      final logs = DiagnosticLogService.instance.currentText();
      expect(logs, contains('登录智慧研工失败（非阻断）'));
    });
  });
}
