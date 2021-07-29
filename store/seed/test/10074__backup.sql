
-- Backup for database 7008 blog
INSERT INTO
    backup (
        creator_id,
        created_ts,
        updater_id,
        updated_ts,
        database_id,
        name,
        `status`,
        `type`,
        storage_backend,
        path,
        `comment`
    )
VALUES
    (
        101,
        1624558090,
        101,
        1624558090,
        7008,
        'blog-backup-1',
        'DONE',
        'MANUAL',
        'LOCAL',
        '/tmp/blog-backup-1.sql',
        'The first backup'
    );