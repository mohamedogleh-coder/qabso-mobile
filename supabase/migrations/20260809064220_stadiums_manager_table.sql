CREATE TABLE stadium_managers
(
    stadium_id uuid REFERENCES stadiums (id) ON DELETE CASCADE,
    user_id    uuid REFERENCES app_users (id) ON DELETE CASCADE,
    PRIMARY KEY (stadium_id, user_id)
);