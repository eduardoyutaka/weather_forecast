# Rendered inside a lazy-loaded <turbo-frame> on the address page, so a slow or
# failing weather API never blocks or breaks the rest of the page.
class ForecastsController < ApplicationController
  before_action :set_address

  rescue_from ApiClient::Error, with: :render_unavailable

  def show
    @result = ForecastService.new.call(@address)
  end

  private

  def set_address
    @address = Address.find_by!(postal_code: params[:address_postal_code])
  end

  def render_unavailable(error)
    Rails.error.report(error, handled: true, context: { postal_code: @address.postal_code })
    response.set_header("Retry-After", error.retry_after.to_s) if error.try(:retry_after)
    render :unavailable, status: :service_unavailable
  end
end
