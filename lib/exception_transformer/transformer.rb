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

  def after_rescue(obj, e, calling_method, except: [], use_default: true, report: true)
    case strategy
    when :delegate
      obj.instance_exec(e, calling_method, &delegate)
    when :rewrite, :regex
      exception, message = find_target(e, except, use_default)
    else
      raise
    end

    if exception.present?
      if defined?(Raven) && report
        # Create an instance of the exception to send to Sentry. We can't
        # use `Raven.capture do ... end` because we want to report the full message.
        inst_to_report = exception.new(e.message)
        inst_to_report.set_backtrace(e.backtrace)
        Raven.capture_exception(inst_to_report)
      end

      raise exception, message.first(MAX_MESSAGE_SIZE), e.backtrace
    else
      # We couldn't transform the exception, so this should be sent to Sentry
      # unless otherwise caught.
      raise
    end
  end

  def after_yield(obj, result, calling_method, except: [], use_default: true, report: true)
    case strategy
    when :validate
      obj.instance_exec(result, calling_method, &validator)
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
end
