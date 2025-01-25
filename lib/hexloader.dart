library hexloader;
import 'dart:io';

class HexLoader {
  late final int strtAddr;
  late final int endAddr;
  late final int dataRecordSize;
  late List<List<int>> data;

  HexLoader(int strt, int end, int drsize) {
    this.strtAddr = strt;
    this.endAddr = end;
    this.dataRecordSize = drsize;
    this.data = List.generate((this.endAddr - this.strtAddr) ~/ 16 + 1, (i) => List.filled(16, 0));
  }

  // 開始アドレスと終了アドレスを指定してHEXデータを置き換えるメソッド
  bool replaceData(int strt, int len, List<int> datas) {
    // 範囲外のエラーハンドル
    final int end = strt + len - 1;
    if (!(strt >= this.strtAddr && end <= this.endAddr)) {
      print("アドレス ${strt.toRadixString(16)} - ${end.toRadixString(16)} は、このHEXファイルの範囲 ${this.strtAddr.toRadixString(16)} - ${this.endAddr.toRadixString(16)} の外にあります。");
      return false;
    }

    // 開始アドレスの要素番号サーチ
    final int strtRow = (strt - this.strtAddr) ~/ 16;
    final int strtCol = (strt - this.strtAddr) % 16;

    int curRow = strtRow;
    int curCol = strtCol;

    // 逐次代入
    datas.forEach((data) {
      this.data[curRow][curCol] = data;
      if (curCol != 15) {
        curCol++;
      }
      else {
        curCol = 0;
        curRow++;
      }
    });

    return true;
  }

  // HEXデータをファイル出力するメソッド、データレコードサイズを指定しなければメンバフィールドの値を使う
  Future<bool> toIHEXFile(String fileName, [int? dataRecordSize, bool? doOverRide]) async {
    int len = dataRecordSize ?? this.dataRecordSize;
    if (len % 16 != 0) {
      print("このプログラムは16Byteの倍数でのみIntel HEXファイルの出力が可能です。");
      print("HEXファイルの作成を中止します。");
      return false;
    }

    try {
      var file = File(fileName);
      if (await file.exists() && !(doOverRide ?? false)) {
          print("既にファイルが存在しているため、処理を中止します。");
          return false;
      }

      int currAddr = this.strtAddr;
      int prevAddr = 0x00000000;
      int dataRecordLeft = 0;
      String writeBuff = "";

      this.data.forEach((dats) async {
        String tempRecord = "";
        if (currAddr ~/ 0x10000 != prevAddr ~/ 0x10000) {
          writeBuff += ":";
          tempRecord += "02000004";
          tempRecord += (currAddr ~/ 0x10000).toRadixString(16).padLeft(4, "0").toUpperCase();
          tempRecord += (calcChecksum(tempRecord) ?? 0).toRadixString(16).padLeft(2, "0").toUpperCase();
          writeBuff += "${tempRecord}\n";
          tempRecord = "";
        }

        if (dataRecordLeft == 0) {
          writeBuff += ":";
          tempRecord += len.toRadixString(16).padLeft(2, "0").toUpperCase();
          tempRecord += ((currAddr % 0x10000) ~/ 0x10 * 0x10).toRadixString(16).padLeft(4, "0").toUpperCase();
          tempRecord += "00";
          dataRecordLeft = len;
        }

        dats.forEach((d) => tempRecord += d.toRadixString(16).padLeft(2, "0").toUpperCase());
        writeBuff += "${tempRecord}";
        dataRecordLeft -= 16;
        prevAddr = currAddr;

        if (dataRecordLeft == 0) {
          writeBuff += (calcChecksum(tempRecord) ?? 0).toRadixString(16).padLeft(2, "0").toUpperCase();
          writeBuff += "\n";
          currAddr += len;
        }
      });
      
      writeBuff += ":00000001FF\n";
      await file.writeAsString(writeBuff, mode: FileMode.write);

      return true;
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      print("ファイルの作成を中止します。");
      return false;
    }
  }

  @override
  String toString() {
    String ret = "Start: 0x${this.strtAddr.toRadixString(16).padLeft(8, "0").toUpperCase()}\nEnd  : 0x${this.endAddr.toRadixString(16).padLeft(8, "0").toUpperCase()}";
    ret += "\nFirst 16Byte Data (HEX):\n ";
    this.data.first.forEach((d) => ret += " ${d.toRadixString(16).padLeft(2,"0").toUpperCase()}");
    ret += "\nEnd   16Byte Data (HEX):\n ";
    this.data.last.forEach((d) => ret += " ${d.toRadixString(16).padLeft(2,"0").toUpperCase()}");
    ret += "\nIntel Hex File Data Record Size: ${this.dataRecordSize} Bytes";

    return ret;
  }

  // Intel HEXファイルからデータを読みだしてインスタンスを生成する
  static Future<HexLoader?> load(String fileName) async {
    try {
      final file = File(fileName);
      if (!(await file.exists())) {
        print("HEXファイルが存在しません");
        return null;
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        print("HEXファイルが空です");
        return null;
      }

      late final int strt;
      late final int end;
      late final int drsize;
      int tmpBaseAddr = 0x00000000;
      int tmpAddr = 0x00000000;
      String rType = "FF";
      bool isStrStrt = false;
      bool isStrEnd = false;
      bool feTerm = false;
      List<String> datas = [];
      int prevAddr = 0x00000000;
      int rowCnt = 0;

      // ファイルから読み込んだ行をレコードタイプ毎に処理する。
      // EOFレコードを読み込んだり、読み込んだレコードがFormat不良(下記いずれか)の場合は以降のForEach処理をスキップする
      // * 異なるデータ長のデータレコード (最初に読み込んだデータレコードのデータ長と異なるデータ長)
      // * 前回読み込みの終了アドレスと今回読み込みの開始アドレスが連続していない
      lines.forEach((str) {
        rType = str.substring(7,9);
        rowCnt++;

        if (feTerm) {} // 処理中止 or 終了時はForEach処理を飛ばす
        else if (rType == "00") {
          // Data Record
          tmpAddr = tmpBaseAddr + int.parse("0x" + str.substring(3,7));
          if (!isStrStrt) {
            strt = tmpAddr;
            drsize = int.parse("0x" + str.substring(1,3));
            prevAddr = tmpAddr - 1;
            isStrStrt = true;
          }

          // 今回の読み込みデータ範囲が前回までと異なる場合に処理を中止する
          if (drsize != int.parse("0x" + str.substring(1,3))) {
            print("$rowCnt 行目で異なるデータ長のデータレコードを検出しました。処理を中止します。");
            feTerm = true;
          }
          // 前回の終了アドレスと今回の開始アドレスが不一致の場合に処理を中止する
          else if (tmpAddr != (prevAddr + 1)) {
            print("$rowCnt 行目で前回読み込み最終アドレスと今回読み込み開始アドレスの乖離を検出しました。処理を中止します。");
            print("prev: ${prevAddr.toRadixString(16).toUpperCase()}, now: ${tmpAddr.toRadixString(16).toUpperCase()}, rawText: ${str}");
            feTerm = true;
          }
          else {
            prevAddr = tmpAddr + drsize - 1;
            datas.add(str.substring(9, (9 + drsize * 2)));
          }
        }
        else if (rType == "01") {
          // EOF Record
          end = prevAddr;
          isStrEnd = true;
          feTerm = true;
        }
        else if (rType == "04") {
          // Ex Linear Addr Record
          tmpBaseAddr = int.parse("0x" + str.substring(9, 13) + "0000");
        }
        else {
          // Other Record
          print("レコードタイプ 0x$rType は現在サポートしていません。Skipします。");
        }
      });

      if (feTerm && !isStrEnd) {
        return null;
      }

      // 開始アドレス、終了アドレス、データレコードサイズを渡してインスタンスを生成する
      HexLoader hex = HexLoader(strt, end, drsize);

      tmpAddr = strt;
      feTerm = false;
      datas.forEach((data) {
        if (!feTerm) {
          int len = data.length ~/ 2;
          List<int>? tmpData = parseData(data, len);
          if (tmpData == null) {
            print("アドレス 0x${tmpAddr.toRadixString(16).toUpperCase()} に代入するデータ ${data} あるいはデータサイズ ${len} が不正です。処理を中止します。");
            feTerm = true;
          }
          else {
            if (!hex.replaceData(tmpAddr, len, tmpData)) {
              print("アドレス 0x${tmpAddr.toRadixString(16).toUpperCase()} へのデータ代入に失敗しました。処理を中止します。");
              feTerm = true;
            }
            else tmpAddr += len;
          }
        }
      });
      return hex;
    }
    catch (e) {
      print("不測のエラーが発生しました: $e");
      return null;
    }
  }

  // HEX文字列(バイナリ)を1ByteずつパースしてInt型配列として返す
  static List<int>? parseData(String strData, int dLen) {
    // データサイズ不正のハンドリング
    if (strData.length != dLen * 2) return null;

    List<int> datas = List.generate(dLen, (i) => 0);
    for (int i = 0; i < dLen; i++) {
      int? tempData = int.tryParse(strData[2 * i] + strData[2 * i + 1], radix: 16);
      if (tempData == null) return null;
      datas[i] = tempData;
    }

    return datas;
  }

  // Intel HEXのチェックサムフィールド値を計算する
  static int? calcChecksum(String strData) {
    List<int>? recordData = parseData(strData, strData.length ~/ 2);
    if (recordData == null) return null;

    int sum = 0;
    recordData.forEach((rd) => sum += rd);
    return (256 - (sum % 256)) % 0x100;
  }
}
