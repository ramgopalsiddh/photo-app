class RegistrationsController < Devise::RegistrationsController

  def create
    build_resource(sign_up_params)

    resource.class.transaction do
      resource.save
      yield resource if block_given?
      if resource.persisted?
        @user_payment = Payment.new(email: params["user"]["email"],
                                    token: params[:payment]["token"],
                                    user_id: resource.id)

        flash[:error] = "Please check registration errors" unless @user_payment.valid?

        begin
          # Use Payment Intents
          intent = Stripe::PaymentIntent.create(
            amount: 1000,
            currency: 'usd',
            description: 'Premium Membership',
            confirmation_method: 'automatic',
            # TODO : Add dynamic payment method this is fix at (visa credit card)
            payment_method: 'pm_card_visa'
          )

          # Client-side confirmation would happen here (using Stripe.js)

          # Capture payment after confirmation
          intent.capture if intent.status == 'succeeded'
          @user_payment.save!
        rescue Stripe::StripeError => e
          Rails.logger.error "Stripe Error: #{e.message}"
          flash[:error] = "Payment failed: #{e.message}"
          resource.destroy
          render :new and return
        rescue Exception => e
          Rails.logger.error "Payment Processing Error: #{e.message}"
          flash[:error] = "An unexpected error occurred during registration"
          resource.destroy
          render :new and return
        end

        if resource.active_for_authentication?
          set_flash_message :notice, :signed_up if is_flashing_format?
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end

    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up).push(:payment)
  end
end
