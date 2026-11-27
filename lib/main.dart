// ============================================================
// GIA SƯ TƯ DUY — Ứng dụng gia sư Socratic cho học sinh Việt Nam
// Tệp duy nhất: lib/main.dart
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Hàm main ───────────────────────────────────────────────
void main() {
  runApp(const GiaSuTuDuyApp());
}

// ─── Phiên bản, Tác giả & Cấu hình Model Gemini ─────────────
const String appVersion = '1.0.3';
const String authorName = 'Nguyễn Hồng Quang';
const String authorClassSchool = 'Lớp 10A10 — THPT Châu Thành 1';
const String defaultGeminiModel = 'gemini-3.5-flash-lite';
const String defaultWorkerProxyUrl = '';

class GeminiModelOption {
  final String id;
  final String label;
  final String subtitle;

  const GeminiModelOption({
    required this.id,
    required this.label,
    required this.subtitle,
  });
}

// Danh sách các model Flash / Flash-Lite (ưu tiên nhẹ, nhanh, free tier cao)
const List<GeminiModelOption> geminiModelOptions = [
  GeminiModelOption(
    id: 'gemini-3.5-flash-lite',
    label: 'Gemini 3.5 Flash-Lite (Khuyên dùng)',
    subtitle: 'Siêu nhanh, nhẹ, tối ưu quota miễn phí',
  ),
  GeminiModelOption(
    id: 'gemini-3.8-flash',
    label: 'Gemini 3.8 Flash',
    subtitle: 'Thế hệ mới, suy luận Toán/Lý/Hóa mạnh hơn',
  ),
  GeminiModelOption(
    id: 'gemini-2.5-flash-lite',
    label: 'Gemini 2.5 Flash-Lite',
    subtitle: 'Bản nhẹ dự phòng ổn định',
  ),
  GeminiModelOption(
    id: 'gemini-2.5-flash',
    label: 'Gemini 2.5 Flash',
    subtitle: 'Bản tiêu chuẩn cân bằng',
  ),
];

// ─── Màu sắc cho từng môn học ───────────────────────────────
class SubjectColors {
  static const Color toan = Color(0xFF1565C0);     // Toán – Xanh dương
  static const Color vatLy = Color(0xFF6A1B9A);    // Vật Lý – Tím
  static const Color hoaHoc = Color(0xFF2E7D32);   // Hóa Học – Xanh lá
  static const Color tiengAnh = Color(0xFFE65100); // Tiếng Anh – Cam
}

// ─── Model dữ liệu môn học ──────────────────────────────────
class Subject {
  final String name;
  final String emoji;
  final Color color;
  final String systemHint; // gợi ý thêm cho môn

  const Subject({
    required this.name,
    required this.emoji,
    required this.color,
    required this.systemHint,
  });
}

// Danh sách 4 môn học
final List<Subject> subjects = [
  Subject(
    name: 'Toán',
    emoji: '📐',
    color: SubjectColors.toan,
    systemHint: 'Môn Toán học',
  ),
  Subject(
    name: 'Vật Lý',
    emoji: '⚡',
    color: SubjectColors.vatLy,
    systemHint: 'Môn Vật Lý',
  ),
  Subject(
    name: 'Hóa Học',
    emoji: '🧪',
    color: SubjectColors.hoaHoc,
    systemHint: 'Môn Hóa Học',
  ),
  Subject(
    name: 'Tiếng Anh',
    emoji: '🌍',
    color: SubjectColors.tiengAnh,
    systemHint: 'Môn Tiếng Anh',
  ),
];

// ─── System Instruction 1: Giải chi tiết & Đối chiếu nguồn (Mặc định) ───
const String detailedSystemInstruction = '''
Bạn là "Gia Sư Tư Duy", trợ lý học tập thông minh dành cho học sinh phổ thông Việt Nam, được phát triển bởi Nguyễn Hồng Quang (Lớp 10A10 - THPT Châu Thành 1).

NHIỆM VỤ KHI NHẬN BÀI TẬP (CHỮ HOẶC ẢNH):

BƯỚC 1 — Nhận diện bài:
- Nếu là ảnh: Đọc rõ đề bài, nhận diện tên bài/trang/sách giáo khoa (nếu có, ví dụ: "Bài 3 trang 15 SGK Toán 10").
- Xác định môn học (Toán, Lý, Hóa, Tiếng Anh...) và bộ sách (Kết nối tri thức / Chân trời sáng tạo / Cánh diều).

BƯỚC 2 — Tra cứu lời giải:
- Sử dụng Google Search để tìm lời giải trên:
  🥇 ƯU TIÊN 1: vietjack.com — Tìm cụm từ "site:vietjack.com [tên bài]"
  🥈 ƯU TIÊN 2: loigiaihay.com — Tìm cụm từ "site:loigiaihay.com [tên bài]"
  🥉 Dự phòng: hoc247.net, tech12h.com, haylamdo.com
- Lấy lời giải ĐẦY ĐỦ từ các trang này.

BƯỚC 3 — Trình bày kết quả:
Trình bày theo cấu trúc:

📋 **ĐỀ BÀI**: (tóm tắt yêu cầu)

📝 **LỜI GIẢI CHI TIẾT**:
(Trình bày từng bước rõ ràng, đầy đủ)

✅ **ĐÁP ÁN**: (kết quả cuối cùng)

🔗 **NGUỒN**: (Ghi rõ: VietJack / Lời Giải Hay / Hoc247 / ... hoặc "Phân tích theo SGK" nếu không tìm được trên web)

QUY TẮC BẮT BUỘC:
- KHÔNG bịa đặt tên trang web hay đường link không có thật.
- Nếu tìm được lời giải trên VietJack hoặc Lời Giải Hay → trình bày lại ĐẦY ĐỦ từng bước từ nguồn đó.
- Nếu không tìm được → tự giải theo kiến thức SGK và ghi "Phân tích theo SGK phổ thông".
- Luôn kiểm tra lại phép tính, công thức, đơn vị trước khi chốt đáp án.
- Trình bày ngắn gọn, dễ đọc trên điện thoại.
''';

// ─── System Instruction 2: Chế độ Socratic (Gợi mở từng bước) ───
const String socraticSystemInstruction = '''
Bạn là một Gia sư Socratic tận tâm, kiên nhẫn dành cho học sinh phổ thông Việt Nam (Toán, Lý, Hóa, Tiếng Anh).

NGUYÊN TẮC BẮT BUỘC:

1. TUYỆT ĐỐI KHÔNG giải trọn vẹn bài tập và KHÔNG đưa ra đáp án cuối cùng ngay lập tức, kể cả khi học sinh năn nỉ hoặc yêu cầu "giải nhanh giúp em".

2. Chia nhỏ vấn đề: Khi nhận được đề bài (bằng chữ hoặc ảnh), hãy xác định kiến thức trọng tâm, tóm tắt ngắn gọn đề bài đang hỏi gì, sau đó chỉ đưa ra 1 gợi ý nhỏ hoặc 1 câu hỏi dẫn dắt đầu tiên để học sinh tự thực hiện bước 1.

3. Phản hồi theo câu trả lời của học sinh:
- Nếu học sinh làm đúng bước đó: Khen ngợi ngắn gọn và đặt câu hỏi gợi mở cho bước tiếp theo.
- Nếu học sinh làm sai: Không chê bai, chỉ ra chỗ chưa hợp lý ở bước đó và gợi ý lại bằng một ví dụ dễ hiểu hơn.
- Nếu học sinh bí hoàn toàn ("em không biết làm"): Gợi ý công thức hoặc quy tắc ngữ pháp liên quan, sau đó hỏi lại cách áp dụng vào số liệu/câu chữ trong bài.

4. Văn phong: Thân thiện, xưng "mình" và gọi "bạn" (hoặc "thầy/cô - em"), trình bày ngắn gọn, thoáng mắt để dễ đọc trên màn hình điện thoại.
''';

// ─── Model nguồn tham khảo trích xuất từ Google Search Grounding ───
class SourceReference {
  final String title;
  final String uri;

  const SourceReference({required this.title, required this.uri});
}

// ─── Model kết quả trả về từ API ────────────────────────────
class _GeminiApiResult {
  final String text;
  final List<SourceReference> sources;

  const _GeminiApiResult({required this.text, this.sources = const []});
}

// ─── Model tin nhắn ─────────────────────────────────────────
class ChatMessage {
  final String role; // 'user' hoặc 'model'
  final String text;
  final String? imageBase64; // base64 ảnh đính kèm (chỉ user)
  final String? imageMimeType;
  final List<SourceReference> sources; // danh sách nguồn tham khảo (chỉ model)

  const ChatMessage({
    required this.role,
    required this.text,
    this.imageBase64,
    this.imageMimeType,
    this.sources = const [],
  });

  // Chuyển thành định dạng Gemini API
  Map<String, dynamic> toApiContent() {
    final List<Map<String, dynamic>> parts = [];

    // Thêm ảnh nếu có
    if (imageBase64 != null && imageMimeType != null) {
      parts.add({
        'inline_data': {
          'mime_type': imageMimeType,
          'data': imageBase64,
        }
      });
    }

    // Thêm text
    if (text.isNotEmpty) {
      parts.add({'text': text});
    }

    return {'role': role, 'parts': parts};
  }
}

// ============================================================
// App Root Widget
// ============================================================
class GiaSuTuDuyApp extends StatelessWidget {
  const GiaSuTuDuyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gia Sư Tư Duy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: SubjectColors.toan,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// Màn hình chính với TabBar
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lịch sử chat riêng cho từng môn học
  final List<List<ChatMessage>> _histories =
      List.generate(4, (_) => []);

  int _currentSubjectIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: subjects.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {
            _currentSubjectIndex = _tabController.index;
          });
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Màu môn hiện tại
  Color get _currentColor => subjects[_currentSubjectIndex].color;

  // Mở dialog cài đặt API key
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Áp dụng màu sắc theo môn học hiện tại
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _currentColor,
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _currentColor,
          foregroundColor: Colors.white,
          elevation: 2,
          title: Row(
            children: [
              Text(
                subjects[_currentSubjectIndex].emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              Text(
                'Gia Sư Tư Duy — ${subjects[_currentSubjectIndex].name}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Cài đặt API Key',
              onPressed: _openSettings,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: subjects
                .map((s) => Tab(text: '${s.emoji} ${s.name}'))
                .toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(
            subjects.length,
            (i) => ChatScreen(
              subject: subjects[i],
              history: _histories[i],
              onHistoryUpdate: (msgs) {
                setState(() {
                  _histories[i] = msgs;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Màn hình Chat cho từng môn
// ============================================================
class ChatScreen extends StatefulWidget {
  final Subject subject;
  final List<ChatMessage> history;
  final ValueChanged<List<ChatMessage>> onHistoryUpdate;

  const ChatScreen({
    super.key,
    required this.subject,
    required this.history,
    required this.onHistoryUpdate,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _detailedMode = true; // Mặc định: giải chi tiết chính xác + ghi nguồn
  File? _selectedImage;      // ảnh đã chọn
  String? _imageBase64;      // base64 của ảnh
  String? _imageMimeType;    // mime type ảnh

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadModePreference();
  }

  Future<void> _loadModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _detailedMode = prefs.getBool('detailed_solution_mode') ?? true;
    });
  }

  Future<void> _toggleSolveMode(bool detailed) async {
    setState(() => _detailedMode = detailed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('detailed_solution_mode', detailed);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Cuộn xuống cuối danh sách tin nhắn
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Chọn ảnh từ camera hoặc thư viện
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      final File file = File(picked.path);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);

      // Xác định mime type từ extension
      final ext = picked.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

      setState(() {
        _selectedImage = file;
        _imageBase64 = base64Str;
        _imageMimeType = mime;
      });
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  // Hiển thị menu chọn nguồn ảnh
  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: widget.subject.color),
              title: const Text('Chụp ảnh bài tập'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: widget.subject.color),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Xóa ảnh đã chọn
  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
      _imageMimeType = null;
    });
  }

  // Gửi tin nhắn
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _imageBase64 == null) return;

    // Lấy API key, proxy URL và model đã chọn từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';
    final savedProxy = prefs.getString('worker_proxy_url')?.trim() ?? '';
    final proxyUrl =
        savedProxy.isNotEmpty ? savedProxy : defaultWorkerProxyUrl;
    final selectedModel =
        prefs.getString('gemini_model') ?? defaultGeminiModel;

    if (apiKey.isEmpty && proxyUrl.isEmpty) {
      _showError('Vui lòng nhập Gemini API Key hoặc Worker URL trong cài đặt ⚙️');
      return;
    }

    // Thêm tin nhắn của người dùng vào lịch sử
    final userMsg = ChatMessage(
      role: 'user',
      text: text,
      imageBase64: _imageBase64,
      imageMimeType: _imageMimeType,
    );

    final updatedHistory = [...widget.history, userMsg];
    widget.onHistoryUpdate(updatedHistory);

    // Reset ô nhập
    _inputController.clear();
    _clearImage();

    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      final result = await _callGeminiAPI(
        apiKey: apiKey,
        proxyUrl: proxyUrl,
        history: updatedHistory,
        preferredModel: selectedModel,
        detailedMode: _detailedMode,
      );

      final aiMsg = ChatMessage(
        role: 'model',
        text: result.text,
        sources: result.sources,
      );
      widget.onHistoryUpdate([...updatedHistory, aiMsg]);
    } catch (e) {
      _showError('Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // Xây dựng payload gửi Gemini API
  String _buildRequestBody(
    List<ChatMessage> history, {
    required bool detailedMode,
    required bool useSearchGrounding,
  }) {
    final contents = history.map((m) => m.toApiContent()).toList();
    final payload = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {
            'text': detailedMode
                ? detailedSystemInstruction
                : socraticSystemInstruction,
          }
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': detailedMode ? 0.3 : 0.7,
        'maxOutputTokens': 4096,
      },
    };

    if (useSearchGrounding) {
      payload['tools'] = [
        {'google_search': {}}
      ];
    }

    return jsonEncode(payload);
  }

  // Trích xuất nguồn tham khảo thực tế từ groundingMetadata (VietJack, Lời Giải Hay...)
  List<SourceReference> _extractSources(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return const [];

    final metadata = candidates[0]?['groundingMetadata'] as Map<String, dynamic>?;
    final chunks = metadata?['groundingChunks'] as List<dynamic>?;
    if (chunks == null) return const [];

    final seenUris = <String>{};
    final result = <SourceReference>[];

    for (final chunk in chunks) {
      final web = chunk?['web'] as Map<String, dynamic>?;
      final uri = (web?['uri'] as String?)?.trim() ?? '';
      if (uri.isEmpty || !seenUris.add(uri)) continue;

      final rawTitle = (web?['title'] as String?)?.trim() ?? '';
      final title = rawTitle.isNotEmpty ? rawTitle : uri;
      result.add(SourceReference(title: title, uri: uri));
    }

    return result;
  }

  // Gọi Gemini API qua Worker Proxy hoặc trực tiếp, tự fallback nếu lỗi/bận
  Future<_GeminiApiResult> _callGeminiAPI({
    required String apiKey,
    required String proxyUrl,
    required List<ChatMessage> history,
    required String preferredModel,
    required bool detailedMode,
  }) async {
    final candidateModels = <String>{
      preferredModel.trim().isEmpty ? defaultGeminiModel : preferredModel.trim(),
      'gemini-3.5-flash-lite',
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash',
      'gemini-3.8-flash',
    }.toList();

    final cleanProxy = proxyUrl.endsWith('/')
        ? proxyUrl.substring(0, proxyUrl.length - 1)
        : proxyUrl;

    Exception? lastError;

    for (final model in candidateModels) {
      // Thử bật Google Search Grounding trước khi ở chế độ giải chi tiết;
      // nếu model/key báo 400 không hỗ trợ tool search, thử lại không có tool.
      final searchAttempts = detailedMode ? [true, false] : [false];

      for (final useSearch in searchAttempts) {
        final uri = cleanProxy.isNotEmpty
            ? Uri.parse('$cleanProxy/v1beta/models/$model:generateContent')
            : Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
              );

        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: _buildRequestBody(
                history,
                detailedMode: detailedMode,
                useSearchGrounding: useSearch,
              ),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final parts =
              data['candidates']?[0]?['content']?['parts'] as List<dynamic>?;
          final text = parts
                  ?.map((p) => p?['text'] as String?)
                  .whereType<String>()
                  .join('\n')
                  .trim() ??
              '';
          final sources = _extractSources(data);
          return _GeminiApiResult(
            text: text.isNotEmpty ? text : '(Không có phản hồi)',
            sources: sources,
          );
        }

        String errMsg = 'Lỗi không xác định';
        try {
          final err = jsonDecode(response.body);
          errMsg = err['error']?['message'] ?? errMsg;
        } catch (_) {}

        lastError =
            Exception('API Error ${response.statusCode} ($model): $errMsg');

        // Nếu đang bật search mà bị 400 (model/key chưa hỗ trợ grounding) -> thử lại tắt search
        if (useSearch && response.statusCode == 400) {
          continue;
        }

        final shouldFallbackModel = response.statusCode == 404 ||
            response.statusCode == 429 ||
            response.statusCode == 503;
        if (shouldFallbackModel) {
          break; // Chuyển sang model dự phòng tiếp theo
        }

        throw lastError;
      }
    }

    throw lastError ?? Exception('Không thể kết nối tới các model Gemini');
  }

  // Hiển thị thông báo lỗi
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Ẩn bàn phím khi nhấn ra ngoài
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Thanh chuyển chế độ Giải chi tiết / Gợi mở Socratic
          _buildModeBar(),

          // Danh sách tin nhắn
          Expanded(
            child: widget.history.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    itemCount: widget.history.length + (_isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == widget.history.length) {
                        // Hiển thị indicator đang tải
                        return _buildLoadingBubble();
                      }
                      return _buildMessageBubble(widget.history[i]);
                    },
                  ),
          ),

          // Khu vực nhập liệu
          _buildInputArea(),
        ],
      ),
    );
  }

  // Thanh chọn nhanh chế độ trả lời & xóa cuộc trò chuyện
  Widget _buildModeBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('📖 Giải chi tiết + Nguồn',
                        style: TextStyle(fontSize: 12)),
                    selected: _detailedMode,
                    selectedColor: widget.subject.color.withOpacity(0.16),
                    onSelected: (_) => _toggleSolveMode(true),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('💡 Gợi mở Socratic',
                        style: TextStyle(fontSize: 12)),
                    selected: !_detailedMode,
                    selectedColor: widget.subject.color.withOpacity(0.16),
                    onSelected: (_) => _toggleSolveMode(false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          if (widget.history.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Colors.grey.shade600),
              tooltip: 'Xóa lịch sử môn ${widget.subject.name}',
              onPressed: () => widget.onHistoryUpdate([]),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  // Màn hình trống khi chưa có tin nhắn
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.subject.emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'Chào mừng đến với\nGia Sư Tư Duy!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: widget.subject.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hãy đặt câu hỏi về môn ${widget.subject.name}\nhoặc gửi ảnh bài tập để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.subject.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: widget.subject.color.withOpacity(0.2)),
              ),
              child: Text(
                _detailedMode
                    ? '📖 Chụp ảnh hoặc nhập bài tập → AI tự tra cứu lời giải trên VietJack, Lời Giải Hay và trình bày đầy đủ từng bước. Nguồn được ghi rõ cuối mỗi câu trả lời.'
                    : '💡 Chế độ Socratic: Gia sư dẫn dắt từng bước giúp bạn tự tư duy ra đáp án.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.subject.color,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '👨‍🎓 $authorName • $authorClassSchool • v$appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bubble tin nhắn
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar AI
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.subject.color.withOpacity(0.15),
              child: Text(
                widget.subject.emoji,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Nội dung bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? widget.subject.color
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hiển thị ảnh đính kèm nếu có
                  if (msg.imageBase64 != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: Image.memory(
                        base64Decode(msg.imageBase64!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
                      ),
                    ),

                  // Text tin nhắn với hỗ trợ markdown đơn giản
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      msg.imageBase64 != null ? 8 : 10,
                      12,
                      msg.sources.isNotEmpty && !isUser ? 6 : 10,
                    ),
                    child: _buildMessageText(msg.text, isUser),
                  ),

                  // Hiển thị danh sách nguồn tham khảo thực tế (Lời Giải Hay, VietJack...)
                  if (!isUser && msg.sources.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.subject.color.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📚 Nguồn tham khảo đã đối chiếu:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: widget.subject.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...msg.sources.take(5).map(
                                (src) => InkWell(
                                  onTap: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: src.uri));
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Đã sao chép link nguồn: ${src.title}'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.link,
                                            size: 13,
                                            color: widget.subject.color),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            src.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.blue.shade800,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Avatar người dùng
          if (isUser) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.subject.color,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // Render text hỗ trợ **bold** và newlines
  Widget _buildMessageText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : const Color(0xFF212121);

    if (!text.contains('**') && !text.contains('\n')) {
      return Text(
        text,
        style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.45),
      );
    }

    // Parse **bold** đơn giản
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        final before = text.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: before,
          style: TextStyle(
              color: baseColor, fontSize: 14.5, height: 1.45),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: baseColor,
          fontSize: 14.5,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
            color: baseColor, fontSize: 14.5, height: 1.45),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  // Bubble loading (đang chờ AI phản hồi)
  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: widget.subject.color.withOpacity(0.15),
            child: Text(widget.subject.emoji,
                style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LoadingDot(color: widget.subject.color, delay: 0),
                const SizedBox(width: 4),
                _LoadingDot(color: widget.subject.color, delay: 150),
                const SizedBox(width: 4),
                _LoadingDot(color: widget.subject.color, delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khu vực nhập liệu phía dưới
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview ảnh đã chọn
            if (_selectedImage != null) _buildImagePreview(),

            // Row nhập liệu
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Nút chọn ảnh
                  IconButton(
                    icon: Icon(
                      Icons.add_a_photo_outlined,
                      color: widget.subject.color,
                    ),
                    tooltip: 'Chụp/chọn ảnh bài tập',
                    onPressed: _showImageSourceMenu,
                  ),

                  // Ô nhập văn bản
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.subject.color.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        maxLines: 4,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText:
                              'Nhập câu hỏi về môn ${widget.subject.name}...',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Nút gửi
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: widget.subject.color,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isLoading ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Preview ảnh đã chọn với nút xóa
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _selectedImage!,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
          ),
          // Nút X xóa ảnh
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: _clearImage,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
          // Label nhỏ
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: const Text(
                'Ảnh đính kèm',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dot animation loading (3 chấm nhấp nhô)
// ============================================================
class _LoadingDot extends StatefulWidget {
  final Color color;
  final int delay;

  const _LoadingDot({required this.color, required this.delay});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Delay trước khi bắt đầu animation
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Sheet cài đặt API Key & Model AI
// ============================================================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _proxyController = TextEditingController();
  String _selectedModel = defaultGeminiModel;
  bool _obscureText = true;
  bool _isSaving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Tải API key, proxy URL và model đã lưu
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    final proxy = prefs.getString('worker_proxy_url') ?? defaultWorkerProxyUrl;
    final savedModel = prefs.getString('gemini_model') ?? defaultGeminiModel;
    final validModel = geminiModelOptions.any((m) => m.id == savedModel)
        ? savedModel
        : defaultGeminiModel;

    setState(() {
      _keyController.text = key;
      _proxyController.text = proxy;
      _selectedModel = validModel;
    });
  }

  // Lưu API key, proxy URL và model
  Future<void> _saveSettings() async {
    final key = _keyController.text.trim();
    final proxy = _proxyController.text.trim();
    if (key.isEmpty && proxy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập API Key hoặc Worker Proxy URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    await prefs.setString('worker_proxy_url', proxy);
    await prefs.setString('gemini_model', _selectedModel);

    setState(() {
      _isSaving = false;
      _saved = true;
    });

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Tránh bàn phím che mất nội dung
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Row(
                children: [
                  const Icon(Icons.settings, color: SubjectColors.toan),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cài đặt AI & API Key',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SubjectColors.toan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'v$appVersion',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SubjectColors.toan,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Thẻ thông tin tác giả
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SubjectColors.toan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: SubjectColors.toan.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '👨‍🎓 Phát triển bởi: $authorName',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: SubjectColors.toan,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$authorClassSchool • Phiên bản v$appVersion',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Hướng dẫn
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📌 Hướng dẫn lấy API Key miễn phí:',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Truy cập aistudio.google.com\n'
                      '2. Đăng nhập tài khoản Google\n'
                      '3. Chọn "Get API Key" → "Create API Key"\n'
                      '4. Sao chép và dán vào ô bên dưới\n\n'
                      '⚡ Mặc định dùng Gemini Flash-Lite (nhanh, miễn phí, tự dự phòng khi bận).',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Chọn Model Gemini Flash / Flash-Lite
              DropdownButtonFormField<String>(
                value: _selectedModel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Mô hình AI (Flash / Flash-Lite)',
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
                items: geminiModelOptions
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(
                          m.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedModel = value);
                  }
                },
              ),
              const SizedBox(height: 6),
              Text(
                geminiModelOptions
                    .firstWhere(
                      (m) => m.id == _selectedModel,
                      orElse: () => geminiModelOptions.first,
                    )
                    .subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 14),

              // Ô nhập API Key
              TextField(
                controller: _keyController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),

              const SizedBox(height: 14),

              // Ô nhập Worker Proxy URL (tùy chọn)
              TextField(
                controller: _proxyController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Cloudflare Worker URL (Tùy chọn)',
                  hintText: 'https://gia-su-proxy.xxxx.workers.dev',
                  helperText: 'Nếu có Worker URL thì không cần nhập API Key',
                  prefixIcon: const Icon(Icons.cloud_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),

              const SizedBox(height: 16),

              // Nút lưu
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _saved ? Colors.green : SubjectColors.toan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_saved ? Icons.check : Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Đang lưu...'
                        : _saved
                            ? 'Đã lưu thành công!'
                            : 'Lưu cài đặt',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
