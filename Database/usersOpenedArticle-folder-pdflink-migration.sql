/*
    usersOpenedArticle deterministic article history migration

    SQLPro / SSMS usage:
    1. Run Database/usersOpenedArticle-folder-pdflink-procedure.sql once.
    2. Run this script to backfill a controlled number of batches.
    3. Re-run it as needed while remainingRows is still high.
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
    @MaxIterations = 20,
    @Verbose = 1;
