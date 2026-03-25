import 'dart:convert';
import 'package:http/http.dart' as http;

class LicenseService {

  static const String baseUrl = "https://YOUR-RENDER-URL.onrender.com";

  static Future<String> activate(String key, String deviceId) async {

    try {

      final res = await http.post(
        Uri.parse("$baseUrl/activate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "key": key,
          "device_id": deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return "server_error";
      }

      final data = jsonDecode(res.body);
      return data["status"];

    } catch (e) {
      return "no_connection";
    }
  }
}