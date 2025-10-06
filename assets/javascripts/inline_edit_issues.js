$(document).ready(function () {
    // Avoid autofocus
    $(function () {
        $('input').blur();
    });

    $(function () {
        $('#inline_edit_form td input, #inline_edit_form td select, #inline_edit_form td span.select2').each(function () {
            $.data(this, 'default', this.value);
        }).change(function () {
            var curValue = getCurrentValue(this);
            var defValue = getDefaultValue($(this));
            var editedVal = (curValue != defValue);
            $.data(this, 'edited', editedVal);
            if ($(this).is(":checkbox")) {
                if (editedVal) {
                    $(this).parent().addClass('has_background');
                } else {
                    $(this).parent().removeClass('has_background');
                }
            }
        }).blur(function () {
            if (!$.data(this, 'edited')) {
                this.value = $.data(this, 'default');
            }
        });
    });


    // Reset Everything...
    $('#inline_edit_reset').click(function () {
        $('#inline_edit_form')[0].reset();
        calcAllGroupEstimatedHours();
        calcTotalEstimatedHours();
        $('#inline_edit_form td input, #inline_edit_form td select').css("color", "black").each(function () {
            $.data(this, 'edited', false);
            if ($(this).is(":checkbox")) {
                $(this).parent().removeClass('has_background');
            }
        });
    });

    // Calculate Total Estimated Hours
    function calcTotalEstimatedHours() {
        var total = 0.0;
        $('[id$=_estimated_hours]').each(function () {
            total += parseFloat($(this).val()) || 0;
        });

        var result = total.toFixed(2);
        $('td#total-estimated_hours').html(result);
    }

    // Re-calculate group totals for all groups... useful for a reset
    function calcAllGroupEstimatedHours() {
        var previousGroupName = "";

        // Loop through only the estimated hours columns that have a grouping
        $('td[class*="estimated_hours group_"]').each(function () {
            var myClass = $(this).attr('class');
            var groupPos = myClass.search("group");
            if (groupPos >= 0) {
                var groupName = myClass.substr(groupPos);
                if (groupName != previousGroupName) {
                    calcGroupEstimatedHours(groupName);
                    previousGroupName = groupName;
                }
            }
        });
    }

    function calcCurrentGroupEstimatedHours(element) {
        // get this group name by looking at the class names of the parent element
        var myClass = element.parent().attr('class');
        var groupPos = myClass.search("group");

        // continue only if there is a grouping
        if (groupPos >= 0) {
            var groupName = myClass.substr(groupPos);
            calcGroupEstimatedHours(groupName);
        }
    }

    function calcGroupEstimatedHours(groupName) {
        // loop through all elements in this group and sum the Estimated Hours
        var loopName = "td.estimated_hours." + groupName;
        var groupTotal = 0.0;
        $(loopName).each(function () {
            groupTotal += parseFloat($(this).children().val()) || 0;
        });
        //alert(groupTotal);

        // Update the Estimated Hours Total for this group
        var groupTotalId = groupName + "_total_estimated_hours";
        //alert(groupTotalId);
        var result = groupTotal.toFixed(2);
        $('td#' + groupTotalId).html(result);
    }

    // If user changes an estimated hours input,
    // update totals and group totals
    $('td.estimated_hours input').change(function () {
        calcCurrentGroupEstimatedHours($(this));
        calcTotalEstimatedHours();
    });

    // On hover, display the field's default (original) value
    function displayOriginalValue(element, originalValue) {
        var pos = element.offset();
        var height = element.outerHeight();
        $('#field_original_value').html(originalValue);
        $('#field_original').css({
            position: "absolute",
            top: (pos.top + height + 5) + "px",
            left: pos.left + "px"
        }).show();
    }

    function getCurrentValue(el) {
        if ($(el).is(":checkbox")) {
            var currentValue = $(el).is(":checked") ? "True" : "False";
        } else {
            var currentValue = $("option:selected", el).text() || el.value;
        }
        return currentValue;
    }


    function getDefaultValue(element) {
        if (element.is(":checkbox")) {
            var originalValue = element.prop("defaultChecked") ? "True" : "False";
        } else {
            var originalValue = element.prop("defaultValue") || element.find('option[selected]').text();
        }
        return originalValue;
    }


    // handle changes from the datepicker	
    if (window.datepickerOptions) {
        window.datepickerOptions.onSelect = function () {
            var curValue = getCurrentValue(this);
            var defValue = getDefaultValue($(this));
            if (curValue != defValue) {
                $.data(this, 'edited', true);
            } else {
                $.data(this, 'edited', false);
            }
        };
    }

    // トラッカー変更時にステータスをフィルタリング（Redmine標準の動作に準拠）
    function updateStatusOptions($trackerSelect) {
        var trackerId = $trackerSelect.val();
        var $row = $trackerSelect.closest('.new-issue-row-data');
        var $statusSelect = $row.find('.new-issue-status');
        
        console.log('updateStatusOptions called - trackerId:', trackerId, 'type:', typeof trackerId);
        
        // data属性からワークフロー情報を取得（最初の行にのみ存在）
        var trackerStatuses = $('.new-issue-status').first().data('tracker-statuses');
        console.log('trackerStatuses:', trackerStatuses);
        
        // trackerIdを文字列に変換（data属性のキーは文字列の可能性があるため）
        var trackerKey = String(trackerId);
        console.log('Looking for tracker key:', trackerKey);
        
        if (trackerId && trackerStatuses && (trackerStatuses[trackerId] || trackerStatuses[trackerKey])) {
            var allowedStatuses = trackerStatuses[trackerId] || trackerStatuses[trackerKey];
            console.log('allowedStatuses for tracker', trackerId, ':', allowedStatuses);
            
            // 現在の選択値を保持
            var currentValue = $statusSelect.val();
            
            // ステータスのオプションを更新
            $statusSelect.empty();
            allowedStatuses.forEach(function(status) {
                $statusSelect.append($('<option>', {
                    value: status[0],
                    text: status[1]
                }));
            });
            
            // 以前の選択値が新しいオプションに存在する場合は維持、なければ最初の値を選択
            if (allowedStatuses.some(function(s) { return s[0] == currentValue; })) {
                $statusSelect.val(currentValue);
            } else if (allowedStatuses.length > 0) {
                $statusSelect.val(allowedStatuses[0][0]);
            }
            console.log('Status updated to:', $statusSelect.val());
        } else if (!trackerId || trackerId === '') {
            // トラッカーが未選択の場合はステータスをクリア
            console.log('Tracker not selected, clearing status');
            $statusSelect.empty();
            $statusSelect.append($('<option>', { value: '', text: '' }));
        }
    }
    
    $(document).on('change', '.new-issue-tracker', function() {
        console.log('Tracker changed');
        updateStatusOptions($(this));
    });
    
    // ページ読み込み時に既存の行のトラッカーが選択されている場合、ステータスを初期化
    $('.new-issue-row-data').each(function() {
        var $row = $(this);
        var $tracker = $row.find('.new-issue-tracker');
        if ($tracker.val()) {
            console.log('Initializing status for existing row with tracker:', $tracker.val());
            updateStatusOptions($tracker);
        }
    });

    // Add new issue row functionality
    var newIssueIndex = 1;
    
    // Use document-level delegation to ensure button works
    $(document).on('click', '#add-new-issue-row', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        console.log('Add button clicked, current index:', newIssueIndex);
        
        var $firstRow = $('.new-issue-row-data').first();
        var $newRow = $firstRow.clone();
        
        // Update indices and clear values
        $newRow.attr('data-index', newIssueIndex);
        $newRow.find('input, select, textarea').each(function() {
            var name = $(this).attr('name');
            if (name) {
                // Replace all occurrences of [0] with [newIssueIndex]
                var newName = name.replace(/\[0\]/g, '[' + newIssueIndex + ']');
                $(this).attr('name', newName);
                console.log('Updated name from', name, 'to', newName);
            }
            var id = $(this).attr('id');
            if (id) {
                // Replace _0_ pattern (e.g., new_issues_0_subject -> new_issues_1_subject)
                var newId = id.replace(/new_issues_\d+_/g, 'new_issues_' + newIssueIndex + '_');
                $(this).attr('id', newId);
                console.log('Updated id from', id, 'to', newId);
            }
            
            // Clear values
            if ($(this).is('select')) {
                // ステータス以外をクリア
                if (!$(this).hasClass('new-issue-status')) {
                    $(this).val('');
                }
            } else if (!$(this).is(':checkbox') && !$(this).is(':radio')) {
                $(this).val('');
            }
        });
        
        // トラッカーは未選択にし、ステータスも空白にする
        var $newTracker = $newRow.find('.new-issue-tracker');
        var $newStatus = $newRow.find('.new-issue-status');
        
        // トラッカーをクリア
        $newTracker.val('');
        
        // ステータスもクリア
        $newStatus.empty();
        $newStatus.append($('<option>', { value: '', text: '' }));
        
        // Update labels
        $newRow.find('label').each(function() {
            var forAttr = $(this).attr('for');
            if (forAttr) {
                var newFor = forAttr.replace(/new_issues_\d+_/g, 'new_issues_' + newIssueIndex + '_');
                $(this).attr('for', newFor);
                console.log('Updated label for from', forAttr, 'to', newFor);
            }
        });
        
        // Show remove button
        $newRow.find('.remove-new-issue').show();
        
        // 追加ボタンの行の前に挿入
        $('#add-new-issue-row').closest('tr').before($newRow);
        
        console.log('New row added with index:', newIssueIndex);
        newIssueIndex++;
        
        // Update remove buttons visibility
        updateRemoveButtons();
    });
    
    // Remove new issue row
    $(document).on('click', '.remove-new-issue', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        console.log('Remove button clicked'); // Debug log
        
        $(this).closest('.new-issue-row-data').remove();
        updateRemoveButtons();
    });
    
    function updateRemoveButtons() {
        var $rows = $('.new-issue-row-data');
        if ($rows.length > 1) {
            $rows.find('.remove-new-issue').show();
        } else {
            $rows.find('.remove-new-issue').hide();
        }
    }

});
