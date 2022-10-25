# relayer

A relayer for the Bridge to watch and sync event between Layer 1 and Taiko Layer 2.

## Layout

### cmd

Entry point to the application.

### migrations

Contains database migrations. They are created and ran with the `goose` binary.

`cd migrations`

`GOOSE_DRIVER=mysql GOOSE_DBSTRING="username:password@/dbname" goose up`
