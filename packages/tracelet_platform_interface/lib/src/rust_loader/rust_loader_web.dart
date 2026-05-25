import '../rust/frb_generated.dart';

Future<void> initializeRustLib() async {
  await RustLib.init();
}
