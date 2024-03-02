class Payment < ApplicationRecord
  attr_accessor :card_number, :card_cvc, :card_expires_month, :card_expires_year
  belongs_to :user

  def self.month_options
    Date::MONTHNAMES.compact.each_with_index.map { |name, i| ["#{i+1} - #{name}", i+1]}
  end

  def self.year_options
    (Date.today.year..(Date.today.year+10)).to_a
  end

  def process_payment(description:)
    raise ArgumentError, "Description is required for processing payment" unless description.present?

    token = create_stripe_token

    customer = Stripe::Customer.retrieve(user.stripe_customer_id)
    customer.sources.create(source: token.id)

    create_stripe_charge(customer, description: description)

    true
  rescue Stripe::StripeError => e
    errors.add(:base, e.message)
    false
  rescue ArgumentError => e
    errors.add(:base, e.message)
    false
  end

  private

  def create_stripe_token
    Stripe::Token.create({
      card: {
        number: card_number,
        exp_month: card_expires_month,
        exp_year: card_expires_year,
        cvc: card_cvc
      }
    })
  end

  def create_stripe_charge(customer, description:)
    Stripe::Charge.create({
      amount: 1000,
      currency: 'usd',
      description: description,
      customer: customer.id
    })
  end
end
