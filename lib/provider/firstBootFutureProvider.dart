// 처음 부팅할 때 필요한 초기화 작업을 수행하는 Provider

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orre_manager/provider/Data/loginDataProvider.dart';
import 'package:orre_manager/provider/Network/connectivityStateNotifier.dart';
import 'package:orre_manager/provider/Network/stompClientStateNotifier.dart';
import 'package:orre_manager/provider/errorStateNotifier.dart';
import 'package:orre_manager/services/hive_service.dart';

final firstBootState = StateProvider<bool>((ref) => false);

// final firstBootServiceProvider = Provider<FirstBootService>((ref) {
//   return FirstBootService(ref);
// });

class FirstBootService {
  static Future<bool> firstBoot(WidgetRef ref) async {
    try{
      print('하이브 저장소를 초기화합니다. [FIrstBootService]');
      await HiveService.initHive(); // 하이브 저장소를 초기화 해줌.
      print('자동 로그인을 실행합니다. [FIrstBootService]');
      await ref.read(loginProvider.notifier).requestAutoLogin();
      print('Websocket을 구동합니다. [FIrstBootService]');
      await ref.read(stompClientStateNotifierProvider.notifier).configureClient().listen((event) {
        print("!!!!!!!!!!!!!!!! 발생한 이벤트: $event [FIrstBootService]");
        if (event == StompStatus.CONNECTED) {
          print("웹소켓 연결됨..... [FIrstBootService]");
          ref.read(errorStateNotifierProvider.notifier).deleteError(Error.websocket);
        } else {
          print("웹소켓 연결되지 않음... [FIrstBootService]");
          ref.read(errorStateNotifierProvider.notifier).addError(Error.websocket);
        }
        print("웹소켓 관련 에러체크 완료. [FIrstBootService]");
      });
    }catch(error){
      print('최초부팅 오류 감지 : $error [FIrstBootService]');
      return false;
    }finally{
      ref.watch(firstBootState.notifier).state = true;
      print('최초부팅 완료... [firstBootService]');
    }
    return true;
  }
}

// final signInProvider = FutureProvider<void>((ref) async {
//   print("로그인 프로바이더 start [SignInProvider]");
//   Completer<void> completer = Completer();
//   bool alreadyLogged = false;  // 로그인 시도 여부를 추적하기 위한 변수

//   // networkStreamProvider를 구독하고, true가 되면 작업을 수행
//   ref.listen<bool>(networkStateNotifier, (prevState, newState) {
//     print("네트워크 status: $newState [SignInProvider]");
//     if (newState && !alreadyLogged) {  // newState가 true이고, alreadyLogged가 false인 경우에만 로그인 시도
//       alreadyLogged = true;  // 로그인 시도 시작을 표시
//       print("네트워크 연결 성공.. 로그인 준비중... [SignInProvider]");
//       ref.read(loginProvider.notifier).requestLoginData(null, null).then((value) {
//         if (value && !completer.isCompleted) {
//           print("로그인 성공 [SignInProvider]");
//           completer.complete();
//         } else if (!completer.isCompleted) {
//           print("로그인 실패: $value [SigninProvider]");
//           completer.completeError("로그인 실패 [SigninProvider]");
//         }
//       }).catchError((error) {
//         if (!completer.isCompleted) {
//           print("최초접속 로그인 에러: $error [SignInProvider]");
//           completer.completeError(error);
//         }
//       });
//     } else if (!newState) {
//       print("네트워크 대기중... [signInProvider]");
//     } 
//   });

//   // Completer의 Future를 반환하여, 외부에서 signInProvider의 완료를 기다릴 수 있도록 함
//   await completer.future;
// });

// final firstBootFutureProvider = FutureProvider<void>((ref) async {
//   final Completer<void> completer = Completer();
//   if (ref.watch(firstBootState.notifier).state) {
//     print("already booted [firstBoot]");
//     return;
//   }

//   print("[First Boot]시작됨");
//   try {
//     await ref.read(signInProvider.future);
//   } catch (error) {
//     print("로그인 에러 in error: $error [FirstBootProvider]");
//     completer.completeError(error);
//   } finally {
//     print('최초실행 로그인 프로세스 종료 ... STOMP 설정... [FIrstBootFutureProvider]');
//     if(ref.read(stompClientStateNotifierProvider) != null){
//       print('이미 STOMP Configure이 진행되어있습니다. [FirstBootFutureProvider]');
//       completer.complete();
//     } else {
//       await ref.read(stompClientStateNotifierProvider.notifier).configureClient().listen((event) {
//         print("!!!!!!!!!!!!!!!! 발생한 이벤트: $event [FirstBootFutureProvider]");
//         if (event == StompStatus.CONNECTED) {
//           print("웹소켓 연결됨..... [FirstBootFutureProvider]");
//           ref.read(errorStateNotifierProvider.notifier).deleteError(Error.websocket);
//         } else {
//           print("웹소켓 연결되지 않음... [FirstBootFutureProvider]");
//           ref.read(errorStateNotifierProvider.notifier).addError(Error.websocket);
//         }
//         // print("웹소켓 이벤트 문제없음~! [FirstBootFutureProvider]");
//         // print('이 프로바이더의 state는 ? -> ${ref.read(firstBootState).toString()} [FirstBootFutureProvider]');
//         completer.complete();
//       });
//     }
//   }
// });
