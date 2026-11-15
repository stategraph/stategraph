-- The run lock of the daily retention task: one runner at a time changes the pair of tables.
-- The key carries no meaning beyond being distinct from every other advisory lock this
-- installation takes -- 2979, 2128, 2721 and the hashtext pairs -- and the second argument is a
-- constant, so the two tables lock together: a runner that wins the lock walks both, and a runner
-- that loses it skips both.  One lock for the pair is what keeps a tree row and its build row from
-- expiring in two transactions.  Non-blocking on purpose: a runner that finds the lock held skips
-- the pair, whose work is idempotent and stays for the next run.  Transaction-scoped, so it
-- releases itself on commit and on rollback.  The key arrives as a parameter: the number is the
-- module's [Terrat_repo_tree_retention.advisory_lock_key], which the skip test shares.
select pg_try_advisory_xact_lock($key, hashtext('repo_tree_cache'))
