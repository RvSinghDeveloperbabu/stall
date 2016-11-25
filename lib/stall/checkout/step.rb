module Stall
  module Checkout
    class StepNotFoundError < StandardError; end

    class Step
      class_attribute :_validations

      attr_reader :cart

      def initialize(cart)
        @cart = cart
      end

      # Allow injecting dependencies on step initialization and accessing
      # them as instance method in subclasses
      def inject(method, content)
        define_singleton_method(method, -> { content })
      end

      # Allows for preparing to the cart for the current step before rendering
      # the step's view
      #
      # Note : Meant to be overriden by subclasses
      #
      def prepare
      end

      def process
        save
      end

      def skip?
        false
      end

      def is?(key)
        identifier == key
      end

      def identifier
        @identifier ||= begin
          class_name = self.class.name.demodulize
          class_name.gsub(/CheckoutStep$/, '').underscore.to_sym
        end
      end

      # Allows subclasses to override this value with `true` to allow paid carts
      # to be processed by that step too.
      #
      # Returning false redirects the user telling him that his cart is empty
      #
      # By default, the `PaymentReturn` checkout step returns true, since it's
      # always called after the cart is paid
      #
      def allow_inactive_carts?
        false
      end

      # Run cart validations then step validations, and cart validations, returning wether they're both valid or
      # not, allowing to display all involved errors to the visitor in one time
      #
      def valid?
        cart.validate
        run_step_validations!(clear:  false)

        cart.errors.empty?
      end

      # Abstracts the simple case of assigning the submitted parameters to the
      # cart object, running the step validations and saving the cart
      def save
        cart.assign_attributes(cart_params)
        cart.save if valid?
      end

      private

      def run_step_validations!(clear: true)
        if (validations = self.class.validations)
          validations.new(cart, self, clear: clear).validate
        end
      end

      # Handles conversion from an identifier to a checkout step class, allowing
      # us to specify a list of symbols in our wizard's .step macro
      #
      def self.for(identifier)
        name = identifier.to_s.camelize
        step_name = [name, 'CheckoutStep'].join
        # Try loading step from app
        step = Stall::Utils.try_load_constant(step_name)
        # Try loading step from stall core or lib if not found in app
        step = Stall::Utils.try_load_constant(
          ['Stall', 'Checkout', step_name.demodulize].join('::')
        ) unless step

        unless step
          raise StepNotFoundError,
            "No checkout step was found for #{ identifier }. You can generate " +
            "it with `rails g stall:checkout:step #{ identifier }`"
        end

        step
      end

      def self.validations(&block)
        return _validations unless block
        self._validations = Stall::Checkout::StepForm.build(&block)
      end
    end
  end
end
