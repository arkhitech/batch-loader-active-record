# frozen_string_literal: true

require "batch-loader"
require "batch_loader_active_record/version"
require "batch_loader_active_record/association_manager"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end
  module ClassMethods
    # defines a method to override main association reader method to use this method
    # so product.master_lazy_load would load the object as well as define method
    # inside product so that the next call to product.master after this product.master_lazy_load
    # would also reference the lazy_loaded method
    def define_reader_override_method(manager)
      define_method(manager.writer_name) do |options = nil|
        association_object = self.send(manager.accessor_name, options)
        association_object = !association_object.nil? && association_object || nil
        define_singleton_method(name) do
          association_object
        end
      end
    end
    private :define_reader_override_method

    # ensures that object is loaded immediately or nil is returned
    def define_reader_load_method(manager)
      define_method(manager.loaded_accessor_name) do |options = nil|
        association_object = self.send(manager.accessor_name, options)
        association_object = !association_object.nil? && association_object || nil
      end
    end
    private :define_reader_load_method
    
    def lazy_association_accessor(name)
      reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
      manager = AssociationManager.new(model: self, reflection: reflection)
      case reflection.macro
      when :belongs_to
        if reflection.polymorphic?
          define_method(manager.accessor_name) do |options = nil|
            manager.polymorphic_belongs_to_batch_loader(self, options)
          end
          define_reader_override_method(manager)
          define_reader_load_method(manager)
        else
          define_method(manager.accessor_name) do |options = nil|
            manager.belongs_to_batch_loader(self, options)
          end
          define_reader_override_method(manager)
          define_reader_load_method(manager)
        end
      when :has_one
        define_method(manager.accessor_name) do |options = nil|
          manager.has_one_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      when :has_many
        define_method(manager.accessor_name) do |options = nil|
          manager.has_many_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      when :has_and_belongs_to_many
        define_method(manager.accessor_name) do |options = nil|
          manager.has_and_belongs_to_many_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      else
        raise NotImplementedError, "association kind #{reflection.macro.inspect} is not yet supported"
      end
    end

    def belongs_to_lazy(*args)
      belongs_to(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        if reflection.polymorphic?
          define_method(manager.accessor_name) do |options = nil| 
            manager.polymorphic_belongs_to_batch_loader(self, options)
          end
          define_reader_override_method(manager)
          define_reader_load_method(manager)
        else
          define_method(manager.accessor_name) do |options = nil| 
            manager.belongs_to_batch_loader(self, options)
          end
          define_reader_override_method(manager)
          define_reader_load_method(manager)
        end
      end
    end

    def has_one_lazy(*args)
      has_one(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_method(manager.accessor_name) do |options = nil| 
          manager.has_one_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_method(manager.accessor_name) do |options = nil|
          manager.has_many_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      end
    end

    def has_and_belongs_to_many_lazy(*args)
      has_and_belongs_to_many(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_method(manager.accessor_name) do |options = nil|
          manager.has_and_belongs_to_many_to_batch_loader(self, options)
        end
        define_reader_override_method(manager)
        define_reader_load_method(manager)
      end
    end
  end
end
