import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gaorre/provider/Data/UserLogProvider.dart';
import 'package:gaorre/provider/Data/waitingDataProvider.dart';
import 'package:gaorre/provider/Network/stompClientStateNotifier.dart';
import 'package:gaorre/presenter/Widget/AlertDialog.dart';
import 'package:gaorre/services/HIVE_service.dart';
import 'package:gaorre/services/HTTP_service.dart';
import '../../Model/LoginDataModel.dart';

// LoginInfo 객체를 관리하는 프로바이더를 정의합니다.
final loginProvider =
    StateNotifierProvider<LoginDataNotifier, LoginData?>((ref) {
  return LoginDataNotifier(null); // 초기 상태를 null로 설정합니다.
});

// StateNotifier를 확장하여 LoginInfo 객체를 관리하는 클래스를 정의합니다.
class LoginDataNotifier extends StateNotifier<LoginData?> {
  LoginDataNotifier(LoginData? initialState) : super(initialState);

  void saveLoginData() async {
    // _storage.write(key: 'userID', value: adminPhoneNumber);
    try {
      LoginData? currentState = state;
      if (currentState != null) {
        await HiveService.saveData('loginData', currentState.toJson());
        print('[saveLoginData] 성공! [loginProvider]');
      } else {
        print('[saveLoginData] null값은 저장하지 않습니다. [loginProvider]');
        return;
      }
    } catch (error) {
      print('[saveLoginData] 실패. 에러 : $error [loginProvider]');
    }
  }

  void logout(WidgetRef ref) async {
    print('로그아웃 요청 [loginProvider]');
    HiveService.deleteData('phoneNumber');
    HiveService.deleteData('password');
    ref.read(waitingProvider.notifier).unSubscribe(0);
    ref.read(waitingProvider.notifier).resetState();
    ref.read(userLogProvider.notifier).unSubscribe(1);
    ref.read(userLogProvider.notifier).resetState();
    ref.read(stompClientStateNotifierProvider.notifier).client = null;
    state = null;
  }

  Future<bool> resetPassword(WidgetRef ref, String adminPhoneNumber,
      String newPassword, String authCode) async {
    final jsonBody = json.encode({
      "adminPhoneNumber": adminPhoneNumber,
      "verificationCode": authCode,
      "newAdminPassword": newPassword,
    });
    try {
      final response =
          await HttpsService.postRequest('/StoreAdmin/login/reset', jsonBody);
      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        if (responseBody['status'] == '200') {
          print("비밀번호 변경 성공!");
          await HiveService.saveStringData('password', newPassword);
          await HiveService.saveStringData('phoneNumber', adminPhoneNumber);
          // await showAlertDialog(ref.context, "비밀번호 변경", "비밀번호 변경을 성공하였습니다.", null);
          return true;
        } else {
          print('비밀번호 변경 실패...');
          throw Exception('${responseBody['status']}');
        }
      } else {
        print('resetPassword 오류 ${response.statusCode}');
        throw Exception('HTTP${response.statusCode}');
      }
    } catch (error) {
      print('예기치 못한 에러 발생 [loginProvider - resetPassword]');
      await showAlertDialog(
          ref.context, "비밀번호 변경", "비밀번호 변경 실패\n에러코드:${error}", null);
      return false;
    }
  }

  Future<bool> loadLoginData() async {
    String? loginDataRaw = await HiveService.retrieveData('loginData');
    if (loginDataRaw == null) {
      updateState(null);
      return false;
    } else {
      Map<String, dynamic> loginDataJson = jsonDecode(loginDataRaw);
      LoginData newloginData = LoginData.fromJson(loginDataJson);
      updateState(newloginData);

      return true;
    }
  }

  void updateState(LoginData? newLoginData) {
    state = newLoginData;
    saveLoginData();
  }

  LoginData? getLoginData() {
    return state;
  }

  Future<bool> requestAutoLogin() async {
    print('[자동 로그인 요청...] [loginProvider]');
    String? adminPhoneNumber = await HiveService.retrieveData('phoneNumber');
    String? password = await HiveService.retrieveData('password');
    if (adminPhoneNumber != null && password != null) {
      if (true == await requestLoginData(adminPhoneNumber, password)) {
        print('자동 로그인 성공!! [loginProvider]');
        return true;
      } else {
        print('자동 로그인에 실패했습니다.');
        return false;
      }
    } else {
      return false;
    }
  }

  Future<bool> requestLoginData(
      String? adminPhoneNumber, String? password) async {
    print('[로그인 요청...] [loginProvider]');
    if (adminPhoneNumber == null || password == null) {
      print(
          '아이디 혹은 비밀번호가 공백입니다. 자동로그인을 실패했습니다. 로그인 화면으로 이동합니다. [loginProvider]');
      return false;
    }
    String? token = await FirebaseMessaging.instance.getToken();
    print(
        "FCMtoken : ${token ?? 'token NULL!'} [loginProvider - requestLoginData]");
    try {
      final jsonBody = json.encode({
        "adminPhoneNumber": adminPhoneNumber,
        "adminPassword": password,
        "adminFcmToken": token,
      });
      final response =
          await HttpsService.postRequest('/StoreAdmin/login', jsonBody);
      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        if (responseBody['status'] == "200") {
          print('로그인 성공 [loginProvider]');
          print(responseBody.toString());
          // 자동로그인을 위한 데이터 저장
          await HiveService.saveStringData('phoneNumber', adminPhoneNumber)
              .then((value) => {
                    HiveService.saveStringData('password', password)
                        .then((value) => {print('[자동로그인을 위한 데이터 저장 성공]')})
                  });
          LoginData? loginResponse = LoginData.fromJson(responseBody);
          updateState(loginResponse);
          return true;
        } else {
          print('로그인에 실패하였습니다. [loginProvider]');
          return false;
        }
      } else {
        print('에러발생. 다음은 에러내용 [loginProvider]');
        print(response.body);
        return false;
      }
    } catch (error) {
      print('에러 발생 $error [loginProvider]');
      return false;
    }
  }
}

// Legacy
class LoginProviderLegacy {
  // StompClient 인스턴스를 설정하는 메소드
  // void setClient(StompClient client) {
  //   print("<LoginProvider> 스텀프 연결 설정");
  //   _client = client; // 내부 변수에 StompClient 인스턴스 저장
  // }

  //   void subscribeToLoginData(BuildContext context, String adminPhoneNumber) {
  //   if (nowSubscribe != null) {
  //     unSubscribeLoginData();
  //   }
  //   nowSubscribe = _client?.subscribe(
  //     destination: '/topic/admin/StoreAdmin/login/$adminPhoneNumber',
  //     callback: (StompFrame frame) {
  //       print("<LoginData>를 구독중입니다.");
  //       print('<LoginData> 정보 수신. 다음은 수신된 메세지');
  //       print(frame.body.toString());
  //       Map<String, dynamic> responseData = json.decode(frame.body ?? '');
  //       LoginData loginResponse = LoginData.fromJson(responseData);
  //       if (loginResponse.status == 'success') {
  //         print('<LoginProvider> 로그인 성공');
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) =>
  //                 StoreScreenWidget(loginResponse: loginResponse),
  //           ),
  //         );
  //         showDialog(
  //           context: context,
  //           builder: (context) {
  //             return AlertDialog(
  //                 title: Text('Login Succeeded'),
  //                 content: Text('Welcome!'),
  //                 actions: <Widget>[
  //                   TextButton(
  //                     onPressed: () {
  //                       Navigator.of(context).pop();
  //                     },
  //                     child: Text('OK'),
  //                   ),
  //                 ]);
  //           },
  //         );
  //       } else if (loginResponse.status == 'failure') {
  //         print('<LoginProvider> 로그인 실패');
  //         showDialog(
  //           context: context,
  //           builder: (context) {
  //             return AlertDialog(
  //               title: Text('Login Failed'),
  //               content: Text('Invalid ID or Password.'),
  //               actions: <Widget>[
  //                 TextButton(
  //                   onPressed: () {
  //                     Navigator.of(context).pop();
  //                   },
  //                   child: Text('OK'),
  //                 ),
  //               ],
  //             );
  //           },
  //         );
  //       }
  //     },
  //   );
  // }

  // void unSubscribeLoginData() {
  //   print("<LoginData> 구독 해제.");
  //   nowSubscribe(unsubscribeHeaders: null);
  // }

  // // Logindata를 보내는 메서드
  // void sendLoginData(BuildContext context, String adminPhoneNumber, String pw) {
  //   print("<LoginData> 로그인 정보 송신 : $adminPhoneNumber, $pw");
  //   _client?.send(
  //     destination: '/app/admin/StoreAdmin/login/$adminPhoneNumber',
  //     body: json.encode({
  //       "adminPhoneNumber": adminPhoneNumber,
  //       "adminPassword": pw,
  //     }),
  //   );
  // }

  // @override
  // void dispose() {
  //   _client?.deactivate();
  //   super.dispose();
  // }
}
