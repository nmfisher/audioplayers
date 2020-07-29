import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'audioplayers_platform_interface.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';


/// An implementation of [UrlLauncherPlatform] that uses method channels.
class MethodChannelAudioPlayer extends AudioPlayerPlatform {

  static MethodChannel _channel = MethodChannel('xyz.luan/audioplayers')..setMethodCallHandler(platformCallHandler);
  static MethodChannel _callbackChannel = MethodChannel('xyz.luan/audioplayers_callback')..setMethodCallHandler(platformCallHandler);

  static final _uuid = Uuid();

  /// Reference [Map] with all the players created by the application.
  ///
  /// This is used to exchange messages with the [MethodChannel]
  /// (there is only one).
  static final players = Map<String, MethodChannelAudioPlayer>();

  /// An unique ID generated for this instance of [AudioPlayer].
  ///
  /// This is used to properly exchange messages with the [MethodChannel].
  String playerId;

  /// Enables more verbose logging.
  static bool logEnabled = false;

  AudioPlayerState _audioPlayerState;

  AudioPlayerState get state => _audioPlayerState;

  MethodChannelAudioPlayer({PlayerMode mode = PlayerMode.MEDIA_PLAYER, this.playerId}) : super(mode:mode) {
    _channel.setMethodCallHandler(platformCallHandler);
    this.mode ??= PlayerMode.MEDIA_PLAYER;
    this.playerId ??= _uuid.v4();
    players[playerId] = this;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Start the headless audio service. The parameter here is a handle to
      // a callback managed by the Flutter engine, which allows for us to pass
      // references to our callbacks between isolates.
      // TODO - fix this - does this need the background audio permission in Info.plist?
      // final CallbackHandle handle =
      //     PluginUtilities.getCallbackHandle(_backgroundCallbackDispatcher);
      // assert(handle != null, 'Unable to lookup callback.');
      // _invokeMethod('startHeadlessService', {
      //   'handleKey': <dynamic>[handle.toRawHandle()]
      // });
    }
  }

// When we start the background service isolate, we only ever enter it once.
// To communicate between the native plugin and this entrypoint, we'll use
// MethodChannels to open a persistent communication channel to trigger
// callbacks.

/// Not implemented on macOS.
void _backgroundCallbackDispatcher() {
  const MethodChannel _channel =
      MethodChannel('xyz.luan/audioplayers_callback');

  // Setup Flutter state needed for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  // Reference to the onAudioChangeBackgroundEvent callback.
  Function(AudioPlayerState) onAudioChangeBackgroundEvent;

  // This is where the magic happens and we handle background events from the
  // native portion of the plugin. Here we message the audio notification data
  // which we then pass to the provided callback.
  _channel.setMethodCallHandler((MethodCall call) async {
    print("background callback received");
    Function _performCallbackLookup() {
      final CallbackHandle handle = CallbackHandle.fromRawHandle(
          call.arguments['updateHandleMonitorKey']);

      // PluginUtilities.getCallbackFromHandle performs a lookup based on the
      // handle we retrieved earlier.
      final Function closure = PluginUtilities.getCallbackFromHandle(handle);

      if (closure == null) {
        print('Fatal Error: Callback lookup failed!');
        // exit(-1);
      }
      return closure;
    }

    final Map<dynamic, dynamic> callArgs = call.arguments as Map;
    if (call.method == 'audio.onNotificationBackgroundPlayerStateChanged') {
      onAudioChangeBackgroundEvent ??= _performCallbackLookup();
      final String playerState = callArgs['value'];
      if (playerState == 'playing') {
        onAudioChangeBackgroundEvent(AudioPlayerState.PLAYING);
      } else if (playerState == 'paused') {
        onAudioChangeBackgroundEvent(AudioPlayerState.PAUSED);
      } else if (playerState == 'completed') {
        onAudioChangeBackgroundEvent(AudioPlayerState.COMPLETED);
      }
    } else {
      assert(false, "No handler defined for method type: '${call.method}'");
    }
  });
}

  Future<int> _invokeMethod(
    String method, [
    Map<String, dynamic> arguments,
  ]) {
    arguments ??= const {};

    final Map<String, dynamic> withPlayerId = Map.of(arguments)
      ..['playerId'] = playerId
      ..['mode'] = mode.toString();

    return _channel
        .invokeMethod(method, withPlayerId)
        .then((result) => (result as int));
  }

  /// this should be called after initiating AudioPlayer only if you want to
  /// listen for notification changes in the background. Not implemented on macOS
  void startHeadlessService() {
    if (this == null || playerId.isEmpty) {
      return;
    }
    // Start the headless audio service. The parameter here is a handle to
    // a callback managed by the Flutter engine, which allows for us to pass
    // references to our callbacks between isolates.
    final CallbackHandle handle =
        PluginUtilities.getCallbackHandle(_backgroundCallbackDispatcher);
    assert(handle != null, 'Unable to lookup callback.');
    _invokeMethod('startHeadlessService', {
      'handleKey': <dynamic>[handle.toRawHandle()]
    });

    return;
  }

  /// Start getting significant audio updates through `callback`.
  ///
  /// `callback` is invoked on a background isolate and will not have direct
  /// access to the state held by the main isolate (or any other isolate).
  Future<bool> monitorNotificationStateChanges(
      void Function(AudioPlayerState value) callback) async {
    if (callback == null) {
      throw ArgumentError.notNull('callback');
    }
    final CallbackHandle handle = PluginUtilities.getCallbackHandle(callback);

    await _invokeMethod('monitorNotificationStateChanges', {
      'handleMonitorKey': <dynamic>[handle.toRawHandle()]
    });

    return true;
  }

  /// Plays an audio.
  ///
  /// If [isLocal] is true, [url] must be a local file system path.
  /// If [isLocal] is false, [url] must be a remote URL.
  ///
  /// respectSilence and stayAwake are not implemented on macOS.
  @override
  Future<int> play(
    String url, {
    bool isLocal,
    double volume = 1.0,
    // position must be null by default to be compatible with radio streams
    Duration position,
    bool respectSilence = false,
    bool stayAwake = false,
    bool allowRecord = true,
  }) async {
    isLocal ??= isLocalUrl(url);
    volume ??= 1.0;
    respectSilence ??= false;
    stayAwake ??= false;

    final int result = await _invokeMethod('play', {
      'url': url,
      'isLocal': isLocal,
      'volume': volume,
      'position': position?.inMilliseconds,
      'respectSilence': respectSilence,
      'stayAwake': stayAwake,
      'allowRecord':allowRecord
    });

    if (result == 1) {
      state = AudioPlayerState.PLAYING;
    } else {
        throw Exception("Unknown error trying to play audio, audioplayer returned result : $result");
    }

    return result;
  }

  /// Plays a raw audio stream in WAV format.
  @override
  Future<int> playBuffer(
    Uint8List buffer, 
    int numChannels,
    int sampleRate,
        int bitDepth
  ) async {
     final int result = await _invokeMethod('playBuffer', {
      "buffer":buffer,
      "bitDepth":bitDepth,
      "numChannels":numChannels,
      "sampleRate":sampleRate
    });

    if (result == 1) {
      state = AudioPlayerState.PLAYING;
    }

    return result;
  }

  /// Pauses the audio that is currently playing.
  ///
  /// If you call [resume] later, the audio will resume from the point that it
  /// has been paused.
  @override
  Future<int> pause() async {
    final int result = await _invokeMethod('pause');

    if (result == 1) {
      state = AudioPlayerState.PAUSED;
    }

    return result;
  }

  /// Stops the audio that is currently playing.
  ///
  /// The position is going to be reset and you will no longer be able to resume
  /// from the last point.
  @override
  Future<int> stop() async {
    final int result = await _invokeMethod('stop');

    if (result == 1) {
      state = AudioPlayerState.STOPPED;
    }

    return result;
  }

  /// Resumes the audio that has been paused or stopped, just like calling
  /// [play], but without changing the parameters.
  @override
  Future<int> resume() async {
    final int result = await _invokeMethod('resume');

    if (result == 1) {
      state = AudioPlayerState.PLAYING;
    }

    return result;
  }

  /// Releases the resources associated with this media player.
  ///
  /// The resources are going to be fetched or buffered again as soon as you
  /// call [play] or [setUrl].
  @override
  Future<int> release() async {
    final int result = await _invokeMethod('release');

    if (result == 1) {
      state = AudioPlayerState.STOPPED;
    }

    return result;
  }

  /// Moves the cursor to the desired position.
  @override
  Future<int> seek(Duration position) {
    this.position = position;
    return _invokeMethod('seek', {'position': position.inMilliseconds});
  }

  /// Sets the volume (amplitude).
  ///
  /// 0 is mute and 1 is the max volume. The values between 0 and 1 are linearly
  /// interpolated.
  Future<int> setVolume(double volume) {
    return _invokeMethod('setVolume', {'volume': volume});
  }

  /// Sets the release mode.
  ///
  /// Check [ReleaseMode]'s doc to understand the difference between the modes.
  Future<int> setReleaseMode(ReleaseMode releaseMode) {
    return _invokeMethod(
      'setReleaseMode',
      {'releaseMode': releaseMode.toString()},
    );
  }

  /// Sets the playback rate - call this after first calling play() or resume().
  ///
  /// iOS and macOS have limits between 0.5 and 2x
  /// Android SDK version should be 23 or higher.
  /// not sure if that's changed recently.
  Future<int> setPlaybackRate({double playbackRate = 1.0}) {
    return _invokeMethod('setPlaybackRate', {'playbackRate': playbackRate});
  }

  /// Sets the notification bar for lock screen and notification area in iOS for now.
  ///
  /// Specify atleast title
  Future<dynamic> setNotification(
      {String title,
      String albumTitle,
      String artist,
      String imageUrl,
      Duration forwardSkipInterval,
      Duration backwardSkipInterval,
      Duration duration,
      Duration elapsedTime}) {
    return _invokeMethod('setNotification', {
      'title': title ?? '',
      'albumTitle': albumTitle ?? '',
      'artist': artist ?? '',
      'imageUrl': imageUrl ?? '',
      'forwardSkipInterval': forwardSkipInterval?.inSeconds ?? 30,
      'backwardSkipInterval': backwardSkipInterval?.inSeconds ?? 30,
      'duration': duration?.inSeconds ?? 0,
      'elapsedTime': elapsedTime?.inSeconds ?? 0
    });
  }

  /// Sets the URL.
  ///
  /// Unlike [play], the playback will not resume.
  ///
  /// The resources will start being fetched or buffered as soon as you call
  /// this method.
  ///
  /// respectSilence is not implemented on macOS.
  Future<int> setUrl(String url,
      {bool isLocal: false, bool respectSilence = false}) {
    isLocal = isLocalUrl(url);
    return _invokeMethod('setUrl',
        {'url': url, 'isLocal': isLocal, 'respectSilence': respectSilence});
  }

  /// Get audio duration after setting url.
  /// Use it in conjunction with setUrl.
  ///
  /// It will be available as soon as the audio duration is available
  /// (it might take a while to download or buffer it if file is not local).
  Future<int> getDuration() {
    return _invokeMethod('getDuration');
  }

  // Gets audio current playing position
  Future<int> getCurrentPosition() async {
    return _invokeMethod('getCurrentPosition');
  }

  static Future<void> platformCallHandler(MethodCall call) async {
    try {
      _doHandlePlatformCall(call);
    } catch (ex) {
      _log('Unexpected error: $ex');
    }
  }

  static Future<void> _doHandlePlatformCall(MethodCall call) async {
    final Map<dynamic, dynamic> callArgs = call.arguments as Map;
    _log('_platformCallHandler call ${call.method} $callArgs');

    final playerId = callArgs['playerId'] as String;
    final MethodChannelAudioPlayer player = players[playerId];

    if (!kReleaseMode && Platform.isAndroid && player == null) {
      final oldPlayer = MethodChannelAudioPlayer(playerId: playerId);
      await oldPlayer.release();
      oldPlayer.dispose();
      players.remove(playerId);
      return;
    }

    final value = callArgs['value'];

    switch (call.method) {
      case 'audio.onNotificationPlayerStateChanged':
        final bool isPlaying = value;
        player.notificationState =
            isPlaying ? AudioPlayerState.PLAYING : AudioPlayerState.PAUSED;
        break;
      case 'audio.onDuration':
        Duration newDuration = Duration(milliseconds: value);
        player.duration = newDuration;
        // ignore: deprecated_member_use_from_same_package
        player.durationHandler?.call(newDuration);
        break;
      case 'audio.onCurrentPosition':
        Duration newDuration = Duration(milliseconds: value);
        player.position = newDuration;
        // ignore: deprecated_member_use_from_same_package
        player.positionHandler?.call(newDuration);
        break;
      case 'audio.onComplete':
        print("audio on complete!");
        player.state = AudioPlayerState.COMPLETED;
        player.completion = null;
        // ignore: deprecated_member_use_from_same_package
        player.completionHandler?.call();
        break;
      case 'audio.onSeekComplete':
        player.seekComplete = value;
        // ignore: deprecated_member_use_from_same_package
        player.seekCompleteHandler?.call(value);
        break;
      case 'audio.onError':
        player.state = AudioPlayerState.STOPPED;
        player.error = value;
        // ignore: deprecated_member_use_from_same_package
        player.errorHandler?.call(value);
        break;
      default:
        _log('Unknown method ${call.method} ');
    }
  }

  static void _log(String param) {
    if (logEnabled) {
      print(param);
    }
  }


  Future<int> earpieceOrSpeakersToggle() async {
    PlayingRouteState playingRoute =
        playingRouteState == PlayingRouteState.EARPIECE
            ? PlayingRouteState.SPEAKERS
            : PlayingRouteState.EARPIECE;

    final playingRouteName =
        playingRoute == PlayingRouteState.EARPIECE ? 'earpiece' : 'speakers';
    final int result = await _invokeMethod(
      'earpieceOrSpeakersToggle',
      {'playingRoute': playingRouteName},
    );

    if (result == 1) {
      playingRouteState = playingRoute;
    }

    return result;
  }

  bool isLocalUrl(String url) {
    return url.startsWith("/") ||
        url.startsWith("file://") ||
        url.substring(1).startsWith(':\\');
  }
}
