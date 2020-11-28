require_dependency 'inline_edit_hooks'

Redmine::Plugin.register :redmine_inline_edit_issues do
  name 'Inline Edit Issues plugin'
  author 'Tomasz Gietek for Omega Code Sp. z o.o.'
  description 'This is a plugin for Redmine.  It allows inline edit of issues in the issues index page.'
  version '2.0.1'

  requires_redmine :version_or_higher => '2.0.0'


  Rails.application.paths["app/overrides"] ||= []
  Rails.application.paths["app/overrides"] << File.expand_path("../app/overrides", __FILE__)
  
  project_module :issue_tracking do
  permission :issues_inline_edit, :inline_issues => [:edit_multiple, :update_multiple]
  end
end
