(* Padded RFC 4648, the variant {!is_valid} accepts. Padding is not optional: a padded encoding
   carries its own length, so a value that was truncated in transit or in storage fails to decode
   instead of decoding into a shorter string that looks intact. *)
let encode s = Base64.encode_string ~pad:true s

(* Fails rather than best-efforts. [Base64.decode_exn] pads a malformed input out with trailing NULs
   and returns it, which is the one outcome a caller storing opaque bytes must never get: it turns a
   damaged row into a plausible value nothing downstream can distinguish from the real one. *)
let decode s = Base64.decode ~pad:true s

let is_alphabet = function
  | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '+' | '/' -> true
  | _ -> false

(* Checked by walking the string rather than by decoding it: the values this guards are plans large
   enough to have needed fragmenting in the first place, and decoding one only to discard the result
   would allocate the whole plan to answer a yes/no question. *)
let is_valid s =
  let len = CCString.length s in
  if len mod 4 <> 0 then false
  else
    let pad =
      if len = 0 then 0
      else if not (CCChar.equal (CCString.get s (len - 1)) '=') then 0
      else if CCChar.equal (CCString.get s (len - 2)) '=' then 2
      else 1
    in
    let stop = len - pad in
    let rec loop i = i >= stop || (is_alphabet (CCString.get s i) && loop (i + 1)) in
    loop 0

(* [Base64_rfc2045] gives [`Malformed "\n"] for the bare LF that PostgreSQL writes, and the decoder
   continues after a [`Malformed]. Thus the loop ignores that one value and continues. Each other
   malformation is an error. *)
let decode_rfc2045 s =
  let decoder = Base64_rfc2045.decoder (`String s) in
  let buf = Buffer.create (CCString.length s) in
  let rec loop () =
    match Base64_rfc2045.decode decoder with
    | `End -> Ok (Buffer.contents buf)
    | `Flush data ->
        Buffer.add_string buf data;
        loop ()
    | `Malformed "\n" -> loop ()
    | `Malformed err -> Error (`Msg (Printf.sprintf "malformed base64: %s" err))
    | `Wrong_padding -> Error (`Msg "wrong base64 padding")
    | `Await -> Error (`Msg "unexpected await from string source")
  in
  loop ()
