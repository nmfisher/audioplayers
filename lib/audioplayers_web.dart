import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

final AudioContext _audioCtx = AudioContext();

class WrappedPlayer {
  double startingPoint;
  double soughtPosition;
  double pausedAt = null;
  double currentVolume = 1.0;
  bool isPlaying = false;

  AudioBuffer currentBuffer;
  AudioBufferSourceNode currentNode;
  GainNode gainNode;

  void setBuffer(AudioBuffer buffer) {
    stop();
    currentBuffer = buffer;
    recreateNode();
    if (isPlaying) {
      resume();
    }
  }

  static const int _int32Divisor = 2147483648;
  ByteData _int32ToFloat32(ByteData source, int sampleRate, int numChannels) {
      var newBuf = ByteData(source.lengthInBytes);
      for(int i = 0 ; i < source.lengthInBytes; i+=4) {
        int val = source.getInt32(i, Endian.little);
        newBuf.setFloat32(i,  val / _int32Divisor, Endian.little);
      }
      return newBuf;  
  }

  static const int _int16Divisor = 32768;
  ByteData _int16ToFloat32(ByteData source, int sampleRate, int numChannels) {
    var newBuf = ByteData(source.lengthInBytes * 2);
    for(int i = 0 ; i < source.lengthInBytes;i+=2) {
      int val = source.getInt16(i, Endian.little);
      double floatVal = val / _int16Divisor;

      newBuf.setFloat32(i*2, floatVal, Endian.little);

    }
    return newBuf;  
  }


  void playBuffer(ByteBuffer buffer, int sampleRate, int numChannels, int bitDepth) async {
    var view = buffer.asByteData(44);
    int numFrames = view.lengthInBytes ~/ (bitDepth ~/ 8) ~/ numChannels; 
    print("Playing audio buffer of length ${buffer.lengthInBytes}, sample rate $sampleRate, bitDepth $bitDepth and numFrames $numFrames");
    AudioBuffer _audioBuf = _audioCtx.createBuffer(numChannels, numFrames, sampleRate);
    // need to convert from 16/32 bit PCM to 32 bit float
    ByteData converted = bitDepth == 16 ? _int16ToFloat32(view, sampleRate, numChannels) : _int32ToFloat32(view, sampleRate, numChannels);

    _audioBuf.copyToChannel(converted.buffer.asFloat32List(), 0);
    setBuffer(_audioBuf);
    start(0);
  }

  void setVolume(double volume) {
    currentVolume = volume;
    gainNode.gain.value = currentVolume;
  }

  void recreateNode() {
    currentNode = _audioCtx.createBufferSource();
    currentNode.buffer = currentBuffer;

    gainNode = _audioCtx.createGain();

    gainNode.connectNode(_audioCtx.destination);

    currentNode.connectNode(gainNode);
  }

  void start(double position) {
    isPlaying = true;
    if (currentBuffer == null) {
      return; // nothing to play yet
    }
    if (currentNode == null) {
      recreateNode();
    }
    startingPoint = _audioCtx.currentTime;
    gainNode.gain.setValueAtTime(0, startingPoint);
    gainNode.gain.linearRampToValueAtTime(currentVolume, startingPoint + 0.03);
    gainNode.gain.setValueAtTime(currentVolume, startingPoint + currentBuffer.duration - 0.03);
    gainNode.gain.linearRampToValueAtTime(0, startingPoint + currentBuffer.duration);

    soughtPosition = position;
    currentNode.start(startingPoint, soughtPosition);
  }

  void resume() {
    start(pausedAt ?? 0);
  }

  void pause() {
    pausedAt = _audioCtx.currentTime - startingPoint + soughtPosition;
    _cancel();
  }

  void stop() {
    pausedAt = 0;
    _cancel();
  }

  void _cancel() {
    isPlaying = false;
    currentNode?.stop();
    currentNode = null;
  }
}

class AudioplayersPlugin {
  // players by playerId
  Map<String, WrappedPlayer> players = {};

  // cache of pre-loaded buffers by URL
  Map<String, AudioBuffer> preloadedBuffers = {};

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'xyz.luan/audioplayers',
      const StandardMethodCodec(),
      registrar.messenger,
    );

    final AudioplayersPlugin instance = AudioplayersPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

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

  Future<WrappedPlayer> setUrl(String playerId, String url) async {
    final WrappedPlayer player = getOrCreatePlayer(playerId);
    final AudioBuffer buffer = await loadAudio(url);
    player.setBuffer(buffer);
    return player;
  }

  WrappedPlayer playBuffer(String playerId, ByteBuffer buffer, int numChannels,
      int sampleRate, int bitDepth) {
    final WrappedPlayer player = getOrCreatePlayer(playerId);
    player.playBuffer(buffer, sampleRate, numChannels, bitDepth);
    return player;
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    final method = call.method;
    final playerId = call.arguments['playerId'];
    switch (method) {
      case 'setUrl':
        {
          final String url = call.arguments['url'];
          await setUrl(playerId, url);
          return 1;
        }
      case 'play':
        {
          final String url = call.arguments['url'];
          final bool isLocal = call.arguments['isLocal'];
          double volume = call.arguments['volume'] ?? 1.0;
          final double position = call.arguments['position'] ?? 0;
          // web does not care for the `stayAwake` argument

          final player = await setUrl(playerId, url);
          player.setVolume(volume);
          player.start(position);

          return 1;
        }
      case 'playBuffer':
        {
          final Uint8List buffer = call.arguments['buffer'];
          final int numChannels = call.arguments['numChannels'];
          final int sampleRate = call.arguments['sampleRate'];
          final int bitDepth = call.arguments['bitDepth'];

          playBuffer(playerId, buffer.buffer, numChannels, sampleRate, bitDepth);

          return 1;
        }
      case 'pause':
        {
          getOrCreatePlayer(playerId).pause();
          return 1;
        }
      case 'stop':
        {
          getOrCreatePlayer(playerId).stop();
          return 1;
        }
      case 'resume':
        {
          getOrCreatePlayer(playerId).resume();
          return 1;
        }
      case 'setVolume':
        {
          double volume = call.arguments['volume'] ?? 1.0;
          getOrCreatePlayer(playerId).setVolume(volume);
          return 1;
        }
      case 'release':
      case 'seek':
      case 'setReleaseMode':
      case 'setPlaybackRate':
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              "The audioplayers plugin for web doesn't implement the method '$method'",
        );
    }
  }
}
