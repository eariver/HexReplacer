import 'package:HexReplacer/hexloader.dart';

Future<void> main(List<String> args) async {
  // HEX読み込み/生成のデバッグ
  HexLoader hex = (await HexLoader.load("example.hex"))!;
  print(hex);
  hex.toIHEXFile("output/hoge.hex", 16, true);
  hex.toIHEXFile("output/hoge_16.hex", 16, true);
  hex.toIHEXFile("output/hoge_32.hex", 32, true);
}
