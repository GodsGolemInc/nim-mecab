# ADR-002: MeCab Node API ではなく String API を採用

## Status

Accepted

## Context

MeCab C API は解析結果を取得する方法を 2 つ提供する:

1. **Node API** (`mecab_sparse_tonode`) — `MecabNodeT` 構造体の連結リストを返す
2. **String API** (`mecab_sparse_tostr`) — テキスト形式の解析結果を返す

### Node API のリスク

`MecabNodeT` は C 構造体であり、Nim 側でフィールドオフセットを正確に再現する必要がある。以下のリスクが存在する:

- **パディング差異**: コンパイラ (gcc/clang/msvc)、アーキテクチャ (x86_64/arm64)、MeCab ビルドオプションによって構造体のパディングが異なる可能性がある
- **バージョン差異**: MeCab のバージョンアップでフィールドが追加・変更された場合、Nim 側の定義と乖離しセグメンテーションフォールトを引き起こす
- **検出困難性**: レイアウト不一致はコンパイル時に検出できず、実行時に不正メモリアクセスとして顕在化する。症状はフィールド値の化け、間欠的セグフォなど再現困難な形をとる

### String API の特性

- 出力形式: `"surface\tPOS,detail1,detail2,...,reading,pronunciation\n"`
- 最終行: `"EOS\n"`
- C 構造体のメモリレイアウトに依存しない
- 文字列パースのオーバーヘッドがある（ただし形態素解析自体が支配的なため影響は無視できる）

## Decision

**String API (`mecab_sparse_tostr`) を採用する。**

パース処理は純粋関数 `parseMecabLine` として抽出し、C ライブラリ非依存で全分岐をテスト可能にする。

Node API の FFI 定義 (`mecab_sparse_tonode`, `MecabNodeT`) は ffi.nim に保持する。デバッグやプロファイリングで Node API が必要になるケースに備えるが、本番コードパスでは使用しない。

## Consequences

- クロスプラットフォームでの安全性が保証される（セグフォリスク排除）
- 文字列パースにより全フィールドの抽出ロジックが明示的かつテスト可能になる
- Node API 固有の情報（`alpha`, `beta`, `prob`, `cost` 等のスコア値）は String API では取得できない。将来これらが必要になった場合は Node API への切り替えを検討し、構造体レイアウトの検証テストを必須とする
