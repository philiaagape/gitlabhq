require 'spec_helper'

describe Groups::CreateService, '#execute', services: true do
  let!(:user) { create(:user) }
  let!(:group_params) { { path: "group_path", visibility_level: Gitlab::VisibilityLevel::PUBLIC } }

  describe 'visibility level restrictions' do
    let!(:service) { described_class.new(user, group_params) }

    subject { service.execute }

    context "create groups without restricted visibility level" do
      it { is_expected.to be_persisted }
    end

    context "cannot create group with restricted visibility level" do
      before { allow_any_instance_of(ApplicationSetting).to receive(:restricted_visibility_levels).and_return([Gitlab::VisibilityLevel::PUBLIC]) }

      it { is_expected.not_to be_persisted }
    end
  end

  describe 'creating subgroup' do
    let!(:group) { create(:group) }
    let!(:service) { described_class.new(user, group_params.merge(parent_id: group.id)) }

    subject { service.execute }

    context 'as group owner' do
      before { group.add_owner(user) }

      it { is_expected.to be_persisted }
    end

    context 'as guest' do
      it 'does not save group and returns an error' do
        is_expected.not_to be_persisted
        expect(subject.errors[:parent_id].first).to eq('manage access required to create subgroup')
        expect(subject.parent_id).to be_nil
      end
    end
  end
end
