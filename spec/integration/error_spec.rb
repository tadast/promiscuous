require 'spec_helper'

describe Promiscuous do
  before { load_models }

  let!(:error_notifier) { proc { |exception| @error_notifier_called_with = exception } }
  before { use_real_amqp(:error_notifier => error_notifier, :logger_level => Logger::FATAL) }

  context 'when replicating the update of a model that fails' do
    before do
      define_constant('Publisher', ORM::PublisherBase) do
        publish :to => 'crowdtap/publisher_model',
                :class => :PublisherModel,
                :attributes => [:field_1, :field_2, :field_3]
      end

      define_constant('Subscriber', ORM::SubscriberBase) do
        subscribe :from => 'crowdtap/publisher_model',
                  :class => SubscriberModel,
                  :attributes => [:field_1, :field_2, :field_3]
      end
    end

    before { Promiscuous::Worker.replicate }

    context 'on the subscriber side' do
      before { SubscriberModel.class_eval { validates_format_of :field_1, :without => /death/ } }

      it 'calls the error_notifier with an exception' do
        pub = PublisherModel.create
        pub.update_attributes(:field_1 => 'death')
        eventually do
          @error_notifier_called_with.should be_a(Promiscuous::Error::Subscriber)
          @error_notifier_called_with.payload.should =~ /death/
        end
      end
    end
  end

  context 'when subscribing to non published fields' do
    before do
      define_constant('Publisher', ORM::PublisherBase) do
        publish :to => 'crowdtap/publisher_model',
                :class => PublisherModel,
                :attributes => [:field_1, :field_2]
      end

      define_constant('Subscriber', ORM::SubscriberBase) do
        subscribe :from => 'crowdtap/publisher_model',
                  :class => SubscriberModel,
                  :attributes => [:field_1, :field_2, :field_3]
      end
    end

    before { Promiscuous::Worker.replicate }

    it 'calls the error_notifier with an exception' do
      PublisherModel.create
      eventually { @error_notifier_called_with.should be_a(Exception) }
    end
  end

  if ORM.has(:embedded_documents)
    context 'when the subscriber is missing' do
      before do
        define_constant('PublisherEmbed', ORM::PublisherBase) do
          publish :to => 'crowdtap/publisher_model_embed',
                  :class => PublisherModelEmbed,
                  :attributes => [:field_1, :field_2, :field_3, :model_embedded]
        end

        define_constant('PublisherEmbedded', ORM::PublisherBase) do
          publish :to => 'crowdtap/model_embedded',
                  :class => PublisherModelEmbedded,
                  :attributes => [:embedded_field_1, :embedded_field_2, :embedded_field_3]
        end

        define_constant('SubscriberEmbed', ORM::SubscriberBase) do
          subscribe :from => 'crowdtap/publisher_model_embed',
                    :class => SubscriberModelEmbed,
                    :attributes => [:field_1, :field_2, :field_3, :model_embedded]
        end
      end

      before { Promiscuous::Worker.replicate }

      it 'calls the error_notifier with an exception' do
        pub = PublisherModelEmbed.create(:field_1 => '1',
                                         :model_embedded => { :embedded_field_1 => 'e1',
                                                              :embedded_field_2 => 'e2' })
        eventually { @error_notifier_called_with.should be_a(Exception) }
      end
    end
  end
end
