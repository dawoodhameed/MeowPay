-- A short, typeable identifier for each cat.
--
-- Wallet ids are UUIDs: correct internally, unusable as something a person reads
-- off a screen and types into another device. Real transfer flows are built on a
-- short account number for exactly that reason, and having one lets the app ask
-- for a payee the way a banking app does rather than offering a picker.
--
-- Eight digits, unique. There is no cat-creation endpoint in this slice, so the
-- column is populated for the seeded cats and then made NOT NULL; anything that
-- creates a cat later has to supply one, which is the correct constraint.

ALTER TABLE cats ADD COLUMN account_number varchar(8);

UPDATE cats SET account_number = '10000001' WHERE id = '11111111-1111-4111-8111-111111111111';
UPDATE cats SET account_number = '10000002' WHERE id = '22222222-2222-4222-8222-222222222222';
UPDATE cats SET account_number = '10000003' WHERE id = '33333333-3333-4333-8333-333333333333';

ALTER TABLE cats ALTER COLUMN account_number SET NOT NULL;

-- Looking a payee up by account number is on the critical path of every send, so
-- it gets an index; unique because an account number that resolves to two cats
-- would let a sender confirm one payee and pay another.
CREATE UNIQUE INDEX cats_account_number_uq ON cats (account_number);
