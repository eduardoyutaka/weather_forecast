# Immutable snapshot of the weather at a location. Lives only in Rails.cache:
# forecasts expire after 30 minutes, so persisting them to the database would
# only add write load and a table that needs pruning.
Forecast = Data.define(:temperature, :temperature_min, :temperature_max, :description, :observed_at, :fetched_at)
