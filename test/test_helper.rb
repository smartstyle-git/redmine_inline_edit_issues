require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

class RedmineInlineEditIssues::TestCase
  include ActionDispatch::TestProcess

  def self.prepare
    # u1: p1 [r1 manager]
    # u2: p1 [r2 developer]
    # u3: p1 [r3 reporter]

    Project.find(1, 2, 3).each do |project|
      # EnabledModule.create(:project => project, :name => 'schedule')
    end

    Role.find(1, 2).each do |r|
      r.permissions << :issues_inline_edit
      r.save
    end

    Role.find(1) do |r|
      r.permissions << :issues_inline_edit
    end
  end
end

