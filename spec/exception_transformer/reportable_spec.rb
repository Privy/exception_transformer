require 'exception_transformer/reportable'
require 'helpers/class_helpers'

describe ExceptionTransformer::Reportable do
  include ClassHelpers

  context 'when included' do
    context 'in a class that is not an Exception' do
      before(:each) { build_class :NotAnException }

      it 'raises TypeError' do
        expect { NotAnException.include ExceptionTransformer::Reportable }
          .to raise_error(TypeError)
      end
    end

    context 'in an Exception' do
      before(:each) { build_class :MyException, Exception }

      it 'it should extend it with class methods' do
        expect { MyException.include ExceptionTransformer::Reportable }
          .to change { MyException.singleton_class.ancestors }
          .to include(ExceptionTransformer::Reportable::ClassMethods)
      end
    end
  end

  shared_context :reportable, define_reportable: true do
    before(:each) do
      build_class :MyException, Exception do
        include ExceptionTransformer::Reportable
      end
    end

    after(:each) { MyException.unload_reportable }
  end

  describe '::as_reportable', define_reportable: true do
    it 'returns a subclass of ReportableException' do
      expect(MyException.as_reportable).to be < ExceptionTransformer::ReportableException
    end

    it 'is idempotent' do
      reportable_exception = MyException.as_reportable
      expect(reportable_exception).to equal(reportable_exception.as_reportable)
    end

    describe 'the return value' do
      it 'is a subclass of the caller' do
        expect(MyException.as_reportable).to be < MyException
      end

      it 'is a constant' do
        expect(MyException.as_reportable.name).not_to be_nil
      end

      context 'when raised' do
        it 'is reportable' do
          expect { raise MyException.as_reportable, 'oops!' }.to raise_error(be_reportable, 'oops!')
        end
      end
    end
  end

  describe '::unload_reportable', define_reportable: true do
    context 'when the reportable exception is defined' do
      it 'removes the constant' do
        reportable_exception = MyException.as_reportable
        MyException.unload_reportable
        expect(Object.const_defined?(reportable_exception.name)).to be false
      end

      it 'returns it' do
        reportable_exception = MyException.as_reportable
        expect(MyException.unload_reportable).to equal(reportable_exception)
      end
    end

    context 'when the reportable exception is not defined' do
      it 'returns nil' do
        expect(MyException.unload_reportable).to be_nil
      end
    end
  end

  describe '#reportable?', define_reportable: true do
    context 'when ReportableException is not included' do
      context 'when the exception is raised' do
        it 'is false' do
          # assert !MyException.include?(ExceptionTransformer::ReportableException)
          expect { raise MyException.new }.to raise_error do |e|
            expect(e).not_to be_reportable
          end
        end
      end
    end
  end

  describe '#mark_reportable!', define_reportable: true do
    it 'marks the exception as reportable' do
      exception = MyException.new
      expect { exception.mark_reportable! }
        .to change { exception.reportable? }.from(false).to(true)
    end
  end
end
