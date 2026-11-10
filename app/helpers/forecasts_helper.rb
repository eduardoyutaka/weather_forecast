module ForecastsHelper
  def fahrenheit(degrees)
    "#{degrees.round}°F"
  end

  def cache_status_badge(result)
    if result.cached?
      tag.span "Cached", class: "badge badge--cached", title: "Served from cache (refreshed at most every #{ForecastService::CACHE_TTL.inspect})"
    else
      tag.span "Live", class: "badge badge--live", title: "Fetched from the weather provider just now"
    end
  end
end
