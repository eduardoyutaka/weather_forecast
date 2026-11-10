# The test environment uses :null_store so tests can't leak state through the
# cache. Tests that exercise caching swap in a real, empty store.
module CacheHelpers
  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
