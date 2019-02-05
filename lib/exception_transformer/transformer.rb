# frozen_string_literal: true

class ExceptionTransformer::Transformer
  attr_accessor :strategy, :validator, :delegate, :mappings

  MAX_MESSAGE_SIZE = 100

  def initialize(strategy)
    self.strategy = strategy
    self.mappings = {}
  end

  def register_target(target, exceptions)
    case strategy
    when :validate
      self.validator = target
    when :delegate
      self.delegate  = target
    when :rewrite, :regex
      exceptions.each do |klass|
        self.mappings[klass] = target
      end
    end
  end

  def after_rescue(obj, e, calling_method, except: [], use_default: true, opts: {})
    with_reporting do
      case strategy
      when :delegate
        obj.instance_exec(e, calling_method, opts, &delegate)
      when :rewrite, :regex
        exception, message = find_target(e, except, use_default)
      end

      if exception.present?
        raise exception, message.first(MAX_MESSAGE_SIZE), e.backtrace
      else
        # Couldn't transform the exception to a defined mapping.
        raise e
      end
    end
  end

  def after_yield(obj, result, calling_method, except: [], use_default: true, opts: {})
    with_reporting do
      case strategy
      when :validate
        obj.instance_exec(result, calling_method, opts, &validator)
      end
    end
  end

  private

  # @return [Array] `[exception, message]`
  def find_target(e, exclude, use_default_match)
    case strategy
    when :rewrite
      exception = find_mapping(e, exclude)
      message   = e.message
    when :regex
      patterns  = find_mapping(e, exclude) || {}

      pattern = patterns.keys.find { |re| re.is_a?(Regexp) && e.message =~ re }
      pattern ||= :default if use_default_match

      exception = patterns[pattern]
      message   = e.message.length <= MAX_MESSAGE_SIZE ? e.message : pattern.inspect.gsub(/([^\w\s]|i\z)*/, '')
    end

    [exception, message]
  end

  # @return [StandardError, Hash]
  def find_mapping(e, exclude)
    mappings
      .select  { |klass| e.is_a?(klass) && !exclude.include?(klass) }
      .sort_by { |klass, _| klass.ancestors.count }
      .last.try(:[], 1)
  end

  # Report all exceptions that occur except those
  # with the `reportable?` flag set to false.
  def with_reporting
    yield
  rescue => e
    unless e.respond_to?(:reportable?) && !e.reportable?
      ExceptionTransformer.config.reporter
    end

    raise
  end
end
