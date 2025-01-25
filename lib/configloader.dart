library configloader;
import 'dart:io';
import 'package:yaml/yaml.dart';

class Config {
  late final bool isUseCustomDataRecordSize;
  late final int dataRecordSize;

  Config({int? dataRecordSize}) {
    this.dataRecordSize = dataRecordSize ?? 0;
    this.isUseCustomDataRecordSize = (dataRecordSize != null);
  }

  @override
  String toString() {
    String ret = "";
    ret += "UseCustomDataRecordSize: ${this.isUseCustomDataRecordSize}\n";
    if (this.isUseCustomDataRecordSize)
      ret += "DataRecordSize: ${this.dataRecordSize}\n";
    return ret;
  }

  // config.yamlから設定を読み込んで、Configインスタンスを作成する
  static Future<Config?> load() async {
    int? dataRecordSize;
    try {
      final file = File("config.yaml");

      // Yamlがない → 再生成
      if (!await file.exists()) {
        _createSettingYaml(file);
        print("config.yamlが存在しないため新規作成しました。デフォルト設定で動作します。");
        return Config();
      }

      late final yamlFile;
      try {
        yamlFile = loadYaml(file.readAsStringSync()) as YamlMap;
      }
      // Yamlが開けない → 再生成
      catch (e1) {
        _createSettingYaml(file);
        print("config.yamlが正常に読み込めないため新規作成しました。デフォルト設定で動作します。");
        return Config();
      }

      // Yamlが空 → 再生成
      if (yamlFile.isEmpty) {
        _createSettingYaml(file);
        print("config.yamlが空白であるため新規作成しました。デフォルト設定で動作します。");
        return Config();
      }

      // DataRecordSettingセクションの読み込み
      // いずれかの項目がない場合は再生成せずデフォルト設定とする
      // ファイル削除で再生成可能な旨を表示する
      if (!yamlFile.containsKey("DataRecordSetting")) {
        print("config.yamlに DataRecordSetting が存在しません。この項目についてはデフォルト設定で動作します。");
        print("config.yamlを再生成する場合は、config.yamlを削除してください。");
        dataRecordSize = null;
      }
      else {
        final drs = yamlFile["DataRecordSetting"] as YamlMap?;

        if (drs == null || !drs.containsKey("UseCustomDataRecordSize")) {
          print("config.yamlに UseCustomDataRecordSize が存在しません。この項目についてはデフォルト設定で動作します。");
          print("config.yamlを再生成する場合は、config.yamlを削除してください。");
          dataRecordSize = null;
        }
        else {
          try {
            final ucdrs = drs["UseCustomDataRecordSize"] as bool?;
            if (ucdrs == null || !ucdrs)
              dataRecordSize = null;
            else if (!drs.containsKey("DataRecordSize")) {
              print(
                  "config.yamlに DataRecordSize が存在しません。この項目についてはデフォルト設定で動作します。");
              print(
                  "config.yamlを再生成する場合は、config.yamlを削除してください。");
              dataRecordSize = null;
            }
            else {
              final drsiz = drs["DataRecordSize"] as int?;
              if (drsiz == null)
                dataRecordSize = null;
              else
                dataRecordSize = drsiz;
            }
          }
          catch (e2) {
            print("DataRecordSetting の読み込みに失敗しました。この項目についてはデフォルト設定で動作します。");
            print("config.yamlを再生成する場合は、config.yamlを削除してください。");
            dataRecordSize = null;
          }
        }
      }

      return Config(dataRecordSize: dataRecordSize);
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      return null;
    }
  }

  // config.yamlを作成する
  static Future<void> _createSettingYaml(File file) async {
    // Configに書き込む内容を記載
    String writeBuff = "";
    writeBuff += "# 00: DataRecord に関する設定\n";
    writeBuff += "DataRecordSetting:\n";
    writeBuff += "    # 書き出し時に読み込み元HEXと同じデータサイズを使用するか否か(bool)\n";
    writeBuff += "    UseCustomDataRecordSize: false\n";
    writeBuff += "    # 1レコードあたりのデータサイズを指定する(un-sig int)\n";
    writeBuff += "    # UseCustomDataRecordSize == false ならばこの設定は無視される\n";
    writeBuff += "    dataRecordSize: 16\n";
    try {
      await file.writeAsString(writeBuff, mode: FileMode.write);
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      print("Configファイルの作成を中止します。");
    }
  }
}
