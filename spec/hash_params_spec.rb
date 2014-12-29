require_relative 'spec_helper'


describe HashParams do
  let (:sample_hash) {

    h= {
        ignored:          "this will be ignored because it's not mentioned",
        to_be_renamed:    :to_be_renamed,
        integer_coercion: "1",
        bad_number:       '1aaa2',
        array_with_delim: '1|2|3',
        hash_as_string:   "{a => 1,b => 2,c => d}",
        proc_validation:  "is_this_valid?",
        some_number:      122,
        some_string:      'this is a test string',
        is_true:          'true',
        is_false:         'f',
        recursive:        {}
    }

  }
  let (:validations) {
    v={
        doesnt_exist:            {required: true},
        to_be_renamed:           {as: :renamed},
        no_value:                {default: 1},
        #proc default relying on previously set value
        proc_default:            {default: lambda { |o| 1 * 5 }},
        integer_coercion:        {coerce: Integer},
        #chained coersions of various types
        bad_number:              {coerce: [lambda { |o| o.gsub('a', '') }, :to_i, Float]},
        #arrays and hashes
        array_with_delim:        {coerce: Array, delimiter: '|'},
        hash_as_string:          {coerce: Hash, delimiter: ',', separator: '=>'},
        proc_validation:         {validate: lambda { |v| v == 'Failed_proc_validation' }},
        #validations
        some_number:             {min: 120, max: 500, in: (100..200), is: 122},
        some_string:             {min_length: 21, max_length: 30, format: /^t.*g$/},
        #combinations
        missing_with_validation: {coerce: Integer, :default => 60 * 60, :validate => lambda { |v| v >= 60 * 60 }},
        is_true:                 {coerce: :boolean},
        is_false:                {coerce: :boolean},
        #recursive}
        recursive:               {
            wasnt_here_before: {default: true}
        }
    }
  }
  let (:r) {
    HashParams.validate_hash(sample_hash, validations, {raise_errors: false})
  }


  it 'does amazing things' do

    (r.valid?).must_equal false

    r[:ignored].must_be_nil
    r[:no_value].must_equal 1
    r[:proc_default].must_equal 5
    r[:to_be_renamed].must_equal :to_be_renamed
    r[:integer_coercion].must_equal 1
    r[:bad_number].must_equal 12.0

    r[:array_with_delim].must_equal ["1", "2", "3"]
    r[:hash_as_string].must_equal ({"a" => "1", "b" => "2", "c" => "d"})
    r[:missing_with_validation].must_equal 60 * 60
    r[:is_true].must_equal true
    r[:is_false].must_equal false

    #recursive checking
    r[:recursive][:wasnt_here_before].must_equal true


    #failed items don't show up
    r.errors.size.must_equal 2
    r[:doesnt_exist].must_be_nil
    r[:proc_validation].must_be_nil
    r.errors[:doesnt_exist].must_equal 'Required Parameter missing and has no default specified'
    r.errors[:proc_validation].must_equal 'is_this_valid? failed validation using proc'

  end

  it 'injects methods into returned hash' do

    #set strict to false so all keys will pass trough
    hash={will_be_injected: 12345}
    opts={make_methods: true, strict: false}

    r=HashParams.validate_hash(hash, {}, opts)
    r[:will_be_injected].must_equal 12345
    r.will_be_injected.must_equal 12345
  end

end
