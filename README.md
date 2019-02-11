# exception-transformer
Add exceptions to be transformed in `handle_exceptions` block.

Battle-tested in production at [Privy](https://www.privy.com).

# Examples

1. Transform several errors to a single error:
  ```ruby
  transform_exceptions FooError, BazError, to: BarError
  ```

2. Transform a single error based on it's message:
  ```ruby
  transform_exceptions FooError, where: {
    /Invalid API key/i => BarError,
    :default => RuntimeError
  }
  ```
  To prevent *all* errors being caught via the `:default` branch,
  pass `use_default: false` to `handle_exceptions`.

3. Validate a response with a Proc that takes two parameters. The
first parameter is the response, and the second is the calling method.
  ```ruby
  transform_exceptions validate: proc { |response, action| ... }
  ```

4. Inspect an error with a Proc that takes two parameters. The
first parameter is the error, and the second is the calling method.
  ```ruby
  transform_exceptions with: proc { |err, action| ... }
  ```

# Crash Reporter
A crash reporter should be configured during the gem setup.
  ```ruby
  ExceptionTransformer.configure do |config|
    config.reporter = proc { |e| Raven.capture_exception(e) }
  end
  ```
