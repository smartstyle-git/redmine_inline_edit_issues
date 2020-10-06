require File.expand_path('../../test_helper', __FILE__)

class InlineIssuesControllerTest < ActionController::TestCase

  fixtures :issues
  def test_truth
    assert true
  end
  
  def test_get_edit_multiple
    get :edit_multiple, :ids => [1, 2]
    assert_response(200)
  end
end
