// file: lib/services/data_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataService {
  static const String _baseUrl = 'http://202.157.187.108:3000';

  Future<dynamic> fetchData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/data'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }
}
