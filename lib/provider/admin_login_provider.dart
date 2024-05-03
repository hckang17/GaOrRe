import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:orre_manager/Coding_references/login.dart';
import 'package:orre_manager/presenter/store_screen.dart';
import 'package:orre_manager/services/http_service.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../Model/login_data_model.dart';

// LoginInfo 객체를 관리하는 프로바이더를 정의합니다.
final loginProvider =
    StateNotifierProvider<LoginDataNotifier, LoginData?>((ref) {
  return LoginDataNotifier(null); // 초기 상태를 null로 설정합니다.
});

// StateNotifier를 확장하여 LoginInfo 객체를 관리하는 클래스를 정의합니다.
class LoginDataNotifier extends StateNotifier<LoginData?> {
  StompClient? _client; // StompClient 인스턴스를 저장할 내부 변수 추가
  dynamic nowSubscribe;

  LoginDataNotifier(LoginData? initialState) : super(initialState);

  // StompClient 인스턴스를 설정하는 메소드
  void setClient(StompClient client) {
    print("<LoginProvider> 스텀프 연결 설정");
    _client = client; // 내부 변수에 StompClient 인스턴스 저장
  }

  Future<void> requestLoginData(BuildContext context, String adminPhoneNumber, String password) async {
    print('[로그인 데이터 요청]');
    final jsonBody = json.encode({
        "adminPhoneNumber": adminPhoneNumber,
        "adminPassword": password,
    });
    final response = await HttpsService.postRequest('/login', jsonBody);
    if(response.statusCode == 200){
      final responseBody = json.decode(utf8.decode(response.bodyBytes));
      if(responseBody['status'] == "success"){
        print('로그인 성공');
        print(responseBody.toString());
        LoginData? loginResponse = LoginData.fromJson(responseBody);
        state = loginResponse;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder : (context) => StoreScreenWidget(loginResponse: loginResponse),
          )
        );
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('로그인 성공'),
              content: Text('환영합니다.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ]
            );
          },
        );
      } else {
        print('로그인에 실패하였습니다.');
        return;
      }
    } else {
      print('에러발생. 다음은 에러내용');
      print(response.body);
    }
  }
}

// Legacy
class LoginProviderLegacy {
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
