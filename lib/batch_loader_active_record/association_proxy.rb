module BatchLoaderActiveRecord
  class AssociationProxy < BasicObject
    def initialize(collection_proxy, records, logger = ::Logger.new(::STDOUT))
      @collection_proxy = collection_proxy
      @records = records
      @logger = logger
    end

    delegate :<<, :to_a, :each, :each_index, :empty?, :first, :last, :map, :collect, :count, :size, to: :@records

    private

    def method_missing(meth, *args, &block)      
      @collection_proxy.send(meth, *args, &block)
    end
  end
end