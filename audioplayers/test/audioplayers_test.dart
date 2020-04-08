import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/half.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<MethodCall> calls = [];
  const channel = const MethodChannel('xyz.luan/audioplayers');
  channel.setMockMethodCallHandler((MethodCall call) {
    calls.add(call);
    return null;
  });

  MethodCall popCall() {
    expect(calls, hasLength(1));
    return calls.removeAt(0);
  }

  group('AudioPlayers', () {
  //   test('#play', () async {
  //     calls.clear();
  //     AudioPlayer player = AudioPlayer();
  //     await player.play('internet.com/file.mp3');
  //     MethodCall call = popCall();
  //     expect(call.method, 'play');
  //     expect(call.arguments['url'], 'internet.com/file.mp3');
  //   });

  //   test('multiple players', () async {
  //     calls.clear();
  //     AudioPlayer player1 = AudioPlayer();
  //     AudioPlayer player2 = AudioPlayer();

  //     await player1.play('internet.com/file.mp3');
  //     MethodCall call = popCall();
  //     String player1Id = call.arguments['playerId'];
  //     expect(call.method, 'play');
  //     expect(call.arguments['url'], 'internet.com/file.mp3');

  //     await player1.play('internet.com/file.mp3');
  //     expect(popCall().arguments['playerId'], player1Id);

  //     await player2.play('internet.com/file.mp3');
  //     expect(popCall().arguments['playerId'], isNot(player1Id));

  //     await player1.play('internet.com/file.mp3');
  //     expect(popCall().arguments['playerId'], player1Id);
  //   });

  //   test('#resume, #pause and #duration', () async {
  //     calls.clear();
  //     AudioPlayer player = AudioPlayer();
  //     await player.setUrl('assets/audio.mp3');
  //     expect(popCall().method, 'setUrl');

  //     await player.resume();
  //     expect(popCall().method, 'resume');

  //     await player.getDuration();
  //     expect(popCall().method, 'getDuration');

  //     await player.pause();
  //     expect(popCall().method, 'pause');
  //   });

    // test('#playBuffer', () async {
    //   calls.clear();
    //   AudioPlayer player = AudioPlayer();
    //   var ping = await File('assets/ping.wav').readAsBytes();
      
    //   await player.playBuffer(ping.cast<int>(), 2, 44100);
    //   MethodCall call = popCall();
    //   expect(call.method, 'playBuffer');
    //   expect(call.arguments['url'], 'internet.com/file.mp3');
    // });

     test('#playBuffer', () async {
      calls.clear();
      AudioPlayer player = AudioPlayer();

      // var test = ByteData(8);
      // test.setUint16(0, 0x41FE, Endian.little);
      // test.setUint16(2, 0x2225, Endian.little);
      // test.setUint16(4, 0xBA17, Endian.little);
      // test.setUint16(6, 0x0000, Endian.little);
      // print(Half.ToFloat32(test).buffer.asFloat32List());
      var test = await File('test_mono_16b_le.wav').readAsBytes();
      // var converted = Half.ToFloat32(test.buffer.asByteData());
      // File('test_mono_32b_le.bin').writeAsBytesSync(converted.buffer.asUint8List());

      var output = ByteData(test.buffer.lengthInBytes * 2);
      for(var i = 0; i < test.lengthInBytes; i+=2) {
        var sample = test.buffer.asByteData().getInt16(i);
        output.setInt32(i*2, sample);
      }
      File('test_mono_32bit_PCM_le.bin').writeAsBytesSync(output.buffer.asUint8List());

    });
  });
}

