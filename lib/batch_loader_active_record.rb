# frozen_string_literal: true

require "batch-loader"
require "batch_loader_active_record/version"
require "batch_loader_active_record/association_manager"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def association_accessor(name)
      reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
      manager = AssociationManager.new(model: self, reflection: reflection)
      case reflection.macro
      when :belongs_to
        if reflection.polymorphic?
          define_method(manager.accessor_name) do |options = nil|
            manager.polymorphic_belongs_to_batch_loader(self, options)
          end
        else
          define_method(manager.accessor_name) do |options = nil|
            manager.belongs_to_batch_loader(self, options)
          end
        end
      when :has_one
        define_method(manager.accessor_name) do |options = nil|
          manager.has_one_to_batch_loader(self, options)
        end
      when :has_many
        define_method(manager.accessor_name) do |options = nil|
          manager.has_many_to_batch_loader(self, options)
        end
      when :has_and_belongs_to_many
        define_method(manager.accessor_name) do |options = nil|
          manager.has_and_belongs_to_many_to_batch_loader(self, options)
        end
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
        else
          define_method(manager.accessor_name) do |options = nil| 
            manager.belongs_to_batch_loader(self, options)
          end
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
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_method(manager.accessor_name) do |options = nil|
          manager.has_many_to_batch_loader(self, options)
        end
      end
    end

    def has_and_belongs_to_many_lazy(*args)
      has_and_belongs_to_many(*args).tap do
        reflection = reflect_on_association(args[0]) or raise "Can't find association #{args[0].inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_method(manager.accessor_name) do |options = nil|
          manager.has_and_belongs_to_many_to_batch_loader(self, options)
        end
      end
    end
  end
end
