import 'dart:io';

import 'package:auth/models/user.dart';
import 'package:auth/utils/app_const.dart';
import 'package:auth/utils/app_response.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit/conduit.dart';

class AppUserController extends ResourceController {
  final ManagedContext managedContext;

  AppUserController(this.managedContext);

  @Operation.get()
  Future<Response> getProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);
      user?.removePropertiesFromBackingMap(
          [AppConst.accessToken, AppConst.refreshToken]);
      return AppResponse.ok(
          message: 'Успешное получения профиля', body: user?.backing.contents);
    } catch (error) {
      return AppResponse.serverError(error,
          message: 'Ошибка получения профиля');
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() User user,
  ) async {
    try {
      // получаем user по id
      // делаем запрос Query на обновления данных
      final id = AppUtils.getIdFromHeader(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.username = user.username ?? fUser?.username
        ..values.email = user.email ?? fUser?.email;
      //обновляем базу данных
      await qUpdateUser.updateOne();
      // получаем обновленного user по id
      final uUser = await managedContext.fetchObjectWithID<User>(id);
      // удаляем не нужное с данных user
      uUser?.removePropertiesFromBackingMap(
          [AppConst.accessToken, AppConst.refreshToken]);

      return AppResponse.ok(
          message: 'Успешное обновления данных', body: uUser?.backing.contents);
    } catch (error) {
      return AppResponse.serverError(error,
          message: 'Ошибка обновления данных');
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('oldPassword') String oldPassword,
      @Bind.query('newPassword') String newPassword) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindUser = Query<User>(managedContext)
        ..where((table) => table.id).equalTo(id)
        ..returningProperties((table) => [table.salt, table.hashPassword]);
      final findUser = await qFindUser.fetchOne();
      final salt = findUser?.salt ?? '';
      final oldPasswordHash =
          AuthUtility.generatePasswordHash(oldPassword, salt);
      if (oldPasswordHash != findUser?.hashPassword) {
        return AppResponse.badRequest(message: "Пароль не верный");
      }
      final newPasswordHash =
          AuthUtility.generatePasswordHash(newPassword, salt);
      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.hashPassword = newPasswordHash;
      await qUpdateUser.updateOne();
      return AppResponse.ok(message: 'Успешное обновление пароля');
    } catch (error) {
      return AppResponse.serverError(error,message: 'Ошибка обновления пароля');
    }
  }
}
