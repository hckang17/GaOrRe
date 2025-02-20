import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gaorre/widget/text/text_widget.dart';

class ServerErrorScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final stomp = ref.watch(stompClientStateNotifierProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextWidget('서버 에러가 발생했습니다.'),
            TextWidget('앱을 종료하고, 잠시 후에 다시 실행해주세요.'),
            TextWidget('오류가 반복되면 관리자에게 문의해주세요'),
            TextWidget('010-3546-3360'),
          ],
        ),
      ),
    );
  }
}
