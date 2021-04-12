class WorkgroupWorkbenchDecorator < AF83::Decorator
  decorates Workbench

	policy WorkgroupWorkbenchPolicy
  set_scope { context[:workgroup] }

  with_instance_decorator do |instance_decorator|
    instance_decorator.crud
  end
end
