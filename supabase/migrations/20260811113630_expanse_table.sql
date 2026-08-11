CREATE TABLE expenses
(
    id           serial primary key,
    expense_type varchar(10)    not null default
                                             'expense' CHECK ( expense_type in ('salary', 'expense', 'other') ),
    stadium_id   uuid           not null references stadiums (id) on delete cascade,
    description  varchar(100),
    expense_date DATE           not null
);

