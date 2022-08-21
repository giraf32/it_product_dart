import 'package:auth/models/response_model.dart';
import 'package:auth/models/user.dart';
import 'package:auth/utils/app_env.dart';
import 'package:auth/utils/app_response.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit/conduit.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<Response> singIn(@Bind.body() User user) async {
    if (user.password == null || user.username == null) {
      return AppResponse.badRequest(
          message: 'Поля password и username не найдены');
    }
    try {
      // делаем запрос в бд и ищем таблицу usera сравнивая по полю user.usermame
      // возвращаем данные нашего usera
      final qFindUser = Query<User>(managedContext)
        ..where((table) => table.username).equalTo(user.username)
        ..returningProperties(
            (table) => [table.id, table.salt, table.hashPassword]);
      // получаем usera из одной таблицы
      final findUser = await qFindUser.fetchOne();
      if (findUser == null) {
        throw QueryException.input('Пользователь не найден', []);
      }
      // генерируем хеш пароля и сравниваем с текущем
      final requestrHasPassword = AuthUtility.generatePasswordHash(
          user.password ?? '', findUser.salt ?? '');
      if (requestrHasPassword == findUser.hashPassword) {
        await _updateTokens(findUser.id ?? -1, managedContext);
        final newUser =
            await managedContext.fetchObjectWithID<User>(findUser.id);
        return AppResponse.ok(
            body: newUser?.backing.contents, message: 'Успешная авторизация');
      } else {
        throw QueryException.input('Пороль не верный', []);
      }
    } catch (error) {
      return AppResponse.serverError(error, message: 'Ошибка авторизации');
    }
  }

  @Operation.put()
  Future<Response> singUp(@Bind.body() User user) async {
    if (user.password == null || user.username == null || user.email == null) {
      return AppResponse.badRequest(
          message: 'Поля password username email обязательны');
    }

    final salt = AuthUtility.generateRandomSalt();
    final hashPassword =
        AuthUtility.generatePasswordHash(user.password ?? '', salt);

    try {
      late final int id;
      await managedContext.transaction((transaction) async {
        final qCreateUser = Query<User>(transaction)
          ..values.username = user.username
          ..values.email = user.email
          ..values.salt = salt
          ..values.hashPassword = hashPassword;
        final createUser = await qCreateUser.insert();
        id = createUser.asMap()['id'];
        await _updateTokens(id, transaction);
      });
      final userData = await managedContext.fetchObjectWithID<User>(id);
      return AppResponse.ok(
          body: userData?.backing.contents, message: 'Успешная регистрация');
    } catch (error) {
      return AppResponse.serverError(error, message: 'Ошибка регистрации');
    }
  }

  @Operation.post('refresh')
  Future<Response> refreshToken(
      @Bind.path('refresh') String refreshToken) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);
      final user = await managedContext.fetchObjectWithID<User>(id);

      if (user?.refreshToken != refreshToken) {
        return Response.unauthorized(
            body: ResponseModel(message: 'Token is not valid'));
      } else {
        await _updateTokens(id, managedContext);
        final user = await managedContext.fetchObjectWithID<User>(id);
        return AppResponse.ok(
            body: user?.backing.contents,
            message: 'Успешное обновления токенов');
      }
    } catch (error) {
      return AppResponse.serverError(error,
          message: 'Ошибка обновления токенов');
    }
  }

  Map<String, dynamic> _getTokens(int id) {
    
    final key = AppEnv.secretKey;
    final accessClaimSet =
        JwtClaim(maxAge: Duration(hours: 1), otherClaims: {'id': id});
    final refresgClaimSet = JwtClaim(otherClaims: {'id': id});

    final tokens = <String, dynamic>{};
    tokens['access'] = issueJwtHS256(accessClaimSet, key);
    tokens['refresh'] = issueJwtHS256(refresgClaimSet, key);
    return tokens;
  }

  Future<void> _updateTokens(int id, ManagedContext transaction) async {
    final Map<String, dynamic> tokens = _getTokens(id);
    final qUpdateTokens = Query<User>(transaction)
      ..where((user) => user.id).equalTo(id)
      ..values.accessToken = tokens['access']
      ..values.refreshToken = tokens['refresh'];
    await qUpdateTokens.updateOne();
  }
}
