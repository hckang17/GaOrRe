import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orre_manager/presenter/Widget/WaitingPage/AddWaitingPopup.dart';
import 'package:orre_manager/presenter/Widget/WaitingPage/CallButton.dart';
import 'package:orre_manager/presenter/MainScreen/management_screen.dart';
import 'package:orre_manager/presenter/MainScreen/table_status_screen.dart';
import 'package:orre_manager/provider/Data/loginDataProvider.dart';
import 'package:orre_manager/Coding_references/stompClientFutureProvider.dart';
import 'package:orre_manager/provider/Data/waitingAvailableStatusProvider.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../../Model/login_data_model.dart';
import '../../Model/waiting_data_model.dart';
import '../../provider/Data/waitingDataProvider.dart';

class StoreScreenWidget extends ConsumerWidget {
  StoreScreenWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final stompClientAsyncValue = ref.watch(stompClientProvider);

    // return stompClientAsyncValue.when(
    //   data: (stompClient) => StoreScreenBody(loginData: loginResponse),
    //   loading: () => _LoadingScreen(),
    //   error: (error, stackTrace) => _ErrorScreen(error),
    // );
    return StoreScreenBody();
  }
}

class StoreScreenBody extends ConsumerStatefulWidget {
  StoreScreenBody();

  @override
  StoreScreenBodyState createState() => StoreScreenBodyState();
}

class StoreScreenBodyState extends ConsumerState<StoreScreenBody> {
  late int storeCode;
  late LoginData? loginData;
  late int waitingAvailableState;
  int minutesToAdd = 1;
  WaitingData? currentWaitingData;
  bool isSubscribed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loginData = ref.read(loginProvider.notifier).getLoginData();
    storeCode = loginData!.storeCode;
    // waitingAvailableState = ref.read(waitingAvailableStatusStateProvider.notifier).loadWaitingAvailableStatus();
    final waitingNotifier = ref.read(waitingProvider.notifier);
    if (!isSubscribed) {
      waitingNotifier.subscribeToWaitingData(storeCode);
      waitingNotifier.sendWaitingData(storeCode);
      isSubscribed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    waitingAvailableState = ref.watch(waitingAvailableStatusStateProvider);
    currentWaitingData = ref.watch(waitingProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Store Page')),
      body: currentWaitingData == null
          ? _LoadingScreen()
          : buildWaitingScreen(),
      floatingActionButton: buildAddingWaitingTeam(),
    );
  }

  Widget buildInitialScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('매장코드 : $storeCode', style: TextStyle(fontSize: 20)),
          ElevatedButton(
            onPressed: () {ref.read(waitingProvider.notifier).sendWaitingData(loginData!.storeCode);}, // No action needed, already subscribed and data sent
            child: Text("웨이팅정보 수신하기"),
          ),
        ],
      ),
    );
  }

  Widget buildWaitingScreen() {
    _startTimerForTeamDeletion(ref);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Consumer(
            builder: (context, ref, child) {
              ref.watch(waitingProvider);
              final currentWaitingCount = ref.watch(waitingProvider.select((data) => data?.teamInfoList.length ?? 0));
              return Text('현재 대기 팀수 : $currentWaitingCount', style: TextStyle(fontSize: 24));
            },
          ),
          ElevatedButton(onPressed: () {
            ref.read(loginProvider.notifier).logout();
            Navigator.pop(context);
            }, child: Text('로그아웃')),
          ElevatedButton(onPressed: () {
            ref.read(waitingAvailableStatusStateProvider.notifier).changeAvailableStatus(loginData!);
            }, 
            child: Text('현재 웨이팅 가능 상태 : $waitingAvailableState. 0이면 웨이팅추가가능, 1이면 웨이팅추가불가')
            ),
          Expanded(
            child: ListView.builder(
              itemCount: currentWaitingData!.teamInfoList.length,
              itemBuilder: (context, index) {
                WaitingTeam? team = currentWaitingData!.teamInfoList[index];
                return ListTile(
                  title: Text('예약 번호 : ${team.waitingNumber}'),
                  subtitle: buildSubtitle(team),
                  trailing: buildTrailingButtons(team, ref),
                );
              },
            ),
          ),
          buildFooterButtons(),
        ],
      ),
    );
  }

  Column buildSubtitle(WaitingTeam team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('상태 : ${_getGuestStatus(team.status)}'),
        Text('연락처 : ${team.phoneNumber}'),
        if (team.entryTime != null)
          StreamBuilder<Duration>(
            stream: startCountdown(team.entryTime),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('Calculating...');
              } else if (snapshot.hasData) {
                final mins = snapshot.data!.inMinutes.remainder(60).toString().padLeft(2, '0');
                final secs = snapshot.data!.inSeconds.remainder(60).toString().padLeft(2, '0');
                return Text('입장마감까지 남은 시간 : $mins:$secs');
              } else {
                return Text('Time expired');
              }
            },
          ),
      ],
    );
  }

  Row buildTrailingButtons(WaitingTeam team, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CallIconButton(
          phoneNumber: team.phoneNumber,
          waitingNumber: team.waitingNumber,
          storeCode: storeCode,
          minutesToAdd: minutesToAdd,
          ref: ref,
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => ref.read(waitingProvider.notifier).requestUserDelete(ref.context, storeCode, team.waitingNumber),
          child: const Text('웨이팅 삭제하기'),
        ),
      ],
    );
  }

  Row buildFooterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () {
            ref.read(waitingProvider.notifier).requestUserCall(
              ref.context,
              currentWaitingData!.teamInfoList[0].phoneNumber,
              currentWaitingData!.teamInfoList[0].waitingNumber,
              storeCode,
              minutesToAdd);
          },
          child: Text('다음손님 호출하기'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ref.context).push(MaterialPageRoute(
              builder: (BuildContext context) =>
                ManagementScreenWidget()));
          },
          child: Text('가게 정보 수정하기'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ref.context).push(MaterialPageRoute(
              builder: (BuildContext context) =>
                TableManagementScreen()));
          },
          child: Text('테이블 관리하기'),
        ),
      ],
    );
  }

  Widget buildAddingWaitingTeam() {
    return FloatingActionButton(
      onPressed: () => showAddWaitingDialog(ref.context),
      child: Icon(Icons.person_add),
      tooltip: '웨이팅팀 수동 추가하기',);
  }

  String _getGuestStatus(int status) {
    switch (status) {
      case 1: return '대기중';
      case 2: return '착석 완료';
      case 3: return '삭제 완료';
      default: return 'Unknown';
    }
  }

  Stream<Duration> startCountdown(DateTime? startTime) {
    return Stream.periodic(Duration(seconds: 1), (count) {
      return startTime!.difference(DateTime.now());
    }).map((duration) => Duration(seconds: duration.inSeconds.abs()));
  }

  void _startTimerForTeamDeletion(WidgetRef ref) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      for (var team in currentWaitingData!.teamInfoList) {
        if (team.entryTime != null && team.entryTime!.difference(DateTime.now()) <= Duration.zero) {
          await ref.read(waitingProvider.notifier).requestUserDelete(ref.context, storeCode, team.waitingNumber);
          break;
        }
      }
    });
  }
}


class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manager screen')),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// class _ErrorScreen extends StatelessWidget {
//   final dynamic error;
  
//   _ErrorScreen(this.error);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Manager screen')),
//       body: Center(child: Text('Error: $error')),
//     );
//   }
// }