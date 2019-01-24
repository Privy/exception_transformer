require 'exception_transformer/version'
require 'exception_transformer/transformer'

require 'active_support'
require 'active_support/core_ext'

module ExceptionTransformer
  def self.included base
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module ClassMethods
    # Add exceptions to be transformed in `handle_exceptions` block.
    # @examples
    #   1. Transform several errors to a single error:
    #
    #        transform_exceptions FooError, BazError, to: BarError
    #
    #   2. Transform a single error based on it's message:
    #
    #        transform_exceptions FooError, where: {
    #          /Invalid API key/i => BarError,
    #          :default => RuntimeError
    #        }
    #
    #      To prevent *all* errors being caught via the `:default` branch,
    #      pass `use_default: false` to `handle_exceptions`.
    #
    #   3. Validate a response with a Proc that takes two parameters. The
    #      first parameter is the response, and the second is the calling method.
    #
    #         transform_exceptions validate: proc { |response, action| ... }
    #
    #   4. Inspect an error with a Proc that takes two parameters. The
    #      first parameter is the error, and the second is the calling method.
    #
    #         transform_exceptions with: proc { |err, action| ... }
    def transform_exceptions(*exceptions, group: :default, to: nil, where: nil, with: nil, validate: nil)
      strategies = { validate: validate, delegate: with, rewrite: to, regex: where }

      strategy = strategies.keys.find { |s| strategies[s].present? }
      target   = strategies[strategy]

      transformer = find_or_create_exception_transformer(group, strategy)
      transformer.register_target(target, exceptions)
    end

    def find_exception_transformer(group)
      exception_transformers[group]
    end

    def find_or_create_exception_transformer(group, strategy)
      exception_transformers[group] ||= Transformer.new(strategy)
    end

    private

    def exception_transformers
      @exception_transformers ||= {}
    end
  end

  module InstanceMethods
    def handle_exceptions(group = :default, **opts)
      # NOTE: `base_label` returns the label of this frame without decoration,
      # i.e. if `label` was 'block in test', then `base_label` would be `test`.
      calling_method = caller_locations(1, 1)[0].base_label
      transformer    = self.class.find_exception_transformer(group)

      result = yield

      transformer.after_yield(self, result, calling_method, opts)

      result
    rescue => e
      transformer.after_rescue(self, e, calling_method, opts)
    end
  end
end
