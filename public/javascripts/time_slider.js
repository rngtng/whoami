  var from = new Date()
  var to   = new Date()
  
  function load( min, max, from, to) {
     d = new DoubleSlider({
        container: $('container'),
        clip_left: $('clip_left'),
        clip_right: $('clip_right'),
        handle_min: $('handle_min'),
        handle_max: $('handle_max'),
        range: [min, max],
        change: setRange,
        slide: setRange
     });
     d.setRange( from, to );
     show_range();
  }
  
   function setRange( range ) {
	from.setTime( range[0] * 86400000 );
	to.setTime(   range[1] * 86400000 );
        $('from_str').value =  date2str( from )
        $('to_str').value   =  date2str( to )
	$('from').value    =  Math.floor( from.getTime() / 1000 )
	$('to').value      =  Math.floor( to.getTime() / 1000 ) + 86400
     }
     
  function date2str( date )  {
    day =  date.getDate()
    if( day < 10 ) day = '0' + day
    month =  date.getMonth() + 1
    if( month < 10 ) month = '0' + month
    year = date.getFullYear()
    return day+'.'+month+'.'+year
  }
