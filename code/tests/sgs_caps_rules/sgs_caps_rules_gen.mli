(** Shared QCheck2 generators for {!Sgs_caps_rules} values, reused across test suites. *)

(** A group pattern/name string: a short token over a small alphabet, optionally suffixed with [*].
*)
val group_str_gen : string QCheck2.Gen.t

(** A bounded-depth [cond] tree, biased toward [Group] leaves so the [Any]/[All] nesting terminates.
*)
val cond_gen : Sgs_caps_rules.cond QCheck2.Gen.t
