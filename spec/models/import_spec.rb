RSpec.describe Import, type: :model do

  it { should belong_to(:referential) }
  it { should belong_to(:workbench) }
  it { should belong_to(:parent) }

  it { should enumerize(:status).in("aborted", "canceled", "failed", "new", "pending", "running", "successful") }

  it { should validate_presence_of(:file) }
  it { should validate_presence_of(:workbench) }
  it { should validate_presence_of(:creator) }

  let(:workbench_import) { build_stubbed(:workbench_import) }
  let(:workbench_import_with_completed_steps) do
    workbench_import = build_stubbed(
      :workbench_import,
      total_steps: 2,
      current_step: 2
    )
  end

  let(:netex_import) do
    netex_import = build_stubbed(
      :netex_import,
      parent: workbench_import
    )
  end

  describe "#notify_parent" do
    it "must call #child_change on its parent" do
      allow(netex_import).to receive(:update)

      expect(workbench_import).to receive(:child_change)

      netex_import.notify_parent
    end

    it "must update the :notified_parent_at field of the child import" do
      allow(workbench_import).to receive(:child_change)

      Timecop.freeze(DateTime.now) do
        expect(netex_import).to receive(:update).with(
          notified_parent_at: DateTime.now
        )

        netex_import.notify_parent
      end
    end
  end

  describe "#child_change" do
    it "calls #update_status" do
      allow(workbench_import).to receive(:update)

      expect(workbench_import).to receive(:update_status)
      workbench_import.child_change
    end

    it "calls #update_referentials" do
      allow(workbench_import).to receive(:update)

      expect(workbench_import).to receive(:update_referentials)
      workbench_import.child_change
    end
  end

  describe "#update_status" do
    shared_examples(
      "updates :status to failed when >=1 child has failing status"
    ) do |failure_status|
      it "updates :status to failed when >=1 child has failing status" do
        workbench_import = create(:workbench_import)
        create(
          :netex_import,
          parent: workbench_import,
          status: failure_status
        )

        Timecop.freeze(Time.now) do
          workbench_import.update_status

          expect(workbench_import.status).to eq('failed')
        end
      end
    end

    include_examples(
      "updates :status to failed when >=1 child has failing status",
      "failed"
    )
    include_examples(
      "updates :status to failed when >=1 child has failing status",
      "aborted"
    )
    include_examples(
      "updates :status to failed when >=1 child has failing status",
      "canceled"
    )

    # TODO: rewrite these for new #update_status
    # it "updates :status to successful when #ready?" do
    #   expect(workbench_import).to receive(:update).with(status: 'successful')
    #
    #   workbench_import.child_change
    # end
    #
    # it "updates :status to failed when #ready? and child is failed" do
    #   build_stubbed(
    #     :netex_import,
    #     parent: workbench_import,
    #     status: :failed
    #   )
    #
    #   expect(workbench_import).to receive(:update).with(status: 'failed')
    #
    #   workbench_import.child_change
    # end

    it "updates :ended_at to now when status is finished" do
      skip "Redo the `#update_status` code to make it easier to write this."
    end
  end

  # TODO: specs for #update_referential
end
