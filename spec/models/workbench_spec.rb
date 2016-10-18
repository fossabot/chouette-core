require 'rails_helper'

RSpec.describe Workbench, :type => :model do

  it 'should have a valid factory' do
    expect(FactoryGirl.build(:workbench)).to be_valid
  end

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:organisation) }

  it { should belong_to(:organisation) }
  it { should belong_to(:line_referential) }
  it { should belong_to(:stop_area_referential) }
end
