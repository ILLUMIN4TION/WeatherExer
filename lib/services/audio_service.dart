import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioQueueService {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  int _chunkIndex = 0;
  
  // 🔥 이번 세션에 기록한 청크 파일 경로 (재생 완료/큐 정리 시 일괄 삭제용)
  final List<String> _playedFilePaths = [];

  // 🔥 오디오 파이프라인 워밍업 완료 여부 (에뮬레이터는 콜드 상태에서 첫 버퍼가 떨어질 수 있음)
  bool _warmedUp = false;

  AudioPlayer get player => _player;

  AudioQueueService() {
    _player.setAudioSource(_playlist);

    // 🔥 플레이어 에러 옵저버 (디버그 — 청크 로드 실패 즉시 로그로 확인)
    _player.errorStream.listen((e) {
      print('⚠️ 플레이어 에러: $e | state=${_player.processingState} playing=${_player.playing}');
    });

    // 🔥 상태 변화 옵저버 (디버그)
    _player.processingStateStream.listen((state) {
      print('🔄 상태 변경: $state | 큐=${_playlist.children.length}');
    });

    // ⚠️ "재생 완료 시 파일 삭제" 리스너는 제거됨:
    // setAudioSource(빈 플레이리스트) 리셋 시에도 ENDED→completed 이벤트가 firing되어
    // (앱 시작 시점, 매 clearQueue마다) 실제로는 재생이 끝난 게 아닌데 파일이
    // 삭제되던 문제가 있었다. 파일 정리는 이제 clearQueue()/disposeAll() 시점으로만 한다.

    // 🔥 이전 실행에서 남은 고아 청크 파일 정리 (앱 강제 종료 등으로 clearQueue가
    //    실행되지 않은 경우 캐시가 누적되는 것을 방지)
    _cleanupOrphanChunkFiles();
  }

  /// 🔥 캐시에 남은 chunk_*.wav / warmup_silence.wav 고아 파일 정리
  Future<void> _cleanupOrphanChunkFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.path.endsWith('.wav') &&
            (entity.path.contains('/chunk_') ||
                entity.path.contains('/warmup_silence'))) {
          await entity.delete();
          print('🧹 고아 파일 정리: ${entity.path}');
        }
      }
    } catch (e) {
      print('고아 파일 정리 실패: $e');
    }
  }

  Future<void> addAudioChunk(String base64Audio, String textChunk) async {
    if (base64Audio.isEmpty) return;

    try {
      Uint8List audioBytes = base64Decode(base64Audio);
      Directory tempDir = await getTemporaryDirectory();
      File tempFile = File('${tempDir.path}/chunk_$_chunkIndex.wav');
      
      // 🔥 기존에 삭제되지 않고 남은 파일이 있으면 먼저 정리
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      _chunkIndex++;

      await tempFile.writeAsBytes(audioBytes, flush: true);
      
      // 새 파일 경로 추적 목록에 추가
      _playedFilePaths.add(tempFile.path);

      await _playlist.add(
        AudioSource.uri(
          Uri.file(tempFile.path),
          tag: textChunk, 
        ),
      );

      // 🔥 디버그: 큐 등록 시 플레이어 상태 확인
      print('🔊 청크 ${_chunkIndex - 1} 큐 등록 | state=${_player.processingState} playing=${_player.playing} idx=${_player.currentIndex}');

      // 🔥 오디오 잘림 방지: 재생 중이 아니라면 재생 시작
      // (현재 위치에서 재개 — 옛 로직은 가장 마지막 추가 인덱스로 seek해서
      //  아직 재생을 못 시작한 이전 청크를 통째로 건너뛸 수 있음)
      if (!_player.playing || _player.processingState == ProcessingState.completed) {
        
        final int? current = _player.currentIndex;
        final int indexToPlay = (current != null && current > 0) ? current : 0;
        
        await _player.seek(Duration.zero, index: indexToPlay);
        _player.play();
        print('▶️ 재생 시작 요청 (index $indexToPlay)');
      }
    } catch (e) {
      print("오디오 디코딩 에러: $e");
    }
  }
  
  /// 🔥 추적된 모든 파일 일괄 삭제 (async — deleteSync는 메인 스레드를 막음)
  /// "재생 완료"/"큐 정리" 시에만 호출 — 재생 중 파일 삭제 금지
  Future<void> _deleteAllChunkFiles() async {
    for (final path in _playedFilePaths) {
      try {
        await File(path).delete();
      
        print("🗑️ 청크 파일 삭제: $path");
      } catch (e) {
        print("파일 삭제 실패: $path - $e");
      }
    }
    _playedFilePaths.clear();
  }

  /// 🔥 오디오 파이프라인 워밍업 (첫 1회만)
  /// 에뮬레이터의 오디오 HAL은 워밍업 중 첫 버퍼를 드롭해서
  /// 첫 문장의 처음 ~0.4초("안녕하")가 사라지는 증상이 있었다.
  /// 실제 오디오 전에 짧은 침묵을 한 번 재생해 오디오 라우트를 미리 열어둔다.
  ///
  /// ⚠️ 중요: 성공/실패와 무관하게 finally에서 임시 파일 삭제 + 플레이리스트
  /// 복원을 보장한다. 예외가 발생하면 복원이 생략되어 플레이어가
  /// 에러 상태(마지막 소스 = 실패한 파일)에 머물던 문제가 있었다.
  Future<void> _warmUpPlayer() async {
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File('${dir.path}/warmup_silence.wav');
      await tmp.writeAsBytes(_buildSilentWav(0.3), flush: true);
      await _player.setAudioSource(AudioSource.uri(Uri.file(tmp.path)));
      await _player.play();
      await Future.delayed(const Duration(milliseconds: 350));
      await _player.stop();
      print('✅ 오디오 워밍업 완료');
    } catch (e) {
      print('오디오 워밍업 실패: $e');
    } finally {
      try {
        if (tmp != null && await tmp.exists()) {
          await tmp.delete();
        }
      } catch (_) {}
      // 🔥 워밍업 소스로 바뀐 플레이어 상태를 항상 플레이리스트로 되돌린다
      try {
        await _player.setAudioSource(_playlist);
      } catch (e) {
        print('워밍업 후 플레이리스트 복원 실패: $e');
      }
    }
  }

  /// [seconds]초 분량의 무음 WAV 생성 (16kHz mono 16bit PCM)
  ///
  /// ⚠️ 바이트 순서 주의: 'RIFF'/'fmt '/'data' 같은 ASCII 마커는
  /// setUint32(..., Endian.little)로 쓰면 바이트가 뒤집힌다
  /// (0x52494646 → "FIFR" → ExoPlayer WavExtractor가 "Source error"로
  ///  파일을 못 읽음). 그래서 마커는 setUint8로 1바이트씩 직접 쓴다.
  Uint8List _buildSilentWav(double seconds) {
    const int sampleRate = 16000;
    final int numSamples = (seconds * sampleRate).toInt();
    final data = ByteData(44 + numSamples * 2);
    void setAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }
    setAscii(0, 'RIFF');
    data.setUint32(4, 36 + numSamples * 2, Endian.little); // RIFF 크기
    setAscii(8, 'WAVE');
    setAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // fmt 청크 크기
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    setAscii(36, 'data');
    data.setUint32(40, numSamples * 2, Endian.little); // data 크기
    // (샘플 영역은 ByteData 기본값 0 = 무음)
    return data.buffer.asUint8List();
  }

  Future<void> clearQueue() async {
    // 🔥 실제 큐보다 먼저 워밍업 (첫 1회만)
    if (!_warmedUp) {
      _warmedUp = true;
      await _warmUpPlayer();
    }
    await _player.stop();
    await Future.delayed(const Duration(milliseconds: 50)); // 플레이어 안정화 대기
    await _playlist.clear();
    
    // 🔥 추적된 모든 파일 삭제 (중단된 세션의 미재생 파일 포함)
    await _deleteAllChunkFiles();
    
    _chunkIndex = 0; // 인덱스 완전 초기화
    
    // 플레이터 리셋 - 새 소스로 설정
    await _player.setAudioSource(_playlist);
  }
  
  /// 🔥 앱 종료 시 모든 임시 파일 강제 정리 (선택적 호출)
  Future<void> disposeAll() async {
    await clearQueue();
    await _player.dispose();
    _playedFilePaths.clear();
  }
}
