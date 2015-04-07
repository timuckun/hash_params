require_relative 'spec_helper'


describe HashParams do
  let(:v) { HashParams }

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
    v.validate(nil, default: lambda { 2 * 5 }).must_equal 10
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
    v.coerce('1', :boolean).must_equal true
    v.coerce(1, :boolean).must_equal true
  end

  it 'coerces false' do
    v.coerce('f', :boolean).must_equal false
    v.coerce('false', :boolean).must_equal false
    v.coerce('no', :boolean).must_equal false
    v.coerce('0', :boolean).must_equal false
    v.coerce(0, :boolean).must_equal false
  end

  it 'coerces array' do
    v.coerce('1|2|3', Array, delimiter: '|').must_equal ["1", "2", "3"]
  end

  it 'coerces hash' do
    v.coerce('{a => 1,b => 2,c => d}', Hash, delimiter: ',', separator: '=>').must_equal({"a" => "1", "b" => "2", "c" => "d"})
  end

  it 'validates a hash using a block' do
    r = v.validate(
        {
            ignored:          "this will be ignored because it's not mentioned",
            to_be_renamed:    :to_be_renamed,
            integer_coercion: "1",
            proc_validation:  "is_this_valid?",
            recursive:        {}
        }
    ) do
      param :doesnt_exist, required: true
      param :to_be_renamed, as: :renamed
      #Default Lambdas take no parameters
      param :proc_default, default: lambda { 1 * 5 }
      param :proc_validation, validate: lambda { |v| v == 'Failed_proc_validation' }
      #recursive
      param :recursive do
        param :wasnt_here_before, default: true
      end
    end

    (r.valid?).must_equal false
    r[:ignored].must_be_nil
    # r[:proc_default].must_equal 5
    r[:renamed].must_equal :to_be_renamed
    #recursive checking
    r[:recursive][:wasnt_here_before].must_equal true

    #failed items don't show up
    r[:doesnt_exist].must_be_nil
    r[:proc_validation].must_be_nil

    r.validation_errors.size.must_equal 2
    r.validation_errors[0].must_equal "Error processing key 'doesnt_exist': Required Parameter missing and has no default specified"
    r.validation_errors[1].must_equal "Error processing key 'proc_validation': is_this_valid? failed validation using proc"

  end
end
