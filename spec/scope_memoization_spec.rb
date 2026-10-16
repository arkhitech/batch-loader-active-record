RSpec.describe "lazy associations with time-dependent scopes" do
  after(:each) { BatchLoader::Executor.clear_current }

  before(:all) do
    Owner = new_model(:owner) do
      include BatchLoaderActiveRecord
      has_many_lazy :published_items, -> { where("published_at <= ?", Time.now) }, class_name: 'Item', foreign_key: 'owner_id'
    end
    Item = new_model(:item, owner_id: :integer, published_at: :datetime)
  end

  # The association's scope is evaluated when the batch loader builds its relation. That relation is
  # cached for the life of the process, so a Time.now captured during the first load would be reused.
  it "uses the current time on every load, not the time of the first load" do
    owner = Owner.create!

    allow(Time).to receive(:now).and_return(Time.now - 1.day)
    expect(Owner.find(owner.id).published_items_lazy.to_a).to be_empty
    allow(Time).to receive(:now).and_call_original
    BatchLoader::Executor.clear_current

    item = Item.create!(owner_id: owner.id, published_at: Time.now)

    expect(Owner.find(owner.id).published_items_lazy.to_a).to include(item)
  end
end
