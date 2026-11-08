import 'dart:convert';

class CommandParser {
  String parseReply(String responseBody) {
    final decodedResponse = jsonDecode(responseBody);
    if (decodedResponse is! Map<String, dynamic>) {
      throw const FormatException(
        'SMS Edge Function returned a non-object JSON response.',
      );
    }

    final reply = decodedResponse['reply'];
    if (reply is! String) {
      throw const FormatException(
        'SMS Edge Function response must contain a string reply.',
      );
    }
    return reply.trim();
  }
}
