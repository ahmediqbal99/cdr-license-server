import 'dart:convert';
import 'package:http/http.dart' as http;

class NameLookupService {

  static const String baseUrl = "http://192.168.68.59:3000";

  static Map<String,String> cache = {};

  static Future<Map<String,String>> lookupBatch(List<String> numbers) async {

    List<String> toLookup = [];

    for (var n in numbers) {
      if (!cache.containsKey(n)) {
        toLookup.add(n);
      }
    }

    if (toLookup.isEmpty) return cache;

    final response = await http.post(
      Uri.parse("$baseUrl/lookup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"numbers": toLookup}),
    );

    print("Sending numbers: $toLookup");
    print("Response: ${response.body}");

    if (response.statusCode == 200) {

      Map<String, dynamic> result = jsonDecode(response.body);

      if (result.containsKey("data")) {
        for (var item in result["data"]) {
          String number = item["number"].toString();
          String name = item["name"]?.toString() ?? "Unknown";

          cache[number] = name;
        }
      }
    }

    return cache;
  }
}