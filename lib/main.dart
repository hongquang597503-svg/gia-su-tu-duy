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

// ─── System Instruction (Socratic — Bộ não Gia Sư Tư Duy) ───
const String systemInstruction = '''
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

// ─── Model tin nhắn ─────────────────────────────────────────
class ChatMessage {
  final String role; // 'user' hoặc 'model'
  final String text;
  final String? imageBase64; // base64 ảnh đính kèm (chỉ user)
  final String? imageMimeType;

  const ChatMessage({
    required this.role,
    required this.text,
    this.imageBase64,
    this.imageMimeType,
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
  File? _selectedImage;      // ảnh đã chọn
  String? _imageBase64;      // base64 của ảnh
  String? _imageMimeType;    // mime type ảnh

  final ImagePicker _picker = ImagePicker();

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

    // Lấy API key từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';

    if (apiKey.isEmpty) {
      _showError('Vui lòng nhập Gemini API Key trong cài đặt ⚙️');
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
      final aiResponse = await _callGeminiAPI(apiKey, updatedHistory);

      final aiMsg = ChatMessage(role: 'model', text: aiResponse);
      widget.onHistoryUpdate([...updatedHistory, aiMsg]);
    } catch (e) {
      _showError('Lỗi kết nối: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // Gọi Gemini API
  Future<String> _callGeminiAPI(
      String apiKey, List<ChatMessage> history) async {
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

    // Chuyển lịch sử chat thành định dạng API
    final contents = history.map((m) => m.toApiContent()).toList();

    // Body request
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    });

    final response = await http
        .post(
          Uri.parse('$endpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final errMsg = err['error']?['message'] ?? 'Lỗi không xác định';
      throw Exception('API Error ${response.statusCode}: $errMsg');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
        as String?;
    return text ?? '(Không có phản hồi)';
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

  // Màn hình trống khi chưa có tin nhắn
  Widget _buildEmptyState() {
    return Center(
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
              '💡 Gia sư sẽ dẫn dắt bạn tự tìm ra đáp án\nthay vì cho đáp án trực tiếp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: widget.subject.color,
                height: 1.5,
              ),
            ),
          ),
        ],
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
                      10,
                    ),
                    child: _buildMessageText(msg.text, isUser),
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
// Sheet cài đặt API Key
// ============================================================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  // Tải API key đã lưu
  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    setState(() {
      _keyController.text = key;
    });
  }

  // Lưu API key
  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập API Key'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Tránh bàn phím che mất nội dung
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                const Text(
                  'Cài đặt Gemini API Key',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

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
                    '📌 Hướng dẫn lấy API Key:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Truy cập aistudio.google.com\n'
                    '2. Đăng nhập tài khoản Google\n'
                    '3. Chọn "Get API Key" → "Create API Key"\n'
                    '4. Sao chép và dán vào ô bên dưới\n\n'
                    '🔒 API Key được lưu riêng tư trên thiết bị của bạn.',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            // Nút lưu
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveKey,
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
                          : 'Lưu API Key',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
