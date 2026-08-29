import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_server.dart';
import '../helpers/test_core.dart';
import 'package:desktop/data/api/api_service.dart';
import 'package:desktop/data/repositories/auth_service.dart';

void main() {
  late TestCore core;
  late MockServerAdapter server;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // No seeded user: AuthService assumes a single local account and
    // getCurrentUser() returns the first row.
    core = await TestCore.create(seedUser: false);
    server = MockServerAdapter({});
    final dio = Dio()..httpClientAdapter = server;
    authService = AuthService(core.db, ApiService(dio: dio));
  });

  tearDown(() async {
    await core.dispose();
  });

  test('login stores token, session and local user', () async {
    server.routes['auth/login'] = (req) async =>
        MockServerAdapter.jsonResponse(200, {
          'token': 'tok_123',
          'user': {
            'id': 'user_abc',
            'email': 'peter@example.com',
            'name': 'Peter',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        });

    final response = await authService.login('peter@example.com', 'secret');

    expect(response.token, 'tok_123');
    expect(response.user.id, 'user_abc');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'tok_123');
    expect(prefs.getString('user_session_token'), 'tok_123');

    final localUser = await authService.getCurrentUser();
    expect(localUser, isNotNull);
    expect(localUser!.id, 'user_abc');
    expect(localUser.email, 'peter@example.com');
    expect(localUser.name, 'Peter');
  });

  test('login falls back to email prefix when name is empty', () async {
    server.routes['auth/login'] = (req) async =>
        MockServerAdapter.jsonResponse(200, {
          'token': 'tok_123',
          'user': {
            'id': 'user_abc',
            'email': 'jane@example.com',
            'name': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        });

    await authService.login('jane@example.com', 'secret');

    final localUser = await authService.getCurrentUser();
    expect(localUser!.name, 'jane');
  });

  test('registerUser posts signup payload and stores the user', () async {
    server.routes['auth/signup'] = (req) async {
      expect((req.body as Map)['name'], 'Peter');
      expect((req.body as Map)['email'], 'peter@example.com');
      return MockServerAdapter.jsonResponse(201, {
        'token': 'tok_new',
        'user': {
          'id': 'user_new',
          'email': 'peter@example.com',
          'name': 'Peter',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      });
    };

    final response =
        await authService.registerUser('Peter', 'peter@example.com', 'secret');

    expect(response.user.id, 'user_new');
    final localUser = await authService.getCurrentUser();
    expect(localUser!.id, 'user_new');
  });

  test('failed login throws and does not store a session', () async {
    server.routes['auth/login'] =
        (req) async => MockServerAdapter.jsonResponse(401, {
              'error': 'Invalid credentials',
            });

    await expectLater(
      authService.login('peter@example.com', 'wrong'),
      throwsException,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_session_token'), isNull);
  });

  test('logout clears tokens and session', () async {
    server.routes['auth/login'] = (req) async =>
        MockServerAdapter.jsonResponse(200, {
          'token': 'tok_123',
          'user': {
            'id': 'user_abc',
            'email': 'peter@example.com',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        });

    await authService.login('peter@example.com', 'secret');
    await authService.logout();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('user_session_token'), isNull);
  });

  test('authenticated requests carry the Bearer token header', () async {
    server.routes['auth/login'] = (req) async =>
        MockServerAdapter.jsonResponse(200, {
          'token': 'tok_123',
          'user': {
            'id': 'user_abc',
            'email': 'peter@example.com',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        });

    await authService.login('peter@example.com', 'secret');

    // Login request itself must not carry a token.
    expect(server.requests.first.header('authorization'), isNull);

    server.routes['anything'] =
        (req) async => MockServerAdapter.jsonResponse(200, {'ok': true});
    await authService.api.get('anything');
    expect(server.requests.last.header('authorization'), 'Bearer tok_123');
  });
}
