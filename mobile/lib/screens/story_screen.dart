import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/story_provider.dart';
import '../providers/social_provider.dart';
import '../providers/theme_provider.dart';
import '../models/chapter.dart';
import '../widgets/choice_card.dart';
import '../widgets/camera_button.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../services/pdf_downloader_stub.dart'
    if (dart.library.io) '../services/pdf_downloader_native.dart'
    if (dart.library.html) '../services/pdf_downloader_web.dart';
import '../services/io_helper_stub.dart'
    if (dart.library.io) '../services/io_helper_native.dart';
import 'story_tree_screen.dart';
import 'character_creation_screen.dart';

class StoryScreen extends StatefulWidget {
  final int storyId;

  const StoryScreen({super.key, required this.storyId});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _capturedImageBase64;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<StoryProvider>().loadStory(widget.storyId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _capturedImageBase64 = base64Encode(bytes);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fotoğraf eklendi!', style: TextStyle(fontSize: 13)),
            backgroundColor: const Color(0xFF242424),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(),
          ),
        );
      }
    }
  }

  Future<void> _makeChoice(int choiceId) async {
    final provider = context.read<StoryProvider>();
    provider.makeChoiceStream(
      widget.storyId,
      choiceId,
      imageBase64: _capturedImageBase64,
    );
    setState(() => _capturedImageBase64 = null);
    _scrollToBottom();
  }

  Future<void> _onMenuAction(String action, dynamic story) async {
    final api = context.read<ApiService>();
    switch (action) {
      case 'recap':
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              color: Color(0xFF242424),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFC9A96E), strokeWidth: 1.5),
                    SizedBox(height: 16),
                    Text('Özet oluşturuluyor...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w300)),
                  ],
                ),
              ),
            ),
          ),
        );
        try {
          final res = await api.get('/stories/${widget.storyId}/recap');
          if (mounted) {
            Navigator.pop(context); // dismiss loading
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF242424),
                shape: const RoundedRectangleBorder(),
                title: const Text('ÖZET', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w500)),
                content: SingleChildScrollView(child: Text(res.data['recap'] ?? '', style: TextStyle(fontSize: 14, height: 1.7, fontWeight: FontWeight.w300, color: Colors.grey[300]))),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Color(0xFFC9A96E))))],
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            Navigator.pop(context); // dismiss loading
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Özet oluşturulamadı', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating));
          }
        }
        break;
      case 'tree':
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoryTreeScreen(storyId: widget.storyId, storyTitle: story.title)));
        break;
      case 'characters':
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CharacterCreationScreen(storyId: widget.storyId)));
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karakter eklendi', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
        }
        break;
      case 'share':
        try {
          final result = await context.read<SocialProvider>().shareStory(widget.storyId);
          if (mounted) {
            if (result) {
              context.read<SocialProvider>().loadPublicStories();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hikaye paylaşıldı!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu hikaye zaten paylaşılmış.', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF3a2e00), behavior: SnackBarBehavior.floating));
            }
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Hikaye paylaşılamadı', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating));
          }
        }
        break;
      case 'pdf':
        try {
          final exportService = ExportService(api);
          final bytes = await exportService.exportPdf(widget.storyId);
          await savePdf(bytes, 'story_${widget.storyId}.pdf');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF indirildi!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
          }
        } catch (e) {
          debugPrint('PDF error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('PDF oluşturulamadı', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating));
          }
        }
        break;
      case 'complete':
        try {
          await api.post('/stories/${widget.storyId}/complete', data: {});
          if (mounted) {
            context.read<StoryProvider>().loadStory(widget.storyId);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hikaye tamamlandı!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Hikaye tamamlanamadı', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating));
          }
        }
        break;
      case 'download':
        try {
          await context.read<StoryProvider>().downloadStory(widget.storyId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çevrimdışı kaydedildi!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('İndirilemedi', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating));
          }
        }
        break;
      case 'remove_download':
        await context.read<StoryProvider>().removeDownload(widget.storyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çevrimdışı kayıt kaldırıldı', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();
    final story = provider.currentStory;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          story != null && story.title.length > 30
              ? '${story.title.substring(0, 30)}...'
              : story?.title ?? 'Hikaye',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)), onPressed: () => Navigator.pop(context)),
        actions: [
          if (story != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text(
                  '${story.chapters.length} BÖLÜM',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (story != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
              color: const Color(0xFF242424),
              onSelected: (v) => _onMenuAction(v, story),
              itemBuilder: (_) {
                final isDownloaded = context.read<StoryProvider>().isStoryDownloaded(story.id);
                return [
                  const PopupMenuItem(value: 'recap', child: Text('Özet', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'tree', child: Text('Hikaye Ağacı', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'characters', child: Text('Karakter Ekle', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'share', child: Text('Paylaş', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'pdf', child: Text('PDF İndir', style: TextStyle(fontSize: 13))),
                  PopupMenuItem(
                    value: isDownloaded ? 'remove_download' : 'download',
                    child: Row(
                      children: [
                        Icon(
                          isDownloaded ? Icons.delete_outline : Icons.download_outlined,
                          size: 18,
                          color: isDownloaded ? const Color(0xFFAA4444) : const Color(0xFFC9A96E),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDownloaded ? 'Çevrimdışı Kaldır' : 'Çevrimdışı İndir',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDownloaded ? const Color(0xFFAA4444) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!story.isCompleted)
                    const PopupMenuItem(value: 'complete', child: Text('Tamamla', style: TextStyle(fontSize: 13))),
                ];
              },
            ),
        ],
      ),
      body: provider.loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : story == null
              ? const Center(child: Text('Hikaye bulunamadı'))
              : _buildStoryContent(story.chapters, provider.choosing),
    );
  }

  Widget _buildStoryContent(List<Chapter> chapters, bool choosing) {
    final provider = context.watch<StoryProvider>();
    final isStreaming = provider.isStreaming;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length + ((choosing || isStreaming) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chapters.length && (choosing || isStreaming)) {
          if (isStreaming) {
            final displayText = provider.extractStoryText(provider.streamingText);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'YENİ BÖLÜM',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1, color: const Color(0xFFC9A96E))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (displayText.isNotEmpty)
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: context.watch<ThemeProvider>().fontSize,
                        height: 1.8,
                        fontWeight: FontWeight.w300,
                      ),
                    )
                  else
                    Text(
                      'Hikaye yazılıyor...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w300),
                    ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5),
                  const SizedBox(height: 16),
                  Text('Hikaye devam ediyor...', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          );
        }

        final chapter = chapters[index];
        final isLatest = index == chapters.length - 1;
        final story = context.read<StoryProvider>().currentStory;

        return _ChapterWidget(
          chapter: chapter,
          storyId: widget.storyId,
          isLatest: isLatest,
          isCompleted: story?.isCompleted ?? false,
          isChoosing: choosing,
          onChoice: _makeChoice,
          onTakePhoto: _takePhoto,
          hasPhoto: _capturedImageBase64 != null,
          apiService: context.read<ApiService>(),
        );
      },
    );
  }
}

class _ChapterWidget extends StatefulWidget {
  final Chapter chapter;
  final int storyId;
  final bool isLatest;
  final bool isCompleted;
  final bool isChoosing;
  final Function(int) onChoice;
  final VoidCallback onTakePhoto;
  final bool hasPhoto;
  final ApiService apiService;

  const _ChapterWidget({
    required this.chapter,
    required this.storyId,
    required this.isLatest,
    required this.isCompleted,
    required this.isChoosing,
    required this.onChoice,
    required this.onTakePhoto,
    required this.hasPhoto,
    required this.apiService,
  });

  @override
  State<_ChapterWidget> createState() => _ChapterWidgetState();
}

class _ChapterWidgetState extends State<_ChapterWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _ttsLoading = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _audioFilePath;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _cleanupAudioFile();
    super.dispose();
  }

  void _cleanupAudioFile() {
    if (_audioFilePath != null) {
      deleteFileSync(_audioFilePath!);
    }
  }

  Future<void> _playTts() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (_audioFilePath != null && _position > Duration.zero && _position < _duration) {
      await _audioPlayer.resume();
      return;
    }

    // Daha önce indirilmiş dosya varsa tekrar indir
    if (_audioFilePath != null) {
      await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
      return;
    }

    setState(() => _ttsLoading = true);
    try {
      final audioBase64 = await widget.apiService.getChapterAudio(widget.storyId, widget.chapter.chapterNumber);
      if (audioBase64 != null && mounted) {
        final bytes = base64Decode(audioBase64);
        _audioFilePath = await writeTempFile('tts_${widget.storyId}_${widget.chapter.chapterNumber}.wav', bytes);
        await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Ses oluşturulamadı', style: TextStyle(fontSize: 13, color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating, shape: const RoundedRectangleBorder()),
        );
      }
    }
    if (mounted) setState(() => _ttsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BÖLÜM ${widget.chapter.chapterNumber}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2, color: Colors.grey[600]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _ttsLoading ? null : _playTts,
                child: _ttsLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1, color: const Color(0xFFC9A96E))),
                          const SizedBox(width: 6),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.3, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Opacity(opacity: value, child: child);
                            },
                            onEnd: () {},
                            child: Text(
                              'SES OLUŞTURULUYOR',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 1, color: const Color(0xFFC9A96E)),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _isPlaying ? '■ DUR' : '▶ DİNLE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.5, color: _isPlaying ? const Color(0xFFC9A96E) : Colors.grey[600]),
                      ),
              ),
            ],
          ),

          if (_isPlaying || _position > Duration.zero) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0,
              backgroundColor: Colors.grey[800],
              color: const Color(0xFFC9A96E),
              minHeight: 2,
            ),
          ],

          const SizedBox(height: 14),

          Text(
            widget.chapter.content,
            style: TextStyle(fontSize: context.watch<ThemeProvider>().fontSize, height: 1.8, fontWeight: FontWeight.w300),
          ),

          if (widget.chapter.selectedChoice != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: const Color(0xFFC9A96E), width: 2)),
              ),
              child: Text(
                widget.chapter.selectedChoiceText ?? '',
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 13, fontWeight: FontWeight.w300),
              ),
            ),
          ],

          if (widget.chapter.hasChoice && widget.isLatest && !widget.isCompleted && !widget.isChoosing) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Text('SEÇİM YAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2, color: Colors.grey[500])),
                const Spacer(),
                CameraButton(onPressed: widget.onTakePhoto, hasPhoto: widget.hasPhoto),
              ],
            ),
            const SizedBox(height: 14),
            ...widget.chapter.choices.map((choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceCard(choice: choice, onTap: () => widget.onChoice(choice.id)),
            )),
          ],
        ],
      ),
    );
  }
}
