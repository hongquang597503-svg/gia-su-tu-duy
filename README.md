# Gia Sư Tư Duy 🎓

> Ứng dụng gia sư AI theo phương pháp Socratic dành cho học sinh phổ thông Việt Nam

[![Build & Release APK](https://github.com/hongquang597503-svg/gia-su-tu-duy/actions/workflows/build.yml/badge.svg)](https://github.com/hongquang597503-svg/gia-su-tu-duy/actions/workflows/build.yml)

## 📱 Tải APK mới nhất

👉 **[Tải APK tại đây (Releases)](https://github.com/hongquang597503-svg/gia-su-tu-duy/releases/latest)**

## Tính năng

| Môn học | Biểu tượng |
|---------|-----------|
| Toán    | 📐        |
| Vật Lý  | ⚡        |
| Hóa Học | 🧪        |
| Tiếng Anh | 🌍      |

- 🤖 **AI Gia sư Socratic**: Không cho đáp án thẳng — dẫn dắt học sinh tự tư duy
- 📸 **Chụp ảnh đề bài**: Gửi ảnh bài tập vào chat để AI phân tích
- 💬 **Chat nhiều lượt**: Nhớ toàn bộ lịch sử hội thoại trong buổi học
- 🔑 **API Key của bạn**: Dùng Gemini API Key riêng (miễn phí tại aistudio.google.com)

## Cài đặt

1. Tải APK từ [Releases](https://github.com/hongquang597503-svg/gia-su-tu-duy/releases/latest)
2. Cài đặt trên Android (minSdk 21 / Android 5.0+)
3. Mở app → nhấn ⚙️ → dán Gemini API Key
4. Chọn môn học và bắt đầu! 🚀

## Lấy Gemini API Key miễn phí

1. Vào [aistudio.google.com](https://aistudio.google.com)
2. Đăng nhập tài khoản Google
3. Chọn **Get API Key** → **Create API Key**
4. Dán vào ô cài đặt trong app

## Build từ source

```bash
git clone https://github.com/hongquang597503-svg/gia-su-tu-duy.git
cd gia-su-tu-duy
flutter pub get
flutter build apk --release
```

## Tech Stack

- **Flutter** 3.24.5 (Dart)
- **Google Gemini API** (`gemini-2.5-flash`)
- **Packages**: `http`, `image_picker`, `shared_preferences`

## License

MIT License
