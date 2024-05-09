/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.on_invoke_submitted = function() {

    const options = {
        "request_form_id": "#invoke-service-request-form",
        "on_started_activate_blinking": ["#invoking-please-wait"],
        "on_ended_draw_attention": ["#result-header"],
        "get_request_url_func": $.fn.zato.invoker.get_request_url,

    }
    $.fn.zato.invoker.run_sync_invoker(options);
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.invoke = function(
    url,
    data,
    callback,
    data_type,
    context
) {
    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        headers: {'X-CSRFToken': $.cookie('csrftoken')},
        complete: callback,
        dataType: data_type,
        context: context
    });
};

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.submit_form = function(
    url,
    form_id,
    options,
    on_success_func,
    on_error_func,
    display_timeout,
) {
    let _display_timeout = display_timeout || 120;
    let form = $(form_id);
    let form_data = form.serialize();

    $.ajax({
        type: "POST",
        url: url,
        data: form_data,
        dataType: null,
        headers: {'X-CSRFToken': $.cookie('csrftoken')},
        success: function(data, text_status, request) {
            let _on_success = function() {
                on_success_func(options, data);
            }
            setTimeout(_on_success, _display_timeout)
        },
        error: function(jq_xhr, text_status, error_message) {
            let _on_error = function() {
                on_error_func(options, jq_xhr, text_status, error_message);
            }
            setTimeout(_on_error, _display_timeout)
        },
    });
};

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.get_request_url = function() {
    let select = $("#service-select");
    let service = select.val();
    let out = "/zato/service/invoke/"+ service + "/cluster/1/";
    return out
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.on_sync_invoke_ended_common = function(
    options,
    status,
    data,
) {

    // Local variables
    let response = $.parseJSON(data);
    let has_response = !!response.response_time_human;
    let on_started_activate_blinking = options["on_started_activate_blinking"];
    let on_ended_draw_attention = options["on_ended_draw_attention"];

    // Disable blinking for all the elements that should blink
    on_started_activate_blinking.each(function(elem) {
        $.fn.zato.toggle_css_class($(elem), "invoker-blinking", "hidden");
    });

    // End by draw attention to specific elements
    on_ended_draw_attention.each(function(elem) {
        let _elem = $(elem);
        _elem.removeClass("hidden");
        _elem.removeClass("invoker-draw-attention");
        _elem.addClass("invoker-draw-attention", 1);
    });

    // This is optional
    if(response.response_time_human) {
        status += " | ";
        status += response.response_time_human;
    }

    if(has_response) {
        response_data = response.data;
    }
    else {
        response_data = $.fn.zato.to_json(response.data[0].zato_env);
    }

    $("#result-header").text(status);
    $("#data-response").text(response_data);
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.on_sync_invoke_ended_error = function(options, jq_xhr, text_status, error_message) {

    let status = jq_xhr.status + " " + error_message;
    $.fn.zato.invoker.on_sync_invoke_ended_common(options, status, jq_xhr.responseText);
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.on_sync_invoke_ended_success = function(options, data) {

    let status = "200 OK";
    $.fn.zato.invoker.on_sync_invoke_ended_common(options, status, data);
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

$.fn.zato.invoker.run_sync_invoker = function(options) {

    // Local variables
    let request_form_id = options["request_form_id"];
    let get_request_url_func = options["get_request_url_func"];
    let on_started_activate_blinking = options["on_started_activate_blinking"];
    let on_ended_draw_attention = options["on_ended_draw_attention"];

    // Obtain the URL we are to invoke
    let url = get_request_url_func();

    // Enable blinking for all the elements that should blink
    on_started_activate_blinking.each(function(elem) {
        $.fn.zato.toggle_css_class($(elem), "hidden", "invoker-blinking");
    });

    // Disable all the elements that previously might have needed attention
    on_ended_draw_attention.each(function(elem) {
        let _elem = $(elem);
        _elem.addClass("hidden");
    });

    // Submit the form, if we have one on input
    if(request_form_id) {
        $.fn.zato.invoker.submit_form(
            url,
            request_form_id,
            options,
            $.fn.zato.invoker.on_sync_invoke_ended_success,
            $.fn.zato.invoker.on_sync_invoke_ended_error
        )
    }
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
