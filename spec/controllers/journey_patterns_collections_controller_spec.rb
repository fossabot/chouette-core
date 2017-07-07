RSpec.describe JourneyPatternsCollectionsController, :type => :controller do

  before do
    @user = build_stubbed(:allmighty_user)
  end

  describe 'user_permissions' do
    let( :referential ){ build_stubbed(:referential) }
    let( :user_context ){ UserContext.new(@user, referential: referential) }

    before do
      allow(controller).to receive(:pundit_user).and_return(user_context)
    end

    it 'computes them correctly if not authorized' do
      expect( controller.user_permissions ).to eq({'journey_patterns.create'  => false,
                                                   'journey_patterns.destroy' => false,
                                                   'journey_patterns.update'  => false }.to_json)
    end
    it 'computes them correctly if authorized' do
      @user.organisation_id = referential.organisation_id
      expect( controller.user_permissions ).to eq({'journey_patterns.create'  => true,
                                                   'journey_patterns.destroy' => true,
                                                   'journey_patterns.update'  => true }.to_json)
    end
  end
end
