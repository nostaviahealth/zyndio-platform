
void main() async {
  try {
    final history = [{"role": "user", "text": "hello"}].map((m) => {
      "role": m["role"]!,
      "text": m["text"]!
    }).toList().cast<Map<String, String>>();
    print("Cast successful: $history");
  } catch (e) {
    print("Exception: $e");
  }
}
