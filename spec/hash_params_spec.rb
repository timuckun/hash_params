require_relative 'spec_helper'


describe HashParams do
  let(:v) { HashParams }

  it 'raises error if required and missing' do
    proc {
      v.validate(nil, nil, required: true)
    }.must_raise HashParams::Validator::ValidationError
  end
  it 'runs multiple coersions' do
    v.validate('1aaa2', Float, coerce: [lambda { |o| o.gsub('a', '') }, :to_i]).must_equal(12.0)
  end

  it 'defaults missing values' do
    v.validate(nil, Integer, default: 1).must_equal(1)
    v.validate(nil, Integer, default: lambda { 2 * 5 }).must_equal(10)
  end

  it 'validates with lambdas' do
    v.validate(nil, Integer, :validate => lambda { |v| v = 60 * 60 }).must_equal(60 * 60)
  end

  it 'validates with procs' do
    v.validate('is_this_valid?', String) do |v|
      v = 'Validated with Proc'
    end.must_equal('Validated with Proc')
  end

  it 'verifies numbers with common params' do
    v.validate(122, Integer, min: 120, max: 500, in: (100..200), is: 122).must_equal(122)
  end

  it 'verifies strings with common params' do
    v.validate('this is a test string', String, min_length: 21, max_length: 30, format: /^t.*g$/).must_equal 'this is a test string'
  end

  it 'coerces true' do
    v.validate('t', :boolean).must_equal true
    v.validate('true', :boolean).must_equal true
    v.validate('yes', :boolean).must_equal true
    v.validate('1', :boolean).must_equal true
    v.validate(1, :boolean).must_equal true
  end

  it 'coerces false' do
    v.validate('f', :boolean).must_equal false
    v.validate('false', :boolean).must_equal false
    v.validate('no', :boolean).must_equal false
    v.validate('0', :boolean).must_equal false
    v.validate(0, :boolean).must_equal false
  end


  it 'coerces array' do
    v.validate('1|2|3', Array, delimiter: '|').must_equal ["1", "2", "3"]
  end

  it 'coerces hash' do
    v.validate('{a => 1,b => 2,c => d}', Hash, delimiter: ',', separator: '=>').must_equal({"a" => "1", "b" => "2", "c" => "d"})
  end

  it 'validates a hash using a block' do
    h = {
        ignored:           "this will be ignored because it's not mentioned",
        to_be_renamed:     :renamed_value,
        'integer_coercion': "1",
        proc_validation:   "is_this_valid?",
        recursive:         {}
    }
    r = v.validate(h, Hash, symbolize_keys: true) do
      key :doesnt_exist, nil, required: true
      key :to_be_renamed, Symbol, as: :renamed
      #Default Lambdas take no parameters
      key :proc_default, Integer, default: lambda { 1 * 5 }
      key :proc_validation, String, validate: lambda { |v| v = 'Validated in proc' }
      #recursive
      key :recursive, Hash do
        key :wasnt_here_before, :boolean, default: true
      end
    end

    (r.valid?).must_equal false
    r[:ignored].must_be_nil
    # r[:proc_default].must_equal 5
    r[:renamed].must_equal :renamed_value
    #recursive checking
    r[:recursive][:wasnt_here_before].must_equal true

    #failed items don't show up
    r[:doesnt_exist].must_be_nil
    r[:proc_validation].must_equal 'Validated in proc'

    r.validation_errors.size.must_equal 1
    r.validation_errors[0].must_equal "Error processing key 'doesnt_exist': Required Parameter missing and has no default specified"

  end

  it 'validates variables in the local binding' do

    x='10'
    y='this is a test string'
    z={}
    will_be_int='100'

    HashParams.with_binding do
      var :x, Integer, min: 10, max: 100
      var :y, String, min_length: 21, max_length: 30, format: /^t.*g$/
      var :z, Hash, raise_errors: true, symbolize_keys: true, make_methods: true do
        key :blah, String, default: 1
      end
      var :will_be_int, :to_i
    end
    x.must_equal 10
    y.must_equal 'this is a test string'
    z[:blah].must_equal '1'
    z.blah.must_equal '1'
    will_be_int.must_equal 100
  end


end
