require File.expand_path('../../test_helper', __FILE__)
#require File.dirname(__FILE__) + '/../test_helper'

class InlineIssuesControllerTest < ActionController::TestCase
  fixtures :issues, :users, :projects, :roles
  include RedmineInlineEditIssues

  def setup
    RedmineInlineEditIssues::TestCase.prepare
  end

  def test_truth
    assert true
  end

  def test_get_edit_multiple
    get :edit_multiple, :ids => [1, 2]
    assert_response(302)
  end

  def test_get_edit_multiple_logged
    @request.session[:user_id] = 2
    get :edit_multiple, :ids => [1, 2]
    assert_response(200)
  end

  def test_update_edit_multiple_logged
    @request.session[:user_id] = 2
    put :update_multiple, params: {1 => {subject: '123'}}, format: :json
    assert_response(200)
  end

  def test_update_edit_multiple_logged_more
    @request.session[:user_id] = 2
    put :update_multiple, params: {1 => {subject: '123'}}, format: :json
    assert_response(999)
  end
end
