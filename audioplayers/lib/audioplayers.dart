import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';

/// Self explanatory. Indicates the state of the audio player.
enum AudioPlayerState {
  STOPPED,
  PLAYING,
  PAUSED,
  COMPLETED,
}

/// This enum is meant to be used as a parameter of [setReleaseMode] method.
///
/// It represents the behaviour of [AudioPlayer] when an audio is finished or
/// stopped.
enum ReleaseMode {
  /// Releases all resources, just like calling [release] method.
  ///
  /// In Android, the media player is quite resource-intensive, and this will
  /// let it go. Data will be buffered again when needed (if it's a remote file,
  /// it will be downloaded again).
  /// In iOS and macOS, works just like [stop] method.
  ///
  /// This is the default behaviour.
  RELEASE,

  /// Keeps buffered data and plays again after completion, creating a loop.
  /// Notice that calling [stop] method is not enough to release the resources
  /// when this mode is being used.
  LOOP,

  /// Stops audio playback but keep all resources intact.
  /// Use this if you intend to play again later.
  STOP
}

/// Indicates which speakers use for playing
enum PlayingRouteState {
  SPEAKERS,
  EARPIECE,
}

/// This enum is meant to be used as a parameter of the [AudioPlayer]'s
/// constructor. It represents the general mode of the [AudioPlayer].
///
// In iOS and macOS, both modes have the same backend implementation.
enum PlayerMode {
  /// Ideal for long media files or streams.
  MEDIA_PLAYER,

  /// Ideal for short audio files, since it reduces the impacts on visuals or
  /// UI performance.
  ///
  /// In this mode the backend won't fire any duration or position updates.
  /// Also, it is not possible to use the seek method to set the audio a
  /// specific position.
  LOW_LATENCY
}



/// This represents a single AudioPlayer plugin, which can play one audio at a time.
/// To play several audios at the same time, you must create several instances
/// of this class.
///
/// It holds methods to play, loop, pause, stop, seek the audio, and some useful
/// hooks for handlers and callbacks.
class AudioPlayer {

/// Stream of changes on player state.
get onPlayerStateChanged =>
      AudioPlayerPlatform.instance.onPlayerStateChanged;

  /// Stream of changes on player state coming from notification area in iOS.
get onNotificationPlayerStateChanged =>
      AudioPlayerPlatform.instance.onNotificationPlayerStateChanged;

  /// Stream of changes on audio position.
  ///
  /// Roughly fires every 200 milliseconds. Will continuously update the
  /// position of the playback if the status is [AudioPlayerState.PLAYING].
  ///
  /// You can use it on a progress bar, for instance.
  Stream<Duration> get onAudioPositionChanged => AudioPlayerPlatform.instance.onAudioPositionChanged;

  /// Stream of changes on audio duration.
  ///
  /// An event is going to be sent as soon as the audio duration is available
  /// (it might take a while to download or buffer it).
  Stream<Duration> get onDurationChanged => AudioPlayerPlatform.instance.onDurationChanged;

  /// Stream of player completions.
  ///
  /// Events are sent every time an audio is finished, therefore no event is
  /// sent when an audio is paused or stopped.
  ///
  /// [ReleaseMode.LOOP] also sends events to this stream.
  Stream<void> get onPlayerCompletion => AudioPlayerPlatform.instance.onPlayerCompletion;

  /// Stream of seek completions.
  ///
  /// An event is going to be sent as soon as the audio seek is finished.
  Stream<void> get onSeekComplete => AudioPlayerPlatform.instance.onSeekComplete;

  /// Stream of player errors.
  ///
  /// Events are sent when an unexpected error is thrown in the native code.
  Stream<String> get onPlayerError => AudioPlayerPlatform.instance.onPlayerError;

  String _playerId;

  /// Creates a new instance and assigns an unique id to it.
  AudioPlayer(
    {PlayerMode mode = PlayerMode.MEDIA_PLAYER, String playerId}
    ) {
    AudioPlayerPlatform.instance.mode = mode;
    _playerId = playerId;
  }
 
  /// this should be called after initiating AudioPlayer only if you want to
  /// listen for notification changes in the background. Not implemented on macOS
  void get startHeadlessService => AudioPlayerPlatform.instance.startHeadlessService;

  /// Start getting significant audio updates through `callback`.
  ///
  /// `callback` is invoked on a background isolate and will not have direct
  /// access to the state held by the main isolate (or any other isolate).
  get monitorNotificationStateChanges => AudioPlayerPlatform.instance.monitorNotificationStateChanges;

  /// Plays an audio.
  ///
  /// If [isLocal] is true, [url] must be a local file system path.
  /// If [isLocal] is false, [url] must be a remote URL.
  ///
  /// respectSilence and stayAwake are not implemented on macOS.
  get play => AudioPlayerPlatform.instance.play;

  /// Plays a raw audio stream in WAV format.
  get playBuffer => AudioPlayerPlatform.instance.playBuffer;

  /// Pauses the audio that is currently playing.
  ///
  /// If you call [resume] later, the audio will resume from the point that it
  /// has been paused.
  get pause => AudioPlayerPlatform.instance.pause;

  /// Stops the audio that is currently playing.
  ///
  /// The position is going to be reset and you will no longer be able to resume
  /// from the last point.
  get stop => AudioPlayerPlatform.instance.stop;
    
  /// Resumes the audio that has been paused or stopped, just like calling
  /// [play], but without changing the parameters.
  get resume => AudioPlayerPlatform.instance.resume;
    
  /// Releases the resources associated with this media player.
  ///
  /// The resources are going to be fetched or buffered again as soon as you
  /// call [play] or [setUrl].
  get release => AudioPlayerPlatform.instance.release;
    
  /// Moves the cursor to the desired position.
  get seek => AudioPlayerPlatform.instance.seek;
    
  /// Sets the volume (amplitude).
  ///
  /// 0 is mute and 1 is the max volume. The values between 0 and 1 are linearly
  /// interpolated.
  get setVolume => AudioPlayerPlatform.instance.setVolume;
    
  /// Sets the release mode.
  ///
  /// Check [ReleaseMode]'s doc to understand the difference between the modes.
  get setReleaseMode => AudioPlayerPlatform.instance.setReleaseMode;
    
  /// Sets the playback rate - call this after first calling play() or resume().
  ///
  /// iOS and macOS have limits between 0.5 and 2x
  /// Android SDK version should be 23 or higher.
  /// not sure if that's changed recently.
  get setPlaybackRate => AudioPlayerPlatform.instance.setPlaybackRate;
    
  /// Sets the notification bar for lock screen and notification area in iOS for now.
  ///
  /// Specify atleast title
  get setNotification => AudioPlayerPlatform.instance.setNotification;
      
  /// Sets the URL.
  ///
  /// Unlike [play], the playback will not resume.
  ///
  /// The resources will start being fetched or buffered as soon as you call
  /// this method.
  ///
  /// respectSilence is not implemented on macOS.
  get setUrl => AudioPlayerPlatform.instance.setUrl;
      
  /// Get audio duration after setting url.
  /// Use it in conjunction with setUrl.
  ///
  /// It will be available as soon as the audio duration is available
  /// (it might take a while to download or buffer it if file is not local).
  get getDuration => AudioPlayerPlatform.instance.getDuration;

  // Gets audio current playing position
  get getCurrentPosition => AudioPlayerPlatform.instance.getCurrentPosition;

  /// Closes all [StreamController]s.
  ///
  /// You must call this method when your [AudioPlayer] instance is not going to
  /// be used anymore.
  get dispose => AudioPlayerPlatform.instance.dispose;

  get earpieceOrSpeakersToggle => AudioPlayerPlatform.instance.earpieceOrSpeakersToggle;

}
