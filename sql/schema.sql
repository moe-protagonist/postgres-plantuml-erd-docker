BEGIN;

CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DO $$BEGIN
CREATE TYPE hub_status AS ENUM ('canonical', 'provisional', 'approved');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS users (
  id    UUID PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
  email VARCHAR UNIQUE NOT NULL, CHECK (email <> ''),

  is_active    BOOLEAN DEFAULT true  NOT NULL,

  first_name   VARCHAR NOT NULL, CHECK (first_name <> ''),
  last_name    VARCHAR NOT NULL, CHECK (last_name  <> ''),
  purpose      VARCHAR(200),
  photo        VARCHAR,
  location     POINT NOT NULL,

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);


DROP TRIGGER IF EXISTS update_users_updated_at ON users;

CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

DO $$BEGIN
CREATE TYPE user_role AS ENUM ('user-admin', 'user-curator');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id    UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    role       user_role NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, role)
);

CREATE TABLE IF NOT EXISTS networks(
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
  name        citext UNIQUE NOT NULL, CHECK (name <> ''),
  purpose     VARCHAR(200)  NOT NULL, CHECK (purpose <> ''),

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS update_networks_updated_at ON networks;

CREATE TRIGGER update_networks_updated_at
BEFORE UPDATE ON networks
FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

DO $$BEGIN
CREATE TYPE group_visibility AS ENUM ('public', 'private', 'invisible');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS groups(
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
  name        citext UNIQUE NOT NULL, CHECK (name  <> ''),
  purpose     VARCHAR(200)  NOT NULL, CHECK (purpose <> ''),
  network_id  UUID REFERENCES networks(id) NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  visibility  group_visibility NOT NULL DEFAULT 'public',

  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS groups_visibility_idx ON groups(visibility);
CREATE INDEX IF NOT EXISTS groups_network_idx    ON groups(network_id);

DROP TRIGGER IF EXISTS update_groups_updated_at ON groups;

CREATE TRIGGER update_groups_updated_at
BEFORE UPDATE ON groups
FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

DO $$BEGIN
CREATE TYPE network_role AS ENUM ('network-host', 'network-member');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS networks__users (
  network_id UUID REFERENCES networks(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES users(id)    ON DELETE CASCADE NOT NULL,
  role       network_role NOT NULL DEFAULT 'network-member',
  joined_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (network_id, user_id)
);

CREATE INDEX IF NOT EXISTS networks__users_role_idx ON networks__users(role);

DO $$BEGIN
CREATE TYPE group_role AS ENUM ('group-lead', 'group-host', 'group-member', 'group-invitee');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS groups__users(
  group_id   UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES users(id)  ON DELETE CASCADE NOT NULL,
  role       group_role NOT NULL DEFAULT 'group-member',
  joined_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS groups__users_role_idx ON groups__users(role);

CREATE TABLE IF NOT EXISTS groups__users_applications(
  group_id    UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  user_id     UUID REFERENCES users(id)  ON DELETE CASCADE NOT NULL,
  applied_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (group_id, user_id)
);

DO $$BEGIN
CREATE TYPE event_visibility AS ENUM ('public');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END$$;

CREATE TABLE IF NOT EXISTS events (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
  network_id   UUID REFERENCES networks(id) ON DELETE CASCADE NOT NULL,
  group_id     UUID references groups(id)   ON DELETE CASCADE,
  name         VARCHAR(60) NOT NULL, CHECK (name <> ''),
  description  VARCHAR,
  datetime     TIMESTAMP WITH TIME ZONE NOT NULL,
  duration     INTERVAL,
  visibility   event_visibility DEFAULT 'public' NOT NULL,
  created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS update_events_updated_at ON events;

COMMIT;
