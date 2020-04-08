import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'wrapped_player.dart';


class AudioPlayerPlugin extends AudioPlayerPlatform {

  final AudioContext _audioCtx = AudioContext();
  
   /// Registers this class as the default instance of [AudioPlayerPlatform].
  static void registerWith(Registrar registrar) {
    AudioPlayerPlatform.instance = AudioPlayerPlugin();
  }

  // players by playerId
  Map<String, WrappedPlayer> players = {};

  // cache of pre-loaded buffers by URL
  Map<String, AudioBuffer> preloadedBuffers = {};

  Future<AudioBuffer> loadAudio(String url) async {
    if (preloadedBuffers.containsKey(url)) {
      return preloadedBuffers[url];
    }

    final HttpRequest response =
        await HttpRequest.request(url, responseType: 'arraybuffer');
    final AudioBuffer buffer =
        await _audioCtx.decodeAudioData(response.response);
    return preloadedBuffers.putIfAbsent(url, () => buffer);
  }

  WrappedPlayer getOrCreatePlayer(String playerId) {
    return players.putIfAbsent(playerId, () => WrappedPlayer());
  }

  Future<int> setUrl(String url, {bool isLocal: false, bool respectSilence = false}) async {
    final WrappedPlayer player = getOrCreatePlayer("default");
    final AudioBuffer buffer = await loadAudio(url);
    player.setBuffer(buffer);
    return 1;
  }

  Future<int> playBuffer(Uint8List buffer, int numChannels,
      int sampleRate, int bitDepth) async {
    final WrappedPlayer player = getOrCreatePlayer("default");
    player.playBuffer(buffer.buffer, sampleRate, numChannels, bitDepth);
    return 1;
  }

  Future<int> play(
    String url, {
    bool isLocal,
    double volume = 1.0,
    // position must be null by default to be compatible with radio streams
    Duration position,
    bool respectSilence = false,
    bool stayAwake = false,
  }) async {
    print("Playing!");
    await setUrl(url);
    final player = getOrCreatePlayer("default");
    player.setVolume(volume);
    player.start(position?.inMilliseconds ?? 0);
  }

  Future<int> pause() async {
    getOrCreatePlayer("default").pause();
  }

  Future<int> stop() async {
    getOrCreatePlayer("default").stop();
  }

  Future<int> resume() async {
    getOrCreatePlayer("default").resume();
  }

  Future<int> setVolume(double volume) {
    volume = volume ?? 1.0;
    getOrCreatePlayer("default").setVolume(volume);  
  }
}
