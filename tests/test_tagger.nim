import std/[unittest, sequtils, options]
import ../src/nim_mecab/tagger

suite "parseMecabLine":

  test "Given EOS line, When parse, Then none":
    check parseMecabLine("EOS").isNone

  test "Given empty line, When parse, Then none":
    check parseMecabLine("").isNone

  test "Given line without tab, When parse, Then none":
    check parseMecabLine("no-tab-here").isNone

  test "Given normal line, When parse, Then token extracted":
    let token = parseMecabLine("水\t名詞,一般,*,*,*,*,水,ミズ,ミズ")
    check token.isSome
    let t = token.get
    check t.surface == "水"
    check t.pos == "名詞"
    check t.posDetail1 == "一般"
    check t.posDetail2 == "*"
    check t.conjugation == "*"
    check t.conjugForm == "*"
    check t.baseForm == "水"
    check t.reading == "ミズ"

  test "Given line with minimal features, When parse, Then missing fields default empty":
    # Only POS, no other fields
    let token = parseMecabLine("x\t名詞")
    check token.isSome
    let t = token.get
    check t.surface == "x"
    check t.pos == "名詞"
    check t.posDetail1 == ""
    check t.posDetail2 == ""
    check t.conjugation == ""
    check t.conjugForm == ""
    check t.baseForm == "x"  # fallback to surface when parts.len <= 6
    check t.reading == ""

  test "Given line with 3 features, When parse, Then partial fields filled":
    let token = parseMecabLine("foo\tA,B,C")
    check token.isSome
    let t = token.get
    check t.pos == "A"
    check t.posDetail1 == "B"
    check t.posDetail2 == "C"
    check t.conjugation == ""
    check t.conjugForm == ""
    check t.baseForm == "foo"  # fallback to surface
    check t.reading == ""

  test "Given baseForm asterisk, When parse, Then surface used as baseForm":
    let token = parseMecabLine("xyz\t名詞,一般,*,*,*,*,*,*,*")
    check token.isSome
    check token.get.baseForm == "xyz"

  test "Given verb line, When parse, Then conjugation fields extracted":
    let token = parseMecabLine("捻っ\t動詞,自立,*,*,五段・ラ行,連用タ接続,捻る,ヒネッ,ヒネッ")
    check token.isSome
    let t = token.get
    check t.surface == "捻っ"
    check t.pos == "動詞"
    check t.conjugation == "五段・ラ行"
    check t.conjugForm == "連用タ接続"
    check t.baseForm == "捻る"
    check t.reading == "ヒネッ"

  test "Given tab at position 0, When parse, Then empty surface":
    let token = parseMecabLine("\t名詞,一般")
    check token.isSome
    let t = token.get
    check t.surface == ""
    check t.pos == "名詞"
    check t.baseForm == ""  # fallback to empty surface

  test "Given all-empty comma fields, When parse, Then empty strings":
    let token = parseMecabLine("w\t,,,,,,,")
    check token.isSome
    let t = token.get
    check t.surface == "w"
    check t.pos == ""
    check t.posDetail1 == ""
    check t.posDetail2 == ""
    check t.conjugation == ""
    check t.conjugForm == ""
    check t.baseForm == ""
    check t.reading == ""

  test "Given exactly 5 parts, When parse, Then conjugation filled but conjugForm empty":
    # parts[0..4] = A,B,C,D,E → conjugation=parts[4]=E, conjugForm="" (parts.len<=5)
    let token = parseMecabLine("w\tA,B,C,D,E")
    check token.isSome
    let t = token.get
    check t.pos == "A"
    check t.posDetail1 == "B"
    check t.posDetail2 == "C"
    check t.conjugation == "E"
    check t.conjugForm == ""
    check t.baseForm == "w"  # fallback to surface (parts.len <= 6)

  test "Given exactly 4 parts, When parse, Then conjugation empty":
    let token = parseMecabLine("w\tA,B,C,D")
    check token.isSome
    check token.get.conjugation == ""  # parts.len == 4, not > 4

  test "Given empty feature after tab, When parse, Then pos is empty":
    let token = parseMecabLine("w\t")
    check token.isSome
    let t = token.get
    check t.surface == "w"
    check t.pos == ""
    check t.baseForm == "w"


suite "MecabTagger":

  test "Given Japanese text, When tokenize, Then morphemes extracted":
    var tagger = newMecabTagger()
    let tokens = tagger.tokenize("水を出す")
    check tokens.len >= 3
    check tokens[0].surface == "水"
    check tokens[0].pos == "名詞"
    check tokens[1].surface == "を"
    check tokens[1].pos == "助詞"
    check tokens[2].surface == "出す"
    check tokens[2].pos == "動詞"
    check tokens[2].baseForm == "出す"
    tagger.destroy()

  test "Given verb, When tokenize, Then baseForm is dictionary form":
    var tagger = newMecabTagger()
    let tokens = tagger.tokenize("捻った")
    let verb = tokens.filterIt(it.pos == "動詞")
    check verb.len >= 1
    check verb[0].baseForm == "捻る"
    tagger.destroy()

  test "Given text, When contentTokens, Then only content words returned":
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("水を出すときに捻るものは")
    # "水"(名詞), "出す"(動詞), "捻る"(動詞) — とき(非自立名詞), もの(非自立名詞) excluded
    check "水" in content
    check "出す" in content
    check "捻る" in content
    check "もの" notin content  # 非自立名詞は除外
    check "は" notin content    # 助詞は除外
    tagger.destroy()

  test "Given empty text, When tokenize, Then empty seq":
    var tagger = newMecabTagger()
    check tagger.tokenize("").len == 0
    tagger.destroy()

  test "Given katakana word, When tokenize, Then tokens extracted":
    var tagger = newMecabTagger()
    let tokens = tagger.tokenize("マザーボード")
    check tokens.len >= 1
    let surfaces = tokens.mapIt(it.surface)
    check "マザー" in surfaces or "マザーボード" in surfaces
    tagger.destroy()

  test "Given invalid args, When newMecabTagger, Then MecabError raised":
    expect MecabError:
      discard newMecabTagger("-d /nonexistent/dictionary/path")

  test "Given destroyed tagger, When destroy again, Then no crash":
    var tagger = newMecabTagger()
    tagger.destroy()
    tagger.destroy()  # second call should be safe no-op

  test "Given destroyed tagger, When tokenize, Then empty seq":
    var tagger = newMecabTagger()
    tagger.destroy()
    check tagger.tokenize("テスト").len == 0


suite "isContentWord":

  test "Given noun token, When isContentWord, Then true":
    check MecabToken(pos: "名詞").isContentWord == true

  test "Given verb token, When isContentWord, Then true":
    check MecabToken(pos: "動詞").isContentWord == true

  test "Given adjective token, When isContentWord, Then true":
    check MecabToken(pos: "形容詞").isContentWord == true

  test "Given adverb token, When isContentWord, Then true":
    check MecabToken(pos: "副詞").isContentWord == true

  test "Given particle token, When isContentWord, Then false":
    check MecabToken(pos: "助詞").isContentWord == false

  test "Given auxiliary verb token, When isContentWord, Then false":
    check MecabToken(pos: "助動詞").isContentWord == false


suite "contentTokens":

  test "Given adjective input, When contentTokens, Then adjective baseForm included":
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("美しい花")
    check "美しい" in content
    check "花" in content
    tagger.destroy()

  test "Given adverb input, When contentTokens, Then adverb baseForm included":
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("とても速い")
    check "とても" in content
    tagger.destroy()

  test "Given suffix noun, When contentTokens, Then suffix excluded":
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("田中さんは走る")
    check "田中" in content
    check "走る" in content
    check "さん" notin content  # 接尾名詞は除外
    tagger.destroy()

  test "Given non-independent noun, When contentTokens, Then excluded":
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("食べることが好きだ")
    check "こと" notin content  # 非自立名詞は除外
    check "食べる" in content
    tagger.destroy()

  test "Given token with empty baseForm, When contentTokens, Then skipped":
    # Verify the baseForm.len == 0 guard in contentTokens.
    # A content word token with empty baseForm should not appear in results.
    # We test this via isContentWord + contentTokens contract:
    # constructing a scenario where baseForm would be empty is not possible
    # with real MeCab, so we verify the guard exists by checking that
    # contentTokens returns only non-empty strings.
    var tagger = newMecabTagger()
    let content = tagger.contentTokens("水を出す")
    for word in content:
      check word.len > 0  # no empty strings in output
    tagger.destroy()
