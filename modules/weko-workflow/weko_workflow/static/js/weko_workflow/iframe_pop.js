require([
  "jquery",
  "bootstrap"
], function() {
  $("#step_item_login", parent.document).attr('height', '240px');
  $('#btn-finish').on('click', function(){
    let post_uri = $(".cur_step", parent.document).data('next-uri');
    let post_data = {
      commond: $('#input-comment').val(),
      action_version: $(".cur_step", parent.document).data('action-version'),
      temporary_save: 0
    };
    $.ajax({
      url: post_uri,
      method: 'POST',
      async: true,
      contentType: 'application/json',
      data: JSON.stringify(post_data),
      success: function(data, status) {
        if(0 == data.code) {
          if(data.hasOwnProperty('data') && data.data.hasOwnProperty('redirect')) {
            parent.document.location.href=data.data.redirect;
          } else {
            let redirectUrl = "/workflow/activity/detail/" + $("#activity_id").text().trim();
            parent.document.location.href=redirectUrl;
          }
        } else {
          //parent.alert(data.msg);
          var modalcontent =  data.msg;
          $("#inputModal").html(modalcontent);
          $("#allModal").modal("show");
        }
      },
      error: function(jqXHE, status) {
          //parent.alert('server error');
          var modalcontent =  "Server Error";
          $("#inputModal").html(modalcontent);
          $("#allModal").modal("show");
      }
    });
  });
  $('#btn-draft').on('click', function(){
    let post_uri = $(".cur_step", parent.document).data('next-uri');
    let post_data = {
      commond: $('#input-comment').val(),
      action_version: $(".cur_step", parent.document).data('action-version'),
      temporary_save: 1
    };
    $.ajax({
      url: post_uri,
      method: 'POST',
      async: true,
      contentType: 'application/json',
      data: JSON.stringify(post_data),
      success: function(data, status) {
        if(0 == data.code) {
          if(data.hasOwnProperty('data') && data.data.hasOwnProperty('redirect')) {
            parent.document.location.href=data.data.redirect;
          } else {
            let redirectUrl = "/workflow/activity/detail/" + $("#activity_id").text().trim();
            parent.document.location.href=redirectUrl;
          }
        } else {
            //parent.alert(data.msg);
             var modalcontent =  data.msg;
             $("#inputModal").html(modalcontent);
             $("#allModal").modal("show");
        }
      },
      error: function(jqXHE, status) {
        // parent.alert('server error');
        var modalcontent =  "Server Error";
        $("#inputModal").html(modalcontent);
        $("#allModal").modal("show");
      }
    });
  });
});
