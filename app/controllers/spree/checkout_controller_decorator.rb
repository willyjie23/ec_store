# frozen_string_literal: true

Spree::CheckoutController.class_eval do
  before_action :adjust_params, only: :update
  before_action :fetch_allowed_shipping_methods, only: %i[edit update]

  def update
    binding.pry
    if @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
      @order.temporary_address = !params[:save_user_address]
      unless @order.next
        flash[:error] = @order.errors.full_messages.join("\n")
        redirect_to(checkout_state_path(@order.state)) && return
      end

      @order.update(state: 'payment', completed_at: nil) if @order.payment_method.blank?
      if @order.completed?
        flash.notice = Spree.t(:order_processed_successfully)
        flash['order_completed'] = true
        redirect_to completion_route
      else
        redirect_to checkout_state_path(@order.reload.state)
      end
    else
      render :edit
    end
  end

  def edit
    adjust_address
  end

  private

  def fetch_allowed_shipping_methods
    @allowed_shipping_categories = @order.products.map(&:shipping_category).map(&:shipping_methods).flatten.uniq
    @shipping_method = Spree::ShippingMethod.find_by(admin_name: 'home')
  end

  def before_payment
    packages = @order.shipments.map(&:to_package)
    @differentiator = Spree::Stock::Differentiator.new(@order, packages)
    @differentiator.missing.each do |variant, quantity|
      @order.contents.remove(variant, quantity)
    end

    return unless try_spree_current_user
    return unless try_spree_current_user.respond_to?(:payment_sources)

    @payment_sources = try_spree_current_user.payment_sources
  end

  def save_data_to_user
    @order.user.update(name: @order.bill_address.firstname)
  end

  def adjust_address
    return unless @order.state == 'address'

    set_default_address
    update_address
  end

  def set_default_address
    @order.billing_address ||= Spree::Address.new
    address = @order.billing_address
    address.update(arrival_date: nil)
    address.city = '-'
    address.country = Spree::Country.default
  end

  def update_address
    return unless params.has_key?(:billing_address)

    address = @order.billing_address
    address.assign_attributes(billing_address_params)
    address.auto_fill_zipcode
  end

  def billing_address_params
    params.require(:billing_address).permit(:shipping_method_id, :cvs_store_id, :cvs_store_name, :address1, :arrival_date)
  end

  def adjust_params
    return unless @order.state == 'address'

    zipcode = ZipcodeService
              .get_zipcode(full_address_from_params).presence || '000'
    params[:order][:bill_address_attributes][:zipcode] = zipcode
  end

  def full_address_from_params
    address1 = params[:order][:bill_address_attributes][:address1] || ''
    address2 = params[:order][:bill_address_attributes][:address2] || ''
    address1 + address2
  end
end
