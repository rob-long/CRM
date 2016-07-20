var path = window.location.protocol + "//" + window.location.host + "/" + window.location.pathname;

$(document).ready(function() {
	// item input remind box
    $('input#remind').change(function() {
        if ($(this).is(':checked')) {
            $('#item-input-date').show();
            $('textarea[id=value]').prop('placeholder','Enter a task');
            $(this).next('label[for=remind]').html("Remind me <span class='item-bubble' id='item-input-remind-info'>You are now entering a task</span>");
        } else {
            $('#item-input-date').hide();
            $('textarea[id=value]').prop('placeholder','Enter a note');
            $('#item-input-remind-info').remove();
        }
    });
    
    // item input linked contact
    $('#linked_contact').on("click", function() {
        $(this).hide();
        $("input[name=uid]").val('');
        $("#linked_contact_input").show();
    });
    
  	// task status update
    $('.item-value-task input[type=checkbox]').change(function() {
        var input_name = $(this).attr("name");
        var task_id = input_name.replace(/task_/,"");
        toggle_task($(this), task_id);
    });
});

function toggle_task(checkbox, task_id) {
    var container = checkbox.parent(); 
    var item_date = container.parent().find(".item-date");
    if (checkbox.is(':checked')) {
        var url = '?pro=ajax_do_task&item_id=' + task_id;
        container.addClass("item-value-complete");
        item_date.hide();
        $.ajax({
            url: url,
            success: function(html) {
            }
        });
    } else {
        var url = '?pro=ajax_do_task&off=1&item_id=' + task_id;
        container.removeClass("item-value-complete");
        item_date.show();        
        $.ajax({
            url: url
        });
    }
}

// autocomplete functions
function split( val ) {
  return val.split( /,\\s*/ );
}

function extractLast( term ) {
  return split( term ).pop();
}

function setup_acc(id,collection) {
	$("#"+id)
    // don't navigate away from the field on tab when selecting an item
    .bind("keydown", function(event) {
    if ( event.keyCode === $.ui.keyCode.TAB &&
        $(this).autocomplete("instance").menu.active) {
      event.preventDefault();
    }
    })
    .autocomplete({
	    minLength: 0,
        source: function(request, response) {
          // delegate back to autocomplete, but extract the last term
          response( $.ui.autocomplete.filter(
            collection, extractLast(request.term)));
        },
	    focus: function() {
	        return false;
	    },
	    select: function(event, ui) {
	        $("#linked_contact").show().html(ui.item.label + ' &xotime;').text();
	        $("#linked_contact_input").hide();
	    }
    });
}
