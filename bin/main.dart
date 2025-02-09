import 'package:HexReplacer/configloader.dart';
import 'package:HexReplacer/hexloader.dart';
import 'package:HexReplacer/replacefileloader.dart';

Future<void> main(List<String> args) async {
  // コマンドライン引数パース
  if (args.length == 0 || args[0] == "-h") {
    print("=============================================");
    print(" HexReplacer v1.0.0");
    print(" author: Eariver (2025/01/26)");
    print(" url: https://github.com/eariver/HexReplacer");
    print("=============================================");
    print("Intel HEX形式のバイナリファイルから指定されたアドレスから指定バイト分のデータを上書きします。");
    print("引数例: `> hexreplacer.exe 置き換え情報.csv 置き換え元.hex 置き換え先.hex`");
    print("置き換え情報のテンプレートは `> hexreplacer.exe -t` で生成できます。");
    print("HEXファイルをCSVファイルに変換する場合は `> hexreplacer.exe -c 変換元.hex` を実行してください。");
    return;
  }
  else if (args[0] == "-t") {
    ReplaceFileLoader.createTemplate();
    print("./template.csv にテンプレートを作成しました。");
    return;
  }
  else if (args[0] == "-c") {
    if (args.length != 2) {
      print("Error: コマンドライン引数を正しく入力してください。");
      print("-cオプションは第2引数にHEXファイル名が必要です。");
      print("引数例: `> HexReplacer.exe -c 変換元.hex`");
    }
    HexLoader? hex = await HexLoader.load(args[1]);
    if (hex == null) {
      print("HEXファイルの読み込みに失敗しました。処理を中止します。");
      return;
    }
    print("CSVファイルを書き出しました！");
    hex.toCSVFile(args[1]+".csv");
    return;
  }
  else if (args.length != 3) {
    print("Error: コマンドライン引数を正しく入力してください。");
    print("引数例: `> HexReplacer.exe 置き換え情報.csv 置き換え元.hex 置き換え先.hex`");
    return;
  }
  String repl = args[0];
  String oHex = args[1];
  String dHex = args[2];

  // Configファイルの読み込み
  Config? conf = await Config.load();
  if (conf == null) {
    print("Configの読み込みに失敗しました。処理を中止します。");
    return;
  }
  print("Configファイルを読み込みました。");

  // Replaceファイルの読み込み
  ReplaceFileLoader? rfl = await ReplaceFileLoader.load(repl);
  if (rfl == null) {
    print("置き換えデータの読み込みに失敗しました。処理を中止します。");
    return;
  }
  print("置き換えデータを読み込みました。");

  // HEXファイルの読み込み
  HexLoader? hex = await HexLoader.load(oHex);
  if (hex == null) {
    print("HEXファイルの読み込みに失敗しました。処理を中止します。");
    return;
  }
  print("HEXファイルを読み込みました。\n");

  // Replace情報のHEX適用
  int cnt = 0;
  rfl.data.forEach((d) {
    cnt++;
    print("${d.name} (${cnt}/${rfl.data.length} 件目) を置き換えています。");
    hex.replaceData(d.strtAddr, d.len, d.data);
  });

  // 置換後のHEXファイルを出力
  print("\nHEXファイルを書き出します。");
  if (conf.isUseCustomDataRecordSize) {
    await hex.toIHEXFile(dHex, conf.dataRecordSize, true);
  }
  else {
    await hex.toIHEXFile(dHex, null, true);
  }
  print("HEXファイルを書き出しました！");
}
