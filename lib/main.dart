import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:test_flutter/src/rust/api/analyzer.dart';
import 'package:test_flutter/src/rust/frb_generated.dart';
import 'package:wav/wav.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

Future<String> getSafeOutputPath(String filename) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/$filename';
}

class _MyAppState extends State<MyApp> {
  String resultText = "No analysis yet.";

  /// Let user pick an audio file, process it, and analyze fart sound
  Future<void> _pickAndAnalyzeFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null) return; // User canceled

    File file = File(result.files.single.path!);

    // Extract audio samples
    // List<double>? samples = await _extractAudioSamples(file);

    // Use FFmpeg to convert M4A to raw PCM
    String outputPath = await getSafeOutputPath("converted_audio.pcm");

    if (await File(outputPath).exists()) {
      await File(outputPath).delete(); // Delete existing file before writing
    }

    await FFmpegKit.execute('-i "${file.path}" -ac 1 -ar 44100 -f s16le "$outputPath"');

    if (await File(outputPath).exists()) {
      print("✅ PCM file created at: $outputPath");
    } else {
      print("❌ PCM file missing after FFmpeg conversion.");
    }

    // Read PCM bytes
    Uint8List pcmBytes = await File(outputPath).readAsBytes();

    // Convert PCM to float samples
    List<double> samples = pcmBytes.buffer
        .asInt16List()
        .map((e) => e.toDouble() / 32768.0) // Normalize PCM
        .toList();
    
    if (samples == null) {
      setState(() {
        resultText = "Failed to extract audio samples.";
      });
      return;
    }

    double sampleRate = 44100.0; // Modify if needed

    // Call Rust function
    final analysis = analyzeFart(samples: samples, sampleRate: sampleRate);

    // Update UI with results
    setState(() {
      resultText = """ Analyzing Fart...""";
    });

    String outputWavPath = await getSafeOutputPath("trimmed_audio.wav");

    if (await File(outputWavPath).exists()) {
      await File(outputWavPath).delete(); // Delete existing file before writing
    }

    await FFmpegKit.execute('-f s16le -ar 44100 -ac 1 -i "$outputPath" "$outputWavPath"');
    

    if (!await File(outputWavPath).exists()) {
      print("❌ Failed to create WAV file.");
      return;
    }
    File outputWav = File(outputWavPath);
    await playAudio(outputWav);

    // Update UI with results
    setState(() {
      resultText = """
      🎺 Fart Analysis:
      🔊 Loudness: ${analysis.loudnessDb.toStringAsFixed(2)} dB
      ⏳ Duration: ${analysis.duration.toStringAsFixed(2)} seconds
      🎶 Dominant Frequency: ${analysis.dominantFreq.toStringAsFixed(2)} Hz
      """;
    });


  }

  /// Extract PCM samples from the audio file
  // Future<List<double>?> _extractAudioSamples(File file) async {
  //   try {
  //     // Read the file as bytes
  //     Uint8List bytes = await file.readAsBytes();

  //     // Decode the WAV file
  //     final wav = Wav.read(bytes);

  //     // Access the audio samples
  //     List<double> samples = [];
  //     for (final channel in wav.channels) {
  //       samples.addAll(channel);
  //     }

  //     return samples;
  //   } catch (e) {
  //     print('Error reading WAV file: $e');
  //     return null;
  //   }
  // }
  /// Converts an M4A file to PCM and extracts audio samples
  // Future<List<double>?> _extractAudioSamples(File file) async {
  //   final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  //   String outputPath = "${file.path}.pcm"; // Temporary PCM file

  //   // Use FFmpeg to convert M4A to raw PCM (16-bit, single channel, 44100 Hz)
  //   int rc = await _ffmpeg.execute(
  //       "-i ${file.path} -ac 1 -ar 44100 -f s16le $outputPath");

  //   if (rc != 0) {
  //     print("FFmpeg failed to convert M4A to PCM.");
  //     return null;
  //   }

  //   // Read the PCM file as bytes
  //   final bytes = await File(outputPath).readAsBytes();

  //   // Convert PCM bytes to float samples
  //   List<double> samples = bytes.buffer
  //       .asInt16List()
  //       .map((e) => e.toDouble() / 32768.0) // Normalize 16-bit PCM
  //       .toList();

  //   return samples;
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Fart Analyzer 🎷💨')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pickAndAnalyzeFile,
                child: const Text("Pick Fart Audio 🎤"),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(resultText, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




Future<void> playAudio(File file) async {
  final player = AudioPlayer();
  await player.play(DeviceFileSource(file.path)); // Play the file
}
