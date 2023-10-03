module BatchLoaderActiveRecord
  class AssociationProxy < BasicObject
    def initialize(collection_proxy, records, logger = ::Logger.new(::STDOUT))
      @collection_proxy = collection_proxy
      @records = records
      @logger = logger
    end

    methods = [:<<, :to_a, :each, :each_index, :empty?, :first, :last, :map, :collect, :count, :size]
    to = :@records
    location = caller_locations(1, 1).first
    file, line = location.path, location.lineno    
    methods.map do |method|
      definition = /[^\]]=$/.match?(method) ? "arg" : "*args, &block"
      exception = %(raise DelegationError, "#{self}##{method} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")

      method_def = [
        "def #{method}(#{definition})",
        " _ = #{to}",
        "  _.#{method}(#{definition})",
        "rescue ::NoMethodError => e",
        "  if _.nil? && e.name == :#{method}",
        "    #{exception}",
        "  else",
        "    raise",
        "  end",
        "end"
      ].join ";"

      module_eval(method_def, file, line)
    end

    private

    def method_missing(meth, *args, &block)      
      @collection_proxy.send(meth, *args, &block)
    end
  end
end