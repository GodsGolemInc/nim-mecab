# ADR-001: MeCab バインディングに直接 C FFI を採用

## Status

Accepted

## Context

nim-mecab は MeCab 形態素解析器の Nim バインディングである。
MeCab へのアクセス方法として以下の選択肢が存在した:

1. **直接 C FFI** — Nim の `{.importc, dynlib.}` プラグマで MeCab の C API を直接呼び出す
2. **Rust バインディング経由** — mecab-rs 等の Rust クレートを介し、Nim → Rust → C の二段 FFI で接続する

### 評価軸

| 観点 | 直接 C FFI | Rust 経由 |
|------|-----------|-----------|
| 依存関係 | MeCab (libmecab) のみ | MeCab + Rust toolchain + mecab-rs |
| ビルド複雑度 | `{.dynlib.}` 1行 | cargo build + cdylib + Nim FFI |
| レイテンシ | 直接呼び出し | 二段間接呼び出し |
| メンテナンス | MeCab C API は安定 (2013年以降変更なし) | Rust クレートの互換性追従が必要 |
| 安全性 | Nim 側で管理 | Rust 側の安全性は Nim には伝播しない |
| デバッグ | MeCab のエラーを直接取得 | Rust レイヤーが介在し原因特定が複雑化 |

## Decision

**直接 C FFI を採用する。**

MeCab の C API は 5 関数 (`mecab_new2`, `mecab_sparse_tostr`, `mecab_sparse_tonode`, `mecab_destroy`, `mecab_strerror`) と小規模であり、Rust レイヤーを挟む利点がない。Rust の安全性保証は Nim の FFI 境界を超えて伝播しないため、二段 FFI は複雑さのみを追加する。

dynlib パス解決には `nim-vendor-lib` (`systemDynlib`) を使用し、プラットフォーム分岐を一元管理する。

## Consequences

- MeCab C API の安定性に依存する（リスク低: 10年以上 API 変更なし）
- Rust toolchain がビルド要件から外れ、CI/開発環境が簡素化される
- C 構造体のメモリレイアウト問題は別途対処が必要 → [ADR-002](002-string-api-over-node-api.md) で解決
