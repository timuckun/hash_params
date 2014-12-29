require_relative 'spec_helper'


describe HashParams do
  let(:v) { HashParams}

  it 'raises error if required and missing' do
    proc {
      v.validate(nil, required: true)
    }.must_raise HashParams::ValidationError
  end
  it 'runs multiple coersions' do
    v.validate('1aaa2', coerce: [lambda { |o| o.gsub('a', '') }, :to_i, Float]).must_equal 12.0
  end

  it 'defaults missing values' do
    v.validate(nil, default: 1).must_equal 1
    v.validate(nil, default: lambda { |o| 2 * 5 }).must_equal 10
  end

  it 'applies defaults before other actions' do
    v.validate(nil, coerce: Integer, :default => 60 * 60, :validate => lambda { |v| v >= 60 * 60 }).must_equal 60 * 60
  end

  it 'validates with procs' do
    proc {
      v.validate('is_this_valid?') do |v|
        v == 'Failed_proc_validation'
      end
    }.must_raise HashParams::ValidationError
  end

  it 'verifies numbers with common params' do
    v.validate(122, min: 120, max: 500, in: (100..200), is: 122).must_equal 122
  end
  it 'verifies strings with common params' do
    v.validate('this is a test string', min_length: 21, max_length: 30, format: /^t.*g$/).must_equal 'this is a test string'
  end

  it 'coerces true' do
    v.coerce('t', :boolean).must_equal true
    v.coerce('true', :boolean).must_equal true
    v.coerce('yes', :boolean).must_equal true
    v.coerce('1',:boolean).must_equal true
    v.coerce(1,:boolean).must_equal true
  end
  it 'coerces false' do
    v.coerce('f', :boolean).must_equal false
    v.coerce('false', :boolean).must_equal false
    v.coerce('no', :boolean).must_equal false
    v.coerce('0',:boolean).must_equal false
    v.coerce(0,:boolean).must_equal false
  end
  it 'coerces array' do
   v.coerce('1|2|3', Array, delimiter: '|').must_equal ["1", "2", "3"]
  end
  it 'coerces hash' do
    v.coerce('{a => 1,b => 2,c => d}', Hash, delimiter: ',', separator: '=>').must_equal({"a" => "1", "b" => "2", "c" => "d"})
  end


end
