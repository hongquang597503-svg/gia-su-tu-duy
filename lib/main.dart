// ============================================================
// GIA SƯ TƯ DUY v1.0.4 — AI Mã Nguồn Mở Chạy Offline
// Tệp duy nhất: lib/main.dart
// AI: Qwen 2.5 (llama.cpp) — chạy hoàn toàn trên điện thoại
// OCR: Google ML Kit — đọc chữ từ ảnh không cần mạng
// Phát triển: Nguyễn Hồng Quang — 10A10 — THPT Châu Thành 1
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── main ───────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ModelManager.instance.init();
  runApp(const GiaSuTuDuyApp());
}

// ─── Hằng số ────────────────────────────────────────────────
const String appVersion    = '1.0.4';
const String authorName    = 'Nguyễn Hồng Quang';
const String authorSchool  = 'Lớp 10A10 — THPT Châu Thành 1';

// ============================================================
// MODEL MANAGEMENT
// ============================================================

class ModelInfo {
  final String name;
  final String description;
  final String fileName;
  final String url;
  final double sizeGB;
  const ModelInfo({required this.name, required this.description,
      required this.fileName, required this.url, required this.sizeGB});
}

enum ModelChoice { lite, standard }
enum ModelState  { notDownloaded, downloading, loadingModel, ready, error }

const Map<ModelChoice, ModelInfo> kModels = {
  ModelChoice.lite: ModelInfo(
    name        : 'Qwen 2.5 — 0.5B (Nhanh & Nhẹ)',
    description : 'Điện thoại RAM ≥ 3 GB • Tải ~469 MB',
    fileName    : 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    url         : 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF'
                  '/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    sizeGB      : 0.47,
  ),
  ModelChoice.standard: ModelInfo(
    name        : 'Qwen 2.5 — 1.5B (Tiêu Chuẩn)',
    description : 'Điện thoại RAM ≥ 5 GB • Tải ~1.04 GB',
    fileName    : 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    url         : 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF'
                  '/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sizeGB      : 1.04,
  ),
};

class ModelManager extends ChangeNotifier {
  static final ModelManager instance = ModelManager._();
  ModelManager._();

  ModelState   _state            = ModelState.notDownloaded;
  double       _progress         = 0;
  int          _downloadedBytes  = 0;
  int          _totalBytes       = 0;
  String?      _errorMsg;
  ModelChoice  _choice           = ModelChoice.lite;

  ModelState  get state           => _state;
  double      get progress        => _progress;
  int         get downloadedBytes => _downloadedBytes;
  int         get totalBytes      => _totalBytes;
  String?     get errorMsg        => _errorMsg;
  ModelChoice get choice          => _choice;
  ModelInfo   get info            => kModels[_choice]!;

  llama.LlamaController? _ctrl;
  http.Client?           _httpClient;
  bool                   _cancelDl = false;

  // ─── Khởi tạo khi mở app ────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = (prefs.getInt('model_choice') ?? 0)
        .clamp(0, ModelChoice.values.length - 1);
    _choice = ModelChoice.values[idx];

    // Thử load model đã chọn
    final f = await _modelFile(_choice);
    if (await f.exists()) { await _load(f); return; }

    // Thử model còn lại
    for (final c in ModelChoice.values) {
      if (c == _choice) continue;
      final ff = await _modelFile(c);
      if (await ff.exists()) { _choice = c; await _load(ff); return; }
    }
    _state = ModelState.notDownloaded;
    notifyListeners();
  }

  Future<File> _modelFile(ModelChoice c) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${kModels[c]!.fileName}');
  }

  Future<bool> isDownloaded(ModelChoice c) async =>
      (await _modelFile(c)).exists();

  // ─── Tải model từ HuggingFace ───────────────────────────
  Future<void> download(ModelChoice c) async {
    _cancelDl      = false;
    _choice        = c;
    _state         = ModelState.downloading;
    _progress      = 0;
    _downloadedBytes = 0;
    _totalBytes    = 0;
    _errorMsg      = null;
    notifyListeners();

    final file = await _modelFile(c);
    final info = kModels[c]!;

    // Dừng model cũ nếu có
    await _ctrl?.dispose();
    _ctrl = null;

    try {
      _httpClient = http.Client();
      final req = http.Request('GET', Uri.parse(info.url));
      final res = await _httpClient!.send(req);

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      _totalBytes = res.contentLength ??
          (info.sizeGB * 1024 * 1024 * 1024).round();

      final sink = file.openWrite();
      try {
        await for (final chunk in res.stream) {
          if (_cancelDl) {
            await sink.close();
            if (await file.exists()) await file.delete();
            _state = ModelState.notDownloaded;
            notifyListeners();
            return;
          }
          sink.add(chunk);
          _downloadedBytes += chunk.length;
          if (_totalBytes > 0) _progress = _downloadedBytes / _totalBytes;
          notifyListeners();
        }
      } finally {
        await sink.close();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('model_choice', c.index);

      await _load(file);
    } catch (e) {
      _state    = ModelState.error;
      _errorMsg = 'Lỗi tải: $e';
      if (await file.exists()) await file.delete();
      notifyListeners();
    } finally {
      _httpClient = null;
    }
  }

  void cancelDownload() {
    _cancelDl = true;
    _httpClient?.close();
  }

  // ─── Nạp model vào RAM ──────────────────────────────────
  Future<void> _load(File file) async {
    _state = ModelState.loadingModel;
    notifyListeners();
    try {
      await _ctrl?.dispose();
      _ctrl = llama.LlamaController();
      final gpu = await _ctrl!.detectGpu();
      await _ctrl!.loadModel(
        modelPath  : file.path,
        threads    : 4,
        contextSize: 4096,
        gpuLayers  : gpu.recommendedGpuLayers,
      );
      _state = ModelState.ready;
    } catch (e) {
      _state    = ModelState.error;
      _errorMsg = 'Lỗi nạp model: $e';
      _ctrl     = null;
    }
    notifyListeners();
  }

  // ─── Xóa model khỏi máy ─────────────────────────────────
  Future<void> deleteModel() async {
    if (_state == ModelState.ready || _state == ModelState.loadingModel) {
      await _ctrl?.dispose();
      _ctrl = null;
    }
    final f = await _modelFile(_choice);
    if (await f.exists()) await f.delete();
    _state = ModelState.notDownloaded;
    notifyListeners();
  }

  // ─── Sinh câu trả lời (Stream token) ───────────────────
  Stream<String> chat({
    required List<AppMessage> history,
    required bool detailed,
    required String subject,
  }) {
    if (_ctrl == null || _state != ModelState.ready) {
      return Stream.error(Exception('Model AI chưa sẵn sàng.'));
    }
    if (_ctrl!.isGenerating) {
      return Stream.error(Exception('AI đang xử lý, vui lòng chờ.'));
    }

    final sys = detailed
        ? _sysDetailed(subject)
        : _sysSocratic(subject);

    final msgs = <llama.ChatMessage>[
      llama.ChatMessage(role: 'system', content: sys),
    ];

    for (final m in history) {
      String c = m.text;
      if (m.ocrText != null && m.ocrText!.isNotEmpty) {
        c = '[Đề bài từ ảnh]\n${m.ocrText!}'
            '${m.text.isNotEmpty ? '\n\n${m.text}' : ''}';
      }
      if (c.trim().isEmpty) c = '[Học sinh gửi ảnh đề bài]';
      msgs.add(llama.ChatMessage(
        role   : m.role == 'user' ? 'user' : 'assistant',
        content: c.trim(),
      ));
    }

    return _ctrl!.generateChat(
      messages     : msgs,
      maxTokens    : 2048,
      temperature  : detailed ? 0.3 : 0.7,
      topP         : 0.9,
      topK         : 40,
      repeatPenalty: 1.1,
      template     : 'chatml',
    );
  }

  Future<void> stop() async => _ctrl?.stop();

  static String _sysDetailed(String sub) => '''
Bạn là "Gia Sư Tư Duy", trợ lý học tập AI chạy hoàn toàn trên điện thoại dành cho học sinh phổ thông Việt Nam. Phát triển bởi Nguyễn Hồng Quang (Lớp 10A10 — THPT Châu Thành 1).

Môn hiện tại: $sub

NHIỆM VỤ:
1. Đọc kỹ đề bài (có thể từ OCR ảnh chụp — kiểm tra lại nếu chữ bị nhận sai).
2. Giải đầy đủ từng bước theo SGK Việt Nam (Kết nối tri thức / Chân trời sáng tạo / Cánh diều).
3. Kiểm tra lại phép tính và công thức trước khi chốt đáp án.

Trình bày:
📋 **Đề bài**: (tóm tắt)
📝 **Lời giải**: (từng bước chi tiết)
✅ **Đáp án**: (kết quả cuối cùng)

Dùng tiếng Việt. Ngắn gọn, dễ đọc trên điện thoại nhỏ.
''';

  static String _sysSocratic(String sub) => '''
Bạn là gia sư Socratic kiên nhẫn, dành cho học sinh phổ thông Việt Nam. Môn: $sub.

NGUYÊN TẮC:
- KHÔNG giải trọn bài ngay. Dẫn dắt học sinh tự tư duy.
- Tóm tắt đề bài → Hỏi gợi mở bước 1.
- Học sinh đúng → khen ngắn + hỏi bước tiếp.
- Học sinh sai → chỉ nhẹ nhàng + gợi ý lại bằng ví dụ dễ hơn.
Dùng tiếng Việt, xưng "mình", gọi "bạn".
''';
}

// ============================================================
// OCR SERVICE
// ============================================================

class OcrService {
  static Future<String> read(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input  = InputImage.fromFile(imageFile);
      final result = await recognizer.processImage(input);
      return result.text.trim();
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}

// ============================================================
// DATA MODELS
// ============================================================

class AppMessage {
  final String  role;         // 'user' | 'model'
  final String  text;
  final String? imageBase64;
  final String? imageMimeType;
  final String? ocrText;      // text trích từ ảnh bằng OCR

  const AppMessage({
    required this.role,
    required this.text,
    this.imageBase64,
    this.imageMimeType,
    this.ocrText,
  });
}

class Subject {
  final String name;
  final String emoji;
  final Color  color;
  final String hint;
  const Subject({required this.name, required this.emoji,
      required this.color, required this.hint});
}

class _Colors {
  static const toan    = Color(0xFF1565C0);
  static const vatLy   = Color(0xFF6A1B9A);
  static const hoaHoc  = Color(0xFF2E7D32);
  static const tiengAnh= Color(0xFFE65100);
}

final subjects = [
  Subject(name:'Toán',      emoji:'📐', color:_Colors.toan,     hint:'Toán học'),
  Subject(name:'Vật Lý',    emoji:'⚡', color:_Colors.vatLy,    hint:'Vật Lý'),
  Subject(name:'Hóa Học',   emoji:'🧪', color:_Colors.hoaHoc,   hint:'Hóa Học'),
  Subject(name:'Tiếng Anh', emoji:'🌍', color:_Colors.tiengAnh, hint:'Tiếng Anh'),
];

// ============================================================
// APP ROOT
// ============================================================
class GiaSuTuDuyApp extends StatelessWidget {
  const GiaSuTuDuyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gia Sư Tư Duy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _Colors.toan),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    ),
    home: const HomeScreen(),
  );
}

// ============================================================
// HOME SCREEN
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _histories = List.generate(4, (_) => <AppMessage>[]);
  int _subIdx = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: subjects.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) setState(() => _subIdx = _tab.index);
      });
    ModelManager.instance.addListener(_onModelChange);
  }

  void _onModelChange() => setState(() {});

  @override
  void dispose() {
    ModelManager.instance.removeListener(_onModelChange);
    _tab.dispose();
    super.dispose();
  }

  Color get _color => subjects[_subIdx].color;

  void _openSettings() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const SettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: _color, brightness: Brightness.light),
      ),
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              elevation: 2,
              title: Row(children: [
                Text(subjects[_subIdx].emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  'Gia Sư Tư Duy — ${subjects[_subIdx].name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              actions: [
                // Model status chip
                _ModelStatusChip(color: _color),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Cài đặt',
                  onPressed: _openSettings,
                ),
              ],
              bottom: TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: subjects
                    .map((s) => Tab(text: '${s.emoji} ${s.name}'))
                    .toList(),
              ),
            ),
            body: TabBarView(
              controller: _tab,
              children: List.generate(subjects.length, (i) => ChatScreen(
                subject  : subjects[i],
                history  : _histories[i],
                onUpdate : (msgs) => setState(() => _histories[i] = msgs),
              )),
            ),
          ),

          // Overlay khi model chưa tải hoặc đang tải
          if (ModelManager.instance.state == ModelState.notDownloaded ||
              ModelManager.instance.state == ModelState.downloading   ||
              ModelManager.instance.state == ModelState.loadingModel  ||
              ModelManager.instance.state == ModelState.error)
            const ModelOverlay(),
        ],
      ),
    );
  }
}

// ─── Chip trạng thái model nhỏ ──────────────────────────────
class _ModelStatusChip extends StatelessWidget {
  final Color color;
  const _ModelStatusChip({required this.color});

  @override
  Widget build(BuildContext context) {
    final mm  = ModelManager.instance;
    String lbl;
    Color  bg;
    switch (mm.state) {
      case ModelState.ready:
        lbl = '🧠 AI';
        bg  = Colors.green.shade700;
        break;
      case ModelState.downloading:
        lbl = '⬇️ ${(mm.progress * 100).toStringAsFixed(0)}%';
        bg  = Colors.orange.shade700;
        break;
      case ModelState.loadingModel:
        lbl = '⏳ Nạp';
        bg  = Colors.orange.shade700;
        break;
      case ModelState.error:
        lbl = '❌ Lỗi';
        bg  = Colors.red.shade700;
        break;
      default:
        lbl = '📥 Tải AI';
        bg  = Colors.grey.shade600;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Chip(
        label: Text(lbl,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: bg,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ============================================================
// MODEL OVERLAY (download / loading / error)
// ============================================================
class ModelOverlay extends StatefulWidget {
  const ModelOverlay({super.key});
  @override
  State<ModelOverlay> createState() => _ModelOverlayState();
}

class _ModelOverlayState extends State<ModelOverlay> {
  @override
  Widget build(BuildContext context) {
    final mm = ModelManager.instance;
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              const Text('🧠', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('Gia Sư Tư Duy', style: TextStyle(
                  color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('AI Mã Nguồn Mở — Không Cần Internet',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 24),

              if (mm.state == ModelState.downloading)
                _buildDownloading(mm)
              else if (mm.state == ModelState.loadingModel)
                _buildLoading()
              else if (mm.state == ModelState.error)
                _buildError(mm)
              else
                _buildChoose(),
            ]),
          ),
        ),
      ),
    );
  }

  // Chọn model để tải
  Widget _buildChoose() => Column(mainAxisSize: MainAxisSize.min, children:[
    const Text('Chọn model AI để tải về máy:',
        style: TextStyle(color: Colors.white70, fontSize: 14)),
    const SizedBox(height: 16),
    ...ModelChoice.values.map((c) {
      final info = kModels[c]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => ModelManager.instance.download(c),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children:[
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Text(info.name, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(info.description, style: const TextStyle(
                        color: Colors.white60, fontSize: 12.5)),
                  ],
                )),
                const SizedBox(width: 12),
                const Icon(Icons.download_rounded, color: Color(0xFF82B1FF), size: 28),
              ]),
            ),
          ),
        ),
      );
    }),
    const SizedBox(height: 8),
    const Text('⚡ Dùng mạng WiFi để tải. Chỉ tải 1 lần duy nhất.',
        style: TextStyle(color: Colors.white38, fontSize: 11.5),
        textAlign: TextAlign.center),
  ]);

  // Đang tải
  Widget _buildDownloading(ModelManager mm) {
    final dlMB = (mm.downloadedBytes / 1024 / 1024).toStringAsFixed(1);
    final totMB = mm.totalBytes > 0
        ? '${(mm.totalBytes / 1024 / 1024).toStringAsFixed(0)} MB'
        : '...';
    return Column(mainAxisSize: MainAxisSize.min, children:[
      Text('Đang tải ${mm.info.name}',
          style: const TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: mm.progress,
          minHeight: 10,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF82B1FF)),
        ),
      ),
      const SizedBox(height: 10),
      Text('$dlMB MB / $totMB  •  ${(mm.progress * 100).toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: () => ModelManager.instance.cancelDownload(),
        icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
        label: const Text('Huỷ tải', style: TextStyle(color: Colors.redAccent)),
      ),
    ]);
  }

  // Đang nạp model
  Widget _buildLoading() => Column(mainAxisSize: MainAxisSize.min, children:[
    const CircularProgressIndicator(color: Color(0xFF82B1FF)),
    const SizedBox(height: 16),
    const Text('Đang nạp AI vào bộ nhớ…',
        style: TextStyle(color: Colors.white, fontSize: 15)),
    const SizedBox(height: 8),
    const Text('Lần đầu có thể mất 10–30 giây',
        style: TextStyle(color: Colors.white54, fontSize: 12.5)),
  ]);

  // Lỗi
  Widget _buildError(ModelManager mm) => Column(mainAxisSize: MainAxisSize.min, children:[
    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
    const SizedBox(height: 12),
    Text(mm.errorMsg ?? 'Có lỗi xảy ra',
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: () => setState(() {}),
      icon: const Icon(Icons.refresh),
      label: const Text('Thử lại'),
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF82B1FF)),
    ),
  ]);
}

// ============================================================
// CHAT SCREEN
// ============================================================
class ChatScreen extends StatefulWidget {
  final Subject             subject;
  final List<AppMessage>    history;
  final ValueChanged<List<AppMessage>> onUpdate;
  const ChatScreen({super.key, required this.subject,
      required this.history, required this.onUpdate});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input    = TextEditingController();
  final _scroll   = ScrollController();
  final _picker   = ImagePicker();

  bool   _detailed     = true;
  bool   _isOcring     = false;
  bool   _isStreaming  = false;
  String _streaming    = '';
  StreamSubscription<String>? _sub;

  File?   _img;
  String? _imgB64;
  String? _imgMime;
  String? _ocrText;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _detailed = p.getBool('detailed_mode') ?? true);
  }

  Future<void> _toggleMode(bool v) async {
    setState(() => _detailed = v);
    (await SharedPreferences.getInstance()).setBool('detailed_mode', v);
  }

  @override
  void dispose() {
    _sub?.cancel();
    ModelManager.instance.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  });

  // ─── Chọn ảnh ─────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    try {
      final x = await _picker.pickImage(source:src, imageQuality:85,
          maxWidth:1920, maxHeight:1920);
      if (x == null) return;
      final file  = File(x.path);
      final bytes = await file.readAsBytes();
      final b64   = base64Encode(bytes);
      final ext   = x.path.split('.').last.toLowerCase();
      final mime  = ext == 'png' ? 'image/png' : 'image/jpeg';

      setState(() {
        _img      = file;
        _imgB64   = b64;
        _imgMime  = mime;
        _ocrText  = null;
        _isOcring = true;
      });

      // OCR tự động
      final ocr = await OcrService.read(file);
      if (mounted) setState(() { _ocrText = ocr; _isOcring = false; });
    } catch (e) {
      if (mounted) setState(() => _isOcring = false);
      _err('Không thể chọn ảnh: $e');
    }
  }

  void _showImgMenu() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SafeArea(child: Wrap(children:[
      ListTile(
        leading: Icon(Icons.camera_alt, color: widget.subject.color),
        title: const Text('Chụp ảnh đề bài'),
        onTap: (){ Navigator.pop(context); _pickImage(ImageSource.camera); },
      ),
      ListTile(
        leading: Icon(Icons.photo_library, color: widget.subject.color),
        title: const Text('Chọn từ thư viện'),
        onTap: (){ Navigator.pop(context); _pickImage(ImageSource.gallery); },
      ),
    ])),
  );

  void _clearImg() => setState(() {
    _img=null; _imgB64=null; _imgMime=null; _ocrText=null;
  });

  // ─── Gửi tin nhắn ─────────────────────────────────────────
  Future<void> _send() async {
    if (ModelManager.instance.state != ModelState.ready) {
      _err('AI chưa sẵn sàng. Vui lòng tải model trước.');
      return;
    }
    final txt = _input.text.trim();
    if (txt.isEmpty && _img == null) return;
    if (_isStreaming || _isOcring) return;

    final userMsg = AppMessage(
      role         : 'user',
      text         : txt,
      imageBase64  : _imgB64,
      imageMimeType: _imgMime,
      ocrText      : _ocrText,
    );

    final hist = [...widget.history, userMsg];
    widget.onUpdate(hist);
    _input.clear();
    _clearImg();

    setState(() { _isStreaming = true; _streaming = ''; });
    _scrollBottom();

    final stream = ModelManager.instance.chat(
      history : hist,
      detailed: _detailed,
      subject : widget.subject.hint,
    );

    _sub = stream.listen(
      (tok) {
        if (mounted) {
          setState(() => _streaming += tok);
          _scrollBottom();
        }
      },
      onDone: () {
        if (!mounted) return;
        final txt = _streaming.trim().isNotEmpty ? _streaming.trim()
            : '(Không có phản hồi)';
        widget.onUpdate([...hist, AppMessage(role:'model', text:txt)]);
        setState(() { _isStreaming = false; _streaming = ''; });
        _scrollBottom();
      },
      onError: (e) {
        if (!mounted) return;
        _err('Lỗi AI: $e');
        setState(() { _isStreaming = false; _streaming = ''; });
      },
      cancelOnError: true,
    );
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(children:[
        _modeBar(),
        Expanded(child: widget.history.isEmpty && !_isStreaming
            ? _emptyState()
            : _msgList()),
        _inputArea(),
      ]),
    );
  }

  Widget _modeBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
    child: Row(children:[
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children:[
          ChoiceChip(
            label: const Text('📖 Giải chi tiết',
                style: TextStyle(fontSize: 12)),
            selected: _detailed,
            selectedColor: widget.subject.color.withOpacity(0.16),
            onSelected: (_) => _toggleMode(true),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('💡 Gợi mở',
                style: TextStyle(fontSize: 12)),
            selected: !_detailed,
            selectedColor: widget.subject.color.withOpacity(0.16),
            onSelected: (_) => _toggleMode(false),
            visualDensity: VisualDensity.compact,
          ),
          if (_isStreaming) ...[ const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () { _sub?.cancel(); ModelManager.instance.stop();
                setState(() { _isStreaming = false; _streaming = ''; }); },
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Dừng', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.red,
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ]),
      )),
      if (widget.history.isNotEmpty)
        IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade600),
          tooltip: 'Xóa lịch sử',
          onPressed: () => widget.onUpdate([]),
          visualDensity: VisualDensity.compact,
        ),
    ]),
  );

  Widget _msgList() => ListView.builder(
    controller : _scroll,
    padding    : const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    itemCount  : widget.history.length + (_isStreaming ? 1 : 0),
    itemBuilder: (ctx, i) {
      if (i == widget.history.length) {
        return _streaming.isNotEmpty
            ? _bubble(AppMessage(role:'model', text:_streaming), streaming:true)
            : _loadingBubble();
      }
      return _bubble(widget.history[i]);
    },
  );

  Widget _emptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children:[
        Text(widget.subject.emoji, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        Text('Gia Sư Tư Duy', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: widget.subject.color)),
        const SizedBox(height: 8),
        Text('Hỏi bài về môn ${widget.subject.name}\nhoặc gửi ảnh đề bài để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.subject.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.subject.color.withOpacity(0.2)),
          ),
          child: Text(
            _detailed
              ? '📸 Chụp ảnh đề bài → AI tự đọc chữ (OCR) và giải ngay trên máy — không cần mạng!'
              : '💡 Gia sư gợi mở từng bước để bạn tự tư duy ra đáp án.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: widget.subject.color, height: 1.5),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text('👨‍🎓 $authorName • $authorSchool • v$appVersion',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );

  // ─── Bubble tin nhắn ──────────────────────────────────────
  Widget _bubble(AppMessage m, {bool streaming = false}) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:[
          if (!isUser) ...[ CircleAvatar(
            radius: 16, backgroundColor: widget.subject.color.withOpacity(0.15),
            child: Text(widget.subject.emoji,
                style: const TextStyle(fontSize: 14)),
          ), const SizedBox(width: 6)],

          Flexible(child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80),
            decoration: BoxDecoration(
              color: isUser ? widget.subject.color : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.only(
                topLeft    : const Radius.circular(18),
                topRight   : const Radius.circular(18),
                bottomLeft : Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 4, offset: const Offset(0,2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                // Ảnh đính kèm
                if (m.imageBase64 != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                    child: Image.memory(base64Decode(m.imageBase64!),
                        fit: BoxFit.cover, width: double.infinity, height: 160),
                  ),

                // OCR badge
                if (m.ocrText != null && m.ocrText!.isNotEmpty && isUser)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('📝 OCR: ${m.ocrText!.length > 60
                          ? '${m.ocrText!.substring(0,60)}…' : m.ocrText!}',
                        style: const TextStyle(color: Colors.white70,
                            fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),

                // Nội dung text
                Padding(
                  padding: EdgeInsets.fromLTRB(12,
                      (m.imageBase64 != null || (m.ocrText != null && m.ocrText!.isNotEmpty)) ? 6 : 10,
                      12, 10),
                  child: _richText(m.text, isUser),
                ),

                // Streaming cursor
                if (streaming)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Container(width: 10, height: 14,
                        color: Colors.grey.shade500),
                  ),
              ],
            ),
          )),

          if (isUser) ...[ const SizedBox(width: 6), CircleAvatar(
            radius: 16, backgroundColor: widget.subject.color,
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          )],
        ],
      ),
    );
  }

  Widget _richText(String text, bool isUser) {
    final base = isUser ? Colors.white : const Color(0xFF212121);
    if (!text.contains('**') && !text.contains('\n')) {
      return Text(text,
          style: TextStyle(color: base, fontSize: 14.5, height: 1.45));
    }
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.*?)\*\*');
    int end = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > end) spans.add(TextSpan(text: text.substring(end, m.start),
          style: TextStyle(color: base, fontSize: 14.5, height: 1.45)));
      spans.add(TextSpan(text: m.group(1),
          style: TextStyle(color: base, fontSize: 14.5, height: 1.45,
              fontWeight: FontWeight.w700)));
      end = m.end;
    }
    if (end < text.length) spans.add(TextSpan(text: text.substring(end),
        style: TextStyle(color: base, fontSize: 14.5, height: 1.45)));
    return Text.rich(TextSpan(children: spans));
  }

  Widget _loadingBubble() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children:[
      CircleAvatar(radius:16,
          backgroundColor: widget.subject.color.withOpacity(0.15),
          child: Text(widget.subject.emoji,
              style: const TextStyle(fontSize:14))),
      const SizedBox(width:6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),
        decoration: BoxDecoration(color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children:[
          _Dot(color: widget.subject.color, delay: 0),
          const SizedBox(width: 4),
          _Dot(color: widget.subject.color, delay: 150),
          const SizedBox(width: 4),
          _Dot(color: widget.subject.color, delay: 300),
        ]),
      ),
    ]),
  );

  // ─── Input area ───────────────────────────────────────────
  Widget _inputArea() => Container(
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0,-2))]),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children:[

      // Preview ảnh + OCR
      if (_img != null) _imgPreview(),

      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children:[
          // Nút ảnh
          IconButton(
            icon: _isOcring
                ? SizedBox(width:22, height:22,
                    child: CircularProgressIndicator(
                        strokeWidth:2, color: widget.subject.color))
                : Icon(Icons.add_a_photo_outlined, color: widget.subject.color),
            tooltip: 'Chụp/chọn ảnh đề bài',
            onPressed: _isOcring ? null : _showImgMenu,
          ),

          // Text field
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.subject.color.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _input,
              maxLines: 4, minLines: 1,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Hỏi về môn ${widget.subject.name}…',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          )),

          const SizedBox(width: 6),

          // Nút gửi
          Material(
            color: _isStreaming
                ? Colors.grey.shade400
                : widget.subject.color,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: (_isStreaming || _isOcring) ? null : _send,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: _isStreaming
                    ? const SizedBox(width:22, height:22,
                        child: CircularProgressIndicator(
                            strokeWidth:2, color:Colors.white))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ),
    ])),
  );

  Widget _imgPreview() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Stack(clipBehavior: Clip.none, children:[
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(_img!, height:80, width:80, fit:BoxFit.cover),
      ),
      Positioned(top:-6, right:-6, child: GestureDetector(
        onTap: _clearImg,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color:Colors.red, shape:BoxShape.circle),
          child: const Icon(Icons.close, size:14, color:Colors.white),
        ),
      )),
      if (_ocrText != null && _ocrText!.isNotEmpty)
        Positioned(left:88, top:0, right:0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '✅ OCR đọc được ${_ocrText!.length} ký tự:\n'
              '${_ocrText!.length > 80 ? '${_ocrText!.substring(0,80)}…' : _ocrText!}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
            ),
          ),
        )
      else if (_isOcring)
        Positioned(left:88, top:0, right:0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: const Text('⏳ Đang đọc chữ từ ảnh…',
                style: TextStyle(fontSize:11, color: Colors.grey)),
          ),
        )
      else if (_ocrText != null && _ocrText!.isEmpty)
        Positioned(left:88, top:0, right:0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200)),
            child: const Text('⚠️ Không đọc được chữ từ ảnh.\nVui lòng gõ đề bài vào ô bên dưới.',
                style: TextStyle(fontSize:11, color: Colors.orange)),
          ),
        ),
    ]),
  );
}

// ─── Dot animation ──────────────────────────────────────────
class _Dot extends StatefulWidget {
  final Color color;
  final int   delay;
  const _Dot({required this.color, required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync:this,
        duration: const Duration(milliseconds:600));
    _a = Tween(begin:0.0, end:-6.0).animate(
        CurvedAnimation(parent:_c, curve:Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse:true);
    });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_,__) => Transform.translate(offset: Offset(0, _a.value),
      child: Container(width:7, height:7,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ),
  );
}

// ============================================================
// SETTINGS SHEET
// ============================================================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool   _loading      = true;
  bool?  _liteExists;
  bool?  _stdExists;
  bool   _deleting     = false;

  @override
  void initState() {
    super.initState();
    ModelManager.instance.addListener(_onMM);
    _refresh();
  }

  @override
  void dispose() {
    ModelManager.instance.removeListener(_onMM);
    super.dispose();
  }

  void _onMM() => setState(() {});

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _liteExists = await ModelManager.instance.isDownloaded(ModelChoice.lite);
    _stdExists  = await ModelManager.instance.isDownloaded(ModelChoice.standard);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final mm = ModelManager.instance;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize:MainAxisSize.min, crossAxisAlignment:CrossAxisAlignment.start, children:[

          // Header
          Row(children:[
            const Icon(Icons.settings, color: _Colors.toan),
            const SizedBox(width: 10),
            const Expanded(child: Text('Cài đặt & Quản lý AI',
                style: TextStyle(fontSize:18, fontWeight:FontWeight.w700))),
            Chip(label: Text('v$appVersion',
                style: const TextStyle(fontSize:11, fontWeight:FontWeight.w700,
                    color: _Colors.toan))),
            IconButton(icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),

          const SizedBox(height: 8),

          // Tác giả
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _Colors.toan.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Colors.toan.withOpacity(0.2)),
            ),
            child: const Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('👨‍🎓 Phát triển bởi: $authorName',
                    style: TextStyle(fontWeight:FontWeight.w700, fontSize:13.5,
                        color: _Colors.toan)),
                SizedBox(height: 2),
                Text('$authorSchool • Phiên bản v$appVersion',
                    style: TextStyle(fontSize:12.5)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text('🧠 Quản lý Model AI (Qwen 2.5)',
              style: TextStyle(fontSize:14, fontWeight:FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('Model chạy hoàn toàn trên điện thoại — không cần internet sau khi tải.',
              style: TextStyle(fontSize:12, color:Colors.grey)),
          const SizedBox(height: 10),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...ModelChoice.values.map((c) {
            final info     = kModels[c]!;
            final exists   = c == ModelChoice.lite ? _liteExists! : _stdExists!;
            final isActive = mm.choice == c && mm.state == ModelState.ready;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.shade50
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isActive
                          ? Colors.green.shade300
                          : Colors.grey.shade300),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal:14, vertical:4),
                  title: Text(info.name,
                      style: TextStyle(fontWeight:FontWeight.w700,
                          fontSize:13.5,
                          color: isActive ? Colors.green.shade800 : null)),
                  subtitle: Text(
                    info.description + (exists
                        ? '\n✅ Đã tải ${(info.sizeGB * 1024).toStringAsFixed(0)} MB'
                        : '\n📥 Chưa tải'),
                    style: TextStyle(fontSize:12,
                        color: isActive ? Colors.green.shade700 : null),
                  ),
                  trailing: exists
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) async {
                            if (v == 'delete') {
                              setState(() => _deleting = true);
                              await mm.deleteModel();
                              await _refresh();
                              setState(() => _deleting = false);
                            } else if (v == 'load') {
                              Navigator.pop(context);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!isActive) const PopupMenuItem(
                                value:'load',
                                child: Text('Khởi động lại app để dùng')),
                            const PopupMenuItem(
                                value:'delete',
                                child: Text('Xóa khỏi máy',
                                    style:TextStyle(color:Colors.red))),
                          ],
                        )
                      : FilledButton.icon(
                          onPressed: mm.state == ModelState.downloading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  mm.download(c);
                                },
                          icon: const Icon(Icons.download, size:16),
                          label: const Text('Tải về', style:TextStyle(fontSize:12)),
                          style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal:12, vertical:6)),
                        ),
                ),
              ),
            );
          }),

          if (_deleting)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            )),

          const SizedBox(height: 8),

          // Thông tin
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: const Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('ℹ️ Thông tin kỹ thuật:',
                    style:TextStyle(fontWeight:FontWeight.w700, fontSize:12.5)),
                SizedBox(height:6),
                Text(
                  '• AI engine: llama.cpp + Qwen 2.5 (mã nguồn mở)\n'
                  '• OCR engine: Google ML Kit (nhận diện chữ từ ảnh)\n'
                  '• Yêu cầu: Android 8.0+ (ARM64), RAM ≥ 3 GB\n'
                  '• Môn hỗ trợ: Toán, Vật Lý, Hóa Học, Tiếng Anh',
                  style: TextStyle(fontSize:12, height:1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}
