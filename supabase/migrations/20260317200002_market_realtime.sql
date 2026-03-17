-- Enable realtime for marketplace tables
ALTER PUBLICATION supabase_realtime ADD TABLE transfer_market;
ALTER PUBLICATION supabase_realtime ADD TABLE market_bids;
