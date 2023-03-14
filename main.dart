import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import 'socket_tts.dart';
import 'sound_player.dart';
import 'sound_recorder.dart';
import 'flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'socket_stt.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'date.dart';

String tmpEvent = "";
String tmpMedicalTime = "";
String tmpMedicalPlace = "";
String tmpMedicalName = "";
String tmpMedicalNum = "";
String tmpPlayTime = "";
String tmpGatherPlace = "";
String tmpPlayName = "";
String tmpPlayPlace = "";
String tmpBringThing = "";

void main() {
  initializeDateFormatting().then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.amber,
        ),
        debugShowCheckedModeBanner: false,
        home: CustomTableCalendar(),
    );
  }
}

class AppColors {
  AppColors._();

  static const Color blackCoffee = Color(0xFF352d39);
  static const Color eggPlant = Color(0xFF6d435a);
  static const Color celeste = Color(0xFFb1ede8);
  static const Color babyPowder = Color(0xFFFFFcF9);
  static const Color ultraRed = Color(0xFFFF6978);
}

class CustomTableCalendar extends StatefulWidget {
  const CustomTableCalendar({Key? key}) : super(key: key);

  @override
  _CustomTableCalendarState createState() => _CustomTableCalendarState();
}

class _CustomTableCalendarState extends State<CustomTableCalendar> {
  final recorder = SoundRecorder();
  final player = SoundPlayer();
  final todaysDate = DateTime.now();
  var _focusedCalendarDate = DateTime.now();
  final _initialCalendarDate = DateTime(2000);
  final _lastCalendarDate = DateTime(2050);
  DateTime? selectedCalendarDate;
  final placeController = TextEditingController();
  final nameController = TextEditingController();
  final numController = TextEditingController();
  final gatherPlaceController = TextEditingController();
  final playerController = TextEditingController();
  final playPlaceController = TextEditingController();
  final bringThingController = TextEditingController();
  final descpController = TextEditingController();
  TextEditingController recognitionController = TextEditingController();
  final ValueNotifier<TimeOfDay?> timePick = ValueNotifier(null);
  int? status = 1;

  late Map<DateTime, List<MyEvents>> mySelectedEvents;

  @override
  void initState() {
    selectedCalendarDate = _focusedCalendarDate;
    mySelectedEvents = {};
    getData();
    super.initState();
    recorder.init();
    player.init();
  }

  @override
  void dispose() {
    nameController.dispose();
    placeController.dispose();
    numController.dispose();
    descpController.dispose();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  List<MyEvents> _listOfDayEvents(DateTime dateTime) {
    return mySelectedEvents[dateTime] ?? [];
  }

  _chooseEventDialog() async {
    await Text2Speech().connect(play, "請選擇要新增的活動", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              "請選擇要新增的活動",
              style: TextStyle(fontSize: 25),
          ),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return SingleChildScrollView(
                child: Column(
                    children: [
                      RadioListTile(
                        value: 1,
                        groupValue: this.status,
                        onChanged: (value) {
                          setState(() {
                            this.status = value;
                          });
                        },
                        title: Text("門診",style: TextStyle(fontSize: 30)),
                        subtitle: Text("紀錄門診時間與細節",style: TextStyle(fontSize: 20)),
                        selected: this.status == 1,
                      ),
                      RadioListTile(
                        value: 2,
                        groupValue: this.status,
                        onChanged: (value) {
                          setState(() {
                            this.status = value;
                          });
                        },
                        title: Text("娛樂",style: TextStyle(fontSize: 30)),
                        subtitle: Text("記錄出遊時間、朋友聚會...",style: TextStyle(fontSize: 20)),
                        selected: this.status == 2,
                      ),
                    ]
                )
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消',style: TextStyle(fontSize: 30)),
            ),

            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if(status == 1){
                    _showMedicalEventTime();
                  }
                  else{
                    _showPlayEventTime();
                  }
                },
                child: const Text('確認',style: TextStyle(fontSize: 30)),
            ),
          ],
        ),
    );
  }

  Widget buildTimePicker(String data) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: const BorderSide(color: AppColors.eggPlant, width: 1.5),
      ),
      title: Text(data,style: TextStyle(fontSize: 20)),
      trailing: const Icon(
        Icons.calendar_today,
        color: AppColors.eggPlant,
      ),
    );
  }

  String recognitionLanguage = "Chinese";

  Widget buildRecord(int idx) {
    // whether is recording
    final isRecording = recorder.isRecording;
    // if recording => icon is Icons.stop
    // else => icon is Icons.mic
    final icon = isRecording ? Icons.stop : Icons.mic;
    // if recording => color of button is red
    // else => color of button is white
    final primary = isRecording ? Colors.red : Colors.white;
    // if recording => text in button is STOP
    // else => text in button is START
    final text = '語音輸入';
    // if recording => text in button is white
    // else => color of button is black
    final onPrimary = isRecording ? Colors.white : Colors.black;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        // 設定 Icon 大小及屬性
        minimumSize: const Size(175, 50),
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      icon: Icon(icon),
      label: Text(
        text,
        // 設定字體大小及字體粗細（bold粗體，normal正常體）
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      //onPressed: () {},
      // 當 Iicon 被點擊時執行的動作
      onPressed: () async {
        // getTemporaryDirectory(): 取得暫存資料夾，這個資料夾隨時可能被系統或使用者操作清除
        Directory tempDir = await path_provider.getTemporaryDirectory();
        // define file directory
        String path = '${tempDir.path}/SpeechRecognition.wav';
        // 控制開始錄音或停止錄音
        await recorder.toggleRecording(path);
        // When stop recording, pass wave file to socket
        if (!recorder.isRecording) {
          if (recognitionLanguage == "Taiwanese") {
            // if recognitionLanguage == "Taiwanese" => use Minnan model
            // setTxt is call back function
            // parameter: wav file path, call back function, model
            if(idx == 1){
              await Speech2Text().connect(path, setTxt1, "Minnan");
            }
            else if(idx == 2){
              await Speech2Text().connect(path, setTxt2, "Minnan");
            }
            else if(idx == 3){
              await Speech2Text().connect(path, setTxt3, "Minnan");
            }
            else if(idx == 4){
              await Speech2Text().connect(path, setTxt4, "Minnan");
            }
            else if(idx == 5){
              await Speech2Text().connect(path, setTxt5, "Minnan");
            }
            else if(idx == 6){
              await Speech2Text().connect(path, setTxt6, "Minnan");
            }
            else if(idx == 7){
              await Speech2Text().connect(path, setTxt7, "Minnan");
            }
            // glSocket.listen(dataHandler, cancelOnError: false);
          } else {
            // if recognitionLanguage == "Chinese" => use MTK_ch model
            if(idx == 1){
              await Speech2Text().connect(path, setTxt1, "MTK_ch");
            }
            else if(idx == 2){
              await Speech2Text().connect(path, setTxt2, "MTK_ch");
            }
            else if(idx == 3){
              await Speech2Text().connect(path, setTxt3, "Minnan");
            }
            else if(idx == 4){
              await Speech2Text().connect(path, setTxt4, "Minnan");
            }
            else if(idx == 5){
              await Speech2Text().connect(path, setTxt5, "Minnan");
            }
            else if(idx == 6){
              await Speech2Text().connect(path, setTxt6, "Minnan");
            }
            else if(idx == 7){
              await Speech2Text().connect(path, setTxt7, "Minnan");
            }
          }
        }

        // set state is recording or stop
        setState(() {
          recorder.isRecording;
        });
      },
    );
  }

  void setTxt1(taiTxt) {
    setState(() {
      placeController.text = taiTxt;
    });
  }

  void setTxt2(taiTxt) {
    setState(() {
      nameController.text = taiTxt;
    });
  }

  void setTxt3(taiTxt) {
    setState(() {
      numController.text = taiTxt;
    });
  }

  void setTxt4(taiTxt) {
    setState(() {
      gatherPlaceController.text = taiTxt;
    });
  }

  void setTxt5(taiTxt) {
    setState(() {
      playerController.text = taiTxt;
    });
  }

  void setTxt6(taiTxt) {
    setState(() {
      playPlaceController.text = taiTxt;
    });
  }

  void setTxt7(taiTxt) {
    setState(() {
      bringThingController.text = taiTxt;
    });
  }

  _showMedicalEventTime() async {
    await Text2Speech().connect(play, "請填入門診時間", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('門診時間',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<TimeOfDay?>(
                    valueListenable: timePick,
                    builder: (context, timeVal, child) {
                      return InkWell(
                          onTap: () async {
                            TimeOfDay? time = await showTimePicker(
                              context: context,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context),
                                  child: child!,
                                );
                              },
                              initialTime: TimeOfDay.now(),
                            );
                            timePick.value = time;
                          },
                          child: buildTimePicker(timeVal != null ? timeVal.format(context) : '')
                      );

                    }),
              ],
            );
          }),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 30)),
            ),
            TextButton(
              onPressed: () {
                if (timePick == ValueNotifier(null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊!',style: TextStyle(fontSize: 30)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  //tmpEvent = '在 ${timePick.value?.format(context)}';
                  if(timePick.value?.period == DayPeriod.am){
                    if(timePick.value?.hour == 0 || timePick.value?.hour == 5 || timePick.value?.hour == 1 || timePick.value?.hour == 2|| timePick.value?.hour == 3|| timePick.value?.hour == 4) {
                      tmpMedicalTime =
                          '凌晨' + turnTime(timePick.value?.hour) + '點' +
                              turnTime(timePick.value?.minute) + '分';
                    }
                    else if(timePick.value?.hour == 6 || timePick.value?.hour == 7 || timePick.value?.hour == 8 || timePick.value?.hour == 9|| timePick.value?.hour == 10|| timePick.value?.hour == 11) {
                      tmpMedicalTime =
                          '早上' + turnTime(timePick.value?.hour) + '點' +
                              turnTime(timePick.value?.minute) + '分';
                    }
                  }
                  else if(timePick.value?.period == DayPeriod.pm){
                    if(timePick.value?.hour == 12 || timePick.value?.hour == 17 || timePick.value?.hour == 13 || timePick.value?.hour == 14|| timePick.value?.hour == 15|| timePick.value?.hour == 16) {
                      tmpMedicalTime =
                          '下午' + turnTime(timePick.value!.hour - 12) + '點' +
                              turnTime(timePick.value?.minute) + '分';
                    }
                    else if(timePick.value?.hour == 18 || timePick.value?.hour == 19 || timePick.value?.hour == 20 || timePick.value?.hour == 21|| timePick.value?.hour == 22|| timePick.value?.hour == 23) {
                      tmpMedicalTime =
                          '晚上' + turnTime(timePick.value!.hour - 12) + '點' +
                              turnTime(timePick.value?.minute) + '分';
                    }
                  }
                  print(tmpMedicalTime);
                  Navigator.pop(context);
                  _showMedicalEventPlace();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 30)),
            ),
          ],
        ),
    );
  }

  String turnTime(int ?time){
    String ret = "";
    if(time == 0){
      return '零';
    }
    int ten = (time! / 10).floor();
    if(ten == 1){
      ret = ret + "十";
    }
    else if(ten == 2){
      ret = ret + "二十";
    }
    else if(ten == 3){
      ret = ret + "三十";
    }
    else if(ten == 4){
      ret = ret + "四十";
    }
    else if(ten == 5){
      ret = ret + "五十";
    }
    int one = time % 10;
    if(one == 1){
      ret = ret + "一";
    }
    else if(one == 2){
      ret = ret + "二";
    }
    else if(one == 3){
      ret = ret + "三";
    }
    else if(one == 4){
      ret = ret + "四";
    }
    else if(one == 5){
      ret = ret + "五";
    }
    else if(one == 6){
      ret = ret + "六";
    }
    else if(one == 7){
      ret = ret + "七";
    }
    else if(ten == 8){
      ret = ret + "八";
    }
    else if(one == 9){
      ret = ret + "九";
    }

    return ret;
  }

  _showMedicalEventPlace() async {
    await Text2Speech().connect(play, "請填入看診地點", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('看診地點',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: placeController, hint: '門診地點'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(1),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                        // 將 recognitionLanguage 設為 Taiwanese
                        recognitionLanguage = "Taiwanese";
                      });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                    // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                        // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: (){
                Navigator.pop(context);
                _showMedicalEventTime();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (placeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 25)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpMedicalPlace = placeController.text;
                  //print(tmpEvent);
                  Navigator.pop(context);
                  _showMedicalEventName();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 25)),
            )
          ],
        ));
  }

  _showMedicalEventName() async {
    await Text2Speech().connect(play, "請填入醫生姓名", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('醫生姓名',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: nameController, hint: '醫生姓名'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(2),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: (){
                Navigator.pop(context);
                _showMedicalEventPlace();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 25)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpMedicalName = nameController.text;
                  //print(tmpEvent);
                  Navigator.pop(context);
                  _showMedicalEventNum();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 25)),
            )
          ],
        ));
  }

  _showMedicalEventNum() async {
    await Text2Speech().connect(play, "請填入門診號碼", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('門診號碼',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: numController, hint: '門診號碼'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(3),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
            onPressed: (){
              Navigator.pop(context);
              _showMedicalEventName();
            },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (placeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 25)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpMedicalNum = numController.text;
                  tmpEvent = '到${tmpMedicalPlace}找${tmpMedicalName}看診，時間是${tmpMedicalTime},門診號碼是${tmpMedicalNum}';
                  //print(tmpEvent);
                  String month = '';
                  String day = '';
                  if(selectedCalendarDate!.month < 10){
                    month = '0' + selectedCalendarDate!.month.toString();
                  }
                  else{
                    month = selectedCalendarDate!.month.toString();
                  }
                  if(selectedCalendarDate!.day < 10){
                    day = '0' + selectedCalendarDate!.day.toString();
                  }
                  else{
                    day = selectedCalendarDate!.day.toString();
                  }
                  String date = selectedCalendarDate!.year.toString() + month + day;
                  insertData(date, '看醫生', tmpEvent);
                  setState(() {
                    if (mySelectedEvents[selectedCalendarDate] != null) {
                      mySelectedEvents[selectedCalendarDate]?.add(MyEvents(
                          eventTitle: '看醫生',
                          eventDescp: tmpEvent
                      ));
                    } else {
                      mySelectedEvents[selectedCalendarDate!] = [
                        MyEvents(
                            eventTitle: '看醫生',
                            eventDescp: tmpEvent)
                      ];
                    }
                    //print(selectedCalendarDate);
                    //print(mySelectedEvents[selectedCalendarDate!]);
                  });
                  Navigator.pop(context);
                  return;
                }
              },
              child: const Text('確認',style: TextStyle(fontSize: 25)),
            ),
          ],
        ));
  }

  _showPlayEventTime() async {
    await Text2Speech().connect(play, "請填入集合時間", "taiwanese");
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('集合時間',style: TextStyle(fontSize: 35)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TimeOfDay?>(
                valueListenable: timePick,
                builder: (context, timeVal, child) {
                  return InkWell(
                      onTap: () async {
                        TimeOfDay? time = await showTimePicker(
                          context: context,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context),
                              child: child!,
                            );
                          },
                          initialTime: TimeOfDay.now(),
                        );
                        timePick.value = time;
                      },
                      child: buildTimePicker(timeVal != null ? timeVal.format(context) : '')
                  );

                }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              tmpEvent = "";
            },
            child: const Text('取消',style: TextStyle(fontSize: 25)),
          ),
          TextButton(
            onPressed: () {
              if (timePick == ValueNotifier(null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('請輸入必要資訊!',style: TextStyle(fontSize: 30)),
                    duration: Duration(seconds: 3),
                  ),
                );
                //Navigator.pop(context);
                return;
              } else {
                if(timePick.value?.period == DayPeriod.am){
                  if(timePick.value?.hour == 0 || timePick.value?.hour == 5 || timePick.value?.hour == 1 || timePick.value?.hour == 2|| timePick.value?.hour == 3|| timePick.value?.hour == 4) {
                    tmpPlayTime =
                        '凌晨' + turnTime(timePick.value?.hour) + '點' +
                            turnTime(timePick.value?.minute) + '分';
                  }
                  else if(timePick.value?.hour == 6 || timePick.value?.hour == 7 || timePick.value?.hour == 8 || timePick.value?.hour == 9|| timePick.value?.hour == 10|| timePick.value?.hour == 11) {
                    tmpPlayTime =
                        '早上' + turnTime(timePick.value?.hour) + '點' +
                            turnTime(timePick.value?.minute) + '分';
                  }
                }
                if(timePick.value?.period == DayPeriod.pm){
                  if(timePick.value?.hour == 12 || timePick.value?.hour == 17 || timePick.value?.hour == 13 || timePick.value?.hour == 14|| timePick.value?.hour == 15|| timePick.value?.hour == 4) {
                    tmpPlayTime =
                        '下午' + turnTime(timePick.value!.hour - 12) + '點' +
                            turnTime(timePick.value?.minute) + '分';
                  }
                  else if(timePick.value?.hour == 18 || timePick.value?.hour == 19 || timePick.value?.hour == 20 || timePick.value?.hour == 21|| timePick.value?.hour == 22|| timePick.value?.hour == 23) {
                    tmpPlayTime =
                        '晚上' + turnTime(timePick.value!.hour - 12) + '點' +
                            turnTime(timePick.value?.minute) + '分';
                  }
                }
                print(tmpPlayTime);
                Navigator.pop(context);
                _showPlayEventGatherPlace();
                return;
              }
            },
            child: const Text('下一步',style: TextStyle(fontSize: 25)),
          ),
        ],
      ),
    );
  }

  _showPlayEventGatherPlace() async {
    await Text2Speech().connect(play, "請填入集合地點", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('集合地點',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: gatherPlaceController, hint: '集合地點'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(4),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPlayEventTime();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (gatherPlaceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 30)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpGatherPlace = gatherPlaceController.text;
                  //print(tmpEvent);
                  Navigator.pop(context);
                  _showPlayerName();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 25)),
            ),
          ],
        ));
  }

  _showPlayerName() async {
    await Text2Speech().connect(play, "請填入要跟誰去玩", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('遊玩旅伴',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: playerController, hint: '旅伴'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(5),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPlayEventGatherPlace();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (playerController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 30)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpPlayName = playerController.text;
                  //print(tmpEvent);
                  Navigator.pop(context);
                  _showPlayPlaceName();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 25)),
            ),
          ],
        ));
  }

  _showPlayPlaceName() async {
    await Text2Speech().connect(play, "請填入旅遊地點", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('旅遊地點',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: playPlaceController, hint: '旅游地點'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(6),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPlayerName();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (playPlaceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 30)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpPlayPlace = playPlaceController.text;
                  //print(tmpEvent);
                  Navigator.pop(context);
                  _showBringThing();
                  return;
                }
              },
              child: const Text('下一步',style: TextStyle(fontSize: 25)),
            ),
          ],
        ));
  }

  _showBringThing() async {
    await Text2Speech().connect(play, "請填入必帶物品", "taiwanese");
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('必帶物品',style: TextStyle(fontSize: 35)),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTextField(controller: bringThingController, hint: '必帶物品'),
                const SizedBox(
                  height: 20.0,
                ),
                buildRecord(7),
                const SizedBox(
                  height: 20.0,
                ),
                Row(children: <Widget>[
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Taiwanese',
                      // Set option name、color
                      title: const Text(
                        '台語',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Taiwanese";
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: RadioListTile<String>(
                      // 設定此選項 value
                      value: 'Chinese',
                      // Set option name、color
                      title: const Text(
                        '中文',
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                      //  如果Radio的value和groupValu一樣就是此 Radio 選中其他設置為不選中
                      groupValue: recognitionLanguage,
                      // 設定選種顏色
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          // 將 recognitionLanguage 設為 Taiwanese
                          recognitionLanguage = "Chinese";
                        });
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                tmpEvent = "";
              },
              child: const Text('取消',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPlayPlaceName();
              },
              child: const Text('上一步',style: TextStyle(fontSize: 25)),
            ),
            TextButton(
              onPressed: () {
                if (bringThingController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請輸入必要資訊',style: TextStyle(fontSize: 30)),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  //Navigator.pop(context);
                  return;
                } else {
                  tmpBringThing = bringThingController.text;
                  tmpEvent = '和${tmpPlayName}去${tmpPlayPlace}，在${tmpGatherPlace}集合，時間是${tmpPlayTime}，要記得帶${tmpBringThing}。';
                  //print(tmpEvent);
                  String month = '';
                  String day = '';
                  if(selectedCalendarDate!.month < 10){
                    month = '0' + selectedCalendarDate!.month.toString();
                  }
                  else{
                    month = selectedCalendarDate!.month.toString();
                  }
                  if(selectedCalendarDate!.day < 10){
                    day = '0' + selectedCalendarDate!.day.toString();
                  }
                  else{
                    day = selectedCalendarDate!.day.toString();
                  }
                  String date = selectedCalendarDate!.year.toString() + month + day;
                  insertData(date, '出遊', tmpEvent);
                  setState(() {
                    if (mySelectedEvents[selectedCalendarDate] != null) {
                      mySelectedEvents[selectedCalendarDate]?.add(MyEvents(
                          eventTitle: '出遊',
                          eventDescp: tmpEvent
                      ));
                    } else {
                      mySelectedEvents[selectedCalendarDate!] = [
                        MyEvents(
                            eventTitle: '出遊',
                            eventDescp: tmpEvent)
                      ];
                    }
                  });
                  Navigator.pop(context);
                  return;
                }
              },
              child: const Text('確認',style: TextStyle(fontSize: 25)),
            ),
          ],
        ));
  }

  Future<void> insertData(String date, String title, String description) async{
    final res = await http.get(Uri.parse('http://192.168.208.168:30011/insert_data/$date/$title/$description'));

    if(res.statusCode == 200){
      print('Success');
      return;
    }
    else{
      throw Exception('Failed to load : ${res.body}');
    }
  }

  Future<void> getData() async{
    final res = await http.get(Uri.parse('http://192.168.208.168:30011/get_data/'));

    if(res.statusCode == 200){
      final jso = json.decode(res.body);
      final length = jso.length;
      print(jso);
      //print(json.length);
      for(int i = 0; i < length; i++){
        String date = jso[i]['date'];
        String title = jso[i]['title'];
        String des = jso[i]['description'];
        int date_num = int.parse(date);
        String year = date.substring(0, 4);
        String month = date.substring(4, 6);
        String day = date.substring(6);
        DateTime dateTime = DateTime.parse(year + '-' + month + '-' + day + ' 00:00:00Z');
        //print(year);
        //print(month);
        //print(day);
        //print(dateTime);

        setState((){
          //print('a');
          if (mySelectedEvents[dateTime] != null) {
            //print('b');
            mySelectedEvents[dateTime]?.add(MyEvents(
                eventTitle: title,
                eventDescp: des
            ));
            print(mySelectedEvents[dateTime]);
          } else {
            //print('c');
            mySelectedEvents[dateTime] = [
              MyEvents(
                  eventTitle: title,
                  eventDescp: des)
            ];
            print(mySelectedEvents[dateTime]);
          }
        });

      }

    }
    else{
      throw Exception('Failed to load: ${res.body}');
    }
  }

  Future play(String pathToReadAudio) async {
    await player.play(pathToReadAudio);
    setState(() {
      player.init();
      player.isPlaying;
    });
  }

  Future<void> deleteData(String date, String title, String description) async{
    final res = await http.get(Uri.parse('http://192.168.208.168:30011/delete_data/$date/$title/$description'));

    if(res.statusCode == 200){
      print('Success');
      return;
    }
    else{
      throw Exception('Failed to load : ${res.body}');
    }
  }

  Widget buildTextField(
      {String? hint, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,

      decoration: InputDecoration(
        labelText: hint ?? '',
        labelStyle: TextStyle(fontSize: 25),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(
            10.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(
            10.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語音行事曆',style: TextStyle(fontSize: 35)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _chooseEventDialog(),
        label: const Text('新增活動',style: TextStyle(fontSize: 30)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(8.0),
              elevation: 5.0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
                side: BorderSide(color: Colors.black, width: 3.0),
              ),
              child: TableCalendar(
                locale: 'zh_CN',
                focusedDay: _focusedCalendarDate,
                // today's date
                firstDay: _initialCalendarDate,
                // earliest possible date
                lastDay: _lastCalendarDate,
                // latest allowed date
                calendarFormat: CalendarFormat.month,
                // default view when displayed
                // default is Saturday & Sunday but can be set to any day.
                // instead of day number can be mentioned as well.
                weekendDays: const [DateTime.sunday, 6],
                // default is Sunday but can be changed according to locale
                startingDayOfWeek: StartingDayOfWeek.monday,
                // height between the day row and 1st date row, default is 16.0
                daysOfWeekHeight: 60.0,
                // height between the date rows, default is 52.0
                rowHeight: 80.0,
                // this property needs to be added if we want to show events
                eventLoader: _listOfDayEvents,
                // Calendar Header Styling
                headerStyle: const HeaderStyle(
                  titleTextStyle:
                  TextStyle(color: Colors.white, fontSize: 30.0),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10))),
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AppColors.babyPowder,
                    size: 30,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AppColors.babyPowder,
                    size: 30,
                  ),
                ),
                // Calendar Days Styling
                daysOfWeekStyle: const DaysOfWeekStyle(
                  // Weekend days color (Sat,Sun)
                  weekendStyle: TextStyle(color: Colors.red,fontSize: 25),
                  weekdayStyle: TextStyle(color: Colors.black,fontSize: 25),
                ),
                // Calendar Dates styling
                calendarStyle: const CalendarStyle(
                  defaultTextStyle: TextStyle(color: Colors.black,fontSize: 25),
                  // Weekend dates color (Sat & Sun Column)
                  weekendTextStyle: TextStyle(color: Colors.red,fontSize: 25),
                  selectedTextStyle: TextStyle(color: Colors.white,fontSize: 35),
                  // highlighted color for today
                  todayTextStyle: TextStyle(color: Colors.black,fontSize: 25),
                  todayDecoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  // highlighted color for selected day
                  selectedDecoration: BoxDecoration(
                    color: AppColors.blackCoffee,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                      color: AppColors.ultraRed, shape: BoxShape.circle),
                ),
                selectedDayPredicate: (currentSelectedDate) {
                  // as per the documentation 'selectedDayPredicate' needs to determine
                  // current selected day
                  return (isSameDay(
                      selectedCalendarDate!, currentSelectedDate));
                },
                onDaySelected: (selectedDay, focusedDay) {
                  // as per the documentation
                  if (!isSameDay(selectedCalendarDate, selectedDay)) {
                    setState(() {
                      selectedCalendarDate = selectedDay;
                      _focusedCalendarDate = focusedDay;
                    });
                  }
                },
              ),
            ),
            ..._listOfDayEvents(selectedCalendarDate!).map(
                  (myEvents) => ListTile(
                leading: IconButton(
                  icon: const Icon(
                    Icons.volume_up,
                    color: Colors.orange,
                    size: 30,
                  ),
                  onPressed: () async {
                    // 得到 TextField 中輸入的 value
                    String strings = myEvents.eventDescp;
                    // 如果為空則 return
                    if (strings.isEmpty) return;
                    // connect to text2speech socket
                    await Text2Speech().connect(play, strings, "taiwanese");
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.orange,
                    size: 30,
                  ),
                  onPressed: () async {
                    String month = '';
                    String day = '';
                    if(selectedCalendarDate!.month < 10){
                      month = '0' + selectedCalendarDate!.month.toString();
                    }
                    else{
                      month = selectedCalendarDate!.month.toString();
                    }
                    if(selectedCalendarDate!.day < 10){
                      day = '0' + selectedCalendarDate!.day.toString();
                    }
                    else{
                      day = selectedCalendarDate!.day.toString();
                    }
                    String date = selectedCalendarDate!.year.toString() + month + day;
                    await deleteData(date, myEvents.eventTitle, myEvents.eventDescp);
                    // 得到 TextField 中輸入的 value

                    setState((){
                      //print('b');
                      mySelectedEvents[selectedCalendarDate]?.remove(
                          myEvents
                      );
                      print(mySelectedEvents[selectedCalendarDate]);
                    });
                  },
                ),
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(myEvents.eventTitle,style: TextStyle(fontSize: 35)),
                ),
                subtitle: Text(myEvents.eventDescp,style: TextStyle(fontSize: 30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyEvents {
  final String eventTitle;
  final String eventDescp;

  MyEvents({required this.eventTitle, required this.eventDescp});

  @override
  String toString() => eventTitle;
}
