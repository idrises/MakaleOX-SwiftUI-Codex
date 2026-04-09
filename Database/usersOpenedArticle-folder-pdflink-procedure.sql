/*
    Installs the shared repair procedure for dbo.usersOpenedArticle.

    Compatible with older SQL Server versions.

    SQLPro / SSMS usage:
    - Run the whole file, not a partial selection.
    - The file uses GO batch separators.
*/

IF OBJECT_ID(N'dbo.RepairUsersOpenedArticleHistoryColumns', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RepairUsersOpenedArticleHistoryColumns;
END;
GO

CREATE PROCEDURE dbo.RepairUsersOpenedArticleHistoryColumns
    @BatchSize INT = 500,
    @MaxIterations INT = 1,
    @Verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchSize IS NULL OR @BatchSize <= 0
    BEGIN
        SET @BatchSize = 500;
    END;

    IF COL_LENGTH('dbo.usersOpenedArticle', 'issueTitle') IS NULL
    BEGIN
        ALTER TABLE dbo.usersOpenedArticle ADD issueTitle NVARCHAR(255) NULL;
    END;

    IF COL_LENGTH('dbo.usersOpenedArticle', 'folder') IS NULL
    BEGIN
        ALTER TABLE dbo.usersOpenedArticle ADD folder NVARCHAR(255) NULL;
    END;

    IF COL_LENGTH('dbo.usersOpenedArticle', 'pdfLink') IS NULL
    BEGIN
        ALTER TABLE dbo.usersOpenedArticle ADD pdfLink NVARCHAR(255) NULL;
    END;

    DECLARE @RowsUpdated INT;
    DECLARE @RemainingRows BIGINT;
    DECLARE @Iteration INT;
    DECLARE @Message NVARCHAR(400);

    SET @RowsUpdated = 1;
    SET @RemainingRows = 0;
    SET @Iteration = 0;

    WHILE @RowsUpdated > 0
      AND (@MaxIterations = 0 OR @Iteration < @MaxIterations)
    BEGIN
        SET @Iteration = @Iteration + 1;

        ;WITH Targets AS (
            SELECT TOP (@BatchSize)
                ua.usermail,
                ua.Article,
                ua.Journal,
                ISNULL(ua.year, '') AS year,
                ISNULL(ua.volume, '') AS volume,
                ua.[date]
            FROM dbo.usersOpenedArticle AS ua
            WHERE
                ISNULL(ua.issueTitle, '') = ''
                OR ISNULL(ua.folder, '') = ''
                OR ISNULL(ua.pdfLink, '') = ''
            ORDER BY
                ua.[date] ASC,
                ua.Article ASC,
                ua.Journal ASC
        ),
        MatchedRows AS (
            SELECT
                t.usermail,
                t.Article,
                t.Journal,
                t.year,
                t.volume,
                t.[date],
                resolved.DONEM,
                resolved.KLASOR,
                resolved.LINK
            FROM Targets AS t
            OUTER APPLY (
                SELECT TOP 1
                    m.DONEM,
                    m.KLASOR,
                    m.LINK
                FROM dbo.MAKALE AS m
                WHERE m.MAKALE = t.Article
                  AND m.dergi = t.Journal
                ORDER BY
                    CASE
                        WHEN t.year <> '' AND m.YIL = t.year THEN 0
                        ELSE 1
                    END,
                    CASE
                        WHEN t.volume <> '' AND m.VOLUME = t.volume THEN 0
                        ELSE 1
                    END,
                    m.createDate DESC,
                    m.YIL DESC,
                    m.VOLUME DESC
            ) AS resolved
            WHERE
                resolved.DONEM IS NOT NULL
                OR resolved.KLASOR IS NOT NULL
                OR resolved.LINK IS NOT NULL
        )
        UPDATE ua
        SET
            ua.issueTitle = CASE
                WHEN ISNULL(ua.issueTitle, '') = '' THEN MatchedRows.DONEM
                ELSE ua.issueTitle
            END,
            ua.folder = CASE
                WHEN ISNULL(ua.folder, '') = '' THEN MatchedRows.KLASOR
                ELSE ua.folder
            END,
            ua.pdfLink = CASE
                WHEN ISNULL(ua.pdfLink, '') = '' THEN MatchedRows.LINK
                ELSE ua.pdfLink
            END
        FROM dbo.usersOpenedArticle AS ua
        INNER JOIN MatchedRows
            ON ua.usermail = MatchedRows.usermail
           AND ua.Article = MatchedRows.Article
           AND ua.Journal = MatchedRows.Journal
           AND ISNULL(ua.year, '') = MatchedRows.year
           AND ISNULL(ua.volume, '') = MatchedRows.volume
           AND ua.[date] = MatchedRows.[date];

        SET @RowsUpdated = @@ROWCOUNT;

        SELECT
            @RemainingRows = COUNT(*)
        FROM dbo.usersOpenedArticle
        WHERE
            ISNULL(issueTitle, '') = ''
            OR ISNULL(folder, '') = ''
            OR ISNULL(pdfLink, '') = '';

        IF @Verbose = 1
        BEGIN
            SET @Message =
                N'Iteration ' + CAST(@Iteration AS NVARCHAR(20)) +
                N' | updated=' + CAST(@RowsUpdated AS NVARCHAR(20)) +
                N' | remaining=' + CAST(@RemainingRows AS NVARCHAR(20));
            PRINT @Message;
        END;

        IF @RowsUpdated = 0
        BEGIN
            BREAK;
        END;
    END;

    SELECT
        @Iteration AS iterationsRun,
        COUNT(*) AS totalRows,
        SUM(CASE WHEN ISNULL(folder, '') <> '' THEN 1 ELSE 0 END) AS rowsWithFolder,
        SUM(CASE WHEN ISNULL(pdfLink, '') <> '' THEN 1 ELSE 0 END) AS rowsWithPdfLink,
        SUM(CASE WHEN ISNULL(issueTitle, '') <> '' THEN 1 ELSE 0 END) AS rowsWithIssueTitle,
        SUM(
            CASE
                WHEN ISNULL(folder, '') = ''
                  OR ISNULL(pdfLink, '') = ''
                  OR ISNULL(issueTitle, '') = ''
                THEN 1
                ELSE 0
            END
        ) AS remainingRows
    FROM dbo.usersOpenedArticle;
END;
GO
