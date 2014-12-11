require 'rails_helper'

describe MetricConfigurationsController, :type => :controller do
  let(:kalibro_configuration) { FactoryGirl.build(:kalibro_configuration) }
  describe 'choose_metric' do
    let(:metric_collector) { FactoryGirl.build(:metric_collector) }
    before :each do
      sign_in FactoryGirl.create(:user)
    end

    context 'when adding new metrics' do
      before :each do
        subject.expects(:kalibro_configuration_owner?).returns true
        KalibroClient::Processor::MetricCollector.expects(:all).returns([metric_collector])
        get :choose_metric, kalibro_configuration_id: kalibro_configuration.id
      end

      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:choose_metric) }
    end
  end

  describe 'new' do
    let(:metric_collector) { FactoryGirl.build(:metric_collector) }
    before :each do
      sign_in FactoryGirl.create(:user)
    end

    context 'when the current user owns the mezuro configuration' do
      before :each do
        subject.expects(:kalibro_configuration_owner?).returns true
        KalibroClient::Processor::MetricCollector.expects(:find).with(metric_collector.name).returns(metric_collector)
        post :new, kalibro_configuration_id: kalibro_configuration.id, metric_name: "Lines of Code", metric_collector_name: metric_collector.name
      end

      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:new) }
    end

    context "when the current user doesn't owns the mezuro configuration" do
      before :each do
        post :new, kalibro_configuration_id: kalibro_configuration.id, metric_name: "Lines of Code", metric_collector_name: metric_collector.name
      end

      it { is_expected.to redirect_to(kalibro_configurations_url(kalibro_configuration.id)) }
      it { is_expected.to respond_with(:redirect) }
    end
  end

  describe 'create' do
    let!(:metric_configuration) { FactoryGirl.build(:metric_configuration) }
    let(:metric_configuration_params) { Hash[FactoryGirl.attributes_for(:metric_configuration).map { |k,v| [k.to_s, v.to_s] }] }  #FIXME: Mocha is creating the expectations with strings, but FactoryGirl returns everything with symbols and integers
    let(:kalibro_configuration) { FactoryGirl.build(:kalibro_configuration) }
    let(:metric_collector) { FactoryGirl.build(:metric_collector) }

    before do
      sign_in FactoryGirl.create(:user)
    end

    context 'when the current user owns the metric configuration' do
      before :each do
        subject.expects(:kalibro_configuration_owner?).returns true
      end

      context 'with valid fields' do
        before :each do
          MetricConfiguration.any_instance.expects(:save).returns(true)
          KalibroClient::Processor::MetricCollector.expects(:find).with(metric_collector.name).returns(metric_collector)
          metric_collector.expects(:metric).with(metric_configuration.metric.name).returns(metric_configuration.metric)

          post :create, kalibro_configuration_id: kalibro_configuration.id, metric_configuration: metric_configuration_params, metric_collector_name: metric_collector.name, metric_name: metric_configuration.metric.name
        end

        it { is_expected.to respond_with(:redirect) }
      end

      context 'with invalid fields' do
        before :each do
          MetricConfiguration.any_instance.expects(:save).returns(false)
          KalibroClient::Processor::MetricCollector.expects(:find).with(metric_collector.name).returns(metric_collector)
          metric_collector.expects(:metric).with(metric_configuration.metric.name).returns(metric_configuration.metric)

          post :create, kalibro_configuration_id: kalibro_configuration.id, metric_configuration: metric_configuration_params, metric_collector_name: metric_collector.name, metric_name: metric_configuration.metric.name
        end

        it { is_expected.to render_template(:new) }
      end
    end
  end

  describe 'show' do
    let(:metric_configuration) { FactoryGirl.build(:metric_configuration) }
    let(:reading_group) { FactoryGirl.build(:reading_group) }
    let(:mezuro_range) { FactoryGirl.build(:mezuro_range) }

    before :each do
      ReadingGroup.expects(:find).with(metric_configuration.reading_group_id).returns(reading_group)
      subject.expects(:find_resource).with(MetricConfiguration, metric_configuration.id).returns(metric_configuration)
      metric_configuration.expects(:kalibro_ranges).returns([mezuro_range])

      get :show, kalibro_configuration_id: metric_configuration.configuration_id.to_s, id: metric_configuration.id
    end

    it { is_expected.to render_template(:show) }
  end

  describe 'edit' do
    let(:metric_configuration) { FactoryGirl.build(:metric_configuration) }

    context 'with an User logged in' do
      before do
        sign_in FactoryGirl.create(:user)
      end

      context 'when the user owns the metric configuration' do
        before :each do
          subject.expects(:metric_configuration_owner?).returns(true)
          subject.expects(:find_resource).with(MetricConfiguration, metric_configuration.id).returns(metric_configuration)
          get :edit, id: metric_configuration.id, kalibro_configuration_id: metric_configuration.configuration_id.to_s
        end

        it { is_expected.to render_template(:edit) }
      end

      context 'when the user does not own the metric configuration' do
        before do
          get :edit, id: metric_configuration.id, kalibro_configuration_id: metric_configuration.configuration_id.to_s
        end

        it { is_expected.to redirect_to(kalibro_configurations_path(metric_configuration.configuration_id)) }
        it { is_expected.to respond_with(:redirect) }
        it { is_expected.to set_the_flash[:notice].to("You're not allowed to do this operation") }
      end
    end

    context 'with no user logged in' do
      before :each do
        get :edit, id: metric_configuration.id, kalibro_configuration_id: metric_configuration.configuration_id.to_s
      end

      it { is_expected.to redirect_to new_user_session_path }
    end
  end

  describe 'update' do
    let(:metric_configuration) { FactoryGirl.build(:metric_configuration) }
    let(:metric_configuration_params) { Hash[FactoryGirl.attributes_for(:metric_configuration).map { |k,v| [k.to_s, v.to_s] }] } #FIXME: Mocha is creating the expectations with strings, but FactoryGirl returns everything with sybols and integers

    context 'when the user is logged in' do
      before do
        sign_in FactoryGirl.create(:user)
      end

      context 'when user owns the metric configuration' do
        before :each do
          subject.expects(:metric_configuration_owner?).returns true
        end

        context 'with valid fields' do
          before :each do
            subject.expects(:find_resource).with(MetricConfiguration, metric_configuration.id).returns(metric_configuration)
            MetricConfiguration.any_instance.expects(:update).with(metric_configuration_params).returns(true)

            post :update, kalibro_configuration_id: metric_configuration.configuration_id, id: metric_configuration.id, metric_configuration: metric_configuration_params
          end

          it { is_expected.to redirect_to(kalibro_configuration_path(metric_configuration.configuration_id)) }
          it { is_expected.to respond_with(:redirect) }
        end

        context 'with an invalid field' do
          before :each do
            subject.expects(:find_resource).with(MetricConfiguration, metric_configuration.id).returns(metric_configuration)
            MetricConfiguration.any_instance.expects(:update).with(metric_configuration_params).returns(false)

            post :update, kalibro_configuration_id: metric_configuration.configuration_id, id: metric_configuration.id, metric_configuration: metric_configuration_params
          end

          it { is_expected.to render_template(:edit) }
        end
      end

      context 'when the user does not own the reading' do
        before :each do
          post :update, kalibro_configuration_id: metric_configuration.configuration_id, id: metric_configuration.id, metric_configuration: metric_configuration_params
        end

        it { is_expected.to redirect_to kalibro_configurations_path(metric_configuration.configuration_id) }
      end
    end
  end


  describe 'destroy' do
    let(:metric_configuration) { FactoryGirl.build(:metric_configuration) }

    context 'with an User logged in' do
      before do
        sign_in FactoryGirl.create(:user)
      end

      context 'when the user owns the configuration' do
        before :each do
          subject.expects(:metric_configuration_owner?).returns true
          metric_configuration.expects(:destroy)
          subject.expects(:find_resource).with(MetricConfiguration, metric_configuration.id).returns(metric_configuration)

          delete :destroy, id: metric_configuration.id, kalibro_configuration_id: metric_configuration.configuration_id.to_s
        end

        it { is_expected.to redirect_to(kalibro_configuration_path(metric_configuration.configuration_id)) }
        it { is_expected.to respond_with(:redirect) }
      end

      context "when the user doesn't own the configuration" do
        before :each do
          delete :destroy, id: metric_configuration.id, kalibro_configuration_id: metric_configuration.configuration_id.to_s
        end

         it { is_expected.to redirect_to(kalibro_configurations_path(metric_configuration.configuration_id)) }
         it { is_expected.to respond_with(:redirect) }
      end
    end

    context 'with no User logged in' do
      before :each do
        delete :destroy, id: metric_configuration.id, kalibro_configuration_id: kalibro_configuration.id.to_s
      end

      it { is_expected.to redirect_to new_user_session_path }
    end
  end
end
