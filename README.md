# hash-params
_Lightweight Parameter Validation & Type Coercion_

This is a variation of the sinatra-param gem  https://github.com/mattt/sinatra-param
with the sinatra specific things taken out and slight modifications to make it more useful for generic applications.

`hash-params` allows you to declare, validate, and transform endpoint parameters as you would in frameworks like [ActiveModel](http://rubydoc.info/gems/activemodel/3.2.3/frames) or [DataMapper](http://datamapper.org/). but in a lighterweight fashion

 See the spec down the page for usage scenarios

## Validations

- Validations are passed as a hash.
- You can validate either individual values or hashes.
- Hashes can be validated recursively
- You can call the coersion methods separately if you wish
- If you don't pass in any validations you'll get the same hash back unless you set the strict option (see below)

## Coercions

 By declaring parameter types, incoming parameters will automatically be coerced into an object of that type.

 - `String`
 - `Integer`
 - `Float`
 - `Array` _("1,2,3,4,5")_
 - `Hash` _(key1:value1,key2:value2)_
 - `Date`, `Time`, & `DateTime`
 - `:boolean` _("1/0", "true/false", "t/f", "yes/no", "y/n")_


 Note that the `Hash` and `Array` coercions are not deep (only one level).  The internal elements are not validated or coerced, everything is returned as a string.

 Since Ruby doesn't have a Boolean type use the symbol :boolean.  This will attempt to cast the commonly used values to either true or false (`TrueClass` or `FalseClass`)

 You can also use anything that will respond to `to_proc` such as `:to_i`, `:downcase`, etc.  It's up to you to make sure the value will obey the method


## Validation Options

 You can pass in the following options along with your validations

- `strict`: Defaults to true. Only the elements mentioned in the validation will be returned. If set to false all elements will be returned by the validated values will replace the originals
- `make_methods`: If passed the returned hash will have methods defined for each key in the new hash.  This will allow you access the values using standard dot notation.
- `raise_errors`: Defaults to true. All errors will be collected during processing and raised just once.  If you set this to false no error will be raised, you can check the ```hash.valid?``` method or the ```hash.errors``` collection


## Yaml files

   ```validate_yaml_file``` and ```validate_default_yaml_files``` methods are provided for convenience.

   ```validate_yaml_file``` works exactly like ```validate_hash``` but takes a file name instead of a hash

   ```validate_default_file_names``` scours various directories for yaml files and intelligently merges them together before validation.  See the source code for the standard paths and file name patterns.


   You can specify the following in the options hash they will all have sensible defaults except the ```app_name```

   - app_name
   - env
   - roots
   - file_separator
   - file_extension

## Example

``` ruby
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



```




## Contact

Tim Uckun

- http://github.com/timuckun
- http://twitter.com/timuckun
- tim@uckun.com

## License

hash-parameters is available under the MIT license. See the LICENSE file for more info.
