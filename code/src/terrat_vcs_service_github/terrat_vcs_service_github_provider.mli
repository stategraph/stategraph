include Terrat_vcs_provider2_github.S

(* [Tier] with the OSS feature caps (Terrat_tier.oss) clamped over whatever
   tier the installation row carries. Linked by the oss binaries; the ee
   binaries keep [Tier]. *)
module Tier_capped : module type of Tier
