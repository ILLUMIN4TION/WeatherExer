import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioQueueService {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  int _chunkIndex = 0;

  // 🔥 홈 화면에서 플레이어의 상태를 구독할 수 있도록 공개
  AudioPlayer get player => _player;

  AudioQueueService() {
    _player.setAudioSource(_playlist);
  }

  // 🔥 텍스트 청크를 같이 받도록 수정
  Future<void> addAudioChunk(String base64Audio, String textChunk) async {
    if (base64Audio.isEmpty) return;

    try {
      Uint8List audioBytes = base64Decode(base64Audio);
      Directory tempDir = await getTemporaryDirectory();
      File tempFile = File('${tempDir.path}/chunk_$_chunkIndex.wav');
      _chunkIndex++;

      await tempFile.writeAsBytes(audioBytes, flush: true);

      await _playlist.add(
        AudioSource.uri(
          Uri.file(tempFile.path),
          tag: textChunk, 
        ),
      );

      // 🔥 복잡한 조건(loading 상태 확인) 삭제하고 직관적으로 수정
      // 플레이어가 멈춰있다면 (즉, 첫 번째 파일이 들어왔거나 재생이 끝났다면) 바로 재생!
      if (!_player.playing) {
        await _player.play();
      }
    } catch (e) {
      print("오디오 디코딩 에러: $e");
    }
  }

  Future<void> clearQueue() async {
    await _player.stop();
    await _playlist.clear();
    _chunkIndex = 0;
  }
}