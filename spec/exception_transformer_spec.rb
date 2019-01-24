require 'exception_transformer'

describe ExceptionTransformer do
  class FooError < StandardError; end
  class BarError < StandardError; end

  class BazError < StandardError; end
  class QuxError < StandardError; end

  class ClassWithExceptionTransformer
    include ExceptionTransformer
  end

  def build_obj(&block)
    Class.new(ClassWithExceptionTransformer, &block).new
  end

  it 'returns the result if there are no errors' do
    obj = build_obj do
      transform_exceptions FooError, to: BarError
      def task; :task end
    end

    expect(obj.task).to be(:task)
  end

  it 'should preserve exception messages' do
    obj = build_obj do
      transform_exceptions FooError, to: BarError

      def task; handle_exceptions { raise FooError, 'oops' } end
    end

    expect{obj.task}.to raise_error(BarError, 'oops')
  end

  context 'when using :validate strategy' do
    it 'transforms exceptions' do
      obj = build_obj do
        transform_exceptions validate: proc { |res, action|
          unless res == :success
            fail FooError
          end
        }

        def task1; handle_exceptions { :success } end
        def task2; handle_exceptions { :failure } end
      end

      expect{obj.task1}.not_to raise_error
      expect{obj.task2}.to raise_error(FooError)
    end

    it 'executes the proc in instance context' do
      obj = build_obj do
        transform_exceptions validate: proc { |res, action|
          raise FooError unless @foo
        }

        def task1; handle_exceptions { @foo = :foo } end
        def task2; handle_exceptions { @foo = nil  } end
      end

      expect{obj.task1}.not_to raise_error
      expect{obj.task2}.to raise_error(FooError)
    end
  end

  context 'when using :delegate strategy' do
    it 'transforms exceptions' do
      obj = build_obj do
        transform_exceptions with: proc { |e, action|
          next unless e.is_a? FooError
          raise BazError
        }

        def task1; handle_exceptions { raise FooError } end
        def task2; handle_exceptions { raise BarError } end
      end

      expect{obj.task1}.to raise_error(BazError)
      expect{obj.task2}.to raise_error(BarError)
    end

    it 'executes the proc in instance context' do
      obj = build_obj do
        transform_exceptions with: proc { |err, action|
          if @foo
            raise FooError
          else
            raise BarError
          end
        }

        def task1
          handle_exceptions do
            @foo = :foo
            raise
          end
        end

        def task2
          handle_exceptions do
            @foo = nil
            raise
          end
        end
      end

      expect{obj.task1}.to raise_error(FooError)
      expect{obj.task2}.to raise_error(BarError)
    end

    it 'doesnt decorate the caller_location label' do
      obj = build_obj do
        transform_exceptions with: proc { |res, action|
          raise action
        }

        def task1
          handle_exceptions { raise }
        end

        def task2
          [:foo, :bar].each do |sym|
            handle_exceptions { raise }
          end
        end
      end

      expect{obj.task1}.to raise_error('task1')
      expect{obj.task2}.to raise_error('task2')
    end
  end

  it 'should limit exception messages to certain length' do
    obj = build_obj do
      transform_exceptions FooError, to: BarError

      def task; handle_exceptions { raise FooError, 'oops' * 50 } end
    end

    begin
      obj.task
    rescue BarError => e
      expect(e.message.length).to be <= ExceptionTransformer::Transformer::MAX_MESSAGE_SIZE
    end
  end

  context 'when using :rewrite strategy' do
    it 'transforms exceptions' do
      obj = build_obj do
        transform_exceptions FooError, to: BarError

        def task; handle_exceptions { raise FooError } end
      end

      expect{obj.task}.to raise_error(BarError)
    end

    it 'transforms exceptions by inheritance order' do
      obj = build_obj do
        transform_exceptions FooError, to: BarError
        transform_exceptions StandardError, to: QuxError

        def task1; handle_exceptions { raise FooError } end
        def task2; handle_exceptions { raise ArgumentError} end
      end

      expect{obj.task1}.to raise_error(BarError)
      expect{obj.task2}.to raise_error(QuxError)
    end

    it 'doesnt transform exceptions to be skipped' do
      obj = build_obj do
        transform_exceptions FooError, to: BarError

        def task; handle_exceptions(except: [FooError]) { raise FooError, 'oops' } end
      end

      expect{obj.task}.to raise_error(FooError)
    end
  end

  context 'when using :regex strategy' do
    it 'is able to transform exceptions' do
      obj = build_obj do
        transform_exceptions FooError, where: {
                               /oops/ => BarError,
                               :default  => StandardError
                             }

        def task1; handle_exceptions { raise FooError, 'oops' } end
        def task2; handle_exceptions { raise FooError } end
      end

      expect{obj.task1}.to raise_error(BarError)
      expect{obj.task2}.to raise_error(StandardError)
    end

    it 'should fallback to the default transformation unless specified' do
      obj = build_obj do
        transform_exceptions FooError, where: {
                               /oops/ => BarError,
                               :default  => StandardError
                             }

        def task1; handle_exceptions { raise FooError, 'oops' } end

        def task2
          handle_exceptions use_default: false do
            raise FooError
          end
        end
      end

      expect{obj.task1}.to raise_error(BarError)
      expect{obj.task2}.to raise_error(FooError)
    end

    it 'should keep the exception message if < 100 characters' do
      obj = build_obj do
        transform_exceptions FooError, where: {
          /oops/ => BarError,
          :default  => StandardError
        }

        def task1; handle_exceptions { raise FooError, 'oops it broke' } end
      end

      begin
        obj.task1
      rescue BarError => e
        expect(e.message).to eq('oops it broke')
      end
    end

    it 'should use a readable version of the regex if message > 100 characters' do
      obj = build_obj do
        transform_exceptions FooError, where: {
          /oops/ => BarError,
          :default  => StandardError
        }

        def task1; handle_exceptions { raise FooError, 'oops' + ((0..9).to_a.join * 10) } end
      end

      begin
        obj.task1
      rescue BarError => e
        expect(e.message).to eq('oops')
      end
    end
  end

  describe '::find_exception_transformer' do
    let!(:obj) do
      build_obj do
        transform_exceptions FooError, to: BarError, group: :a
        transform_exceptions FooError, to: BazError, group: :b
      end
    end

    it 'returns the transformer defined for the given group' do
      transformer = obj.class.find_exception_transformer(:a)

      expect(transformer).to be
      expect(transformer.mappings).to eq(FooError => BarError)
    end
  end

  describe '#handle_exceptions' do
    context 'when a group is provided' do
      let!(:obj) do
        build_obj do
          transform_exceptions FooError, to: BarError, group: :a
          transform_exceptions FooError, to: BazError, group: :b

          def task(group)
            handle_exceptions(group) { raise FooError }
          end
        end
      end

      it 'should use the transformer defined for the given group' do
        expect { obj.task(:a) }.to raise_error(BarError)
        expect { obj.task(:b) }.to raise_error(BazError)
      end
    end
  end
end
