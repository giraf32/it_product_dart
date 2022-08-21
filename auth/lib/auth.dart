
import 'package:auth/controllers/app_auth_controller.dart';
import 'package:auth/controllers/app_token_controller.dart';
import 'package:auth/controllers/app_user_controller.dart';
import 'package:auth/utils/app_env.dart';
import 'package:conduit/conduit.dart';

class AppService extends ApplicationChannel {
  late final ManagedContext managedContext;
  // метод для настройки служб, которые [Контролеры] используют для выполнения своих обязанностях
  @override
  Future prepare() {
    // служат связующим звеном между [Запросом] и конкретной базой данных.
    PersistentStore? persistentStore = _initDatabase();
    ManagedDataModel? dataModel = ManagedDataModel.fromCurrentMirrorSystem();
    // [Запрос] отправляется в базу данных, описанную [постоянное хранилище'persistenStore'].
    //[Запрос] может быть выполнен только в этом контексте, если его тип находится в [модели данных'dataModel'].
    managedContext = ManagedContext(dataModel, persistentStore);
    return super.prepare();
  }

  @override
  Controller get entryPoint => Router()
    ..route('token/[:refresh]').link(() => AppAuthController(managedContext))
    ..route('user')
        .link(() => AppTokenController())!
        .link(() => AppUserController(managedContext));

  // Для взаимодействия с базой данных PostgreSQL
  PostgreSQLPersistentStore _initDatabase() {
    return PostgreSQLPersistentStore( AppEnv.dbUsername,AppEnv.dbPassword,AppEnv.dbHost,
         int.tryParse(AppEnv.dbPort),AppEnv.dbDatabaseName);
  }
}
