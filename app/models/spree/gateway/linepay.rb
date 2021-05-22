# frozen_string_literal: true

module Spree
  class Gateway
    class Linepay < Gateway
      preference :line_id, :string
      preference :line_secret, :string
      preference :test_mode, :boolean

      def method_type
        'linepay'
      end

      def provider_class
        ActiveMerchant::Billing::LinepayGateway
      end

      def payment_source_class
        Check
      end

      def refundable?
        true
      end

      def purchase(amount_in_cents, prime_or_token, gateway_options)
        params = options_for_purchase(
          amount_in_cents, prime_or_token, gateway_options
        )
        provider.purchase(*params)
      end

      def authorize(amount_in_cents, prime_or_token, gateway_options)
        params = options_for_auth(
          amount_in_cents, prime_or_token, gateway_options
        )
        provider.authorize(*params)
      end

      delegate :capture, to: :provider

      # partial refund
      def credit(amount_in_cents, response_code, _gateway_options)
        amount = dollars(amount_in_cents)
        provider.refund(amount, response_code, {})
      end

      def void(response_code, _gateway_options)
        provider.void(response_code, {})
      end

      def cancel(response_code)
        provider.void(response_code, {})
      end

      private

      def options_for_purchase(amount_in_cents, creditcard, gateway_options)
        options_for_auth(amount_in_cents, creditcard, gateway_options)
      end

      def options_for_auth(amount_in_cents, creditcard, gateway_options)
        options = {}
        options[:description] = "Spree Order ID: #{gateway_options[:order_id]}"
        options[:currency] = gateway_options[:currency]
        options[:cardholder] = cardholder(gateway_options)

        customer = creditcard.gateway_customer_profile_id
        options[:customer] = customer if customer
        token_or_card_id = creditcard.gateway_payment_profile_id
        creditcard = token_or_card_id if token_or_card_id
        options[:order_number] = gateway_options[:order_id]
        options[:bank_transaction_id] = gateway_options[:bank_transaction_id]
        [dollars(amount_in_cents), creditcard, options]
      end

      def cardholder(gateway_options)
        address = gateway_options[:billing_address]
        address_key = %i[address1 address2 city state country]
        {
          phone_number: address[:phone],
          name: address[:name],
          email: gateway_options[:email],
          zip_code: address[:zip],
          address: address.values_at(*address_key).join(', ')
        }
      end

      def dollars(amount_in_cents)
        (amount_in_cents / 100.0.to_d).to_i
      end
    end
  end
end
