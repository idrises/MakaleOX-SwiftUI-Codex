/*
    usersOpenedArticle deterministic article history migration

    SQLPro / SSMS usage:
    1. Run Database/usersOpenedArticle-folder-pdflink-procedure.sql once.
    2. Run this script to backfill until no more rows can be repaired.
*/

SET NOCOUNT ON;

IF OBJECT_ID('dbo.RepairUsersOpenedArticleHistoryColumns', 'P') IS NULL
BEGIN
    RAISERROR(
        'dbo.RepairUsersOpenedArticleHistoryColumns not found. Run Database/usersOpenedArticle-folder-pdflink-procedure.sql first.',
        16,
        1
    );
    RETURN;
END;

EXEC dbo.RepairUsersOpenedArticleHistoryColumns
    @BatchSize = 500,
    @MaxIterations = 0,
    @Verbose = 1;
