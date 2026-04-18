import ../src/nim_mecab/ffi
import ../src/nim_mecab/tagger

var t = newMecabTagger("")
echo "tagger created"

# Test raw API first
let raw = mecab_sparse_tostr(t.handle, "水を出す")
echo "raw result: ", (if raw.isNil: "nil" else: $raw)

# Test node API
let node = mecab_sparse_tonode(t.handle, "水を出す")
echo "node: ", (if node.isNil: "nil" else: "ptr")
if not node.isNil:
  var cur = node
  var i = 0
  while not cur.isNil and i < 10:
    echo "  [", i, "] stat=", cur.stat, " len=", cur.length
    if cur.stat == 0'u8 or cur.stat == 1'u8:
      if not cur.surface.isNil and cur.length > 0:
        var s = newString(int(cur.length))
        copyMem(addr s[0], cur.surface, int(cur.length))
        echo "      surface='", s, "'"
      if not cur.feature.isNil:
        echo "      feature='", $cur.feature, "'"
    cur = cur.next
    inc i

echo "---"
let tokens = t.tokenize("水を出す")
echo "tokenize result: ", tokens.len, " tokens"
for tok in tokens:
  echo "  '", tok.surface, "' pos=", tok.pos, " base=", tok.baseForm
t.destroy()
