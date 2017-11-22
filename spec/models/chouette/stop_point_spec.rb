describe Chouette::StopPoint, :type => :model do
  let!(:vehicle_journey) { create(:vehicle_journey)}
  subject { Chouette::Route.find( vehicle_journey.route_id).stop_points.first }

  it { is_expected.to validate_uniqueness_of :objectid }
  it { is_expected.to validate_presence_of :stop_area }
  it { is_expected.to be_versioned }

  describe '#objectid' do
    subject { super().get_objectid }
    it { is_expected.to be_kind_of(Chouette::Objectid::StifNetex) }
  end

  describe "#destroy" do
    before(:each) do
      @vehicle = create(:vehicle_journey)
      @stop_point = Chouette::Route.find( @vehicle.route_id).stop_points.first
    end
    def vjas_stop_point_ids( vehicle_id)
      Chouette::VehicleJourney.find( vehicle_id).vehicle_journey_at_stops.map(&:stop_point_id)
    end
    def jpsp_stop_point_ids( journey_id)
      Chouette::JourneyPattern.find( journey_id).stop_points.map(&:id)
    end
    it "should remove dependent vehicle_journey_at_stop" do
      expect(vjas_stop_point_ids(@vehicle.id)).to include(@stop_point.id)

      @stop_point.destroy

      expect(vjas_stop_point_ids(@vehicle.id)).not_to include(@stop_point.id)
    end
    it "should remove dependent journey_pattern_stop_point" do
      expect(jpsp_stop_point_ids(@vehicle.journey_pattern_id)).to include(@stop_point.id)

      @stop_point.destroy

      expect(jpsp_stop_point_ids(@vehicle.journey_pattern_id)).not_to include(@stop_point.id)
    end
  end

  describe '#duplicate' do
    let!( :new_route ){ create :route }

    it 'creates a new instance' do
      expect{ subject.duplicate(for_route: new_route) }.to change{ Chouette::StopPoint.count }.by(1)
    end
    it 'new instance has a new route' do
      expect(subject.duplicate(for_route: new_route).route).to eq(new_route)
    end
    it 'and old stop_area' do
      expect(subject.duplicate(for_route: new_route).stop_area).to eq(subject.stop_area)
    end
  end
end
