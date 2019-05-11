# frozen_string_literal: true

module ExceptionTransformer
  # Include this module when declaring an exception class to add
  # the `reportable?` flag to individual exceptions. The presence
  # of this flag can then be checked when capturing exceptions to
  # send to a crash reporter.
  #
  # @example Conditionally reporting exceptions
  #   class MyError < StandardError
  #     include ExceptionTransformer::ReportableException
  #   end
  #
  #   begin
  #     # do something that may fail
  #   rescue MyError => e
  #     CrashReport.new(e) if e.reportable?
  #   end
  #
  # This flag can be set at the instance level with `mark_reportable!`.
  # Alternatively, the class method `as_reportable` returns a subclass
  # for which `reportable?` is true when raised.
  module Reportable
    def self.included(base)
      raise TypeError, "#{base} is not a type of Exception" unless base <= Exception
      base.extend ClassMethods
    end

    module ClassMethods
      # Returns a subclass 'Reportable_<name>' of the current class that
      # includes `Reportable`. This subclass is created the first time
      # this method is called and reused for subsequent invocations.
      def as_reportable
        return self if self <= ReportableException

        name = reportable_name
        mod = self.respond_to?(:module_parent) ? module_parent : parent

        mod.const_defined?(name) ? mod.const_get(name) : mod.const_set(name, build_reportable)
      end

      def unload_reportable
        name = reportable_name
        mod = self.respond_to?(:module_parent) ? module_parent : parent

        mod.send(:remove_const, name) if mod.const_defined?(name)
      end

      def reported_class
        @reported_class ||= self
      end

      def reported_class=(klass)
        @reported_class = klass
      end

      private

      def build_reportable
        super_class = self
        Class.new(super_class) do
          include ReportableException
          self.reported_class = super_class
        end
      end

      def reportable_name
        [ReportableException.name, self.name].map(&:demodulize).join("_")
      end
    end

    def reportable?
      @reportable ||= false
    end

    def mark_reportable!
      @reportable = true
    end
  end

  # Every `Reportable` that includes `ReportableException` will be
  # raised with the `reportable?` flag set to true.
  module ReportableException
    def self.included(base)
      base.include(Reportable) unless base <= Reportable
      base.extend ClassMethods
    end

    module ClassMethods
      def exception(*args)
        if reported_class == self
          super.tap(&:mark_reportable!)
        else
          reported_class.exception(*args).tap(&:mark_reportable!)
        end
      end
    end

    def exception(*args)
      mark_reportable!
      super
    end
  end
end
