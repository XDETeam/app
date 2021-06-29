CREATE OR REPLACE FUNCTION mesh.node_view_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    __id bigint;
    __version integer;
BEGIN
    IF OLD.id != NEW.id THEN
        RAISE EXCEPTION 'Node IDs are read-only';
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO
            mess.node(id, url, content, version)
        VALUES
           (DEFAULT, NEW.url, NEW.content, DEFAULT)
       RETURNING
            id, version INTO __id, __version
       ;

        INSERT INTO mess.log
            (id, version, author, url, content)
        VALUES
            (__id, __version, mesh.session_get(), NEW.url, NEW.content)
        ;

        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.version != OLD.version THEN
            RAISE EXCEPTION 'Version conflict. You are attempting to update node "%" with version %, but the actual version is %', NEW.url, NEW.version, OLD.version;
        END IF;

        UPDATE
            mess.node
        SET
            url = NEW.url,
            content = NEW.content
        WHERE
            id = OLD.id
        ;

        INSERT INTO mess.log
            (id, version, author, url, content)
        VALUES
            (OLD.id, NEW.version + 1, mesh.session_get(), NEW.url, NEW.content)
        ;

        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        --TODO:Should we implement version validation as it is for UPDATE?

        DELETE
        FROM
             mess.node
        WHERE
            id = OLD.id
        RETURNING
            version INTO __version
        ;

        RAISE NOTICE 'DELETE OLD:% NEW:% V:%', OLD.id, NEW.id, __version;

        INSERT INTO mess.log
            (id, version, author, url, content)
        VALUES
            (OLD.id, __version + 1, mesh.session_get(), OLD.url, NULL)
        ;

        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$;
