require_relative 'spec_helper'


describe HashParamsNew::Validator do
  let(:v) { HashParamsNew::Validator }
  # let (:r) {
  #   HashParamsClass.new(
  #       {
  #           ignored:          "this will be ignored because it's not mentioned",
  #           to_be_renamed:    :to_be_renamed,
  #           integer_coercion: "1",
  #           bad_number:       '1aaa2',
  #           array_with_delim: '1|2|3',
  #           hash_as_string:   "{a => 1,b => 2,c => d}",
  #           proc_validation:  "is_this_valid?",
  #           some_number:      122,
  #           some_string:      'this is a test string',
  #           is_true:          'true',
  #           is_false:         'f',
  #           recursive:        {}
  #       }
  #   ) do
  #     param :doesnt_exist, required: true
  #     param :to_be_renamed, as: :renamed
  #     param :no_value, default: 1
  #     #proc default relying on previously set value
  #     param :proc_default, default: lambda { |o| o[:no_value] * 5 }
  #     param :integer_coercion, coerce: Integer
  #     #chained coersions of various types
  #
  #     #arrays and hashes
  #     param :array_with_delim, coerce: Array, delimiter: '|'
  #     param :hash_as_string, coerce: Hash, delimiter: ',', separator: '=>'
  #     param :proc_validation, validate: lambda { |v| v == 'Failed_proc_validation' }
  #     #validations
  #     param :some_number, min: 120, max: 500, in: (100..200), is: 122
  #     param :some_string, min_length: 21, max_length: 30, format: /^t.*g$/
  #     #combinations
  #
  #     param :is_true, coerce: :boolean
  #     param :is_false, coerce: :boolean
  #     #recursive
  #     param :recursive do
  #       param :wasnt_here_before, default: true
  #     end
  #   end
  # }

  it 'raises error if required and missing' do
    proc {
      v.validate(nil, required: true)
    }.must_raise HashParamsNew::ValidationError
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
    }.must_raise HashParamsNew::ValidationError
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
  #   if r[:proc_validation].must_be_nil
  #
  #     r[:integer_coercion].must_equal 1
  #   r[:bad_number].must_equal 12.0
  #  it
  #   r[:array_with_delim].must_equal ["1", "2", "3"]
  #   r[:hash_as_string].must_equal ({"a" => "1", "b" => "2", "c" => "d"})
  #   r[:missing_with_validation].must_equal 60 * 60
  #   r[:is_true].must_equal true
  #   r[:is_false].must_equal false
  #
  #   #recursive checking
  #   r[:recursive][:wasnt_here_before].must_equal true
  #
  #   #failed items don't show up
  #   r.errors.size.must_equal 2
  #   r[:doesnt_exist].must_be_nil
  #
  #   r.errors[0].must_equal 'Parameter doesnt_exist is required and missing'
  #   r.errors[1].must_equal 'is_this_valid? failed validation using proc'
  #
  # end

  # it 'injects into current class' do
  #   r = HashParamsClass.new({will_be_injected: 12345}, self) do
  #     param :will_be_injected
  #   end
  #   r[:will_be_injected].must_equal 12345
  #   @will_be_injected.must_equal 12345
  #   will_be_injected.must_equal 12345
  # end

end
