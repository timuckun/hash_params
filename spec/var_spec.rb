require_relative 'spec_helper'

describe HashParams do
  let(:v) { HashParams }
  it 'does things' do
    HashParams::BindingValidator("test")
    binding.pry
  end
end
