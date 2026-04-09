/*
    Installs the shared repair procedure for dbo.usersOpenedArticle.

    Usage after running this file once:

    EXEC dbo.RepairUsersOpenedArticleHistoryColumns
        @BatchSize = 500,
        @MaxIterations = 0,   -- run until no more rows are updated
        @Verbose = 1;

    EXEC dbo.RepairUsersOpenedArticleHistoryColumns
        @BatchSize = 500,
        @MaxIterations = 1,   -- repair a single batch
        @Verbose = 0;
*/

CREATE OR ALTER PROCEDURE dbo.RepairUsersOpenedArticleHistoryColumns
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

    IF OBJECT_ID('tempdb..#Progress') IS NOT NULL
    BEGIN
        DROP TABLE #Progress;
    END;

    CREATE TABLE #Progress (
        rowsUpdated INT NOT NULL,
        rowsSelected INT NOT NULL,
        remainingRows BIGINT NOT NULL
    );

    DECLARE @RowsUpdated INT = 1;
    DECLARE @RowsSelected INT = 0;
    DECLARE @RemainingRows BIGINT = 0;
    DECLARE @Iteration INT = 0;

    DECLARE @BatchSql NVARCHAR(MAX) = N'
    IF OBJECT_ID(''tempdb..#Targets'') IS NOT NULL
    BEGIN
        DROP TABLE #Targets;
    END;

    SELECT TOP (@BatchSize)
        ua.usermail,
        ua.Article,
        ua.Journal,
        ISNULL(ua.year, '''') AS year,
        ISNULL(ua.volume, '''') AS volume,
        ua.[date]
    INTO #Targets
    FROM dbo.usersOpenedArticle AS ua WITH (READPAST)
    WHERE
        ISNULL(ua.folder, '''') = ''''
        OR ISNULL(ua.pdfLink, '''') = ''''
        OR ISNULL(ua.issueTitle, '''') = ''''
    ORDER BY
        ua.[date] ASC,
        ua.Article ASC,
        ua.Journal ASC;

    ;WITH CandidateMatches AS (
        SELECT
            t.usermail,
            t.Article,
            t.Journal,
            t.year,
            t.volume,
            t.[date],
            resolved.DONEM AS resolvedIssueTitle,
            resolved.KLASOR AS resolvedFolder,
            resolved.LINK AS resolvedPdfLink
        FROM #Targets AS t
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
                    WHEN t.year <> ''''
                     AND m.YIL = t.year THEN 0
                    ELSE 1
                END,
                CASE
                    WHEN t.volume <> ''''
                     AND m.VOLUME = t.volume THEN 0
                    ELSE 1
                END,
                m.createDate DESC,
                m.YIL DESC,
                m.VOLUME DESC
        ) AS resolved
        WHERE resolved.KLASOR IS NOT NULL
           OR resolved.LINK IS NOT NULL
           OR resolved.DONEM IS NOT NULL
    )
    UPDATE ua
    SET
        ua.issueTitle = CASE
            WHEN ISNULL(ua.issueTitle, '''') = '''' THEN CandidateMatches.resolvedIssueTitle
            ELSE ua.issueTitle
        END,
        ua.folder = CASE
            WHEN ISNULL(ua.folder, '''') = '''' THEN CandidateMatches.resolvedFolder
            ELSE ua.folder
        END,
        ua.pdfLink = CASE
            WHEN ISNULL(ua.pdfLink, '''') = '''' THEN CandidateMatches.resolvedPdfLink
            ELSE ua.pdfLink
        END
    FROM dbo.usersOpenedArticle AS ua
    INNER JOIN CandidateMatches
        ON ua.usermail = CandidateMatches.usermail
       AND ua.Article = CandidateMatches.Article
       AND ua.Journal = CandidateMatches.Journal
       AND ISNULL(ua.year, '''') = CandidateMatches.year
       AND ISNULL(ua.volume, '''') = CandidateMatches.volume
       AND ua.[date] = CandidateMatches.[date];

    SELECT
        @@ROWCOUNT AS rowsUpdated,
        (SELECT COUNT(*) FROM #Targets) AS rowsSelected,
        (
            SELECT COUNT(*)
            FROM dbo.usersOpenedArticle
            WHERE
                ISNULL(folder, '''') = ''''
                OR ISNULL(pdfLink, '''') = ''''
                OR ISNULL(issueTitle, '''') = ''''
        ) AS remainingRows;
    ';

    WHILE @RowsUpdated > 0
      AND (@MaxIterations = 0 OR @Iteration < @MaxIterations)
    BEGIN
        SET @Iteration += 1;

        DELETE FROM #Progress;

        INSERT INTO #Progress (rowsUpdated, rowsSelected, remainingRows)
        EXEC sys.sp_executesql
            @BatchSql,
            N'@BatchSize INT',
            @BatchSize = @BatchSize;

        SELECT TOP (1)
            @RowsUpdated = rowsUpdated,
            @RowsSelected = rowsSelected,
            @RemainingRows = remainingRows
        FROM #Progress;

        IF @Verbose = 1
        BEGIN
            PRINT CONCAT(
                'Iteration ',
                @Iteration,
                ' | selected=',
                @RowsSelected,
                ' | updated=',
                @RowsUpdated,
                ' | remaining=',
                @RemainingRows
            );
        END;

        IF @RowsSelected = 0 OR @RowsUpdated = 0
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
