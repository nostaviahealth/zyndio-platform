import 'package:shared_preferences/shared_preferences.dart';
void main() async {
  final prefs = await SharedPreferences.getInstance();
  print("Linked: ${prefs.getBool('health_connected')}");
}
