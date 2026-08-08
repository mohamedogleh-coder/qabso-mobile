CREATE TYPE public.user_role AS ENUM (
    'manager',
    'referee',
    'user'
);

CREATE TABLE public.app_users
(
    id           uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name    varchar(100),
    phone_number varchar(20) UNIQUE,
    photo_url    text,
    role public.user_role NOT NULL DEFAULT 'user',
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);