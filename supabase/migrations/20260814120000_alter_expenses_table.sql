ALTER TABLE public.expenses
    ADD COLUMN expense_total NUMERIC(12, 2) NOT NULL CHECK (expense_total > 0);

COMMENT ON COLUMN public.expenses.expense_total IS
    'How much the stadium paid out for this expense.';
