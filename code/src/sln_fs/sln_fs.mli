(** Concatenate a root path with a list of segments. [concat_many path ["dir"; "subdir"]] is
    [path/dir/subdir]. *)
val concat_many : string -> string list -> string

(** Normalize a file path by resolving [.], [..], and redundant separators. *)
val normalize_path : string -> string

(** [has_no_parent_escape path] is [true] iff [path], after {!normalize_path}, is non-absolute and
    does not begin with a [..] segment — i.e., walking the path from its first segment never steps
    upward above its starting point.

    Stronger than {!Stdlib.Filename.is_relative}: that function only rejects absolute paths, while
    this also rejects relative paths like [..] or [../a] that escape their base. Because
    {!normalize_path} is applied first, it correctly classifies paths whose escape status only
    becomes visible after [.]/[..] resolution — e.g. [a/../b] is contained (normalizes to [b]) while
    [a/../../b] escapes (normalizes to [../b]).

    Use this to decide whether a path is safe to treat as a location inside some tree without the
    caller needing to know what that tree's root actually is. *)
val has_no_parent_escape : string -> bool

(** [relpath ~from ~to_] computes the relative filesystem walk from directory [from] to [to_]. Both
    arguments are normalized first via {!normalize_path}. The result walks up via [..] for each
    segment of [from] that is not shared with [to_], then down through the remaining segments of
    [to_].

    Examples:
    - [relpath ~from:"a/b" ~to_:"a/b/c/d"] = ["c/d"]
    - [relpath ~from:"a/b" ~to_:"a/c"] = ["../c"]
    - [relpath ~from:"a/b/c" ~to_:"x/y"] = ["../../../x/y"]
    - [relpath ~from:"a" ~to_:"a"] = ["."]

    Assumes both paths normalize to non-absolute, non-escaping forms. Behavior on absolute or
    escaping inputs is unspecified. *)
val relpath : from:string -> to_:string -> string

(** [classify_path ~scope filepath] decides where [filepath] lands relative to an outer tree and an
    optional inner [scope] directory nested within it. [scope] and [filepath] must be expressed in
    the same frame (both relative to the same origin).
    - [`In_scope rel] — [filepath] is under [scope]; [rel] is the path within it ([""] when it IS
      the scope directory).
    - [`In_tree p] — no scope match, but the path stays inside the tree ([has_no_parent_escape]);
      [p] is the normalized path ([""] for the tree root itself).
    - [`Outside] — absolute, or a relative path that escapes above the tree. *)
val classify_path :
  scope:string option -> string -> [ `In_scope of string | `In_tree of string | `Outside ]

(** [mkdir_p path] creates [path] and every missing ancestor, stopping at [/], [.] or the empty
    string. An already-existing directory is not an error, so concurrent callers building
    overlapping trees (parallel tests laying down fixture directories, say) do not race each other.
*)
val mkdir_p : string -> unit

(** [write_file ~dir ~filepath content] writes [content] to [dir/filepath], creating any
    intermediate directories via {!mkdir_p}. Truncates an existing file. *)
val write_file : dir:string -> filepath:string -> string -> unit

(** [mode_of_path ~default path] is [path]'s permission bits, masked to [0o777], or [default] when
    [path] cannot be stat'd. Total rather than optional because every caller reads the file's
    contents first: a stat that fails on a path just opened for reading is not a case worth
    propagating a [None] through the whole pipeline for.

    [default] is the caller's to choose. What an unreadable mode should become is a question about
    the tree being reproduced, not about the filesystem, so this layer holds no opinion on it. *)
val mode_of_path : default:int -> string -> int

(** The path whose mode could not be set, and the system's message for why. *)
type chmod_err = [ `Chmod_err of string * string ] [@@deriving show]

(** [chmod path mode] sets [path]'s permission bits to [mode land 0o777].

    Whether a mode that did not land is worth acting on belongs to the caller, not here, so the
    failure is returned rather than swallowed. *)
val chmod : string -> int -> (unit, [> chmod_err ]) result
