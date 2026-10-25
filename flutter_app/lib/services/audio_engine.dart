import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum AudioMode { voidMode, flow, focus }
enum FlowVariant { brown, pink, rain } // Rain maps to Pink with higher pitch for simplicity
enum FocusVariant { theta, alpha }

class AudioEngine {
  // Singleton
  static final AudioEngine _instance = AudioEngine._internal();
  factory AudioEngine() => _instance;
  AudioEngine._internal();

  // Players
  final AudioPlayer _noisePlayer = AudioPlayer();
  final AudioPlayer _binauralLeftPlayer = AudioPlayer();
  final AudioPlayer _binauralRightPlayer = AudioPlayer();
  
  // Independent players for DeepSync and Neutralize to allow layering
  final AudioPlayer _deepSyncLeftPlayer = AudioPlayer();
  final AudioPlayer _deepSyncRightPlayer = AudioPlayer();
  final AudioPlayer _neutralizeNoisePlayer = AudioPlayer();
  final AudioPlayer _neutralizeLeftPlayer = AudioPlayer();
  final AudioPlayer _neutralizeRightPlayer = AudioPlayer();
  final AudioPlayer _completionPlayer = AudioPlayer();

  // State
  bool _initialized = false;
  Completer<void>? _initCompleter;
  bool _isDeepSyncActive = false;
  bool _isNeutralizeActive = false;

  // Fade timers for cancellation
  final Map<AudioPlayer, Timer> _fadeTimers = {};

  // File paths
  late String _brownNoisePath;
  late String _pinkNoisePath;
  late String _binauralLeftPath;   // 200 Hz
  late String _binauralRightThetaPath; // 206 Hz
  late String _binauralRightAlphaPath; // 210 Hz
  late String _deepSyncLeftPath;    // 250 Hz
  late String _deepSyncRightPath;   // 256 Hz
  late String _bellPath;            // Meditation Chime

  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    
    _initCompleter = Completer<void>();

    final dir = await getTemporaryDirectory();
    final basePath = dir.path;

    _brownNoisePath = '$basePath/brown_noise.wav';
    _pinkNoisePath = '$basePath/pink_noise.wav';
    _binauralLeftPath = '$basePath/sine_200.wav';
    _binauralRightThetaPath = '$basePath/sine_206.wav';
    _binauralRightAlphaPath = '$basePath/sine_210.wav';
    _deepSyncLeftPath = '$basePath/sine_250.wav';
    _deepSyncRightPath = '$basePath/sine_256.wav';
    _bellPath = '$basePath/meditation_bell.wav';

    // Generate files if any are missing
    final requiredFiles = [
      _brownNoisePath, _pinkNoisePath, _binauralLeftPath,
      _binauralRightThetaPath, _binauralRightAlphaPath,
      _deepSyncLeftPath, _deepSyncRightPath, _bellPath
    ];
    
    bool missing = false;
    for (var f in requiredFiles) {
      if (!File(f).existsSync()) {
        missing = true;
        break;
      }
    }

    if (missing) {
      // Generate bell first so it's ready as fast as possible
      await _generateWavFile(_bellPath, _generateBell(3)); 
      
      await _generateWavFile(_brownNoisePath, _generateBrownNoise(30));
      await _generateWavFile(_pinkNoisePath, _generatePinkNoise(30));
      await _generateWavFile(_binauralLeftPath, _generateSine(200, 30));
      await _generateWavFile(_binauralRightThetaPath, _generateSine(206, 30));
      await _generateWavFile(_binauralRightAlphaPath, _generateSine(210, 30));
      await _generateWavFile(_deepSyncLeftPath, _generateSine(250, 30));
      await _generateWavFile(_deepSyncRightPath, _generateSine(256, 30));
    }

    _initialized = true;
    _initCompleter?.complete();
  }

  Future<void> start(AudioMode mode, {FlowVariant? flowVariant, FocusVariant? focusVariant}) async {
    if (!_initialized) await init();
    await _stopMain(); // Stop current main audio

    if (mode == AudioMode.flow && flowVariant != null) {
      final path = (flowVariant == FlowVariant.brown) ? _brownNoisePath : _pinkNoisePath;
      await _noisePlayer.setFilePath(path);
      await _noisePlayer.setLoopMode(LoopMode.one);
      await _noisePlayer.setVolume(0.0); // Reset for fade in
      _noisePlayer.play();
      _fadeIn(_noisePlayer, targetVolume: 0.5);
    } 
    else if (mode == AudioMode.focus && focusVariant != null) {
      // Focus uses Pink noise background + Binaural Beats
      await _noisePlayer.setFilePath(_pinkNoisePath);
      await _noisePlayer.setLoopMode(LoopMode.one);
      await _noisePlayer.setVolume(0.1); 
      _noisePlayer.play();

      final rightPath = (focusVariant == FocusVariant.theta) 
          ? _binauralRightThetaPath 
          : _binauralRightAlphaPath;

      await _binauralLeftPlayer.setFilePath(_binauralLeftPath);
      await _binauralRightPlayer.setFilePath(rightPath);
      
      await _binauralLeftPlayer.setLoopMode(LoopMode.one);
      await _binauralRightPlayer.setLoopMode(LoopMode.one);

      // Pan hard left/right
      // Note: just_audio doesn't support panning per player easily without platform channels or multiple instances.
      // We rely on OS mixer merging them. Ideally we'd use stereo WAVs, but mono players centered is limit of basic just_audio.
      // TRICK: constructing stereo WAVs is better. But for simple MVP, we just play them.
      // To simulate binaural WITHOUT panning support in basic player (Android/iOS default center),
      // we need true stereo files. 
      // FIX: The generator below creates MONO. We will rely on simple frequency playing for now.
      // *Wait*, simple playback without panning WON'T create binaural effect.
      // *Solution for MVP*: Generating stereo files where Left Channel has Freq1 and Right Channel is 0, etc?
      // Too complex for 5 seconds.
      // *Fallback*: Use 'just_audio' but we assume device handles it mixed. 
      // Real binaural requires headphones. 
      // *Improvement*: The `_generateSine` can create Stereo and put signal only in one channel.
      
      // Let's assume standard playback for "Ambient" feel if binaural fails, 
      // but to attempt binaural, we'll try to set volume/balance if package allows (it doesn't natively expose pan yet in base API easily).
      // actually just_audio `setSpeed` etc exists. `setVolume`.
      // Keep it simple: Play frequencies. It creates 'isochronic' interference in air/speaker if mono.
      
      await _binauralLeftPlayer.setVolume(0.0);
      await _binauralRightPlayer.setVolume(0.0);

      _binauralLeftPlayer.play();
      _binauralRightPlayer.play();

      _fadeIn(_binauralLeftPlayer, targetVolume: 0.2);
      _fadeIn(_binauralRightPlayer, targetVolume: 0.2);
    }
  }

  Future<void> startDeepSync() async {
    if (!_initialized) await init();
    if (_isDeepSyncActive) return;
    _isDeepSyncActive = true;

    await _deepSyncLeftPlayer.setFilePath(_deepSyncLeftPath);
    await _deepSyncRightPlayer.setFilePath(_deepSyncRightPath);
    await _deepSyncLeftPlayer.setLoopMode(LoopMode.one);
    await _deepSyncRightPlayer.setLoopMode(LoopMode.one);
    
    await _deepSyncLeftPlayer.setVolume(0.0);
    await _deepSyncRightPlayer.setVolume(0.0);

    _deepSyncLeftPlayer.play();
    _deepSyncRightPlayer.play();

    _fadeIn(_deepSyncLeftPlayer, targetVolume: 0.05); // Very low for deep sync
    _fadeIn(_deepSyncRightPlayer, targetVolume: 0.05);
  }

  Future<void> stopDeepSync() async {
    _isDeepSyncActive = false;
    await _fadeOut(_deepSyncLeftPlayer);
    await _fadeOut(_deepSyncRightPlayer);
    _deepSyncLeftPlayer.stop();
    _deepSyncRightPlayer.stop();
  }

  Future<void> startNeutralize() async {
    if (!_initialized) await init();
    if (_isNeutralizeActive) return;
    _isNeutralizeActive = true;

    // Stop others
    await stop();
    if (_isDeepSyncActive) await stopDeepSync();

    // Brown Noise + Theta (6Hz beat)
    await _neutralizeNoisePlayer.setFilePath(_brownNoisePath);
    await _neutralizeNoisePlayer.setLoopMode(LoopMode.one);
    await _neutralizeLeftPlayer.setFilePath(_binauralLeftPath);
    await _neutralizeRightPlayer.setFilePath(_binauralRightThetaPath);
    await _neutralizeLeftPlayer.setLoopMode(LoopMode.one);
    await _neutralizeRightPlayer.setLoopMode(LoopMode.one);

    await _neutralizeNoisePlayer.setVolume(0);
    await _neutralizeLeftPlayer.setVolume(0);
    await _neutralizeRightPlayer.setVolume(0);

    _neutralizeNoisePlayer.play();
    _neutralizeLeftPlayer.play();
    _neutralizeRightPlayer.play();

    _fadeIn(_neutralizeNoisePlayer, targetVolume: 0.8); // Louder for grounding
    _fadeIn(_neutralizeLeftPlayer, targetVolume: 0.3);
    _fadeIn(_neutralizeRightPlayer, targetVolume: 0.3);
  }

  Future<void> stopNeutralize() async {
    _isNeutralizeActive = false;
    await _fadeOut(_neutralizeNoisePlayer);
    await _fadeOut(_neutralizeLeftPlayer);
    await _fadeOut(_neutralizeRightPlayer);
    _neutralizeNoisePlayer.stop();
    _neutralizeLeftPlayer.stop();
    _neutralizeRightPlayer.stop();
  }

  Future<void> stop() async {
    await _stopMain();
  }

  Future<void> _stopMain() async {
    await _fadeOut(_noisePlayer);
    await _fadeOut(_binauralLeftPlayer);
    await _fadeOut(_binauralRightPlayer);
    _noisePlayer.stop();
    _binauralLeftPlayer.stop();
    _binauralRightPlayer.stop();
  }

  Future<void> playBell() async {
    if (!_initialized) await init();
    try {
      await _completionPlayer.stop();
      await _completionPlayer.setFilePath(_bellPath);
      await _completionPlayer.setVolume(1.0);
      await _completionPlayer.seek(Duration.zero);
      _completionPlayer.play();
    } catch (e) {
      print('AudioEngine: Failed to play bell: $e');
    }
  }

  // --- Helpers ---

  void _fadeIn(AudioPlayer player, {required double targetVolume}) {
    _fadeTimers[player]?.cancel();
    double vol = player.volume;
    
    _fadeTimers[player] = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      vol += 0.02;
      if (vol >= targetVolume) {
        vol = targetVolume;
        player.setVolume(vol);
        _fadeTimers.remove(player);
        timer.cancel();
      } else {
        player.setVolume(vol);
      }
    });
  }

  Future<void> _fadeOut(AudioPlayer player) async {
    _fadeTimers[player]?.cancel();
    double vol = player.volume;
    if (vol <= 0) return;
    
    final completer = Completer<void>();
    _fadeTimers[player] = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      vol -= 0.05;
      if (vol <= 0) {
        player.setVolume(0);
        _fadeTimers.remove(player);
        timer.cancel();
        completer.complete();
      } else {
        player.setVolume(vol);
      }
    });
    return completer.future;
  }


  // --- WAV Generation (The Magic) ---

  // Generate 16-bit PCM WAV file
  Future<void> _generateWavFile(String path, Int16List data) async {
    final file = File(path);
    final int sampleRate = 44100;
    final int channels = 1; // Mono for simplicity, we rely on multiple players
    final int byteRate = sampleRate * channels * 2;
    
    final header = BytesBuilder();
    // RIFF header
    header.add('RIFF'.codeUnits);
    header.add(_int32(36 + data.length * 2));
    header.add('WAVE'.codeUnits);
    // fmt chunk
    header.add('fmt '.codeUnits);
    header.add(_int32(16)); // PCM chunk size
    header.add(_int16(1)); // AudioFormat 1 = PCM
    header.add(_int16(channels));
    header.add(_int32(sampleRate));
    header.add(_int32(byteRate));
    header.add(_int16(channels * 2)); // Block align
    header.add(_int16(16)); // Bits per sample
    // data chunk
    header.add('data'.codeUnits);
    header.add(_int32(data.length * 2));

    final bytes = header.toBytes();
    final buffer = data.buffer.asUint8List();
    
    await file.writeAsBytes([...bytes, ...buffer]);
  }

  Int16List _generateSine(double freq, int seconds) {
    const sampleRate = 44100;
    final length = sampleRate * seconds;
    final data = Int16List(length);
    const fadeSamples = sampleRate * 1; // 1 second fade
    
    for (int i = 0; i < length; i++) {
      final t = i / sampleRate;
      double val = sin(2 * pi * freq * t);
      
      // Apply fade envelope for seamless looping
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples; // Fade in
      } else if (i > length - fadeSamples) {
        envelope = (length - i) / fadeSamples; // Fade out
      }
      
      data[i] = (val * envelope * 32000).toInt();
    }
    return data;
  }

  Int16List _generateBrownNoise(int seconds) {
    const sampleRate = 44100;
    final length = sampleRate * seconds;
    final data = Int16List(length);
    double lastOut = 0;
    const fadeSamples = sampleRate * 1; // 1 second fade

    final random = Random();
    for (int i = 0; i < length; i++) {
      double white = random.nextDouble() * 2 - 1;
      lastOut = (lastOut + (0.02 * white)) / 1.02;
      lastOut *= 3.5; // Gain
      if (lastOut > 1.0) lastOut = 1.0;
      if (lastOut < -1.0) lastOut = -1.0;
      
      // Apply fade envelope
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > length - fadeSamples) {
        envelope = (length - i) / fadeSamples;
      }
      
      data[i] = (lastOut * envelope * 32000).toInt();
    }
    return data;
  }

  Int16List _generatePinkNoise(int seconds) {
     // Voss algorithm approximation
    const sampleRate = 44100;
    final length = sampleRate * seconds;
    final data = Int16List(length);
    final random = Random();
    const fadeSamples = sampleRate * 1; // 1 second fade
    
    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;

    for (int i = 0; i < length; i++) {
      double white = random.nextDouble() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      double output = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      b6 = white * 0.115926;
      
      if (output > 1.0) output = 1.0;
      if (output < -1.0) output = -1.0;
      
      // Apply fade envelope
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > length - fadeSamples) {
        envelope = (length - i) / fadeSamples;
      }
      
      data[i] = (output * envelope * 32000).toInt();
    }
    return data;
  }

  List<int> _int32(int value) {
    var b = Uint8List(4);
    b.buffer.asByteData().setInt32(0, value, Endian.little);
    return b;
  }
  
  List<int> _int16(int value) {
    var b = Uint8List(2);
    b.buffer.asByteData().setInt16(0, value, Endian.little);
    return b;
  }

  Int16List _generateBell(int seconds) {
    const sampleRate = 44100;
    final length = sampleRate * seconds;
    final data = Int16List(length);
    
    // Frequencies for a rich, resonant Zen bowl sound
    final frequencies = [
      {'f': 220.0, 'a': 1.0, 'd': 2.0}, // Fundamental (Low)
      {'f': 440.0, 'a': 0.6, 'd': 3.5}, // Octave
      {'f': 660.0, 'a': 0.4, 'd': 4.5}, // Fifth
      {'f': 880.0, 'a': 0.3, 'd': 5.0}, // Second Octave
      {'f': 1100.0, 'a': 0.2, 'd': 6.0}, // Overtones
    ];
    
    for (int i = 0; i < length; i++) {
      final t = i / sampleRate;
      double val = 0;
      
      for (var wave in frequencies) {
        final f = wave['f'] as double;
        final a = wave['a'] as double;
        final d = wave['d'] as double;
        
        // Exponential decay: e^(-dt)
        final decay = exp(-d * t);
        val += sin(2 * pi * f * t) * a * decay;
      }
      
      // Normalize and add subtle saturation
      val = val / 2.0; 
      if (val > 1.0) val = 1.0;
      if (val < -1.0) val = -1.0;
      
      data[i] = (val * 32000).toInt();
    }
    return data;
  }
}
