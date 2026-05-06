## High-level MeCab tagger API.
##
## Uses mecab_sparse_tostr (string output) instead of node API
## to avoid C struct layout issues across platforms.
##
## Usage:
##   var tagger = newMecabTagger()
##   let tokens = tagger.tokenize("水を出すときに捻るものは")
##   for t in tokens:
##     echo t.surface, " ", t.pos, " ", t.baseForm
##   tagger.destroy()

import std/[strutils, options, unicode]
import ./ffi

type
  MecabToken* = object
    surface*: string
    pos*: string          ## 品詞
    posDetail1*: string   ## 品詞細分類1
    posDetail2*: string   ## 品詞細分類2
    conjugation*: string  ## 活用型
    conjugForm*: string   ## 活用形
    baseForm*: string     ## 原形（辞書形）
    reading*: string      ## 読み

  MecabTagger* = object
    handle*: MecabT

  MecabError* = object of CatchableError

proc newMecabTagger*(args: string = ""): MecabTagger {.raises: [MecabError].} =
  let handle = mecab_new2(args.cstring)
  if handle.isNil:
    let errMsg = mecab_strerror(nil)
    raise newException(MecabError, "Failed to initialize MeCab: " & $errMsg)
  result = MecabTagger(handle: handle)

proc destroy*(tagger: var MecabTagger) {.raises: [].} =
  if not tagger.handle.isNil:
    mecab_destroy(tagger.handle)
    tagger.handle = nil

proc parseMecabLine*(line: string): Option[MecabToken] {.raises: [].} =
  ## Parse a single MeCab output line into a token.
  ## Format: "surface\tPOS,detail1,detail2,detail3,conjugation,form,base,reading,pronunciation"
  ## Returns none for EOS, empty lines, or malformed lines.
  if line == "EOS" or line.len == 0:
    return none(MecabToken)
  let tabPos = line.find('\t')
  if tabPos < 0:
    return none(MecabToken)
  let surface = line[0 ..< tabPos]
  let featureStr = line[tabPos + 1 .. ^1]
  let parts = featureStr.split(',')
  var token = MecabToken(surface: surface)
  token.pos = if parts.len > 0: parts[0] else: ""
  token.posDetail1 = if parts.len > 1: parts[1] else: ""
  token.posDetail2 = if parts.len > 2: parts[2] else: ""
  token.conjugation = if parts.len > 4: parts[4] else: ""
  token.conjugForm = if parts.len > 5: parts[5] else: ""
  token.baseForm = if parts.len > 6: parts[6] else: surface
  token.reading = if parts.len > 7: parts[7] else: ""
  if token.baseForm == "*":
    token.baseForm = surface
  result = some(token)

proc tokenize*(tagger: MecabTagger, text: string): seq[MecabToken] {.raises: [].} =
  ## Tokenize text by parsing mecab_sparse_tostr output.
  result = @[]
  if tagger.handle.isNil or text.len == 0:
    return
  let raw = mecab_sparse_tostr(tagger.handle, text.cstring)
  if raw.isNil:
    return
  let output = $raw
  for line in output.splitLines():
    let token = parseMecabLine(line)
    if token.isNone:
      if line == "EOS" or line.len == 0:
        break
      continue
    result.add(token.get)

proc isContentWord*(token: MecabToken): bool {.raises: [].} =
  ## True for content words: nouns, verbs, adjectives, adverbs.
  token.pos in ["名詞", "動詞", "形容詞", "副詞"]

proc contentTokens*(tagger: MecabTagger, text: string): seq[string] {.raises: [].} =
  ## Tokenize and return base forms of content words only.
  ## Excludes particles, auxiliary verbs, non-independent nouns (もの, こと, とき).
  let tokens = tagger.tokenize(text)
  for t in tokens:
    if not t.isContentWord: continue
    if t.baseForm.len == 0: continue
    # Skip non-independent nouns (もの, こと, とき, etc.)
    if t.pos == "名詞" and t.posDetail1 == "非自立":
      continue
    # Skip suffix nouns (さん, 的, etc.)
    if t.pos == "名詞" and t.posDetail1 == "接尾":
      continue
    result.add(t.baseForm)

proc containsKanji*(s: string): bool {.raises: [].} =
  ## True if any rune in `s` falls in the CJK unified ideographs range.
  for r in s.runes:
    let cp = int32(r)
    if (cp >= 0x4E00 and cp <= 0x9FFF) or
       (cp >= 0x3400 and cp <= 0x4DBF) or
       (cp >= 0x20000 and cp <= 0x2A6DF):
      return true
  return false

proc kanaize*(tagger: MecabTagger, text: string): string {.raises: [].} =
  ## Replace kanji-bearing tokens with their MeCab `reading` (katakana).
  ## Hiragana / katakana / ASCII / punctuation tokens are passed through
  ## verbatim. Tokens whose `reading` is empty (unknown words, single
  ## punctuation) fall back to `surface`. The output is intended for TTS
  ## engines that mishandle kanji directly — pre-converting to katakana
  ## stabilises pronunciation while preserving non-kanji segments.
  if tagger.handle.isNil or text.len == 0:
    return text
  let tokens = tagger.tokenize(text)
  if tokens.len == 0:
    return text
  result = newStringOfCap(text.len * 2)
  for t in tokens:
    if t.reading.len > 0 and t.surface.containsKanji():
      result.add(t.reading)
    else:
      result.add(t.surface)
