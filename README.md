# hash-params
_Lightweight Parameter Validation & Type Coercion_

This is a variation of the sinatra-param gem  https://github.com/mattt/sinatra-param
with the sinatra specific things taken out and slight modifications to make it more useful for generic applications.

**`hash-params` allows you to declare, validate, and transform endpoint parameters as you would in frameworks like [ActiveModel](http://rubydoc.info/gems/activemodel/3.2.3/frames) or [DataMapper](http://datamapper.org/). but in a lighterweight fashion**


## Example

``` ruby
describe HashParams do

  let (:r) {
    HashParams.new(
        {
            ignored:          "this will be ignored because it's not mentioned",
            to_be_renamed:    :to_be_renamed,
            integer_coercion: "1",
            bad_number:       '1aaa2',
            array_with_delim: '1|2|3',
            hash_as_string:   "{a => 1,b => 2,c => d}",
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
      #arrays and hashes
      param :array_with_delim, coerce: Array, delimiter: '|'
      param :hash_as_string, coerce: Hash, delimiter: ',', separator: '=>'
      #procs
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
    r[:hash_as_string].must_equal ({ "a" => "1", "b" => "2", "c" => "d" })
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

```


### Defaults

Passing a `default` option will provide a default value for a parameter if none is passed.  A `default` can defined as either a default or as a `Proc`:

```ruby
param :attribution, String, default: "©"
param :year, Integer, default: lambda { Time.now.year }
```


### Coercions

By declaring parameter types, incoming parameters will automatically be coerced into an object of that type.

- `String`
- `Integer`
- `Float`
- `Array` _("1,2,3,4,5")_
- `Hash` _(key1:value1,key2:value2)_
- `Date`, `Time`, & `DateTime`

Note that the `Hash` and `Array` coercions are not deep (only one level).  The internal elements are not validated or coerced, everything is returned as a string.
 
Since Ruby doesn't have a Boolean type use the symbol :boolean.  This will attempt to cast the commonly used values to either true or false (`TrueClass` or `FalseClass`)
- `:boolean` _("1/0", "true/false", "t/f", "yes/no", "y/n")_

You can also use anything that will respond to `to_proc` such as `:to_i`, `:downcase`, etc.  It's up to you to make sure the value will obey the method


### Validations

Encapsulate business logic in a consistent way with validations. If a parameter does not satisfy a particular condition the parameter is not added to the result and an entry is made into the errors collection.

- `required`
- `blank`
- `is`
- `in`, `within`, `range`
- `min` / `max`
- `format`

**Only valid entries are returned, all others are ignored**


### Exceptions and Validation Failures

All recorded validation errors, coercion errors, and exceptions are in the errors collection of the returned object. You can also call the valid? method to check to see if everything went OK.

```ruby
p = HashParams.new({a: :b}) do 
      param :a
    end

p.errors.inspect unless p.valid?
```

### Injection into classes

You can if you choose inject all passing variables (but not valid? or errors collection) into a given class.  The injection is done via  `attr_accessor` The values are injected into the singleton so no need to worry about polluting other objects.

```ruby
it 'injects into current class' do
    r = HashParams.new({will_be_injected: 12345}, self) do
      param :will_be_injected
    end
    r[:will_be_injected].must_equal 12345
    @will_be_injected.must_equal 12345
    will_be_injected.must_equal 12345
  end
```


## Contact

Tim Uckun

- http://github.com/timuckun
- http://twitter.com/timuckun
- tim@uckun.com

## License

hash-parameters is available under the MIT license. See the LICENSE file for more info.
