class AddressesController < ApplicationController
  # Searching an unseen ZIP calls a third-party API; cap how fast one client can do it.
  rate_limit to: 10, within: 1.minute, only: :create, with: -> {
    render_search_error "Too many searches. Please wait a minute and try again.", :too_many_requests
  }

  def new
  end

  def create
    @address = AddressLookup.new.call(params[:postal_code])
    redirect_to @address, status: :see_other
  rescue AddressLookup::InvalidPostalCode
    render_search_error "Please enter a valid 5-digit US ZIP code.", :unprocessable_content
  rescue ApiClient::NotFoundError
    render_search_error "We couldn't find a US location for that ZIP code.", :unprocessable_content
  rescue ApiClient::Error => error
    Rails.error.report(error, handled: true, context: { postal_code: params[:postal_code] })
    render_search_error "Location lookup is temporarily unavailable. Please try again shortly.", :service_unavailable
  end

  def show
    @address = Address.find_by!(postal_code: params[:postal_code])
  end

  private

  def render_search_error(message, status)
    flash.now[:alert] = message
    render :new, status:
  end
end
