class ApiConfig {
  // Production URL on Render (Requires active PostgreSQL database in Render env)
  static const String baseUrl = 'https://medical-0n1w.onrender.com/api';

  // Local testing options:
  // static const String baseUrl = 'http://localhost:10000/api'; // iOS Simulator / macOS / Web
  // static const String baseUrl = 'http://10.0.2.2:10000/api'; // Android Emulator
  // static const String baseUrl = 'http://192.168.1.XXX:10000/api'; // Physical device on local Wi-Fi

  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const int maxFileSizeMB = 10;
}
