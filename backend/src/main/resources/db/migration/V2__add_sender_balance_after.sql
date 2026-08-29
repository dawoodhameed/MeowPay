-- Records the sender's balance as it stood immediately after the transfer committed.
--
-- Without this the API cannot honour its own idempotency contract. A replay is
-- supposed to return the original response, but a balance read at replay time is
-- whatever the wallet holds *now* -- later transfers will have moved it. Storing
-- the figure at commit time makes a replay genuinely identical to the original
-- rather than approximately so.
--
-- It also removes a round trip from the send flow: the client updates its
-- displayed balance from the transfer response instead of re-fetching the wallet.
ALTER TABLE transfers
    ADD COLUMN sender_balance_after bigint NOT NULL;
