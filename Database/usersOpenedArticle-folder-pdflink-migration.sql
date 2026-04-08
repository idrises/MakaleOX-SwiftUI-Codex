/*
    usersOpenedArticle deterministic article history migration

    Goal:
    - Preserve article history refreshes without relying on a second MAKALE lookup.
    - Keep old records working through backfill plus app-side fallback.

    Safe to run multiple times:
    - Column adds are guarded with COL_LENGTH checks.
    - Backfill only fills blank values.
*/

SET NOCOUNT ON;

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

;WITH candidateMatches AS (
    SELECT
        ua.usermail,
        ua.Article,
        ua.Journal,
        ua.year,
        ua.volume,
        ua.[date],
        resolved.DONEM AS resolvedIssueTitle,
        resolved.KLASOR AS resolvedFolder,
        resolved.LINK AS resolvedPdfLink
    FROM dbo.usersOpenedArticle AS ua
    OUTER APPLY (
        SELECT TOP 1
            m.DONEM,
            m.KLASOR,
            m.LINK
        FROM dbo.MAKALE AS m
        WHERE m.MAKALE = ua.Article
          AND m.dergi = ua.Journal
        ORDER BY
            CASE
                WHEN ISNULL(ua.year, '') <> ''
                 AND m.YIL = ua.year THEN 0
                ELSE 1
            END,
            CASE
                WHEN ISNULL(ua.volume, '') <> ''
                 AND m.VOLUME = ua.volume THEN 0
                ELSE 1
            END,
            m.createDate DESC,
            m.YIL DESC,
            m.VOLUME DESC
    ) AS resolved
    WHERE
        ISNULL(ua.folder, '') = ''
        OR ISNULL(ua.pdfLink, '') = ''
        OR ISNULL(ua.issueTitle, '') = ''
)
UPDATE ua
SET
    ua.issueTitle = CASE
        WHEN ISNULL(ua.issueTitle, '') = '' THEN candidateMatches.resolvedIssueTitle
        ELSE ua.issueTitle
    END,
    ua.folder = CASE
        WHEN ISNULL(ua.folder, '') = '' THEN candidateMatches.resolvedFolder
        ELSE ua.folder
    END,
    ua.pdfLink = CASE
        WHEN ISNULL(ua.pdfLink, '') = '' THEN candidateMatches.resolvedPdfLink
        ELSE ua.pdfLink
    END
FROM dbo.usersOpenedArticle AS ua
INNER JOIN candidateMatches
    ON ua.usermail = candidateMatches.usermail
   AND ua.Article = candidateMatches.Article
   AND ua.Journal = candidateMatches.Journal
   AND ISNULL(ua.year, '') = ISNULL(candidateMatches.year, '')
   AND ISNULL(ua.volume, '') = ISNULL(candidateMatches.volume, '')
   AND ua.[date] = candidateMatches.[date];

SELECT
    COUNT(*) AS totalRows,
    SUM(CASE WHEN ISNULL(folder, '') <> '' THEN 1 ELSE 0 END) AS rowsWithFolder,
    SUM(CASE WHEN ISNULL(pdfLink, '') <> '' THEN 1 ELSE 0 END) AS rowsWithPdfLink,
    SUM(CASE WHEN ISNULL(issueTitle, '') <> '' THEN 1 ELSE 0 END) AS rowsWithIssueTitle
FROM dbo.usersOpenedArticle;
