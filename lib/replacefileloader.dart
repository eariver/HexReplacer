library replacefileloader;
import 'dart:io';
import 'package:HexReplacer/hexloader.dart';
import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';

class ReplaceFileLoader {
  late List<ReplaceData> data;

  ReplaceFileLoader(List<ReplaceData> data) {
    this.data = data;
  }

  @override
  String toString() {
    return this.data.toString();
  }

  // CSVファイルから置き換え用データを読みだしてインスタンスを生成する
  static Future<ReplaceFileLoader?> load(String fileName, [bool? doLoadNoDataRow]) async {
    try {
      final file = File(fileName);
      if (!(await file.exists())) {
        print("CSVファイルが存在しません。");
        return null;
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        print("CSVファイルが空です。");
      }

      var det = FirstOccurrenceSettingsDetector(
          fieldDelimiters: [","], textDelimiters: ["'", '"'], eols: ["\r\n", "\n"]);
      var csvData = CsvToListConverter().convert(file.readAsStringSync(), csvSettingsDetector: det);

      int rCnt = 0;
      List<ReplaceData> datTemp = [];

      csvData.forEach((row) {
        rCnt++;
        if (rCnt == 1) {
          print("置き換えデータ $rCnt 行目はヘッダとしてスキップします。");
        }
        else if (row.length != 4) {
          print("$rCnt 行目の列数が不正です。スキップします。");
        }
        else {
          String? name = row[0];
          if (name != null && name.length == 0) {
            name = null;
          }
          int? strtAddr = int.tryParse(row[1].toString(), radix: 16);
          int? len = int.tryParse(row[2].toString(), radix: 10);
          if (strtAddr == null || len == null) {
            print("$rCnt 行目の開始アドレスもしくはデータ長が不正です。スキップします。");
            print(row);
          }
          else {
            List<int>? dat = HexLoader.parseData(row[3].toString(), len);
            if (dat == null && !(doLoadNoDataRow ?? false)) {
              print("$rCnt 行目のデータが不正です。スキップします。");
            }
            else if (doLoadNoDataRow!) {
              datTemp.add(ReplaceData(strtAddr, len, List<int>.empty(), name));
            }
            else datTemp.add(ReplaceData(strtAddr, len, dat!, name));
          }
        }
      });
      return ReplaceFileLoader(datTemp);
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      return null;
    }
  }

  // 置き換えデータのテンプレートを作成する
  static Future<void> createTemplate() async {
    String writeBuff = "";
    writeBuff += "Name(Optional),StartAddress(HEX),Length(DEC),Data(HEX)\n";

    try {
      final file = File("template.csv");
      await file.writeAsString(writeBuff, mode: FileMode.write);
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      print("テンプレートファイルの作成を中止します。");
    }
  }
}

// 置き換え用データをまとめて持つためのクラス
class ReplaceData {
  late final int strtAddr;
  late final int len;
  late List<int> data;
  late String name;
  
  ReplaceData(int strtAddr, int len, List<int> data, [String? name]) {
    this.strtAddr = strtAddr;
    this.len = len;
    this.data = data;
    this.name = name ?? "(名称未設定)";
  }

  @override
  String toString() {
    String ret = "";
    ret += "Name    : ${this.name}\n";
    ret += "strtAddr: ${this.strtAddr.toRadixString(16).padLeft(8,"0").toUpperCase()}\n";
    ret += "len     : ${this.len}\n";
    ret += "data    : ${this.data}\n";
    return ret;
  }
}
