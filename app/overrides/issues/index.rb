Deface::Override.new :virtual_path  => 'issues/index',
                     :name          => 'direct-edit-multiple-link',
                     :original		=> 'df818bfe864c66cf8c89bd594b0c68ddb8cf1b1a',
                     :insert_bottom	=> "div#query_form_with_buttons p.buttons",
                     :text			=> "<%= link_to l(:'button_accept_edit'), '#', 
                     	:class => 'icon icon-edit', 
                     	:onclick => \"$('#query_form').attr('action', '\"+(@project ? edit_multiple_project_inline_issues_path(@project) : edit_multiple_inline_issues_path)+\"').submit(); return false;\" %>"