let is_whitespace = function
  | ' ' | '\t' | '\n' | '\r' -> true
  | _ -> false

let is_non_empty s = not (CCString.is_empty s)

let take_words ~max_nb_words s =
  if max_nb_words <= 0 then []
  else
    let len = CCString.length s in
    let rec skip_ws i = if i >= len || not (is_whitespace s.[i]) then i else skip_ws (i + 1) in
    let rec find_ws i = if i >= len || is_whitespace s.[i] then i else find_ws (i + 1) in
    let rec collect acc count i =
      if count >= max_nb_words then List.rev acc
      else
        let start = skip_ws i in
        if start >= len then List.rev acc
        else
          let stop = find_ws start in
          collect (CCString.sub s start (stop - start) :: acc) (count + 1) stop
    in
    collect [] 0 0

let words = take_words ~max_nb_words:Int.max_int
