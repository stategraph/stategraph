let pattern text =
  Oth.Assert.ok ~fail_msg:("not a pattern: " ^ text) (Sg_caps_trie.Pattern.of_string text)

let rule text =
  match CCString.chop_prefix ~pre:"!" text with
  | Some refused -> (pattern refused, false)
  | None -> (pattern text, true)

let render_rule (p, allowed) = (if allowed then "" else "!") ^ Sg_caps_trie.Pattern.to_string p
let scope texts = Sg_caps_trie_scope.of_rules (CCList.map rule texts)
