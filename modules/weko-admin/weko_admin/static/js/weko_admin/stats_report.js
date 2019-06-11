$(document).ready(function () {
  var fileDownloadURL = '/admin/report/stats_file_tsv';
  $('#downloadReport').on('click', function () {
    var year = $("#report_year_select").val();
    var month = $("#report_month_select").val();
    var type = $("#report_type_select").val();
    if(year == 'Year') {
      alert('Year is required!');
      return;
    } else if (month == 'Month') {
      alert('Month is required!');
      return;
    }
    let uriByType = {
        file_download:'file_download',
        file_preview:'file_preview',
        detail_view:'report/record/record_view',
        file_using_per_user:'report/file/file_using_per_user'};
    var statsURL = '/api/stats/' + uriByType[type] + '/' + year + '/' + month;
    var statsReports = {};
    var ajaxReturn = [0,0,0,0];

    if (type == 'all') { // Get both reports
      let options = ['file_download',
        'file_preview',
        'detail_view',
        'file_using_per_user'];
      $.ajax({
        url: '/api/stats/' + options[0] + '/' + year + '/' + month,
        type: 'GET',
        async: false,
        contentType: 'application/json',
        success: function (results) {
          statsReports[options[0]] = results;
        },
        error: function (error) {
          console.log(error);
          $('#error_modal').modal('show');
        }
      });
      $.ajax({
        url: '/api/stats/' + options[1] + '/' + year + '/' + month,
        type: 'GET',
        async: false,
        contentType: 'application/json',
        success: function (results) {
          statsReports[options[1]] = results;
        },
        error: function (error) {
          console.log(error);
          $('#error_modal').modal('show');
        }
      });
      $.ajax({
        url: '/api/stats/' + uriByType[options[2]] + '/' + year + '/' + month,
        type: 'GET',
        async: false,
        contentType: 'application/json',
        success: function (results) {
          statsReports[options[2]] = results;
        },
        error: function (error) {
          console.log(error);
          $('#error_modal').modal('show');
        }
      });
      $.ajax({
        url: '/api/stats/' + uriByType[options[3]] + '/' + year + '/' + month,
        type: 'GET',
        async: false,
        contentType: 'application/json',
        success: function (results) {
          statsReports[options[3]] = results;
        },
        error: function (error) {
          console.log(error);
          $('#error_modal').modal('show');
        }
      });
      setStatsReportSubmit(statsReports);
    } else { // Get single report
      $.ajax({
        url: statsURL,
        type: 'GET',
        async: false,
        contentType: 'application/json',
        success: function (results) {
          statsReports[type] = results;
          setStatsReportSubmit(statsReports);
        },
        error: function (error) {
          console.log(error);
          $('#error_modal').modal('show');
        }
      });
    }
  });

   $('#addEmail').on('click', function () {
       var addressRange = parseInt($('#email_address_length').val());

   //    moreEmail(addressRange);
   //    $('#email_address_length').val((addressRange + 1));
        $(moreEmail(addressRange)).insertBefore('#removeEmail'+ addressRange);
        $('#address_' + addressRange).append(' &nbsp;');
        $('#email_address_length').val((addressRange + 1));
    });

    $('#saveEmail').on('click', function () {
         $('#email_form').submit();
         var message = 'Successfully email address saved.';
         addAlert(message);
        /*var emailAdd = $('#inputEmail').val();
        
        $.ajax({
            url: "/api/stats/get_email_address",
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify(emailAdd),
            dataType: 'json',
            success: function(data){
                var message = 'Successfully email address saved.';
                addAlert(message);
            }
            error: function(error){
                var modalcontent = error;
                $("#inputModal").html(modalcontent);
                $("#allModal").modal("show");
            }
        });*/
    });

    $('#removeEmail_'+row_id).on('click',function(){
        //$('#email_'+row_id).remove();

        var addressRange = parseInt($('#email_address_length').val());
        $('#removeEmail' + row_id).remove();
        $('#email_address_length').val((addressRange - 1));
    });
});

function setStatsReportSubmit(statsReports) {
  $('#report_file_input').val(JSON.stringify(statsReports));
  $('#report_file_form').submit();
  $('#report_file_input').val('');
}

function addAlert(message) {
    $('#alerts').append(
        '<div class="alert alert-light" id="alert-style">' +
        '<button type="button" class="close" data-dismiss="alert">' +
        '&times;</button>' + message + '</div>');
         }

function moreEmail(address_id){
    var id = address_id;
    $('#newEmail').append(
    '<div class="col-md-5 col-md-offset-3" id="emailAdd">'
    +'<input type="text" class="form-control" name="inputEmail" id="inputEmail_' + id + '"'
    // +'<input type="text" class="form-control" name="inputEmail" id="inputEmail" name="inputEmail"'
    +'placeholder="Enter email address." value=""></br>'
    +'</div>'
    +'<div class="col-md-1">'
    +'<button class="btn-danger remove-button" id="remove_button_' + id + '">'
    +'<span class="glyphicon glyphicon-remove"></span>'
    +'</button>'
    +'</div>'

    );
}
