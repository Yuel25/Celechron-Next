import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/zdbk.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/services/diagnostic_log_service.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final Map<String, String> cache = <String, String>{};

  @override
  String? getCachedWebPage(String key) => cache[key];

  @override
  Future<void> setCachedWebPage(String key, String value) async {
    cache[key] = value;
  }
}

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

  void expectPost(Uri uri, HttpClientResponse response) {
    _pending.add(_ExpectedExchange('POST', uri, (_) => response));
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

Session createTestSession({
  required String name,
  String teacher = '测试教师',
  int dayOfWeek = 1,
  List<int> time = const [1, 2],
  bool firstHalf = true,
  bool secondHalf = true,
  String? location = '西区教1',
}) {
  return Session.empty()
    ..id = '(2024-2025-1)-$name'
    ..name = name
    ..teacher = teacher
    ..dayOfWeek = dayOfWeek
    ..time = time
    ..firstHalf = firstHalf
    ..secondHalf = secondHalf
    ..oddWeek = true
    ..evenWeek = true
    ..location = location;
}

void main() {
  group('1. 缓存层：zdbk getTimetable 空响应与缓存行为', () {
    late Zdbk zdbk;
    late FakeDatabaseHelper fakeDb;
    late _ScriptedHttpClient client;

    setUp(() {
      zdbk = Zdbk();
      fakeDb = FakeDatabaseHelper();
      zdbk.db = fakeDb;
      client = _ScriptedHttpClient();
    });

    Future<void> mockLogin() async {
      final ssoUri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fzdbk.zju.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_ssologin.html',
      );
      final stUri = Uri.parse(
        'https://zdbk.zju.edu.cn/jwglxt/xtgl/login_ssologin.html?ticket=ST-12345',
      );
      client.expectGet(
        ssoUri,
        _ScriptedResponse(
          statusCode: HttpStatus.found,
          headers: {'location': stUri.toString()},
        ),
      );
      client.expectGet(
        stUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          cookies: [
            Cookie('JSESSIONID', 'mock-jsessionid'),
            Cookie('route', 'mock-route'),
          ],
          body: 'login ok',
        ),
      );
      await zdbk.login(client, Cookie('iPlanetDirectoryPro', 'mock-token'));
    }

    test('空成功响应 (HTTP 200, kbList: []) 不写缓存且记录 Warning', () async {
      await mockLogin();
      const cacheKey = 'zdbk_Timetable20241';
      fakeDb.cache[cacheKey] = jsonEncode([
        {'kcmc': '旧缓存课程'}
      ]);

      final timetableUri =
          Uri.parse('https://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html');
      client.expectPost(
        timetableUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          body: jsonEncode({'kbList': []}),
        ),
      );

      final result = await zdbk.getTimetable(client, '2024', '1');

      expect(result.item1, isNull);
      expect(result.item2, isEmpty);
      // 验证旧缓存未被空数组覆盖
      expect(fakeDb.cache[cacheKey], contains('旧缓存课程'));
      // 验证诊断日志中记录了 warning
      final logs = DiagnosticLogService.instance.currentText();
      expect(logs, contains('返回空课表列表，跳过写入缓存以避免覆盖已有数据'));
    });

    test('非空成功响应正常写入缓存', () async {
      await mockLogin();
      const cacheKey = 'zdbk_Timetable20242';

      final timetableUri =
          Uri.parse('https://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html');
      client.expectPost(
        timetableUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          body: jsonEncode({
            'kbList': [
              {
                'kcb': '高等数学<br>教学班<br>陈老师<br>东1-101zwf',
                'sfqd': '1',
                'xqj': 1,
                'dsz': '2',
                'xxq': '秋冬',
                'djj': 1,
                'skcd': 2,
              }
            ]
          }),
        ),
      );

      final result = await zdbk.getTimetable(client, '2024', '2');

      expect(result.item1, isNull);
      expect(result.item2, hasLength(1));
      expect(result.item2.first.name, '高等数学');
      // 验证缓存被正常写入
      expect(fakeDb.cache[cacheKey], isNotNull);
      expect(fakeDb.cache[cacheKey], contains('高等数学'));
    });
  });

  group('2. 模型层：Semester.carryOverTimetablesFrom 承接排课行为', () {
    test('新学期无排课且历史学期有排课时，成功承接课表与课程', () {
      final oldSemester = Semester('2024-2025秋冬');
      final s1 = createTestSession(name: '微积分', teacher: '李老师');
      final s2 = createTestSession(name: '大学物理', teacher: '王老师');
      oldSemester.addSession(s1, '2024-2025-1');
      oldSemester.addSession(s2, '2024-2025-1');
      expect(oldSemester.sessions, hasLength(2));
      expect(oldSemester.courses, hasLength(2));

      final newSemester = Semester('2024-2025秋冬');
      expect(newSemester.sessions, isEmpty);

      newSemester.carryOverTimetablesFrom(oldSemester);

      expect(newSemester.sessions, hasLength(2));
      expect(newSemester.courses, hasLength(2));
      expect(newSemester.courses.values.map((c) => c.name),
          containsAll(['微积分', '大学物理']));
      expect(newSemester.firstHalfTimetable[1], isNotEmpty);

      final logs = DiagnosticLogService.instance.currentText();
      expect(logs, contains('学期 2024-2025秋冬 新拉取课表为空，已承接本地已有排课（2 节）'));
    });

    test('新学期已有自身排课时，不承接历史排课', () {
      final oldSemester = Semester('2024-2025秋冬');
      final sOld = createTestSession(name: '旧课程');
      oldSemester.addSession(sOld, '2024-2025-1');

      final newSemester = Semester('2024-2025秋冬');
      final sNew = createTestSession(name: '新课程');
      newSemester.addSession(sNew, '2024-2025-1');

      newSemester.carryOverTimetablesFrom(oldSemester);

      expect(newSemester.sessions, hasLength(1));
      expect(newSemester.sessions.first.name, '新课程');
    });

    test('原本就空的学期收到空结果不受影响', () {
      final oldSemester = Semester('2025-2026秋冬');
      final newSemester = Semester('2025-2026秋冬');

      newSemester.carryOverTimetablesFrom(oldSemester);

      expect(newSemester.sessions, isEmpty);
      expect(newSemester.courses, isEmpty);
    });

    test('承接时若新学期缺少校历时间配置，自动承接历史校历', () {
      final oldSemester = Semester('2024-2025秋冬');
      oldSemester.addSession(createTestSession(name: '概率论'), '2024-2025-1');
      oldSemester.addZjuCalendar({
        'startEnd': ['20240901', '20241110', '20241111', '20250120'],
        'sessionTime': [
          [],
          ['08:00', '08:45'],
          ['08:50', '09:35'],
        ],
        'holiday': {
          '20241001': '国庆节',
        },
        'exchange': {
          '2024092920241004': '调休',
        },
      });

      final newSemester = Semester('2024-2025秋冬');
      newSemester.carryOverTimetablesFrom(oldSemester);

      expect(newSemester.periods, isNotEmpty);
      expect(newSemester.periods.first.summary, '概率论');
      final newJson = newSemester.toJson();
      expect(newJson['holidays'], isNotEmpty);
      expect(newJson['exchanges'], isNotEmpty);
    });

    test('新学期已有自身校历配置时，不被历史校历覆盖', () {
      final oldSemester = Semester('2024-2025秋冬');
      oldSemester.addSession(createTestSession(name: '微积分'), '2024-2025-1');
      oldSemester.addZjuCalendar({
        'startEnd': ['20240901', '20241110', '20241111', '20250120'],
        'sessionTime': [
          [],
          ['08:00', '08:45'],
        ],
        'holiday': {
          '20241001': '旧国庆节',
        },
        'exchange': {
          '2024092920241004': '旧调休',
        },
      });

      final newSemester = Semester('2024-2025秋冬');
      // 新学期已配置了新的校历（如假期、调休或节次不同）
      newSemester.addZjuCalendar({
        'startEnd': ['20240902', '20241111', '20241112', '20250121'],
        'sessionTime': [
          [],
          ['08:05', '08:50'],
        ],
        'holiday': {
          '20241002': '新国庆假期',
        },
        'exchange': {
          '2024093020241005': '新调休',
        },
      });

      newSemester.carryOverTimetablesFrom(oldSemester);

      // 课表成功承接
      expect(newSemester.sessions, hasLength(1));
      expect(newSemester.sessions.first.name, '微积分');

      // 但新学期的校历节次与假期配置未被旧校历覆盖
      final newJson = newSemester.toJson();
      expect(newJson['holidays'],
          containsPair('2024-10-02T00:00:00.000', '新国庆假期'));
      expect(newJson['holidays'],
          isNot(containsPair('2024-10-01T00:00:00.000', '旧国庆节')));
    });
  });

  group('3. 应用层：Scholar.setScholar 课表保活与学期合并', () {
    test('已有排课的学期收到空结果时保留原排课', () {
      final scholar = Scholar();
      final localSemester = Semester('2024-2025秋冬');
      localSemester.addSession(
        createTestSession(name: '数据结构与算法'),
        '2024-2025-1',
      );
      scholar.semesters = [localSemester];

      // 模拟刷新结果：课表请求成功（无报错），但新拉取的学期排课为空
      final incomingEmptySemester = Semester('2024-2025秋冬');
      scholar.setScholar(
        [null, null, null, null], // 成绩、课表、作业、实践均无错误
        [incomingEmptySemester],
        {},
        {},
        [],
        null,
      );

      expect(scholar.semesters, hasLength(1));
      final resultSem = scholar.semesters.first;
      expect(resultSem.name, '2024-2025秋冬');
      expect(resultSem.sessions, hasLength(1));
      expect(resultSem.sessions.first.name, '数据结构与算法');
      expect(resultSem.courses.values.first.name, '数据结构与算法');
    });

    test('已有排课的学期若在爬虫层全空被移除，本地仍保留该学期', () {
      final scholar = Scholar();
      final localSemester = Semester('2024-2025秋冬');
      localSemester.addSession(
        createTestSession(name: '计算机组成原理'),
        '2024-2025-1',
      );
      scholar.semesters = [localSemester];

      // 模拟 spider.getEverything 因所有字段为空而移除了该学期，tempSemesters 中无此学期
      final otherSemester = Semester('2023-2024春夏');
      otherSemester.addSession(createTestSession(name: '历史学期课'), '2023-2024-2');

      scholar.setScholar(
        [null, null, null, null],
        [otherSemester],
        {},
        {},
        [],
        null,
      );

      final semesterNames = scholar.semesters.map((s) => s.name).toList();
      expect(semesterNames, contains('2024-2025秋冬'));
      final preservedSem =
          scholar.semesters.firstWhere((s) => s.name == '2024-2025秋冬');
      expect(preservedSem.sessions, hasLength(1));
      expect(preservedSem.sessions.first.name, '计算机组成原理');
    });

    test('原本就空的学期（如探测未来学年）收到空结果不受影响', () {
      final scholar = Scholar();
      final probeSemester = Semester('2026-2027秋冬');
      scholar.semesters = [probeSemester];

      final incomingProbe = Semester('2026-2027秋冬');
      scholar.setScholar(
        [null, null, null, null],
        [incomingProbe],
        {},
        {},
        [],
        null,
      );

      expect(scholar.semesters, hasLength(1));
      expect(scholar.semesters.first.sessions, isEmpty);
      expect(scholar.semesters.first.courses, isEmpty);
    });

    test('新拉取到非空排课时正常覆盖旧数据', () {
      final scholar = Scholar();
      final localSemester = Semester('2024-2025秋冬');
      localSemester.addSession(createTestSession(name: '旧排课'), '2024-2025-1');
      scholar.semesters = [localSemester];

      final incomingNewSemester = Semester('2024-2025秋冬');
      incomingNewSemester.addSession(
        createTestSession(name: '新排课A'),
        '2024-2025-1',
      );
      incomingNewSemester.addSession(
        createTestSession(name: '新排课B'),
        '2024-2025-1',
      );

      scholar.setScholar(
        [null, null, null, null],
        [incomingNewSemester],
        {},
        {},
        [],
        null,
      );

      expect(scholar.semesters, hasLength(1));
      final resultSem = scholar.semesters.first;
      expect(resultSem.sessions, hasLength(2));
      expect(
          resultSem.sessions.map((s) => s.name), containsAll(['新排课A', '新排课B']));
      expect(resultSem.sessions.map((s) => s.name), isNot(contains('旧排课')));
    });

    test('学期排序专用比较器：跨年降序且同年内春夏先于秋冬', () {
      final scholar = Scholar();
      final autumn24 = Semester('2024-2025秋冬');
      final spring24 = Semester('2024-2025春夏');
      final autumn23 = Semester('2023-2024秋冬');
      final spring23 = Semester('2023-2024春夏');

      // 故意以颠倒或乱序输入
      scholar.setScholar(
        [null, null, null, null],
        [autumn23, autumn24, spring23, spring24],
        {},
        {},
        [],
        null,
      );

      final names = scholar.semesters.map((s) => s.name).toList();
      expect(
        names,
        ['2024-2025春夏', '2024-2025秋冬', '2023-2024春夏', '2023-2024秋冬'],
        reason: '应保证学年降序且同年内春夏学期排在秋冬学期之前',
      );
    });

    test('thisSemester 在 semesters[1].periods 为空时不抛 StateError 且安全回退', () {
      final scholar = Scholar();
      final spring = Semester('2024-2025春夏');
      final autumn = Semester('2024-2025秋冬');
      // 保持两者 periods 为空（未选课/未排课）
      scholar.semesters = [spring, autumn];

      expect(() => scholar.thisSemester, returnsNormally);
      expect(scholar.thisSemester.name, '2024-2025春夏');
    });
  });
}
