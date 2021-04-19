 /*
  * Clearable Text Field - jQuery plugin version 0.3.2
  * Copyright (c) 2009 Tatsuya Ono
  *
  * http://github.com/ono/clearable_text_field
  *
  * Dual licensed under the MIT and GPL licenses:
  *   http://www.opensource.org/licenses/mit-license.php
  *   http://www.gnu.org/licenses/gpl.html
  */
  //Fixes and enhancements Copyright 2012 EL SoftWare, Inc.
(function($) {
  $.fn.clearableTextField = function() {
    if ($(this).length>0) {
      $(this).bind('keyup change paste cut', onSomethingChanged);
    
      $(this).each( function(){
		var l_Input = $(this);
		
		l_Input.wrap('<div class="clear_button_wrapper" style="margin:0;padding:0;position:relative; display:inline;" />');
		l_Input.after("<div class='text_clear_button'></div>");
        
		//11 is the width of the graphic file
		//The following line seems to fix the width chaning due to the future css padding right change and being the Transition Doctype, at least in non IE browsers
		l_Input.width(l_Input.width());
		l_Input.css('padding-right', "11px");
		
        trigger($(this));
      });      
    }
  }
  
  function onSomethingChanged() {
    trigger($(this), true);
  }
  
  function trigger(input, set_focus) {
    if(input.val().length>0){
      add_clear_button(input, set_focus);
    } else {
      remove_clear_button(input, set_focus);
    }    
  }
  
  function add_clear_button(input, set_focus) {
    if (input.attr('has_clearable_button')!="1") {
      input.attr('has_clearable_button',"1");
      
      var clear_button = input.next();
      var w = clear_button.outerHeight(), h = clear_button.outerHeight();
      
      clear_button.css("visibility","visible");
	  
      var pos = input.position();
      var style = {};  
      style['left'] = pos.left + input.outerWidth(false) - (w+2);
      var offset = Math.round((input.outerHeight(true) - h)/2.0);
      style['top'] = pos.top + offset;
            
      clear_button.css(style);
          
      clear_button.click(function(){
        input.val('');
        trigger(input);
        input.change();
      });
      
      if (set_focus && set_focus!=undefined) input.focus();
    }
  }
  
  function remove_clear_button(input, set_focus) {
    var clear_button = input.next();
    
    clear_button.css("visibility","hidden");
    input.attr('has_clearable_button',"");
	
    if (set_focus && set_focus!=undefined) input.focus();
  }
  
})(jQuery);