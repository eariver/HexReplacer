# HexReplacer v1.2.1

## About
Dart練習用のCLIアプリ。Intel HEX形式のバイナリファイルから指定されたアドレスから指定バイト分のデータを上書きする。

## How to Use
`hexreplacer.exe` (あるいは `dart main.dart`) に以下のコマンドライン引数を与える。

1. 置き換え情報が記載されたCSVファイルのパス (コマンドラインオプション `-t` でテンプレートを生成できる)
2. 置き換える前のIntel HEXファイル (現在対応しているレコードタイプはデータ、EOF、拡張リニアアドレスのみ)
3. 置き換え後のIntel HEXファイル (既に存在している場合は上書きします)

Intel HEXのデータレコード長は、`config.yaml` に記載する。 (現在は16Byteの倍数のみ対応)

## Options
いくつかのオプション機能がある。詳細はコマンドラインオプション `-h` 参照。

- 置き換え情報テンプレート作成 (コマンドラインオプション `-t`)
- HEX→CSVファイル変換 (コマンドラインオプション `-c`)
- HEXファイルからのデータ抜き出し (コマンドラインオプション `-d`)
