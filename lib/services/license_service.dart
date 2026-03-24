import 'dart:convert';
import 'package:http/http.dart' as http;

class LicenseService {

  static const baseUrl = "http://192.168.68.63:4000";

  static Future<String> activate(String key, String deviceId) async {

    final res = await http.post(
      Uri.parse("$baseUrl/activate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "key": key,
        "device_id": deviceId
      }),
    );

    final data = jsonDecode(res.body);
    return data["status"];
  }
}