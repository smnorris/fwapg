Very basic tests, run and check manually if editing the covered function.
All queries should return true.

psql $DATABASE_URL -f test_FWA_Downstream.sql
psql $DATABASE_URL -f test_hydroshed.sql
psql $DATABASE_URL -f test_FWA_IndexPoint.sql
psql $DATABASE_URL -f test_FWA_LocateAlong.sql
psql $DATABASE_URL -f test_FWA_Upstream.sql
psql $DATABASE_URL -f test_FWA_UpstreamBorderCrossings.sql