# frozen_string_literal: true

class ExceptionTransformer::Config
  attr_accessor :reporter

  def initialize
    self.reporter ||= proc { |e| }
  end
end
