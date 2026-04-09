/*
    usersOpenedArticle repair job step

    SQLPro manual usage:
    - Run Database/usersOpenedArticle-folder-pdflink-procedure.sql once.
    - Run this script whenever you want to repair one small batch of new NULL rows.

    Scheduler usage:
    - Safe to run every 1 to 5 minutes.
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
    @MaxIterations = 1,
    @Verbose = 0;
