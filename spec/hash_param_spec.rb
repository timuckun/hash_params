require_relative 'spec_helper'


describe HashParams do

  let (:r) {
    HashParams.new(
        {
            ignored: "this will be ignored because it's not mentioned",
            to_be_renamed:    :to_be_renamed,
            integer_coercion: "1",
            bad_number:       '1aaa2',
            array_with_delim: '1|2|3',
            proc_validation:  "is_this_valid?",
            some_number:      122,
            some_string:      'this is a test string'
        }
    ) do
      param :doesnt_exist, required: true
      param :to_be_renamed, as: :renamed
      param :no_value, default: 1
      #proc default relying on previously set value
      param :proc_default, default: lambda { |o| o[:no_value] * 5 }
      param :integer_coercion, coerce: Integer
      #chained coersions of various types
      param :bad_number, coerce: [lambda { |o| o.gsub('a', '') }, :to_i, Float]
      param :array_with_delim, coerce: Array, delimiter: '|'
      param :proc_validation, validate: lambda { |v| v == 'Failed_proc_validation' }
      #validations
      param :some_number, min: 120, max: 500, in: (100..200), is: 122
      param :some_string, min_length: 21, max_length: 30, format: /^t.*g$/
      #combinations
      param :missing_with_validation, coerce: Integer, :default => 60 * 60, :validate => lambda { |v| v >= 60 * 60 }
    end
  }


  it 'does amazing things' do
    (r.valid?).must_equal false
    r[:ignored].must_be_nil
    r[:no_value].must_equal 1
    r[:proc_default].must_equal 5
    r[:renamed].must_equal :to_be_renamed
    r[:integer_coercion].must_equal 1
    r[:bad_number].must_equal 12.0
    #no deep coersion
    r[:array_with_delim].must_equal ["1", "2", "3"]
    r[:missing_with_validation].must_equal 60 * 60

    #failed items don't show up
    r.errors.size.must_equal 2
    r[:doesnt_exist].must_be_nil
    r[:proc_validation].must_be_nil
    r.errors[0].must_equal 'Parameter doesnt_exist is required and missing'
    r.errors[1].must_equal 'is_this_valid? failed validation using proc'

  end

  it 'injects into current class' do
    r = HashParams.new({will_be_injected: 12345}, self) do
      param :will_be_injected
    end
    r[:will_be_injected].must_equal 12345
    @will_be_injected.must_equal 12345
    will_be_injected.must_equal 12345
  end

end
