import 'dart:typed_data';
import 'dart:web_audio';

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