-- RFD 1008 Phase 2: which rows of [transaction_hints] a walk wrote for the
-- instances of a body block.  The walk of a plan writes them, and the apply then
-- moves them into [hcl_hints] with the rows of the root blocks
-- ([update_state_apply_tx.sql], [move_hints]).  The apply asks this column
-- whether a walk already wrote them: an import runs no walk, and the apply makes
-- them itself.
--
-- The answer has to be exact.  A false "already written" leaves the stored hint
-- of a changed instance behind, and the next plan then reads a hint of the
-- configuration before this transaction.
--
-- Backwards compatible: the column is new and has a default, and a row that a
-- server before this phase writes is a row of a root block, which the default
-- describes.
alter table transaction_hints
    add column instance boolean not null default false;
