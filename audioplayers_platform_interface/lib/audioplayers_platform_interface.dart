import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/method_channel_audioplayers.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/uuid.dart';

typedef StreamController CreateStreamController();
typedef void TimeChangeHandler(Duration duration);
typedef void SeekHandler(bool finished);
typedef void ErrorHandler(String message);
typedef void AudioPlayerStateChangeHandler(AudioPlayerState state);



/// The interface that implementations of audioplayer must implement.
///
/// Platform implementations should extend this class rather than implement it as `audioplayer`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [AudioPlayerPlatformPlatform] methods.
abstract class AudioPlayerPlatform extends PlatformInterface {
  /// Constructs a AudioPlayerPlatform.
  AudioPlayerPlatform({this.mode}) : super(token: _token);

  static final Object _token = Object();

  static AudioPlayerPlatform _instance;
  /// The default instance of [AudioPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioPlayer].
  static AudioPlayerPlatform get instance {
    if(_instance == null) {
        _instance  = MethodChannelAudioPlayer();
    }
    return _instance;
    }
    

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [AudioPlayerPlatform] when they register themselves.
  static set instance(AudioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  static final _uuid = Uuid();

  final StreamController<AudioPlayerState> _playerStateController =
      StreamController<AudioPlayerState>.broadcast();

  final StreamController<AudioPlayerState> _notificationPlayerStateController =
      StreamController<AudioPlayerState>.broadcast();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  final StreamController<bool> _seekCompleteController =
      StreamController<bool>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  /// Enables more verbose logging.
  static bool logEnabled = false;

  AudioPlayerState _audioPlayerState;

  AudioPlayerState get state => _audioPlayerState;

  set state(AudioPlayerState state) {
    _playerStateController.add(state);
    // ignore: deprecated_member_use_from_same_package
    audioPlayerStateChangeHandler?.call(state);
    _audioPlayerState = state;
  }

  PlayingRouteState _playingRouteState = PlayingRouteState.SPEAKERS;

  PlayingRouteState get playingRouteState => _playingRouteState;

  set playingRouteState(PlayingRouteState routeState) {
    _playingRouteState = routeState;
  }

  set notificationState(AudioPlayerState state) {
    _notificationPlayerStateController.add(state);
    _audioPlayerState = state;
  }

  Duration _duration;
  set duration(Duration duration) {
    _duration = duration;
    _durationController.add(duration);
  }

  Duration _position;
  set position(Duration position) {
    _positionController.add(position);
    _position = position;
  }
  
  set completion(void completed) {
    _completionController.add(null);
  }

  set seekComplete(void completed) {
    _seekCompleteController.add(null);
  }

  set error(String error) {
    _errorController.add(error);
  }

  

  /// Stream of changes on player state.
  Stream<AudioPlayerState> get onPlayerStateChanged =>
      _playerStateController.stream;

  /// Stream of changes on player state coming from notification area in iOS.
  Stream<AudioPlayerState> get onNotificationPlayerStateChanged =>
      _notificationPlayerStateController.stream;

  /// Stream of changes on audio position.
  ///
  /// Roughly fires every 200 milliseconds. Will continuously update the
  /// position of the playback if the status is [AudioPlayerState.PLAYING].
  ///
  /// You can use it on a progress bar, for instance.
  Stream<Duration> get onAudioPositionChanged => _positionController.stream;

  /// Stream of changes on audio duration.
  ///
  /// An event is going to be sent as soon as the audio duration is available
  /// (it might take a while to download or buffer it).
  Stream<Duration> get onDurationChanged => _durationController.stream;

  /// Stream of player completions.
  ///
  /// Events are sent every time an audio is finished, therefore no event is
  /// sent when an audio is paused or stopped.
  ///
  /// [ReleaseMode.LOOP] also sends events to this stream.
  Stream<void> get onPlayerCompletion => _completionController.stream;

  /// Stream of seek completions.
  ///
  /// An event is going to be sent as soon as the audio seek is finished.
  Stream<void> get onSeekComplete => _seekCompleteController.stream;

  /// Stream of player errors.
  ///
  /// Events are sent when an unexpected error is thrown in the native code.
  Stream<String> get onPlayerError => _errorController.stream;

  /// Handler of changes on player state.
  @deprecated
  AudioPlayerStateChangeHandler audioPlayerStateChangeHandler;

  /// Handler of changes on player position.
  ///
  /// Will continuously update the position of the playback if the status is
  /// [AudioPlayerState.PLAYING].
  ///
  /// You can use it on a progress bar, for instance.
  ///
  /// This is deprecated. Use [onAudioPositionChanged] instead.
  @deprecated
  TimeChangeHandler positionHandler;

  /// Handler of changes on audio duration.
  ///
  /// An event is going to be sent as soon as the audio duration is available
  /// (it might take a while to download or buffer it).
  ///
  /// This is deprecated. Use [onDurationChanged] instead.
  @deprecated
  TimeChangeHandler durationHandler;

  /// Handler of player completions.
  ///
  /// Events are sent every time an audio is finished, therefore no event is
  /// sent when an audio is paused or stopped.
  ///
  /// [ReleaseMode.LOOP] also sends events to this stream.
  ///
  /// This is deprecated. Use [onPlayerCompletion] instead.
  @deprecated
  VoidCallback completionHandler;

  /// Handler of seek completion.
  ///
  /// An event is going to be sent as soon as the audio seek is finished.
  ///
  /// This is deprecated. Use [onSeekComplete] instead.
  @deprecated
  SeekHandler seekCompleteHandler;

  /// Handler of player errors.
  ///
  /// Events are sent when an unexpected error is thrown in the native code.
  ///
  /// This is deprecated. Use [onPlayerError] instead.
  @deprecated
  ErrorHandler errorHandler;

  /// Current mode of the audio player. Can be updated at any time, but is going
  /// to take effect only at the next time you play the audio.
  PlayerMode mode;

  /// this should be called after initiating AudioPlayer only if you want to
  /// listen for notification changes in the background. Not implemented on macOS
  void startHeadlessService() {
    throw UnimplementedError('startHeadlessService has not been implemented.');
  }

  /// Start getting significant audio updates through `callback`.
  ///
  /// `callback` is invoked on a background isolate and will not have direct
  /// access to the state held by the main isolate (or any other isolate).
  Future<bool> monitorNotificationStateChanges(
      void Function(AudioPlayerState value) callback) async {
    throw UnimplementedError('monitorNotificationStateChanges has not been implemented.');
  }

  /// Plays an audio.
  ///
  /// If [isLocal] is true, [url] must be a local file system path.
  /// If [isLocal] is false, [url] must be a remote URL.
  ///
  /// respectSilence and stayAwake are not implemented on macOS.
  Future<int> play(
    String url, {
    bool isLocal,
    double volume = 1.0,
    // position must be null by default to be compatible with radio streams
    Duration position,
    bool respectSilence = false,
    bool stayAwake = false,
  }) async {
    throw UnimplementedError('play has not been implemented.');
  }

  /// Plays a raw audio stream in WAV format.
  Future<int> playBuffer(
    Uint8List buffer, 
    int numChannels,
    int sampleRate,
        int bitDepth
  ) async {
    throw UnimplementedError('playBuffer has not been implemented.');
  }

  /// Pauses the audio that is currently playing.
  ///
  /// If you call [resume] later, the audio will resume from the point that it
  /// has been paused.
  Future<int> pause() async {
    throw UnimplementedError('pause has not been implemented.');
  }

  /// Stops the audio that is currently playing.
  ///
  /// The position is going to be reset and you will no longer be able to resume
  /// from the last point.
  Future<int> stop() async {
    throw UnimplementedError('stop has not been implemented.');
  }

  /// Resumes the audio that has been paused or stopped, just like calling
  /// [play], but without changing the parameters.
  Future<int> resume() async {
    throw UnimplementedError('resume has not been implemented.');
  }

  /// Releases the resources associated with this media player.
  ///
  /// The resources are going to be fetched or buffered again as soon as you
  /// call [play] or [setUrl].
  Future<int> release() async {
    throw UnimplementedError('release has not been implemented.');
  }

  /// Moves the cursor to the desired position.
  Future<int> seek(Duration position) {
    throw UnimplementedError('seek has not been implemented.');
  }

  /// Sets the volume (amplitude).
  ///
  /// 0 is mute and 1 is the max volume. The values between 0 and 1 are linearly
  /// interpolated.
  Future<int> setVolume(double volume) {
    throw UnimplementedError('setVolume has not been implemented.');
  }

  /// Sets the release mode.
  ///
  /// Check [ReleaseMode]'s doc to understand the difference between the modes.
  Future<int> setReleaseMode(ReleaseMode releaseMode) {
    throw UnimplementedError('setReleaseMode has not been implemented.');
  }

  /// Sets the playback rate - call this after first calling play() or resume().
  ///
  /// iOS and macOS have limits between 0.5 and 2x
  /// Android SDK version should be 23 or higher.
  /// not sure if that's changed recently.
  Future<int> setPlaybackRate({double playbackRate = 1.0}) {
    throw UnimplementedError('setPlaybackRate has not been implemented.');
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
    throw UnimplementedError('setNotification has not been implemented.');
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
    throw UnimplementedError('setUrl has not been implemented.');
  }

  /// Get audio duration after setting url.
  /// Use it in conjunction with setUrl.
  ///
  /// It will be available as soon as the audio duration is available
  /// (it might take a while to download or buffer it if file is not local).
  Future<int> getDuration() {
    throw UnimplementedError('getDuration has not been implemented.');
  }

  // Gets audio current playing position
  Future<int> getCurrentPosition() async {
        throw UnimplementedError('getCurrentPosition has not been implemented.');
  }

    /// Closes all [StreamController]s.
  ///
  /// You must call this method when your [AudioPlayer] instance is not going to
  /// be used anymore.
  Future<void> dispose() async {
    List<Future> futures = [];

    if (!_playerStateController.isClosed)
      futures.add(_playerStateController.close());
    if (!_notificationPlayerStateController.isClosed)
      futures.add(_notificationPlayerStateController.close());
    if (!_positionController.isClosed) futures.add(_positionController.close());
    if (!_durationController.isClosed) futures.add(_durationController.close());
    if (!_completionController.isClosed)
      futures.add(_completionController.close());
    if (!_seekCompleteController.isClosed)
      futures.add(_seekCompleteController.close());
    if (!_errorController.isClosed) futures.add(_errorController.close());

    await Future.wait(futures);
  }

  Future<int> earpieceOrSpeakersToggle() async {
    throw UnimplementedError('earpieceOrSpeakersToggle has not been implemented.');
  }

}

