# frozen_string_literal: true

module Spree
  class PaymentMethod
    class LinePay < PaymentMethod
      preference :line_id, :string
      preference :line_secret, :string
      preference :test_mode, :boolean

      def self.payment_subtype
        self.const_get('LinePay')
      end

      def actions
        %w[void]
      end

      # # Indicates whether its possible to capture the payment
      def can_capture?(payment)
        %w[checkout pending].include?(payment.state)
      end

      def payment_source_class
        EcpayPaymentInfo
      end

      # # Indicates whether its possible to void the payment.
      def can_void?(payment)
        payment.state != 'void'
      end

      def authorize(_amount_in_cent, source, _gateway_options)
        is_success = source&.return_code == '2'
        message = source&.return_message || ''
        params = source&.info_payload || {}

        ActiveMerchant::Billing::Response.new(
          is_success, message, params, response_options(params)
        )
      end

      def cancel(*args)
        simulated_successful_billing_response
      end

      def void(*args)
        simulated_successful_billing_response
      end

      private

      def options_for_capture(gateway_options)
        _, payment_id = gateway_options[:order_id].split('-')
        payment = Spree::Payment.find_by(number: payment_id)
        source = payment&.source
        params = source&.paid_payload
        [payment, source, params]
      end

      def response_message(amount_in_cent, payment, source, params)
        is_success = source&.return_code == '1'
        message = source&.return_message || ''
        # 確認 payment 的 method 是 EcpayBase 的 subclass
        message = '付款方式不正確' unless payment.payment_method.is_a?(Spree::PaymentMethod::EcpayBase)

        # 確認交易金額正確
        message = '交易金額不正確' if amount_in_cent != params['TradeAmt'].to_i * 100

        is_success = false if message != source&.return_message
        [is_success, message]
      end

      def simulated_successful_billing_response
        ActiveMerchant::Billing::Response.new(true, '', {}, {})
      end

      def response_options(params)
        {
          simulate_paid: params['SimulatePaid'].to_i == 1
        }
      end
    end
  end
end
