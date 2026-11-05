-- The job that this job continues.  A run of several layers is a chain of
-- jobs: the job of the command or event that started the run, then one job
-- per later layer, each made when the layer before it completes.  The head of
-- the chain is the job that started the run, and its type says whether a
-- comment started it.  Nullable: a job that starts a run continues nothing,
-- and a server that does not know the column never writes it.
alter table jobs add column if not exists continuation_of uuid
