import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Built-in backend — accounts and data API, provided by Danger World Builder.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// Built-in device features — installed apps, home screen, on-device storage.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Built-in backend — accounts and data API, provided by Danger World Builder.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------
class DwBackend {
  static const String baseUrl =
      "https://danger-build-core.base44.app/functions/appBackend";
  static const String appKey = "a86d8ebd054f42aa80dea1b29735dd15";
  static String? token;
  static String? userEmail;
  static String? userId;
  static String? userName;

  static Future<Map<String, dynamic>> _post(
      String action, Map<String, dynamic> extra) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(baseUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      final payload = <String, dynamic>{"app_key": appKey, "action": action};
      payload.addAll(extra);
      if (token != null) payload["token"] = token;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"ok": false, "error": "Unexpected response from the server."};
    } catch (_) {
      return {"ok": false, "error": "Could not reach the server. Check your connection."};
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> res, String key) {
    final items = res[key];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _session(Map<String, dynamic> res, String email) {
    if (res["ok"] == true && res["token"] is String) {
      token = res["token"] as String;
      userEmail = email;
      final user = res["user"];
      if (user is Map) {
        userId = user["id"]?.toString();
        userName = user["name"]?.toString();
      }
    }
    return res;
  }

  static Future<Map<String, dynamic>> signUp(String email, String password,
      {String? name}) async {
    final extra = <String, dynamic>{"email": email, "password": password};
    if (name != null) extra["name"] = name;
    return _session(await _post("signup", extra), email);
  }

  static Future<Map<String, dynamic>> signIn(String email, String password) async {
    return _session(
        await _post("login", {"email": email, "password": password}), email);
  }

  static Future<void> signOut() async {
    token = null;
    userEmail = null;
    userId = null;
    userName = null;
  }

  // The signed-in user's profile: {"id", "email", "name", "avatar_url", "bio"}.
  static Future<Map<String, dynamic>> me() async {
    final res = await _post("me", {});
    final user = res["user"];
    return user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateProfile(
      {String? name, String? avatarUrl, String? bio}) async {
    final extra = <String, dynamic>{};
    if (name != null) extra["name"] = name;
    if (avatarUrl != null) extra["avatar_url"] = avatarUrl;
    if (bio != null) extra["bio"] = bio;
    final res = await _post("update_profile", extra);
    if (res["ok"] == true && name != null) userName = name;
    return res;
  }

  // Everyone who signed up to this app (contacts, friends, people to message).
  static Future<List<Map<String, dynamic>>> users({String search = ""}) async {
    return _items(await _post("users", {"search": search}), "users");
  }

  // The signed-in user's own records in a collection.
  static Future<List<Map<String, dynamic>>> list(String collection,
      {Map<String, dynamic>? where, int limit = 100, bool newestFirst = false}) async {
    return _items(
        await _post("list", {
          "collection": collection,
          "where": where ?? <String, dynamic>{},
          "limit": limit,
          "newest_first": newestFirst,
        }),
        "items");
  }

  // Shared records from ALL users of the app, filtered by exact field values.
  // Pass since (an item's "created_at") to fetch only newer records when polling.
  static Future<List<Map<String, dynamic>>> query(String collection,
      {Map<String, dynamic>? where,
      String? since,
      int limit = 100,
      bool newestFirst = false}) async {
    final extra = <String, dynamic>{
      "collection": collection,
      "where": where ?? <String, dynamic>{},
      "limit": limit,
      "newest_first": newestFirst,
    };
    if (since != null) extra["since"] = since;
    return _items(await _post("query", extra), "items");
  }

  // shared: true makes the record visible to every user through query().
  static Future<Map<String, dynamic>> create(
      String collection, Map<String, dynamic> data,
      {bool shared = false}) {
    return _post("create",
        {"collection": collection, "data": data, "shared": shared});
  }

  // Merges the given fields into a record the signed-in user created.
  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) {
    return _post("update", {"id": id, "data": data});
  }

  static Future<Map<String, dynamic>> remove(String id) {
    return _post("remove", {"id": id});
  }

  // The same id for a one-to-one conversation whichever of the two users opens it.
  static String chatIdWith(String otherUserId) {
    final ids = [userId ?? "", otherUserId]..sort();
    return ids.join("_");
  }
}


// ---------------------------------------------------------------------------
// Built-in device features — installed apps, home screen, on-device storage.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------
class DwNative {
  static const MethodChannel _channel = MethodChannel("dw/native");

  // Every launchable app: {"name": String, "package": String, "icon": Uint8List? (PNG)}.
  static Future<List<Map<String, dynamic>>> installedApps({bool icons = true}) async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>("installedApps", {"icons": icons});
      return (result ?? const [])
          .whereType<Map>()
          .map((app) => Map<String, dynamic>.from(app))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> _call(String method, [String packageName = ""]) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, {"package": packageName});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchApp(String packageName) => _call("launchApp", packageName);
  static Future<bool> openAppInfo(String packageName) => _call("openAppInfo", packageName);
  static Future<bool> uninstallApp(String packageName) => _call("uninstallApp", packageName);
  static Future<bool> openHomeSettings() => _call("openHomeSettings");
  static Future<bool> isDefaultLauncher() => _call("isDefaultLauncher");

  static Future<String?> getLocal(String key) async {
    try {
      return await _channel.invokeMethod<String>("getLocal", {"key": key});
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setLocal(String key, String? value) async {
    try {
      final ok = await _channel.invokeMethod<bool>("setLocal", {"key": key, "value": value});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> loadJson(String key) async {
    final raw = await getLocal(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveJson(String key, dynamic value) => setLocal(key, jsonEncode(value));
}
