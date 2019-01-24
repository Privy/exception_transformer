module ClassHelpers
  # Defines a named class, descending from `super_class`.
  # The constant assigned to the the class will be restored
  # to it's original state when an example completes.
  #
  # @param name [Symbol, String] the constant name
  # @param super_class [Class] the class the return value inherits from
  # @yield [] block passed to `Class.new`
  # @return [Class]
  def build_class(name, super_class = Object, &block)
    stub_const(name.to_s, Class.new(super_class, &block))
  end
end
