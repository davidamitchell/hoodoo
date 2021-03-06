require 'spec_helper'

describe Hoodoo::Presenters::Boolean do

  before do
    @inst = Hoodoo::Presenters::Boolean.new('one',:required => false)
  end

  describe '#validate' do
    it 'should return [] when valid boolean' do
      expect(@inst.validate(true).errors).to eq([])
      expect(@inst.validate(false).errors).to eq([])
    end

    it 'should return correct error when data is not a boolean' do
      errors = @inst.validate('adskncasc')

      err = [  {'code'=>"generic.invalid_boolean", 'message'=>"Field `one` is an invalid boolean", 'reference'=>"one"}]
      expect(errors.errors).to eq(err)
    end

    it 'should return correct error with non boolean types' do
      err = [  {'code'=>"generic.invalid_boolean", 'message'=>"Field `one` is an invalid boolean", 'reference'=>"one"}]

      expect(@inst.validate('asckn').errors).to eq(err)
      expect(@inst.validate(34534.234).errors).to eq(err)
      expect(@inst.validate(38247).errors).to eq(err)
      expect(@inst.validate({}).errors).to eq(err)
      expect(@inst.validate([]).errors).to eq(err)
    end

    it 'should not return error when not required and absent' do
      expect(@inst.validate(nil).errors).to eq([])
    end

    it 'should return error when required and absent' do
      @inst.required = true
      expect(@inst.validate(nil).errors).to eq([
        {'code'=>"generic.required_field_missing", 'message'=>"Field `one` is required", 'reference'=>"one"}
      ])
    end

    it 'should return correct error with path' do
      errors = @inst.validate('scdacs','ordinary')
      expect(errors.errors).to eq([
        {'code'=>"generic.invalid_boolean", 'message'=>"Field `ordinary.one` is an invalid boolean", 'reference'=>"ordinary.one"}
      ])
    end
  end

end
