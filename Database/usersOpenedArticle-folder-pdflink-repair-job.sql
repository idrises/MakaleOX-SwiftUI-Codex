/*
    usersOpenedArticle repair job step

    Run this periodically with SQL Server Agent or another scheduler.
    It repairs only a small batch of rows that are still missing
    issueTitle/folder/pdfLink, so legacy apps can keep writing old-format rows
    and the table will still self-heal over time.

    Suggested schedule:
    - every 1 to 5 minutes
*/

SET NOCOUNT ON;

DECLARE @BatchSize INT = 500;

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

;WITH Targets AS (
    SELECT TOP (@BatchSize)
        ua.usermail,
        ua.Article,
        ua.Journal,
        ISNULL(ua.year, '') AS year,
        ISNULL(ua.volume, '') AS volume,
        ua.[date]
    FROM dbo.usersOpenedArticle AS ua WITH (READPAST)
    WHERE
        ISNULL(ua.folder, '') = ''
        OR ISNULL(ua.pdfLink, '') = ''
        OR ISNULL(ua.issueTitle, '') = ''
    ORDER BY
        ua.[date] ASC,
        ua.Article ASC,
        ua.Journal ASC
),
CandidateMatches AS (
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
                WHEN t.year <> ''
                 AND m.YIL = t.year THEN 0
                ELSE 1
            END,
            CASE
                WHEN t.volume <> ''
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
        WHEN ISNULL(ua.issueTitle, '') = '' THEN CandidateMatches.resolvedIssueTitle
        ELSE ua.issueTitle
    END,
    ua.folder = CASE
        WHEN ISNULL(ua.folder, '') = '' THEN CandidateMatches.resolvedFolder
        ELSE ua.folder
    END,
    ua.pdfLink = CASE
        WHEN ISNULL(ua.pdfLink, '') = '' THEN CandidateMatches.resolvedPdfLink
        ELSE ua.pdfLink
    END
FROM dbo.usersOpenedArticle AS ua
INNER JOIN CandidateMatches
    ON ua.usermail = CandidateMatches.usermail
   AND ua.Article = CandidateMatches.Article
   AND ua.Journal = CandidateMatches.Journal
   AND ISNULL(ua.year, '') = CandidateMatches.year
   AND ISNULL(ua.volume, '') = CandidateMatches.volume
   AND ua.[date] = CandidateMatches.[date];

SELECT
    @@ROWCOUNT AS rowsUpdated,
    (
        SELECT COUNT(*)
        FROM dbo.usersOpenedArticle
        WHERE
            ISNULL(folder, '') = ''
            OR ISNULL(pdfLink, '') = ''
            OR ISNULL(issueTitle, '') = ''
    ) AS remainingRows;
