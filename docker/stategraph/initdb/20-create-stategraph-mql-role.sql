-- Dev-only: the least-privilege FDW role with LOGIN and a well-known dev
-- password, so the compose topology works out of the box (pair with
-- STATEGRAPH_FDW_PASSWORD=stategraph_mql in the repo-root .env). Production
-- deployments own the credentials themselves: the unified image only ever
-- creates this role NOLOGIN and never touches passwords -- see README.md.
-- Grants are NOT applied here: the terrateam tables don't exist yet at
-- initdb time; `stategraph-server migrate` converges them after the terrat
-- migrations.
CREATE ROLE stategraph_mql LOGIN PASSWORD 'stategraph_mql';
